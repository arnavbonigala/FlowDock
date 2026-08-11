//
//  NotificationActivity.swift
//  FlowDock
//

import Defaults
import SwiftUI

extension Activity {
    static let notificationID = "notification"

    static func notification(_ notification: FlowDockNotification, count: Int) -> Activity {
        Activity(
            id: notificationID,
            activityClass: .contextual,
            band: .power,
            label: notificationLabel(notification, count: count),
            chinSideWidth: Activity.chinSide,
            leading: {
                NotificationGlyph(notification: notification)
                    .frame(width: Activity.chinSide, alignment: .leading)
            },
            trailing: {
                Text(count > 1 ? "\(count)" : "")
                    .font(.caption)
                    .fontWeight(.semibold)
                    .monospacedDigit()
                    .foregroundStyle(.primary)
                    .frame(width: Activity.chinSide, alignment: .trailing)
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
                let key = NotificationGroup.key(latest)
                let count = feed.groups.first { $0.id == key }?.notifications.count ?? 1
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
    @State private var feedHeight: CGFloat = 0
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
                    .measuring($feedHeight, along: .vertical)
                }
                .scrollIndicators(.never)
                .frame(maxHeight: 64)
                .fadesPastEdge(.vertical, contentLength: feedHeight)
                .transition(.materialize(reduceMotion: reduceMotion))
            }
        }
        .animation(.content, value: feed.groups.isEmpty)
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
                /// The row is headed by who it is from, not what it came through — the icon
                /// beside it already says the application, and saying it twice costs the line
                /// that would have said the name.
                Text(group.notifications.count > 1 ? "\(group.title) (\(group.notifications.count))" : group.title)
                    .font(.caption)
                    .fontWeight(.semibold)
                    .lineLimit(1)
                Text(notification.body.isEmpty ? group.app : notification.body)
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .lineLimit(1)
                    .truncationMode(.tail)
            }
            .frame(maxWidth: .infinity, alignment: .leading)

            if notification.isInteractive {
                /// A ringing call cannot wait for the pointer to arrive, so an alert that
                /// carries its own buttons shows them rather than the hover pair.
                ForEach(notification.actions.prefix(2), id: \.self) { action in
                    Button {
                        NotificationFeed.shared.perform(action, on: notification)
                    } label: {
                        Text(action)
                            .font(.panelMeta)
                            .lineLimit(1)
                            .padding(.horizontal, 8)
                            .frame(height: 20)
                            .background(.quaternary, in: Capsule())
                            .contentShape(Capsule())
                    }
                    .buttonStyle(.plain)
                }
            } else if hovering {
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
        .frame(height: PanelRow.content)
        .padding(.horizontal, 8)
        .panelRowBackground()
        .onHover { hovering = $0 }
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(Activity.notificationLabel(notification, count: group.notifications.count))
        .accessibilityAction { NotificationFeed.shared.activate(notification) }
        .accessibilityAction(named: "Dismiss") { NotificationFeed.shared.dismiss(notification) }
        .accessibilityActions {
            ForEach(notification.actions, id: \.self) { action in
                Button(action) { NotificationFeed.shared.perform(action, on: notification) }
            }
        }
    }
}

#if DEBUG
extension NotificationPanel {
    static func selfCheck() {
        let one = FlowDockNotification(token: "a", app: "Messages", title: "Ada", body: "On my way", actions: [])
        assert(one.summary == "Ada — On my way")
        assert(FlowDockNotification(token: "b", app: "Mail", title: "Ada", body: "", actions: []).summary == "Ada")
        assert(Activity.notificationLabel(one, count: 1) == "Messages, Ada — On my way")
        assert(Activity.notificationLabel(one, count: 3).hasSuffix("3 notifications"))
        assert(Activity.notification(one, count: 1).activityClass == .contextual)
        assert(Activity.notification(one, count: 1).expanded == nil)
        assert(!one.isInteractive)
        let call = FlowDockNotification(
            token: "c", app: "FaceTime", title: "Ada", body: "iPhone", actions: ["Decline", "Accept"])
        assert(call.isInteractive, "an alert with its own buttons offers them instead of the hover pair")

        let other = FlowDockNotification(token: "e", app: "Messages", title: "Grace", body: "Hi", actions: [])
        assert(NotificationGroup.key(one) != NotificationGroup.key(other),
               "two people in one app are two conversations, not one count of three")
        assert(NotificationGroup.key(one)
               == NotificationGroup.key(
                   FlowDockNotification(token: "f", app: "Messages", title: "Ada", body: "Two", actions: [])))
    }
}
#endif
