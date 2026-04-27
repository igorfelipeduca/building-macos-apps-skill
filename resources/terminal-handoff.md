# Terminal hand-off

Spawn a session in the user's terminal of choice with content (a Claude Code prompt, a script, a CLI invocation) preloaded.

## Up-front decision: sandbox

If you're shipping outside the App Store, **disable App Sandbox**. Period.

```
ENABLE_APP_SANDBOX = NO  // both Debug and Release in project.pbxproj
```

Why: with sandbox ON, every file your app writes gets the `com.apple.quarantine` xattr automatically. Gatekeeper then rejects `.command` files with the *"is damaged and can't be opened"* dialog. You can `removexattr()` it but the sandbox blocks that too on certain macOS versions. Disable sandbox once and move on.

If you must keep sandbox (App Store distribution), you cannot reliably do `.command` file hand-off. Use only the AppleScript paste-flow, and the user will need to grant Automation permission per terminal.

## Architecture

```
User clicks "Hand off" toolbar button
  ↓
HandoffSheet (workdir picker + terminal picker + Open button)
  ↓
ClaudeHandoff.open(prompt:, workdir:, terminal:)
  ↓
  ├─ Path A: Terminal/iTerm/Hyper → write .command file → NSWorkspace.open with chosen app
  └─ Path B: Warp/Ghostty/etc.    → open -a App workdir → AppleScript paste + return
```

## Terminal detection

```swift
enum TerminalChoice: String, CaseIterable, Identifiable {
    case terminal  = "com.apple.Terminal"
    case iterm     = "com.googlecode.iterm2"
    case warp      = "dev.warp.Warp-Stable"
    case ghostty   = "com.mitchellh.ghostty"
    case hyper     = "co.zeit.hyper"
    case kitty     = "net.kovidgoyal.kitty"
    case alacritty = "io.alacritty"
    case wezterm   = "com.github.wez.wezterm"

    var id: String { rawValue }
    var bundleID: String { rawValue }
    var displayName: String { /* ... */ }

    var appURL: URL? {
        NSWorkspace.shared.urlForApplication(withBundleIdentifier: bundleID)
    }

    var isInstalled: Bool { appURL != nil }
    static var installed: [TerminalChoice] { allCases.filter(\.isInstalled) }
    var icon: NSImage? {
        guard let url = appURL else { return nil }
        return NSWorkspace.shared.icon(forFile: url.path)
    }
}
```

`NSWorkspace.shared.icon(forFile:)` returns the actual app icon for free.

## Path A — `.command` file (Terminal / iTerm / Hyper)

These terminals natively run `.command` files when opened. Strategy:

```swift
private static func launchViaCommandFile(workdir: URL, terminal: TerminalChoice, command: String) {
    guard let scriptsDir = ensureScriptsDirectory() else { return openClaudeFallback() }

    let stamp = "\(Int(Date().timeIntervalSince1970))-\(Int.random(in: 1000...9999))"
    let promptFile = scriptsDir.appendingPathComponent("prompty-prompt-\(stamp).txt")
    let commandFile = scriptsDir.appendingPathComponent("prompty-launch-\(stamp).command")

    try? prompt.write(to: promptFile, atomically: true, encoding: .utf8)
    stripQuarantine(promptFile)  // belt-and-suspenders even with sandbox off

    let escapedWorkdir = workdir.path.replacingOccurrences(of: "'", with: "'\\''")
    let escapedPath = promptFile.path.replacingOccurrences(of: "'", with: "'\\''")

    let script = """
    #!/bin/bash
    export PATH="$HOME/.local/bin:$HOME/.bun/bin:$HOME/.npm-global/bin:/opt/homebrew/bin:/usr/local/bin:$PATH"
    clear
    cd '\(escapedWorkdir)' || { echo "Working directory not accessible"; read -n 1 -s -r -p "Press any key…"; exit 1; }
    if ! command -v claude >/dev/null 2>&1; then
        echo "Claude Code CLI not found in PATH."
        echo "Install: https://docs.claude.com/en/docs/claude-code/setup"
        echo
        read -n 1 -s -r -p "Press any key to close…"
        exit 1
    fi
    exec claude "$(cat '\(escapedPath)')"
    """

    try? script.write(to: commandFile, atomically: true, encoding: .utf8)
    try? FileManager.default.setAttributes(
        [.posixPermissions: NSNumber(value: 0o755)],
        ofItemAtPath: commandFile.path
    )
    stripQuarantine(commandFile)

    let config = NSWorkspace.OpenConfiguration()
    config.activates = true
    if let appURL = terminal.appURL {
        NSWorkspace.shared.open([commandFile], withApplicationAt: appURL, configuration: config) { _, _ in }
    }
}

private static func stripQuarantine(_ url: URL) {
    url.path.withCString { cPath in
        _ = removexattr(cPath, "com.apple.quarantine", 0)
    }
}
```

Storage location: `~/Library/Application Support/<App>/Handoff/` (use `FileManager.default.url(for: .applicationSupportDirectory, ...)` and create a subdir). Files persist across runs and don't get cleaned up mid-Terminal-execution like `/tmp` might.

The shell script:
- Sets a permissive `PATH` (adds homebrew + bun + npm globals so `claude` resolves)
- `cd` to workdir, with safe failure
- `command -v claude` check, with helpful install hint on miss
- `exec claude "$(cat 'prompt-file.txt')"` — using `$(cat ...)` avoids needing to escape the prompt content into a shell argument

## Path B — paste flow (Warp / Ghostty / Alacritty / kitty / WezTerm)

These don't reliably execute `.command` files. Instead:

1. Copy `claude "<prompt>"` to clipboard (with proper escaping)
2. Open the terminal at the workdir via `open -a App.app workdir`
3. Wait for the terminal to be frontmost (poll `NSWorkspace.frontmostApplication`)
4. Send `⌘V + ↩` via AppleScript to System Events

```swift
private static func launchViaPaste(workdir: URL, terminal: TerminalChoice, command: String) {
    guard let appURL = terminal.appURL else { return openClaudeFallback() }

    let alreadyRunning = isAppRunning(bundleID: terminal.bundleID)
    let isTrusted = ensureAccessibility()

    // 1. Open terminal at workdir
    let openTask = Process()
    openTask.executableURL = URL(fileURLWithPath: "/usr/bin/open")
    openTask.arguments = ["-a", appURL.path, workdir.path]
    try? openTask.run()

    guard isTrusted else {
        showClipboardHint(terminalName: terminal.displayName, missingAccessibility: true)
        return
    }

    // 2. Wait for it to be frontmost, then paste
    let appName = appURL.deletingPathExtension().lastPathComponent
    let coldStartTimeout: TimeInterval = alreadyRunning ? 1.5 : 4.0
    waitForFrontmost(bundleID: terminal.bundleID, timeout: coldStartTimeout) { reached in
        let settle: TimeInterval = reached ? 0.6 : 0.3
        DispatchQueue.main.asyncAfter(deadline: .now() + settle) {
            sendPasteReturn(toApp: appName, terminalDisplayName: terminal.displayName)
        }
    }
}

private static func sendPasteReturn(toApp appName: String, terminalDisplayName: String) {
    let escapedAppName = appName.replacingOccurrences(of: "\"", with: "\\\"")
    let source = """
    tell application "\(escapedAppName)" to activate
    delay 0.4
    tell application "System Events"
        keystroke "v" using command down
        delay 0.2
        keystroke return
    end tell
    """
    if let script = NSAppleScript(source: source) {
        var error: NSDictionary?
        script.executeAndReturnError(&error)
    }
}
```

## Permission setup (the painful part)

Three things need to be in place for AppleScript paste-return to work under hardened runtime:

### 1. `NSAppleEventsUsageDescription` in Info.plist

Without it, macOS silently rejects Apple Events. Add via build setting:

```
INFOPLIST_KEY_NSAppleEventsUsageDescription = "<App> controls your terminal to start a session with the prompt you composed."
```

### 2. `com.apple.security.automation.apple-events` entitlement

Create `<App>/<App>.entitlements`:

```xml
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
<dict>
    <key>com.apple.security.automation.apple-events</key>
    <true/>
</dict>
</plist>
```

Wire it via `CODE_SIGN_ENTITLEMENTS = <App>/<App>.entitlements` in both Debug and Release.

### 3. User-side TCC permission

First time the AppleScript runs, macOS shows *"<App> wants to control System Events."* User must click OK. If they deny, the secret is gone forever and you must:

```bash
tccutil reset AppleEvents <bundle.id>
```

Or guide them to **System Settings → Privacy & Security → Automation → \<App\> → System Events**.

## Accessibility check helper

```swift
import ApplicationServices

@discardableResult
private static func ensureAccessibility() -> Bool {
    let promptKey = kAXTrustedCheckOptionPrompt.takeUnretainedValue() as String
    let options = [promptKey: true] as CFDictionary
    return AXIsProcessTrustedWithOptions(options)
}
```

This both checks AND prompts if not granted. The prompt asks for **Accessibility** specifically (different from Automation but related — both must be granted for keystroke control).

## Frontmost wait helper

```swift
private static func waitForFrontmost(bundleID: String, timeout: TimeInterval, completion: @escaping (Bool) -> Void) {
    let deadline = Date().addingTimeInterval(timeout)
    func tick() {
        if NSWorkspace.shared.frontmostApplication?.bundleIdentifier == bundleID {
            completion(true); return
        }
        if Date() >= deadline {
            completion(false); return
        }
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) { tick() }
    }
    tick()
}
```

## Fallback alert when permissions are missing

Always have the prompt copied to clipboard regardless. If automation fails:

```swift
let alert = NSAlert()
alert.messageText = "Paste in \(terminalName) to start the session"
alert.informativeText = """
Prompty needs Automation permission to auto-run the command in \(terminalName).
Open System Settings → Privacy & Security → Automation, enable Prompty for "System Events", and click "Hand off to Claude" again.

The command is on your clipboard — press ⌘V then ↩︎ in \(terminalName) to start now.
"""
alert.addButton(withTitle: "Open System Settings")
alert.addButton(withTitle: "OK")
let response = alert.runModal()
if response == .alertFirstButtonReturn {
    if let url = URL(string: "x-apple.systempreferences:com.apple.preference.security?Privacy_Automation") {
        NSWorkspace.shared.open(url)
    }
}
```

## Anti-patterns

- ❌ Using `Process` to run `osascript` instead of `NSAppleScript` — same thing, but Process inherits permissions from `osascript`, not your app
- ❌ Writing the script to `NSTemporaryDirectory()` (per-process tmp) and then trying to open it from another process — sandbox/lifecycle confusion
- ❌ Hard-coding 1-second delay before sending keystrokes — Warp cold start can be 4s+
- ❌ Forgetting to copy the command to clipboard — if any permission step fails, user has no fallback
- ❌ Treating Accessibility and Automation as the same — they are separate TCC categories
