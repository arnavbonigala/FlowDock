//
//  CountdownCenter.swift
//  FlowDock
//

import AppKit
import Combine
import Defaults
import Foundation

@MainActor
final class TimerCenter: ObservableObject {
    static let shared = TimerCenter()

    static let durations: [Int] = [5, 10, 25]

    @Published private(set) var endsAt: Date?
    @Published private(set) var startedAt: Date?
    @Published private(set) var finishedAt: Date?

    private var completion: Task<Void, Never>?

    private init() {}

    var isRunning: Bool { endsAt != nil }

    var fraction: Double? {
        guard let endsAt, let startedAt else { return nil }
        let total = endsAt.timeIntervalSince(startedAt)
        guard total > 0 else { return nil }
        return min(max(1 - endsAt.timeIntervalSinceNow / total, 0), 1)
    }

    func start(minutes: Int) {
        start(seconds: TimeInterval(minutes) * 60)
    }

    func start(seconds: TimeInterval) {
        completion?.cancel()
        startedAt = .now
        endsAt = Date(timeIntervalSinceNow: seconds)
        finishedAt = nil
        completion = Task { [weak self] in
            try? await Task.sleep(for: .seconds(seconds))
            guard !Task.isCancelled else { return }
            self?.finish()
        }
    }

    func cancel() {
        completion?.cancel()
        completion = nil
        endsAt = nil
        startedAt = nil
    }

    private func finish() {
        cancel()
        finishedAt = .now
        NSSound(named: "Glass")?.play()
    }
}

@MainActor
final class MeetingWatch: ObservableObject {
    static let shared = MeetingWatch()

    nonisolated static let lead: TimeInterval = 10 * 60

    @Published private(set) var imminent: EventModel?

    private var cancellable: AnyCancellable?
    private var schedule: Task<Void, Never>?

    private init() {
        cancellable = CalendarManager.shared.$events
            .receive(on: RunLoop.main)
            .sink { [weak self] events in self?.reschedule(events) }
    }

    static func imminent(in events: [EventModel], now: Date, lead: TimeInterval = lead) -> EventModel? {
        events
            .filter { !$0.isAllDay && !$0.type.isReminder && $0.end > now }
            .filter { $0.start.timeIntervalSince(now) <= lead }
            .min { $0.start < $1.start }
    }

    private func reschedule(_ events: [EventModel]) {
        schedule?.cancel()
        imminent = Self.imminent(in: events, now: .now)

        let upcoming = events
            .filter { !$0.isAllDay && !$0.type.isReminder }
            .map { $0.start.addingTimeInterval(-Self.lead) }
            .filter { $0 > .now }
            .min()

        let next = [upcoming, imminent?.end].compactMap { $0 }.min()
        guard let next else { return }

        schedule = Task { [weak self] in
            try? await Task.sleep(for: .seconds(max(1, next.timeIntervalSinceNow)))
            guard !Task.isCancelled else { return }
            self?.reschedule(CalendarManager.shared.events)
        }
    }
}

extension EventModel {
    static let conferenceHosts = [
        "zoom.us", "meet.google.com", "teams.microsoft.com", "teams.live.com",
        "webex.com", "whereby.com", "chime.aws", "gotomeeting.com",
        "bluejeans.com", "meet.jit.si", "around.co",
    ]

    var meetingURL: URL? {
        [url?.absoluteString, location, notes]
            .compactMap { $0 }
            .lazy
            .compactMap { Self.conferenceURL(in: $0) }
            .first
    }

    static func conferenceURL(in text: String) -> URL? {
        guard let detector = try? NSDataDetector(types: NSTextCheckingResult.CheckingType.link.rawValue) else {
            return nil
        }
        let matches = detector.matches(in: text, range: NSRange(text.startIndex..., in: text))
        return matches.compactMap(\.url).first { candidate in
            guard let host = candidate.host()?.lowercased() else { return false }
            return conferenceHosts.contains { host == $0 || host.hasSuffix(".\($0)") }
        }
    }
}
