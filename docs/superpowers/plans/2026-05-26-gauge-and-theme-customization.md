# Gauge Styles + Theme/Icon Pack Customization Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Add 4 gauge styles (Linear/Segmented/Liquid/ASCII) and 4 themed bundles (Default/Stoffee/Terminal/Retro) with overridable gauge + icon pack selectors in the settings panel.

**Architecture:** Theme drives defaults via `defaultGauge` and `defaultIconPack` properties. `@AppStorage` keys hold optional overrides (empty string = "use theme default"). `UsageRow` and `OverageRow` switch on the effective gauge style at render time. ASCII gauge is a self-contained black-bg vignette regardless of theme. Status-bar emoji reads from the effective icon pack.

**Tech Stack:** SwiftUI, `@AppStorage` for persistence, `TimelineView` for liquid wave animation, SF Symbols. No new dependencies.

**Spec:** `docs/superpowers/specs/2026-05-26-gauge-and-theme-customization-design.md`

**Testing approach:** No XCTest target exists in this project. Each task uses SwiftUI `#Preview` blocks as the visual test mechanism plus a build-and-run verification. Manual smoke tests at integration milestones.

**Build command:** `xcodebuild -project ClaudeUsage.xcodeproj -scheme ClaudeUsage -configuration Debug build` (run from repo root)

---

## Task 0: Baseline build verification

**Files:** None — verification only.

- [ ] **Step 1: Verify the project builds cleanly before any changes**

Run: `xcodebuild -project ClaudeUsage.xcodeproj -scheme ClaudeUsage -configuration Debug build 2>&1 | tail -5`
Expected: ends with `** BUILD SUCCEEDED **`

- [ ] **Step 2: Verify the working tree is clean**

Run: `git status`
Expected: `nothing to commit, working tree clean`

If unclean, stop and resolve before proceeding.

---

## Task 1: Add `GaugeStyle` enum

**Files:**
- Modify: `ClaudeUsage/UsageView.swift` — add new enum directly below `enum AppTab` (around line 9)

- [ ] **Step 1: Add the enum**

Insert this block in `ClaudeUsage/UsageView.swift` immediately after the closing `}` of `enum AppTab` (around line 9, before the `// MARK: - Theme` comment):

```swift
// MARK: - Gauge Style

enum GaugeStyle: String, CaseIterable, Identifiable {
    case linear
    case segmented
    case liquid
    case ascii

    var id: String { rawValue }

    var displayName: String {
        switch self {
        case .linear:    return "Linear"
        case .segmented: return "Segmented"
        case .liquid:    return "Liquid Fill"
        case .ascii:     return "ASCII"
        }
    }
}
```

- [ ] **Step 2: Verify the build still passes**

Run: `xcodebuild -project ClaudeUsage.xcodeproj -scheme ClaudeUsage -configuration Debug build 2>&1 | tail -3`
Expected: `** BUILD SUCCEEDED **`

- [ ] **Step 3: Commit**

```bash
git add ClaudeUsage/UsageView.swift
git commit -m "Add GaugeStyle enum with display names

Foundational type for the gauge style picker. Cases for the four
v1 gauge geometries: linear, segmented, liquid, ascii."
```

---

## Task 2: Add `IconPack` enum

**Files:**
- Modify: `ClaudeUsage/UsageView.swift` — add new enum directly below the `GaugeStyle` enum

- [ ] **Step 1: Add the enum**

Insert this block in `ClaudeUsage/UsageView.swift` immediately after the closing `}` of `enum GaugeStyle`:

```swift
// MARK: - Icon Pack

enum IconPack: String, CaseIterable, Identifiable {
    case classic    // 🟢 🟡 🔴
    case stoffee    // 🚀 🪫 💀
    case terminal   // [OK] [!] [X]
    case retro      // ♥ ⚠ ☠

    var id: String { rawValue }

    var displayName: String {
        switch self {
        case .classic:  return "Classic"
        case .stoffee:  return "Stoffee"
        case .terminal: return "Terminal"
        case .retro:    return "Retro"
        }
    }

    func statusEmoji(for maxUtil: Double) -> String {
        switch self {
        case .classic:
            if maxUtil >= 90 { return "🔴" }
            if maxUtil >= 70 { return "🟡" }
            return "🟢"
        case .stoffee:
            if maxUtil >= 90 { return "💀" }
            if maxUtil >= 70 { return "🪫" }
            return "🚀"
        case .terminal:
            if maxUtil >= 90 { return "[X]" }
            if maxUtil >= 70 { return "[!]" }
            return "[OK]"
        case .retro:
            if maxUtil >= 90 { return "☠" }
            if maxUtil >= 70 { return "⚠" }
            return "♥"
        }
    }
}
```

- [ ] **Step 2: Verify the build still passes**

Run: `xcodebuild -project ClaudeUsage.xcodeproj -scheme ClaudeUsage -configuration Debug build 2>&1 | tail -3`
Expected: `** BUILD SUCCEEDED **`

- [ ] **Step 3: Commit**

```bash
git add ClaudeUsage/UsageView.swift
git commit -m "Add IconPack enum with status emoji per pack

Four packs corresponding to v1 themes. statusEmoji(for:) returns
the threshold-appropriate symbol for each pack at <70/<90/>=90."
```

---

## Task 3: Extend `AppTheme` with terminal + retro cases

**Files:**
- Modify: `ClaudeUsage/UsageView.swift` — extend `AppTheme` enum (lines 12-123 in current code)

**Important:** Keep the `.system` case for now. It will be removed in Task 5 after migration is in place. Every `switch self` inside AppTheme must compile, so add the two new cases to every property exhaustively.

- [ ] **Step 1: Add new cases to the enum declaration**

In `enum AppTheme`, change:
```swift
enum AppTheme: String, CaseIterable {
    case standard = "Default"
    case system = "System"
    case stoffee = "Stoffee"
```

to:
```swift
enum AppTheme: String, CaseIterable {
    case standard = "Default"
    case system = "System"
    case stoffee = "Stoffee"
    case terminal = "Terminal"
    case retro = "Retro"
```

- [ ] **Step 2: Add terminal + retro to every existing switch**

For each of these properties in `AppTheme`, add the two new cases. Use these exact values:

`headerBackground`:
```swift
case .terminal: return Color(red: 0.0, green: 0.0, blue: 0.0)
case .retro:    return Color(red: 0.1, green: 0.1, blue: 0.18)
```

`cardBackground`:
```swift
case .terminal: return Color(red: 0.04, green: 0.04, blue: 0.04)
case .retro:    return Color(red: 0.13, green: 0.13, blue: 0.22)
```

`popoverBackground`:
```swift
case .terminal: return Color(red: 0.0, green: 0.0, blue: 0.0)
case .retro:    return Color(red: 0.08, green: 0.08, blue: 0.16)
```

`primaryText`:
```swift
case .terminal: return Color(red: 0.0, green: 1.0, blue: 0.0)
case .retro:    return Color.white
```

`secondaryText`:
```swift
case .terminal: return Color(red: 0.0, green: 0.7, blue: 0.0)
case .retro:    return Color(red: 0.6, green: 0.6, blue: 0.85)
```

`accent`:
```swift
case .terminal: return Color(red: 0.0, green: 1.0, blue: 0.0)
case .retro:    return Color(red: 1.0, green: 0.8, blue: 0.0)
```

`barTrack`:
```swift
case .terminal: return Color(red: 0.1, green: 0.2, blue: 0.1)
case .retro:    return Color(red: 0.2, green: 0.2, blue: 0.3)
```

`searchBackground`:
```swift
case .terminal: return Color(red: 0.05, green: 0.1, blue: 0.05)
case .retro:    return Color(red: 0.15, green: 0.15, blue: 0.25)
```

`colorForPercentage(_:)`:
```swift
case .terminal:
    if pct >= 90 { return Color(red: 1.0, green: 0.2, blue: 0.0) }   // red-orange terminal
    if pct >= 70 { return Color(red: 1.0, green: 1.0, blue: 0.0) }   // yellow terminal
    return Color(red: 0.0, green: 1.0, blue: 0.0)                     // green terminal
case .retro:
    if pct >= 90 { return Color(red: 1.0, green: 0.0, blue: 0.27) }   // arcade red
    if pct >= 70 { return Color(red: 1.0, green: 0.8, blue: 0.0) }    // arcade yellow
    return Color(red: 0.35, green: 0.8, blue: 0.4)                    // arcade green
```

`overageColor(_:)`:
```swift
case .terminal:
    if pct >= 90 { return Color(red: 1.0, green: 0.2, blue: 0.0) }
    if pct >= 70 { return Color(red: 1.0, green: 1.0, blue: 0.0) }
    return Color(red: 0.0, green: 0.9, blue: 0.9)   // cyan
case .retro:
    if pct >= 90 { return Color(red: 1.0, green: 0.0, blue: 0.27) }
    if pct >= 70 { return Color(red: 1.0, green: 0.8, blue: 0.0) }
    return Color(red: 0.4, green: 0.7, blue: 1.0)   // arcade blue
```

`statusEmoji(for maxUtil: Double)`:
```swift
case .terminal:
    if maxUtil >= 90 { return "[X]" }
    if maxUtil >= 70 { return "[!]" }
    return "[OK]"
case .retro:
    if maxUtil >= 90 { return "☠" }
    if maxUtil >= 70 { return "⚠" }
    return "♥"
```

`themeIcon`:
```swift
case .terminal: return "terminal"
case .retro:    return "gamecontroller"
```

- [ ] **Step 3: Add `defaultGauge` and `defaultIconPack` properties**

Add these two new computed properties at the bottom of `AppTheme`, just before its closing `}`:

```swift
var defaultGauge: GaugeStyle {
    switch self {
    case .standard, .system: return .linear
    case .stoffee:           return .liquid
    case .terminal:          return .ascii
    case .retro:             return .segmented
    }
}

var defaultIconPack: IconPack {
    switch self {
    case .standard, .system: return .classic
    case .stoffee:           return .stoffee
    case .terminal:          return .terminal
    case .retro:             return .retro
    }
}
```

- [ ] **Step 4: Build and visually verify**

Run: `xcodebuild -project ClaudeUsage.xcodeproj -scheme ClaudeUsage -configuration Debug build 2>&1 | tail -3`
Expected: `** BUILD SUCCEEDED **`

Then open `ClaudeUsage.xcodeproj` in Xcode, hit ⌘R, click the menu bar icon, click the gear in settings, scroll to the theme picker menu, and switch to **Terminal**. You should see green text on black bg in the popover (existing linear bar will still render — colors only change in this task). Switch to **Retro** — should see arcade yellow accents on dark blue bg.

- [ ] **Step 5: Commit**

```bash
git add ClaudeUsage/UsageView.swift
git commit -m "Add Terminal and Retro themes with full color palettes

Terminal: black bg, green text/accent, mono-friendly contrast.
Retro: dark blue-grey bg, arcade yellow accent, red/yellow/green ramp.
Both themes selectable via existing theme picker. Linear gauge still
renders in all themes — gauge-style refactor lands in later tasks."
```

---

## Task 4: Wire status bar to `IconPack` (route through `theme.defaultIconPack`)

**Files:**
- Modify: `ClaudeUsage/ClaudeUsageApp.swift` — wherever `theme.statusEmoji(...)` is called for status-bar icon

This is a refactor with no behavior change: we replace direct AppTheme.statusEmoji calls with theme.defaultIconPack.statusEmoji. AppTheme.statusEmoji stays for now — Task 5 will not remove it because nothing else uses it once we finish this task; Task 10 will switch to AppStorage-backed effective values.

- [ ] **Step 1: Find current call sites**

Run: `grep -n "statusEmoji" ClaudeUsage/ClaudeUsageApp.swift ClaudeUsage/UsageView.swift`
Expected: at least one match in ClaudeUsageApp.swift (the menu-bar `updateStatusItem` flow) and likely none in UsageView.swift.

- [ ] **Step 2: Replace each call site**

For each `theme.statusEmoji(for: <value>)` call in `ClaudeUsage/ClaudeUsageApp.swift`, replace with:
```swift
theme.defaultIconPack.statusEmoji(for: <value>)
```

(Keep the `theme` binding however it's currently obtained — likely from reading `UserDefaults.standard.string(forKey: "appTheme")` and constructing an AppTheme.)

- [ ] **Step 3: Build and verify**

Run: `xcodebuild -project ClaudeUsage.xcodeproj -scheme ClaudeUsage -configuration Debug build 2>&1 | tail -3`
Expected: `** BUILD SUCCEEDED **`

Hit ⌘R. Status-bar emoji should look identical to before for Default and Stoffee themes (same emojis, just routed through IconPack). Switch to Terminal theme → status bar should now show `[OK]` / `[!]` / `[X]` text. Switch to Retro → status bar shows `♥` / `⚠` / `☠`.

- [ ] **Step 4: Commit**

```bash
git add ClaudeUsage/ClaudeUsageApp.swift
git commit -m "Route status-bar emoji through IconPack instead of AppTheme

No behavior change for existing themes. Terminal and Retro now show
their pack symbols ([OK], ♥, etc.) in the menu bar. Wiring will swap
to AppStorage-backed override in a later task."
```

---

## Task 5: Remove `AppTheme.system` + add one-shot migration

**Files:**
- Modify: `ClaudeUsage/UsageView.swift` — remove `.system` case + all its switch arms
- Modify: `ClaudeUsage/ClaudeUsageApp.swift` — add migration in `applicationDidFinishLaunching`

The existing fallback `AppTheme(rawValue: selectedTheme) ?? .standard` already handles unknown stored values gracefully, but we want to actively clean up the stored value so we can drop the case entirely.

- [ ] **Step 1: Add migration to AppDelegate**

In `ClaudeUsage/ClaudeUsageApp.swift`, inside `applicationDidFinishLaunching`, add this block as the FIRST line of the method (before `NSApp.setActivationPolicy(.accessory)`):

```swift
// One-shot migration: legacy "System" theme is merged into "Default" (Standard).
if UserDefaults.standard.string(forKey: "appTheme") == "System" {
    UserDefaults.standard.set("Default", forKey: "appTheme")
}
```

Note: rawValues are "Default" and "System" (the user-facing strings — they're what `@AppStorage` stores via `t.rawValue`). Verify by reading the existing enum declaration at the top of UsageView.swift.

- [ ] **Step 2: Remove the case from AppTheme**

In `ClaudeUsage/UsageView.swift`, remove the line `case system = "System"` from the `AppTheme` enum declaration.

- [ ] **Step 3: Remove `.system` from every switch arm in AppTheme**

For every property in AppTheme that previously had `case .standard, .system:` patterns, change them to just `case .standard:`. There are ~10 such places. The compiler will flag any you miss.

Also remove `.system` from `defaultGauge` and `defaultIconPack` (the two new properties from Task 3) — they currently say `case .standard, .system: return .linear` and `case .standard, .system: return .classic`. Change to just `case .standard:`.

- [ ] **Step 4: Build and verify the migration**

Run: `xcodebuild -project ClaudeUsage.xcodeproj -scheme ClaudeUsage -configuration Debug build 2>&1 | tail -3`
Expected: `** BUILD SUCCEEDED **`

Manually plant a legacy value before launch:
```bash
defaults write com.helpfully.ClaudeUsage appTheme "System"
defaults read com.helpfully.ClaudeUsage appTheme
# Expected: System
```

(Bundle identifier confirmed as `com.helpfully.ClaudeUsage` in `project.pbxproj`.)

Hit ⌘R. Then:
```bash
defaults read com.helpfully.ClaudeUsage appTheme
# Expected: Default
```

- [ ] **Step 5: Commit**

```bash
git add ClaudeUsage/UsageView.swift ClaudeUsage/ClaudeUsageApp.swift
git commit -m "Remove System theme case, migrate legacy stored value

System was visually identical to Default. AppDelegate now migrates any
stored 'System' value to 'Default' on first launch after this version.
AppTheme is now 4 cases: standard, stoffee, terminal, retro."
```

---

## Task 6: Extract `LinearGauge` view (no visual change)

**Files:**
- Modify: `ClaudeUsage/UsageView.swift` — add new `LinearGauge` struct, refactor `UsageRow` (lines ~617-693) and `OverageRow` (lines ~695-747) to use it

- [ ] **Step 1: Add the LinearGauge struct**

Insert this block in `ClaudeUsage/UsageView.swift` immediately after the `OverageRow` struct's closing `}` (around line 747):

```swift
// MARK: - Gauges

struct LinearGauge: View {
    let percentage: Int
    let color: Color
    var theme: AppTheme = .standard

    var body: some View {
        GeometryReader { geometry in
            ZStack(alignment: .leading) {
                RoundedRectangle(cornerRadius: 4)
                    .fill(theme.barTrack)
                    .frame(height: 8)

                RoundedRectangle(cornerRadius: 4)
                    .fill(color)
                    .frame(width: geometry.size.width * CGFloat(min(percentage, 100)) / 100, height: 8)
            }
        }
        .frame(height: 8)
    }
}

#Preview("LinearGauge") {
    VStack(spacing: 16) {
        LinearGauge(percentage: 0, color: .green)
        LinearGauge(percentage: 33, color: .green)
        LinearGauge(percentage: 67, color: .orange)
        LinearGauge(percentage: 95, color: .red)
        LinearGauge(percentage: 120, color: .red)   // overage clamp
    }
    .padding()
    .frame(width: 280)
}
```

- [ ] **Step 2: Replace inline progress bar in UsageRow**

In `struct UsageRow`, replace the existing progress bar block (the `GeometryReader { ... }.frame(height: 8)` chunk at lines ~647-658) with:

```swift
LinearGauge(percentage: percentage, color: color, theme: theme)
```

- [ ] **Step 3: Replace inline progress bar in OverageRow**

In `struct OverageRow`, replace the same progress bar block (lines ~730-741) with:

```swift
LinearGauge(percentage: min(percentage, 100), color: color, theme: theme)
```

- [ ] **Step 4: Build and visually verify no change**

Run: `xcodebuild -project ClaudeUsage.xcodeproj -scheme ClaudeUsage -configuration Debug build 2>&1 | tail -3`
Expected: `** BUILD SUCCEEDED **`

Hit ⌘R. App should look IDENTICAL to before this task — pure refactor.

- [ ] **Step 5: Commit**

```bash
git add ClaudeUsage/UsageView.swift
git commit -m "Extract LinearGauge view, reuse in UsageRow and OverageRow

Pure refactor — no visual change. Sets up the gauge-style switch in
later tasks. Adds a SwiftUI #Preview for visual regression."
```

---

## Task 7: Add `SegmentedGauge` view

**Files:**
- Modify: `ClaudeUsage/UsageView.swift` — add new `SegmentedGauge` struct after `LinearGauge`

- [ ] **Step 1: Add the SegmentedGauge struct**

Insert immediately after the `LinearGauge` `#Preview` block:

```swift
struct SegmentedGauge: View {
    let percentage: Int
    let color: Color
    var theme: AppTheme = .standard
    let segmentCount: Int = 10

    var filledSegments: Int {
        let clamped = max(0, min(percentage, 100))
        return Int((Double(clamped) / 100.0) * Double(segmentCount).rounded())
    }

    var body: some View {
        HStack(spacing: 2) {
            ForEach(0..<segmentCount, id: \.self) { index in
                Rectangle()
                    .fill(index < filledSegments ? color : theme.barTrack)
                    .frame(height: 10)
            }
        }
        .frame(height: 10)
    }
}

#Preview("SegmentedGauge") {
    VStack(spacing: 16) {
        SegmentedGauge(percentage: 0, color: .green)
        SegmentedGauge(percentage: 25, color: .green)
        SegmentedGauge(percentage: 67, color: .orange)
        SegmentedGauge(percentage: 100, color: .red)
    }
    .padding()
    .frame(width: 280)
    .background(Color(red: 0.13, green: 0.13, blue: 0.22))   // retro bg for context
}
```

- [ ] **Step 2: Build and verify**

Run: `xcodebuild -project ClaudeUsage.xcodeproj -scheme ClaudeUsage -configuration Debug build 2>&1 | tail -3`
Expected: `** BUILD SUCCEEDED **`

Open `UsageView.swift` in Xcode and view the `SegmentedGauge` preview canvas (Editor → Canvas, or ⌘⌥↩). Verify the 4 preview rows show 0/2 or 3/6 or 7/10 segments lit. (Math: 67% → 6.7 → rounded to 7 segments.)

- [ ] **Step 3: Commit**

```bash
git add ClaudeUsage/UsageView.swift
git commit -m "Add SegmentedGauge view (8-bit health bar style)

10 discrete segments, color first N based on percentage. Not yet
wired into UsageRow — gauge-style switch lands in a later task."
```

---

## Task 8: Add `ASCIIGauge` view

**Files:**
- Modify: `ClaudeUsage/UsageView.swift` — add new `ASCIIGauge` struct after `SegmentedGauge`

**Design note:** This gauge always renders as a black-bg vignette with green monospaced text, regardless of the surrounding theme. The card may be any theme color around it; the gauge itself is a self-contained terminal block.

- [ ] **Step 1: Add the ASCIIGauge struct**

Insert immediately after the `SegmentedGauge` `#Preview` block:

```swift
struct ASCIIGauge: View {
    let percentage: Int
    let title: String          // e.g. "SESSION"
    let barWidth: Int = 18     // characters in the inner bar

    private var asciiBar: String {
        let clamped = max(0, min(percentage, 100))
        let filled = Int((Double(clamped) / 100.0) * Double(barWidth))
        let empty = barWidth - filled
        return String(repeating: "█", count: filled) + String(repeating: "░", count: empty)
    }

    private var paddedTitle: String {
        // Pad title to 8 chars so bars align
        let upper = title.uppercased()
        if upper.count >= 8 { return String(upper.prefix(8)) }
        return upper + String(repeating: " ", count: 8 - upper.count)
    }

    var body: some View {
        Text("\(paddedTitle) [\(asciiBar)] \(percentage)%")
            .font(.system(.body, design: .monospaced))
            .foregroundColor(Color(red: 0.0, green: 1.0, blue: 0.0))
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(8)
            .background(Color.black)
            .cornerRadius(4)
    }
}

#Preview("ASCIIGauge") {
    VStack(spacing: 8) {
        ASCIIGauge(percentage: 0, title: "Session")
        ASCIIGauge(percentage: 33, title: "Weekly")
        ASCIIGauge(percentage: 67, title: "Sonnet")
        ASCIIGauge(percentage: 98, title: "Opus")
    }
    .padding()
    .frame(width: 280)
}
```

- [ ] **Step 2: Build and verify**

Run: `xcodebuild -project ClaudeUsage.xcodeproj -scheme ClaudeUsage -configuration Debug build 2>&1 | tail -3`
Expected: `** BUILD SUCCEEDED **`

Open the preview canvas. Verify 4 rows of black-bg green-text mono bars. Math check: 67% × 18 / 100 = 12.06 → 12 filled chars. 98% × 18 / 100 = 17.64 → 17 filled chars.

- [ ] **Step 3: Commit**

```bash
git add ClaudeUsage/UsageView.swift
git commit -m "Add ASCIIGauge view as self-contained terminal vignette

Always renders black bg + green mono text regardless of theme.
18-char inner bar with █/░ fill characters. Title padded to 8 chars
for column alignment across rows."
```

---

## Task 9: Add `LiquidGauge` view with animated wave

**Files:**
- Modify: `ClaudeUsage/UsageView.swift` — add new `LiquidGauge` struct after `ASCIIGauge`

**Design note:** Wave animation runs via `TimelineView(.animation)`. When the popover is not displayed, SwiftUI naturally pauses these views, so no manual battery management is needed.

- [ ] **Step 1: Add the LiquidGauge struct**

Insert immediately after the `ASCIIGauge` `#Preview` block:

```swift
struct LiquidGauge: View {
    let percentage: Int
    let color: Color
    var theme: AppTheme = .standard

    var body: some View {
        GeometryReader { geometry in
            let clamped = max(0, min(percentage, 100))
            let fillWidth = geometry.size.width * CGFloat(clamped) / 100

            ZStack(alignment: .leading) {
                // Track + outline
                RoundedRectangle(cornerRadius: 4)
                    .stroke(color, lineWidth: 1)
                    .background(
                        RoundedRectangle(cornerRadius: 4)
                            .fill(theme.barTrack.opacity(0.6))
                    )

                // Animated fill
                TimelineView(.animation) { context in
                    let t = context.date.timeIntervalSinceReferenceDate
                    let phase = CGFloat(t.truncatingRemainder(dividingBy: 2.5)) / 2.5

                    Canvas { ctx, size in
                        let fillRect = CGRect(x: 0, y: 0, width: fillWidth, height: size.height)
                        ctx.clip(to: Path(roundedRect: CGRect(x: 0, y: 0, width: size.width, height: size.height),
                                          cornerRadius: 4))
                        ctx.fill(Path(fillRect), with: .color(color.opacity(0.85)))

                        // Wave overlay
                        var wave = Path()
                        let waveHeight: CGFloat = 3
                        let waveY = size.height * 0.15
                        wave.move(to: CGPoint(x: 0, y: waveY))
                        let segments = 40
                        for i in 0...segments {
                            let x = fillRect.width * CGFloat(i) / CGFloat(segments)
                            let angle = (CGFloat(i) / CGFloat(segments) * .pi * 2) + (phase * .pi * 2)
                            let y = waveY + sin(angle) * waveHeight
                            wave.addLine(to: CGPoint(x: x, y: y))
                        }
                        wave.addLine(to: CGPoint(x: fillRect.width, y: size.height))
                        wave.addLine(to: CGPoint(x: 0, y: size.height))
                        wave.closeSubpath()
                        ctx.fill(wave, with: .color(.white.opacity(0.35)))
                    }
                    .frame(width: fillWidth)
                }
            }
        }
        .frame(height: 14)
    }
}

#Preview("LiquidGauge") {
    VStack(spacing: 16) {
        LiquidGauge(percentage: 0, color: Color(red: 1.0, green: 0.2, blue: 0.6))
        LiquidGauge(percentage: 33, color: Color(red: 0.6, green: 0.2, blue: 1.0))
        LiquidGauge(percentage: 67, color: Color(red: 1.0, green: 0.4, blue: 0.9))
        LiquidGauge(percentage: 98, color: Color(red: 1.0, green: 0.1, blue: 0.3))
    }
    .padding()
    .frame(width: 280)
    .background(Color(red: 0.12, green: 0.03, blue: 0.18))   // stoffee bg
}
```

- [ ] **Step 2: Build and verify**

Run: `xcodebuild -project ClaudeUsage.xcodeproj -scheme ClaudeUsage -configuration Debug build 2>&1 | tail -3`
Expected: `** BUILD SUCCEEDED **`

Open the preview canvas. Verify 4 rows of neon liquid bars on dark bg. The wave should visibly animate (sliding left-to-right cycle every 2.5s). If preview doesn't animate, click the "Play" arrow in the canvas controls.

- [ ] **Step 3: Commit**

```bash
git add ClaudeUsage/UsageView.swift
git commit -m "Add LiquidGauge view with animated sine wave fill

TimelineView drives a Canvas-rendered wave that scrolls every 2.5s.
Wave overlay sits at 15% from top of the fill, white at 35% opacity.
SwiftUI pauses TimelineView when the popover is closed, so no manual
battery management needed."
```

---

## Task 10: Refactor `UsageRow` + `OverageRow` to switch on `GaugeStyle`

**Files:**
- Modify: `ClaudeUsage/UsageView.swift`

At this point we still don't have AppStorage for overrides — that's Task 11. For now, each row receives a `gaugeStyle` prop and the callers pass `theme.defaultGauge`.

- [ ] **Step 1: Add `gaugeStyle` prop to UsageRow**

In `struct UsageRow`, add a new stored property below the existing ones (just below `var theme: AppTheme = .standard`):

```swift
var gaugeStyle: GaugeStyle = .linear
```

- [ ] **Step 2: Replace the LinearGauge call in UsageRow body**

In `UsageRow.body`, find the line you added in Task 6:
```swift
LinearGauge(percentage: percentage, color: color, theme: theme)
```
Replace it with this switch:

```swift
Group {
    switch gaugeStyle {
    case .linear:
        LinearGauge(percentage: percentage, color: color, theme: theme)
    case .segmented:
        SegmentedGauge(percentage: percentage, color: color, theme: theme)
    case .liquid:
        LiquidGauge(percentage: percentage, color: color, theme: theme)
    case .ascii:
        ASCIIGauge(percentage: percentage, title: title)
    }
}
```

- [ ] **Step 3: Add `gaugeStyle` prop to OverageRow**

In `struct OverageRow`, add the same prop below `var theme: AppTheme = .standard`:

```swift
var gaugeStyle: GaugeStyle = .linear
```

- [ ] **Step 4: Replace the LinearGauge call in OverageRow body**

In `OverageRow.body`, find:
```swift
LinearGauge(percentage: min(percentage, 100), color: color, theme: theme)
```
Replace with:

```swift
Group {
    switch gaugeStyle {
    case .linear:
        LinearGauge(percentage: min(percentage, 100), color: color, theme: theme)
    case .segmented:
        SegmentedGauge(percentage: min(percentage, 100), color: color, theme: theme)
    case .liquid:
        LiquidGauge(percentage: min(percentage, 100), color: color, theme: theme)
    case .ascii:
        ASCIIGauge(percentage: min(percentage, 100), title: "Overage")
    }
}
```

- [ ] **Step 5: Pass `theme.defaultGauge` from all callers**

In `UsageView.usageContent(_:)` (around lines 219-256), every `UsageRow(...)` and `OverageRow(...)` call needs `gaugeStyle:` added. For each existing call, add `gaugeStyle: theme.defaultGauge` as the last argument.

Example — change:
```swift
UsageRow(
    title: "Session",
    subtitle: "5-hour window",
    percentage: usage.sessionPercentage,
    resetsAt: usage.sessionResetsAt,
    color: theme.colorForPercentage(usage.sessionPercentage),
    theme: theme
)
```
to:
```swift
UsageRow(
    title: "Session",
    subtitle: "5-hour window",
    percentage: usage.sessionPercentage,
    resetsAt: usage.sessionResetsAt,
    color: theme.colorForPercentage(usage.sessionPercentage),
    theme: theme,
    gaugeStyle: theme.defaultGauge
)
```

Apply this to all 4 `UsageRow` calls and the 1 `OverageRow` call.

- [ ] **Step 6: Build and visually verify all 4 themes**

Run: `xcodebuild -project ClaudeUsage.xcodeproj -scheme ClaudeUsage -configuration Debug build 2>&1 | tail -3`
Expected: `** BUILD SUCCEEDED **`

Hit ⌘R. Cycle through themes via the settings gear:
- **Default** → Linear bars (white card bg)
- **Stoffee** → Liquid wave bars (pink/purple, animated)
- **Terminal** → ASCII bars (`[████░░] 67%` green on black inside the card)
- **Retro** → Segmented health bars (10 chunks, arcade yellow)

- [ ] **Step 7: Commit**

```bash
git add ClaudeUsage/UsageView.swift
git commit -m "Switch UsageRow and OverageRow on gaugeStyle prop

Each row now renders the correct gauge type based on the new
gaugeStyle parameter. Callers in usageContent pass theme.defaultGauge,
so each theme bundles its intended gauge. AppStorage-backed override
comes next."
```

---

## Task 11: Add `@AppStorage` overrides + effective computed values

**Files:**
- Modify: `ClaudeUsage/UsageView.swift` — add new AppStorage keys + effective values on the main `UsageView` struct, plus update callers

- [ ] **Step 1: Add AppStorage properties and effective values**

In `struct UsageView`, immediately below the existing line:
```swift
@AppStorage("appTheme") private var selectedTheme: String = AppTheme.standard.rawValue
private var theme: AppTheme { AppTheme(rawValue: selectedTheme) ?? .standard }
```

add these four lines:

```swift
@AppStorage("gaugeStyleOverride") private var gaugeOverride: String = ""
@AppStorage("iconPackOverride")  private var iconOverride: String = ""

private var effectiveGauge: GaugeStyle { GaugeStyle(rawValue: gaugeOverride) ?? theme.defaultGauge }
private var effectiveIconPack: IconPack { IconPack(rawValue: iconOverride) ?? theme.defaultIconPack }
```

- [ ] **Step 2: Update all UsageRow/OverageRow callers to use `effectiveGauge`**

Replace every `gaugeStyle: theme.defaultGauge` (added in Task 10) with:
```swift
gaugeStyle: effectiveGauge
```

- [ ] **Step 3: Update ClaudeUsageApp.swift status bar to read effective icon pack**

In `ClaudeUsage/ClaudeUsageApp.swift`, replace the line you set in Task 4:
```swift
theme.defaultIconPack.statusEmoji(for: <value>)
```
with logic that reads the override too. Since the status bar code doesn't have access to `@AppStorage`, read UserDefaults directly:

```swift
let iconOverride = UserDefaults.standard.string(forKey: "iconPackOverride") ?? ""
let pack = IconPack(rawValue: iconOverride) ?? theme.defaultIconPack
let emoji = pack.statusEmoji(for: maxUtil)
```

Replace `theme.defaultIconPack.statusEmoji(for: maxUtil)` accordingly. Adapt variable names to the surrounding code (`maxUtil` may be called something else).

- [ ] **Step 4: Build and verify**

Run: `xcodebuild -project ClaudeUsage.xcodeproj -scheme ClaudeUsage -configuration Debug build 2>&1 | tail -3`
Expected: `** BUILD SUCCEEDED **`

Hit ⌘R. App should still look the same as end-of-Task-10 (no UI for overrides yet). But you can manually test the override path:

```bash
defaults write com.helpfully.ClaudeUsage gaugeStyleOverride "ascii"
# (Cmd+Q the app, relaunch)
```

Now every gauge in every theme should be ASCII (black-bg vignettes inside whatever card bg the theme uses). Reset:

```bash
defaults delete com.helpfully.ClaudeUsage gaugeStyleOverride
```

- [ ] **Step 5: Commit**

```bash
git add ClaudeUsage/UsageView.swift ClaudeUsage/ClaudeUsageApp.swift
git commit -m "Add AppStorage-backed gauge and icon pack overrides

Empty-string sentinel means 'use theme default'. effectiveGauge and
effectiveIconPack resolve to override-or-default. Status bar reads
iconPackOverride directly from UserDefaults since it runs outside
the SwiftUI view tree. Settings UI for setting these lands next."
```

---

## Task 12: Settings panel — replace Menu theme picker with 4-button row

**Files:**
- Modify: `ClaudeUsage/UsageView.swift` — the theme picker block around lines 443-463

- [ ] **Step 1: Replace the Menu picker**

Find this block in the settings panel (around lines 443-463):

```swift
// Theme picker
Menu {
    ForEach(AppTheme.allCases, id: \.self) { t in
        Button(action: { selectedTheme = t.rawValue }) {
            HStack {
                Image(systemName: t.themeIcon)
                Text(t.rawValue)
                if t.rawValue == selectedTheme {
                    Image(systemName: "checkmark")
                }
            }
        }
    }
} label: {
    Image(systemName: theme.themeIcon)
        .font(.system(size: 14, weight: .bold))
        .foregroundColor(theme.accent)
}
.menuStyle(.borderlessButton)
.menuIndicator(.hidden)
.frame(width: 24)
```

Replace it entirely with this 4-button grid section. Place it inside the settings panel layout (the same VStack the old Menu was in — keep the surrounding `HStack`/`VStack` structure intact, just swap the Menu region for this picker):

```swift
VStack(alignment: .leading, spacing: 6) {
    Text("Theme")
        .font(.caption)
        .foregroundColor(theme.secondaryText)

    LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible())], spacing: 6) {
        ForEach(AppTheme.allCases, id: \.self) { t in
            Button(action: { selectedTheme = t.rawValue }) {
                HStack(spacing: 6) {
                    Image(systemName: t.themeIcon)
                    Text(t.rawValue)
                        .font(.caption)
                    Spacer()
                }
                .padding(6)
                .background(t.rawValue == selectedTheme ? theme.accent.opacity(0.25) : theme.cardBackground)
                .overlay(
                    RoundedRectangle(cornerRadius: 4)
                        .stroke(t.rawValue == selectedTheme ? theme.accent : Color.clear, lineWidth: 1)
                )
                .cornerRadius(4)
                .foregroundColor(theme.primaryText)
            }
            .buttonStyle(.plain)
        }
    }
}
.padding(.horizontal)
.padding(.bottom, 8)
```

**Note:** This picker is moving from the footer button row (where it sat as a small icon Menu) into the body of the settings panel. The footer row needs the now-removed `.frame(width: 24)` slot cleaned up — the surrounding HStack should just lose that element entirely.

- [ ] **Step 2: Build and visually verify**

Run: `xcodebuild -project ClaudeUsage.xcodeproj -scheme ClaudeUsage -configuration Debug build 2>&1 | tail -3`
Expected: `** BUILD SUCCEEDED **`

Hit ⌘R. Open settings. You should see a 2×2 grid of theme buttons (Default | Stoffee on top row, Terminal | Retro on bottom). Selected theme has a colored outline + tinted background. Clicking any button switches the theme.

- [ ] **Step 3: Commit**

```bash
git add ClaudeUsage/UsageView.swift
git commit -m "Replace Menu theme picker with 2x2 button grid

Theme picker moves from the footer icon row into the settings body
as four labeled buttons. Selected theme is visually highlighted with
accent-color outline and tinted background."
```

---

## Task 13: Settings panel — add gauge override picker with reset

**Files:**
- Modify: `ClaudeUsage/UsageView.swift` — add new picker block in settings panel

- [ ] **Step 1: Add the gauge override picker**

Immediately below the theme-picker VStack you added in Task 12 (still inside the settings panel), add:

```swift
VStack(alignment: .leading, spacing: 6) {
    Text("Gauge Style")
        .font(.caption)
        .foregroundColor(theme.secondaryText)

    HStack(spacing: 6) {
        Picker("", selection: $gaugeOverride) {
            Text("Theme default (\(theme.defaultGauge.displayName))").tag("")
            ForEach(GaugeStyle.allCases) { g in
                Text(g.displayName).tag(g.rawValue)
            }
        }
        .pickerStyle(.menu)
        .labelsHidden()

        if !gaugeOverride.isEmpty {
            Button(action: { gaugeOverride = "" }) {
                Image(systemName: "arrow.counterclockwise")
                    .foregroundColor(theme.secondaryText)
            }
            .buttonStyle(.borderless)
            .help("Reset to theme default")
        }
    }
}
.padding(.horizontal)
.padding(.bottom, 8)
```

- [ ] **Step 2: Build and visually verify the override works end-to-end**

Run: `xcodebuild -project ClaudeUsage.xcodeproj -scheme ClaudeUsage -configuration Debug build 2>&1 | tail -3`
Expected: `** BUILD SUCCEEDED **`

Hit ⌘R. Open settings. You should see "Gauge Style" with a dropdown showing "Theme default (Linear)" (assuming Default theme).

Smoke test matrix:
1. Default theme + override = "ASCII" → bars become ASCII vignettes
2. Default theme + override = "Liquid" → bars become animated waves
3. Click the `↺` button → bars revert to Linear (and the button disappears)
4. Switch to Stoffee theme with no override → bars are liquid (theme default)
5. Stoffee + override = "Segmented" → segmented bars on pink/purple bg

- [ ] **Step 3: Commit**

```bash
git add ClaudeUsage/UsageView.swift
git commit -m "Add gauge style override picker with reset button

Picker shows 'Theme default (X)' as the empty-override option, plus
each of the four gauge styles. Reset arrow appears only when an
override is active and clears it back to theme default."
```

---

## Task 14: Settings panel — add icon pack override picker with reset

**Files:**
- Modify: `ClaudeUsage/UsageView.swift` — add new picker block immediately below the gauge picker

- [ ] **Step 1: Add the icon pack picker**

Immediately below the gauge override VStack from Task 13, add:

```swift
VStack(alignment: .leading, spacing: 6) {
    Text("Icon Pack")
        .font(.caption)
        .foregroundColor(theme.secondaryText)

    HStack(spacing: 6) {
        Picker("", selection: $iconOverride) {
            Text("Theme default (\(theme.defaultIconPack.displayName))").tag("")
            ForEach(IconPack.allCases) { p in
                Text(p.displayName).tag(p.rawValue)
            }
        }
        .pickerStyle(.menu)
        .labelsHidden()

        if !iconOverride.isEmpty {
            Button(action: { iconOverride = "" }) {
                Image(systemName: "arrow.counterclockwise")
                    .foregroundColor(theme.secondaryText)
            }
            .buttonStyle(.borderless)
            .help("Reset to theme default")
        }
    }
}
.padding(.horizontal)
.padding(.bottom, 8)
```

- [ ] **Step 2: Wire popover percentage emoji to `effectiveIconPack`**

The popover currently shows status emojis from `theme.statusEmoji(for:)` in several places (look for `statusEmoji` references in UsageView.swift). Change every such call site to use `effectiveIconPack.statusEmoji(for: <value>)` instead.

Run: `grep -n "\.statusEmoji(" ClaudeUsage/UsageView.swift`
Replace each remaining `theme.statusEmoji(for: X)` with `effectiveIconPack.statusEmoji(for: X)`.

- [ ] **Step 3: Build and visually verify**

Run: `xcodebuild -project ClaudeUsage.xcodeproj -scheme ClaudeUsage -configuration Debug build 2>&1 | tail -3`
Expected: `** BUILD SUCCEEDED **`

Hit ⌘R. Smoke test:
1. Default theme, override Icon Pack = "Terminal" → status emojis in popover become `[OK]/[!]/[X]`; menu bar emoji also updates after the next refresh tick
2. Stoffee theme, no override → rockets/skulls/batteries (theme default)
3. Click `↺` on icon pack → falls back to theme default

- [ ] **Step 4: Commit**

```bash
git add ClaudeUsage/UsageView.swift
git commit -m "Add icon pack override picker; wire popover emojis through pack

Settings panel now has all three controls per the design: Theme,
Gauge Style override, Icon Pack override. Popover usage rows pull
status emojis from effectiveIconPack so overrides apply everywhere."
```

---

## Task 15: Bump version + final acceptance smoke test

**Files:**
- Modify: `ClaudeUsage.xcodeproj/project.pbxproj` — bump `MARKETING_VERSION` to `2.2.0`

- [ ] **Step 1: Bump version**

Run: `grep -n "MARKETING_VERSION = 2.1.0" ClaudeUsage.xcodeproj/project.pbxproj`
Expected: 2 matches (Debug and Release).

For each line, change `MARKETING_VERSION = 2.1.0;` to `MARKETING_VERSION = 2.2.0;`. Use Edit tool with replace_all on the exact `MARKETING_VERSION = 2.1.0;` string.

Verify: `grep -c "MARKETING_VERSION = 2.2.0" ClaudeUsage.xcodeproj/project.pbxproj`
Expected: `2`

- [ ] **Step 2: Run the full acceptance checklist from the spec**

Build + run the app. Walk through each spec acceptance criterion:

- [ ] All 4 themes (Default/Stoffee/Terminal/Retro) selectable from settings; selection persists across launches (quit and relaunch — verify theme stays)
- [ ] Switching theme instantly updates colors, gauge, and icons in popover AND menu bar
- [ ] Gauge override dropdown shows "Theme default (X)" as first option; selecting a specific gauge applies it to all rows
- [ ] Icon pack override dropdown does the same
- [ ] `↺` reset button clears each override back to theme default and disappears when override is empty
- [ ] Liquid gauge wave animates smoothly when popover is open (no frame stutter)
- [ ] ASCII gauge renders black bg + green mono text inside all theme cards (verify it looks intentional on Default white card too)
- [ ] Segmented gauge highlights N of 10 segments (manually: trigger a value, count the lit segments)
- [ ] Legacy `system` migration: `defaults write com.helpfully.ClaudeUsage appTheme "System"`, quit, relaunch, then `defaults read com.helpfully.ClaudeUsage appTheme` → `Default`
- [ ] Menu bar emoji follows the effective icon pack (e.g. Terminal pack shows `[!]` at 75%+)

- [ ] **Step 3: Commit**

```bash
git add ClaudeUsage.xcodeproj/project.pbxproj
git commit -m "Bump version to 2.2.0

Ships gauge styles (Linear/Segmented/Liquid/ASCII) and four themed
bundles (Default/Stoffee/Terminal/Retro) with optional per-control
overrides via the settings panel."
```

- [ ] **Step 4: Push when ready**

You're now multiple commits ahead of origin/main. When you're happy:

```bash
git log --oneline origin/main..HEAD
# Review the commit list
git push origin main
```

---

## Self-Review Notes

**Spec coverage check** — every spec section has a corresponding task:

| Spec section | Tasks |
|---|---|
| `GaugeStyle` enum + displayName | Task 1 |
| `IconPack` enum + displayName + statusEmoji | Task 2 |
| `AppTheme` extension (terminal, retro, defaultGauge, defaultIconPack, all color properties) | Task 3 |
| Status bar wiring to IconPack | Task 4, finalized in 11 |
| Remove `.system` + migration | Task 5 |
| LinearGauge extraction | Task 6 |
| SegmentedGauge | Task 7 |
| ASCIIGauge with always-black-bg vignette | Task 8 |
| LiquidGauge with TimelineView animation | Task 9 |
| UsageRow/OverageRow switch on gaugeStyle | Task 10 |
| `@AppStorage` keys + effective values | Task 11 |
| Settings panel: 4-button theme picker | Task 12 |
| Settings panel: gauge override dropdown + reset | Task 13 |
| Settings panel: icon pack override dropdown + reset | Task 14 |
| Version bump + acceptance checklist | Task 15 |

All 10 acceptance criteria are covered by Task 15's checklist.

**Out-of-scope items confirmed absent:** No Dial gauge, no custom color picker, no SF Symbols icon pack, no per-row gauge overrides, no animated theme transitions.
