# FlowDock Extensions

An extension is a third-party activity: someone else's code occupying FlowDock's chin
and panel under FlowDock's rules. This document defines the boundary it lives behind and
the safety model that makes hosting it defensible. The interaction rules it inherits are
in [INTERACTION.md](INTERACTION.md), its visual rules in [DESIGN.md](DESIGN.md), and the
gates it must pass in [QUALITY.md](QUALITY.md). How to actually build one is in
[BUILDING-EXTENSIONS.md](BUILDING-EXTENSIONS.md).

The premise is narrow on purpose. FlowDock does not need a widget market. It needs a way
for the activities it will never build — a Pomodoro, a build monitor, a specialized music
service, a company's deploy status — to be as native as the ones it did.

## The boundary

**Extensions are macOS app extensions.** They are `.appex` bundles that ship inside a
host application, are discovered by the system, run in their own sandboxed process, and
are launched and terminated by the system rather than by FlowDock. FlowDock does not load
plugin bundles, does not `dlopen` anything, and does not execute scripts. There is no
in-process extension surface, and there will not be one.

That single decision carries most of the safety model:

- An extension crash cannot crash FlowDock. The process is not ours.
- An extension cannot read FlowDock's memory, its bookmarks, its shelf, or the user's
  notification text. Nothing is shared but the messages below.
- An extension cannot inherit FlowDock's permissions. Accessibility, calendar access,
  and Apple Events belong to the process that was granted them, and that process does not
  run extension code.
- An extension's own permissions are its own problem. It asks, its host app is what the
  user sees in System Settings, and a denial degrades that extension alone.

**What crosses the boundary.** An extension sends FlowDock an activity declaration and a
view; FlowDock sends back the state that view is being drawn in, and the user's actions
inside it. Views are remote — they render in the extension's process and composite into
FlowDock's window. FlowDock never receives extension code and the extension never
receives FlowDock's view hierarchy.

## What an extension may declare

Everything an activity must declare — class, band, completion — an extension declares
too, in the same words, through the same contract:

| Field | Allowed values | Enforced how |
|---|---|---|
| Identity | A stable string, unique per extension | Namespaced by the extension's bundle identifier; collisions are the host's to prevent, not the extension's to win |
| Class | `contextual` or `persistent` | A contextual activity gets the same 1.5 s dwell as every other; it cannot ask for longer |
| Band | `progress`, `media`, or `ambient` | The three lower bands are unavailable. See below |
| Label | Plain text, for VoiceOver | Required. An activity with no label does not begin |
| Compact content | One leading and one trailing view | Sized by the host; an extension does not choose the chin's width |
| Expanded content | Optional, one panel row | Height is bounded by the host |
| Completion | An explicit end call, or process exit | Either ends the activity |

**Extensions may not take the top three bands.** A drag in progress, system feedback the
user just caused, and system events like power and notifications are FlowDock reporting
on the machine itself. An extension claiming that rank would be claiming the user just
acted on it, which it cannot know. Extensions join `progress`, `media`, or `ambient`, and
inside those bands they are ordered by the same user ranking as everything else.

**Extensions may not enter expanded state.** Invariant 2 is not relaxed for third
parties: nothing but the user opens the panel. An extension cannot expand, cannot demand
focus, cannot present a window, and cannot show an alert.

## What FlowDock builds and what it hosts

The same question the drop experience answered in [WORKFLOWS.md](WORKFLOWS.md), asked of
activities. An activity stays built in when it reports on the machine the user is sitting
at, using something every Mac already has, for everyone rather than for an audience.

| Built in | Because |
|---|---|
| Music: the system's Now Playing, and Apple Music | The machine is playing it; no account of ours |
| System feedback: volume, brightness, backlight, microphone | The user just caused it, and only the host can see it |
| Power, Bluetooth devices, and their batteries | The hardware the user is holding |
| Notifications | The system's own delivery, relayed, never re-sent |
| Downloads and file progress | The machine is doing the work |
| Calendar, meetings, and timers | Time the user is inside, from the account macOS already has |
| The shelf | The drop experience itself |

| An extension | Which part disqualifies it |
|---|---|
| Spotify, Tidal, and other services beyond Now Playing | A specific product's app and account. Where the system reports them, FlowDock already shows them |
| Weather | A network service and a location, for a thing the machine is not doing |
| Pomodoro and habit tracking beyond a plain timer | A method, and people disagree about the method |
| Clipboard history | A store of the user's content with a lifetime and a privacy model of its own |
| Build, deploy, CI, and other developer status | An audience, not a default |
| Assistant and summarizing panels | An account, a network, and a running cost |
| A company's internal status | The company should ship it, and only they can |

The consequence is the same as the drop experience's: this list is closed, and a new
built-in activity requires the table above to change first. Everything else has a
supported way in, which is the point of this document.

## Resource and behavior limits

An extension that erases the product's value is not extensible, it is a regression. The
limits are the host's existing budgets from [QUALITY.md](QUALITY.md), applied per
extension:

- **Idle cost.** An extension that is not currently showing an activity gets no process
  between questions. FlowDock launches it to ask, and releases it when it has nothing to
  say. An extension cannot hold a process open to poll.
- **Update rate.** FlowDock asks each enabled extension for its declaration when it is
  discovered and every fifteen seconds after that, and holds the process only while the
  answer is `live`. An activity therefore begins within fifteen seconds of becoming true,
  and an extension that is off is never asked at all. Nothing an extension does makes this
  faster, because the question is the host's to ask.
- **Answer deadline.** An extension has two seconds to return its declaration when asked.
  One that does not answer is dropped and its process released, because discovery is
  shared: an extension that never replies must not cost every other extension its place.
- **Render deadline.** A remote scene has two seconds to connect and draw. One that does
  not is released along with the rest of that extension: the chin shows the next activity
  down and the extension's activity ends. A scene that fails after it has drawn ends the
  same way.
- **Failure is silent to the user and loud to the developer.** A misbehaving extension
  loses the chin; the user is not shown a diagnostic they did not ask for and cannot act
  on. The reason is available in the extension's own log.

## Trust and distribution

- **Signed and notarized, or not loaded.** FlowDock hosts extensions from applications
  the user installed and macOS validated. There is no override, no developer switch in
  Settings, and no "load unsigned" path in a release build.
- **The user turns each one on.** A newly discovered extension is listed and off. It
  appears in the same Activities pane as everything else, with the same switch and the
  same rank, because to the user it is not a different kind of thing.
- **An extension is uninstalled by deleting its app.** FlowDock owns no extension store
  directory and installs nothing on an extension's behalf.
- **Nothing is sent anywhere.** FlowDock does not report which extensions a user has, and
  does not proxy an extension's network access. An extension that needs the network uses
  its own entitlement, in its own process, under its own privacy policy.

## What this deliberately does not allow

Refusals are part of the contract, and each one has a reason a developer can argue with:

| Not allowed | Because |
|---|---|
| Replacing or restyling the shell | One state, one appearance (invariant 3). The chin is FlowDock's; the content is the extension's |
| Running code at login or in the background | An activity exists when something is happening. A resident process is an app, not an activity |
| Reading other activities' content | Music titles, notification text, shelf contents, and calendar events are the user's, not the ecosystem's |
| Handling media keys, or any global input | Input safety is the one thing FlowDock must never break, and it cannot promise that on someone else's behalf |
| Long-lived storage inside FlowDock's container | An extension keeps its own state in its own container, where the user can find and delete it |
| Being required for FlowDock to work | Every extension is optional, and a missing one leaves no hole |

## Open questions

These are unresolved and should be answered by the first extensions built against this,
not by more of this document:

- Whether an extension needs to update an activity it did not begin in the current
  process lifetime, or whether re-declaring is sufficient.
- Whether a compact view is worth remote rendering at chin size at all, or whether a
  declarative description (glyph, text, progress) would be both cheaper and more
  consistent, with remote views reserved for the panel.
- How an extension asks for the user's attention when the user is not looking, given that
  it may not expand and FlowDock does not post notifications for it.
