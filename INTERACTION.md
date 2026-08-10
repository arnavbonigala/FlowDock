# FlowDock Interaction Model

FlowDock has four states: **idle**, **contextual**, **persistent**, and **expanded**. Every surface FlowDock draws is in exactly one of them, and every activity — music, a HUD, a download, the shelf, an extension — moves through the same progression. A user who learns one activity has learned all of them.

This document defines the states and the transitions between them. Visual rules are in [DESIGN.md](DESIGN.md); measurable timing and stability gates are in [QUALITY.md](QUALITY.md). It also defines which activity wins when several want the same state, in [Activities](#activities).

## The four states

| State | Purpose | Size | Who enters it | How it ends |
|---|---|---|---|---|
| **Idle** | Nothing to say | The anchor, exactly | Default | An activity begins |
| **Contextual** | A value changed just now | Anchor + chin | The system | Expires on its own |
| **Persistent** | Something is ongoing | Anchor + chin | The system | The activity ends |
| **Expanded** | The user is working | Full panel | The user, only | The user leaves |

**Idle.** The surface is exactly the anchor from `getClosedNotchSize()`, opaque black, empty. It must be indistinguishable from the bezel — idle is not a small UI, it is the absence of one. On a display with no notch, and wherever the anchor would otherwise intrude, idle collapses to zero height. Idle draws no glyph, no dot, and no branding.

**Contextual.** A transient report that a value changed: volume, brightness, keyboard backlight, microphone, power connected, download started. It is caused by the system, never by a click, and it **expires by itself**. Contextual state accepts no input — clicking it does nothing, hovering it does not open the panel. It carries one glyph and one value, and nothing that would reward reading a second time.

**Persistent.** An activity that is genuinely ongoing and has no known end: media playing or paused-but-resumable, a download in flight, a running timer, an active recording. It stays for exactly as long as the activity does. It carries a leading identity (artwork, app icon, glyph) and a trailing indicator (progress, level, count) — one element per side. Its only input is the one that reaches expanded.

**Expanded.** The full 640 × 190 pt panel. The only state with controls, scrolling, drop targets, text entry, and keyboard focus. It is only ever entered by a deliberate user action, and it is the only state a user can dismiss.

## Invariants

These are what make the progression consistent. A change that breaks one of them is a bug, not a variation.

1. **Sizes only go one way.** anchor ≤ chin ≤ panel. Contextual and persistent share the chin; neither may render at panel width.
2. **Only the user reaches expanded.** The system may promote idle → contextual and idle → persistent. It may never expand the panel on its own. No system event, notification, or activity is important enough to take over the screen or the keyboard.
3. **One state, one appearance.** A state looks the same regardless of how it was entered or what it was before. There are no entry-specific variants.
4. **Collapse returns to the highest state still true, never to idle.** Dismissing the panel while music plays returns to persistent. Persistent state ending while the panel is open leaves the panel open until the user leaves, then returns to idle.
5. **Contextual state does not survive a collapse.** If it expired or was replaced while the panel was open, it does not reappear underneath.
6. **Contextual state suppresses hover-to-expand while it is visible.** A HUD must never become a panel because the pointer happened to be there.
7. **Transitions are interruptible.** Any transition can be reversed mid-flight from its current geometry, with no snap back to the state it was leaving.
8. **The anchor never moves.** Width and height animate; the cutout's center and the top edge do not. A state change is a shape change, never a reposition.
9. **State is per display.** Each display runs its own ladder from its own anchor.

## Transitions

| From | To | Trigger | Timing |
|---|---|---|---|
| Idle | Contextual | System value changed | Visible within 100 ms |
| Contextual | Contextual | Same value changed again | Dwell timer restarts; no re-entry animation |
| Contextual | Idle | Dwell elapsed | 1.5 s after the last change |
| Contextual | Persistent | An ongoing activity begins | Immediate; contextual yields without collapsing first |
| Idle / Contextual | Persistent | Activity begins | Immediate |
| Persistent | Idle | Activity reports completion | Immediate, no linger |
| Any | Expanded | Hover intent, click, downward pan, or a file drag entering the anchor | Hover intent = pointer held inside the anchor for `minimumHoverDuration` (0.3 s) |
| Expanded | Highest state still true | Pointer leaves, upward pan, Escape, or the drop completes | 100 ms grace after the pointer leaves |
| Any | Idle | Sleep, wake, lock, display change, or the anchor becoming invalid | Immediate, no animation |

**Hover intent, not hover.** The pointer crossing the anchor on its way somewhere else must never expand the panel. The dwell requirement is the whole mechanism; it is user-configurable and may be disabled, in which case click and gesture remain.

**Dismissal is never blocked by FlowDock's own state**, only by a live child interaction it does not own — an open share sheet or a system popover. Those hold the panel open (`preventNotchClose`, `isBatteryPopoverActive`) and release it the moment they close.

**Expansion is not focus.** Reaching expanded must not activate the app, take key window, or interrupt what the user is typing into.

## Input

Which inputs a state accepts follows from the state, not from what happens to be on screen:

| State | Accepts |
|---|---|
| Idle | Nothing but the inputs that reach expanded |
| Contextual | Nothing at all |
| Persistent | Only the inputs that reach expanded |
| Expanded | Everything |

Three rules cut across all six input kinds:

- **No pointer-only affordance.** Everything reachable with the mouse in expanded state is reachable with the keyboard.
- **One input, one meaning.** A gesture, click, or key does the same thing in every state and every activity. An activity does not get to redefine one.
- **Input never steals context.** FlowDock does not become the key window, does not activate the app, and does not take keystrokes the user meant for something else.

### Hover

- Hover expands only through the dwell described under [Transitions](#transitions). Pointer transit across the anchor must produce nothing but a highlight.
- Hover **never commits an action** and never changes system state — no playback change, no volume change, no send.
- Inside expanded state, hover only highlights: a fill tier step per [DESIGN.md](DESIGN.md), never a size or position change.
- The hover region is the visible surface, plus `extendHoverArea` when enabled. FlowDock never listens for hover outside the shape it draws.
- Reaching the menu bar must never require avoiding FlowDock.

### Click

- **Primary click on an anchored state expands.** It never operates the underlying activity — clicking the music chin opens the panel, it does not pause playback. A one-click surface with two possible meanings is how a user learns to distrust it.
- Primary click in expanded state hits the control under the pointer. Clicking empty panel space does nothing; it does not dismiss.
- **Secondary click opens the same context menu in every state**, including idle. That menu is the guaranteed route to Settings.
- A click on FlowDock never passes through to the window beneath it.
- Double-click and click-and-hold are unassigned and stay that way until something needs them.

### Keyboard

- **Global shortcuts are user-remappable** and defined in `FlowDock/Shortcuts/ShortcutConstants.swift`. Toggling expanded state (⇧⌘I) is the keyboard equivalent of hover and click, and must always exist.
- Inside expanded state: `Tab` / `⇧Tab` move through primary actions in visual order, `Space` and `Return` activate, arrow keys move within a collection, `Escape` dismisses.
- Focus is borrowed, not taken. Opening by shortcut gives the panel focus; dismissing returns focus to where it was. A state the *system* promoted never takes focus.
- **`Option` is the only modifier that changes meaning**, and it always means "the alternate action" (as in `optionKeyAction`). No other modifier alters a FlowDock input.

### Gesture

- Direction follows geometry: **two-finger pan down expands, pan up dismisses.** Down grows, up collapses, in every state.
- Gestures track the pointer continuously and are cancellable — releasing before `gestureSensitivity` returns to the starting state with no action taken.
- Horizontal pan is unassigned and stays that way. The chin has one owner at a time, so there is nothing to swipe between.
- Scrolling inside expanded content is not a gesture and never collapses the panel.
- No gesture is the only route to anything.

### Drag

- **Dragging valid content over the anchor expands immediately** — no dwell. Unlike a hovering pointer, a drag carrying content is unambiguous.
- The drop target is the entire panel, never a small zone inside it.
- Dragging content out is a copy by default (`copyOnDrag`); nothing FlowDock does removes the user's original.
- A drag that ends anywhere — accepted, rejected, or abandoned — returns FlowDock to the highest true state within the settle interval. No drag can leave the panel stuck open or an item half-added.

### Dismissal

- Four routes, all available whenever the panel is open: **pointer leaves, `Escape`, pan up, or the toggle shortcut.**
- Dismissal is never destructive. Nothing is discarded, no shelf item is removed, no playback is changed.
- It is blocked only by a live child interaction FlowDock does not own — an open share sheet or system popover — and released the instant that closes.
- Expanded state has no timeout. A panel the user opened closes when the user is done with it.

### Feedback

- Any accepted input shows a visible result within 100 ms ([QUALITY.md](QUALITY.md)).
- An input that is unavailable does nothing — no alert, no beep, no shake.
- Haptics fire on state changes only, never per control, and only when `enableHaptics` is on.

## Activities

An activity is anything that can occupy a state: a HUD, media playback, a download, the shelf, an extension. The chin has **exactly one owner at a time**. It is never split in half, never stacked, and never rotated between activities — a surface this small is read at a glance or not at all.

Every activity declares three things. Anything that cannot is not an activity yet:

- **Class** — contextual or persistent, per [The four states](#the-four-states).
- **Band** — where it sits in the priority ladder below.
- **Completion** — the observable signal that it is over. A persistent activity with no completion signal is a contextual one wearing a costume, and it is the reason chins get stuck.

### Priority

**Priority is proximity to what the user just did, not importance of the information.** A volume HUD outranks a download not because volume matters more, but because the user pressed a key half a second ago and is waiting to see whether it worked.

| Band | Activity | Class |
|---|---|---|
| 1 | A drag in progress, or the shelf receiving content | Persistent |
| 2 | System feedback the user just caused: volume, brightness, backlight, microphone | Contextual |
| 3 | Power state changes: connected, disconnected, low power | Contextual |
| 4 | Progress with a known end: downloads, transfers, timers | Persistent |
| 5 | Ongoing media | Persistent |
| 6 | Ambient decoration | Persistent |

Ties inside a band go to the activity that started most recently. New activities and extensions join an existing band; the ladder does not grow a band per feature.

### Coexistence

- **In the chin, one owner.** A lower-priority activity that is still true stays live and invisible, and takes the chin back the moment the higher one ends.
- **Two contextual activities never coexist.** A newer one replaces the older immediately, with no queue — a user who changes volume and then brightness wants the brightness, not a backlog. The replaced one is dropped, not deferred.
- **In expanded state, coexistence is allowed**, because there is room. Contextual feedback appears in the header without displacing or resizing content, and every live persistent activity is listed.
- Ambient decoration yields to everything and appears only when nothing else is true.

### Interruption

- A higher-priority activity **interrupts immediately**. It does not wait for the current owner to expire.
- **Interruption is a loan, not a handoff.** When a contextual activity takes the chin from a persistent one, the persistent one gets it back on expiry — the chin returns to it, never to idle.
- **Interruption never passes through idle.** The chin morphs its contents in place; it does not collapse and reopen.
- **Lower priority never interrupts.** A contextual activity that is outranked at the moment it fires is dropped. Its moment has passed and showing it late is worse than not showing it.
- **Nothing interrupts the user.** An expanded panel is never resized, collapsed, or re-laid-out by a system activity, and a drag in progress is never interrupted at all.

### Expiration

- **Contextual expires on a timer**, 1.5 s after its last update. A value that keeps changing — a held volume key — keeps restarting the timer and stays up as long as the user is acting. One duration for the whole class; an activity does not get its own.
- **Persistent expires on its completion signal**, never on a timer. Playback stops, the download finishes, the timer fires.
- **A source that vanishes ends its activity immediately.** If the app quits, the device unplugs, or the connection drops, the activity ends rather than freezing on its last known value. Stale is worse than absent.
- Expiration is silent and uses the standard transition. There is no farewell.
- An activity expiring while the panel is open simply disappears from the panel. **Expiration never closes the panel.**

### Current implementation

- Priority is an `if / else if` chain inside `NotchLayout`, so its order is a rendering side effect and adding an activity means editing a branch.
- The standard sneak peek renders *below* the music activity in the same stack rather than taking the chin — the one case of stacking that the rules forbid.
- Two expiration mechanisms exist for one class: `sneakPeek` at 1.5 s and `expandingView` at 2 s for downloads, 3 s for battery.
- Downloads and battery share `expandingView` despite being progress and a state change, in different bands.
- The face animation is band 6 decoration occupying persistent state whenever media is idle.
- No activity publishes completion. Media is inferred from `isPlayerIdle`, which is why a quit player can leave the chin populated.

## Displays

Every display runs its own ladder from its own anchor (invariant 9). Notch and non-notch displays run the *same* ladder — the states, sizes, inputs, and priorities are identical, and only the anchor's geometry differs, as described in [DESIGN.md](DESIGN.md). Nothing is conditioned on whether a display has a cutout except where the anchor comes from.

### Which display

- **One display is active**: the one the user chose, or the built-in display if they have not chosen. When following the pointer is enabled, the active display is the one containing the pointer.
- **The active display only changes while idle.** FlowDock never moves mid-activity or while the panel is open. A surface that teleports between monitors is worse than one that stays in the wrong place.
- **Expanded state exists on one display at a time**, always — including when FlowDock is shown on all displays. Opening on one collapses any other.
- When FlowDock is shown on all displays: **contextual activities appear only on the active display** — a volume HUD on four monitors is noise — while persistent activities mirror everywhere, since they are ambient by nature.
- A display showing no activity is idle, which means it shows nothing at all.

### Configuration changes

Connecting or disconnecting a display, changing resolution or scale, rotating, rearranging, mirroring, docking, opening or closing the lid, sleeping, waking, and locking are all the same event: **the geometry is no longer trusted.**

- Every affected display returns to idle immediately, without animation, and re-derives its anchor from current metrics.
- **Re-derive, do not rebuild.** A configuration change recomputes geometry; it does not tear down and recreate windows. Rebuilding flashes, drops state, and is the source of most of the failures in roadmap section 4.
- **Activities survive the change.** Media that was playing is still playing, and its chin reappears on the correct display once geometry settles. Only contextual activities are lost, and they were expiring anyway.
- If the chosen display disappears, fall back to the built-in display, then to the main one, and return to the chosen display when it comes back.
- Mirrored displays are one display.

### Hit regions

Every display's interactive region matches what that display is currently drawing — including drag detection. A display in idle state has no hit region larger than its anchor, and a display showing nothing has none at all.

### Current implementation

- A screen configuration change closes and recreates every window rather than repositioning them.
- Following the pointer is implemented by setting `alphaValue` to 0 on the inactive display, so a window remains present on a display that appears to have nothing.
- Drag detection registers a region the size of the *expanded* panel (640 × 190) at the top of every screen, regardless of the state that screen is in.
- `deviceHasNotch()` returns true when any display has a notch, answering a per-display question for the whole machine.
- Windows are created per display only in all-displays mode; single-display mode keeps one window and moves it, so the two modes take different code paths to the same result.

## Anchoring

Everything FlowDock draws hangs below the cutout, so everything it animates must read as coming from it. Content that fades in place, or scales from its own center, reads as a floating window and breaks the illusion the whole product depends on.

- **One transition, defined once.** Every insertion and removal uses a single shared transition — a scale toward the top edge combined with opacity, `AnyTransition.scale(scale: 0.9, anchor: .top).combined(with: .opacity)` — declared in `FlowDock/animations/FlowDockAnimations.swift`, whose existing `// TODO: Move all animations to this file` is where it belongs. A bare `.opacity`, a center-anchored `.scale`, or a `.move(edge:)` is a bug.
- **Call sites choose timing, never the anchor.** Attaching `.animation(…)` where a surface needs its own pacing is fine. Redefining the scale or the anchor is not.
- **Scale and offset anchor to `.top`** wherever they animate, including gesture tracking.
- **Continuity beats transition.** An element that exists in both the collapsed and expanded state moves with `matchedGeometryEffect` — album artwork and the spectrum already do — instead of one copy fading out while another fades in.
- **Growth is a shape change.** The panel's top edge and horizontal center are fixed by construction (`windowSize` with `.top` alignment); animate width and height, never position.
- Reduce Motion is honored inside the shared transition itself, so there is one place to change. See [Accessibility](#accessibility).

Every transition in the current code is unanchored and is replaced when its surface is rebuilt in roadmap section 3:

| Site | Today |
|---|---|
| `ContentView` inline HUD | `.opacity` |
| `ContentView` panel content | `.scale(0.8, anchor: .top)` — anchored, but its own value |
| `FlowDockHeader` open-notch HUD | `.scale(0.8)`, center anchor |
| `NotchHomeView` app icon, volume slider | `.scale`, center anchor |
| `NotchHomeView` lyrics, home content | `.opacity`, `.move(edge: .top)`, asymmetric removal |
| `EmptyState` | `.blurReplace` |

## Accessibility

**An accessibility setting changes how FlowDock behaves, never what it can do.** No feature is withdrawn, no information is dropped, and nothing is "simplified" for a user who turned one on. These are release gates in [QUALITY.md](QUALITY.md), not aspirations.

### Reduce Motion

- **The shared transition becomes a cross-fade in place** — opacity only, no scale, no movement. It keeps its duration; an instant swap is its own kind of disorienting.
- **Springs become an ease curve.** The chin still resizes and the panel still grows, because size *is* the information. What goes is the overshoot, the bounce, and the settle.
- **Looping decoration stops entirely** — the music visualizer, the face animation, and anything else that moves without being asked. It is switched off, not slowed down.
- **Scrolling text stops.** A title that would marquee truncates instead, and the full value is available to VoiceOver and in expanded state.
- Auto-scrolling to the next calendar event becomes an instant jump.
- Gesture tracking is unaffected. Movement the user is driving with their own finger is not animation.

### VoiceOver

- **Each state announces once on entry**, describing the activity and its value — "Volume, 40 percent" — not the interface around it.
- **An activity the user caused announces immediately; one the system caused announces politely** and never interrupts what VoiceOver is already reading. This is the same proximity rule that orders the [priority ladder](#priority).
- **The chin is one element with one label**, not a container to navigate into. Expanded state is fully navigable, in visual order.
- Progress does not re-announce on every tick. It is exposed as a value VoiceOver reads on request.
- Every control has a name, a role, and a value. Decorative elements are hidden from the accessibility tree rather than left to announce themselves.

### Keyboard and pointer

- **No affordance is hover-only or pointer-only.** Everything reachable with the mouse in expanded state is reachable with [the keyboard](#keyboard), with a visible system focus ring.
- Hover-to-expand can be disabled entirely; click, gesture, and the global shortcut remain.
- Hit targets are at least 28 × 28 pt regardless of glyph size, per [DESIGN.md](DESIGN.md).

### Timing

- **No interaction has a time limit.** Nothing expires while the user is deciding.
- The only two timers a user waits on are contextual dwell and hover intent. Hover intent is configurable and can be turned off.
- **Contextual dwell extends to at least the length of its announcement when VoiceOver is active.** 1.5 s is enough to glance at a HUD and not enough to hear one.

### Visual

Specified in [DESIGN.md](DESIGN.md) and listed here so the requirements read in one place: Reduce Transparency replaces every material with an opaque equivalent; Increase Contrast raises fill tiers and adds hairline borders to regions defined only by fill; text and controls meet 4.5:1 and 3:1 against the panel, including when tinted by artwork; nothing renders below 11 pt effective size; and no state is carried by color alone.

### Current implementation

None of this exists yet. The app contains one `accessibilityLabel`, one `accessibilityHidden`, no reference to `accessibilityReduceMotion` or `accessibilityReduceTransparency`, no focusable controls, and no VoiceOver labels on any notch surface. Marquee text and the visualizer animate unconditionally.

## Timing

Current values, in one place so they stay consistent:

| Interval | Value | Source |
|---|---|---|
| Contextual dwell | 1.5 s | `sneakPeekDuration` |
| Hover intent | 0.3 s, configurable | `minimumHoverDuration` |
| Close grace after pointer exit | 100 ms | `ContentView.handleHover` |
| Drop settle before collapse | 500 ms | `ContentView` drop debounce |
| Expand animation | spring, response 0.42, damping 0.8 | `ContentView` |
| Collapse animation | spring, response 0.45, damping 1.0 | `ContentView` |

Every duration a user waits on is one of these. New timeouts are not invented per activity; an activity that needs different pacing changes state, not the clock.

## Current implementation

Today's code implements two of the four states, plus two ad-hoc timed mechanisms that together approximate the other two:

- `NotchState` has `closed` and `open`. It becomes the four-case ladder when the first surface is rebuilt; `closed` splits into idle, contextual, and persistent.
- `sneakPeek` is contextual state, with its own 1.5 s timer.
- `expandingView` is also contextual state, with a separate 2 s / 3 s timer, a separate struct, and a separate code path. The two are one concept and collapse into one.
- The music live activity is persistent state, expressed as a special case inside the closed layout rather than as a state.
- The battery notification renders at 640 pt while `closed`, which breaks invariant 1.
- `close()` already re-derives what to show underneath, which is invariant 4 by accident. It becomes explicit.
- Escape does not dismiss the panel today. It must.
- Nothing in the panel is focusable and there is no tab order; the keyboard reaches FlowDock only through global shortcuts.
- The context menu is attached to the notch layout, so it is unavailable wherever that layout is not hit-testable.
- Shelf items handle secondary click in an `NSView` subclass, separate from the SwiftUI context menu — two menus, one input.
- Haptics fire the moment the pointer enters the closed notch, before hover intent, so transit is rewarded like an action.
- The `toggleSneakPeek` shortcut lets a user summon contextual state, which by definition is system-caused. It becomes a persistent or expanded surface instead.
- Contextual state is gated behind `hudReplacement` for non-media types; that is a permissions concern, not a state concern, and does not change the ladder.
