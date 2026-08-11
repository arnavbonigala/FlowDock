//
//  SettingsView.swift
//  FlowDock
//
//  Created by Richard Kunkli on 07/08/2024.
//

import Defaults
import KeyboardShortcuts
import LaunchAtLogin
import Sparkle
import SwiftUI

struct SettingsView: View {
    @State private var selectedPane: Pane = .activities
    @Default(.useCustomAccentColor) private var useCustomAccentColor
    @Default(.customAccentColorData) private var customAccentColorData

    let updaterController: SPUStandardUpdaterController?

    init(updaterController: SPUStandardUpdaterController? = nil) {
        self.updaterController = updaterController
    }

    enum Pane: String, Hashable, CaseIterable {
        case activities, music, notifications, systemFeedback, battery, devices, downloads, calendar, shelf
        case general, appearance, shortcuts, about

        var title: String {
            switch self {
            case .activities: "All activities"
            case .music: "Music"
            case .notifications: "Notifications"
            case .systemFeedback: "System feedback"
            case .battery: "Battery"
            case .devices: "Devices"
            case .downloads: "Downloads"
            case .calendar: "Calendar"
            case .shelf: "Shelf"
            case .general: "General"
            case .appearance: "Appearance"
            case .shortcuts: "Shortcuts"
            case .about: "About"
            }
        }

        var symbol: String {
            switch self {
            case .activities: "square.stack.3d.up"
            case .music: "play.laptopcomputer"
            case .notifications: "bell.badge"
            case .systemFeedback: "dial.medium"
            case .battery: "battery.100.bolt"
            case .devices: "airpods"
            case .downloads: "arrow.down.circle"
            case .calendar: "calendar"
            case .shelf: "tray.full"
            case .general: "gear"
            case .appearance: "paintbrush"
            case .shortcuts: "keyboard"
            case .about: "info.circle"
            }
        }
    }

    var body: some View {
        NavigationSplitView {
            List(selection: $selectedPane) {
                Section("Activities") {
                    ForEach([Pane.activities, .music, .notifications, .systemFeedback, .battery, .devices, .downloads, .calendar, .shelf], id: \.self) { pane in
                        NavigationLink(value: pane) {
                            Label(pane.title, systemImage: pane.symbol)
                        }
                    }
                }
                Section("App") {
                    ForEach([Pane.general, .appearance, .shortcuts, .about], id: \.self) { pane in
                        NavigationLink(value: pane) {
                            Label(pane.title, systemImage: pane.symbol)
                        }
                    }
                }
            }
            .listStyle(.sidebar)
            .tint(.effectiveAccent)
            .toolbar(removing: .sidebarToggle)
            .navigationSplitViewColumnWidth(200)
        } detail: {
            Group {
                switch selectedPane {
                case .activities: ActivitySettings()
                case .music: MusicSettings()
                case .notifications: NotificationSettings()
                case .systemFeedback: SystemFeedbackSettings()
                case .battery: BatterySettings()
                case .devices: DeviceSettings()
                case .downloads: DownloadSettings()
                case .calendar: CalendarSettings()
                case .shelf: ShelfSettings()
                case .general: GeneralSettings()
                case .appearance: AppearanceSettings()
                case .shortcuts: ShortcutsSettings()
                case .about: AboutSettings(updater: updaterController?.updater)
                }
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            .navigationTitle(selectedPane.title)
        }
        .navigationSplitViewStyle(.balanced)
        .toolbar(removing: .sidebarToggle)
        .formStyle(.grouped)
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .tint(.effectiveAccent)
    }
}

// MARK: - Activities

struct MusicSettings: View {
    @Default(.mediaController) private var mediaController
    @Default(.waitInterval) private var waitInterval
    @Default(.hideNotchOption) private var hideNotchOption
    @Default(.sliderColor) private var sliderColor

    var body: some View {
        Form {
            Section {
                Picker("Music source", selection: $mediaController) {
                    ForEach(availableMediaControllers) { controller in
                        Text(controller.rawValue).tag(controller)
                    }
                }
                .onChange(of: mediaController) { _, _ in
                    NotificationCenter.default.post(name: .mediaControllerChanged, object: nil)
                }
            } header: {
                Text("Source")
            } footer: {
                if MusicManager.shared.isNowPlayingDeprecated {
                    Text("YouTube Music requires [Pear Desktop](https://github.com/pear-devs/pear-desktop) to be installed.")
                } else {
                    Text("Now Playing works with every media app. The others talk to one app directly.")
                }
            }

            Section {
                Defaults.Toggle(key: .showMusicActivity) {
                    Text("Show music activity")
                }
                Stepper(value: $waitInterval, in: 0...10, step: 1) {
                    LabeledContent("Inactivity timeout") {
                        Text("\(waitInterval, specifier: "%.0f") seconds")
                    }
                }
                Picker("In full screen", selection: $hideNotchOption) {
                    Text("Hide for all apps").tag(HideNotchOption.always)
                    Text("Hide for the media app only").tag(HideNotchOption.nowPlayingOnly)
                    Text("Never hide").tag(HideNotchOption.never)
                }
            } header: {
                Text("Activity")
            }

            Section {
                MusicSlotConfigurationView()
                Defaults.Toggle(key: .enableLyrics) {
                    Text("Show the line playing, below the artist")
                }
            } header: {
                Text("Controls")
            } footer: {
                Text("Choose which controls appear in the expanded player. Volume expands when active.")
            }

            Section {
                Defaults.Toggle(key: .coloredSpectrogram) {
                    Text("Tint the spectrogram with the artwork")
                }
                Defaults.Toggle(key: .lightingEffect) {
                    Text("Glow behind the artwork")
                }
                Picker("Progress color", selection: $sliderColor) {
                    ForEach(SliderColorEnum.allCases, id: \.self) { option in
                        Text(option.rawValue).tag(option)
                    }
                }
            } header: {
                Text("Appearance")
            }
        }
    }

    private var availableMediaControllers: [MediaControllerType] {
        MusicManager.shared.isNowPlayingDeprecated
            ? MediaControllerType.allCases.filter { $0 != .nowPlaying }
            : MediaControllerType.allCases
    }
}

struct ActivitySettings: View {
    @Default(.activityPriority) private var priority
    @Default(.enabledExtensions) private var enabledExtensions
    @ObservedObject private var host = ExtensionHost.shared

    private var entries: [ActivityCatalog.Entry] {
        ActivityCatalog.ordered(priority, including: host.available.map {
            ActivityCatalog.Entry(id: $0.id, name: $0.name, symbol: "puzzlepiece.extension", key: nil, hosted: true)
        })
    }

    private func move(_ entry: ActivityCatalog.Entry, by offset: Int) {
        var ordered = entries
        guard let index = ordered.firstIndex(of: entry),
              ordered.indices.contains(index + offset) else { return }
        ordered.swapAt(index, index + offset)
        priority = ordered.map(\.id)
    }

    var body: some View {
        Form {
            Section {
                List {
                    ForEach(entries) { entry in
                        HStack {
                            Label(entry.name, systemImage: entry.symbol)
                                .accessibilityAction(named: "Move up") { move(entry, by: -1) }
                                .accessibilityAction(named: "Move down") { move(entry, by: 1) }
                            Spacer()
                            if let key = entry.key {
                                Defaults.Toggle(key: key) { Text(entry.name) }
                                    .labelsHidden()
                            } else if entry.hosted {
                                Toggle(entry.name, isOn: Binding(
                                    get: { enabledExtensions.contains(entry.id) },
                                    set: { on in
                                        if on {
                                            enabledExtensions.insert(entry.id)
                                        } else {
                                            enabledExtensions.remove(entry.id)
                                        }
                                    }
                                ))
                                .labelsHidden()
                            } else {
                                Text("When active")
                                    .font(.caption)
                                    .foregroundStyle(.secondary)
                            }
                        }
                    }
                    .onMove { source, destination in
                        var ordered = entries
                        ordered.move(fromOffsets: source, toOffset: destination)
                        priority = ordered.map(\.id)
                    }
                }
                .frame(minHeight: 240, maxHeight: .infinity)
            } header: {
                Text("Priority")
            } footer: {
                VStack(alignment: .leading, spacing: 8) {
                    Text("Drag to choose which activity wins when two want the notch at once. Order only decides between activities that are equally close to what you just did: a drag, a volume change, or anything else you caused still comes first.")

                    Text("Extensions are apps you install yourself, and each one stays off until you turn it on. [Reviewed extensions](https://github.com/arnavbonigala/FlowDock/blob/main/DIRECTORY.md)")
                }
            }
        }
    }
}

struct DownloadSettings: View {
    var body: some View {
        Form {
            Section {
                Defaults.Toggle(key: .showDownloads) {
                    Text("Show downloads in progress")
                }
            } footer: {
                Text("Files arriving in the Downloads folder show their progress at the notch until they finish, then show once more as complete. Safari reports how much is left; other browsers only report how much has arrived. Shelf actions that take a moment — compressing, converting, building a PDF, removing a background — report here too.")
            }
        }
    }
}

struct DeviceSettings: View {
    var body: some View {
        Form {
            Section {
                Defaults.Toggle(key: .showDeviceStatus) {
                    Text("Show connected devices")
                }
            } footer: {
                Text("Bluetooth headphones, keyboards, mice, and other paired devices announce themselves at the notch when they connect or disconnect, and their battery appears in the expanded panel when the device reports it.")
            }
        }
    }
}

struct NotificationSettings: View {
    @State private var accessibilityAuthorized = false

    var body: some View {
        Form {
            Section {
                if accessibilityAuthorized {
                    Defaults.Toggle(key: .showNotifications) {
                        Text("Show incoming notifications")
                    }
                } else {
                    LabeledContent("Show incoming notifications") {
                        Button("Grant accessibility access") {
                            XPCHelperClient.shared.requestAccessibilityAuthorization()
                        }
                    }
                    LabeledContent("Nothing happened when you granted it?") {
                        Button("Open Accessibility settings") {
                            if let url = URL(string: "x-apple.systempreferences:com.apple.preference.security?Privacy_Accessibility") {
                                NSWorkspace.shared.open(url)
                            }
                        }
                    }
                }
            } footer: {
                Text(accessibilityAuthorized
                    ? "Notifications arriving on this Mac appear at the notch, grouped by app, with open and dismiss actions. macOS exposes no other route to another app's notifications, so this reads the banners through accessibility."
                    : "Notifications arriving on this Mac appear at the notch, grouped by app, with open and dismiss actions. macOS exposes no other route to another app's notifications, so this reads the banners through accessibility and shows nothing without that access. macOS drops that access when FlowDock is moved or updated, and it then ignores the request above because a stale entry already exists. Open Accessibility settings, remove FlowDock, and add it again.")
            }

            Section {
                Defaults.Toggle(key: .showCallerPhotos) {
                    Text("Show the caller's photo")
                }
            } footer: {
                Text("An incoming call names whoever is ringing. Finding their photo means asking your address book for that name, which macOS asks your permission for the first time a call arrives. Declining costs nothing: the call shows their initials instead. Nothing leaves your Mac.")
            }
        }
        .task {
            accessibilityAuthorized = await XPCHelperClient.shared.isAccessibilityAuthorized()
        }
        .onReceive(NotificationCenter.default.publisher(for: .accessibilityAuthorizationChanged)) { notification in
            if let granted = notification.userInfo?["granted"] as? Bool {
                accessibilityAuthorized = granted
            }
        }
    }
}

struct SystemFeedbackSettings: View {
    @Default(.hudReplacement) private var hudReplacement
    @Default(.optionKeyAction) private var optionKeyAction
    @State private var accessibilityAuthorized = false

    var body: some View {
        Form {
            Section {
                if accessibilityAuthorized {
                    Defaults.Toggle(key: .hudReplacement) {
                        Text("Replace the system HUD")
                    }
                } else {
                    LabeledContent("Replace the system HUD") {
                        Button("Grant accessibility access") {
                            XPCHelperClient.shared.requestAccessibilityAuthorization()
                        }
                    }
                    LabeledContent("Nothing happened when you granted it?") {
                        Button("Open Accessibility settings") {
                            if let url = URL(string: "x-apple.systempreferences:com.apple.preference.security?Privacy_Accessibility") {
                                NSWorkspace.shared.open(url)
                            }
                        }
                    }
                }
            } footer: {
                Text(accessibilityAuthorized
                    ? "Volume, display brightness, and keyboard brightness appear at the notch instead of the middle of the screen. Accessibility access is required to see the key presses."
                    : "Volume, display brightness, and keyboard brightness appear at the notch instead of the middle of the screen. Accessibility access is required to see the key presses. macOS drops that access when FlowDock is moved or updated, and it then ignores the request above because a stale entry already exists. Open Accessibility settings, remove FlowDock, and add it again.")
            }

            Section {
                Picker("Option key on media keys", selection: $optionKeyAction) {
                    ForEach(OptionKeyAction.allCases) { action in
                        Text(action.rawValue).tag(action)
                    }
                }
            }
            .disabled(!hudReplacement)
        }
        .task {
            accessibilityAuthorized = await XPCHelperClient.shared.isAccessibilityAuthorized()
        }
        .onReceive(NotificationCenter.default.publisher(for: .accessibilityAuthorizationChanged)) { notification in
            if let granted = notification.userInfo?["granted"] as? Bool {
                accessibilityAuthorized = granted
            }
        }
    }
}

struct BatterySettings: View {
    var body: some View {
        Form {
            Section {
                Defaults.Toggle(key: .showBatteryIndicator) {
                    Text("Show the battery indicator")
                }
                Defaults.Toggle(key: .showBatteryPercentage) {
                    Text("Show the percentage")
                }
                Defaults.Toggle(key: .showPowerStatusNotifications) {
                    Text("Announce plugging in and unplugging")
                }
            }
        }
    }
}

struct CalendarSettings: View {
    @ObservedObject private var calendarManager = CalendarManager.shared
    @Default(.showCalendar) private var showCalendar

    var body: some View {
        Form {
            Section {
                Defaults.Toggle(key: .showCalendar) {
                    Text("Show the agenda")
                }
                Defaults.Toggle(key: .showMeetingCountdown) {
                    Text("Count down to the next meeting")
                }
                Defaults.Toggle(key: .hideAllDayEvents) {
                    Text("Hide all-day events")
                }
                Defaults.Toggle(key: .showFullEventTitles) {
                    Text("Always show full event titles")
                }
                Defaults.Toggle(key: .autoScrollToNextEvent) {
                    Text("Scroll to the next event")
                }
                Defaults.Toggle(key: .hideCompletedReminders) {
                    Text("Hide completed reminders")
                }
            }

            Section("Calendars") {
                calendarList(
                    authorized: calendarManager.calendarAuthorizationStatus == .fullAccess,
                    calendars: calendarManager.eventCalendars,
                    deniedMessage: "FlowDock does not have access to your calendars.",
                    privacyPane: "Privacy_Calendars"
                )
            }

            Section("Reminders") {
                calendarList(
                    authorized: calendarManager.reminderAuthorizationStatus == .fullAccess,
                    calendars: calendarManager.reminderLists,
                    deniedMessage: "FlowDock does not have access to your reminders.",
                    privacyPane: "Privacy_Reminders"
                )
            }
        }
        .onAppear {
            Task { await calendarManager.requestAccess() }
        }
    }

    @ViewBuilder
    private func calendarList(
        authorized: Bool,
        calendars: [CalendarModel],
        deniedMessage: String,
        privacyPane: String
    ) -> some View {
        if authorized {
            ForEach(calendars, id: \.id) { calendar in
                Toggle(
                    isOn: Binding(
                        get: { calendarManager.getCalendarSelected(calendar) },
                        set: { isSelected in
                            Task { await calendarManager.setCalendarSelected(calendar, isSelected: isSelected) }
                        }
                    )
                ) {
                    Text(calendar.title)
                }
                .accentColor(lighterColor(from: calendar.color))
                .disabled(!showCalendar)
            }
        } else {
            LabeledContent(deniedMessage) {
                Button("Open System Settings") {
                    if let url = URL(string: "x-apple.systempreferences:com.apple.preference.security?\(privacyPane)") {
                        NSWorkspace.shared.open(url)
                    }
                }
            }
        }
    }
}

func lighterColor(from nsColor: NSColor, amount: CGFloat = 0.14) -> Color {
    let srgb = nsColor.usingColorSpace(.sRGB) ?? nsColor
    var (r, g, b, a): (CGFloat, CGFloat, CGFloat, CGFloat) = (0, 0, 0, 0)
    srgb.getRed(&r, green: &g, blue: &b, alpha: &a)

    func lighten(_ c: CGFloat) -> CGFloat {
        min(max(c + (1.0 - c) * amount, 0), 1)
    }

    return Color(red: Double(lighten(r)), green: Double(lighten(g)), blue: Double(lighten(b)), opacity: Double(a))
}

struct ShelfSettings: View {
    @Default(.quickShareProvider) private var quickShareProvider
    @StateObject private var quickShareService = QuickShareService.shared

    var body: some View {
        Form {
            Section {
                Defaults.Toggle(key: .shelfEnabled) {
                    Text("Accept dropped files")
                }
                Defaults.Toggle(key: .copyOnDrag) {
                    Text("Copy items when dragging out")
                }
                Defaults.Toggle(key: .autoRemoveShelfItems) {
                    Text("Remove items after dragging out")
                }
            }

            Section {
                Picker("Quick share with", selection: $quickShareProvider) {
                    ForEach(quickShareService.availableProviders, id: \.id) { provider in
                        Label {
                            Text(provider.id)
                        } icon: {
                            if let data = provider.imageData, let image = NSImage(data: data) {
                                Image(nsImage: image).resizable().aspectRatio(contentMode: .fit)
                            } else {
                                Image(systemName: "square.and.arrow.up")
                            }
                        }
                        .tag(provider.id)
                    }
                }
            } footer: {
                Text("The share button in the shelf hands files to this service.")
            }
        }
        .task {
            await QuickShareService.shared.discoverAvailableProviders()
        }
    }
}

// MARK: - App

struct GeneralSettings: View {
    @ObservedObject private var coordinator = FlowDockViewCoordinator.shared
    @Default(.showOnAllDisplays) private var showOnAllDisplays
    @Default(.automaticallySwitchDisplay) private var automaticallySwitchDisplay
    @Default(.openNotchOnHover) private var openNotchOnHover
    @Default(.enableGestures) private var enableGestures
    @Default(.minimumHoverDuration) private var minimumHoverDuration
    @Default(.gestureSensitivity) private var gestureSensitivity
    @State private var screens: [(uuid: String, name: String)] = GeneralSettings.currentScreens()

    var body: some View {
        Form {
            Section {
                LaunchAtLogin.Toggle("Launch at login")
                Defaults.Toggle(key: .menubarIcon) {
                    Text("Show the menu bar icon")
                }
            } footer: {
                Text("Without it, right-click the notch to reach settings or quit.")
            }

            Section {
                Defaults.Toggle(key: .showOnAllDisplays) {
                    Text("Show on every display")
                }
                .onChange(of: showOnAllDisplays) {
                    NotificationCenter.default.post(name: .showOnAllDisplaysChanged, object: nil)
                }
                Defaults.Toggle(key: .automaticallySwitchDisplay) {
                    Text("Follow the active display")
                }
                .onChange(of: automaticallySwitchDisplay) {
                    NotificationCenter.default.post(name: .automaticallySwitchDisplayChanged, object: nil)
                }
                .disabled(showOnAllDisplays)
                Picker("Preferred display", selection: $coordinator.preferredScreenUUID) {
                    ForEach(screens, id: \.uuid) { screen in
                        Text(screen.name).tag(screen.uuid as String?)
                    }
                }
                .disabled(showOnAllDisplays || automaticallySwitchDisplay)
            } header: {
                Text("Displays")
            } footer: {
                Text("A preferred display is used when FlowDock is neither on every display nor following the active one.")
            }
            .onChange(of: NSScreen.screens) {
                screens = GeneralSettings.currentScreens()
            }

            Section {
                Defaults.Toggle(key: .openNotchOnHover) {
                    Text("Open on hover")
                }
                if openNotchOnHover {
                    Slider(value: $minimumHoverDuration, in: 0...1, step: 0.1) {
                        LabeledContent("Hover delay") {
                            Text("\(minimumHoverDuration, specifier: "%.1f")s")
                        }
                    }
                }
                Defaults.Toggle(key: .enableHaptics) {
                    Text("Haptic feedback")
                }
            } header: {
                Text("Opening")
            }

            Section {
                Defaults.Toggle(key: .enableGestures) {
                    Text("Enable gestures")
                }
                if enableGestures {
                    Defaults.Toggle(key: .closeGestureEnabled) {
                        Text("Swipe up to close")
                    }
                    Picker("Gesture sensitivity", selection: $gestureSensitivity) {
                        Text("High").tag(CGFloat(100))
                        Text("Medium").tag(CGFloat(200))
                        Text("Low").tag(CGFloat(300))
                    }
                }
            } header: {
                Text("Gestures")
            } footer: {
                Text("Two-finger swipe down on the notch to open, swipe up to close.")
            }

            Section {
                Defaults.Toggle(key: .showOnLockScreen) {
                    Text("Show on the lock screen")
                }
                Defaults.Toggle(key: .hideFromScreenRecording) {
                    Text("Hide from screen recordings")
                }
            } header: {
                Text("Privacy")
            } footer: {
                Text("A locked Mac shows the clock, what is playing, and how long until a timer, a meeting, or a full battery. It never shows a notification, a caller, a filename, or the name of the meeting — those belong to whoever can unlock it.")
            }
        }
    }

    private static func currentScreens() -> [(uuid: String, name: String)] {
        NSScreen.screens.compactMap { screen in
            guard let uuid = screen.displayUUID else { return nil }
            return (uuid, screen.localizedName)
        }
    }
}

struct AppearanceSettings: View {
    @Default(.useCustomAccentColor) private var useCustomAccentColor
    @Default(.customAccentColorData) private var customAccentColorData
    @Default(.surfaceAppearance) private var surfaceAppearance
    @State private var customAccentColor: Color = .accentColor

    var body: some View {
        Form {
            Section {
                Picker("Accent color", selection: $useCustomAccentColor) {
                    Text("System").tag(false)
                    Text("Custom").tag(true)
                }
                .pickerStyle(.segmented)

                if useCustomAccentColor {
                    ColorPicker("Custom color", selection: $customAccentColor, supportsOpacity: false)
                        .onChange(of: customAccentColor) { save(customAccentColor) }
                }
            } footer: {
                Text("The accent marks progress, selection, and activity. It is never used for text.")
            }

            Section {
                Defaults.Toggle(key: .enableShadow) {
                    Text("Shadow under the panel")
                }

                Picker("Surface", selection: $surfaceAppearance) {
                    ForEach(SurfaceAppearance.allCases) { appearance in
                        Text(appearance.rawValue).tag(appearance)
                    }
                }
                .pickerStyle(.segmented)
            } header: {
                Text("Panel")
            } footer: {
                Text("A display with a notch is always black, so the surface and the bezel around it are one piece of hardware. A display without one has nothing to match, so it can be glass, glass in your accent color, or a dark blur that takes its color from the wallpaper behind it. Reduce Transparency turns every surface back to black.")
            }
        }
        .onAppear(perform: loadCustomColor)
    }

    private func save(_ color: Color) {
        customAccentColorData = try? NSKeyedArchiver.archivedData(
            withRootObject: NSColor(color), requiringSecureCoding: false)
    }

    private func loadCustomColor() {
        guard let data = customAccentColorData,
              let nsColor = try? NSKeyedUnarchiver.unarchivedObject(ofClass: NSColor.self, from: data)
        else { return }
        customAccentColor = Color(nsColor: nsColor)
    }
}

struct ShortcutsSettings: View {
    var body: some View {
        Form {
            Section {
                KeyboardShortcuts.Recorder("Open the notch:", name: .toggleNotchOpen)
                KeyboardShortcuts.Recorder("Keep the display awake:", name: .toggleKeepAwake)
                KeyboardShortcuts.Recorder("Open the newest notification:", name: .openNewestNotification)
                KeyboardShortcuts.Recorder("Dismiss the newest notification:", name: .dismissNewestNotification)
            }
            Section {
                KeyboardShortcuts.Recorder("Close:", name: .dismissExpanded)
                KeyboardShortcuts.Recorder("Select every item:", name: .shelfSelectAll)
                KeyboardShortcuts.Recorder("Copy the selection:", name: .shelfCopySelection)
                KeyboardShortcuts.Recorder("Remove the selection:", name: .shelfRemoveSelected)
                KeyboardShortcuts.Recorder("Clear the shelf:", name: .shelfClear)
            } header: {
                Text("While the panel is open")
            } footer: {
                Text("The panel never takes keyboard focus, so these work as shortcuts and are live only while it is open.")
            }
        }
    }
}

struct AboutSettings: View {
    let updater: SPUUpdater?
    @State private var showBuildNumber = false

    var body: some View {
        Form {
            Section {
                LabeledContent("Version") {
                    Text(showBuildNumber
                        ? "\(Bundle.main.releaseVersionNumber ?? "—") (\(Bundle.main.buildVersionNumber ?? "—"))"
                        : Bundle.main.releaseVersionNumber ?? "—")
                }
                .onTapGesture {
                    withAnimation { showBuildNumber.toggle() }
                }
            }

            if let updater {
                UpdaterSettingsView(updater: updater)
            }

            Section {
                Link("FlowDock on GitHub", destination: URL(string: "https://github.com/arnavbonigala/FlowDock")!)
                Link("GNU GPL v3", destination: URL(string: "https://github.com/arnavbonigala/FlowDock/blob/main/LICENSE")!)
                Link("BoringNotch", destination: URL(string: "https://github.com/TheBoredTeam/boring.notch")!)
            } header: {
                Text("Open source")
            } footer: {
                Text("FlowDock is a modified version of BoringNotch, distributed under the GNU GPL v3. Copyright © FlowDock and BoringNotch contributors.")
            }
        }
        .toolbar {
            if let updater {
                CheckForUpdatesView(updater: updater)
            }
        }
    }
}
