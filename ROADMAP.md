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
- [ ] Define measurable standards for responsiveness, stability, resource use, accessibility, and visual quality

## 2. Build the core FlowDock experience

- [ ] Define the visual language for layout, typography, materials, spacing, and iconography
- [ ] Define a consistent progression from idle to contextual, persistent, and expanded experiences
- [ ] Make every transition feel anchored to the notch or top-of-screen origin
- [ ] Establish consistent interaction behavior across hover, click, keyboard, gesture, drag, and dismissal
- [ ] Establish clear rules for activity priority, coexistence, interruption, and expiration
- [ ] Support reduced motion and other core accessibility needs from the start
- [ ] Ensure the experience works coherently on notch and non-notch displays, including multiple displays

## 3. Bring existing capabilities into the new experience

- [ ] Migrate music playback, source selection, lyrics, and playback controls into the FlowDock experience
- [ ] Migrate volume, brightness, keyboard backlight, microphone, and other system feedback
- [ ] Migrate battery and charging activities
- [ ] Migrate calendar and reminders
- [ ] Migrate the existing file shelf, sharing, preview, and file actions into the FlowDock drop experience
- [ ] Reassess the camera mirror and other inherited secondary features against the product direction
- [ ] Replace the inherited onboarding, settings, menu bar, and update experiences
- [ ] Remove or retire inherited product elements that do not fit FlowDock

## 4. Eliminate inherited critical failures

- [ ] Recover reliably after sleep, wake, lock, screen saver, and long idle periods
- [ ] Keep the interface anchored and non-disruptive across full-screen apps, spaces, display changes, docking, and clamshell use
- [ ] Prevent clipping, menu bar obstruction, focus theft, and incorrect hit areas on notch and non-notch displays
- [ ] Ensure system feedback never blocks, changes, or misroutes native volume, brightness, backlight, microphone, or media controls
- [ ] Handle external displays, alternate audio devices, AirPods, external keyboards, and third-party display tools without breaking their controls
- [ ] Keep media information, progress, artwork, source switching, and source-specific actions accurate
- [ ] Make file drag-and-drop dependable across common source and destination apps without stuck or lost items
- [ ] Keep calendar dates, reminders, scrolling, long content, and camera recovery correct
- [ ] Make state changes and animations smooth, interruptible, and free of visible jumps, flashes, or stale content
- [ ] Minimize idle CPU use, memory, wakeups, and battery impact
- [ ] Make installation, updates, permission recovery, and uninstallation dependable
- [ ] Validate the experience across supported hardware, display arrangements, and accessibility settings
- [ ] Run a focused preview program and resolve release-blocking feedback

## 5. Deepen the flagship activities

- [ ] Expand music with reliable generic playback, richer context, queues, lyrics, and capability-aware controls
- [ ] Add a first-class notification experience with useful grouping and actions where macOS permits
- [ ] Add Bluetooth and headphone connection, battery, and device-status activities
- [ ] Add dependable download and progress activities
- [ ] Add timers, meeting actions and countdowns, and richer calendar context
- [ ] Let users control which activities appear and how they are prioritized

## 6. Turn the drop experience into a workflow tool

- [ ] Make drag-and-drop a fast, dependable top-of-screen interaction
- [ ] Support selection, clearing, keyboard actions, and other essential shelf management
- [ ] Make AirDrop, system sharing, and moving content between apps dependable
- [ ] Provide a focused set of file actions, including preview, compression, image conversion, and background removal
- [ ] Make available actions discoverable without crowding the primary experience
- [ ] Validate which workflows deserve to remain built in and which belong in extensions

## 7. Open FlowDock to extensions

- [ ] Define the boundaries and safety model for third-party activities and actions
- [ ] Provide a stable way for extensions to supply compact and expanded experiences
- [ ] Let extensions participate in activity priority and lifecycle rules
- [ ] Publish developer documentation and a small set of example extensions
- [ ] Use extensions for specialized music services, productivity tools, developer activities, weather, and other non-core integrations
- [ ] Create a trustworthy discovery and distribution path for community extensions

## 8. Prepare for sustainable public growth

- [ ] Publish clear installation, update, support, privacy, security, and contribution guidance
- [ ] Establish dependable signed release and update processes
- [ ] Create a feedback loop for bugs, feature requests, and extension proposals
- [ ] Define release channels and compatibility expectations
- [ ] Launch FlowDock publicly with source, downloads, and attribution in place
- [ ] Decide whether optional hosted or supporter services are worth pursuing without limiting the open core

## Later, if validated

- [ ] App switching
- [ ] Transcription and other media utilities
- [ ] Cloud-backed sharing or sync
- [ ] Managed deployment for organizations
