//
//  MusicActivity.swift
//  FlowDock
//

import Defaults
import SwiftUI

// MARK: - The activity

extension Activity {
    static let musicID = "music"

    static func music(title: String, artist: String, isPlaying: Bool) -> Activity {
        let name = title.isEmpty ? "Unknown track" : title
        let verb = isPlaying ? "Now playing" : "Paused"
        let label = artist.isEmpty ? "\(verb), \(name)" : "\(verb), \(name) by \(artist)"

        return Activity(
            id: musicID,
            activityClass: .persistent,
            band: .media,
            label: label,
            leading: { MusicChinArtwork() },
            trailing: { MusicChinIndicator() }
        )
    }
}

extension View {
    func musicActivity(in store: ActivityStore, suppressed: Bool) -> some View {
        modifier(MusicActivityBinder(store: store, suppressed: suppressed))
    }
}

private struct MusicActivityBinder: ViewModifier {
    let store: ActivityStore
    let suppressed: Bool

    @ObservedObject private var music = MusicManager.shared
    @ObservedObject private var coordinator = FlowDockViewCoordinator.shared

    private struct Snapshot: Equatable {
        var live: Bool
        var title: String
        var artist: String
        var isPlaying: Bool
    }

    private var snapshot: Snapshot {
        Snapshot(
            live: !suppressed
                && coordinator.musicLiveActivityEnabled
                && (music.isPlaying || !music.isPlayerIdle),
            title: music.songTitle,
            artist: music.artistName,
            isPlaying: music.isPlaying
        )
    }

    func body(content: Content) -> some View {
        content.onChange(of: snapshot, initial: true) { _, now in
            if now.live {
                store.begin(.music(title: now.title, artist: now.artist, isPlaying: now.isPlaying))
            } else {
                store.end(Activity.musicID)
            }
        }
    }
}

// MARK: - Chin

private func chinItemSide(_ vm: FlowDockViewModel) -> CGFloat {
    max(0, vm.effectiveClosedNotchHeight - 12)
}

private struct MusicChinArtwork: View {
    @EnvironmentObject private var vm: FlowDockViewModel
    @ObservedObject private var music = MusicManager.shared

    var body: some View {
        let side = chinItemSide(vm)
        Image(nsImage: music.albumArt)
            .resizable()
            .aspectRatio(contentMode: .fill)
            .frame(width: side, height: side)
            .clipShape(RoundedRectangle(cornerRadius: MusicPlayerImageSizes.cornerRadiusInset.closed))
            .id(music.albumArt)
            .transition(.opacity)
    }
}

private struct MusicChinIndicator: View {
    @EnvironmentObject private var vm: FlowDockViewModel
    @ObservedObject private var music = MusicManager.shared
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @Default(.coloredSpectrogram) private var coloredSpectrogram

    var body: some View {
        let side = chinItemSide(vm)
        Group {
            if reduceMotion {
                Image(systemName: music.isPlaying ? "waveform" : "pause.fill")
                    .imageScale(.medium)
                    .foregroundStyle(.secondary)
            } else {
                Rectangle()
                    .fill(coloredSpectrogram ? Color(nsColor: music.avgColor).gradient : Color.gray.gradient)
                    .mask {
                        AudioSpectrumView(isPlaying: $music.isPlaying)
                            .frame(width: 16, height: 12)
                    }
            }
        }
        .frame(width: side, height: side)
    }
}

// MARK: - Expanded panel

struct MusicPanel: View {
    @ObservedObject private var music = MusicManager.shared
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    private var idle: Bool { !music.isPlaying && music.isPlayerIdle }

    var body: some View {
        HStack(alignment: .top, spacing: 16) {
            MusicArtwork(idle: idle)

            Group {
                if idle {
                    Text("Nothing playing")
                        .font(.body)
                        .foregroundStyle(.secondary)
                        .frame(maxWidth: .infinity, alignment: .leading)
                } else {
                    MusicDetails()
                }
            }
            .transition(.fromNotch(reduceMotion: reduceMotion))
        }
        .buttonStyle(.plain)
        .animation(.experience(reduceMotion: reduceMotion), value: idle)
    }
}

private struct MusicArtwork: View {
    let idle: Bool

    @ObservedObject private var music = MusicManager.shared
    @Default(.lightingEffect) private var lightingEffect

    private var radius: CGFloat { MusicPlayerImageSizes.cornerRadiusInset.opened }

    var body: some View {
        Button {
            music.openMusicApp()
        } label: {
            if idle {
                RoundedRectangle(cornerRadius: radius, style: .continuous)
                    .fill(.quaternary)
                    .frame(width: MusicPlayerImageSizes.size.opened.width,
                           height: MusicPlayerImageSizes.size.opened.height)
                    .overlay {
                        Image(systemName: "music.note")
                            .font(.system(size: 26))
                            .foregroundStyle(.tertiary)
                    }
            } else {
                Image(nsImage: music.albumArt)
                    .resizable()
                    .aspectRatio(contentMode: .fill)
                    .frame(width: MusicPlayerImageSizes.size.opened.width,
                           height: MusicPlayerImageSizes.size.opened.height)
                    .clipShape(RoundedRectangle(cornerRadius: radius))
                    .id(music.albumArt)
                    .transition(.opacity)
            }
        }
        .accessibilityLabel(idle ? "Open music app" : "Open \(music.songTitle) in its app")
        .background {
            if lightingEffect {
                Image(nsImage: music.albumArt)
                    .resizable()
                    .aspectRatio(contentMode: .fill)
                    .frame(width: MusicPlayerImageSizes.size.opened.width,
                           height: MusicPlayerImageSizes.size.opened.height)
                    .blur(radius: 32)
                    .opacity(music.isPlaying ? 0.5 : 0)
                    .allowsHitTesting(false)
                    .id(music.albumArt)
                    .transition(.opacity)
            }
        }
        .overlay(alignment: .bottomTrailing) {
            MusicSourceMenu()
                .offset(x: 8, y: 8)
        }
    }
}

private struct MusicSourceMenu: View {
    @ObservedObject private var music = MusicManager.shared
    @Default(.mediaController) private var source

    private var available: [MediaControllerType] {
        music.isNowPlayingDeprecated
            ? MediaControllerType.allCases.filter { $0 != .nowPlaying }
            : MediaControllerType.allCases
    }

    var body: some View {
        Menu {
            Picker("Music source", selection: $source) {
                ForEach(available) { controller in
                    Text(controller.rawValue).tag(controller)
                }
            }
            .pickerStyle(.inline)
            .labelsHidden()
        } label: {
            AppIcon(for: music.bundleIdentifier ?? "com.apple.Music")
                .resizable()
                .frame(width: 22, height: 22)
        }
        .menuStyle(.borderlessButton)
        .menuIndicator(.hidden)
        .frame(width: 28, height: 28)
        .contentShape(Rectangle())
        .accessibilityLabel("Music source, \(source.rawValue)")
        .onChange(of: source) {
            NotificationCenter.default.post(name: Notification.Name.mediaControllerChanged, object: nil)
        }
    }
}

private struct MusicDetails: View {
    @ObservedObject private var music = MusicManager.shared

    var body: some View {
        GeometryReader { geo in
            VStack(alignment: .leading, spacing: 4) {
                ScrollingText(music.songTitle, style: .body, weight: .semibold, color: .primary, width: geo.size.width)
                ScrollingText(music.artistName, style: .subheadline, color: .secondary, width: geo.size.width)

                MusicContextLine(width: geo.size.width)

                MusicScrubber()

                Spacer(minLength: 0)

                MusicControls()
            }
        }
    }
}

private struct MusicContextLine: View {
    let width: CGFloat

    @ObservedObject private var music = MusicManager.shared
    @Default(.enableLyrics) private var enableLyrics

    var body: some View {
        TimelineView(.periodic(from: .now, by: 0.25)) { timeline in
            ScrollingText(line(at: timeline.date), style: .subheadline, color: .secondary, width: width)
        }
        .frame(height: 16)
    }

    private func line(at date: Date) -> String {
        if let lyric = lyric(at: date) { return lyric }
        if let next = music.upNext.first { return "Up next: \(next)" }
        return music.album
    }

    private func lyric(at date: Date) -> String? {
        guard enableLyrics, music.isPlaying else { return nil }
        if music.isFetchingLyrics { return "Loading lyrics…" }
        if !music.syncedLyrics.isEmpty {
            return music.lyricLine(at: music.estimatedPlaybackPosition(at: date))
        }
        let plain = music.currentLyrics.trimmingCharacters(in: .whitespacesAndNewlines)
        return plain.isEmpty ? nil : plain.replacingOccurrences(of: "\n", with: " ")
    }
}

private struct MusicScrubber: View {
    @ObservedObject private var music = MusicManager.shared
    @Default(.sliderColor) private var sliderColor

    @State private var position: Double = 0
    @State private var dragging = false
    @State private var lastDragged: Date = .distantPast

    private var trackColor: Color {
        switch sliderColor {
        case .albumArt: Color(nsColor: music.avgColor).ensureMinimumBrightness(factor: 0.8)
        case .accent: .effectiveAccent
        case .white: .white
        }
    }

    var body: some View {
        TimelineView(.periodic(from: .now, by: 0.1)) { timeline in
            VStack(spacing: 4) {
                CustomSlider(
                    value: $position,
                    range: 0...max(music.songDuration, 0.001),
                    color: trackColor,
                    dragging: $dragging,
                    lastDragged: $lastDragged
                ) { newValue in
                    music.seek(to: newValue)
                }
                .frame(height: 10)
                .disabled(!music.canSeek)
                .allowsHitTesting(music.canSeek)
                .accessibilityLabel("Playback position")
                .accessibilityValue(timeString(position))

                HStack(spacing: 0) {
                    Text(timeString(position))
                    Spacer(minLength: 0)
                    Text(timeString(music.songDuration))
                }
                .font(.caption)
                .monospacedDigit()
                .foregroundStyle(.secondary)
            }
            .onChange(of: timeline.date) { _, now in
                guard !dragging, music.timestampDate.timeIntervalSince(lastDragged) > -1 else { return }
                position = music.estimatedPlaybackPosition(at: now)
            }
        }
    }

    private func timeString(_ seconds: Double) -> String {
        let total = Int(max(0, seconds))
        let hours = total / 3600
        return hours > 0
            ? String(format: "%d:%02d:%02d", hours, (total % 3600) / 60, total % 60)
            : String(format: "%d:%02d", total / 60, total % 60)
    }
}

// MARK: - Controls

private struct MusicControls: View {
    @ObservedObject private var music = MusicManager.shared
    @Default(.musicControlSlots) private var slots
    @Default(.musicControlSlotLimit) private var slotLimit

    private var activeSlots: [MusicControlButton] {
        let limit = min(max(slotLimit, MusicControlButton.minSlotCount), MusicControlButton.maxSlotCount)
        let padded = slots + Array(repeating: .none, count: max(0, limit - slots.count))
        return padded.prefix(limit).map { music.capabilities.contains($0.requires) ? $0 : .none }
    }

    var body: some View {
        HStack(spacing: 8) {
            ForEach(Array(activeSlots.enumerated()), id: \.offset) { _, slot in
                control(slot)
            }
        }
        .frame(maxWidth: .infinity, alignment: .center)
    }

    @ViewBuilder
    private func control(_ slot: MusicControlButton) -> some View {
        switch slot {
        case .shuffle:
            HoverButton(icon: "shuffle", iconColor: music.isShuffled ? .effectiveAccent : .primary) {
                music.toggleShuffle()
            }
            .accessibilityLabel("Shuffle")
            .accessibilityValue(music.isShuffled ? "On" : "Off")
        case .previous:
            HoverButton(icon: "backward.fill") { music.previousTrack() }
                .accessibilityLabel("Previous track")
        case .playPause:
            HoverButton(icon: music.isPlaying ? "pause.fill" : "play.fill", scale: .large) {
                music.togglePlay()
            }
            .accessibilityLabel(music.isPlaying ? "Pause" : "Play")
        case .next:
            HoverButton(icon: "forward.fill") { music.nextTrack() }
                .accessibilityLabel("Next track")
        case .repeatMode:
            HoverButton(
                icon: music.repeatMode == .one ? "repeat.1" : "repeat",
                iconColor: music.repeatMode == .off ? .primary : .effectiveAccent
            ) { music.toggleRepeat() }
                .accessibilityLabel("Repeat")
                .accessibilityValue(String(describing: music.repeatMode))
        case .volume:
            MusicVolumeControl()
        case .favorite:
            HoverButton(
                icon: music.isFavoriteTrack ? "heart.fill" : "heart",
                iconColor: music.isFavoriteTrack ? .effectiveAccent : .primary
            ) { music.toggleFavoriteTrack() }
                .disabled(!music.canFavoriteTrack)
                .opacity(music.canFavoriteTrack ? 1 : 0.35)
                .accessibilityLabel("Favorite")
                .accessibilityValue(music.isFavoriteTrack ? "On" : "Off")
        case .goBackward:
            HoverButton(icon: "gobackward.15") { music.skip(seconds: -15) }
                .accessibilityLabel("Back 15 seconds")
        case .goForward:
            HoverButton(icon: "goforward.15") { music.skip(seconds: 15) }
                .accessibilityLabel("Forward 15 seconds")
        case .none:
            Color.clear.frame(width: 30, height: 1)
        }
    }
}

private struct MusicVolumeControl: View {
    @ObservedObject private var music = MusicManager.shared

    @State private var level: Double = 0.5
    @State private var dragging = false
    @State private var expanded = false
    @State private var lastSent: Date = .distantPast

    private let throttle: TimeInterval = 0.1

    private var icon: String {
        if !music.volumeControlSupported { return "speaker.slash" }
        if level == 0 { return "speaker.slash.fill" }
        if level < 0.33 { return "speaker.wave.1.fill" }
        if level < 0.66 { return "speaker.wave.2.fill" }
        return "speaker.wave.3.fill"
    }

    var body: some View {
        HStack(spacing: 4) {
            Button {
                expanded.toggle()
            } label: {
                Image(systemName: icon)
                    .contentTransition(.symbolEffect(.replace))
                    .frame(width: 28, height: 28)
                    .contentShape(Rectangle())
            }
            .buttonStyle(.plain)
            .disabled(!music.volumeControlSupported)
            .foregroundStyle(music.volumeControlSupported ? Color.primary : .secondary)
            .accessibilityLabel("Volume")
            .accessibilityValue("\(Int(level * 100)) percent")

            if expanded && music.volumeControlSupported {
                CustomSlider(
                    value: $level,
                    range: 0...1,
                    dragging: $dragging,
                    lastDragged: .constant(.distantPast),
                    onValueChange: { music.setVolume(to: $0) },
                    onDragChange: { newValue in
                        let now = Date()
                        guard now.timeIntervalSince(lastSent) > throttle else { return }
                        music.setVolume(to: newValue)
                        lastSent = now
                    }
                )
                .frame(width: 48, height: 8)
            }
        }
        .clipped()
        .onReceive(music.$volume) { volume in
            if !dragging { level = volume }
        }
        .onChange(of: music.volumeControlSupported) { _, supported in
            if !supported { expanded = false }
        }
        .onChange(of: expanded) { _, showing in
            guard showing else { return }
            Task { await music.syncVolumeFromActiveApp() }
        }
    }
}

// MARK: - Shared pieces

private struct ScrollingText: View {
    let text: String
    let style: Font.TextStyle
    var weight: Font.Weight = .regular
    let color: Color
    let width: CGFloat

    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    init(_ text: String, style: Font.TextStyle, weight: Font.Weight = .regular, color: Color, width: CGFloat) {
        self.text = text
        self.style = style
        self.weight = weight
        self.color = color
        self.width = width
    }

    private var nsStyle: NSFont.TextStyle {
        switch style {
        case .subheadline: .subheadline
        case .caption: .caption1
        default: .body
        }
    }

    var body: some View {
        if reduceMotion {
            Text(text)
                .font(.system(style).weight(weight))
                .foregroundStyle(color)
                .lineLimit(1)
                .truncationMode(.tail)
                .frame(width: width, alignment: .leading)
        } else {
            MarqueeText(
                .constant(text),
                font: .system(style).weight(weight),
                nsFont: nsStyle,
                textColor: color,
                frameWidth: width
            )
        }
    }
}

struct CustomSlider: View {
    @Binding var value: Double
    var range: ClosedRange<Double>
    var color: Color = .white
    @Binding var dragging: Bool
    @Binding var lastDragged: Date
    var onValueChange: ((Double) -> Void)?
    var onDragChange: ((Double) -> Void)?

    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    var body: some View {
        GeometryReader { geometry in
            let width = geometry.size.width
            let height = CGFloat(dragging ? 8 : 4)
            let span = range.upperBound - range.lowerBound
            let progress = span == .zero ? 0 : (value - range.lowerBound) / span

            ZStack(alignment: .leading) {
                Rectangle().fill(.quaternary)
                Rectangle()
                    .fill(color)
                    .frame(width: min(max(progress, 0), 1) * width)
            }
            .frame(height: height)
            .clipShape(Capsule())
            .frame(height: 10)
            .contentShape(Rectangle())
            .gesture(
                DragGesture(minimumDistance: 0)
                    .onChanged { gesture in
                        dragging = true
                        let newValue = range.lowerBound + Double(gesture.location.x / width) * span
                        value = min(max(newValue, range.lowerBound), range.upperBound)
                        onDragChange?(value)
                    }
                    .onEnded { _ in
                        onValueChange?(value)
                        dragging = false
                        lastDragged = Date()
                    }
            )
            .animation(.value(reduceMotion: reduceMotion), value: dragging)
        }
    }
}

#if DEBUG
#Preview {
    MusicPanel()
        .environmentObject(FlowDockViewModel())
        .frame(width: 616, height: 134)
        .padding(12)
        .background(.black)
        .preferredColorScheme(.dark)
}
#endif
