# Onboarding patterns

**Onboarding is the most important UX surface in your app.** Most users will only see this flow once, but it sets the entire tone. A native-feeling 4-page sheet says "this app respects you." A skipped onboarding says "I didn't think about you."

## When to invoke this skill

- Building a new macOS app, before shipping v1
- Adding onboarding to an existing app where it's missing
- The user says "this app needs to feel native" or "first-time UX is bad"
- A feature ships that fundamentally changes the app experience (deserves a re-onboard for existing users)

## The shape

```
WindowGroup
  └─ ContentView
       ├─ NavigationSplitView { sidebar } detail: { ... }
       └─ .sheet(isPresented: $showOnboarding) {
              OnboardingView(onFinish: { hasOnboarded = true })
                  .interactiveDismissDisabled(true)
          }
```

State:
```swift
@AppStorage("hasOnboarded") private var hasOnboarded: Bool = false
@State private var showOnboarding: Bool = false

.task {
    if !hasOnboarded { showOnboarding = true }
}
```

`@AppStorage` (not `@State`) — the value must persist across launches.

## Page count and structure

3–5 pages, never more. The canonical 4-page flow:

| # | Purpose | What's on it |
|---|---|---|
| 1 | **Welcome** | Hero icon (the app's own AppLogo, NOT a system symbol), product title, one-line tagline, 2–3 bullet feature highlights |
| 2 | **How it works** | Visualization of the core loop or structure (e.g. 10-block list, 3-step flow, before/after) |
| 3 | **Key feature** | Pitch the one thing your app does that others don't (in Prompty: Apple Intelligence) — show its actual gradient/branding |
| 4 | **Social/credit** | "Made by @<handle>" + Follow button to X/social, optional support links |

Last page is **always** social. Most users see this once. Don't waste it.

## Native macOS widget rules

1. **Manual paging, not `TabView(.page)`** — `TabView(.page)` is iOS-only on macOS. Use `@State page: Int` and a `Group { switch page { ... } }`.
2. **Footer with three regions**: left = Skip, center = page dots, right = Back / Continue / Get Started.
3. **Page dots** = `Circle().fill(idx == page ? .accentColor : .gray.opacity(0.3)).frame(width: 7, height: 7)` — never use the iOS dot indicator.
4. **`.keyboardShortcut(.defaultAction)` on Continue** so ⏎ advances. **`.keyboardShortcut(.cancelAction)`** is implicit on Skip.
5. **`.interactiveDismissDisabled(true)`** so users can't ⌘W out half-way through.
6. **Fixed window size**: `.frame(width: 640, height: 540)` — onboarding is a known-shape thing, not resizable chaos.

## Code template

```swift
struct OnboardingView: View {
    let onFinish: () -> Void
    @State private var page: Int = 0
    private let pageCount = 4

    var body: some View {
        VStack(spacing: 0) {
            content.frame(maxWidth: .infinity, maxHeight: .infinity).padding(.horizontal, 48).padding(.top, 56)
            footer.padding(.horizontal, 24).padding(.vertical, 16)
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
                .buttonStyle(.plain).foregroundStyle(.secondary)
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
                Button("Back") { withAnimation(.snappy) { page -= 1 } }
            }
            if page < pageCount - 1 {
                Button("Continue") { withAnimation(.snappy) { page += 1 } }
                    .keyboardShortcut(.defaultAction).buttonStyle(.borderedProminent)
            } else {
                Button("Get Started") { onFinish() }
                    .keyboardShortcut(.defaultAction).buttonStyle(.borderedProminent)
            }
        }
    }
}
```

## Per-page content patterns

### Welcome page

```swift
private struct WelcomePage: View {
    var body: some View {
        VStack(spacing: 22) {
            // Hero icon = the app's actual AppLogo image, not SF Symbol
            Image("AppLogo")
                .resizable()
                .interpolation(.none)  // pixel art? keep it crisp
                .aspectRatio(contentMode: .fit)
                .frame(width: 120, height: 120)
                .background(.background.secondary, in: RoundedRectangle(cornerRadius: 24))

            VStack(spacing: 10) {
                Text("Welcome to <App>").font(.largeTitle.weight(.semibold))
                Text("<one-line tagline>")
                    .font(.title3).foregroundStyle(.secondary)
                    .multilineTextAlignment(.center)
            }

            VStack(alignment: .leading, spacing: 10) {
                bullet("rectangle.stack", "<feature>")
                bullet("checklist", "<feature>")
                bullet("sparkles", "<feature>")
            }
            Spacer()
        }
    }

    private func bullet(_ symbol: String, _ text: String) -> some View {
        HStack(spacing: 12) {
            Image(systemName: symbol).font(.system(size: 14, weight: .medium)).foregroundStyle(Color.accentColor).frame(width: 22)
            Text(text).font(.body)
        }
    }
}
```

### Social page

The CTA button uses **Color.black + 𝕏** glyph for X, **github** SF Symbol for GitHub, etc. Always include the handle in the visible button text.

```swift
ZStack(alignment: .bottomTrailing) {
    Image("TwitterPFP")        // user's actual pfp downloaded into asset catalog
        .resizable().aspectRatio(contentMode: .fill)
        .frame(width: 96, height: 96)
        .clipShape(Circle())
        .overlay(Circle().strokeBorder(Color.gray.opacity(0.18), lineWidth: 1))
    ZStack {
        Circle().fill(Color.black).frame(width: 32, height: 32)
            .overlay(Circle().strokeBorder(Color.white, lineWidth: 2))
        Text("𝕏").font(.system(size: 14, weight: .bold)).foregroundStyle(.white)
    }
    .offset(x: 4, y: 4)
}
```

Click action:
```swift
if let url = URL(string: "https://x.com/<handle>") {
    NSWorkspace.shared.open(url)
}
```

## Sidebar / re-entry after onboarding

Always provide a way back into the social/credit:
- Bottom of sidebar: "Made by @<handle>" line, clickable, opens X
- Help menu: "Show Welcome…" command that re-fires `showOnboarding = true`

## Anti-patterns

- ❌ Using `Image(systemName:)` instead of the actual app icon for hero — generic AI vibe
- ❌ "5+" pages — users skip
- ❌ Asking for email / sign-up on page 1 — kills momentum
- ❌ Animating the AI feature explanation (page 3) with auto-play video — distracting on macOS, just show a static gradient mock
- ❌ Forgetting to clear the sheet on `onFinish()` — leads to phantom dismissals
- ❌ `.sheet` without `.interactiveDismissDisabled(true)` — half-way escapes leave the app in a weird state

## Verification

After implementation:

1. Reset state: `defaults delete <bundle.id> hasOnboarded`
2. Relaunch the app
3. Verify the sheet appears centered, all 4 pages render, Skip works on every page except last, Back works after page 1, Get Started closes the sheet, sheet does not reopen on second launch.
