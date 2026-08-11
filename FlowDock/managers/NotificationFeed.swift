//
//  NotificationFeed.swift
//  FlowDock
//

import AppKit
import Combine
import Defaults
import Foundation

struct FlowDockNotification: Identifiable, Equatable, Codable {
    let token: String
    let app: String
    let title: String
    let body: String
    let actions: [String]

    var id: String { token }

    /// A call is a notification whose buttons answer and decline it. FlowDock does not
    /// recognise calls — it offers the buttons the alert offers, so this stays true of
    /// whatever else macOS decides to put two buttons on.
    var isInteractive: Bool { actions.count > 1 }

    /// FaceTime puts the route in the alert's body — "iPhone" for a call ringing through a
    /// phone, the kind of call it is otherwise. An application that says nothing there is
    /// itself the route.
    var callRoute: String { body.isEmpty ? app : body }

    var summary: String {
        body.isEmpty ? title : "\(title) — \(body)"
    }

    @MainActor
    var icon: NSImage? { RunningAppIcons.icon(named: app) }
}

struct NotificationGroup: Identifiable {
    let app: String
    let notifications: [FlowDockNotification]

    var id: String { app }
    var newest: FlowDockNotification { notifications[0] }
}

@MainActor
final class NotificationFeed: ObservableObject {
    static let shared = NotificationFeed()

    static let historyLimit = 12

    /// A ringing call cannot be told from any other alert by what it says: the application
    /// may be anything and the buttons are in the user's language. It can be told by what it
    /// does. A banner is gone in about five seconds, so an alert carrying buttons of its own
    /// that is still on screen after that is ringing — whoever is ringing it.
    static let ringingDelay: TimeInterval = 6

    @Published private(set) var recent: [FlowDockNotification] = []
    @Published private(set) var latest: FlowDockNotification?
    @Published private(set) var call: FlowDockNotification?

    /// What is still on screen, as opposed to what has been seen. A ringing call has to
    /// stop ringing the moment its alert goes, and history cannot say when that was.
    private var present: [FlowDockNotification] = []
    private var firstSeen: [String: Date] = [:]
    private var ringingTask: Task<Void, Never>?
    private var seen: Set<String> = []
    private var running = false

    static func ringing(
        among present: [FlowDockNotification], firstSeen: [String: Date], now: Date
    ) -> FlowDockNotification? {
        present.first {
            $0.isInteractive && now.timeIntervalSince(firstSeen[$0.token] ?? now) >= ringingDelay
        }
    }

    private init() {}

    var groups: [NotificationGroup] {
        var order: [String] = []
        var byApp: [String: [FlowDockNotification]] = [:]

        for notification in recent {
            if byApp[notification.app] == nil { order.append(notification.app) }
            byApp[notification.app, default: []].append(notification)
        }

        return order.map { NotificationGroup(app: $0, notifications: byApp[$0] ?? []) }
    }

    func start() {
        guard Defaults[.showNotifications], !running else { return }
        running = true
        XPCHelperClient.shared.startNotificationRelay { [weak self] json in
            Task { @MainActor in self?.ingest(json) }
        }
    }

    func stop() {
        guard running else { return }
        running = false
        XPCHelperClient.shared.stopNotificationRelay()
        latest = nil
        clearPresent()
    }

    func clear() {
        recent = []
        latest = nil
        clearPresent()
    }

    private func clearPresent() {
        ringingTask?.cancel()
        ringingTask = nil
        present = []
        firstSeen = [:]
        call = nil
    }

    func remove(_ notification: FlowDockNotification) {
        recent.removeAll { $0.token == notification.token }
        present.removeAll { $0.token == notification.token }
        firstSeen[notification.token] = nil
        if latest?.token == notification.token { latest = nil }
        if call?.token == notification.token { call = nil }
    }

    func activate(_ notification: FlowDockNotification) {
        XPCHelperClient.shared.performNotificationAction("activate", token: notification.token)
        remove(notification)
    }

    func perform(_ action: String, on notification: FlowDockNotification) {
        XPCHelperClient.shared.performNotificationAction(action, token: notification.token)
        remove(notification)
    }

    func dismiss(_ notification: FlowDockNotification) {
        XPCHelperClient.shared.performNotificationAction("dismiss", token: notification.token)
        remove(notification)
    }

    func ingest(_ json: String) {
        guard Defaults[.showNotifications],
              let data = json.data(using: .utf8),
              let delivered = try? JSONDecoder().decode([FlowDockNotification].self, from: data)
        else { return }

        let arriving = delivered.filter { !seen.contains($0.token) }

        /// The relay reports everything still in Notification Center, so what has already
        /// been announced is exactly what is still on that list. Remembering a fixed number
        /// of tokens instead re-announces the oldest one still sitting there.
        seen = Set(delivered.map(\.token))
        present = delivered

        let now = Date()
        for notification in arriving { firstSeen[notification.token] = now }
        firstSeen = firstSeen.filter { seen.contains($0.key) }
        promote()

        if !arriving.isEmpty {
            recent = Array((arriving.reversed() + recent).prefix(Self.historyLimit))
            latest = recent.first
        }
    }

    private func promote() {
        ringingTask?.cancel()
        ringingTask = nil

        call = Self.ringing(among: present, firstSeen: firstSeen, now: Date())

        /// A call that has just arrived is not yet distinguishable from a banner, and no
        /// further relay message is due while it simply sits there ringing. One delayed
        /// look settles it; nothing waits when there is nothing waiting to be settled.
        if let call {
            /// The chin is announcing it, so the list must not announce it twice.
            recent.removeAll { $0.token == call.token }
            if latest?.token == call.token { latest = recent.first }
        } else if present.contains(where: \.isInteractive) {
            ringingTask = Task { [weak self] in
                try? await Task.sleep(for: .seconds(Self.ringingDelay))
                guard !Task.isCancelled else { return }
                await self?.promote()
            }
        }
    }
}
