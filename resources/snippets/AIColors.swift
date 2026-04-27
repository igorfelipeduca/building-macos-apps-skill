import SwiftUI

/// Apple Intelligence color palette + helpers.
///
/// Apply gradients to streaming text:
///
///     Text(streamingText).foregroundStyle(AIColors.gradient)
///
/// Or use the animated sweep on accent borders / titles:
///
///     Text(blockTitle).foregroundStyle(AIColors.sweepingGradient(phase: phase))
///         .onAppear {
///             withAnimation(.linear(duration: 2.4).repeatForever(autoreverses: false)) {
///                 phase = 2
///             }
///         }
///
enum AIColors {
    static let orange    = Color(red: 1.000, green: 0.569, blue: 0.145)  // #FF9125
    static let blue      = Color(red: 0.404, green: 0.753, blue: 0.945)  // #67C0F1
    static let pink      = Color(red: 0.804, green: 0.431, blue: 0.765)  // #CD6EC3
    static let pinkShock = Color(red: 0.969, green: 0.133, blue: 0.549)  // #F7228C

    static let gradient = LinearGradient(
        colors: [orange, pink, pinkShock, blue],
        startPoint: .topLeading,
        endPoint: .bottomTrailing
    )

    /// Animated gradient that sweeps colors based on `phase` (0…1+).
    static func sweepingGradient(phase: Double) -> LinearGradient {
        let stops: [Gradient.Stop] = [
            .init(color: orange,    location: 0.00),
            .init(color: pink,      location: 0.33),
            .init(color: pinkShock, location: 0.66),
            .init(color: blue,      location: 1.00),
        ]
        return LinearGradient(
            stops: stops,
            startPoint: UnitPoint(x: phase - 1.0, y: 0.5),
            endPoint:   UnitPoint(x: phase + 0.0, y: 0.5)
        )
    }
}

/// Shimmer overlay — apply to text waiting on AI to start streaming.
struct AIShimmer: ViewModifier {
    @State private var phase: Double = -1.0
    let active: Bool

    func body(content: Content) -> some View {
        content.overlay {
            if active {
                LinearGradient(
                    colors: [.clear, .white.opacity(0.6), .clear],
                    startPoint: UnitPoint(x: phase - 0.3, y: 0.5),
                    endPoint:   UnitPoint(x: phase + 0.3, y: 0.5)
                )
                .blendMode(.plusLighter)
                .mask(content)
                .allowsHitTesting(false)
                .onAppear {
                    withAnimation(.linear(duration: 1.4).repeatForever(autoreverses: false)) {
                        phase = 2.0
                    }
                }
            }
        }
    }
}

extension View {
    func aiShimmer(active: Bool = true) -> some View {
        modifier(AIShimmer(active: active))
    }

    /// Pointing-hand cursor on hover — apply to every clickable element.
    func clickable() -> some View {
        self.pointerStyle(.link)
    }
}
