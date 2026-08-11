//
//  ProgressCenter.swift
//  FlowDock
//

import AppKit
import Combine
import Defaults
import Foundation

struct ProgressReport: Identifiable, Equatable {
    let id: String
    var title: String
    var fraction: Double?
    var detail: String
    var url: URL?

    var label: String {
        if let fraction {
            return "\(title), \(Int(fraction * 100)) percent"
        }
        return detail.isEmpty ? title : "\(title), \(detail)"
    }

    static func formatted(bytes: Int64) -> String {
        ByteCountFormatter.string(fromByteCount: bytes, countStyle: .file)
    }
}

@MainActor
final class ProgressCenter: ObservableObject {
    static let shared = ProgressCenter()

    @Published private(set) var reports: [ProgressReport] = []
    @Published private(set) var finished: ProgressReport?

    private init() {}

    var primary: ProgressReport? { reports.first }

    func report(_ report: ProgressReport) {
        if let index = reports.firstIndex(where: { $0.id == report.id }) {
            guard reports[index] != report else { return }
            reports[index] = report
        } else {
            reports.append(report)
        }
    }

    func finish(_ id: String, at url: URL?) {
        guard let index = reports.firstIndex(where: { $0.id == id }) else { return }
        var completed = reports.remove(at: index)
        completed.fraction = 1
        completed.detail = url.map { ProgressReport.formatted(bytes: DownloadWatcher.size(of: $0)) } ?? completed.detail
        completed.url = url
        finished = completed
    }

    func drop(_ id: String) {
        reports.removeAll { $0.id == id }
    }

    func clearFinished() {
        finished = nil
    }

    func reveal(_ report: ProgressReport) {
        guard let url = report.url else { return }
        NSWorkspace.shared.activateFileViewerSelecting([url])
    }
}

@MainActor
final class DownloadWatcher {
    static let shared = DownloadWatcher()

    static let partialExtensions: Set<String> = ["download", "crdownload", "part", "opdownload", "partial"]

    private var source: DispatchSourceFileSystemObject?
    private var descriptor: CInt = -1
    private var ticker: Timer?
    private var known: [String: String] = [:]

    private init() {}

    private var downloads: URL? {
        FileManager.default.urls(for: .downloadsDirectory, in: .userDomainMask).first
    }

    func start() {
        guard source == nil, let downloads else { return }
        descriptor = open(downloads.path, O_EVTONLY)
        guard descriptor >= 0 else { return }

        let source = DispatchSource.makeFileSystemObjectSource(
            fileDescriptor: descriptor,
            eventMask: [.write, .delete, .rename],
            queue: .main
        )
        source.setEventHandler { [weak self] in
            MainActor.assumeIsolated { self?.scan() }
        }
        source.resume()
        self.source = source
        scan()
    }

    func stop() {
        source?.cancel()
        source = nil
        if descriptor >= 0 { close(descriptor) }
        descriptor = -1
        stopTicking()
        known.keys.forEach { ProgressCenter.shared.drop($0) }
        known.removeAll()
    }

    static func size(of url: URL) -> Int64 {
        let values = try? url.resourceValues(forKeys: [.isDirectoryKey, .totalFileAllocatedSizeKey])
        if values?.isDirectory == true {
            let contents = FileManager.default.enumerator(at: url, includingPropertiesForKeys: [.totalFileAllocatedSizeKey])
            var total: Int64 = 0
            while let child = contents?.nextObject() as? URL {
                total += Int64((try? child.resourceValues(forKeys: [.totalFileAllocatedSizeKey]).totalFileAllocatedSize) ?? 0)
            }
            return total
        }
        return Int64(values?.totalFileAllocatedSize ?? 0)
    }

    static func safariProgress(in bundle: URL) -> Double? {
        guard let plist = NSDictionary(contentsOf: bundle.appendingPathComponent("Info.plist")),
              let total = plist["DownloadEntryProgressTotalToLoad"] as? Int64, total > 0,
              let soFar = plist["DownloadEntryProgressBytesSoFar"] as? Int64
        else { return nil }
        return min(max(Double(soFar) / Double(total), 0), 1)
    }

    private func scan() {
        guard let downloads,
              let entries = try? FileManager.default.contentsOfDirectory(
                  at: downloads, includingPropertiesForKeys: nil, options: [.skipsHiddenFiles]
              )
        else { return }

        let partials = entries.filter { Self.partialExtensions.contains($0.pathExtension.lowercased()) }
        let paths = Set(partials.map(\.path))

        for (path, finalName) in known where !paths.contains(path) {
            let destination = downloads.appendingPathComponent(finalName)
            ProgressCenter.shared.finish(
                path,
                at: FileManager.default.fileExists(atPath: destination.path) ? destination : nil
            )
            known[path] = nil
        }

        for partial in partials {
            let name = partial.deletingPathExtension().lastPathComponent
            known[partial.path] = name
            ProgressCenter.shared.report(
                ProgressReport(
                    id: partial.path,
                    title: name,
                    fraction: Self.safariProgress(in: partial),
                    detail: ProgressReport.formatted(bytes: Self.size(of: partial)),
                    url: partial
                )
            )
        }

        if partials.isEmpty { stopTicking() } else { startTicking() }
    }

    private func startTicking() {
        guard ticker == nil else { return }
        ticker = Timer.scheduledTimer(withTimeInterval: 1, repeats: true) { _ in
            MainActor.assumeIsolated { DownloadWatcher.shared.scan() }
        }
    }

    private func stopTicking() {
        ticker?.invalidate()
        ticker = nil
    }
}
