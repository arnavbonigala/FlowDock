//
//  ExtensionActivity.swift
//  FlowDock
//

import Defaults
import ExtensionFoundation
import ExtensionKit
import SwiftUI

extension Activity {

    static func hosted(_ hosted: HostedExtension) -> Activity {
        let identity = hosted.identity
        let declaration = hosted.declaration

        var activity = Activity(
            id: hosted.id,
            activityClass: declaration.activityClass,
            band: declaration.band,
            label: declaration.label,
            chinSideWidth: Activity.chinSide,
            leading: {
                RemoteScene(identity: identity, sceneID: ActivityExtension.Scene.leading)
                    .frame(width: Activity.chinSide, height: 22)
            },
            trailing: {
                RemoteScene(identity: identity, sceneID: ActivityExtension.Scene.trailing)
                    .frame(width: Activity.chinSide, height: 22)
            }
        )

        if declaration.showsPanel {
            activity = activity.withExpanded {
                RemoteScene(identity: identity, sceneID: ActivityExtension.Scene.panel)
                    .frame(height: 30)
                    .frame(maxWidth: .infinity)
                    .panelRowBackground()
                    .accessibilityElement(children: .contain)
                    .accessibilityLabel(declaration.label)
            }
        }

        return activity
    }
}

extension View {
    func extensionActivities(in store: ActivityStore) -> some View {
        modifier(ExtensionActivityBinder(store: store))
    }
}

private struct ExtensionActivityBinder: ViewModifier {
    let store: ActivityStore

    @ObservedObject private var host = ExtensionHost.shared
    @Default(.extensionsEnabled) private var enabled

    func body(content: Content) -> some View {
        content
            .onChange(of: host.live, initial: true) { previous, current in
                let ids = Set(current.map(\.id))
                previous.filter { !ids.contains($0.id) }.forEach { store.end($0.id) }
                current.forEach { store.begin(.hosted($0)) }
            }
            .onChange(of: enabled, initial: true) { _, enabled in
                if enabled {
                    host.start()
                } else {
                    host.live.forEach { store.end($0.id) }
                    host.stop()
                }
            }
    }
}

struct RemoteScene: NSViewControllerRepresentable {
    static let renderDeadline: Duration = .seconds(2)

    let identity: AppExtensionIdentity
    let sceneID: String

    func makeCoordinator() -> RenderWatch { RenderWatch(identity: identity) }

    func makeNSViewController(context: Context) -> EXHostViewController {
        let controller = EXHostViewController()
        controller.delegate = context.coordinator
        controller.configuration = .init(appExtension: identity, sceneID: sceneID)
        context.coordinator.arm()
        return controller
    }

    func updateNSViewController(_ controller: EXHostViewController, context: Context) {
        guard controller.configuration?.sceneID != sceneID
            || controller.configuration?.appExtension != identity else { return }
        controller.configuration = .init(appExtension: identity, sceneID: sceneID)
        context.coordinator.arm()
    }
}

@MainActor
final class RenderWatch: NSObject, EXHostViewControllerDelegate {
    private let identity: AppExtensionIdentity
    private var deadline: Task<Void, Never>?

    init(identity: AppExtensionIdentity) {
        self.identity = identity
    }

    func arm() {
        deadline?.cancel()
        deadline = Task { [identity] in
            try? await Task.sleep(for: RemoteScene.renderDeadline)
            guard !Task.isCancelled else { return }
            ExtensionHost.shared.release(identity.bundleIdentifier)
        }
    }

    nonisolated func hostViewControllerDidActivate(_ viewController: EXHostViewController) {
        MainActor.assumeIsolated { deadline?.cancel() }
    }

    nonisolated func hostViewControllerWillDeactivate(
        _ viewController: EXHostViewController,
        error: (any Error)?
    ) {
        guard error != nil else { return }
        MainActor.assumeIsolated { ExtensionHost.shared.release(identity.bundleIdentifier) }
    }
}

#if DEBUG
enum ExtensionContract {
    static func selfCheck() {
        let json = """
        {"id":"pomodoro","presentation":"persistent","rank":"progress","label":"Focus, 12 minutes left",\
        "showsPanel":true,"live":true}
        """
        let declaration = ActivityExtension.declaration(from: json)
        assert(declaration?.band == .progress)
        assert(declaration?.activityClass == .persistent)
        assert(declaration?.showsPanel == true)
        assert(ActivityExtension.declaration(from: nil) == nil)
        assert(ActivityExtension.declaration(from: "{}") == nil, "a partial declaration is not an activity")
        let reserved = """
        {"id":"x","presentation":"persistent","rank":"drag","label":"x","showsPanel":false,"live":true}
        """
        assert(ActivityExtension.declaration(from: reserved) == nil, "the reserved bands cannot be asked for")

        func declared(id: String, label: String) -> String {
            """
            {"id":"\(id)","presentation":"persistent","rank":"ambient","label":"\(label)",\
            "showsPanel":false,"live":true}
            """
        }
        assert(ActivityExtension.declaration(from: declared(id: "", label: "x")) == nil, "an activity needs an id")
        assert(ActivityExtension.declaration(from: declared(id: "x", label: "   ")) == nil, "and something to say")
        let shouted = String(repeating: "a", count: ActivityExtension.labelLimit + 40)
        assert(
            ActivityExtension.declaration(from: declared(id: "x", label: shouted))?.label.count
                == ActivityExtension.labelLimit,
            "a label VoiceOver would read for a minute is clamped, not rendered"
        )

        let ambient = ActivityExtension.Declaration(
            id: "weather", presentation: .contextual, rank: .ambient, label: "Rain", showsPanel: false, live: true
        )
        assert(ambient.band == .ambient)
        assert(ambient.activityClass == .contextual)
        assert(ActivityExtension.namespaced(ambient, bundleIdentifier: "com.acme.ext") == "com.acme.ext.weather")
    }
}
#endif
