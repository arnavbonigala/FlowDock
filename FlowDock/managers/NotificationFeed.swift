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

    @Published private(set) var recent: [FlowDockNotification] = []
    @Published private(set) var latest: FlowDockNotification?

    private var seen: Set<String> = []
    private var running = false

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
    }

    func clear() {
        recent = []
        latest = nil
    }

    func remove(_ notification: FlowDockNotification) {
        recent.removeAll { $0.token == notification.token }
        if latest?.token == notification.token { latest = nil }
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
        guard !arriving.isEmpty else { return }

        recent = Array((arriving.reversed() + recent).prefix(Self.historyLimit))
        latest = recent.first
    }
}
