# Gauge Styles + Theme/Icon Pack Customization

**Date:** 2026-05-26
**Status:** Brainstorm complete, awaiting user review
**Target version:** v2.2.0

## Summary

Add user-selectable gauge styles (visual shape of the usage bars) and icon packs (status indicators), bundled into themed presets with optional per-control overrides. Ships as four new themes — Default, Stoffee, Terminal, Retro — each with a default gauge + icon pack, plus visible dropdowns to override either independently.

## Motivation

Today the app has a `standard` / `system` / `stoffee` theme picker that controls colors and a single set of status emojis. The user wants:

1. **Multiple gauge geometries** — not just linear bars (Liquid Fill, ASCII terminal, Segmented health-bar)
2. **Icon pack variety** — terminal-style `[OK]/[!]/[X]`, retro pixel `♥⚠☠`, etc.
3. **A real settings UI surface** for picking these (you literally said "a button or option")

Bundled themes give cohesion out of the box (Stoffee Neon is liquid + skulls; Terminal is ASCII + brackets); visible overrides give power without hiding anything.

## Decisions Locked In

| Question | Answer |
|---|---|
| Relationship model | **C** — theme sets defaults, optional overrides per axis |
| v1 gauges | Linear, ASCII, Segmented, Liquid Fill |
| v2/later gauges | Dial (radial) — needs more vertical space, deferred |
| v1 themes | Default, Stoffee, Terminal, Retro |
| Settings layout | **B** — gauge + icon pack overrides always visible in panel |
| Override granularity | Gauge style **and** icon pack are independently overridable |
| `AppTheme.system` case | Merge into Default; migrate stored value on first launch |

## Architecture

### Three new types in `UsageView.swift`

```swift
enum GaugeStyle: String, CaseIterable, Identifiable {
    case linear, segmented, liquid, ascii
    var id: String { rawValue }
    var displayName: String { … }   // "Linear", "Segmented", "Liquid Fill", "ASCII"
}

enum IconPack: String, CaseIterable, Identifiable {
    case classic    // 🟢 🟡 🔴
    case stoffee    // 🚀 🪫 💀
    case terminal   // [OK] [!] [X]
    case retro      // ♥ ⚠ ☠
    var id: String { rawValue }
    var displayName: String { … }

    func statusEmoji(for maxUtil: Double) -> String { … }
}

enum AppTheme: String, CaseIterable {
    case standard, stoffee, terminal, retro   // system case removed

    var defaultGauge: GaugeStyle { … }
    var defaultIconPack: IconPack { … }

    // ALL existing color properties (headerBackground, cardBackground,
    // popoverBackground, primaryText, secondaryText, accent, barTrack,
    // searchBackground, colorForPercentage, overageColor) must be
    // extended with cases for .terminal and .retro. Color choices:
    //   .terminal: bg = pure black, text = #00ff00, accent = #00ff00,
    //              percentage ramp: green → yellow → red
    //   .retro:    bg = #1a1a2e, text = #fff, accent = #ffcc00 (arcade
    //              yellow), percentage ramp: green → yellow → #ff0044
}
```

### Per-theme defaults

| Theme | Default gauge | Default icon pack | Color signature |
|---|---|---|---|
| Default | Linear | Classic 🟢🟡🔴 | Adaptive macOS controls |
| Stoffee | Liquid | Stoffee 🚀🪫💀 | Neon pink/purple |
| Terminal | ASCII | Terminal `[OK]/[!]/[X]` | Black bg, green mono |
| Retro | Segmented | Retro `♥⚠☠` | Dark blue-grey, arcade yellow/red |

### Persistence (UserDefaults via `@AppStorage`)

```swift
@AppStorage("appTheme") private var selectedTheme: String = "standard"
@AppStorage("gaugeStyleOverride") private var gaugeOverride: String = ""    // "" = use theme default
@AppStorage("iconPackOverride")  private var iconOverride: String = ""      // "" = use theme default
```

A sentinel empty string means "follow theme default." Effective values:

```swift
var effectiveGauge: GaugeStyle {
    GaugeStyle(rawValue: gaugeOverride) ?? theme.defaultGauge
}
var effectiveIconPack: IconPack {
    IconPack(rawValue: iconOverride) ?? theme.defaultIconPack
}
```

### Settings panel additions

In the settings panel (currently lines 443–456), the existing theme picker grows to 4 buttons. Below it, two new visible dropdowns appear:

```
APPEARANCE
Theme:        [⚪ Default] [✨ Stoffee] [▮ Terminal] [▰ Retro]
Gauge style:  [Linear (theme default) ▾]
Icon pack:    [Classic (theme default) ▾]
```

Dropdowns show "(theme default)" suffix when no override is set, swap to the actual name when overridden. A small `↺` reset button next to each dropdown clears the override back to theme default.

### UsageRow rendering

`UsageRow` currently renders a linear bar. Refactor:

```swift
struct UsageRow: View {
    // existing props
    var gaugeStyle: GaugeStyle   // NEW — passed in from UsageView
    var iconPack: IconPack       // NEW — for the percentage-zone emoji

    var body: some View {
        // title row stays
        Group {
            switch gaugeStyle {
            case .linear:    LinearGauge(...)
            case .segmented: SegmentedGauge(...)
            case .liquid:    LiquidGauge(...)
            case .ascii:     ASCIIGauge(...)
            }
        }
    }
}
```

Each gauge is its own small SwiftUI view (`LinearGauge`, `SegmentedGauge`, `LiquidGauge`, `ASCIIGauge`) in `UsageView.swift`. Single-responsibility, easy to swap, easy to test visually.

### Gauge implementations (high level)

**LinearGauge** — existing behavior preserved. `ProgressView` or a manual RoundedRectangle. Theme color ramp.

**SegmentedGauge** — `HStack` of 10 small `RoundedRectangle` segments. Color first N based on `pct/10` rounded. Inactive segments use `theme.barTrack`. Gap of 2pt between segments. Height matches LinearGauge.

**LiquidGauge** — `ZStack`:
- bottom: `RoundedRectangle` outline in theme accent color (border)
- middle: clipping container with fill height = `pct%`
- inside: gradient + animated sine-wave overlay via `Canvas` with a `TimelineView(.animation)` driving phase offset
- top: percentage text overlaid centered
Animation: 2.5s loop. At ≥90% the wave color tints toward `theme.colorForPercentage(pct)` (red zone). At 100%+ overflow, wave clips to full height and pulses.

**ASCIIGauge** — `Text` with monospaced font (`.system(.body, design: .monospaced)`):
- Format: `"SESSION  [████████████░░░░░░] 67%"`
- 18-char inner bar, filled chars = `Int(pct * 18 / 100)`, rest = `░`
- **Always uses black bg + green text regardless of selected theme** — the ASCII gauge is a self-contained terminal vignette. (Rationale: white-card-with-green-text looks broken; the gauge is an intentional aesthetic, not just a shape.)

### Status emoji wiring

`AppTheme.statusEmoji(for:)` currently lives on the theme. It moves to `IconPack.statusEmoji(for:)`. `UsageView` and `ClaudeUsageApp` (menu-bar status item) call `effectiveIconPack.statusEmoji(for: maxUtil)` instead of `theme.statusEmoji(...)`.

### Migration

`AppTheme.system` is removed. On first launch after upgrade, run a one-shot migration:

```swift
// In AppDelegate.applicationDidFinishLaunching or UsageManager init
if UserDefaults.standard.string(forKey: "appTheme") == "system" {
    UserDefaults.standard.set("standard", forKey: "appTheme")
}
```

No version flag needed — the read-and-replace is idempotent.

## File touch list

| File | Change |
|---|---|
| `ClaudeUsage/UsageView.swift` | Add `GaugeStyle`/`IconPack` enums, refactor `AppTheme` (remove `system`, add `terminal`/`retro`, add `defaultGauge`/`defaultIconPack`), split `UsageRow` to switch on gauge style, add 4 gauge subviews, expand settings panel with 2 new dropdowns + reset buttons |
| `ClaudeUsage/ClaudeUsageApp.swift` | Switch status-bar emoji lookup from `theme.statusEmoji(...)` to `iconPack.statusEmoji(...)`. Add migration block for legacy `system` theme value. |
| `ClaudeUsage/UsageManager.swift` | No changes (data layer unchanged) |

Expected impact: ~250 LOC added in `UsageView.swift`, ~20 LOC modified in `ClaudeUsageApp.swift`.

## Out of scope (v2 / later)

- **Dial / radial gauge** — needs vertical space rework
- **Custom user color picker** — themes are curated, no DIY palettes
- **SF Symbols icon pack** — discussed but skipped for v1 (existing 4 packs cover the vibes)
- **Per-row gauge overrides** (e.g. linear for weekly, liquid for session) — single override applies everywhere
- **Animated theme transitions** — switch is instant

## Acceptance criteria

- [ ] All 4 themes selectable from settings panel; selection persists across launches
- [ ] Switching theme instantly updates colors, gauge, and icons everywhere (popover + menu bar)
- [ ] Gauge override dropdown shows current effective value, falls back to theme default when cleared
- [ ] Icon pack override dropdown shows current effective value, falls back to theme default when cleared
- [ ] Reset buttons (`↺`) clear overrides back to theme defaults
- [ ] Liquid gauge wave animates smoothly at 60fps and pauses when popover is closed (no battery drain)
- [ ] ASCII gauge renders correctly in monospaced font with consistent column widths
- [ ] Segmented gauge correctly highlights N of 10 segments based on percentage
- [ ] Legacy `system` theme setting migrates silently to `standard` on first launch
- [ ] Menu-bar emoji follows the effective icon pack (e.g. Terminal pack shows `[!]` not 🟡)

## Open questions for user review

None — all design questions resolved during brainstorm. Spec ready for plan phase.
