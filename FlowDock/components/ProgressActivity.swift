//
//  ProgressActivity.swift
//  FlowDock
//

import Defaults
import SwiftUI

extension Activity {
    static let progressID = "progress"
    static let progressDoneID = "progressDone"
    static let progressChinSide: CGFloat = 34

    static func progress(_ report: ProgressReport, count: Int) -> Activity {
        Activity(
            id: progressID,
            activityClass: .persistent,
            band: .progress,
            label: count > 1 ? "\(report.label), \(count) in progress" : report.label,
            chinSideWidth: progressChinSide,
            leading: {
                ProgressRing(fraction: report.fraction)
                    .frame(width: progressChinSide, alignment: .leading)
            },
            trailing: {
                Text(count > 1 ? "\(count)" : report.detail)
                    .font(.chinValue)
                    .monospacedDigit()
                    .foregroundStyle(.white)
                    .lineLimit(1)
                    .frame(width: progressChinSide, alignment: .trailing)
            }
        )
        .withExpanded { ProgressPanel() }
    }

    static func progressDone(_ report: ProgressReport) -> Activity {
        Activity(
            id: progressDoneID,
            activityClass: .contextual,
            band: .progress,
            label: "\(report.title), finished",
            chinSideWidth: progressChinSide,
            leading: {
                Image(systemName: "checkmark.circle.fill")
                    .font(.chinGlyph)
                    .foregroundStyle(.green)
                    .bounceOnAppear()
                    .frame(width: progressChinSide, alignment: .leading)
            },
            trailing: {
                Text(report.detail)
                    .font(.chinValue)
                    .monospacedDigit()
                    .foregroundStyle(.white)
                    .lineLimit(1)
                    .frame(width: progressChinSide, alignment: .trailing)
            }
        )
    }
}

extension View {
    func progressActivity(in store: ActivityStore) -> some View {
        modifier(ProgressActivityBinder(store: store))
    }
}

private struct ProgressActivityBinder: ViewModifier {
    let store: ActivityStore

    @ObservedObject private var center = ProgressCenter.shared
    @Default(.showDownloads) private var enabled

    func body(content: Content) -> some View {
        content
            .onChange(of: center.reports, initial: true) { _, reports in
                guard enabled else { return }
                if let primary = reports.first {
                    store.begin(.progress(primary, count: reports.count))
                } else {
                    store.end(Activity.progressID)
                }
            }
            .onChange(of: center.finished) { _, finished in
                guard let finished else { return }
                if enabled { store.begin(.progressDone(finished)) }
                center.clearFinished()
            }
            .onChange(of: enabled, initial: true) { _, enabled in
                if enabled {
                    DownloadWatcher.shared.start()
                } else {
                    DownloadWatcher.shared.stop()
                    store.end(Activity.progressID)
                    store.end(Activity.progressDoneID)
                }
            }
    }
}

struct ProgressRing: View {
    let fraction: Double?

    @State private var spin = false
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    var body: some View {
        Group {
            if let fraction {
                Circle()
                    .trim(from: 0, to: max(0.02, fraction))
                    .stroke(.white, style: StrokeStyle(lineWidth: 2.5, lineCap: .round))
                    .rotationEffect(.degrees(-90))
                    .animation(.value(reduceMotion: reduceMotion), value: fraction)
            } else {
                Circle()
                    .trim(from: 0, to: 0.25)
                    .stroke(.white, style: StrokeStyle(lineWidth: 2.5, lineCap: .round))
                    .rotationEffect(.degrees(reduceMotion ? 0 : (spin ? 360 : 0)))
                    .opacity(reduceMotion && spin ? 0.35 : 1)
                    .animation(
                        reduceMotion
                            ? .easeInOut(duration: 0.9).repeatForever(autoreverses: true)
                            : .linear(duration: 1).repeatForever(autoreverses: false),
                        value: spin
                    )
                    .onAppear { spin = true }
            }
        }
        .background(Circle().stroke(.quaternary, lineWidth: 2.5))
        .frame(width: 15, height: 15)
        .accessibilityHidden(true)
    }
}

struct ProgressPanel: View {
    @ObservedObject private var center = ProgressCenter.shared

    var body: some View {
        if !center.reports.isEmpty {
            VStack(alignment: .leading, spacing: 4) {
                ForEach(center.reports) { report in
                    HStack(spacing: 8) {
                        ProgressRing(fraction: report.fraction)

                        VStack(alignment: .leading, spacing: 1) {
                            Text(report.title)
                                .font(.caption)
                                .fontWeight(.semibold)
                                .lineLimit(1)
                                .truncationMode(.middle)
                            if let fraction = report.fraction {
                                ProgressView(value: fraction)
                                    .progressViewStyle(.linear)
                                    .tint(.effectiveAccent)
                            } else {
                                Text(report.detail)
                                    .font(.caption)
                                    .foregroundStyle(.secondary)
                            }
                        }
                        .frame(maxWidth: .infinity, alignment: .leading)

                        HoverButton(icon: "folder", scale: .small) {
                            center.reveal(report)
                        }
                        .iconLabel("Show in Finder")
                    }
                    .frame(height: 30)
                    .padding(.horizontal, 8)
                    .panelRowBackground()
                    .accessibilityElement(children: .contain)
                    .accessibilityLabel(report.label)
                    .transition(.opacity)
                }
            }
            .animation(.value, value: center.reports.map(\.id))
        }
    }
}

#if DEBUG
extension ProgressPanel {
    static func selfCheck() {
        let indeterminate = ProgressReport(id: "a", title: "Xcode.xip", fraction: nil, detail: "1.2 GB", url: nil)
        assert(indeterminate.label == "Xcode.xip, 1.2 GB")
        assert(ProgressReport(id: "a", title: "Xcode.xip", fraction: 0.5, detail: "", url: nil).label
            == "Xcode.xip, 50 percent")
        assert(ProgressReport.formatted(bytes: 1_500_000).hasSuffix("MB"))
        assert(Activity.progress(indeterminate, count: 1).activityClass == .persistent)
        assert(Activity.progress(indeterminate, count: 1).band == .progress)
        assert(Activity.progress(indeterminate, count: 1).expanded != nil)
        assert(Activity.progress(indeterminate, count: 3).label.hasSuffix("3 in progress"))
        assert(Activity.progressDone(indeterminate).activityClass == .contextual)
        assert(Activity.progressDone(indeterminate).expanded == nil)
        assert(DownloadWatcher.partialExtensions.contains("crdownload"))
        assert(!DownloadWatcher.partialExtensions.contains("dmg"))

        let center = ProgressCenter.shared
        center.report(indeterminate)
        center.finish("a", at: nil)
        assert(center.finished?.id == "a")
        center.clearFinished()
        assert(center.finished == nil, "a completion must not linger, or an identical one cannot follow it")
        center.drop("a")
    }
}
#endif
