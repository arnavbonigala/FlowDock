//
//  ActivityExtension.swift
//  FlowDock
//

import Foundation

enum ActivityExtension {
    static let pointID = "com.arnavbonigala.flowdock.activity"

    enum Scene {
        static let leading = "chin.leading"
        static let trailing = "chin.trailing"
        static let panel = "panel"
    }

    struct Declaration: Codable, Equatable {
        enum Presentation: String, Codable {
            case contextual
            case persistent
        }

        enum Rank: String, Codable {
            case progress
            case media
            case ambient
        }

        var id: String
        var presentation: Presentation
        var rank: Rank
        var label: String
        var showsPanel: Bool
        var live: Bool

        var band: ActivityBand {
            switch rank {
            case .progress: .progress
            case .media: .media
            case .ambient: .ambient
            }
        }

        var activityClass: ActivityClass {
            presentation == .contextual ? .contextual : .persistent
        }
    }

    static func namespaced(_ declaration: Declaration, bundleIdentifier: String) -> String {
        "\(bundleIdentifier).\(declaration.id)"
    }

    /// The chin has room for a few words and VoiceOver reads the label whole, so a label
    /// longer than this is a bug in the extension rather than something to render.
    static let labelLimit = 120

    static func declaration(from json: String?) -> Declaration? {
        guard let data = json?.data(using: .utf8),
              var declaration = try? JSONDecoder().decode(Declaration.self, from: data),
              !declaration.id.isEmpty,
              !declaration.label.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
        else { return nil }

        declaration.label = String(declaration.label.prefix(labelLimit))
        return declaration
    }
}

@objc protocol FlowDockActivityExtensionProtocol {
    func activityDeclaration(reply: @escaping (String?) -> Void)
}

@objc protocol FlowDockActivityHostProtocol {
    func activityChanged(_ json: String)
}
