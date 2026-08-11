//
//  FullscreenMediaDetection.swift
//  FlowDock
//
//  Created by Richard Kunkli on 06/09/2024.
//

import Foundation
import Combine
import Defaults
import MacroVisionKit

@MainActor
final class FullscreenMediaDetector: ObservableObject {
    static let shared = FullscreenMediaDetector()
    
    @Published var fullscreenStatus: [String: Bool] = [:]
    
    private var monitorTask: Task<Void, Never>?
    private var cancellables: Set<AnyCancellable> = []
    private var spaces: [MacroVisionKit.FullScreenMonitor.SpaceInfo] = []

    private init() {
        startMonitoring()

        Defaults.publisher(.hideNotchOption)
            .sink { [weak self] _ in
                Task { @MainActor in self?.reevaluate() }
            }
            .store(in: &cancellables)

        MusicManager.shared.$bundleIdentifier
            .removeDuplicates()
            .sink { [weak self] _ in
                Task { @MainActor in self?.reevaluate() }
            }
            .store(in: &cancellables)
    }

    deinit {
        monitorTask?.cancel()
    }

    private func startMonitoring() {
        monitorTask = Task { @MainActor in
            let stream = await FullScreenMonitor.shared.spaceChanges()
            for await spaces in stream {
                updateStatus(with: spaces)
            }
        }
    }
    
    /// The answer depends on the setting and on which app is playing, and neither of those
    /// changes the set of spaces, so both have to re-run this against the spaces we last saw.
    private func reevaluate() {
        updateStatus(with: spaces)
    }

    private func updateStatus(with spaces: [MacroVisionKit.FullScreenMonitor.SpaceInfo]) {
        self.spaces = spaces
        var newStatus: [String: Bool] = [:]

        for space in spaces {
            if let uuid = space.screenUUID {
                let shouldDetect: Bool
                if Defaults[.hideNotchOption] == .nowPlayingOnly, let musicSourceBundle = MusicManager.shared.bundleIdentifier  {
                    shouldDetect = space.runningApps.contains(musicSourceBundle)
                } else {
                    shouldDetect = true
                }
                newStatus[uuid] = shouldDetect
            }
        }
        
        self.fullscreenStatus = newStatus
    }
}

