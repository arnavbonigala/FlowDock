//
//  CalendarManager.swift
//  FlowDock
//
//  Created by Harsh Vardhan  Goswami  on 08/09/24.
//

import Defaults
import EventKit
import SwiftUI

@MainActor
final class CalendarManager: ObservableObject {
    static let shared = CalendarManager()

    @Published private(set) var events: [EventModel] = []
    @Published private(set) var day: Date = Calendar.current.startOfDay(for: .now)

    @Published private(set) var eventCalendars: [CalendarModel] = []
    @Published private(set) var reminderLists: [CalendarModel] = []
    @Published private(set) var selectedCalendarIDs: Set<String> = []

    @Published private(set) var calendarAuthorizationStatus: EKAuthorizationStatus = .notDetermined
    @Published private(set) var reminderAuthorizationStatus: EKAuthorizationStatus = .notDetermined

    private let service = CalendarService()
    private var observers: [NSObjectProtocol] = []
    private var coalescedRefresh: Task<Void, Never>?

    private init() {
        #if DEBUG
        Self.selfCheck()
        #endif

        calendarAuthorizationStatus = EKEventStore.authorizationStatus(for: .event)
        reminderAuthorizationStatus = EKEventStore.authorizationStatus(for: .reminder)

        observers = [.EKEventStoreChanged, .NSCalendarDayChanged, .NSSystemTimeZoneDidChange].map { name in
            NotificationCenter.default.addObserver(forName: name, object: nil, queue: .main) { [weak self] _ in
                Task { @MainActor in self?.refreshSoon() }
            }
        }

        Task { await refresh() }
    }

    deinit {
        observers.forEach(NotificationCenter.default.removeObserver)
        coalescedRefresh?.cancel()
    }

    private func refreshSoon() {
        coalescedRefresh?.cancel()
        coalescedRefresh = Task { [weak self] in
            try? await Task.sleep(for: .milliseconds(500))
            guard !Task.isCancelled else { return }
            await self?.refresh()
        }
    }

    var hasAccess: Bool {
        calendarAuthorizationStatus == .fullAccess || reminderAuthorizationStatus == .fullAccess
    }

    var canRequestAccess: Bool {
        calendarAuthorizationStatus == .notDetermined || reminderAuthorizationStatus == .notDetermined
    }

    func refresh() async {
        calendarAuthorizationStatus = EKEventStore.authorizationStatus(for: .event)
        reminderAuthorizationStatus = EKEventStore.authorizationStatus(for: .reminder)

        let calendars = await service.calendars()
        eventCalendars = calendars.filter { !$0.isReminder }
        reminderLists = calendars.filter { $0.isReminder }
        selectedCalendarIDs = Self.selection(Defaults[.calendarSelectionState], among: calendars)

        day = Calendar.current.startOfDay(for: .now)
        events = await service.events(
            from: day,
            to: Calendar.current.date(byAdding: .day, value: 1, to: day) ?? day,
            calendars: Array(selectedCalendarIDs)
        )
    }

    func requestAccess() async {
        calendarAuthorizationStatus = await status(of: .event)
        reminderAuthorizationStatus = await status(of: .reminder)
        await refresh()
    }

    private func status(of type: EKEntityType) async -> EKAuthorizationStatus {
        let current = EKEventStore.authorizationStatus(for: type)
        guard current == .notDetermined else { return current }
        let granted = (try? await service.requestAccess(to: type)) ?? false
        return granted ? .fullAccess : .denied
    }

    func setReminderCompleted(id: String, completed: Bool) async {
        await service.setReminderCompleted(reminderID: id, completed: completed)
        await refresh()
    }

    // MARK: - Selection

    func getCalendarSelected(_ calendar: CalendarModel) -> Bool {
        selectedCalendarIDs.contains(calendar.id)
    }

    func setCalendarSelected(_ calendar: CalendarModel, isSelected: Bool) async {
        var ids = selectedCalendarIDs
        if isSelected { ids.insert(calendar.id) } else { ids.remove(calendar.id) }

        let known = Set((eventCalendars + reminderLists).map(\.id))
        Defaults[.calendarSelectionState] = (ids.isEmpty || ids == known) ? .all : .selected(ids)
        await refresh()
    }

    static func selection(_ state: CalendarSelectionState, among calendars: [CalendarModel]) -> Set<String> {
        let known = Set(calendars.map(\.id))
        switch state {
        case .all: return known
        case .selected(let ids): return ids.intersection(known)
        }
    }
}

#if DEBUG
extension CalendarManager {
    static func selfCheck() {
        let mine = CalendarModel(id: "mine", account: "a", title: "Mine", color: .systemBlue, isSubscribed: false, isReminder: false)
        let work = CalendarModel(id: "work", account: "a", title: "Work", color: .systemRed, isSubscribed: false, isReminder: false)

        assert(selection(.all, among: [mine, work]) == ["mine", "work"])
        assert(selection(.all, among: []).isEmpty)
        assert(selection(.selected(["work"]), among: [mine, work]) == ["work"])
        assert(selection(.selected(["gone"]), among: [mine, work]).isEmpty, "a calendar that no longer exists is dropped")
        assert(selection(.selected(["work", "gone"]), among: [mine, work]) == ["work"])
    }
}
#endif
