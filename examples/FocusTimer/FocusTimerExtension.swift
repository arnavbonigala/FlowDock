//
//  FocusTimerExtension.swift
//  FocusTimer
//

import ExtensionFoundation
import ExtensionKit
import SwiftUI

@objc protocol FlowDockActivityExtensionProtocol {
    func activityDeclaration(reply: @escaping (String?) -> Void)
}

final class FocusDeclaration: NSObject, FlowDockActivityExtensionProtocol {
    static let json = """
    {"id":"focus","presentation":"persistent","rank":"progress",\
    "label":"Focus session","showsPanel":true,"live":true}
    """

    func activityDeclaration(reply: @escaping (String?) -> Void) {
        reply(Self.json)
    }
}

let accept: @Sendable (NSXPCConnection) -> Bool = { connection in
    connection.exportedInterface = NSXPCInterface(with: FlowDockActivityExtensionProtocol.self)
    connection.exportedObject = FocusDeclaration()
    connection.resume()
    return true
}

@MainActor
final class FocusSession: ObservableObject {
    static let shared = FocusSession()

    @Published var endsAt = Date().addingTimeInterval(25 * 60)

    var fraction: Double {
        max(0, min(1, 1 - endsAt.timeIntervalSinceNow / (25 * 60)))
    }
}

struct FocusScenes: AppExtensionScene {
    @AppExtensionSceneBuilder var body: some AppExtensionScene {
        PrimitiveAppExtensionScene(id: "chin.leading", content: {
            Image(systemName: "timer")
                .foregroundStyle(.white)
        }, onConnection: accept)

        PrimitiveAppExtensionScene(id: "chin.trailing", content: {
            Text(timerInterval: Date()...FocusSession.shared.endsAt, countsDown: true)
                .font(.system(size: 11, weight: .medium, design: .rounded))
                .monospacedDigit()
                .foregroundStyle(.white)
        }, onConnection: accept)

        PrimitiveAppExtensionScene(id: "panel", content: {
            FocusPanel()
        }, onConnection: accept)
    }
}

struct FocusPanel: View {
    @StateObject private var session = FocusSession.shared

    var body: some View {
        HStack(spacing: 10) {
            ProgressView(value: session.fraction)
                .progressViewStyle(.linear)
                .tint(.white)

            Text(timerInterval: Date()...session.endsAt, countsDown: true)
                .font(.system(size: 12, weight: .medium, design: .rounded))
                .monospacedDigit()
                .foregroundStyle(.white)

            Button("Restart") { session.endsAt = Date().addingTimeInterval(25 * 60) }
                .buttonStyle(.plain)
                .font(.system(size: 12))
                .foregroundStyle(.white.opacity(0.7))
        }
        .padding(.horizontal, 12)
        .frame(maxWidth: .infinity, alignment: .leading)
    }
}

@main
struct FocusTimerExtension: AppExtension {
    var configuration: AppExtensionSceneConfiguration {
        AppExtensionSceneConfiguration(FocusScenes())
    }
}
