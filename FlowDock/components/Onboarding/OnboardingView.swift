//
//  OnboardingView.swift
//  FlowDock
//
//  Created by Alexander on 2025-06-23.
//

import Defaults
import EventKit
import SwiftUI

enum OnboardingStep {
    case welcome
    case setup
}

struct OnboardingView: View {
    @State var step: OnboardingStep = .welcome
    let onFinish: () -> Void
    let onOpenSettings: () -> Void

    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    var body: some View {
        Group {
            switch step {
            case .welcome:
                WelcomeView { step = .setup }
                    .transition(.opacity)
            case .setup:
                SetupView(onFinish: onFinish, onOpenSettings: onOpenSettings)
                    .transition(.opacity)
            }
        }
        .animation(.value(reduceMotion: reduceMotion), value: step)
        .frame(width: 460, height: 520)
        .background(.regularMaterial)
    }
}

// MARK: - Welcome

private struct WelcomeView: View {
    let onContinue: () -> Void

    var body: some View {
        VStack(spacing: 12) {
            Spacer()
            Image("logo2")
                .resizable()
                .aspectRatio(contentMode: .fit)
                .frame(width: 96, height: 96)
            Text("FlowDock")
                .font(.largeTitle)
                .fontWeight(.semibold)
            Text("An activity layer for the notch: calm when idle, useful in context.")
                .font(.body)
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)
                .padding(.horizontal, 48)
            Spacer()
            Button("Get started", action: onContinue)
                .buttonStyle(.borderedProminent)
                .controlSize(.large)
                .keyboardShortcut(.defaultAction)
            Link("Open source on GitHub", destination: URL(string: "https://github.com/arnavbonigala/FlowDock")!)
                .font(.footnote)
                .padding(.bottom, 24)
        }
    }
}

// MARK: - Setup

private struct SetupView: View {
    let onFinish: () -> Void
    let onOpenSettings: () -> Void

    @ObservedObject private var calendarManager = CalendarManager.shared
    @Default(.mediaController) private var mediaController
    @State private var accessibilityAuthorized = false

    private var calendarGranted: Bool {
        calendarManager.calendarAuthorizationStatus == .fullAccess
            || calendarManager.reminderAuthorizationStatus == .fullAccess
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            VStack(alignment: .leading, spacing: 4) {
                Text("Set up FlowDock")
                    .font(.title)
                    .fontWeight(.semibold)
                Text("Everything here is optional and can be changed later in settings.")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
            }
            .padding(.top, 24)

            Form {
                Section {
                    PermissionRow(
                        symbol: "calendar",
                        title: "Calendar and Reminders",
                        detail: "Shows today's events and reminders in the expanded panel.",
                        granted: calendarGranted
                    ) {
                        Task { await calendarManager.requestAccess() }
                    }

                    PermissionRow(
                        symbol: "slider.horizontal.3",
                        title: "Accessibility",
                        detail: "Shows notifications at the notch, and replaces the volume, brightness, and backlight HUDs.",
                        granted: accessibilityAuthorized
                    ) {
                        XPCHelperClient.shared.requestAccessibilityAuthorization()
                    }
                } header: {
                    Text("Permissions")
                } footer: {
                    if !accessibilityAuthorized {
                        HStack(alignment: .firstTextBaseline) {
                            Text("macOS drops accessibility access when FlowDock is moved or updated, and then ignores the request because a stale entry already exists. Remove FlowDock there and add it again.")
                                .font(.caption)
                                .foregroundStyle(.secondary)
                                .fixedSize(horizontal: false, vertical: true)
                            Spacer()
                            Button("Open Accessibility settings") {
                                if let url = URL(string: "x-apple.systempreferences:com.apple.preference.security?Privacy_Accessibility") {
                                    NSWorkspace.shared.open(url)
                                }
                            }
                        }
                    }
                }

                Section {
                    Picker("Music source", selection: $mediaController) {
                        ForEach(availableMediaControllers) { controller in
                            Text(controller.rawValue).tag(controller)
                        }
                    }
                    .onChange(of: mediaController) { _, _ in
                        NotificationCenter.default.post(name: .mediaControllerChanged, object: nil)
                    }
                } footer: {
                    Text(MusicManager.shared.isNowPlayingDeprecated
                        ? "Now Playing is unavailable on this version of macOS, so FlowDock talks to one music app directly."
                        : "Now Playing works with every media app.")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
            }
            .formStyle(.grouped)
            .scrollContentBackground(.hidden)

            HStack {
                Button("Open settings", action: onOpenSettings)
                Spacer()
                Button("Done", action: onFinish)
                    .buttonStyle(.borderedProminent)
                    .keyboardShortcut(.defaultAction)
            }
            .controlSize(.large)
            .padding(.bottom, 24)
        }
        .padding(.horizontal, 24)
        .task {
            accessibilityAuthorized = await XPCHelperClient.shared.isAccessibilityAuthorized()
        }
        .onReceive(NotificationCenter.default.publisher(for: .accessibilityAuthorizationChanged)) { notification in
            if let granted = notification.userInfo?["granted"] as? Bool {
                accessibilityAuthorized = granted
            }
        }
    }

    private var availableMediaControllers: [MediaControllerType] {
        MusicManager.shared.isNowPlayingDeprecated
            ? MediaControllerType.allCases.filter { $0 != .nowPlaying }
            : MediaControllerType.allCases
    }
}

private struct PermissionRow: View {
    let symbol: String
    let title: String
    let detail: String
    let granted: Bool
    let request: () -> Void

    var body: some View {
        LabeledContent {
            if granted {
                Label("Granted", systemImage: "checkmark.circle.fill")
                    .foregroundStyle(.secondary)
                    .labelStyle(.titleAndIcon)
            } else {
                Button("Grant", action: request)
            }
        } label: {
            Label {
                VStack(alignment: .leading, spacing: 2) {
                    Text(title)
                    Text(detail)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                        .fixedSize(horizontal: false, vertical: true)
                }
            } icon: {
                Image(systemName: symbol)
            }
        }
    }
}

#Preview {
    OnboardingView(onFinish: {}, onOpenSettings: {})
}
