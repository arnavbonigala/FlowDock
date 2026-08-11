//
//  AppIcons.swift
//  FlowDock
//
//  Created by Harsh Vardhan  Goswami  on 16/08/24.
//

import SwiftUI
import AppKit

@MainActor
enum RunningAppIcons {
    private static var resolved: [String: NSImage] = [:]

    /// An application known only by its display name costs a linear scan of every running
    /// process to find — once per row, per redraw. Remembering the answer also keeps the
    /// icon on a notification whose application has since quit.
    static func icon(named name: String) -> NSImage? {
        if let cached = resolved[name] { return cached }
        guard let icon = NSWorkspace.shared.runningApplications
            .first(where: { $0.localizedName == name })?
            .icon
        else { return nil }
        resolved[name] = icon
        return icon
    }
}

func AppIcon(for bundleID: String) -> Image {
    let workspace = NSWorkspace.shared
    
    if let appURL = workspace.urlForApplication(withBundleIdentifier: bundleID) {
        let appIcon = workspace.icon(forFile: appURL.path)
        return Image(nsImage: appIcon)
    }
    
    return Image(nsImage: workspace.icon(for: .applicationBundle))
}


func AppIconAsNSImage(for bundleID: String) -> NSImage? {
    let workspace = NSWorkspace.shared
    
    if let appURL = workspace.urlForApplication(withBundleIdentifier: bundleID) {
        let appIcon = workspace.icon(forFile: appURL.path)
        appIcon.size = NSSize(width: 256, height: 256)
        return appIcon
    }
    return nil
}

