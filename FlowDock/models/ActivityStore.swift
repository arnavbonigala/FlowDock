//
//  ActivityStore.swift
//  FlowDock
//
//  Owns which activity holds the chin, and what state that puts FlowDock in.
//  See INTERACTION.md.
//

import Defaults
import Foundation

@MainActor
final class ActivityStore: ObservableObject {
    /// One duration for the whole contextual class. An activity does not get its own.
    static let contextualDwell: Duration = .seconds(1.5)

    /// ponytail: one store per display, created by that display's view. Routing activities
    /// from the managers to the right store lands with the first activity in section 3.
    @Published private(set) var activities: [Activity] = []

    private var expiry: [String: Task<Void, Never>] = [:]

    init() {
        #if DEBUG
        Activity.selfCheck()
        PowerReading.selfCheck()
        AgendaPanel.selfCheck()
        ShelfPanel.selfCheck()
        NotificationPanel.selfCheck()
        DevicePanel.selfCheck()
        ProgressPanel.selfCheck()
        MeetingPanel.selfCheck()
        ActivityCatalog.selfCheck()
        #endif
    }

    deinit {
        expiry.values.forEach { $0.cancel() }
    }

    var owner: Activity? { Activity.owner(of: activities, priority: Defaults[.activityPriority]) }

    var chinState: ActivityState {
        guard let owner else { return .idle }
        return owner.activityClass == .contextual ? .contextual : .persistent
    }

    /// Starts an activity, or updates one already running. An update keeps the original
    /// start time — it is the same activity, not a new one — and restarts the dwell.
    func begin(_ activity: Activity) {
        guard ActivityCatalog.isEnabled(activity.id) else { return end(activity.id) }
        var activity = activity
        if let index = activities.firstIndex(where: { $0.id == activity.id }) {
            activity.startedAt = activities[index].startedAt
            activities[index] = activity
        } else {
            activities.append(activity)
        }
        scheduleExpiry(for: activity)
    }

    func end(_ id: String) {
        expiry.removeValue(forKey: id)?.cancel()
        activities.removeAll { $0.id == id }
    }

    private func scheduleExpiry(for activity: Activity) {
        expiry.removeValue(forKey: activity.id)?.cancel()
        guard activity.activityClass == .contextual else { return }

        expiry[activity.id] = Task { [weak self] in
            try? await Task.sleep(for: Self.contextualDwell)
            guard !Task.isCancelled else { return }
            self?.end(activity.id)
        }
    }
}
