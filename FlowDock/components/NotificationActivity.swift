//
//  NotificationActivity.swift
//  FlowDock
//

import Defaults
import SwiftUI

extension Activity {
    static let notificationID = "notification"
    static let notificationChinSide: CGFloat = 34

    static func notification(_ notification: FlowDockNotification, count: Int) -> Activity {
        Activity(
            id: notificationID,
            activityClass: .contextual,
            band: .power,
            label: notificationLabel(notification, count: count),
            chinSideWidth: notificationChinSide,
            leading: {
                NotificationGlyph(notification: notification)
                    .frame(width: notificationChinSide, alignment: .leading)
            },
            trailing: {
                Text(count > 1 ? "\(count)" : "")
                    .font(.caption)
                    .fontWeight(.semibold)
                    .monospacedDigit()
                    .foregroundStyle(.primary)
                    .frame(width: notificationChinSide, alignment: .trailing)
            }
        )
    }

    static func notificationLabel(_ notification: FlowDockNotification, count: Int) -> String {
        let base = "\(notification.app), \(notification.summary)"
        return count > 1 ? "\(base), \(count) notifications" : base
    }
}

extension View {
    func notificationActivity(in store: ActivityStore) -> some View {
        modifier(NotificationActivityBinder(store: store))
    }
}

private struct NotificationActivityBinder: ViewModifier {
    let store: ActivityStore

    @ObservedObject private var feed = NotificationFeed.shared
    @Default(.showNotifications) private var enabled

    func body(content: Content) -> some View {
        content
            .onChange(of: feed.latest) { _, latest in
                guard enabled, let latest else { return }
                let count = feed.groups.first { $0.app == latest.app }?.notifications.count ?? 1
                store.begin(.notification(latest, count: count))
            }
            .onChange(of: enabled, initial: true) { _, enabled in
                if enabled {
                    feed.start()
                } else {
                    feed.stop()
                    feed.clear()
                    store.end(Activity.notificationID)
                }
            }
    }
}

private struct NotificationGlyph: View {
    let notification: FlowDockNotification

    var body: some View {
        Group {
            if let icon = notification.icon {
                Image(nsImage: icon)
                    .resizable()
                    .aspectRatio(contentMode: .fit)
            } else {
                Image(systemName: "bell.fill")
                    .font(.chinGlyph)
                    .foregroundStyle(.primary)
            }
        }
        .frame(width: 18, height: 18)
    }
}

struct NotificationPanel: View {
    @ObservedObject private var feed = NotificationFeed.shared
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    var body: some View {
        Group {
            if !feed.groups.isEmpty {
                ScrollView(.vertical) {
                    VStack(alignment: .leading, spacing: 4) {
                        ForEach(feed.groups) { group in
                            NotificationRow(group: group)
                        }
                    }
                }
                .scrollIndicators(.never)
                .frame(maxHeight: 64)
                .transition(.materialize(reduceMotion: reduceMotion))
            }
        }
        .animation(.experience(reduceMotion: reduceMotion), value: feed.groups.isEmpty)
    }
}

private struct NotificationRow: View {
    let group: NotificationGroup

    @State private var hovering = false

    private var notification: FlowDockNotification { group.newest }

    var body: some View {
        HStack(spacing: 8) {
            NotificationGlyph(notification: notification)

            VStack(alignment: .leading, spacing: 1) {
                Text(group.notifications.count > 1 ? "\(group.app) (\(group.notifications.count))" : group.app)
                    .font(.caption)
                    .fontWeight(.semibold)
                    .lineLimit(1)
                Text(notification.summary)
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .lineLimit(1)
                    .truncationMode(.tail)
            }
            .frame(maxWidth: .infinity, alignment: .leading)

            if hovering {
                HoverButton(icon: "arrow.up.forward.app", scale: .small) {
                    NotificationFeed.shared.activate(notification)
                }
                .iconLabel("Open in \(group.app)")

                HoverButton(icon: "xmark", scale: .small) {
                    NotificationFeed.shared.dismiss(notification)
                }
                .iconLabel("Dismiss")
            }
        }
        .frame(height: 30)
        .padding(.horizontal, 8)
        .panelRowBackground()
        .onHover { hovering = $0 }
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(Activity.notificationLabel(notification, count: group.notifications.count))
        .accessibilityAction { NotificationFeed.shared.activate(notification) }
        .accessibilityAction(named: "Dismiss") { NotificationFeed.shared.dismiss(notification) }
    }
}

#if DEBUG
extension NotificationPanel {
    static func selfCheck() {
        let one = FlowDockNotification(token: "a", app: "Messages", title: "Ada", body: "On my way")
        assert(one.summary == "Ada — On my way")
        assert(FlowDockNotification(token: "b", app: "Mail", title: "Ada", body: "").summary == "Ada")
        assert(Activity.notificationLabel(one, count: 1) == "Messages, Ada — On my way")
        assert(Activity.notificationLabel(one, count: 3).hasSuffix("3 notifications"))
        assert(Activity.notification(one, count: 1).activityClass == .contextual)
        assert(Activity.notification(one, count: 1).expanded == nil)
    }
}
#endif
