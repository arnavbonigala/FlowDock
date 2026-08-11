//
//  AgendaPanel.swift
//  FlowDock
//

import AppKit
import Defaults
import SwiftUI

struct AgendaPanel: View {
    @ObservedObject private var manager = CalendarManager.shared
    @Environment(\.openURL) private var openURL

    @Default(.hideCompletedReminders) private var hideCompletedReminders
    @Default(.hideAllDayEvents) private var hideAllDayEvents
    @Default(.showFullEventTitles) private var showFullTitles
    @Default(.autoScrollToNextEvent) private var autoScroll

    private var agenda: [EventModel] {
        Self.agenda(manager.events, hideCompleted: hideCompletedReminders, hideAllDay: hideAllDayEvents)
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            if manager.hasAccess {
                header

                if agenda.isEmpty {
                    empty
                } else {
                    list
                }
            } else {
                prompt
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
    }

    // MARK: - Surfaces

    private var header: some View {
        HStack(alignment: .firstTextBaseline, spacing: 6) {
            Text("Today")
                .font(.system(size: 13, weight: .semibold))
                .foregroundStyle(.primary)

            Text(manager.day.formatted(.dateTime.weekday(.abbreviated).month(.abbreviated).day()))
                .font(.system(size: 11))
                .foregroundStyle(.secondary)
        }
        .accessibilityElement(children: .combine)
    }

    private var prompt: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("Your day, here")
                .font(.system(size: 13, weight: .semibold))
                .foregroundStyle(.primary)

            Text("FlowDock needs access to Calendar and Reminders.")
                .font(.system(size: 11))
                .foregroundStyle(.secondary)
                .fixedSize(horizontal: false, vertical: true)

            Button(manager.canRequestAccess ? "Enable" : "Open Privacy Settings") {
                if manager.canRequestAccess {
                    Task { await manager.requestAccess() }
                } else if let url = URL(string: "x-apple.systempreferences:com.apple.preference.security?Privacy_Calendars") {
                    openURL(url)
                }
            }
            .buttonStyle(.link)
            .font(.system(size: 11, weight: .medium))
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
    }

    private var empty: some View {
        Text("Nothing today")
            .font(.system(size: 12))
            .foregroundStyle(.secondary)
            .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
    }

    private var list: some View {
        ScrollViewReader { proxy in
            ScrollView {
                LazyVStack(alignment: .leading, spacing: 2) {
                    ForEach(agenda) { event in
                        row(event).id(event.id)
                    }
                }
            }
            .scrollIndicators(.never)
            .onAppear { scrollToNext(proxy) }
            .onChange(of: agenda) { _, _ in scrollToNext(proxy) }
        }
    }

    private func row(_ event: EventModel) -> some View {
        HStack(alignment: .top, spacing: 6) {
            if case .reminder(let completed) = event.type {
                ReminderCheck(completed: completed, color: Color(event.calendar.color)) {
                    Task { await manager.setReminderCompleted(id: event.id, completed: !completed) }
                }
                .padding(.top, 2)
            } else {
                RoundedRectangle(cornerRadius: 1.5, style: .continuous)
                    .fill(Color(event.calendar.color))
                    .frame(width: 3)
                    .padding(.vertical, 1)
                    .accessibilityHidden(true)
            }

            Button {
                if let url = event.calendarAppURL() { openURL(url) }
            } label: {
                HStack(alignment: .top, spacing: 6) {
                    VStack(alignment: .leading, spacing: 1) {
                        Text(event.title)
                            .font(.system(size: 12, weight: .medium))
                            .foregroundStyle(.primary)
                            .lineLimit(showFullTitles ? nil : 2)
                            .multilineTextAlignment(.leading)
                            .fixedSize(horizontal: false, vertical: true)

                        if let location = event.location, !location.isEmpty {
                            Text(location)
                                .font(.system(size: 11))
                                .foregroundStyle(.secondary)
                                .lineLimit(1)
                        }
                    }

                    Spacer(minLength: 4)

                    time(event)
                }
                .contentShape(Rectangle())
            }
            .buttonStyle(.plain)
            .accessibilityLabel(Self.label(event))
        }
        .padding(.vertical, 3)
        .opacity(Self.isSpent(event, now: .now) ? 0.5 : 1)
    }

    @ViewBuilder
    private func time(_ event: EventModel) -> some View {
        VStack(alignment: .trailing, spacing: 1) {
            if event.isAllDay {
                Text("All-day")
                    .font(.system(size: 11, weight: .medium))
                    .foregroundStyle(.primary)
            } else {
                Text(event.start, style: .time)
                    .font(.system(size: 11))
                    .foregroundStyle(.primary)

                if !event.type.isReminder {
                    Text(event.end, style: .time)
                        .font(.system(size: 11))
                        .foregroundStyle(.secondary)
                }
            }
        }
        .monospacedDigit()
        .lineLimit(1)
        .fixedSize()
        .accessibilityHidden(true)
    }

    private func scrollToNext(_ proxy: ScrollViewProxy) {
        guard autoScroll, let target = Self.next(in: agenda, now: .now) else { return }
        withTransaction(Transaction(animation: nil)) {
            proxy.scrollTo(target.id, anchor: .top)
        }
    }

    // MARK: - Rules

    static func agenda(_ events: [EventModel], hideCompleted: Bool, hideAllDay: Bool) -> [EventModel] {
        events.filter { event in
            if case .reminder(let completed) = event.type {
                return !(completed && hideCompleted)
            }
            return !(event.isAllDay && hideAllDay)
        }
    }

    static func next(in agenda: [EventModel], now: Date) -> EventModel? {
        agenda.first { !$0.isAllDay && $0.end > now }
            ?? agenda.first { $0.isAllDay }
            ?? agenda.last
    }

    static func isSpent(_ event: EventModel, now: Date) -> Bool {
        if case .reminder(let completed) = event.type { return completed }
        return !event.isAllDay && event.end <= now
    }

    static func label(_ event: EventModel) -> String {
        let when = event.isAllDay
            ? "all day"
            : event.start.formatted(date: .omitted, time: .shortened)
        if case .reminder(let completed) = event.type {
            return "\(event.title), \(when)\(completed ? ", completed" : "")"
        }
        return "\(event.title), \(when)"
    }
}

// MARK: - Reminder check

private struct ReminderCheck: View {
    let completed: Bool
    let color: Color
    let toggle: () -> Void

    var body: some View {
        Button(action: toggle) {
            ZStack {
                Circle()
                    .strokeBorder(color, lineWidth: 2)
                    .frame(width: 12, height: 12)

                if completed {
                    Circle()
                        .fill(color)
                        .frame(width: 7, height: 7)
                }
            }
            .frame(width: 28, height: 28)
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .accessibilityLabel(completed ? "Mark as incomplete" : "Mark as complete")
    }
}

#if DEBUG
extension EventModel {
    static func stub(
        _ title: String,
        start: Date = .now,
        duration: TimeInterval = 3600,
        isAllDay: Bool = false,
        type: EventType = .event(.accepted)
    ) -> EventModel {
        EventModel(
            id: title,
            start: start,
            end: start.addingTimeInterval(duration),
            title: title,
            location: nil,
            notes: nil,
            url: nil,
            isAllDay: isAllDay,
            type: type,
            calendar: CalendarModel(
                id: "calendar",
                account: "Account",
                title: "Calendar",
                color: .systemBlue,
                isSubscribed: false,
                isReminder: type.isReminder
            ),
            participants: [],
            timeZone: nil,
            hasRecurrenceRules: false,
            priority: nil
        )
    }
}

extension AgendaPanel {
    static func selfCheck() {
        let noon = Date(timeIntervalSinceReferenceDate: 43200)
        let morning = EventModel.stub("morning", start: noon.addingTimeInterval(-7200))
        let evening = EventModel.stub("evening", start: noon.addingTimeInterval(7200))
        let allDay = EventModel.stub("all day", isAllDay: true)
        let done = EventModel.stub("done", type: .reminder(completed: true))
        let todo = EventModel.stub("todo", type: .reminder(completed: false))
        let all = [morning, evening, allDay, done, todo]

        assert(agenda(all, hideCompleted: false, hideAllDay: false).count == 5)
        assert(!agenda(all, hideCompleted: true, hideAllDay: false).contains(done))
        assert(agenda(all, hideCompleted: true, hideAllDay: false).contains(todo), "only completed reminders hide")
        assert(!agenda(all, hideCompleted: false, hideAllDay: true).contains(allDay))
        assert(agenda(all, hideCompleted: true, hideAllDay: true).count == 3)

        assert(next(in: [morning, evening], now: noon)?.id == "evening", "the next one still to come")
        assert(next(in: [morning, allDay], now: noon)?.id == "all day", "nothing left today falls back to all-day")
        assert(next(in: [morning], now: noon)?.id == "morning", "then to the last thing that happened")
        assert(next(in: [], now: noon) == nil)

        assert(isSpent(morning, now: noon))
        assert(!isSpent(evening, now: noon))
        assert(!isSpent(allDay, now: noon), "an all-day entry is not spent at noon")
        assert(isSpent(done, now: noon))
        assert(!isSpent(todo, now: noon))
    }
}

#Preview {
    AgendaPanel()
        .frame(width: 260, height: 150)
        .padding(12)
        .background(.black)
        .preferredColorScheme(.dark)
}
#endif
