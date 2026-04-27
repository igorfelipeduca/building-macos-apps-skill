# Feature implementation flow

How to add a feature without breaking the rest of the app and without writing a 600-line view file.

## Flow

```
Spec → Model → View → State → Wire → Run → Polish → Verify
```

Never skip. Each step gates the next.

### 1. Spec (1–2 sentences)

"Add a Hand-off button in the toolbar. Click → opens a sheet with workdir + terminal picker → confirm → spawns Claude Code in that terminal."

### 2. Model

What new types? What new persistent state?

- `TerminalChoice` enum
- `@AppStorage("handoffWorkdir")` and `@AppStorage("handoffTerminal")`
- New service: `ClaudeHandoff`

Sketch the API shape *before* the view:

```swift
enum ClaudeHandoff {
    static func open(prompt: String, workdir: URL, terminal: TerminalChoice)
}
```

If the model is wrong, the view will be wrong. Don't write the view first.

### 3. View

One file per logical UI unit. Compose, don't nest. Patterns:

```swift
struct HandoffSheet: View {
    let blocks: [PromptBlock]
    let onClose: () -> Void

    @AppStorage(...) ...
    @State ...
    @FocusState ...

    var body: some View {
        VStack(spacing: 0) {
            header
            Divider()
            ScrollView { content.padding(20) }
            Divider()
            footer
        }
    }

    private var header: some View { ... }
    private var content: some View { ... }
    private var footer: some View { ... }
}
```

Header / content / footer / etc. as private computed properties — keeps `body` legible.

### 4. State

- Use `@State` for view-local ephemeral state
- Use `@AppStorage` for persist-across-launches
- Use `@Observable` classes passed via `.environment(...)` for shared state
- Use `@Bindable` for two-way binding into a `@Model` SwiftData object
- Use `@Environment(\.modelContext)` for SwiftData writes

### 5. Wire

Hook the new view into the parent. `.sheet(isPresented:)`, `.toolbar { ToolbarItem { ... } }`, etc.

For floating panels (slide-out from button), prefer `.overlay(alignment: .bottomTrailing) { if showPanel { ... } }` with `.transition(.move(edge: .trailing).combined(with: .opacity))` and explicit `withAnimation` on toggle.

### 6. Run

```bash
xcodebuild -project <Name>.xcodeproj -scheme <Name> -configuration Debug -destination 'platform=macOS' build 2>&1 | grep -E "(error:|warning:|BUILD)" | tail -10
pkill -f "<Name>.app/Contents/MacOS/<Name>"; open <built-app-path>
```

Click through. Do the thing. Verify visually.

**Rule**: do not declare a feature working if you haven't run the app since the last code change. Type-checking is not a substitute for clicking.

### 7. Polish

After the feature *works*, make it feel right:

- `.clickable()` extension on every Button (uses `pointerStyle(.link)`)
- Hover state on cards (`@State hovered`, `.onHover { hovered = $0 }`, `.scaleEffect(hovered ? 1.04 : 1.0)`)
- Spring animations on changes: `.animation(.snappy(duration: 0.2), value: <key>)`
- Consistent spacing — pick 8 / 12 / 16 / 24 / 32, don't introduce random 13s
- Color from accent: `Color.accentColor` (sourced from asset catalog), not hard-coded hex
- Shadows: light, low-radius, low-opacity. `.shadow(color: .black.opacity(0.18), radius: 14, y: 6)`

### 8. Verify

```bash
xcodebuild ... build 2>&1 | grep -E "(error:|warning:)" | head
```

No warnings = ship. Warnings? Fix them before merging:

- `nonisolated` on stateless static helpers used from non-MainActor contexts
- Replace `Text + Text` concatenation with single `Text` + Markdown / interpolation
- Drop unused `@State`, unused imports

## Common feature patterns we used in Prompty

### Floating panel that slides out from a button

```swift
.overlay(alignment: .bottomTrailing) {
    ZStack(alignment: .bottomTrailing) {
        if showPanel {
            MyPanel(...)
                .padding(.trailing, 22)
                .padding(.vertical, 22)
                .transition(.move(edge: .trailing).combined(with: .opacity))
        } else if !buttonHidden {
            FloatingButton(...) {
                withAnimation(.snappy(duration: 0.28)) { showPanel = true }
            }
            .padding(22)
            .transition(.scale(scale: 0.85).combined(with: .opacity))
        }
    }
}
```

### Per-message undo (or per-action snapshot)

```swift
struct AIMessage {
    var previousState: [Block]?  // snapshot pre-action
    var didApply: Bool
}

// In the message view:
if let snapshot = msg.previousState, msg.didApply {
    Button("Undo this change") {
        restoreState(snapshot)
        msg.didApply = false
    }
}
```

Never use a global undo stack for AI edits — per-message snapshots make every edit cleanly reversible without coupling.

### Optimistic submit with cancellable Task

```swift
@State var generationTask: Task<Void, Never>?

private func generate() {
    isLoading = true
    idea = ""  // optimistic clear
    generationTask = Task {
        defer {
            Task { @MainActor in
                isLoading = false
                generationTask = nil
            }
        }
        do {
            let result = try await ai.draftStreaming(...)
            onComplete(result)
        } catch is CancellationError {
            // user pressed stop — keep partial visible, no error
        } catch {
            errorText = error.localizedDescription
        }
    }
}

private func stop() { generationTask?.cancel() }
```

In the streaming loop, check `Task.isCancelled` after each emitted partial and `throw CancellationError()`.

## Anti-patterns

- ❌ Stuffing all state into one giant `@Observable` class — split per feature
- ❌ Using `DispatchQueue.main.async` instead of `Task { @MainActor in }` — SwiftUI/Swift 6 prefers structured concurrency
- ❌ `body` over 80 lines — extract subviews
- ❌ Reading `AppStorage` in 5 different views — wrap in a `@Observable` `Settings` class if it's used widely
- ❌ Writing to `@AppStorage` from inside a render — use `.task` or button actions
