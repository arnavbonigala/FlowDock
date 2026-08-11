//
//  WeatherExtension.swift
//  Weather
//

import ExtensionFoundation
import ExtensionKit
import SwiftUI

@objc protocol FlowDockActivityExtensionProtocol {
    func activityDeclaration(reply: @escaping (String?) -> Void)
}

struct Conditions: Decodable, Sendable {
    struct Current: Decodable, Sendable {
        let temperature_2m: Double
        let weather_code: Int
    }

    let current: Current

    var symbol: String {
        switch current.weather_code {
        case 0, 1: "sun.max"
        case 2, 3: "cloud"
        case 45, 48: "cloud.fog"
        case 51...67, 80...82: "cloud.rain"
        case 71...77, 85, 86: "cloud.snow"
        case 95...99: "cloud.bolt"
        default: "cloud"
        }
    }

    var reading: String { "\(Int(current.temperature_2m.rounded()))°" }

    static func fetch(latitude: Double, longitude: Double) async -> Conditions? {
        let url = URL(string: "https://api.open-meteo.com/v1/forecast?latitude=\(latitude)"
            + "&longitude=\(longitude)&current=temperature_2m,weather_code")!
        guard let (data, _) = try? await URLSession.shared.data(from: url) else { return nil }
        return try? JSONDecoder().decode(Conditions.self, from: data)
    }
}

@MainActor
final class WeatherStore: ObservableObject {
    static let shared = WeatherStore()

    @Published private(set) var conditions: Conditions?

    func load() async {
        conditions = await Conditions.fetch(latitude: 37.7749, longitude: -122.4194)
    }
}

final class Declaration: NSObject, FlowDockActivityExtensionProtocol {
    func activityDeclaration(reply: @escaping (String?) -> Void) {
        Task { @MainActor in
            await WeatherStore.shared.load()
            guard let conditions = WeatherStore.shared.conditions else { return reply(nil) }
            reply("""
            {"id":"weather","presentation":"contextual","rank":"ambient",\
            "label":"Outside, \(conditions.reading)","showsPanel":false,"live":true}
            """)
        }
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
            Image(systemName: WeatherStore.shared.conditions?.symbol ?? "cloud")
                .font(.system(size: 13, weight: .medium))
                .foregroundStyle(.white)
        }, onConnection: accept)

        PrimitiveAppExtensionScene(id: "chin.trailing", content: {
            Text(WeatherStore.shared.conditions?.reading ?? "—")
                .font(.system(size: 12, weight: .semibold))
                .foregroundStyle(.white)
        }, onConnection: accept)
    }
}

@main
struct WeatherExtension: AppExtension {
    var configuration: AppExtensionSceneConfiguration {
        AppExtensionSceneConfiguration(Scenes())
    }
}
