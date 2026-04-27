# building-macos-apps

An agent skill for building native, polished macOS apps — from idea to signed and notarized DMG release. Covers the full arc: ideation, project bootstrap, **onboarding (this is the important part)**, feature implementation, Apple Intelligence integration, Liquid Glass polish, terminal hand-off, and GitHub Actions release pipeline.

Optimized for **macOS 26+ (Tahoe)** on Apple Silicon. SwiftUI-first. Biased toward apps that feel like Apple shipped them, not assembled them.

## Install

```bash
npx skills add igorfelipeduca/building-macos-apps-skill
```

Works in **20+ agents** via [Vercel Skills](https://vercel.com/changelog/introducing-skills-the-open-agent-skills-ecosystem) — Claude Code, Cursor, Codex, Windsurf, Gemini CLI, GitHub Copilot, goose, opencode, amp, antigravity, clawdbot, droid, kilo, kiro-cli, roo, trae, and others. The CLI detects which agents you have installed and wires this skill into each automatically.

<details>
<summary>Manual install (no Vercel Skills CLI)</summary>

```bash
git clone https://github.com/igorfelipeduca/building-macos-apps-skill.git \
  ~/.claude/skills/building-macos-apps        # Claude Code

git clone https://github.com/igorfelipeduca/building-macos-apps-skill.git \
  ~/.agents/skills/building-macos-apps        # generic .agents loader
```

The `SKILL.md` is self-contained and uses standard YAML frontmatter (`name`, `description`, `metadata`) so any agent that consumes that format picks it up without modification.

</details>

## What this skill teaches

- **Phase 1 — Ideation.** A 9-question scope frame to lock down the product before writing code. Audience, v1 cuts, persistence model, ship target, native bias.
- **Phase 2 — Project bootstrap.** Day-one Xcode 26 setup: deployment target, sandbox decision, entitlements file, Info.plist keys, window state.
- **Phase 3 — Onboarding.** *(The most important phase.)* 3–5 page sheet, manual paging, page-dot indicator, social/credit CTA on the last page. Persisted via `@AppStorage`. With drop-in `OnboardingView` template.
- **Phase 4 — Build features incrementally.** Spec → model → view → state → wire → run → polish → verify. The pattern that prevents 600-line view files.
- **Phase 5 — Apple Intelligence.** `FoundationModels` setup, `@Generable` structured output, streaming via `streamResponse(...)`, conversation context across turns, targeted edits, cancellable generation, the AI gradient.
- **Phase 6 — Polish.** Liquid Glass surfaces, pointer cursors, iMessage-style spring animations, symbol effects, optical alignment.
- **Phase 7 — Terminal hand-off.** `.command` file path for Terminal/iTerm/Hyper. AppleScript paste-return for Warp/Ghostty/kitty/Alacritty/WezTerm. Handles the Apple Events / Accessibility permission dance under hardened runtime.
- **Phase 8 — Release pipeline.** Developer ID cert flow, GitHub Actions secrets, signed + notarized DMG via `notarytool`, `create-dmg`, and `softprops/action-gh-release`.
- **Phase 9 — Public release readiness audit.** What's actually private (`.p12`, app-specific passwords) versus what's public-by-default (Apple Team ID, bundle ID).

## When to use this skill

Invoke this skill when the user:

- wants to **start a new macOS app** from scratch
- is shipping **a new feature** in an existing macOS app
- needs **onboarding** designed and built
- wants to **integrate Apple Intelligence** (`FoundationModels`)
- needs **terminal hand-off** to spawn a CLI session with content preloaded
- is setting up **GitHub Actions for signed/notarized DMG releases**
- mentions phrases like *"feels like generic AI slop"*, *"first launch UX is bad"*, *"I want to ship a Mac app"*, *"native vs Electron"*, or shares a `.app`/`.dmg`/`.xcodeproj` link

## When NOT to use this skill

- iOS-only or iPadOS-only apps (this is biased to macOS)
- Mac Catalyst apps (different sandboxing model)
- Apps targeting macOS 14 or earlier (most patterns here use macOS 26+ APIs — Liquid Glass, Foundation Models, `pointerStyle`)
- Pure command-line tools / daemons (no GUI)

## Structure

```
building-macos-apps/
├── SKILL.md                          # entry point: 9-phase flow with iron rules
├── README.md                         # this file
└── resources/
    ├── ideation-checklist.md         # Phase 1: 9-question scope frame
    ├── onboarding-patterns.md        # Phase 3: full template with native widgets
    ├── feature-implementation-flow.md # Phase 4: spec → ship pattern
    ├── apple-intelligence-integration.md  # Phase 5: FoundationModels deep dive
    ├── liquid-glass-and-design.md    # Phase 6: visual polish pass
    ├── terminal-handoff.md           # Phase 7: per-terminal launch + permissions
    ├── github-release-workflow.md    # Phase 8: signed DMG release pipeline
    └── snippets/                     # drop-in code
        ├── Onboarding.swift          # 4-page onboarding scaffold
        ├── PromptAI.swift            # @Generable + streaming Apple Intelligence
        ├── AIColors.swift            # AI gradient + shimmer + .clickable()
        ├── App.entitlements          # automation.apple-events for terminal handoff
        └── release.yml               # GitHub Actions release workflow template
```

## Why this skill exists

Most "AI builds you a Mac app" sessions produce something that compiles but doesn't feel native. Generic system-symbol icons. No onboarding (or a TabView page-style sheet that's iOS-only). Hardcoded hex colors. No pointer cursors. AI features that lock up because there's no stop button. Releases that fail Gatekeeper because nobody set the right entitlements.

This skill is the codified version of building [Prompty](https://github.com/igorfelipeduca/Prompty) — a real app shipped through every phase here, with the mistakes fixed in place.

## Built by

[@ducaswtf](https://x.com/ducaswtf) — derived from real shipping experience on macOS 26 / Apple Silicon.

Companion skill: [apple-expo-crash](https://github.com/igorfelipeduca/apple-expo-crash-skill) for diagnosing Expo / React Native iOS crashes that only repro on device.

## License

MIT
