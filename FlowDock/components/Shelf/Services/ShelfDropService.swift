//
//  ShelfDropService.swift
//  FlowDock
//
//  Created by Alexander on 2025-09-26.
//

import AppKit
import Foundation
import UniformTypeIdentifiers

struct ShelfDropService {
    static func items(from providers: [NSItemProvider]) async -> [ShelfItem] {
        var results: [ShelfItem] = []

        for provider in providers {
            if let item = await processProvider(provider) {
                results.append(item)
            }
        }

        return results
    }
    
    private static func processProvider(_ provider: NSItemProvider) async -> ShelfItem? {
        if let actualFileURL = await provider.extractFileURL(),
           let item = await existingFileItem(for: actualFileURL) {
            return item
        }

        if let url = await provider.extractURL() {
            if url.isFileURL {
                if let item = await existingFileItem(for: url) { return item }
            } else {
                return await ShelfItem(kind: .link(url: url), isTemporary: false)
            }
        }

        if let contents = await provider.extractFileContents(),
           let item = await ownedCopyItem(data: contents.data, name: contents.name) {
            return item
        }

        if let text = await provider.extractText() {
            return await ShelfItem(kind: .text(string: text), isTemporary: false)
        }

        if let fileURL = await provider.extractItem(),
           let item = await existingFileItem(for: fileURL) {
            return item
        }

        return nil
    }

    private static func existingFileItem(for url: URL) async -> ShelfItem? {
        if url.standardizedFileURL.path.hasPrefix(NSTemporaryDirectory()) {
            guard let data = try? Data(contentsOf: url) else { return nil }
            return await ownedCopyItem(data: data, name: url.lastPathComponent)
        }
        guard let bookmark = createBookmark(for: url) else { return nil }
        return await ShelfItem(kind: .file(bookmark: bookmark), isTemporary: false)
    }

    private static func ownedCopyItem(data: Data, name: String) async -> ShelfItem? {
        guard let tempURL = await TemporaryFileStorageService.shared.createTempFile(for: .data(data, suggestedName: name)),
              let bookmark = createBookmark(for: tempURL) else { return nil }
        return await ShelfItem(kind: .file(bookmark: bookmark), isTemporary: true)
    }

    private static func createBookmark(for url: URL) -> Data? {
        return (try? Bookmark(url: url))?.data
    }
}

