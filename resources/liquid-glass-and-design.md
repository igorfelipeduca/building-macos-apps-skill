# Liquid Glass and design polish

How to make your app feel like Apple shipped it, not like you assembled it.

## Liquid Glass

Available in macOS 26+ via `.glassEffect(...)`.

### Floating buttons (the main use case)

```swift
HStack(spacing: 10) {
    Image("AppleIntelligenceIcon").resizable().frame(width: 22, height: 22)
    Text("Build with AI").font(.callout.weight(.semibold))
}
.padding(.horizontal, 18).frame(height: 48)
.glassEffect(.regular.tint(Color.accentColor.opacity(0.18)).interactive(), in: Capsule())
.contentShape(Capsule())   // CRITICAL: makes whole capsule clickable, not just text
.shadow(color: .black.opacity(0.22), radius: 18, x: 0, y: 8)
.shadow(color: Color.accentColor.opacity(0.25), radius: 22, x: 0, y: 0)  // accent glow
```

Two shadows = depth + accent glow. The `.tint(...)` on the glass takes the accent at low opacity. `.interactive()` adds tactile press response.

### Glass panels (slide-out side panels)

```swift
.glassEffect(.regular, in: RoundedRectangle(cornerRadius: 24))
.overlay(RoundedRectangle(cornerRadius: 24).strokeBorder(Color.gray.opacity(0.18), lineWidth: 1))
.shadow(color: .black.opacity(0.22), radius: 32, x: 0, y: 12)
```

### Pitfalls

- `.glassEffect(...)` is macOS 26+ only. Wrap in `if #available(macOS 26.0, *)` if your deployment target is older — but most apps using this skill should just bump deployment.
- Don't combine `.glassEffect` with `.background(.regularMaterial)` — pick one.
- Glass on tiny elements (< 32pt) reads as smudge. Use solid fills for icons, glass for surfaces.

## Pointer cursor on every clickable thing

```swift
extension View {
    /// Show a pointing-hand cursor on hover.
    func clickable() -> some View {
        self.pointerStyle(.link)
    }
}
```

Apply via `.clickable()` on every Button, link, card, hover area. macOS apps that don't change the cursor on click targets feel un-Mac.

For toolbar buttons, also add `.clickable()` — even if the toolbar buttons usually show a cursor, `pointerStyle(.link)` ensures consistency.

## Spring animations (iMessage-style)

```swift
ForEach(messages) { msg in
    messageView(msg)
        .transition(.asymmetric(
            insertion: .scale(scale: 0.7, anchor: msg.role == .user ? .bottomTrailing : .bottomLeading)
                .combined(with: .offset(y: 24))
                .combined(with: .opacity),
            removal: .scale(scale: 0.9).combined(with: .opacity)
        ))
}
.animation(.spring(response: 0.42, dampingFraction: 0.68), value: messages.count)
```

`dampingFraction: 0.68` gives a tiny overshoot — bouncy without being silly. Anchor scale to the message's origin corner (right for user, left for assistant) so the message feels like it's emerging from the side it sits on.

## Symbol effects

```swift
Image(systemName: isLoading ? "stop.fill" : "arrow.up")
    .contentTransition(.symbolEffect(.replace))
```

`.symbolEffect(.replace)` morphs symbols smoothly when their name changes. Standard for state toggles.

## Color and accent

Always use `Color.accentColor` from the asset catalog — never hex literals scattered through code:

```
Assets.xcassets/AccentColor.colorset/Contents.json
```

```json
{
  "colors": [{
    "color": {
      "color-space": "srgb",
      "components": { "alpha": "1.000", "blue": "0.604", "green": "0.690", "red": "0.616" }
    },
    "idiom": "universal"
  }],
  "info": { "author": "xcode", "version": 1 }
}
```

For the AI gradient (or any non-accent gradient), centralize in a single `enum AIColors` (or `BrandColors`) so you can refactor in one place.

## Typography

- Hero titles: `Inter Bold 48-80` (or `.system(.largeTitle, design: .default).weight(.semibold)`)
- Section headers: `28-32` semibold
- Body: `17` regular
- Caption: `13` regular, `.secondary` foreground
- Numerals in counters: `.font(.caption.monospacedDigit())` so digits don't shift width

## Tabular numbers

Always for live counters (char count, token estimate, % progress):

```swift
Text("\(charCount) chars")
    .font(.caption.monospacedDigit())
    .foregroundStyle(.secondary)
```

## Hover states on cards

```swift
struct Card: View {
    @State private var hovered = false
    var body: some View {
        VStack { ... }
            .scaleEffect(hovered ? 1.04 : 1.0)
            .background(
                .background.secondary.opacity(hovered ? 1.0 : 0.6),
                in: RoundedRectangle(cornerRadius: 12)
            )
            .overlay(RoundedRectangle(cornerRadius: 12).strokeBorder(
                hovered ? Color.accentColor.opacity(0.4) : Color.gray.opacity(0.18),
                lineWidth: 1
            ))
            .onHover { hovered = $0 }
            .animation(.snappy(duration: 0.12), value: hovered)
    }
}
```

## Optical alignment

A 22pt icon next to 17pt text often looks 1px high. Drop the icon by 1pt manually if needed:

```swift
HStack(spacing: 8) {
    Image(systemName: "sparkles").offset(y: 1)
    Text("Build with AI")
}
```

## Shadows

Light, soft, low opacity. Stack two: a tight one for elevation and a wide one for ambient.

```swift
.shadow(color: .black.opacity(0.18), radius: 14, x: 0, y: 6)   // contact
.shadow(color: Color.accentColor.opacity(0.25), radius: 22)    // ambient glow (optional)
```

Never use system `.shadow` defaults — they're too dark for macOS.

## Icons

- App icon: full-bleed for iOS-style (system applies squircle on macOS 26)
- In-app icons: SF Symbols when possible (`Image(systemName:)`)
- Custom marks (Apple Intelligence, X, Claude): SVG in asset catalog with `"preserves-vector-representation": true`
- Pixel art (like Prompty's robot): `.interpolation(.none)` to keep crisp

## Anti-patterns

- ❌ Using `.background(Color.gray)` — use `.background(.background.secondary)` so it adapts to dark mode
- ❌ Hard-coded `Color(red: ..., green: ..., blue: ...)` outside an `enum` namespace — refactor pain
- ❌ Animating across `value:` of a frequently-changing field (like `streamedText`) — every chunk re-animates everything. Animate against `count` or coarse markers.
- ❌ Drop shadow with `radius: 0` and large offset — looks fake
- ❌ Mixing `.cornerRadius(8)` and `.background(.x, in: RoundedRectangle(cornerRadius: 8))` — pick the in-shape form, more consistent
