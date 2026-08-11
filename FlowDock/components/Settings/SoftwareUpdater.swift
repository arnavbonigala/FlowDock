//
//  SoftwareUpdater.swift
//  FlowDock
//
//  Created by Richard Kunkli on 09/08/2024.
//

import Defaults
import Sparkle
import SwiftUI

/// Sparkle offers an item with no channel to everyone, so a prerelease reaches
/// stable installs unless it is confined to a channel and the channel is opted into.
/// See RELEASING.md.
final class UpdateChannels: NSObject, SPUUpdaterDelegate {
    static let shared = UpdateChannels()

    func allowedChannels(for updater: SPUUpdater) -> Set<String> {
        Defaults[.receiveBetaUpdates] ? ["beta"] : []
    }
}

final class CheckForUpdatesViewModel: ObservableObject {
    @Published var canCheckForUpdates = false

    init(updater: SPUUpdater) {
        updater.publisher(for: \.canCheckForUpdates)
            .assign(to: &$canCheckForUpdates)
    }
}

struct CheckForUpdatesView: View {
    @ObservedObject private var checkForUpdatesViewModel: CheckForUpdatesViewModel
    private let updater: SPUUpdater
    
    init(updater: SPUUpdater) {
        self.updater = updater
        
        // Create our view model for our CheckForUpdatesView
        self.checkForUpdatesViewModel = CheckForUpdatesViewModel(updater: updater)
    }
    
    var body: some View {
        Button("Check for Updates…", action: updater.checkForUpdates)
            .disabled(!checkForUpdatesViewModel.canCheckForUpdates)
    }
}

struct UpdaterSettingsView: View {
    private let updater: SPUUpdater
    
    @State private var automaticallyChecksForUpdates: Bool
    @State private var automaticallyDownloadsUpdates: Bool
    @Default(.receiveBetaUpdates) private var receiveBetaUpdates
    
    init(updater: SPUUpdater) {
        self.updater = updater
        self.automaticallyChecksForUpdates = updater.automaticallyChecksForUpdates
        self.automaticallyDownloadsUpdates = updater.automaticallyDownloadsUpdates
    }
    
    var body: some View {
        Section {
            Toggle("Automatically check for updates", isOn: $automaticallyChecksForUpdates)
                .onChange(of: automaticallyChecksForUpdates) { _, newValue in
                    updater.automaticallyChecksForUpdates = newValue
                }
            
            Toggle("Automatically download updates", isOn: $automaticallyDownloadsUpdates)
                .disabled(!automaticallyChecksForUpdates)
                .onChange(of: automaticallyDownloadsUpdates) { _, newValue in
                    updater.automaticallyDownloadsUpdates = newValue
                }

            Toggle("Include beta releases", isOn: $receiveBetaUpdates)
        } header: {
            HStack {
                Text("Software updates")
            }
        } footer: {
            Text("Betas arrive earlier and are less tested. Turning this off stops new betas being offered; it does not move this install back to the last stable release.")
        }
    }
}
