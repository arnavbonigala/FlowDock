# FlowDock Interaction Model

FlowDock has four states: **idle**, **contextual**, **persistent**, and **expanded**. Every surface FlowDock draws is in exactly one of them, and every activity — music, a HUD, a download, the shelf, an extension — moves through the same progression. A user who learns one activity has learned all of them.

This document defines the states and the transitions between them. Visual rules are in [DESIGN.md](DESIGN.md); measurable timing and stability gates are in [QUALITY.md](QUALITY.md). Which activity wins when two want the same state, and how activities coexist, is defined by a later roadmap item — this document defines only the ladder each one climbs.

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
- Contextual state is gated behind `hudReplacement` for non-media types; that is a permissions concern, not a state concern, and does not change the ladder.

## Deferred

- Which activity owns the chin when several are eligible, how they queue, and whether any may coexist — the activity priority roadmap item.
- Transition anchoring and motion detail — the motion roadmap item.
- Keyboard and gesture coverage beyond the transitions above — the interaction consistency roadmap item.
