//
//  FlowDockViewCoordinator.swift
//  FlowDock
//
//  Created by Alexander on 2024-11-20.
//

import AppKit
import Combine
import Defaults
import SwiftUI

@MainActor
class FlowDockViewCoordinator: ObservableObject {
    static let shared = FlowDockViewCoordinator()

    private var hudEnableTask: Task<Void, Never>?

    @AppStorage("firstLaunch") var firstLaunch: Bool = true

    @Default(.hudReplacement) var hudReplacement: Bool
    
    // Legacy storage for migration
    @AppStorage("preferred_screen_name") private var legacyPreferredScreenName: String?
    
    // New UUID-based storage
    @AppStorage("preferred_screen_uuid") var preferredScreenUUID: String? {
        didSet {
            if let uuid = preferredScreenUUID {
                selectedScreenUUID = uuid
            }
            NotificationCenter.default.post(name: Notification.Name.selectedScreenChanged, object: nil)
        }
    }

    @Published var selectedScreenUUID: String = NSScreen.main?.displayUUID ?? ""

    @Published var optionKeyPressed: Bool = true
    private var accessibilityObserver: Any?
    private var activationObserver: Any?
    private var hudReplacementCancellable: AnyCancellable?

    private init() {
        // Perform migration from name-based to UUID-based storage
        if preferredScreenUUID == nil, let legacyName = legacyPreferredScreenName {
            // Try to find screen by name and migrate to UUID
            if let screen = NSScreen.screens.first(where: { $0.localizedName == legacyName }),
               let uuid = screen.displayUUID {
                preferredScreenUUID = uuid
            } else {
                // Fallback to main screen if legacy screen not found
                preferredScreenUUID = NSScreen.main?.displayUUID
                NSLog("Could not find the saved display, falling back to the main screen")
            }
            // Clear legacy value after migration
            legacyPreferredScreenName = nil
        } else if preferredScreenUUID == nil {
            // No legacy value, use main screen
            preferredScreenUUID = NSScreen.main?.displayUUID
        }
        
        selectedScreenUUID = preferredScreenUUID ?? NSScreen.main?.displayUUID ?? ""
        // Observe changes to accessibility authorization and react accordingly
        accessibilityObserver = NotificationCenter.default.addObserver(
            forName: Notification.Name.accessibilityAuthorizationChanged,
            object: nil,
            queue: .main
        ) { notification in
            let granted = notification.userInfo?["granted"] as? Bool ?? false
            Task { @MainActor in
                guard Defaults[.hudReplacement] else { return }
                if granted {
                    await MediaKeyInterceptor.shared.start(promptIfNeeded: false)
                } else {
                    MediaKeyInterceptor.shared.stop()
                }
            }
        }

        // Observe changes to hudReplacement
        hudReplacementCancellable = Defaults.publisher(.hudReplacement)
            .sink { [weak self] change in
                Task { @MainActor in
                    guard let self = self else { return }

                    self.hudEnableTask?.cancel()
                    self.hudEnableTask = nil

                    if change.newValue {
                        self.hudEnableTask = Task { @MainActor in
                            if await XPCHelperClient.shared.ensureAccessibilityAuthorization(promptIfNeeded: true),
                               !Task.isCancelled {
                                await MediaKeyInterceptor.shared.start()
                            }
                        }
                    } else {
                        MediaKeyInterceptor.shared.stop()
                    }
                }
            }

        activationObserver = NotificationCenter.default.addObserver(
            forName: NSApplication.didBecomeActiveNotification,
            object: nil,
            queue: .main
        ) { _ in
            Task { _ = await XPCHelperClient.shared.isAccessibilityAuthorized() }
        }

        XPCHelperClient.shared.startMonitoringAccessibilityAuthorization()

        Task { @MainActor in
            // The setting is what the user wants; accessibility is whether we can do it
            // yet. On a first launch the answer is no until onboarding asks, and the
            // authorization observer above starts the tap the moment it changes.
            if Defaults[.hudReplacement] {
                await MediaKeyInterceptor.shared.start(promptIfNeeded: false)
            }
        }
    }
}
