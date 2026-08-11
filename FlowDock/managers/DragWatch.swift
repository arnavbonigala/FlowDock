//
//  DragWatch.swift
//  FlowDock
//

import AppKit
import Combine

@MainActor
final class DragWatch: ObservableObject {
    static let shared = DragWatch()

    @Published private(set) var dragging = false

    private var monitors: [Any] = []

    private init() {
        monitors = [
            NSEvent.addGlobalMonitorForEvents(matching: .leftMouseDragged) { _ in
                MainActor.assumeIsolated { DragWatch.shared.dragging = true }
            },
            NSEvent.addGlobalMonitorForEvents(matching: [.leftMouseUp, .leftMouseDown]) { _ in
                MainActor.assumeIsolated { DragWatch.shared.dragging = false }
            },
        ].compactMap { $0 }
    }
}
