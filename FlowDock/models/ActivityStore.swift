//
//  ActivityStore.swift
//  FlowDock
//
//  Owns which activity holds the chin, and what state that puts FlowDock in.
//  See INTERACTION.md.
//

import AppKit
import Combine
import Defaults
import Foundation
import SwiftUI

@MainActor
final class ActivityStore: ObservableObject {
    /// One duration for the whole contextual class. An activity does not get its own.
    /// 1.5 s is enough to glance at a HUD and not enough to hear one, so VoiceOver gets
    /// long enough for the announcement to finish. See INTERACTION.md §Timing.
    static var contextualDwell: Duration {
        NSWorkspace.shared.isVoiceOverEnabled ? .seconds(4) : .seconds(1.5)
    }

    /// ponytail: one store per display, created by that display's view. Routing activities
    /// from the managers to the right store lands with the first activity in section 3.
    @Published private(set) var activities: [Activity] = []

    /// How long a hold lasts. Every entry ends, and the longest is half an hour: the top
    /// edge reports what is happening now, and a hold with no end is a pin board.
    static let holdDurations: [TimeInterval] = [5 * 60, 15 * 60, 30 * 60]

    @Published private(set) var heldUntil: Date?
    private(set) var heldDuration: TimeInterval?
    private var heldID: String?
    private var holdTask: Task<Void, Never>?

    private var expiry: [String: Task<Void, Never>] = [:]
    private var pruning: AnyCancellable?

    init() {
        pruning = NotificationCenter.default
            .publisher(for: UserDefaults.didChangeNotification)
            .sink { [weak self] _ in
                Task { @MainActor in self?.prune() }
            }

        #if DEBUG
        Activity.selfCheck()
        PowerReading.selfCheck()
        AgendaPanel.selfCheck()
        ShelfPanel.selfCheck()
        NotificationPanel.selfCheck()
        CallPanel.selfCheck()
        DevicePanel.selfCheck()
        ProgressPanel.selfCheck()
        MeetingPanel.selfCheck()
        ActivityCatalog.selfCheck()
        NSImage.selfCheck()
        ExtensionContract.selfCheck()
        ActivityStore.selfCheck()
        #endif
    }

    deinit {
        expiry.values.forEach { $0.cancel() }
        holdTask?.cancel()
    }

    var owner: Activity? {
        let natural = Activity.owner(of: activities, priority: Defaults[.activityPriority])
        guard let heldID, let held = activities.first(where: { $0.id == heldID }) else { return natural }

        /// A hold outranks the priority list, not the machine answering a key press. A drag
        /// and the volume and brightness HUDs are the user's own doing and are gone in a
        /// second and a half, so they still take the chin and give it straight back.
        if let natural, natural.band < .power { return natural }
        return held
    }

    var isHolding: Bool { heldUntil != nil }

    /// Pressing again lengthens the hold, and pressing past the longest ends it. One control
    /// both sets and releases it, because a hold whose end the user cannot see is one they
    /// have to remember to undo.
    static func nextHold(after current: TimeInterval?) -> TimeInterval? {
        guard let current, let index = holdDurations.firstIndex(of: current) else {
            return holdDurations.first
        }
        return index + 1 < holdDurations.count ? holdDurations[index + 1] : nil
    }

    var holdLabel: String {
        guard let next = Self.nextHold(after: heldDuration) else { return "Release the notch" }
        return "Hold the notch for \(Int(next / 60)) minutes"
    }

    func toggleHold() {
        guard let owner else { return release() }
        let current = heldID == owner.id ? heldDuration : nil
        guard let duration = Self.nextHold(after: current) else { return release() }

        heldID = owner.id
        heldDuration = duration
        heldUntil = Date().addingTimeInterval(duration)

        holdTask?.cancel()
        holdTask = Task { [weak self] in
            try? await Task.sleep(for: .seconds(duration))
            guard !Task.isCancelled else { return }
            self?.release()
        }
    }

    func release() {
        holdTask?.cancel()
        holdTask = nil
        heldID = nil
        heldDuration = nil
        heldUntil = nil
    }

    /// The one activity that keeps a mark beside the chin while another holds it. Two marks
    /// over the menu bar is the cap — a third is a menu bar. A contextual owner is momentary
    /// and the activity it interrupted is coming straight back, so it shows none at all.
    var secondary: Activity? {
        guard let owner, owner.activityClass == .persistent else { return nil }
        let others = activities.filter { $0.id != owner.id && $0.activityClass == .persistent }
        return Activity.owner(of: others, priority: Defaults[.activityPriority])
    }

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

    func prune() {
        for activity in activities where !ActivityCatalog.isEnabled(activity.id) {
            end(activity.id)
        }
    }

    func end(_ id: String) {
        if heldID == id { release() }
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

struct HoldButton: View {
    @ObservedObject var store: ActivityStore

    var body: some View {
        if store.owner != nil || store.isHolding {
            HStack(spacing: 6) {
                if let until = store.heldUntil {
                    CountdownText(to: until)
                        .foregroundStyle(.secondary)
                        .accessibilityHidden(true)
                }

                HoverButton(
                    icon: store.isHolding ? "pin.fill" : "pin",
                    iconColor: store.isHolding ? .effectiveAccent : .secondary,
                    scale: .small
                ) {
                    store.toggleHold()
                }
                .iconLabel(store.holdLabel)
            }
        }
    }
}

#if DEBUG
extension ActivityStore {
    static func selfCheck() {
        assert(nextHold(after: nil) == holdDurations[0])
        assert(nextHold(after: holdDurations[0]) == holdDurations[1])
        assert(nextHold(after: holdDurations[1]) == holdDurations[2])
        assert(nextHold(after: holdDurations.last) == nil, "past the longest hold is no hold")
    }
}
#endif
