//
//  NetworkMonitor.swift
//  FlowDock
//

import AppKit
import Combine
import Foundation
import Network

struct NetworkReachability: Equatable {
    var isOnline: Bool
    var interface: NWInterface.InterfaceType?
    var isExpensive: Bool

    init(isOnline: Bool, interface: NWInterface.InterfaceType? = nil, isExpensive: Bool = false) {
        self.isOnline = isOnline
        self.interface = interface
        self.isExpensive = isExpensive
    }

    init(path: NWPath) {
        isOnline = path.status == .satisfied
        interface = [.wifi, .wiredEthernet, .cellular].first { path.usesInterfaceType($0) }
        isExpensive = path.isExpensive
    }

    var name: String {
        guard isOnline else { return "Offline" }
        if isExpensive { return "Hotspot" }
        switch interface {
        case .wifi: return "Wi-Fi"
        case .wiredEthernet: return "Ethernet"
        case .cellular: return "Cellular"
        default: return "Online"
        }
    }

    var symbol: String {
        guard isOnline else { return "wifi.slash" }
        if isExpensive { return "personalhotspot" }
        switch interface {
        case .wiredEthernet: return "cable.connector"
        case .cellular: return "antenna.radiowaves.left.and.right"
        default: return "wifi"
        }
    }

    var label: String { isOnline ? "Back online, \(name)" : "Offline" }

    /// Only losing the connection and getting it back are worth the chin. Plugging in a
    /// cable swaps Wi-Fi for Ethernet, and the user is holding the cable — a notch that
    /// reported it would be confirming their own hand.
    static func announces(_ reading: NetworkReachability, after previous: NetworkReachability) -> Bool {
        reading.isOnline != previous.isOnline
    }
}

@MainActor
final class NetworkMonitor: ObservableObject {
    static let shared = NetworkMonitor()

    /// A path settles noisily. Handing over between access points, plugging in a cable, or
    /// waking each produce several updates in a second, and only the last of them is true.
    static let settleDelay: TimeInterval = 3

    /// Waking crosses offline and back every time, so a lid opening would otherwise report
    /// a drop that never happened. Launching is the same story with no user in front of it.
    static let silence: TimeInterval = 10

    @Published private(set) var reachability = NetworkReachability(isOnline: true)
    @Published private(set) var announcement: NetworkReachability?

    private let monitor = NWPathMonitor()
    private var settling: Task<Void, Never>?
    private var silentUntil = Date.distantPast
    private var running = false

    private init() {}

    func start() {
        guard !running else { return }
        running = true
        hush()

        monitor.pathUpdateHandler = { path in
            let reading = NetworkReachability(path: path)
            Task { @MainActor [weak self] in self?.settle(on: reading) }
        }
        monitor.start(queue: .global(qos: .utility))

        NSWorkspace.shared.notificationCenter.addObserver(
            forName: NSWorkspace.didWakeNotification, object: nil, queue: .main
        ) { _ in
            Task { @MainActor [weak self] in self?.hush() }
        }
    }

    private func hush() {
        silentUntil = Date().addingTimeInterval(Self.silence)
    }

    private func settle(on reading: NetworkReachability) {
        settling?.cancel()
        settling = nil
        guard reading != reachability else { return }

        settling = Task { [weak self] in
            try? await Task.sleep(for: .seconds(Self.settleDelay))
            guard !Task.isCancelled else { return }
            await self?.apply(reading)
        }
    }

    private func apply(_ reading: NetworkReachability) {
        let previous = reachability
        reachability = reading
        guard NetworkReachability.announces(reading, after: previous), Date() >= silentUntil else { return }
        announcement = reading
    }
}

#if DEBUG
extension NetworkReachability {
    static func selfCheck() {
        let wifi = NetworkReachability(isOnline: true, interface: .wifi)
        let ethernet = NetworkReachability(isOnline: true, interface: .wiredEthernet)
        let offline = NetworkReachability(isOnline: false)

        assert(wifi.name == "Wi-Fi")
        assert(ethernet.symbol == "cable.connector")
        assert(NetworkReachability(isOnline: true, interface: .wifi, isExpensive: true).name == "Hotspot")
        assert(NetworkReachability(isOnline: true).name == "Online", "a connection of no known kind is still one")
        assert(offline.label == "Offline")
        assert(wifi.label == "Back online, Wi-Fi")

        assert(announces(offline, after: wifi))
        assert(announces(wifi, after: offline))
        assert(!announces(ethernet, after: wifi), "a cable the user plugged in reports itself")
        assert(!announces(wifi, after: wifi))
    }
}
#endif
