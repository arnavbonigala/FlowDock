//
//  CountdownActivity.swift
//  FlowDock
//

import Defaults
import SwiftUI

extension Activity {
    static let meetingID = "meeting"
    static let timerID = "timer"
    static let timerDoneID = "timerDone"

    static func meeting(_ event: EventModel) -> Activity {
        Activity(
            id: meetingID,
            activityClass: .persistent,
            band: .ambient,
            label: MeetingPanel.label(event),
            chinSideWidth: Activity.chinClockSide,
            leading: {
                Image(systemName: event.meetingURL == nil ? "calendar" : "video.fill")
                    .font(.chinGlyph)
                    .foregroundStyle(.primary)
                    .frame(width: Activity.chinClockSide, alignment: .leading)
            },
            trailing: {
                CountdownText(to: event.start)
                    .frame(width: Activity.chinClockSide, alignment: .trailing)
            }
        )
        .withExpanded { MeetingPanel(event: event) }
    }

    static func timer(endsAt: Date) -> Activity {
        Activity(
            id: timerID,
            activityClass: .persistent,
            band: .progress,
            label: "Timer running",
            chinSideWidth: Activity.chinClockSide,
            leading: {
                Image(systemName: "timer")
                    .font(.chinGlyph)
                    .foregroundStyle(.primary)
                    .frame(width: Activity.chinClockSide, alignment: .leading)
            },
            trailing: {
                CountdownText(to: endsAt)
                    .frame(width: Activity.chinClockSide, alignment: .trailing)
            }
        )
    }

    static func timerDone() -> Activity {
        Activity(
            id: timerDoneID,
            activityClass: .contextual,
            band: .progress,
            label: "Timer finished",
            chinSideWidth: Activity.chinClockSide,
            leading: {
                Image(systemName: "timer")
                    .font(.chinGlyph)
                    .foregroundStyle(.primary)
                    .bounceOnAppear()
                    .frame(width: Activity.chinClockSide, alignment: .leading)
            },
            trailing: {
                Text("Done")
                    .font(.chinValue)
                    .foregroundStyle(.primary)
                    .frame(width: Activity.chinClockSide, alignment: .trailing)
            }
        )
    }
}

struct CountdownText: View {
    let to: Date

    var body: some View {
        Group {
            if to > .now {
                Text(timerInterval: .now...to, countsDown: true)
            } else {
                Text("Now")
            }
        }
        .font(.chinValue)
        .monospacedDigit()
        .foregroundStyle(.primary)
        .lineLimit(1)
    }
}

extension View {
    func countdownActivity(in store: ActivityStore) -> some View {
        modifier(CountdownActivityBinder(store: store))
    }
}

private struct CountdownActivityBinder: ViewModifier {
    let store: ActivityStore

    @ObservedObject private var meetings = MeetingWatch.shared
    @ObservedObject private var timer = TimerCenter.shared
    @Default(.showMeetingCountdown) private var meetingsEnabled

    func body(content: Content) -> some View {
        content
            .onChange(of: meetings.imminent, initial: true) { _, event in
                if let event, meetingsEnabled {
                    store.begin(.meeting(event))
                } else {
                    store.end(Activity.meetingID)
                }
            }
            .onChange(of: timer.endsAt, initial: true) { _, endsAt in
                if let endsAt {
                    store.begin(.timer(endsAt: endsAt))
                } else {
                    store.end(Activity.timerID)
                }
            }
            .onChange(of: timer.finishedAt) { _, finished in
                guard finished != nil else { return }
                store.begin(.timerDone())
            }
    }
}

struct MeetingPanel: View {
    let event: EventModel

    @Environment(\.openURL) private var openURL

    var body: some View {
        HStack(spacing: 8) {
            VStack(alignment: .leading, spacing: 1) {
                Text(event.title)
                    .font(.caption)
                    .fontWeight(.semibold)
                    .lineLimit(1)
                HStack(spacing: 4) {
                    CountdownText(to: event.start)
                        .foregroundStyle(.secondary)
                    if let detail = Self.detail(event) {
                        Text(detail)
                            .font(.caption)
                            .foregroundStyle(.secondary)
                            .lineLimit(1)
                    }
                }
            }
            .frame(maxWidth: .infinity, alignment: .leading)

            if let url = event.meetingURL {
                Button("Join") { openURL(url) }
                    .buttonStyle(.borderedProminent)
                    .controlSize(.small)
                    .tint(.effectiveAccent)
            }
        }
        .frame(height: PanelRow.content)
        .padding(.horizontal, 8)
        .panelRowBackground()
        .accessibilityElement(children: .contain)
        .accessibilityLabel(Self.label(event))
    }

    static func detail(_ event: EventModel) -> String? {
        if event.participants.count > 1 { return "\(event.participants.count) people" }
        if let location = event.location, !location.isEmpty { return location }
        return nil
    }

    /// A chin reads as one static VoiceOver element, so a label saying "in 9 minutes" is
    /// still saying it nine minutes later. The start time does not go stale.
    static func label(_ event: EventModel) -> String {
        let when = event.start.formatted(date: .omitted, time: .shortened)
        return event.meetingURL == nil ? "\(event.title), \(when)" : "\(event.title), \(when), joinable"
    }
}

struct TimerPanel: View {
    @ObservedObject private var timer = TimerCenter.shared
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    var body: some View {
        HStack(spacing: 8) {
            Image(systemName: "timer")
                .font(.panelMeta)
                .foregroundStyle(.secondary)

            if timer.isRunning, let endsAt = timer.endsAt {
                CountdownText(to: endsAt)
                    .frame(maxWidth: .infinity, alignment: .leading)

                HoverButton(icon: "stop.fill", scale: .small) { timer.cancel() }
                    .iconLabel("Stop timer")
            } else {
                ForEach(TimerCenter.durations, id: \.self) { minutes in
                    Button {
                        timer.start(minutes: minutes)
                    } label: {
                        Text("\(minutes)m")
                            .font(.caption.weight(.medium))
                            .foregroundStyle(.primary)
                            .monospacedDigit()
                            .padding(.horizontal, 8)
                            .frame(minWidth: 28, maxHeight: .infinity)
                            .raisedSurface(Capsule())
                            .contentShape(Capsule().inset(by: -3))
                    }
                    .buttonStyle(PressableButtonStyle())
                    .accessibilityLabel("\(minutes) minutes")
                    .accessibilityHint("Starts a timer")
                    .accessibilityInputLabels(["\(minutes)m", "\(minutes) minutes"])
                }

                Spacer(minLength: 0)
            }
        }
        .frame(height: PanelRow.controls)
        .padding(.horizontal, 8)
        .panelRowBackground()
        .animation(.value(reduceMotion: reduceMotion), value: timer.isRunning)
    }
}

#if DEBUG
extension MeetingPanel {
    static func selfCheck() {
        let noon = Date(timeIntervalSinceReferenceDate: 43200)
        let soon = EventModel.stub("standup", start: noon.addingTimeInterval(300))
        let later = EventModel.stub("retro", start: noon.addingTimeInterval(3600))
        let past = EventModel.stub("done", start: noon.addingTimeInterval(-7200))
        let allDay = EventModel.stub("holiday", isAllDay: true)

        assert(MeetingWatch.imminent(in: [later, soon], now: noon)?.id == "standup")
        assert(MeetingWatch.imminent(in: [later], now: noon) == nil, "outside the lead time")
        assert(MeetingWatch.imminent(in: [past], now: noon) == nil, "already over")
        assert(MeetingWatch.imminent(in: [allDay], now: noon) == nil, "all-day entries do not count down")
        assert(MeetingWatch.imminent(in: [EventModel.stub("now", start: noon.addingTimeInterval(-60))], now: noon)?
            .id == "now", "a meeting in progress still counts")

        assert(label(soon).hasPrefix("standup, "))
        assert(!label(soon).hasSuffix("joinable"), "an event with no link is not joinable")

        assert(EventModel.conferenceURL(in: "Join https://zoom.us/j/123 now")?.host() == "zoom.us")
        assert(EventModel.conferenceURL(in: "https://acme.webex.com/meet/x") != nil)
        assert(EventModel.conferenceURL(in: "https://example.com/notes") == nil)
        assert(EventModel.conferenceURL(in: "no link here") == nil)
        assert(EventModel.conferenceURL(in: "https://notzoom.us.example.com/x") == nil)

        assert(Activity.meeting(soon).band == .ambient)
        assert(Activity.meeting(soon).expanded != nil)
        assert(Activity.timer(endsAt: noon).band == .progress)
        assert(Activity.timerDone().activityClass == .contextual)
    }
}
#endif
