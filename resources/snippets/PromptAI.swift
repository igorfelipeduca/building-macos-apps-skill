import Foundation
import Observation
import FoundationModels

/// Reusable Apple Intelligence service. Adapt the @Generable struct and instructions for your app.
///
/// Drop-in usage:
///
///     @State private var ai = AppleIntelligence()
///     // ...
///     .environment(ai)
///     .task { ai.refresh() }
///
@Generable
struct DraftedContent {
    @Guide(description: "Your output field 1, 2-5 sentences")
    var field1: String

    @Guide(description: "Your output field 2, ...")
    var field2: String
}

@MainActor
@Observable
final class AppleIntelligence {
    enum Availability: Equatable {
        case checking
        case available
        case unavailable(String)
    }

    private(set) var availability: Availability = .checking
    var streamedContent: DraftedContent.PartiallyGenerated?
    private var session: LanguageModelSession?

    var isAvailable: Bool {
        if case .available = availability { return true }
        return false
    }

    var unavailableReason: String? {
        if case .unavailable(let reason) = availability { return reason }
        return nil
    }

    static let largeOptions = GenerationOptions(temperature: 0.7, maximumResponseTokens: 4096)
    static let polishOptions = GenerationOptions(temperature: 0.5, maximumResponseTokens: 2048)

    private var systemInstructions: String { """
        You are <role specific to your app>.

        Be substantive and detailed. Aim for 4–8 sentences per text field, never one-liners.
        Pack in concrete specifics: file paths, exact tool names, expected formats, edge cases.
        Match the no-fluff tone of senior engineers.
        """ }

    init() { refresh() }

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

    private func sharedSession() -> LanguageModelSession {
        if let session { return session }
        let s = LanguageModelSession(instructions: systemInstructions)
        session = s
        return s
    }

    func resetSession() {
        session = nil
        streamedContent = nil
    }

    /// Streaming generation. Stop by cancelling the calling Task.
    func generateStreaming(prompt: String) async throws -> DraftedContent {
        streamedContent = nil
        let session = sharedSession()

        let stream = session.streamResponse(
            to: prompt,
            generating: DraftedContent.self,
            options: Self.largeOptions
        )

        do {
            var last: DraftedContent.PartiallyGenerated?
            for try await snapshot in stream {
                if Task.isCancelled {
                    throw CancellationError()
                }
                let partial = snapshot.content
                streamedContent = partial
                last = partial
            }
            return DraftedContent(
                field1: last?.field1 ?? "",
                field2: last?.field2 ?? ""
            )
        } catch {
            throw error
        }
    }

    /// Non-streaming polish — for short rewrites of an existing string.
    func polishStreaming(
        content: String,
        onPartial: @escaping @MainActor (String) -> Void
    ) async throws -> String {
        let session = LanguageModelSession(instructions: """
            You polish text for clarity and concision. Keep the user's intent. \
            Tighten language. Output ONLY the polished text. No preamble.
            """)
        let stream = session.streamResponse(
            to: """
            Current content:
            \(content)

            Polished version:
            """,
            options: Self.polishOptions
        )

        var last = ""
        for try await snapshot in stream {
            if Task.isCancelled { throw CancellationError() }
            let text = snapshot.content
            onPartial(text)
            last = text
        }
        return last.trimmingCharacters(in: .whitespacesAndNewlines)
    }
}
