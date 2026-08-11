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

    private var discovery: Task<Void, Never>?
    private var processes: [String: AppExtensionProcess] = [:]
    private var connections: [String: NSXPCConnection] = [:]

    private override init() {
        super.init()
    }

    func start() {
        guard discovery == nil else { return }
        discovery = Task { [weak self] in
            guard let identities = try? AppExtensionIdentity.matching(
                appExtensionPointIDs: ActivityExtension.pointID
            ) else { return }

            for await found in identities {
                guard !Task.isCancelled else { return }
                await self?.refresh(found)
            }
        }
    }

    func stop() {
        discovery?.cancel()
        discovery = nil
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

    private func refresh(_ identities: [AppExtensionIdentity]) async {
        var hosted: [HostedExtension] = []

        for identity in identities {
            guard let declaration = await declaration(from: identity) else {
                release(identity.bundleIdentifier)
                continue
            }
            hosted.append(HostedExtension(identity: identity, declaration: declaration))
        }

        let names = Set(identities.map(\.bundleIdentifier))
        for stale in connections.keys where !names.contains(stale) {
            release(stale)
        }

        available = hosted
        live = hosted.filter { $0.declaration.live && Defaults[.enabledExtensions].contains($0.id) }
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

    private func release(_ bundleIdentifier: String) {
        connections.removeValue(forKey: bundleIdentifier)?.invalidate()
        processes.removeValue(forKey: bundleIdentifier)?.invalidate()
        available.removeAll { $0.identity.bundleIdentifier == bundleIdentifier }
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
