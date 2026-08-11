//
//  SmallestExtension.swift
//  Smallest
//

import ExtensionFoundation
import ExtensionKit
import SwiftUI

@objc protocol FlowDockActivityExtensionProtocol {
    func activityDeclaration(reply: @escaping (String?) -> Void)
}

final class Declaration: NSObject, FlowDockActivityExtensionProtocol {
    func activityDeclaration(reply: @escaping (String?) -> Void) {
        reply("""
        {"id":"hello","presentation":"contextual","rank":"ambient",\
        "label":"Hello from an extension","showsPanel":false,"live":true}
        """)
    }
}

let accept: @Sendable (NSXPCConnection) -> Bool = { connection in
    connection.exportedInterface = NSXPCInterface(with: FlowDockActivityExtensionProtocol.self)
    connection.exportedObject = Declaration()
    connection.resume()
    return true
}

struct Scenes: AppExtensionScene {
    @AppExtensionSceneBuilder var body: some AppExtensionScene {
        PrimitiveAppExtensionScene(id: "chin.leading", content: {
            Image(systemName: "hand.wave")
                .font(.system(size: 13, weight: .medium))
                .foregroundStyle(.white)
        }, onConnection: accept)

        PrimitiveAppExtensionScene(id: "chin.trailing", content: {
            Text("Hello")
                .font(.system(size: 12, weight: .semibold))
                .foregroundStyle(.white)
        }, onConnection: accept)
    }
}

@main
struct SmallestExtension: AppExtension {
    var configuration: AppExtensionSceneConfiguration {
        AppExtensionSceneConfiguration(Scenes())
    }
}
