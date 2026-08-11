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
        var hosted = false

        static func == (lhs: Entry, rhs: Entry) -> Bool { lhs.id == rhs.id }
    }

    static let all: [Entry] = [
        Entry(id: Activity.musicID, name: "Music", symbol: "play.laptopcomputer", key: .showMusicActivity),
        Entry(id: Activity.notificationID, name: "Notifications", symbol: "bell.badge", key: .showNotifications),
        Entry(id: Activity.callID, name: "Calls", symbol: "phone", key: nil),
        Entry(id: Activity.powerID, name: "Power", symbol: "battery.100.bolt", key: .showPowerStatusNotifications),
        Entry(id: Activity.deviceID, name: "Devices", symbol: "airpods", key: .showDeviceStatus),
        Entry(id: Activity.microphoneID, name: "Microphone", symbol: "mic", key: .showMicrophoneActivity),
        Entry(id: Activity.progressID, name: "Downloads", symbol: "arrow.down.circle", key: .showDownloads),
        Entry(id: Activity.meetingID, name: "Meetings", symbol: "video", key: .showMeetingCountdown),
        Entry(id: Activity.timerID, name: "Timers", symbol: "timer", key: nil),
        Entry(id: Activity.shelfID, name: "Shelf", symbol: "tray.full", key: .shelfEnabled),
        Entry(id: Activity.keepAwakeID, name: "Keep Awake", symbol: "cup.and.saucer", key: nil),
    ]

    static func entry(_ id: String) -> Entry? {
        all.first { $0.id == id } ?? all.first { id.hasPrefix($0.id) }
    }

    static func isEnabled(_ id: String) -> Bool {
        guard let key = entry(id)?.key else { return true }
        return Defaults[key]
    }

    static func ordered(_ priority: [String], including extra: [Entry] = []) -> [Entry] {
        let pool = all + extra
        let known = priority.compactMap { id in pool.first { $0.id == id } }
        return known + pool.filter { entry in !known.contains(entry) }
    }
}

#if DEBUG
extension ActivityCatalog {
    static func selfCheck() {
        assert(entry(Activity.musicID) != nil)
        assert(entry("nothing") == nil)
        assert(entry(Activity.progressDoneID)?.id == Activity.progressID, "a completion follows its activity's switch")
        assert(entry(Activity.timerDoneID)?.id == Activity.timerID)
        for entry in all {
            assert(
                all.filter { entry.id.hasPrefix($0.id) }.count == 1,
                "one catalog id prefixes another, so which switch a completion follows depends on list order"
            )
        }
        assert(isEnabled("nothing"), "an activity outside the catalog is never suppressed")
        assert(isEnabled(Activity.timerID), "an activity with no setting is always on")
        assert(ordered([]).map(\.id) == all.map(\.id))
        assert(ordered([Activity.shelfID]).first?.id == Activity.shelfID)
        assert(ordered([Activity.shelfID]).count == all.count)
        assert(ordered(["nothing"]).map(\.id) == all.map(\.id))

        let hosted = Entry(id: "com.acme.ext.timer", name: "Timer", symbol: "timer", key: nil, hosted: true)
        assert(ordered([], including: [hosted]).last == hosted, "a discovered extension joins the bottom")
        assert(ordered([hosted.id], including: [hosted]).first == hosted, "and can be ranked like anything else")
        assert(isEnabled(hosted.id), "the host decides whether an extension runs, not the catalog")
    }
}
#endif
