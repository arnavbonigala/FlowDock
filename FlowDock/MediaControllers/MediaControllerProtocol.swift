//
//  MediaControllerProtocol.swift
//  FlowDock
//
//  Created by Alexander on 2025-03-29.
//

import Foundation
import AppKit
import Combine

struct MediaCapabilities: OptionSet {
    let rawValue: Int

    static let seek = MediaCapabilities(rawValue: 1 << 0)
    static let shuffle = MediaCapabilities(rawValue: 1 << 1)
    static let repeatMode = MediaCapabilities(rawValue: 1 << 2)
    static let volume = MediaCapabilities(rawValue: 1 << 3)
    static let favorite = MediaCapabilities(rawValue: 1 << 4)
    static let queue = MediaCapabilities(rawValue: 1 << 5)
}

protocol MediaControllerProtocol: ObservableObject {
    var playbackStatePublisher: AnyPublisher<PlaybackState, Never> { get }
    var capabilities: MediaCapabilities { get }

    func setFavorite(_ favorite: Bool) async
    func play() async
    func pause() async
    func seek(to time: Double) async
    func nextTrack() async
    func previousTrack() async
    func togglePlay() async
    func toggleShuffle() async
    func toggleRepeat() async
    func setVolume(_ level: Double) async
    func isActive() -> Bool
    func updatePlaybackInfo() async
    func upNext() async -> [String]
}

extension MediaControllerProtocol {
    func upNext() async -> [String] { [] }
}
