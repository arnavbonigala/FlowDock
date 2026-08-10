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
    @State private var selectedPane: Pane = .music
    @State private var accentColorUpdateTrigger = UUID()

    let updaterController: SPUStandardUpdaterController?

    init(updaterController: SPUStandardUpdaterController? = nil) {
        self.updaterController = updaterController
    }

    enum Pane: String, Hashable, CaseIterable {
        case music, systemFeedback, battery, calendar, shelf
        case general, appearance, shortcuts, about

        var title: String {
            switch self {
            case .music: "Music"
            case .systemFeedback: "System feedback"
            case .battery: "Battery"
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
            case .music: "play.laptopcomputer"
            case .systemFeedback: "dial.medium.fill"
            case .battery: "battery.100.bolt"
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
                    ForEach([Pane.music, .systemFeedback, .battery, .calendar, .shelf], id: \.self) { pane in
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
                case .music: MusicSettings()
                case .systemFeedback: SystemFeedbackSettings()
                case .battery: BatterySettings()
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
        .frame(width: 700)
        .tint(.effectiveAccent)
        .id(accentColorUpdateTrigger)
        .onReceive(NotificationCenter.default.publisher(for: .accentColorChanged)) { _ in
            accentColorUpdateTrigger = UUID()
        }
    }
}

// MARK: - Activities

struct MusicSettings: View {
    @ObservedObject private var coordinator = FlowDockViewCoordinator.shared
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
                        .font(.caption)
                        .foregroundStyle(.secondary)
                } else {
                    Text("Now Playing works with every media app. The others talk to one app directly.")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
            }

            Section {
                Toggle("Show music activity", isOn: $coordinator.musicLiveActivityEnabled.animation())
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
                    Text("Show lyrics below the artist")
                }
            } header: {
                Text("Controls")
            } footer: {
                Text("Choose which controls appear in the expanded player. Volume expands when active.")
                    .font(.caption)
                    .foregroundStyle(.secondary)
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
        .accentColor(.effectiveAccent)
    }

    private var availableMediaControllers: [MediaControllerType] {
        MusicManager.shared.isNowPlayingDeprecated
            ? MediaControllerType.allCases.filter { $0 != .nowPlaying }
            : MediaControllerType.allCases
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
                }
            } footer: {
                Text("Volume, display brightness, and keyboard brightness appear at the notch instead of the middle of the screen. Accessibility access is required to see the key presses.")
                    .font(.caption)
                    .foregroundStyle(.secondary)
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
        .accentColor(.effectiveAccent)
        .task {
            accessibilityAuthorized = await XPCHelperClient.shared.isAccessibilityAuthorized()
        }
        .onAppear {
            XPCHelperClient.shared.startMonitoringAccessibilityAuthorization()
        }
        .onDisappear {
            XPCHelperClient.shared.stopMonitoringAccessibilityAuthorization()
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
        .accentColor(.effectiveAccent)
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
        .accentColor(.effectiveAccent)
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
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
        }
        .accentColor(.effectiveAccent)
        .task {
            await QuickShareService.shared.discoverAvailableProviders()
        }
    }
}

// MARK: - App

struct GeneralSettings: View {
    @ObservedObject private var coordinator = FlowDockViewCoordinator.shared
    @Default(.showOnAllDisplays) private var showOnAllDisplays
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
            }

            Section {
                Defaults.Toggle(key: .showOnAllDisplays) {
                    Text("Show on every display")
                }
                .onChange(of: showOnAllDisplays) {
                    NotificationCenter.default.post(name: .showOnAllDisplaysChanged, object: nil)
                }
                Picker("Preferred display", selection: $coordinator.preferredScreenUUID) {
                    ForEach(screens, id: \.uuid) { screen in
                        Text(screen.name).tag(screen.uuid as String?)
                    }
                }
                .disabled(showOnAllDisplays)
                Defaults.Toggle(key: .automaticallySwitchDisplay) {
                    Text("Follow the active display")
                }
                .onChange(of: Defaults[.automaticallySwitchDisplay]) {
                    NotificationCenter.default.post(name: .automaticallySwitchDisplayChanged, object: nil)
                }
                .disabled(showOnAllDisplays)
            } header: {
                Text("Displays")
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
                .disabled(!openNotchOnHover)
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
                    .font(.caption)
                    .foregroundStyle(.secondary)
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
            }
        }
        .accentColor(.effectiveAccent)
        .onChange(of: openNotchOnHover) {
            if !openNotchOnHover { enableGestures = true }
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
    @State private var customAccentColor: Color = .accentColor

    var body: some View {
        Form {
            Section {
                Picker("Accent color", selection: $useCustomAccentColor) {
                    Text("System").tag(false)
                    Text("Custom").tag(true)
                }
                .pickerStyle(.segmented)
                .onChange(of: useCustomAccentColor) { announceAccentChange() }

                if useCustomAccentColor {
                    ColorPicker("Custom color", selection: $customAccentColor, supportsOpacity: false)
                        .onChange(of: customAccentColor) { save(customAccentColor) }
                }
            } footer: {
                Text("The accent marks progress, selection, and activity. It is never used for text.")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }

            Section {
                Defaults.Toggle(key: .enableShadow) {
                    Text("Shadow under the panel")
                }
            } header: {
                Text("Panel")
            }
        }
        .accentColor(.effectiveAccent)
        .onAppear(perform: loadCustomColor)
    }

    private func save(_ color: Color) {
        customAccentColorData = try? NSKeyedArchiver.archivedData(
            withRootObject: NSColor(color), requiringSecureCoding: false)
        announceAccentChange()
    }

    private func loadCustomColor() {
        guard let data = customAccentColorData,
              let nsColor = try? NSKeyedUnarchiver.unarchivedObject(ofClass: NSColor.self, from: data)
        else { return }
        customAccentColor = Color(nsColor: nsColor)
    }

    private func announceAccentChange() {
        NotificationCenter.default.post(name: .accentColorChanged, object: nil)
    }
}

struct ShortcutsSettings: View {
    var body: some View {
        Form {
            Section {
                KeyboardShortcuts.Recorder("Open the notch:", name: .toggleNotchOpen)
            }
        }
        .accentColor(.effectiveAccent)
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
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
        }
        .accentColor(.effectiveAccent)
        .toolbar {
            if let updater {
                CheckForUpdatesView(updater: updater)
            }
        }
    }
}

extension Notification.Name {
    static let accentColorChanged = Notification.Name("AccentColorChanged")
}
