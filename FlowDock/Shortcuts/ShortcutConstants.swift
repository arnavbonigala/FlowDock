//
//  Constants.swift
//  FlowDock
//
//  Created by Richard Kunkli on 16/08/2024.
//

import KeyboardShortcuts
import SwiftUI

extension KeyboardShortcuts.Name {
    static let toggleNotchOpen = Self("toggleNotchOpen", default: .init(.i, modifiers: [.command, .shift]))
    static let toggleKeepAwake = Self("toggleKeepAwake")
    static let dismissExpanded = Self("dismissExpanded", default: .init(.escape))
    static let shelfSelectAll = Self("shelfSelectAll", default: .init(.a, modifiers: [.command]))
    static let shelfCopySelection = Self("shelfCopySelection", default: .init(.c, modifiers: [.command]))
    static let shelfRemoveSelected = Self("shelfRemoveSelected", default: .init(.delete))
    static let shelfClear = Self("shelfClear", default: .init(.delete, modifiers: [.command, .shift]))
}
