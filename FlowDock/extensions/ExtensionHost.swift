//
//  ExtensionHost.swift
//  FlowDock
//

import Combine
import Defaults
import ExtensionFoundation
import Foundation

struct HostedExtension: Identifiable, Equatable {
    let identity: AppExtensionIdentity
    var declaration: ActivityExtension.Declaration

    var id: String { ActivityExtension.namespaced(declaration, bundleIdentifier: identity.bundleIdentifier) }
    var name: String { identity.localizedName }

    static func == (lhs: HostedExtension, rhs: HostedExtension) -> Bool {
        lhs.id == rhs.id && lhs.declaration == rhs.declaration
    }
}

@MainActor
final class ExtensionHost: NSObject, ObservableObject {
    static let shared = ExtensionHost()

    @Published private(set) var available: [HostedExtension] = []
    @Published private(set) var live: [HostedExtension] = []

    static let pollInterval: Duration = .seconds(15)

    private var discovery: Task<Void, Never>?
    private var poll: Task<Void, Never>?
    private var ranking: AnyCancellable?

    /// EXTENSIONS.md gives an extension two seconds to say what it is. Longer than that and
    /// discovery is waiting on a process rather than answering the user.
    static let answerDeadline: Duration = .seconds(2)
    private var processes: [String: AppExtensionProcess] = [:]
    private var connections: [String: NSXPCConnection] = [:]

    private override init() {
        super.init()
    }

    func start() {
        guard discovery == nil else { return }
        ranking = Defaults.publisher(.enabledExtensions).sink { _ in
            Task { @MainActor [weak self] in
                self?.settle()
                self?.pollWhileHostingSomething()
            }
        }
        discovery = Task { [weak self] in
            guard let identities = try? AppExtensionIdentity.matching(
                appExtensionPointIDs: ActivityExtension.pointID
            ) else { return }

            for await found in identities {
                guard !Task.isCancelled else { return }
                await self?.refresh(found)
            }
        }
        pollWhileHostingSomething()
    }

    /// Nothing enabled means nothing to ask, and a timer that wakes to answer its own guard
    /// is exactly the idle cost the shell is supposed to not have.
    private func pollWhileHostingSomething() {
        guard !Defaults[.enabledExtensions].isEmpty else {
            poll?.cancel()
            poll = nil
            return
        }
        guard poll == nil else { return }
        poll = Task { [weak self] in
            while !Task.isCancelled {
                try? await Task.sleep(for: Self.pollInterval)
                guard !Task.isCancelled else { return }
                await self?.reask()
            }
        }
    }

    func stop() {
        discovery?.cancel()
        discovery = nil
        poll?.cancel()
        poll = nil
        ranking?.cancel()
        ranking = nil
        connections.values.forEach { $0.invalidate() }
        connections.removeAll()
        processes.values.forEach { $0.invalidate() }
        processes.removeAll()
        available = []
        live = []
    }

    func identity(for id: String) -> AppExtensionIdentity? {
        available.first { $0.id == id }?.identity
    }

    /// Every installed extension is asked at once. Asked one after another, a single
    /// extension that never answers holds up discovery of all the ones behind it for the
    /// whole answer deadline.
    private func refresh(_ identities: [AppExtensionIdentity]) async {
        let answers = await ask(identities)

        var hosted: [HostedExtension] = []
        for (identity, declaration) in zip(identities, answers) {
            guard let declaration else {
                release(identity.bundleIdentifier)
                continue
            }
            hosted.append(HostedExtension(identity: identity, declaration: declaration))
        }

        let names = Set(identities.map(\.bundleIdentifier))
        for stale in Array(connections.keys) where !names.contains(stale) {
            release(stale)
        }

        available = hosted
        settle()
    }

    private func reask() async {
        let enabled = Defaults[.enabledExtensions]
        let asking = available.filter { enabled.contains($0.id) }
        guard !asking.isEmpty else { return }

        for (hosted, declaration) in zip(asking, await ask(asking.map(\.identity))) {
            guard let declaration else {
                release(hosted.identity.bundleIdentifier)
                continue
            }
            guard let index = available.firstIndex(where: { $0.id == hosted.id }) else { continue }
            available[index].declaration = declaration
        }

        settle()
    }

    private func settle() {
        let enabled = Defaults[.enabledExtensions]
        live = available.filter { $0.declaration.live && enabled.contains($0.id) }

        let running = Set(live.map(\.identity.bundleIdentifier))
        for idle in Array(connections.keys) where !running.contains(idle) {
            connections.removeValue(forKey: idle)?.invalidate()
            processes.removeValue(forKey: idle)?.invalidate()
        }
    }

    private func ask(_ identities: [AppExtensionIdentity]) async -> [ActivityExtension.Declaration?] {
        await withTaskGroup(of: (Int, ActivityExtension.Declaration?).self) { group in
            for (index, identity) in identities.enumerated() {
                group.addTask { @MainActor [weak self] in
                    (index, await self?.declaration(from: identity))
                }
            }

            var answers = [ActivityExtension.Declaration?](repeating: nil, count: identities.count)
            for await (index, declaration) in group { answers[index] = declaration }
            return answers
        }
    }

    private func declaration(from identity: AppExtensionIdentity) async -> ActivityExtension.Declaration? {
        guard let connection = connection(for: identity) else { return nil }

        let json: String? = await withCheckedContinuation { continuation in
            let resumed = OneShot()
            let proxy = connection.remoteObjectProxyWithErrorHandler { _ in
                resumed.fire { continuation.resume(returning: nil) }
            } as? FlowDockActivityExtensionProtocol

            guard let proxy else {
                resumed.fire { continuation.resume(returning: nil) }
                return
            }

            Task {
                try? await Task.sleep(for: Self.answerDeadline)
                resumed.fire { continuation.resume(returning: nil) }
            }

            proxy.activityDeclaration { reply in
                resumed.fire { continuation.resume(returning: reply) }
            }
        }

        return ActivityExtension.declaration(from: json)
    }

    private func connection(for identity: AppExtensionIdentity) -> NSXPCConnection? {
        if let existing = connections[identity.bundleIdentifier] { return existing }

        let configuration = AppExtensionProcess.Configuration(
            appExtensionIdentity: identity,
            onInterruption: {
                Task { @MainActor in ExtensionHost.shared.release(identity.bundleIdentifier) }
            }
        )

        guard let process = try? AppExtensionProcess(configuration: configuration),
              let connection = try? process.makeXPCConnection()
        else { return nil }

        connection.remoteObjectInterface = NSXPCInterface(with: (any FlowDockActivityExtensionProtocol).self)
        connection.invalidationHandler = {
            Task { @MainActor in ExtensionHost.shared.release(identity.bundleIdentifier) }
        }
        connection.resume()

        processes[identity.bundleIdentifier] = process
        connections[identity.bundleIdentifier] = connection
        return connection
    }

    /// Ends the activity and drops the process. Membership of `available` belongs to
    /// discovery, so an extension that failed at runtime is asked again by the next poll
    /// rather than being silently uninstalled for the rest of the session.
    func release(_ bundleIdentifier: String) {
        connections.removeValue(forKey: bundleIdentifier)?.invalidate()
        processes.removeValue(forKey: bundleIdentifier)?.invalidate()
        live.removeAll { $0.identity.bundleIdentifier == bundleIdentifier }
    }
}

private final class OneShot: @unchecked Sendable {
    private var fired = false
    private let lock = NSLock()

    func fire(_ body: () -> Void) {
        lock.lock()
        defer { lock.unlock() }
        guard !fired else { return }
        fired = true
        body()
    }
}
