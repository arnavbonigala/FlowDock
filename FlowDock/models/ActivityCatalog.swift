//
//  ActivityCatalog.swift
//  FlowDock
//

import Defaults
import Foundation

struct ActivityCatalog {
    struct Entry: Identifiable, Equatable {
        let id: String
        let name: String
        let symbol: String
        let key: Defaults.Key<Bool>?

        static func == (lhs: Entry, rhs: Entry) -> Bool { lhs.id == rhs.id }
    }

    static let all: [Entry] = [
        Entry(id: Activity.musicID, name: "Music", symbol: "play.laptopcomputer", key: .showMusicActivity),
        Entry(id: Activity.notificationID, name: "Notifications", symbol: "bell.badge", key: .showNotifications),
        Entry(id: Activity.powerID, name: "Power", symbol: "battery.100.bolt", key: .showPowerStatusNotifications),
        Entry(id: Activity.deviceID, name: "Devices", symbol: "airpods", key: .showDeviceStatus),
        Entry(id: Activity.progressID, name: "Downloads", symbol: "arrow.down.circle", key: .showDownloads),
        Entry(id: Activity.meetingID, name: "Meetings", symbol: "video", key: .showMeetingCountdown),
        Entry(id: Activity.timerID, name: "Timers", symbol: "timer", key: nil),
        Entry(id: Activity.shelfID, name: "Shelf", symbol: "tray.full", key: .shelfEnabled),
    ]

    static func entry(_ id: String) -> Entry? {
        all.first { $0.id == id }
    }

    static func isEnabled(_ id: String) -> Bool {
        guard let key = entry(id)?.key else { return true }
        return Defaults[key]
    }

    /// The catalog order, with whatever the user has reordered moved to the front.
    static func ordered(_ priority: [String]) -> [Entry] {
        let known = priority.compactMap(entry)
        return known + all.filter { entry in !known.contains(entry) }
    }
}

#if DEBUG
extension ActivityCatalog {
    static func selfCheck() {
        assert(entry(Activity.musicID) != nil)
        assert(entry("nothing") == nil)
        assert(isEnabled("nothing"), "an activity outside the catalog is never suppressed")
        assert(isEnabled(Activity.timerID), "an activity with no setting is always on")
        assert(ordered([]).map(\.id) == all.map(\.id))
        assert(ordered([Activity.shelfID]).first?.id == Activity.shelfID)
        assert(ordered([Activity.shelfID]).count == all.count)
        assert(ordered(["nothing"]).map(\.id) == all.map(\.id))
    }
}
#endif
