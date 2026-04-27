# Apple Intelligence integration (`FoundationModels`)

How to use the on-device foundation model for structured generation, streaming, conversation context, and per-block polish — without burning the user with one-line outputs or runaway hallucinations.

## Availability check (always do this first)

```swift
import FoundationModels

@MainActor @Observable
final class PromptAI {
    enum Availability: Equatable {
        case checking, available, unavailable(String)
    }
    private(set) var availability: Availability = .checking

    var isAvailable: Bool {
        if case .available = availability { return true }
        return false
    }

    func refresh() {
        let model = SystemLanguageModel.default
        if case .available = model.availability {
            availability = .available
        } else {
            availability = .unavailable(
                "Apple Intelligence is unavailable. Turn it on in System Settings → Apple Intelligence & Siri, or wait for the on-device model to finish downloading."
            )
        }
    }
}
```

Hide AI features (or show inline "unavailable" notices) when `!isAvailable`. Don't crash on `LanguageModelSession()` calls when the model isn't ready.

## Structured output via `@Generable`

```swift
@Generable
struct DraftedPromptBlocks {
    @Guide(description: "Role, environment, goal. 2-3 sentences.")
    var taskContext: String

    @Guide(description: "Voice, tone, brand. Plain instruction.")
    var tone: String

    @Guide(description: "Hard constraints as bulleted list. 6–10 bullets.")
    var rules: String

    // ...
}
```

Each `var` becomes part of `DraftedPromptBlocks.PartiallyGenerated` automatically — every property is `Optional` in the partial type. The model fills them progressively while streaming.

## Calling synchronously (for short polish-style work)

```swift
let session = LanguageModelSession(instructions: "You polish prompt blocks for clarity...")
let response = try await session.respond(
    to: "Polish this:\n\n\(content)\n\nPolished version:",
    options: GenerationOptions(temperature: 0.5, maximumResponseTokens: 2048)
)
return response.content
```

## Calling with streaming

```swift
let stream = session.streamResponse(
    to: prompt,
    generating: DraftedPromptBlocks.self,
    options: GenerationOptions(temperature: 0.7, maximumResponseTokens: 4096)
)

var last: DraftedPromptBlocks.PartiallyGenerated?
for try await snapshot in stream {
    if Task.isCancelled {
        throw CancellationError()
    }
    let partial = snapshot.content   // ← `.content`, not the snapshot itself
    applyPartial(partial)            // update UI from the partial
    last = partial
}

// Convert last partial → full struct
return DraftedPromptBlocks(
    taskContext: last?.taskContext ?? "",
    tone:        last?.tone ?? "",
    // ...
)
```

**Key gotchas:**
- `streamResponse(...)` returns an async sequence of `Snapshot` values. Use `snapshot.content` to get the `PartiallyGenerated<T>`.
- `Task.isCancelled` check + `throw CancellationError()` is your stop button (see below).
- The on-device model is small (~3B params). Without explicit length coaching it returns one-liners.

## Forcing larger outputs

Two levers, both required:

1. **Bump `GenerationOptions.maximumResponseTokens`** to 4096 for build/edit, 2048 for polish.
2. **Tell the model to write more in the system instructions and `@Guide` text:**

```swift
private var composeInstructions: String { """
    REQUIREMENTS for every block:
    - Be substantive and detailed. Aim for 4–8 full sentences per text block, never \
      one-liners. Pack in concrete specifics: file paths, exact tool names, expected \
      formats, edge cases, fallback behavior.
    - Rules block: 6–10 bulleted constraints with - prefix.
    - Examples block: 1–3 concrete worked examples in User: / Assistant: format.
    - Output block: a strict contract — exact JSON schema, XML tags, or markdown \
      structure with field names. Be specific.
    """ }
```

User prompts also need: "Be detailed and specific in every field — never collapse to a single line."

## Conversation context across turns

To support multi-turn editing ("make rules stricter"), persist the `LanguageModelSession`:

```swift
@MainActor @Observable
final class PromptAI {
    private var composeSession: LanguageModelSession?

    private func sharedComposeSession() -> LanguageModelSession {
        if let composeSession { return composeSession }
        let s = LanguageModelSession(instructions: composeInstructions)
        composeSession = s
        return s
    }

    func resetComposeConversation() {
        composeSession = nil
        transcript = []
    }
}
```

Each subsequent `streamResponse` call inside the same session sees prior turns automatically. Reset when user clicks "New conversation."

## Targeted edits (only change what user asked)

Tell the model: empty string for a field means "leave the existing block unchanged."

```swift
private var composeInstructions: String { """
    TARGETED EDITS — critical:
    When the user names specific blocks ("improve the tone", "make rules stricter"), \
    ONLY return new content for those blocks. Leave every other field as an empty string \
    so the existing content is preserved.
    
    When the user gives a generic instruction ("make it better", "rewrite this"), \
    fill in every block with substantive content.
    
    An empty string for a field always means "leave the existing block unchanged".
    """ }
```

In the apply logic, filter out empty fields:

```swift
let updates = candidates.filter {
    !$0.1.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
}
```

## Stop button (cancellable streaming)

```swift
@State var generationTask: Task<Void, Never>?

private func generate() {
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
            // user stopped — keep partial visible, don't apply
        } catch {
            errorText = error.localizedDescription
        }
    }
}

private func stop() {
    generationTask?.cancel()
}
```

The send button morphs into a stop button while loading:
```swift
Button(action: isLoading ? stop : generate) {
    Image(systemName: isLoading ? "stop.fill" : "arrow.up")
        .contentTransition(.symbolEffect(.replace))
}
```

## Apple Intelligence color gradient

For visual cues on streaming/AI text:

```swift
enum AIColors {
    static let orange    = Color(red: 1.000, green: 0.569, blue: 0.145)  // #FF9125
    static let blue      = Color(red: 0.404, green: 0.753, blue: 0.945)  // #67C0F1
    static let pink      = Color(red: 0.804, green: 0.431, blue: 0.765)  // #CD6EC3
    static let pinkShock = Color(red: 0.969, green: 0.133, blue: 0.549)  // #F7228C

    static let gradient = LinearGradient(
        colors: [orange, pink, pinkShock, blue],
        startPoint: .topLeading, endPoint: .bottomTrailing
    )
}

// Apply to streaming text:
Text(streamingText)
    .foregroundStyle(AIColors.gradient)
```

## Per-block streaming UI

While AI is filling a block:

1. Click "Polish" → set `streamingText = ""`
2. While `streamingText` is empty, show shimmer over old content (`aiShimmer()` modifier)
3. When first partial arrives, switch to streaming text in AI gradient
4. When done, set `block.content = streamingText`, then `streamingText = nil`

```swift
@ViewBuilder
private func streamingOverlay(_ stream: String) -> some View {
    if stream.isEmpty {
        Text(block.content.isEmpty ? "Generating…" : block.content)
            .foregroundStyle(.secondary)
            .aiShimmer(active: true)
    } else {
        Text(stream)
            .foregroundStyle(AIColors.gradient)
    }
}
```

`AIShimmer` is a `ViewModifier` with a moving `LinearGradient` overlay using `.blendMode(.plusLighter)` and `.mask(content)`.

## Error handling

```swift
do {
    try await ai.draftStreaming(...)
} catch is CancellationError {
    // user stopped — silent
} catch {
    errorText = error.localizedDescription
    Task { @MainActor in
        try? await Task.sleep(for: .seconds(3))
        errorText = nil
    }
}
```

Common errors:
- `Apple Intelligence not enabled` — show notice with "Open System Settings" link
- `Model not ready` — model is downloading, wait a few minutes
- `Device not eligible` — Intel Mac, no fallback (other than asking user to use Apple Silicon)

## Anti-patterns

- ❌ Polling `availability` in a loop — call `refresh()` once per session, optionally on app focus
- ❌ Creating a fresh `LanguageModelSession` for every call when you want context — persist it
- ❌ Using `.respond(to:)` (non-streaming) for long generations — user sees no progress
- ❌ Returning empty `DraftedPromptBlocks` if the cancellation happens mid-stream — apply nothing instead, leave doc unchanged
- ❌ Ignoring `Task.isCancelled` — the stream will run to completion even if the user clicked stop
