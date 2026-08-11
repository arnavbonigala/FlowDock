//
//  LockScreenView.swift
//  FlowDock
//

import SwiftUI

/// What FlowDock shows while the Mac is locked. A locked Mac is a Mac somebody else may be
/// standing in front of, so this shows facts with a shape — a countdown, a percentage, a
/// track — and never content: no notification, no caller, no filename, and no meeting title.
/// It is open without being opened, because there is nobody signed in to open it.
struct LockScreenView: View {
    @ObservedObject private var music = MusicManager.shared

    var body: some View {
        HStack(alignment: .top, spacing: spacing) {
            if music.isPlayerIdle {
                LockClock()
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
            } else {
                LockMedia()
                    .frame(maxWidth: .infinity, alignment: .leading)
            }

            LockFacts()
                .frame(width: ExperienceView.contextColumn, alignment: .leading)
        }
        .padding(.horizontal, 24)
        .padding(.vertical, 16)
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .top)
    }
}

/// Nothing is playing and nothing is due, so the panel says the one thing a locked screen
/// is always asked. SwiftUI drives the minute itself; this costs no timer of FlowDock's own.
private struct LockClock: View {
    var body: some View {
        VStack(alignment: .leading, spacing: 2) {
            Text(Date.now, style: .time)
                .font(.lockClock)
                .monospacedDigit()
                .foregroundStyle(.primary)
            Text(Date.now, format: .dateTime.weekday(.wide).month().day())
                .font(.panelMeta)
                .foregroundStyle(.secondary)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .accessibilityElement(children: .combine)
    }
}

private struct LockMedia: View {
    @ObservedObject private var music = MusicManager.shared

    private var fraction: Double {
        guard music.songDuration > 0 else { return 0 }
        return min(max(music.elapsedTime / music.songDuration, 0), 1)
    }

    var body: some View {
        HStack(spacing: 16) {
            Image(nsImage: music.albumArt)
                .resizable()
                .aspectRatio(contentMode: .fill)
                .frame(width: 96, height: 96)
                .clipShape(RoundedRectangle(cornerRadius: 10, style: .continuous))
                .accessibilityHidden(true)

            VStack(alignment: .leading, spacing: 6) {
                VStack(alignment: .leading, spacing: 1) {
                    Text(music.songTitle)
                        .font(.panelPrimary)
                        .foregroundStyle(.primary)
                    Text(music.artistName)
                        .font(.panelMeta)
                        .foregroundStyle(.secondary)
                }
                .lineLimit(1)
                .truncationMode(.tail)

                Capsule()
                    .fill(.quaternary)
                    .frame(height: 3)
                    .overlay(alignment: .leading) {
                        GeometryReader { geo in
                            Capsule()
                                .fill(.secondary)
                                .frame(width: geo.size.width * fraction)
                        }
                    }
                    .accessibilityHidden(true)

                HStack(spacing: 18) {
                    /// The transport is here because a locked Mac still plays, and reaching
                    /// the keyboard's own media keys means finding them. It changes what is
                    /// playing and nothing else — there is nothing here to unlock.
                    LockTransport(symbol: "backward.fill", label: "Previous track") {
                        music.previousTrack()
                    }
                    LockTransport(
                        symbol: music.isPlaying ? "pause.fill" : "play.fill",
                        label: music.isPlaying ? "Pause" : "Play"
                    ) {
                        music.togglePlay()
                    }
                    LockTransport(symbol: "forward.fill", label: "Next track") {
                        music.nextTrack()
                    }
                }
                .padding(.top, 2)
            }
        }
    }
}

private struct LockTransport: View {
    let symbol: String
    let label: String
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            Image(systemName: symbol)
                .font(.panelPrimary)
                .foregroundStyle(.primary)
                .frame(width: 28, height: 28)
                .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .iconLabel(label)
    }
}

private struct LockFacts: View {
    @ObservedObject private var timer = TimerCenter.shared
    @ObservedObject private var meetings = MeetingWatch.shared
    @ObservedObject private var battery = BatteryStatusViewModel.shared

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            if timer.isRunning, let endsAt = timer.endsAt {
                LockFact(symbol: "timer", name: "Timer") {
                    CountdownText(to: endsAt)
                }
            }

            /// The meeting's title is content, and a locked screen shows none. When it
            /// starts is not: it is a number, and it is the only part worth waking for.
            if let event = meetings.imminent {
                LockFact(symbol: "video", name: "Meeting") {
                    CountdownText(to: event.start)
                }
            }

            let reading = battery.reading
            LockFact(symbol: reading.symbol ?? "battery.100", name: reading.status) {
                Text(reading.timeToFull.map { "\(Int(reading.level))% · \($0)" }
                    ?? "\(Int(reading.level))%")
                    .font(.panelMeta)
                    .monospacedDigit()
                    .foregroundStyle(.secondary)
            }
        }
    }
}

private struct LockFact<Value: View>: View {
    let symbol: String
    let name: String
    @ViewBuilder let value: () -> Value

    var body: some View {
        HStack(spacing: 8) {
            Image(systemName: symbol)
                .font(.panelMeta)
                .foregroundStyle(.secondary)
                .frame(width: 16)
                .accessibilityHidden(true)

            Text(name)
                .font(.panelMeta)
                .foregroundStyle(.secondary)
                .lineLimit(1)

            Spacer(minLength: 8)

            value()
        }
        .frame(height: PanelRow.content)
        .padding(.horizontal, 8)
        .panelRowBackground()
        .accessibilityElement(children: .combine)
    }
}
