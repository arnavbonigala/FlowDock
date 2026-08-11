//
//  CallActivity.swift
//  FlowDock
//

import Defaults
import SwiftUI

extension Activity {
    static let callID = "call"

    static func call(_ notification: FlowDockNotification) -> Activity {
        Activity(
            id: callID,
            activityClass: .persistent,
            /// A ringing call shares its band with notifications rather than claiming a
            /// new one: bands rank proximity, not importance, and a call that has just
            /// started already wins the tie on recency.
            band: .power,
            label: CallPanel.label(notification),
            chinSideWidth: Activity.chinClockSide,
            leading: {
                Image(systemName: "phone.fill")
                    .font(.chinGlyph)
                    .foregroundStyle(.green)
                    .frame(width: Activity.chinClockSide, alignment: .leading)
            },
            trailing: {
                Text(notification.title)
                    .font(.chinValue)
                    .lineLimit(1)
                    .truncationMode(.tail)
                    .foregroundStyle(.primary)
                    .frame(width: Activity.chinClockSide, alignment: .trailing)
            }
        )
        .withExpanded { CallPanel(notification: notification) }
    }
}

extension View {
    func callActivity(in store: ActivityStore) -> some View {
        modifier(CallActivityBinder(store: store))
    }
}

private struct CallActivityBinder: ViewModifier {
    let store: ActivityStore

    @ObservedObject private var feed = NotificationFeed.shared
    @Default(.showNotifications) private var enabled

    func body(content: Content) -> some View {
        content.onChange(of: feed.call) { _, call in
            guard enabled, let call else {
                store.end(Activity.callID)
                return
            }
            store.begin(.call(call))
        }
    }
}

struct CallPanel: View {
    let notification: FlowDockNotification

    static func label(_ notification: FlowDockNotification) -> String {
        "Incoming call from \(notification.title), \(notification.callRoute)"
    }

    var body: some View {
        HStack(spacing: 12) {
            Image(systemName: "phone.fill")
                .font(.panelPrimary)
                .foregroundStyle(.green)
                .accessibilityHidden(true)

            VStack(alignment: .leading, spacing: 2) {
                Text(notification.title)
                    .font(.panelPrimary)
                    .foregroundStyle(.primary)
                    .lineLimit(1)
                Text(notification.callRoute)
                    .font(.panelMeta)
                    .foregroundStyle(.secondary)
                    .lineLimit(1)
            }

            Spacer()

            ForEach(notification.actions.prefix(2), id: \.self) { action in
                Button {
                    NotificationFeed.shared.perform(action, on: notification)
                } label: {
                    Text(action)
                        .font(.panelControl)
                        .padding(.horizontal, 12)
                        .frame(height: 28)
                        .background(.quaternary, in: Capsule())
                        .contentShape(Capsule())
                }
                .buttonStyle(.plain)
            }
        }
        .padding(.horizontal, 12)
        .accessibilityElement(children: .contain)
        .accessibilityLabel(Self.label(notification))
    }
}

#if DEBUG
extension CallPanel {
    static func selfCheck() {
        let call = FlowDockNotification(
            token: "c", app: "Phone", title: "Ada", body: "iPhone", actions: ["Decline", "Accept"])
        assert(call.callRoute == "iPhone")
        assert(label(call) == "Incoming call from Ada, iPhone")

        let missed = FlowDockNotification(
            token: "d", app: "FaceTime", title: "Ada", body: "", actions: ["Call Back"])
        assert(missed.callRoute == "FaceTime")

        let start = Date()
        let ringing = start.addingTimeInterval(NotificationFeed.ringingDelay)
        let seen = [call.token: start, missed.token: start]

        assert(NotificationFeed.ringing(among: [call, missed], firstSeen: seen, now: start) == nil,
               "an alert that has only just appeared could still be a banner")
        assert(NotificationFeed.ringing(among: [call, missed], firstSeen: seen, now: ringing) == call,
               "an alert with its own buttons that outlasts a banner is ringing")
        assert(NotificationFeed.ringing(among: [missed], firstSeen: seen, now: ringing) == nil,
               "one button is a missed call, not a ringing one")
    }
}
#endif
