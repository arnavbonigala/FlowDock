//
//  ContactPhotos.swift
//  FlowDock
//

import AppKit
import Contacts
import Defaults

@MainActor
enum ContactPhotos {
    private static var found: [String: NSImage] = [:]
    private static var absent: Set<String> = []

    /// The caller is known only by the name the alert printed, which is the name the address
    /// book gave it in the first place. Looking that name up costs a permission prompt, so
    /// nothing here runs until the setting is on, and a name that misses is remembered as a
    /// miss — every ring of the same call would otherwise search the address book again.
    static func photo(named name: String) async -> NSImage? {
        guard Defaults[.showCallerPhotos], !name.isEmpty else { return nil }
        if let cached = found[name] { return cached }
        guard !absent.contains(name) else { return nil }

        guard (try? await CNContactStore().requestAccess(for: .contacts)) == true else {
            absent.insert(name)
            return nil
        }

        let image = await Task.detached {
            let keys = [CNContactThumbnailImageDataKey as CNKeyDescriptor]
            let matching = CNContact.predicateForContacts(matchingName: name)
            guard let data = try? CNContactStore()
                .unifiedContacts(matching: matching, keysToFetch: keys)
                .compactMap(\.thumbnailImageData)
                .first
            else { return NSImage?.none }
            return NSImage(data: data)
        }.value

        if let image { found[name] = image } else { absent.insert(name) }
        return image
    }

    /// A name written in any script shortens the same way: the first letter of each of the
    /// first two words it has. A call from a number nobody has saved has no letters to take,
    /// and shortens to nothing rather than to punctuation.
    static func initials(of name: String) -> String {
        name.split(whereSeparator: \.isWhitespace)
            .prefix(2)
            .compactMap { $0.first.flatMap { $0.isLetter ? String($0) : nil } }
            .joined()
            .uppercased()
    }
}
