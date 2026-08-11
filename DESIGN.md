# FlowDock Visual Language

FlowDock should read as part of macOS, not as an app drawn on top of it. The default answer to any visual question is whatever AppKit, SwiftUI, and SF Symbols already do; a custom value is a decision that needs a reason.

This document defines layout, typography, materials, spacing, and iconography. Motion, interaction, and activity-priority rules are defined separately in later roadmap work. Release gates for contrast, frame budget, and accessibility live in [QUALITY.md](QUALITY.md) and apply to everything here.

Values that already exist in code are cited rather than restated. Where current code disagrees with a rule, it is listed under [Known deviations](#known-deviations); it is debt, not precedent.

## 1. Layout

**The cutout is the origin.** Every surface is anchored to the physical notch and grows from it. Nothing appears at a screen edge unrelated to the anchor, and nothing is centered on the screen when it could be centered on the cutout.

- **Anchor.** The closed surface matches the display's real notch: width and height come from `getClosedNotchSize()` in `FlowDock/sizing/matters.swift`. Heights are never invented — on notch displays use `safeAreaInsets.top`, on non-notch displays use the menu bar height, with a 185 × 32 pt synthetic anchor as the fallback.
- **Growth is symmetric.** Width expands equally left and right of the cutout's horizontal center, not the screen's. Height grows downward only. A surface never grows upward, past the display edge, or off-center.
- **Three widths, one shape.** Closed (the anchor), contextual (the anchor plus a chin extension, as in `computedChinWidth`), and expanded (`openNotchSize`, 640 × 190 pt). All three use `NotchShape`; only its radii and frame change.
- **Concentric corners.** Inner radius = outer radius − inset, so a rounded thing inside a rounded thing stays parallel to it rather than crowding one corner and floating off another. Radii come in matched pairs that change together with the state: the surface's own in `cornerRadiusInsets`, artwork's in `MusicPlayerImageSizes.cornerRadiusInset`. A nested container recomputes from its own inset; a radius invented at a call site is a bug.
- **Expanded layout.** A leading primary column (the activity in focus) and a trailing context column, separated by one 16 pt gutter (`spacing` in `FlowDock/models/Constants.swift`). Two columns maximum. If a third region is needed, the activity is too large for the expanded state.
- **Closed layout.** A single row: leading glyph or artwork, trailing indicator, cutout between them. Never more than one item per side.
- **Two chin side widths**, `Activity.chinSide` and `Activity.chinClockSide`. Each side of the cutout is 34 pt — enough for a glyph and a short value — and 44 pt only when the trailing side carries a running clock, which is wider than any other value the chin shows. An activity that wants a third text width is asking for the expanded state instead. The one exception is a side that carries an image rather than a glyph and a value: artwork and the visualizer are squares, so they take the chin's own height (`chinItemSide`) and stay square on every display instead of sitting in a fixed text-shaped box.
- **Non-notch displays.** The anchor is synthetic: 185 pt wide at the top center, as tall as that display's menu bar. There is no cutout to imitate, so the surface hangs from the screen edge — top corners square where they meet the edge, bottom corners rounded. Idle paints nothing at all: the anchor keeps its hover and click target so the surface can still be opened from the menu bar, but no black block sits over the menu bar until an activity or the user asks for one.
- **Multiple displays.** Each display renders its own anchor from its own metrics. A machine is never "a notch Mac" — each display is notched or not, and is measured on its own. Nothing is shared across displays except state.

## 2. Typography

**San Francisco, system text styles, nothing else.**

- Use `Font` text styles (`.body`, `.subheadline`, `.caption`). `Font.system(size:)` is permitted only to optically match a system HUD or a fixed-size glyph, and carries a comment saying which.
- No `design: .rounded`, no `design: .serif`, no bundled faces. Rounded is the system's playful voice; FlowDock is a calm one. Non-Latin scripts fall back through the system font, not a custom file.
- **Role mapping.** Expanded title: `.title3` semibold. Primary: `.body`. Secondary: `.subheadline`. Metadata, timestamps, counts: `.caption`. Nothing smaller than `.caption2`, and nothing below 11 pt effective size at any Dynamic Type setting.
- **Two sizes maximum** are visible in the closed and contextual states. Hierarchy there comes from weight and color, not size.
- **Anything that changes in place uses `.monospacedDigit()`** — elapsed time, remaining time, percentages, countdowns, byte counts. Digits must not reflow while ticking.
- **Letter spacing belongs to the font.** No `tracking()` and no `kerning()`. San Francisco tracks optically by size already, and a hand-set value fights it at exactly the small sizes where it is tempting.
- **Color is semantic.** `.primary` and `.secondary` only. No hard-coded greys, no opacity applied to text to fake a tier.
- **Truncation.** One line closed, two lines maximum expanded, `.truncationMode(.tail)` — except a filename, which truncates in the middle so the extension survives, the way Finder does. A file the user cannot identify is not a shorter label, it is a different one. Scrolling text is reserved for a title that loses meaning when cut, and only while the thing it names is still moving — a playing track scrolls its title, a paused one truncates. Motion that outlives the state it describes is noise.
- Sentence case for labels, title case for proper names. No all-caps.

## 3. Materials and color

**The anchored surface is opaque black. This is the one non-negotiable rule.**

The closed and contextual surfaces must be indistinguishable from the display bezel, so they are `Color.black` — never a material, never translucent, never tinted, and never lighter in light appearance. A blur that lets the desktop through breaks the illusion that the hardware grew.

- **Elevation inside the panel is opacity, not shadow.** Base is black; a raised region uses `.quaternary` fill; a raised region on top of that uses `.tertiary`. Shadows are used only where the expanded panel meets the desktop (`enableShadow`), never between internal layers and never behind the closed or contextual surface — bezel does not cast a shadow onto the menu bar.
- **The fill tiers are for fills.** Foreground text and any glyph carrying meaning stop at `.secondary`; `.tertiary` on black is around 2.5:1 and fails the text gate in [QUALITY.md](QUALITY.md). A third level of emphasis in a panel is a sign the panel is saying too much, not a reason to go dimmer.
- **Materials belong to detached surfaces only** — settings, popovers, menus, and windows that are not attached to the bezel. Those use `.regularMaterial` and follow the system appearance normally. A menu opened *from* the panel is the exception: AppKit gives a menu the appearance of the window it was raised from, so it comes up dark, and it should — a light menu hanging off a black surface would read as a different app's.
- **The panel is always dark**, in both light and dark appearance, because it is bezel. Detached surfaces are not.
- **Accent.** `Color.accentColor`, or the user's override (`useCustomAccentColor`). Accent marks state — progress, selection, activity — and is never used for body text or as a large fill.
- **Artwork tinting** (`playerColorTinting`) may color a progress track, a glyph, or a gradient wash. It may not color text, and any tinted element still meets the 4.5:1 text and 3:1 non-text contrast gates in QUALITY.md against black. Clamp the extracted color; do not trust the source image.
- **Reduce Transparency** replaces every material with its opaque equivalent. **Increase Contrast** raises fill tiers by one step and adds a hairline border to any region that relied on fill alone to define its edge.

## 4. Spacing

**4 pt grid.** Permitted steps: 4, 8, 12, 16, 24. 2 pt is allowed only for optical correction and needs a comment. No other values.

| Relationship | Step |
|---|---|
| Inside a control cluster (glyph to its label) | 4 |
| Between related items in a group | 8 |
| Panel content inset from the panel side edges | 24 |
| Panel content inset from the panel bottom edge | 12 |
| Between columns and unrelated groups | 16 |
| Between major sections of the expanded state | 24 |

**Two row heights, not one per panel** — `PanelRow.content` and `PanelRow.controls`.
Panels stack in the same column, so a row that carries content is **30 pt** — an agenda
entry, a notification, a download, a meeting — and a strip that only carries controls is
**22 pt**. The two stacked lines of text inside a content row are separated by 1 pt, which
is optical, not a spacing step.

A row that is itself one surface is inset 8 pt horizontally and sits on an 8 pt continuous
rounded rectangle (`panelRowBackground`). A row that is a line of separate targets — the
shelf's chips, its action strip — is not a surface, so it keeps the height and skips the
card; the things inside it carry their own. Two cards deep is elevation the panel does not
have.

**The agenda column is a list, not a stack of rows.** An event's title wraps, so its
height cannot be fixed, and a card behind every entry would make a dense day unreadable.
Agenda entries are plain rows separated by 2 pt, marked by a 3 pt calendar colour bar
instead of a fill, in the manner of the system's own agenda. This is the only list in the
app and the only place the two row heights do not apply.

- Prefer `VStack(spacing:)` / `HStack(spacing:)` over per-child padding. A bare `.padding()` is not acceptable in new code — it resolves to a system default that ignores this scale.
- Content is inset from the panel edge, never from the screen edge.
- **A region that scrolls says so at its edge**, not with a scrollbar. A scrollbar inside the bezel reads as a window, so indicators stay hidden and the far edge fades instead (`fadesPastEdge`), only while there is something past it. Every scrollable region in the panel uses it; a new one that does not is a region the user cannot tell is longer than it looks.
- **Hit targets are at least 28 × 28 pt** regardless of glyph size, expanded with `.contentShape(Rectangle())` rather than by growing the visual.
- Optical over mathematical: a glyph with visual weight below its baseline may be nudged, and the nudge is a 2 pt correction, not a new spacing step.

## 5. Iconography

**SF Symbols only.** The app icon and the brand mark are the only custom art. A concept macOS already has a symbol for uses that symbol — `speaker.wave.2.fill`, `sun.max.fill`, `keyboard`, `mic.fill`, `battery.75percent` — because FlowDock stands in for system HUDs and must not invent a second vocabulary for the same thing.

- **Sizes** are the named tokens in `FlowDock/extensions/Typography.swift` — `.panelMeta`, `.panelControl`, `.panelPrimary` — reached through `Image.Scale.glyphFont` so a preview cannot pick a size the panel never draws. A text style such as `.largeTitle` is not one of them: it grows with Dynamic Type inside a control whose frame does not. Symbols paired with text use the text's own style so they scale together.
- **Weight** matches the adjacent text weight; default `.medium`.
- **Rendering** is `.hierarchical` by default. `.palette` is used only when a second color carries meaning, `.multicolor` only where the system's own multicolor form is expected.
- **State changes animate the symbol**, not the view: `.contentTransition(.symbolEffect(.replace))` for play/pause, mute/unmute, and similar pairs. Never crossfade two `Image` views.
- Filled variants inside the panel, outline variants in detached surfaces such as settings — matching macOS.
- The menu bar icon is a monochrome template image and inherits menu bar tinting.
- **One symbol, one action.** A control never swaps which command it runs based on how much is selected or what state the app is in — a glyph the user has learned must keep meaning the same thing. Two commands are two controls, shown when each applies.
- Every symbol that is the only content of a control carries an `.accessibilityLabel`, and the same words become its help tag — `.iconLabel(_:)` sets both, so a control cannot name itself to VoiceOver and stay anonymous to the pointer. A symbol is never the only carrier of state where color or shape alone would have to communicate it.

## Conformance

- New or reworked interface code follows this document. Existing code is brought into line when it is touched, not in a separate sweep.
- Pull requests with visible changes include light and dark screenshots at 1× and 2×, plus Reduce Motion and Reduce Transparency where relevant, per [CONTRIBUTING.md](CONTRIBUTING.md).
- A deliberate exception is allowed with a comment giving the reason. An undocumented one-off value is a bug.

## Sanctioned exceptions

Every value in the app is on this document's scale except these, which exist to match
something the system already draws and are the complete list:

| Where | Value | Why |
|---|---|---|
| The system feedback pill | 10 pt gap, 14 pt inset, 11 and 15 pt text | It stands in for the macOS volume and brightness HUD and must be indistinguishable from it |
| The drawn battery glyph | 25 × 12 pt body, 3.5 pt radius, 1 pt gap to the tip, 2 pt fill inset, 7 pt bolt | It reproduces the menu bar's own battery, so its internal metrics come from that glyph rather than from this scale. Nothing else may borrow them |
| Missing-artwork placeholder | 26 pt | A single glyph filling artwork's square, not text |
| The drawn spectrum | 16 × 14 pt, four 2 pt bars with 2 pt gaps | It is a glyph the app draws rather than a layout, and it stands in for the bars macOS shows beside a playing track. The mask it fills must match these metrics exactly or the bars clip |
| A title with its own second line under it | 1 pt leading, and up to 2 pt of optical alignment for a control or rule set beside it | The pair is one thing being read, not two elements being spaced, and 4 pt between a title and its own subtitle breaks it into two. This applies inside a text stack only — the gap to whatever comes next is still on the grid |

Anything else off the 4 pt grid, and any other `Font.system(size:)`, is a bug rather than
a precedent.

## The chin type scale

Sizes inside the bezel surface come from `FlowDock/extensions/Typography.swift` rather
than from each activity, so a new activity cannot introduce a fourth size for the same
job:

| Role | Style |
|---|---|
| Leading glyph in the chin | `.chinGlyph` — 13 pt medium |
| Trailing value or short state in the chin | `.chinValue` — 12 pt semibold, with `.monospacedDigit()` |
| A control's glyph in the panel | `.panelControl` — 15 pt medium |
| Secondary text in a panel row | `.panelMeta` — 11 pt medium |

The inherited BoringNotch deviations this section used to list — off-grid spacing,
non-concentric radii, `design: .rounded`, a bundled Persian face, bare `.padding()` — are
resolved. The only `.padding()` calls left are in `#Preview` blocks.
