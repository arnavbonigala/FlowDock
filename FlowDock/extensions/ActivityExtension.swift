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

    static func declaration(from json: String?) -> Declaration? {
        guard let data = json?.data(using: .utf8) else { return nil }
        return try? JSONDecoder().decode(Declaration.self, from: data)
    }
}

@objc protocol FlowDockActivityExtensionProtocol {
    func activityDeclaration(reply: @escaping (String?) -> Void)
}

@objc protocol FlowDockActivityHostProtocol {
    func activityChanged(_ json: String)
}
