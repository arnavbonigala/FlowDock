# FlowDock Validation Matrix

Everything in [QUALITY.md](QUALITY.md) that a shell cannot prove. The code checks — unit self-checks, builds, static audits — run in CI and in review. What is written here needs a real Mac, a real display, a real calendar account, and a person watching.

Work through it in one sitting per configuration. Record, with every run: **commit sha, Mac model, macOS version, display setup, and how long you observed.** A check with no recorded configuration is not a result.

Mark each check `pass`, `fail`, or `n/a` (with the reason). A `fail` on anything in **Blocking** stops the release regardless of what else passed.

---

## 1. Hardware and OS matrix

Extends the minimum matrix in `build/research/boringnotch-product-research.md`. Runtime target is macOS 14 or later on Apple Silicon and Intel; none of that is validated by CI, which only builds a generic macOS target.

| # | Configuration | Required scenarios |
|---|---|---|
| H1 | Apple Silicon MacBook Pro **with notch** | Idle/contextual/persistent/expanded ladder, battery, internal brightness and keyboard backlight, sleep/wake, full screen, Spaces. |
| H2 | Apple Silicon MacBook Air **without notch** | Menu-bar collision, top-edge anchoring, zero-height idle, full screen. |
| H3 | **Intel** MacBook, ideally with Touch Bar | Launch, media source switching, volume/brightness/backlight interception, XPC helper authorization, sleep/wake. |
| H4 | Mac mini / Studio, **one external display, no internal** | Non-notch layout, no battery or backlight assumptions anywhere in the UI, audio output changes. |
| H5 | Notched MacBook **plus** external display | Preferred-display and all-display modes, lid open and closed, hot plug, display reorder, full screen on either display. |
| H6 | Docked / **clamshell** MacBook | Dock disconnect and reconnect, shelf drag while docked, camera/audio/display re-enumeration. |
| H7 | Display driven by **BetterDisplay** (or similar) | FlowDock does not swallow media keys, does not claim brightness control it does not have, and does not fight the tool for the menu bar. |
| H8 | **Oldest supported OS** — macOS 14 | Everything in H1 plus onboarding, permission prompts, and update check. Nothing is gated on a symbol that only exists on 15/26. `MediaRemoteAdapter.framework` is built for 15.0, so confirm the app still launches and that music falls back to Music/Spotify control instead of the generic now-playing path. |
| H9 | **Newest OS** — current release | Same as H8, plus the macOS 26 glass path in `SystemFeedback.glassBackground` and icon-appearance tinting. |

Run H1 and H5 for every release candidate. Run the rest at least once per minor release and whenever the window, sizing, or display code changes.

---

## 2. Display arrangements

Each of these is exercised on H5 or H6 unless noted. FlowDock measures every display on its own — a machine is never "a notch Mac".

| # | Arrangement | What to do | Correct |
|---|---|---|---|
| D1 | Single internal, notch | Baseline | Surface matches the physical cutout; no wallpaper sliver above it. |
| D2 | Single external, non-notch | Baseline on H4 | Synthetic 185 pt anchor at top centre, square top corners, height = that display's menu bar. Idle is zero height and nothing covers the menu bar. |
| D3 | Mixed notch + non-notch | Move the pointer and the panel between them | Each display draws from its own metrics. No notch cutout imitated on the non-notch display. |
| D4 | Menu bar moved to the external display | System Settings → Displays → arrange | FlowDock follows the preferred-display setting, not a stale screen reference. |
| D5 | Hot plug while expanded | Unplug and replug the external display with the panel open | Panel re-anchors or closes cleanly. No orphan window, no window on a dead screen, no duplicate panels. |
| D6 | Clamshell open → closed → open | Close the lid docked, use it, reopen | Internal window is torn down and rebuilt; the external window keeps working the whole time. |
| D7 | Display reorder / resolution change | Drag displays in Arrangement; change scaled resolution | Anchor recomputes. No clipping, no off-centre growth, no leftover shadow. |
| D8 | **Sub-640 pt logical width** | A small or heavily scaled display narrower than the 640 pt panel | Panel clamps to the screen width, still centred on the anchor, nothing runs off either edge, agenda column still readable. |
| D9 | Mixed scale factors | 1× display next to 2× | Text and hairlines are crisp on both. No half-pixel borders on the 1× display. |
| D10 | Full screen / Stage Manager / Mission Control | Enter and leave each on both displays | Panel hides where INTERACTION.md says it hides; it never blocks the traffic lights or the menu bar; no focus theft. |

---

## 3. Accessibility settings

Set these in System Settings → Accessibility. Toggle them **while FlowDock is running** — a setting picked up only at launch is a fail.

| # | Setting | What to do | Correct |
|---|---|---|---|
| A1 | **Reduce Motion** | Toggle on, then open/close the panel, change tracks, change volume | Transitions cross-fade in place: no scale, no bounce, same duration. The panel still changes size (size is the information). Music visualiser is replaced by a static glyph, not slowed. Scrolling titles truncate instead of marqueeing. Scrubber track resize eases rather than springs. Calendar auto-scroll is an instant jump. |
| A2 | **Reduce Motion**, left on for ten minutes | Idle with music paused | Nothing loops. No CPU floor from a timer that kept running behind a hidden animation. |
| A3 | **Reduce Transparency** | Toggle on, press a volume key | The system feedback pill is opaque, not blurred desktop. The panel itself was already opaque black and must not change. |
| A4 | **Increase Contrast** | Toggle on, open the panel with items on the shelf, press a volume key | Shelf chips and the share button step up a fill tier and gain a hairline border. The feedback pill's border becomes solid white at 1 pt and its level track darkens. Nothing becomes unreadable. |
| A5 | **Increase Contrast + Reduce Transparency together** | macOS turns Reduce Transparency on with Increase Contrast | Both apply; no double-darkened text, no invisible borders. |
| A6 | **Larger text** (app-level, or with an accessibility text size where the OS offers it) | Open the agenda with a full day of events | Agenda text scales with its text style. Titles truncate rather than overlap; the reminder checkbox stays 28 × 28 pt; the time column does not collide with the title. |
| A7 | **Contrast measurement** | Sample the panel with a contrast checker in light and dark appearance, with artwork tinting on and a bright album cover | 4.5:1 for text, 3:1 for non-text, against the panel's black. Tinted progress tracks included. |
| A8 | **VoiceOver — chin** | VO on, trigger a volume change and start music | The chin reads as one element with one label ("Now playing, *title* by *artist*"), not a container to navigate into. Decorative art and the battery gauge glyph do not announce themselves. |
| A9 | **VoiceOver — media transport** | VO into the expanded panel | Every transport button has a name, and stateful ones have a value: Shuffle On/Off, Repeat, Play/Pause, Favorite On/Off, Volume *n* percent, Playback position with a time value. Nothing reads as "button". |
| A10 | **VoiceOver — shelf** | Drop three files, VO onto a chip | Chip reads its file name, has the button role, and offers actions: default (open), "Quick Look", "Remove". Verify each action actually fires — the chip's pointer handling is a raw `NSView`, so this is the only keyboard/VO path to it. |
| A11 | **VoiceOver — calendar** | VO down the agenda | Each row reads "*title*, *time*", completed reminders say "completed", the colour bar and the duplicated time column stay silent. The reminder checkbox reads "Mark as complete" / "Mark as incomplete" and toggles. |
| A12 | **VoiceOver — settings** | VO through Settings, especially the music slot configurator | Each of the five slots reads "Slot *n*, *control*" or "Slot *n*, empty" and offers "Clear slot". Each palette item is a real button ("Add Shuffle to the next free slot") and activates with Space. |
| A13 | **VoiceOver — onboarding and permissions** | Fresh install with VO on | Every permission row reads its title, its detail, and its Grant button. Granted rows announce "Granted". |
| A14 | **Keyboard only**, no pointer | Open with ⇧⌘I, dismiss with Escape, reopen, dismiss by toggling | The shortcut opens and closes the same state. Escape works only while the panel is open. Neither ever steals focus from the frontmost app — type into TextEdit throughout and confirm no keystroke is lost. |
| A15 | **Keyboard in Settings** | Tab through every Settings pane | Every control takes focus in visual order with a visible focus ring, including the slot palette buttons. |
| A16 | **Hover disabled** | Turn off open-on-hover | Click, downward pan, and the global shortcut still open the panel. Nothing is hover-only. |
| A17 | **Hit targets** | Accessibility Inspector, expanded panel | Every interactive element is at least 28 × 28 pt. |
| A18 | **Accessibility Inspector audit** | Run the audit on the expanded panel and on each Settings pane | No critical or high-severity issue. |
| A19 | **Switch Control / Full Keyboard Access** | Turn on Full Keyboard Access and try to reach the panel | Expected outcome today: **you cannot.** See [Known gaps](#5-known-gaps). Confirm the failure is only "unreachable", not "reachable and broken". |

---

## 4. Per-area checklist

### 4.1 Lifecycle recovery — Blocking

| Do | Correct |
|---|---|
| Sleep the Mac, wake it. 20 cycles. | Panel returns to idle on the right display, media info is current, HUD interception still works. |
| Lock the screen, unlock. Screen saver in and out. | No panel drawn over the login window or the saver. Idle after unlock. |
| Leave idle eight hours, then use it. | No stale track, no dead window, memory growth ≤ 25 MiB or 10%. |
| Fast user switch away and back. | One panel, one set of windows, no duplicate menu bar item. |
| Log out and back in. | Launch-at-login (if enabled) restores exactly one instance. |

### 4.2 Position and obstruction — Blocking

| Do | Correct |
|---|---|
| Run through every arrangement in §2. | No clipping, no menu-bar obstruction, no focus theft, hit areas match what is drawn. |
| Click precisely on the menu bar to either side of the panel while idle. | The menu opens. FlowDock does not swallow the click. |
| Open a menu bar extra directly under the anchor. | Menu draws above the panel or the panel yields; the menu is usable either way. |

### 4.3 System feedback and native controls — Blocking

| Do | Correct |
|---|---|
| Press volume, brightness, and keyboard-backlight keys with HUD replacement on and off. | Exactly one HUD — FlowDock's or the system's, never both. The underlying value actually changes. |
| Hold Option with a volume key. | Whatever `optionKeyAction` promises, and the system's own Option behaviour is not broken. |
| Switch output to **AirPods**, then a **USB DAC**, then a **multichannel/aggregate device**. | Level readout tracks the new device, the device name in the pill is right, and volume keys still work on all three. Multichannel devices that report no scalar volume must degrade to "unsupported", not to a stuck bar. |
| Non-backlit external keyboard, then a backlit one. | Backlight HUD appears only where a backlight exists. |
| External keyboard media keys, and a keyboard with an F-row instead of media keys. | Media keys route to the frontmost player; F-keys are untouched. |
| Quit FlowDock with the HUD replacement enabled. | System HUDs come back immediately. |

### 4.4 Media

| Do | Correct |
|---|---|
| Apple Music, Spotify, YouTube Music, and a generic AVPlayer page in Safari. | Title, artist, artwork, duration, and progress are accurate and update. Source switching does not strand the old source's state. |
| Scrub, then let it play for two minutes. | Position does not jump back after the seek settles. |
| Play a track with a very long title, then a CJK and an RTL title. | Marquee or truncation, never overlap. System font fallback, no missing glyphs. |
| Pause, leave paused for ten minutes. | Visualiser stops; nothing polls at the playing rate. |
| Favourite / shuffle / repeat on a source that does not support them. | Control is disabled and reads as disabled, not silently inert. |

### 4.5 Shelf and drag-and-drop

| Do | Correct |
|---|---|
| Drag in from **Finder, Mail, Outlook, Photos, Slack**, and a browser (file, image, link, selected text). | Each lands as the right kind of item with the right name and thumbnail. Promised files resolve; nothing lands as a zero-byte placeholder. |
| Drag out to **Finder, Mail compose, Outlook compose, Slack, Photos**. | The file arrives intact. With `copyOnDrag` off, a move is a move. |
| Drag out, then cancel over an invalid target. | Item stays on the shelf; no stuck drag image; no leaked security-scoped access. |
| Multi-select and drag all of them. | All arrive. `autoRemoveShelfItems` removes exactly the ones that landed. |
| Restart the app with items on the shelf. | Bookmarks resolve; items that no longer exist are cleaned up, not left as broken chips. |
| Drop onto the closed notch while another app is full screen. | Panel expands to receive and settles closed afterwards. |

### 4.6 Calendar

| Do | Correct |
|---|---|
| A **real** account — iCloud plus Google or Exchange — with a full day. | All events appear once. No duplicates across delegated calendars. |
| Cross midnight with the app open. | The day rolls over without a relaunch. |
| All-day events, multi-day events, declined invitations, recurring events with exceptions. | Filtered and labelled as the settings promise. |
| A day with 30+ items. | Scrolls smoothly; auto-scroll lands on the next event, not the top. |
| Revoke Calendar access in System Settings while running. | Falls back to the permission prompt; no crash, no empty silent panel. |
| Toggle Reminders completion from the panel. | Reflected in Reminders.app within a few seconds. |

### 4.7 Install, update, permissions

| Do | Correct |
|---|---|
| Fresh install on a Mac that has never run FlowDock. | Onboarding appears once; each permission prompt is the real system prompt. |
| Deny every permission, then grant them from Settings. | Each surface recovers without a relaunch. |
| Revoke Accessibility while running. | One clear prompt, not a stack of HUDs. |
| Run an update end to end. | Helper is re-authorized, settings survive, no duplicate login item. |
| Uninstall. | No leftover login item, helper, or window. |

### 4.8 Resource use

Measure with the panel idle and the Mac otherwise quiet. See QUALITY.md for the numbers.

| Do | Correct |
|---|---|
| Ten idle minutes, Activity Monitor + `powermetrics`. | Median CPU ≤ 1%, RSS ≤ 200 MiB, wakeups ≤ 2/s. |
| Same, with music playing. | No busy-wait; the 0.1 s scrubber tick is the ceiling, not a floor. |
| Eight-hour soak. | Memory growth ≤ 25 MiB or 10%. |
| Battery: unplug and use normally for an hour. | FlowDock does not appear in "Apps Using Significant Energy". |

---

## 5. Known gaps

Confirm these behave as described rather than treating them as bugs found in the field. They are decisions, and where they are debt they are named as debt.

- **Nothing in the panel takes keyboard focus.** The panel is a non-activating window that cannot become key, because INTERACTION.md forbids taking focus from the frontmost app. The consequence is that Tab, Full Keyboard Access, and Switch Control cannot reach the panel's controls at all; the keyboard reaches FlowDock only through the global toggle and Escape. VoiceOver *can* read and activate the panel through the accessibility tree, which is why every control there carries a label and an action. Closing this properly needs a focus model that INTERACTION.md does not yet have — check A19 records the current state, it does not accept it.
- **Contextual dwell does not extend for VoiceOver.** INTERACTION.md §Timing asks for the 1.5 s dwell to stretch to the length of its announcement when VoiceOver is running; both `ActivityStore.contextualDwell` and the feedback pill's expiry are still fixed. A VoiceOver user may lose a HUD mid-sentence.
- **No announcement on state entry.** A contextual state is readable but does not post an announcement. This is deliberate for volume and brightness — VoiceOver already speaks those itself, and a second announcement would double up — but it means a system-caused activity can pass unnoticed.
- **Shelf reordering and the slot configurator's drag-to-reorder are pointer-only.** Assignment and clearing have keyboard/VO paths; changing the *order* still requires a drag.
- **The system feedback pill uses fixed 11 pt and 15 pt type** to match the system HUD it stands in for; it does not scale with larger text. The panel's own text does.
