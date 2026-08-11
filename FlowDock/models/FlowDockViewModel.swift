//
//  FlowDockViewModel.swift
//  FlowDock
//
//  Created by Harsh Vardhan  Goswami  on 04/08/24.
//

import Combine
import Defaults
import SwiftUI

class FlowDockViewModel: NSObject, ObservableObject {
    @ObservedObject var coordinator = FlowDockViewCoordinator.shared
    @ObservedObject var detector = FullscreenMediaDetector.shared

    @Published private(set) var notchState: NotchState = .closed

    var cancellables: Set<AnyCancellable> = []
    
    @Published var hideOnClosed: Bool = true
    /// Set by the app delegate from the screen-lock notifications. The shell needs it
    /// because a locked Mac shows a different panel, not the same one behind glass.
    @Published var isLocked: Bool = false

    /// Mirrored off the display's store so window placement can ask what is on screen
    /// without owning it. A HUD that teleports mid-glance is worse than a late move.
    @Published var chinState: ActivityState = .idle

    @Published var edgeAutoOpenActive: Bool = false

    @Published var screenUUID: String?

    @Published var notchSize: CGSize = getClosedNotchSize()
    @Published var closedNotchSize: CGSize = getClosedNotchSize()
    
    deinit {
        destroy()
    }

    func destroy() {
        cancellables.forEach { $0.cancel() }
        cancellables.removeAll()
    }

    init(screenUUID: String? = nil) {
        super.init()
        
        self.screenUUID = screenUUID
        notchSize = getClosedNotchSize(screenUUID: screenUUID)
        closedNotchSize = notchSize

        setupDetectorObserver()
    }
    
    private func setupDetectorObserver() {
        // Publisher for the user’s fullscreen detection setting
        let enabledPublisher = Defaults
            .publisher(.hideNotchOption)
            .map(\.newValue)
            .map { $0 != .never }
            .removeDuplicates()

        // Publisher for the current screen UUID (non-nil, distinct)
        let screenPublisher = $screenUUID
            .compactMap { $0 }
            .removeDuplicates()

        // Publisher for fullscreen status dictionary
        let fullscreenStatusPublisher = detector.$fullscreenStatus
            .removeDuplicates()

        // Combine all three: screen UUID, fullscreen status, and enabled setting
        Publishers.CombineLatest3(screenPublisher, fullscreenStatusPublisher, enabledPublisher)
            .map { screenUUID, fullscreenStatus, enabled in
                let isFullscreen = fullscreenStatus[screenUUID] ?? false
                return enabled && isFullscreen
            }
            .removeDuplicates()
            .receive(on: RunLoop.main)
            .sink { [weak self] shouldHide in
                withAnimation(.experience(reduceMotion: NSWorkspace.shared.accessibilityDisplayShouldReduceMotion)) {
                    self?.hideOnClosed = shouldHide
                }
            }
            .store(in: &cancellables)
    }

    /// Bottom edge of whatever the notch is currently drawing, measured down from the top
    /// of the screen. Detached surfaces hang off this so the notch never covers them.
    var surfaceBottom: CGFloat {
        if notchState == .open { return openNotchSize.height }

        let screen = screenUUID.flatMap { NSScreen.screen(withUUID: $0) } ?? NSScreen.main
        let menuBarHeight = screen.map { $0.frame.maxY - $0.visibleFrame.maxY } ?? 0
        return max(effectiveClosedNotchHeight, menuBarHeight)
    }

    // Computed property for effective notch height
    var effectiveClosedNotchHeight: CGFloat {
        let currentScreen = screenUUID.flatMap { NSScreen.screen(withUUID: $0) }
        let noNotchAndFullscreen = hideOnClosed && (currentScreen?.safeAreaInsets.top ?? 0 <= 0 || currentScreen == nil)
        return noNotchAndFullscreen ? 0 : closedNotchSize.height
    }

    var chinItemSide: CGFloat {
        max(0, effectiveClosedNotchHeight - 12)
    }

    func open() {
        self.notchSize = openNotchSize
        self.notchState = .open
        
        // Force music information update when notch is opened
        MusicManager.shared.forceUpdate()
    }

    func close() {
        // Do not close while a share picker or sharing service is active
        if SharingStateManager.shared.preventNotchClose {
            return
        }
        self.notchSize = getClosedNotchSize(screenUUID: self.screenUUID)
        self.closedNotchSize = self.notchSize
        self.notchState = .closed
        self.edgeAutoOpenActive = false
    }
}
