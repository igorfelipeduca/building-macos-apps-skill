import SwiftUI

/// Drop-in onboarding scaffold. 4 pages: Welcome, How It Works, Key Feature, Social.
/// Wire from your root view:
///
///     @AppStorage("hasOnboarded") private var hasOnboarded = false
///     @State private var showOnboarding = false
///
///     ContentView()
///         .sheet(isPresented: $showOnboarding) {
///             OnboardingView { hasOnboarded = true; showOnboarding = false }
///                 .interactiveDismissDisabled(true)
///         }
///         .task { if !hasOnboarded { showOnboarding = true } }
///
struct OnboardingView: View {
    let onFinish: () -> Void
    @State private var page: Int = 0
    private let pageCount = 4

    var body: some View {
        VStack(spacing: 0) {
            content
                .frame(maxWidth: .infinity, maxHeight: .infinity)
                .padding(.horizontal, 48)
                .padding(.top, 56)
            footer
                .padding(.horizontal, 24)
                .padding(.vertical, 16)
        }
        .frame(width: 640, height: 540)
    }

    @ViewBuilder
    private var content: some View {
        switch page {
        case 0: WelcomePage()
        case 1: HowItWorksPage()
        case 2: KeyFeaturePage()
        default: SocialPage()
        }
    }

    private var footer: some View {
        HStack(spacing: 12) {
            Button("Skip") { onFinish() }
                .buttonStyle(.plain)
                .foregroundStyle(.secondary)
                .opacity(page == pageCount - 1 ? 0 : 1)

            Spacer()

            HStack(spacing: 6) {
                ForEach(0..<pageCount, id: \.self) { idx in
                    Circle()
                        .fill(idx == page ? Color.accentColor : Color.gray.opacity(0.3))
                        .frame(width: 7, height: 7)
                        .animation(.snappy(duration: 0.18), value: page)
                }
            }

            Spacer()

            if page > 0 {
                Button("Back") {
                    withAnimation(.snappy(duration: 0.2)) { page -= 1 }
                }
            }

            if page < pageCount - 1 {
                Button("Continue") {
                    withAnimation(.snappy(duration: 0.2)) { page += 1 }
                }
                .keyboardShortcut(.defaultAction)
                .buttonStyle(.borderedProminent)
            } else {
                Button("Get Started") { onFinish() }
                    .keyboardShortcut(.defaultAction)
                    .buttonStyle(.borderedProminent)
            }
        }
    }
}

// MARK: - Pages

private struct WelcomePage: View {
    var body: some View {
        VStack(spacing: 22) {
            Image("AppLogo")               // your asset catalog logo
                .resizable()
                .interpolation(.none)      // pixel art? keep it crisp
                .aspectRatio(contentMode: .fit)
                .frame(width: 120, height: 120)
                .background(.background.secondary, in: RoundedRectangle(cornerRadius: 24))

            VStack(spacing: 10) {
                Text("Welcome to <App>")
                    .font(.largeTitle.weight(.semibold))
                Text("<one-line tagline>")
                    .font(.title3)
                    .foregroundStyle(.secondary)
                    .multilineTextAlignment(.center)
            }

            VStack(alignment: .leading, spacing: 10) {
                bullet("rectangle.stack", "<feature 1>")
                bullet("checklist", "<feature 2>")
                bullet("sparkles", "<feature 3>")
            }
            .padding(.top, 6)

            Spacer()
        }
        .frame(maxWidth: .infinity)
    }

    private func bullet(_ symbol: String, _ text: String) -> some View {
        HStack(spacing: 12) {
            Image(systemName: symbol)
                .font(.system(size: 14, weight: .medium))
                .foregroundStyle(Color.accentColor)
                .frame(width: 22)
            Text(text)
                .font(.body)
        }
    }
}

private struct HowItWorksPage: View {
    var body: some View {
        VStack(alignment: .leading, spacing: 18) {
            VStack(alignment: .leading, spacing: 6) {
                Text("How it works")
                    .font(.title.weight(.semibold))
                Text("<one-line summary>")
                    .font(.title3)
                    .foregroundStyle(.secondary)
            }

            // Replace with your own visualization (steps, block list, before/after, etc.)
            ForEach(["Step 1", "Step 2", "Step 3"], id: \.self) { step in
                HStack {
                    Image(systemName: "circle.fill")
                        .font(.system(size: 8))
                        .foregroundStyle(Color.accentColor)
                    Text(step).font(.body)
                }
            }

            Spacer()
        }
    }
}

private struct KeyFeaturePage: View {
    var body: some View {
        VStack(alignment: .leading, spacing: 18) {
            HStack(spacing: 12) {
                Image(systemName: "sparkles")
                    .font(.system(size: 22))
                    .foregroundStyle(
                        LinearGradient(
                            colors: [.purple, .pink, .orange],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        )
                    )
                Text("<key feature>")
                    .font(.title.weight(.semibold))
            }

            Text("<2–3 sentences explaining the killer feature, in plain language>")
                .font(.body)
                .foregroundStyle(.secondary)
                .lineSpacing(2)

            Spacer()
        }
    }
}

private struct SocialPage: View {
    @State private var didFollow = false

    var body: some View {
        VStack(spacing: 22) {
            ZStack(alignment: .bottomTrailing) {
                Image("TwitterPFP")        // your actual profile pic in asset catalog
                    .resizable()
                    .aspectRatio(contentMode: .fill)
                    .frame(width: 96, height: 96)
                    .clipShape(Circle())
                    .overlay(
                        Circle().strokeBorder(Color.gray.opacity(0.18), lineWidth: 1)
                    )
                ZStack {
                    Circle()
                        .fill(Color.black)
                        .frame(width: 32, height: 32)
                        .overlay(Circle().strokeBorder(Color.white, lineWidth: 2))
                    Text("𝕏")
                        .font(.system(size: 14, weight: .bold))
                        .foregroundStyle(.white)
                }
                .offset(x: 4, y: 4)
            }

            VStack(spacing: 8) {
                Text("Built by @<handle>")
                    .font(.title.weight(.semibold))
                Text("Follow for more tools, prompts, and updates.")
                    .font(.body)
                    .foregroundStyle(.secondary)
                    .multilineTextAlignment(.center)
                    .frame(maxWidth: 420)
            }

            Button {
                if let url = URL(string: "https://x.com/<handle>") {
                    NSWorkspace.shared.open(url)
                    didFollow = true
                }
            } label: {
                HStack(spacing: 10) {
                    Text("𝕏")
                        .font(.system(size: 16, weight: .bold))
                    Text(didFollow ? "Opened in browser" : "Follow @<handle> on X")
                        .font(.headline)
                }
                .frame(width: 280, height: 44)
                .foregroundStyle(.white)
                .background(Color.black, in: RoundedRectangle(cornerRadius: 10))
            }
            .buttonStyle(.plain)

            Spacer()
        }
    }
}
