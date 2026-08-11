//
//  NetworkActivity.swift
//  FlowDock
//

import Defaults
import SwiftUI

extension Activity {
    static let networkID = "network"

    static func network(_ reachability: NetworkReachability) -> Activity {
        Activity(
            id: networkID,
            activityClass: .contextual,
            band: .power,
            label: reachability.label,
            chinSideWidth: Activity.chinSide,
            leading: {
                Image(systemName: reachability.symbol)
                    .font(.chinGlyph)
                    .foregroundStyle(reachability.isOnline ? .primary : Color.red)
                    .frame(width: Activity.chinSide, alignment: .leading)
            },
            trailing: {
                Text(reachability.name)
                    .font(.chinValue)
                    .foregroundStyle(.primary)
                    .lineLimit(1)
                    .frame(width: Activity.chinSide, alignment: .trailing)
            }
        )
    }
}

extension View {
    func networkActivity(in store: ActivityStore) -> some View {
        modifier(NetworkActivityBinder(store: store))
    }
}

private struct NetworkActivityBinder: ViewModifier {
    let store: ActivityStore

    @ObservedObject private var network = NetworkMonitor.shared
    @Default(.showNetworkStatus) private var enabled

    func body(content: Content) -> some View {
        content
            .onChange(of: network.announcement) { _, announcement in
                guard enabled, let announcement else { return }
                store.begin(.network(announcement))
            }
            .onChange(of: enabled, initial: true) { _, enabled in
                if enabled { network.start() }
            }
    }
}
