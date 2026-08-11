# FlowDock Roadmap

FlowDock is an open-source activity layer for macOS: calm when idle, useful in context, and deliberate when expanded.

This roadmap tracks product outcomes rather than implementation details. It should be updated as work progresses and revisited when product learning changes the order.

## Progress

- [x] Complete
- [ ] Planned

## 1. Establish the FlowDock foundation

- [x] Fork BoringNotch as the starting point
- [x] Define the FlowDock name and initial product direction
- [x] Complete the FlowDock identity across the app, repository, distribution, and community surfaces
- [x] Preserve required open-source licensing, attribution, and contributor history
- [x] Document the inherited capabilities, known limitations, and supported Mac configurations
- [x] Establish a reliable baseline for building, testing, and tag-driven releases
- [x] Define measurable standards for responsiveness, stability, resource use, accessibility, and visual quality

## 2. Build the core FlowDock experience

- [x] Define the visual language for layout, typography, materials, spacing, and iconography
- [x] Define a consistent progression from idle to contextual, persistent, and expanded experiences
- [x] Make every transition feel anchored to the notch or top-of-screen origin
- [x] Establish consistent interaction behavior across hover, click, keyboard, gesture, drag, and dismissal
- [x] Establish clear rules for activity priority, coexistence, interruption, and expiration
- [x] Support reduced motion and other core accessibility needs from the start
- [x] Ensure the experience works coherently on notch and non-notch displays, including multiple displays

### Sequencing

Section 2 builds the shell and nothing else. No capability moves into it — the first surface a user sees in the new experience arrives in section 3.

The shell is the state store that replaces `sneakPeek` and `expandingView`, the contract every activity declares itself through, the anchored window and geometry, the one shared transition, input handling, and accessibility scaffolding. It is specified by [DESIGN.md](DESIGN.md) and [INTERACTION.md](INTERACTION.md) and gated by [QUALITY.md](QUALITY.md).

The backend is reused, not rewritten or copied: `managers/`, `MediaControllers/`, `Providers/`, `observers/`, `XPCHelperClient/`, and the shelf services already do their jobs and know nothing about the notch.

Section 2 work landed in `FlowDock/Experience/` behind a debug default while the inherited interface remained the one users got. Section 3 then ported one capability per change: its activity was added and its inherited view deleted in the same change, so nothing existed in both. With the last capability landed, the flag is gone, the inherited shell is deleted, and `Experience/` has been flattened back into `FlowDock/`.

## 3. Bring existing capabilities into the new experience

- [x] Migrate music playback, source selection, lyrics, and playback controls into the FlowDock experience
- [x] Migrate volume, brightness, keyboard backlight, microphone, and other system feedback
- [x] Migrate battery and charging activities
- [x] Migrate calendar and reminders
- [x] Migrate the existing file shelf, sharing, preview, and file actions into the FlowDock drop experience
- [x] Reassess the camera mirror and other inherited secondary features against the product direction
- [x] Replace the inherited onboarding, settings, menu bar, and update experiences
- [x] Remove or retire inherited product elements that do not fit FlowDock

## 4. Eliminate inherited critical failures

- [x] Recover reliably after sleep, wake, lock, screen saver, and long idle periods
- [x] Keep the interface anchored and non-disruptive across full-screen apps, spaces, display changes, docking, and clamshell use
- [x] Prevent clipping, menu bar obstruction, focus theft, and incorrect hit areas on notch and non-notch displays
- [x] Ensure system feedback never blocks, changes, or misroutes native volume, brightness, backlight, microphone, or media controls
- [x] Handle external displays, alternate audio devices, AirPods, external keyboards, and third-party display tools without breaking their controls
- [x] Keep media information, progress, artwork, source switching, and source-specific actions accurate
- [x] Make file drag-and-drop dependable across common source and destination apps without stuck or lost items
- [x] Keep calendar dates, reminders, scrolling, and long content correct
- [x] Make state changes and animations smooth, interruptible, and free of visible jumps, flashes, or stale content
- [x] Minimize idle CPU use, memory, wakeups, and battery impact
- [x] Make installation, updates, permission recovery, and uninstallation dependable
- [x] Validate the experience across supported hardware, display arrangements, and accessibility settings
- [ ] Run a focused preview program and resolve release-blocking feedback

## 5. Deepen the flagship activities

- [x] Expand music with reliable generic playback, richer context, queues, lyrics, and capability-aware controls
- [x] Add a first-class notification experience with useful grouping and actions where macOS permits
- [x] Add Bluetooth and headphone connection, battery, and device-status activities
- [x] Add dependable download and progress activities
- [x] Add timers, meeting actions and countdowns, and richer calendar context
- [x] Let users control which activities appear and how they are prioritized

## 6. Turn the drop experience into a workflow tool

- [x] Make drag-and-drop a fast, dependable top-of-screen interaction
- [x] Support selection, clearing, keyboard actions, and other essential shelf management
- [x] Make AirDrop, system sharing, and moving content between apps dependable
- [x] Provide a focused set of file actions, including preview, compression, image conversion, and background removal
- [x] Make available actions discoverable without crowding the primary experience
- [x] Validate which workflows deserve to remain built in and which belong in extensions

The verdict on which drop workflows FlowDock ships and which belong to extensions is in [WORKFLOWS.md](WORKFLOWS.md).

## 7. Open FlowDock to extensions

- [x] Define the boundaries and safety model for third-party activities and actions
- [x] Provide a stable way for extensions to supply compact and expanded experiences
- [x] Let extensions participate in activity priority and lifecycle rules
- [x] Publish developer documentation and a small set of example extensions
- [x] Use extensions for specialized music services, productivity tools, developer activities, weather, and other non-core integrations
- [x] Create a trustworthy discovery and distribution path for community extensions

The boundary and safety model third-party activities live behind is in [EXTENSIONS.md](EXTENSIONS.md), the developer guide is [BUILDING-EXTENSIONS.md](BUILDING-EXTENSIONS.md), and what listing an extension means is in [DIRECTORY.md](DIRECTORY.md).

## 8. Prepare for sustainable public growth

- [x] Publish clear installation, update, support, privacy, security, and contribution guidance
- [ ] Establish dependable signed release and update processes
- [x] Create a feedback loop for bugs, feature requests, and extension proposals
- [x] Define release channels and compatibility expectations
- [ ] Launch FlowDock publicly with source, downloads, and attribution in place
- [ ] Decide whether optional hosted or supporter services are worth pursuing without limiting the open core

## Later, if validated

- [ ] App switching
- [ ] Transcription and other media utilities
- [ ] Cloud-backed sharing or sync
- [ ] Managed deployment for organizations
