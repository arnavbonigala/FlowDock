//
//  AudioPlayer.swift
//  FlowDock
//
//  Created by Harsh Vardhan  Goswami  on 09/08/24.
//

import AppKit
import Foundation

@MainActor
enum AudioPlayer {
    private static var playing: NSSound?

    static var interfaceSoundsEnabled: Bool {
        UserDefaults.standard.persistentDomain(forName: "NSGlobalDomain")?["com.apple.sound.uiaudio.enabled"]
            as? Bool ?? true
    }

    static func playInterfaceSound(fileName: String, fileExtension: String) {
        guard interfaceSoundsEnabled,
              let url = Bundle.main.url(forResource: fileName, withExtension: fileExtension),
              let sound = NSSound(contentsOf: url, byReference: false)
        else { return }

        playing = sound
        sound.play()
    }
}
