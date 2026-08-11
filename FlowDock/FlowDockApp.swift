//
//  FlowDockApp.swift
//  FlowDockApp
//
//  Created by Harsh Vardhan  Goswami  on 02/08/24.
//

import AVFoundation
import Combine
import Defaults
import KeyboardShortcuts
import Sparkle
import SwiftUI

@main
struct FlowDockApp: App {
    @NSApplicationDelegateAdaptor(AppDelegate.self) var appDelegate
    @Default(.menubarIcon) var showMenuBarIcon
    @Environment(\.openWindow) var openWindow

    let updaterController: SPUStandardUpdaterController

    init() {
        updaterController = SPUStandardUpdaterController(
            startingUpdater: true,
            updaterDelegate: UpdateChannels.shared,
            userDriverDelegate: nil)

        // Initialize the settings window controller with the updater controller
        SettingsWindowController.shared.setUpdaterController(updaterController)
    }

    var body: some Scene {
        MenuBarExtra(
            "FlowDock",
            systemImage: "rectangle.topthird.inset.filled",
            isInserted: $showMenuBarIcon
        ) {
            Button("Settings…") {
                DispatchQueue.main.async {
                    SettingsWindowController.shared.showWindow()
                }
            }
            .keyboardShortcut(",", modifiers: .command)
            CheckForUpdatesView(updater: updaterController.updater)
            Divider()
            Button("Restart FlowDock") {
                ApplicationRelauncher.restart()
            }
            Button("Quit FlowDock") {
                NSApplication.shared.terminate(self)
            }
            .keyboardShortcut("q", modifiers: .command)
        }
    }
}

class AppDelegate: NSObject, NSApplicationDelegate {
    var windows: [String: NSWindow] = [:] // UUID -> NSWindow
    var viewModels: [String: FlowDockViewModel] = [:] // UUID -> FlowDockViewModel
    var window: NSWindow?
    let vm: FlowDockViewModel = .init()
    @ObservedObject var coordinator = FlowDockViewCoordinator.shared
    var quickShareService = QuickShareService.shared
    var timer: Timer?
    private var onboardingWindowController: NSWindowController?
    private var distributedObservers: [Any] = []
    private var workspaceObservers: [Any] = []
    private var isScreenLocked: Bool = false
    private var recoveryTask: Task<Void, Never>?
    private var deprecationWatch: AnyCancellable?

    func applicationShouldTerminateAfterLastWindowClosed(_ sender: NSApplication) -> Bool {
        return false
    }

    func applicationWillTerminate(_ notification: Notification) {
        NotificationCenter.default.removeObserver(self)
        distributedObservers.forEach { DistributedNotificationCenter.default().removeObserver($0) }
        distributedObservers.removeAll()
        workspaceObservers.forEach { NSWorkspace.shared.notificationCenter.removeObserver($0) }
        workspaceObservers.removeAll()
        recoveryTask?.cancel()
        MusicManager.shared.destroy()
        cleanupWindows()
        XPCHelperClient.shared.stopMonitoringAccessibilityAuthorization()
    }

    private func observeLifecycle() {
        let distributed = DistributedNotificationCenter.default()
        distributedObservers.append(
            distributed.addObserver(
                forName: NSNotification.Name("com.apple.screenIsLocked"),
                object: nil, queue: .main
            ) { [weak self] notification in
                Task { @MainActor in self?.onScreenLocked(notification) }
            })
        distributedObservers.append(
            distributed.addObserver(
                forName: NSNotification.Name("com.apple.screenIsUnlocked"),
                object: nil, queue: .main
            ) { [weak self] notification in
                Task { @MainActor in self?.onScreenUnlocked(notification) }
            })
        distributedObservers.append(
            distributed.addObserver(
                forName: NSNotification.Name("com.apple.screensaver.didstop"),
                object: nil, queue: .main
            ) { [weak self] _ in
                Task { @MainActor in self?.scheduleRecovery() }
            })

        let workspaceNames: [Notification.Name] = [
            NSWorkspace.didWakeNotification,
            NSWorkspace.screensDidWakeNotification,
            NSWorkspace.sessionDidBecomeActiveNotification,
        ]
        for name in workspaceNames {
            workspaceObservers.append(
                NSWorkspace.shared.notificationCenter.addObserver(
                    forName: name, object: nil, queue: .main
                ) { [weak self] _ in
                    Task { @MainActor in self?.scheduleRecovery() }
                })
        }

        let activeDisplayNames: [Notification.Name] = [
            NSWorkspace.didActivateApplicationNotification,
            NSWorkspace.activeSpaceDidChangeNotification,
        ]
        for name in activeDisplayNames {
            workspaceObservers.append(
                NSWorkspace.shared.notificationCenter.addObserver(
                    forName: name, object: nil, queue: .main
                ) { [weak self] _ in
                    Task { @MainActor in self?.followActiveDisplay() }
                })
        }
    }

    @MainActor
    private func scheduleRecovery() {
        recoveryTask?.cancel()
        recoveryTask = Task { @MainActor [weak self] in
            try? await Task.sleep(for: .milliseconds(750))
            guard !Task.isCancelled, let self, !self.isScreenLocked else { return }

            NotchSpaceManager.shared.notchSpace.revive()
            self.adjustWindowPosition(changeAlpha: true)
            self.allWindows.forEach { $0.orderFrontRegardless() }

            await MediaKeyInterceptor.shared.restartIfNeeded()
            MusicManager.shared.recoverAfterWake()
        }
    }

    private var allWindows: [NSWindow] {
        Defaults[.showOnAllDisplays] ? Array(windows.values) : [window].compactMap { $0 }
    }

    @MainActor
    func onScreenLocked(_ notification: Notification) {
        isScreenLocked = true
        if !Defaults[.showOnLockScreen] {
            cleanupWindows()
        } else {
            enableSkyLightOnAllWindows()
        }
    }

    @MainActor
    func onScreenUnlocked(_ notification: Notification) {
        isScreenLocked = false
        if !Defaults[.showOnLockScreen] {
            adjustWindowPosition(changeAlpha: true)
        } else {
            disableSkyLightOnAllWindows()
        }
        scheduleRecovery()
    }

    @MainActor
    private func enableSkyLightOnAllWindows() {
        setSkyLight(enabled: true)
    }

    @MainActor
    private func disableSkyLightOnAllWindows() {
        // Delay disabling SkyLight to avoid flicker during unlock transition
        Task { @MainActor in
            try? await Task.sleep(for: .milliseconds(150))
            self.setSkyLight(enabled: false)
        }
    }

    @MainActor
    private func setSkyLight(enabled: Bool) {
        allWindows.compactMap { $0 as? FlowDockSkyLightWindow }
            .forEach { enabled ? $0.enableSkyLight() : $0.disableSkyLight() }
    }

    private func cleanupWindows(shouldInvert: Bool = false) {
        let shouldCleanupMulti = shouldInvert ? !Defaults[.showOnAllDisplays] : Defaults[.showOnAllDisplays]
        
        if shouldCleanupMulti {
            windows.values.forEach { window in
                window.close()
                NotchSpaceManager.shared.notchSpace.windows.remove(window)
            }
            windows.removeAll()
            viewModels.removeAll()
        } else if let window = window {
            window.close()
            NotchSpaceManager.shared.notchSpace.windows.remove(window)
            self.window = nil
        }
    }

    private func createFlowDockWindow(for screen: NSScreen, with viewModel: FlowDockViewModel) -> NSWindow {
        let rect = NSRect(x: 0, y: 0, width: windowSize.width, height: windowSize.height)
        let styleMask: NSWindow.StyleMask = [.borderless, .nonactivatingPanel, .utilityWindow, .hudWindow]
        
        let window = FlowDockSkyLightWindow(contentRect: rect, styleMask: styleMask, backing: .buffered, defer: false)
        
        // Enable SkyLight only when screen is locked
        if isScreenLocked {
            window.enableSkyLight()
        } else {
            window.disableSkyLight()
        }

        window.contentView = NSHostingView(
            rootView: ExperienceView()
                .environmentObject(viewModel)
        )

        window.orderFrontRegardless()
        NotchSpaceManager.shared.notchSpace.windows.insert(window)

        _ = VolumeManager.shared

        let feedback = SystemFeedbackWindow(viewModel: viewModel)
        feedback.attach(to: window)
        feedback.orderFrontRegardless()

        return window
    }

    @MainActor
    private func positionWindow(_ window: NSWindow, on screen: NSScreen, changeAlpha: Bool = false) {
        if changeAlpha {
            window.alphaValue = 0
        }

        let screenFrame = screen.frame
        let topInset = surfaceTopInset(screen)
        let width = min(windowSize.width, screenFrame.width)
        let height = min(windowSize.height, screenFrame.height - topInset)
        window.setFrame(
            NSRect(
                x: screenFrame.midX - width / 2,
                y: screenFrame.maxY - topInset - height,
                width: width,
                height: height
            ),
            display: false
        )
        window.alphaValue = 1
    }

    func applicationDidFinishLaunching(_ notification: Notification) {

        NotificationCenter.default.addObserver(
            self,
            selector: #selector(screenConfigurationDidChange),
            name: NSApplication.didChangeScreenParametersNotification,
            object: nil
        )

        NotificationCenter.default.addObserver(
            forName: Notification.Name.selectedScreenChanged, object: nil, queue: nil
        ) { [weak self] _ in
            Task { @MainActor in
                self?.adjustWindowPosition(changeAlpha: true)
            }
        }

        NotificationCenter.default.addObserver(
            forName: Notification.Name.notchHeightChanged, object: nil, queue: nil
        ) { [weak self] _ in
            Task { @MainActor in
                self?.adjustWindowPosition()
            }
        }

        NotificationCenter.default.addObserver(
            forName: Notification.Name.automaticallySwitchDisplayChanged, object: nil, queue: nil
        ) { [weak self] _ in
            Task { @MainActor in
                self?.adjustWindowPosition(changeAlpha: true)
            }
        }

        NotificationCenter.default.addObserver(
            forName: Notification.Name.showOnAllDisplaysChanged, object: nil, queue: nil
        ) { [weak self] _ in
            Task { @MainActor in
                guard let self = self else { return }
                self.cleanupWindows(shouldInvert: true)
                self.adjustWindowPosition(changeAlpha: true)
            }
        }

        observeLifecycle()

        KeyboardShortcuts.onKeyDown(for: .toggleKeepAwake) {
            Task { @MainActor in KeepAwake.shared.toggle() }
        }

        KeyboardShortcuts.onKeyDown(for: .toggleNotchOpen) { [weak self] in
            Task { [weak self] in
                guard let self = self else { return }

                let mouseLocation = NSEvent.mouseLocation

                var viewModel = self.vm

                if Defaults[.showOnAllDisplays] {
                    for screen in NSScreen.screens {
                        if screen.frame.contains(mouseLocation) {
                            if let uuid = screen.displayUUID, let screenViewModel = self.viewModels[uuid] {
                                viewModel = screenViewModel
                                break
                            }
                        }
                    }
                }

                await MainActor.run {
                    switch viewModel.notchState {
                    case .closed: viewModel.open()
                    case .open: viewModel.close()
                    }
                }
            }
        }

        if !Defaults[.showOnAllDisplays] {
            let viewModel = self.vm
            let window = createFlowDockWindow(
                for: NSScreen.main ?? NSScreen.screens.first!, with: viewModel)
            self.window = window
            adjustWindowPosition(changeAlpha: true)
        } else {
            adjustWindowPosition(changeAlpha: true)
        }

        if coordinator.firstLaunch {
            DispatchQueue.main.async {
                self.showOnboardingWindow()
            }
            playWelcomeSound()
        } else if Defaults[.mediaController] == .nowPlaying {
            deprecationWatch = MusicManager.shared.$isNowPlayingDeprecated
                .filter { $0 }
                .prefix(1)
                .sink { [weak self] _ in
                    guard Defaults[.mediaController] == .nowPlaying else { return }
                    self?.showOnboardingWindow(step: .setup)
                }
        }
    }

    func playWelcomeSound() {
        AudioPlayer.playInterfaceSound(fileName: "FlowDock", fileExtension: "m4a")
    }

    @objc func screenConfigurationDidChange() {
        DispatchQueue.main.async { [weak self] in
            self?.adjustWindowPosition()
            self?.allWindows.forEach { $0.orderFrontRegardless() }
        }
    }

    @MainActor
    private func followActiveDisplay() {
        allWindows.forEach { $0.orderFrontRegardless() }
        guard !Defaults[.showOnAllDisplays], Defaults[.automaticallySwitchDisplay],
              vm.notchState == .closed, vm.chinState != .contextual,
              let activeScreenUUID = NSScreen.main?.displayUUID,
              activeScreenUUID != vm.screenUUID
        else { return }
        adjustWindowPosition(changeAlpha: true)
    }

    @objc func adjustWindowPosition(changeAlpha: Bool = false) {
        if Defaults[.showOnAllDisplays] {
            let currentScreenUUIDs = Set(NSScreen.screens.compactMap { $0.displayUUID })

            // Remove windows for screens that no longer exist
            for uuid in windows.keys where !currentScreenUUIDs.contains(uuid) {
                if let window = windows[uuid] {
                    window.close()
                    NotchSpaceManager.shared.notchSpace.windows.remove(window)
                    windows.removeValue(forKey: uuid)
                    viewModels.removeValue(forKey: uuid)
                }
            }

            // Create or update windows for all screens
            for screen in NSScreen.screens {
                guard let uuid = screen.displayUUID else { continue }
                
                if windows[uuid] == nil {
                    let viewModel = FlowDockViewModel(screenUUID: uuid)
                    let window = createFlowDockWindow(for: screen, with: viewModel)

                    windows[uuid] = window
                    viewModels[uuid] = viewModel
                }

                if let window = windows[uuid], let viewModel = viewModels[uuid] {
                    positionWindow(window, on: screen, changeAlpha: changeAlpha)

                    if viewModel.notchState == .closed {
                        viewModel.close()
                    }
                }
            }
        } else {
            let preferredScreen = NSScreen.screen(withUUID: coordinator.preferredScreenUUID ?? "")
            let activeScreen = Defaults[.automaticallySwitchDisplay] ? NSScreen.main : nil

            guard let selectedScreen = activeScreen ?? preferredScreen ?? NSScreen.main else {
                if let window = window {
                    window.alphaValue = 0
                }
                return
            }

            coordinator.selectedScreenUUID = selectedScreen.displayUUID ?? ""

            vm.screenUUID = selectedScreen.displayUUID
            vm.notchSize = getClosedNotchSize(screenUUID: selectedScreen.displayUUID)

            if window == nil {
                window = createFlowDockWindow(for: selectedScreen, with: vm)
            }

            if let window = window {
                positionWindow(window, on: selectedScreen, changeAlpha: changeAlpha)

                if vm.notchState == .closed {
                    vm.close()
                }
            }
        }
    }

    private func showOnboardingWindow(step: OnboardingStep = .welcome) {
        if onboardingWindowController == nil {
            let window = NSWindow(
                contentRect: NSRect(x: 0, y: 0, width: 460, height: 520),
                styleMask: [.titled, .closable, .fullSizeContentView],
                backing: .buffered,
                defer: false
            )
            window.center()
            window.titlebarAppearsTransparent = true
            window.titleVisibility = .hidden
            window.isMovableByWindowBackground = true
            window.contentViewController = NSHostingController(
                rootView: OnboardingView(
                    step: step,
                    onFinish: {
                        window.close()
                        NSApp.deactivate()
                    },
                    onOpenSettings: {
                        window.close()
                        SettingsWindowController.shared.showWindow()
                    }
                ))
            window.isRestorable = false
            window.identifier = NSUserInterfaceItemIdentifier("OnboardingWindow")
            window.delegate = self

            onboardingWindowController = NSWindowController(window: window)
        }

        NSApp.setActivationPolicy(.regular)

        onboardingWindowController?.window?.title = step == .welcome
            ? "Welcome to FlowDock"
            : "Set Up FlowDock"

        NSApp.activate(ignoringOtherApps: true)
        onboardingWindowController?.window?.makeKeyAndOrderFront(nil)
        onboardingWindowController?.window?.orderFrontRegardless()
    }
}

extension AppDelegate: NSWindowDelegate {
    func windowWillClose(_ notification: Notification) {
        guard (notification.object as? NSWindow)?.identifier?.rawValue == "OnboardingWindow" else { return }
        guard SettingsWindowController.shared.window?.isVisible != true else { return }
        NSApp.setActivationPolicy(.accessory)
    }
}

extension Notification.Name {
    static let selectedScreenChanged = Notification.Name("SelectedScreenChanged")
    static let notchHeightChanged = Notification.Name("NotchHeightChanged")
    static let showOnAllDisplaysChanged = Notification.Name("showOnAllDisplaysChanged")
    static let automaticallySwitchDisplayChanged = Notification.Name("automaticallySwitchDisplayChanged")
}

extension CGRect: @retroactive Hashable {
    public func hash(into hasher: inout Hasher) {
        hasher.combine(origin.x)
        hasher.combine(origin.y)
        hasher.combine(size.width)
        hasher.combine(size.height)
    }

    public static func == (lhs: CGRect, rhs: CGRect) -> Bool {
        return lhs.origin == rhs.origin && lhs.size == rhs.size
    }
}
