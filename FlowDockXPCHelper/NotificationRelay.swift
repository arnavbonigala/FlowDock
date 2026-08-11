//
//  NotificationRelay.swift
//  FlowDockXPCHelper
//

import AppKit
import ApplicationServices
import Foundation

struct RelayedNotification: Codable {
    let token: String
    let app: String
    let title: String
    let body: String
    /// The alert's own buttons, by their own titles. An incoming call is a notification
    /// whose buttons happen to say Decline and Accept, so nothing here knows what a call
    /// is — it offers whatever the alert offers, in whatever language it says it.
    let actions: [String]
}

final class NotificationRelay {
    static let shared = NotificationRelay()

    private static let bundleIdentifier = "com.apple.notificationcenterui"
    private static let maximumDepth = 8

    private var observer: AXObserver?
    private var application: AXUIElement?
    private var sink: ((String) -> Void)?
    private var launchObserver: NSObjectProtocol?

    func start(sink: @escaping (String) -> Void) {
        DispatchQueue.main.async {
            self.sink = sink
            self.arm()

            guard self.launchObserver == nil else { return }
            self.launchObserver = NSWorkspace.shared.notificationCenter.addObserver(
                forName: NSWorkspace.didLaunchApplicationNotification,
                object: nil,
                queue: .main
            ) { [weak self] notification in
                let app = notification.userInfo?[NSWorkspace.applicationUserInfoKey] as? NSRunningApplication
                guard app?.bundleIdentifier == Self.bundleIdentifier else { return }
                self?.arm()
            }
        }
    }

    func stop() {
        DispatchQueue.main.async {
            self.disarm()
            self.sink = nil
            if let launchObserver = self.launchObserver {
                NSWorkspace.shared.notificationCenter.removeObserver(launchObserver)
                self.launchObserver = nil
            }
        }
    }

    func perform(_ action: String, token: String) {
        DispatchQueue.main.async {
            guard let window = self.windows().first(where: { Self.token(for: self.notification(in: $0)) == token }) else {
                return
            }

            let buttons = self.buttons(in: window)

            switch action {
            case "dismiss":
                if let close = buttons.first(where: { Self.isDismiss($0.title) }) {
                    AXUIElementPerformAction(close.element, kAXPressAction as CFString)
                }
            case "activate":
                if let primary = buttons.first(where: { !Self.isDismiss($0.title) }) {
                    AXUIElementPerformAction(primary.element, kAXPressAction as CFString)
                } else {
                    AXUIElementPerformAction(window, kAXPressAction as CFString)
                }
            default:
                /// Anything else names a button the alert reported, which is how declining
                /// a call reaches a button that says neither close nor clear.
                if let named = buttons.first(where: { $0.title == action }) {
                    AXUIElementPerformAction(named.element, kAXPressAction as CFString)
                }
            }
        }
    }

    private func arm() {
        disarm()

        guard AXIsProcessTrusted(),
              let running = NSRunningApplication.runningApplications(withBundleIdentifier: Self.bundleIdentifier).first
        else { return }

        let application = AXUIElementCreateApplication(running.processIdentifier)
        var observer: AXObserver?
        let callback: AXObserverCallback = { _, _, _, context in
            guard let context else { return }
            Unmanaged<NotificationRelay>.fromOpaque(context).takeUnretainedValue().publish()
        }

        guard AXObserverCreate(running.processIdentifier, callback, &observer) == .success,
              let observer
        else { return }

        let context = Unmanaged.passUnretained(self).toOpaque()
        AXObserverAddNotification(observer, application, kAXWindowCreatedNotification as CFString, context)
        AXObserverAddNotification(observer, application, kAXUIElementDestroyedNotification as CFString, context)
        CFRunLoopAddSource(CFRunLoopGetMain(), AXObserverGetRunLoopSource(observer), .defaultMode)

        self.observer = observer
        self.application = application
        publish()
    }

    private func disarm() {
        if let observer {
            CFRunLoopRemoveSource(CFRunLoopGetMain(), AXObserverGetRunLoopSource(observer), .defaultMode)
        }
        observer = nil
        application = nil
    }

    private func publish() {
        guard let sink else { return }
        let notifications = windows().compactMap(notification(in:))
        guard let data = try? JSONEncoder().encode(notifications),
              let json = String(data: data, encoding: .utf8)
        else { return }
        sink(json)
    }

    private func windows() -> [AXUIElement] {
        guard let application else { return [] }
        var value: CFTypeRef?
        guard AXUIElementCopyAttributeValue(application, kAXWindowsAttribute as CFString, &value) == .success,
              let windows = value as? [AXUIElement]
        else { return [] }
        return windows
    }

    private func notification(in window: AXUIElement) -> RelayedNotification? {
        let texts = staticTexts(in: window).filter { !$0.isEmpty }
        guard texts.count >= 2 else { return nil }

        let actions = buttons(in: window)
            .map(\.title)
            .filter { !$0.isEmpty && !Self.isDismiss($0) }

        let notification = RelayedNotification(
            token: "",
            app: texts[0],
            title: texts[1],
            body: texts.count > 2 ? texts[2...].joined(separator: " ") : "",
            actions: actions
        )
        return RelayedNotification(
            token: Self.token(for: notification),
            app: notification.app,
            title: notification.title,
            body: notification.body,
            actions: actions
        )
    }

    private static func token(for notification: RelayedNotification?) -> String {
        guard let notification else { return "" }
        return "\(notification.app)|\(notification.title)|\(notification.body)"
    }

    private func staticTexts(in element: AXUIElement, depth: Int = 0) -> [String] {
        guard depth < Self.maximumDepth else { return [] }

        if role(of: element) == kAXStaticTextRole {
            return [string(element, kAXValueAttribute) ?? string(element, kAXTitleAttribute) ?? ""]
        }

        return children(of: element).flatMap { staticTexts(in: $0, depth: depth + 1) }
    }

    private func buttons(in element: AXUIElement, depth: Int = 0) -> [(element: AXUIElement, title: String)] {
        guard depth < Self.maximumDepth else { return [] }

        if role(of: element) == kAXButtonRole {
            let title = string(element, kAXTitleAttribute)
                ?? string(element, kAXDescriptionAttribute)
                ?? ""
            return [(element, title)]
        }

        return children(of: element).flatMap { buttons(in: $0, depth: depth + 1) }
    }

    private func children(of element: AXUIElement) -> [AXUIElement] {
        var value: CFTypeRef?
        guard AXUIElementCopyAttributeValue(element, kAXChildrenAttribute as CFString, &value) == .success,
              let children = value as? [AXUIElement]
        else { return [] }
        return children
    }

    private func role(of element: AXUIElement) -> String? {
        string(element, kAXRoleAttribute)
    }

    private func string(_ element: AXUIElement, _ attribute: String) -> String? {
        var value: CFTypeRef?
        guard AXUIElementCopyAttributeValue(element, attribute as CFString, &value) == .success else { return nil }
        return value as? String
    }

    private static func isDismiss(_ title: String) -> Bool {
        let lowercased = title.lowercased()
        return lowercased.contains("close") || lowercased.contains("clear") || lowercased.contains("dismiss")
    }
}
