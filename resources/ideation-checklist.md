# Ideation checklist — before any code

The single biggest cause of macOS-app sessions blowing up is the agent starting to code feature #3 from the conversation while the product itself isn't agreed. Force the user through this list, write the answers down, and reference them when scope drifts.

## 1. The pitch (one sentence)

> "Prompty composes Claude Code prompts that won't drift."

If you can't finish that sentence in 10 words, the product isn't tight enough yet. Rewrite until it is.

## 2. Audience

| Audience | Implications |
|---|---|
| Yourself + few friends | Skip App Store, sandbox optional, unsigned DMG OK |
| Indie userbase, paid | Sandbox optional, signed/notarized DMG, license key system |
| App Store distribution | Sandbox **mandatory**, no terminal hand-off, more entitlement overhead |

App Store and terminal hand-off do not coexist. Pick one.

## 3. v1 scope

List every feature the user mentioned. Cross out what's *not in v1*. Out loud.

For Prompty v1: 10-block composer, live preview, copy. Everything else (AI, hand-off, onboarding) was added across iterations *after* v1 was working.

## 4. Native bias

For each feature, ask: is there a SwiftUI / system API that gives 80% of this for free?

- "Sidebar navigation" → `NavigationSplitView`, not custom HStack
- "AI assist" → `FoundationModels`, not OpenAI SDK
- "Animated progress" → `ProgressView` + `.symbolEffect`
- "Storage" → `SwiftData @Model`, not custom JSON files
- "Preferences" → `@AppStorage`, not custom UserDefaults wrapper
- "Settings window" → `Settings { Form { ... } }`, not bespoke window

If you must roll your own, justify why in writing.

## 5. Persistence model

Pick one and commit. Don't mix three.

| Need | Pick |
|---|---|
| User-created documents | `SwiftData @Model` |
| User preferences | `@AppStorage` |
| Cached/downloaded data | `Application Support/<app>/`, plain JSON |
| Per-document large blobs | `@Attribute(.externalStorage)` on SwiftData |

## 6. Ship target

| Target | Tradeoffs |
|---|---|
| Local-only (you build, you run) | No signing, no notarization, fastest iteration |
| Public DMG via GitHub Actions | Developer ID + notarization required, ~$99/year, ~10min release time |
| Mac App Store | Sandbox required, capability review, 30% cut, slower releases |
| Setapp / 3rd-party store | Each store has its own contract |

## 7. Apple Intelligence?

Ask: "Does this app benefit from on-device generation?"

- Composing structured output (prompts, emails, code stubs)? **Yes — use it.**
- Summarization? **Yes.**
- Pure tooling, no text generation? **No, skip it.**

If yes:
- Deployment target must be macOS 26+
- App Silicon-only at runtime (gracefully handle `unavailable` on Intel)
- Up-front: read `apple-intelligence-integration.md`

## 8. Terminal hand-off?

If the app produces something the user wants to run in a terminal (a script, a CLI invocation, a Claude Code session), plan terminal hand-off into v1's UX *before* turning sandbox on.

## 9. Risks worth flagging up-front

- **Apple Intelligence model availability**: ~10s download on first use, can be unavailable for hours after enabling
- **Notarization queue**: Apple's notary service takes 2–15 min, sometimes longer in beta-OS season
- **Hardened runtime + sandbox + Apple Events**: complex three-way interaction, see `terminal-handoff.md`
- **macOS beta seasons (June–October)**: SDK + APIs change weekly, builds break

## Anti-checklist

- [ ] Don't say "let's just add X while we're here" mid-Phase-2. Park it.
- [ ] Don't promise a timeline. macOS app development is bursty.
- [ ] Don't pick App Store as the target without explicit user buy-in to the trade-offs.
- [ ] Don't skip onboarding because "it's just for me." First-launch UX is product, see `onboarding-patterns.md`.
