---
name: building-macos-apps
description: Build native, polished macOS apps with SwiftUI, SwiftData, Apple Intelligence, and Liquid Glass — from idea to signed and notarized DMG release. Use when the user wants to create a new macOS app, ship a feature in an existing one, design an onboarding flow, integrate FoundationModels, hand off to a terminal, or set up a GitHub Actions release pipeline. Optimized for macOS 26+ (Tahoe) on Apple Silicon, and biased toward apps that feel like Apple shipped them.
metadata:
  author: igor-ducca
  version: "1.0.0"
---

# building-macos-apps

A flow for building macOS apps that feel native — not generic AI slop, not Electron-styled, not Mac-flavored Windows. **macOS 26+ on Apple Silicon. SwiftUI + SwiftData. Apple Intelligence on-device. Liquid Glass surfaces. Signed and notarized DMG releases via GitHub Actions.**

## Iron rules

1. **Onboarding is product, not chore.** First launch is the most important UX surface. Use a 3–5 page sheet (welcome → how it works → key feature → social/credit). Never ship without it. See `resources/onboarding-patterns.md`.
2. **Build incrementally and verify visually.** After every meaningful change, run `xcodebuild` and re-launch the app. Type-checking ≠ feature-checking. Confirm in the actual window.
3. **Lean on the platform.** Use `@Observable`, `@AppStorage`, SwiftData, `FoundationModels`, `NSWorkspace`, `glassEffect`, `pointerStyle(.link)`. Do not roll your own when Apple ships it.
4. **Sandbox off for personal dev tools that hand off to terminals.** Sandbox auto-quarantines `.command` files and Gatekeeper rejects them. If you need terminal hand-off, you'll fight sandbox forever. See `resources/terminal-handoff.md`.
5. **Persist user preferences via `@AppStorage`, not `@State`.** `hasOnboarded`, hidden buttons, last-used terminal, last-used workdir — all should survive relaunch.
6. **Confirm before publishing.** Public repos, releases, and pushes are visible-to-others actions. Audit for secrets first. Apple Team ID is *public* (in every signed binary); app-specific passwords, `.p12`, and Apple ID password are *not*.

## Phase 1 — Ideation (before any code)

Before writing a line of Swift, force the user through a quick scope frame. Most macOS-app sessions go off the rails because the agent starts coding the third sub-feature that came up in conversation. Don't.

Ask in 1–2 sentences each:

1. **What does it do in one sentence?** ("Compose Claude prompts that won't drift.")
2. **Who is it for?** (You + 50 friends? An indie userbase? App Store?)
3. **What's the smallest version worth shipping?** Strip everything else for v1.
4. **Native bias.** Is there a SwiftUI / system primitive that gives 80% of this for free?
5. **Persistence model.** SwiftData `@Model`, `@AppStorage`, JSON in App Support — pick one and commit.
6. **Ship target.** App Store (sandbox required, automation entitlements painful), or DMG via GitHub (sandbox optional, terminal hand-off easy)? See `resources/ideation-checklist.md`.

Record the answers as a one-paragraph product summary. Reference it whenever the user proposes scope creep.

## Phase 2 — Project bootstrap

```bash
# Xcode 26+ scaffolds a SwiftUI macOS app at ~/path/to/Project
# It already includes:
#   - PBXFileSystemSynchronizedRootGroup (drop files in Project/, auto-built)
#   - default-isolation = MainActor (Swift 6 concurrency)
#   - ENABLE_APP_SANDBOX = YES  (turn off if you need terminal handoff)
#   - ENABLE_HARDENED_RUNTIME = YES
```

Do these on day one:

1. **Set the deployment target** to `26.3` (or whichever macOS 26.x ships). Apple Intelligence + Liquid Glass require it.
2. **Reset window state controls.** Add `.defaultSize(width: 1280, height: 800)` and `.windowResizability(.contentSize)` to `WindowGroup` so first launch centers properly.
3. **Decide sandbox up front.** If you need to hand off to a terminal, disable App Sandbox in `project.pbxproj` (`ENABLE_APP_SANDBOX = NO`) — fighting it later is hours of TCC pain. See `resources/terminal-handoff.md`.
4. **Set up an entitlements file** at `Project/Project.entitlements` and point `CODE_SIGN_ENTITLEMENTS` at it (in both Debug and Release configs). Even an empty file pays off later.
5. **Add `INFOPLIST_KEY_NSAppleEventsUsageDescription`** if you'll ever use AppleScript / `osascript` (terminal handoff, system automation). Without it, macOS silently denies Apple Events.

## Phase 3 — Onboarding (this is the user's first impression — treat it as such)

`resources/onboarding-patterns.md` has the full template. The shape:

```
WindowGroup → ContentView → .sheet(isPresented: !hasOnboarded) { OnboardingView }
```

- 3–5 paged sheet, manual paging (no `TabView(.page)` on macOS)
- Big visual on each page (logo, system illustration, animated SF Symbol)
- Footer: page dots, Skip on left, Continue/Get Started on right
- `@AppStorage("hasOnboarded")` to persist
- `.interactiveDismissDisabled(true)` so user can't ESC out half-way
- **Last page should always have a social/credit CTA** (X, GitHub, support) — most users only see this flow once, don't waste it

Required: a working "Get Started" button that closes the sheet AND drops the user into a non-empty primary view (sample document, welcome cards, template gallery — never a blank canvas).

## Phase 4 — Build features incrementally

For each feature:

1. Sketch the data model (`@Model` for SwiftData, plain struct + `Codable` otherwise)
2. Build the view with `@Observable` state objects passed via `.environment(...)` (Swift 6 way) or `@EnvironmentObject` (older)
3. Wire interactions
4. **Run** the app, click through, confirm
5. Polish (animations, hover states, `pointerStyle(.link)` on every clickable thing)

`resources/feature-implementation-flow.md` has the canonical pattern. Common mistakes to avoid:
- Don't write a 500-line view file. Split per concern.
- Don't put cursor-pointer logic on every Button manually — use a `.clickable()` View extension wrapping `.pointerStyle(.link)`.
- Don't use `.sheet` for things that should slide out from a button (floating panel) — use `.overlay(alignment:) { ... }` with `.transition` and `withAnimation`.

## Phase 5 — Apple Intelligence (`FoundationModels`)

`resources/apple-intelligence-integration.md` has streaming + structured-output patterns.

Top-level rules:

1. **Check availability before every call.** `SystemLanguageModel.default.availability` — handle `.unavailable` gracefully (show notice, don't crash).
2. **Use `@Generable` for structured output.** Mark fields with `@Guide(description:)` and the model fills them. Each property auto-becomes optional in `PartiallyGenerated`.
3. **Stream don't wait.** `session.streamResponse(to:generating:)` returns snapshots. Each `snapshot.content` is a `PartiallyGenerated<T>`. Update UI on every emit.
4. **Bigger output requires bigger options.** `GenerationOptions(temperature: 0.7, maximumResponseTokens: 4096)` and explicit "write 4–8 sentences per field" in instructions. The on-device model is small (~3B); without coaxing it returns one-liners.
5. **Persist `LanguageModelSession`** across calls if you want conversation context (multi-turn editing). Reset by setting it to `nil`.
6. **Always have a stop button.** Streaming hallucinations happen. Wrap the call in `Task { ... }`, store the task, check `Task.isCancelled` inside the streaming loop, throw `CancellationError`.

## Phase 6 — Polish (the part that makes it feel Apple-shipped)

- **Liquid Glass**: `.glassEffect(.regular.tint(Color.accentColor.opacity(0.18)).interactive(), in: Capsule())` on floating buttons, panels, surfaces
- **Pointer cursor** on every clickable thing: extension `.clickable() -> some View { self.pointerStyle(.link) }`
- **iMessage-style spring** on inserting messages: `.transition(.scale(scale: 0.7, anchor: .bottomTrailing).combined(with: .offset(y: 24)).combined(with: .opacity))` + `.animation(.spring(response: 0.42, dampingFraction: 0.68), value: count)`
- **Native asset catalog** for accent color and AppIcon — never hard-code hex throughout the codebase
- **Tabular numbers** for counters: `.font(.caption.monospacedDigit())`
- **Optical alignment**: place a 22pt icon next to 17pt text with the icon offset by 1–2pt downward when needed

`resources/liquid-glass-and-design.md` has the full polish pass.

## Phase 7 — Terminal hand-off (optional but high-value)

If your app composes anything Claude Code can run (prompts, scripts, repro steps), add a "Hand off to Claude" button. Pattern:

1. Sheet with workdir picker (`NSOpenPanel`) + terminal picker (`TerminalChoice` enum, install detection via `NSWorkspace.urlForApplication(withBundleIdentifier:)`)
2. Per-terminal launch strategy (Terminal/iTerm: `.command` file via Launch Services; Warp/Ghostty/etc: `open -a` + AppleScript paste-return)
3. Persist last-used workdir + terminal via `@AppStorage`
4. Always copy the command to the clipboard as fallback so user can ⌘V manually

`resources/terminal-handoff.md` has the full implementation including the Accessibility/Automation permission flow.

## Phase 8 — Release pipeline (signed, notarized DMG via GitHub Actions)

`resources/github-release-workflow.md` is the full guide. Summary:

1. Get a **Developer ID Application** cert (App Store / Apple Distribution certs don't work for outside-store distribution)
2. Export as `.p12`, base64 it, set `CERTIFICATE_P12` and `CERTIFICATE_PASSWORD` secrets
3. Create an **app-specific password** at appleid.apple.com → set `APPLE_ID_PASSWORD`
4. Set `APPLE_ID` (your Apple ID email) and `APPLE_TEAM_ID` (10-char public identifier)
5. Workflow uses `xcrun notarytool submit --wait` then `xcrun stapler staple`
6. `create-dmg` packages it
7. `softprops/action-gh-release@v2` publishes a versioned tag with the DMG and `make_latest: true`

Use `gh secret set <NAME> -R owner/repo` to set secrets via CLI — faster than the web UI and you don't double-paste.

## Phase 9 — Public release readiness audit

Before pushing public:

```bash
# What's tracked?
git ls-files

# Anything sensitive in source?
grep -rE "(api[_-]?key|secret|password|@gmail.com|@apple.com)" . \
  --exclude-dir={.git,DerivedData,build}

# Tracked xcuserdata? remove it.
git ls-files | grep xcuserdata
```

What's actually private:
- ✗ Apple ID email
- ✗ App-specific password  
- ✗ `.p12` files
- ✗ App Store Connect API keys
- ✗ Any `.env` or local secrets file

What's *public-by-default*:
- ✓ Apple Team ID (visible in every signed binary, App Store Connect)
- ✓ Bundle identifier
- ✓ Provisioning profile names
- ✓ Asset catalog contents

Do not nuke the Team ID from `pbxproj` thinking it's a secret. It isn't.

## Things that look like answers but are not

- **"Just enable Sandbox + add automation entitlements."** Sandbox + automation entitlement still triggers TCC + quarantine for files you create. Many days of fighting Apple Events get solved by `ENABLE_APP_SANDBOX = NO` for a personal dev tool. You can flip it back on for App Store later.
- **"Use `NSWindow` directly."** Don't drop down to AppKit unless SwiftUI has no answer. macOS 26 SwiftUI handles 95% of native APIs.
- **"Use a third-party LLM SDK."** Apple Intelligence is on-device, free, no API key, integrated. Use `FoundationModels` first.
- **"Reset Xcode caches."** When build behaves weirdly, the answer is almost never DerivedData. Read the actual error.
- **"Add a launch image."** macOS apps don't need launch images. The OS handles app launch.

## When to escalate

- The user wants App Store distribution AND terminal hand-off in the same app. App Store requires sandbox; terminal handoff fights sandbox. They need to pick one or maintain two configurations.
- The user's deployment target is macOS 14 or earlier. This skill is biased to macOS 26+ APIs. The patterns degrade gracefully but most "wow" features (Liquid Glass, Foundation Models, `pointerStyle`) require recent OS.
- The build runs on Mac mini Intel. Apple Intelligence + many macOS 26 APIs are Apple Silicon-only.

## Completion shape

When delivering a working app, hand back:

```
APP
  Name:           <app name>
  Bundle ID:      <com.example.app>
  Deployment:     macOS <26.x>
  Sandbox:        ON | OFF (and why)
  
SHIPPED
  Onboarding:     <pages count> pages, persisted via @AppStorage
  Features:       <one-line each>
  AI integration: <draft|edit|polish|none>
  Terminal HO:    <terminal list|none>
  Release:        <signed+notarized via gh actions | unsigned local-only>

VERIFICATION
  Build:          ✓  xcodebuild Debug succeeded, no warnings
  Launch:         ✓  app window appears centered
  Onboarding:     ✓  shows on first launch, dismisses on Get Started
  AI:             ✓  Build with AI streamed and applied
  Handoff:        ✓  Claude session opened with prompt
```

Trust mechanical proof over assertions. The user has been burned before. Show, don't tell.
