//
//  ShelfActionService.swift
//  FlowDock
//
//  Created by Alexander on 2025-10-07.
//

import AppKit
import Foundation

/// A service providing common actions for `ShelfItem`s, such as opening, revealing, or copying paths.
@MainActor
enum ShelfActionService {

    static func open(_ item: ShelfItem) {
        switch item.kind {
        case .file(let bookmark):
            handleBookmarkedFile(bookmark) { url in
                NSWorkspace.shared.open(url)
            }
        case .link(let url):
            NSWorkspace.shared.open(url)
        case .text(let string):
            NSPasteboard.general.clearContents()
            NSPasteboard.general.setString(string, forType: .string)
        }
    }

    static func reveal(_ item: ShelfItem) {
        guard case .file(let bookmark) = item.kind else { return }
        handleBookmarkedFile(bookmark) { url in
            NSWorkspace.shared.activateFileViewerSelecting([url])
        }
    }

    static func copyPath(_ item: ShelfItem) {
        guard case .file(let bookmark) = item.kind else { return }
        handleBookmarkedFile(bookmark) { url in
            NSPasteboard.general.clearContents()
            NSPasteboard.general.setString(url.path, forType: .string)
        }
    }

    static func remove(_ item: ShelfItem) {
        ShelfStateViewModel.shared.remove(item)
    }

    static func selectAll() {
        ShelfSelectionModel.shared.selectAll(in: ShelfStateViewModel.shared.items)
    }

    static func removeSelected() {
        let selected = ShelfSelectionModel.shared.selectedItems(in: ShelfStateViewModel.shared.items)
        selected.forEach { ShelfStateViewModel.shared.remove($0) }
        ShelfSelectionModel.shared.clear()
    }

    static func clearShelf() {
        ShelfStateViewModel.shared.removeAll()
    }

    static func copySelection() {
        let selected = ShelfSelectionModel.shared.selectedItems(in: ShelfStateViewModel.shared.items)
        guard !selected.isEmpty else { return }

        copiedURLs.forEach { $0.stopAccessingSecurityScopedResource() }
        copiedURLs = []

        let pasteboard = NSPasteboard.general
        pasteboard.clearContents()

        let urls = ShelfStateViewModel.shared.resolveFileURLs(for: selected)
        if !urls.isEmpty {
            copiedURLs = urls.filter { $0.startAccessingSecurityScopedResource() }
            pasteboard.writeObjects(urls as [NSURL])
            return
        }

        pasteboard.setString(selected.map(text).joined(separator: "\n"), forType: .string)
    }

    private static var copiedURLs: [URL] = []

    private static func text(_ item: ShelfItem) -> String {
        switch item.kind {
        case .text(let string): string
        case .link(let url): url.absoluteString
        case .file: item.displayName
        }
    }

    private static func handleBookmarkedFile(_ bookmarkData: Data, action: @escaping @Sendable (URL) -> Void) {
        Task {
            let bookmark = Bookmark(data: bookmarkData)
            if let url = bookmark.resolveURL() {
                url.accessSecurityScopedResource { accessibleURL in
                    action(accessibleURL)
                }
            }
        }
    }
}

