//
//  Activity.swift
//  FlowDock
//
//  The contract every activity declares itself through. See INTERACTION.md.
//

import SwiftUI

/// The four states, in size order. See INTERACTION.md.
enum ActivityState {
    case idle
    case contextual
    case persistent
    case expanded
}

/// Contextual activities expire on a timer. Persistent ones end when their source says so.
enum ActivityClass {
    case contextual
    case persistent
}

/// Priority is proximity to what the user just did, not importance of the information.
/// Lower band wins the chin.
enum ActivityBand: Int, Comparable {
    case drag = 0
    case systemFeedback
    case power
    case progress
    case media
    case ambient

    static func < (lhs: Self, rhs: Self) -> Bool { lhs.rawValue < rhs.rawValue }
}

/// One thing FlowDock can be showing. Activities declare a class, a band, and — for
/// persistent ones — an end; the shell decides when and where they are seen.
struct Activity: Identifiable {
    let id: String
    let activityClass: ActivityClass
    let band: ActivityBand
    /// The whole chin reads as one VoiceOver element with this label: "Volume, 40 percent".
    let label: String
    /// One element per side, with the cutout between them.
    let leading: () -> AnyView
    let trailing: () -> AnyView
    /// How much room each side needs. `nil` takes the shell's square default.
    let chinSideWidth: CGFloat?

    /// The two chin side widths DESIGN.md allows. A third is an activity asking for the
    /// expanded state instead.
    static let chinSide: CGFloat = 34
    static let chinClockSide: CGFloat = 44
    /// How far below the closed chin this activity extends. DESIGN.md allows an activity
    /// with more to say to grow downward, where the whole screen is, rather than sideways
    /// into the menu bar's own items.
    var chinDrop: CGFloat = 0
    static let chinCallDrop: CGFloat = 30
    /// What a chin view is drawn at. An extension renders in its own process, so this is
    /// the size FlowDock hands across that boundary rather than a layout it can negotiate.
    static let chinHeight: CGFloat = 22
    /// Contextual activities have no expanded form.
    private(set) var expanded: (() -> AnyView)?
    /// Used to break ties within a band. Preserved when a live activity updates, so the
    /// store rewrites it rather than the activity's author.
    var startedAt: Date = .now

    init<Leading: View, Trailing: View>(
        id: String,
        activityClass: ActivityClass,
        band: ActivityBand,
        label: String,
        chinSideWidth: CGFloat? = nil,
        chinDrop: CGFloat = 0,
        @ViewBuilder leading: @escaping () -> Leading,
        @ViewBuilder trailing: @escaping () -> Trailing
    ) {
        self.id = id
        self.activityClass = activityClass
        self.band = band
        self.label = label
        self.chinSideWidth = chinSideWidth
        self.chinDrop = chinDrop
        self.leading = { AnyView(leading()) }
        self.trailing = { AnyView(trailing()) }
    }

    func withExpanded<Content: View>(@ViewBuilder _ content: @escaping () -> Content) -> Activity {
        var copy = self
        copy.expanded = { AnyView(content()) }
        return copy
    }

    /// Highest band wins, then whatever the user ranked higher, then whichever started
    /// most recently.
    static func owner(of activities: [Activity], priority: [String] = []) -> Activity? {
        activities.min { lhs, rhs in
            guard lhs.band == rhs.band else { return lhs.band < rhs.band }
            let left = priority.firstIndex(of: lhs.id) ?? Int.max
            let right = priority.firstIndex(of: rhs.id) ?? Int.max
            return left == right ? lhs.startedAt > rhs.startedAt : left < right
        }
    }
}

#if DEBUG
extension Activity {
    static func stub(
        _ id: String,
        _ activityClass: ActivityClass = .persistent,
        _ band: ActivityBand = .media,
        startedAt: Date = .now
    ) -> Activity {
        var activity = Activity(
            id: id, activityClass: activityClass, band: band, label: id,
            leading: { Image(systemName: "circle.fill") },
            trailing: { Text(id) }
        )
        activity.startedAt = startedAt
        return activity
    }

    /// Runs in debug builds from `ActivityStore.init`. The ordering rule is the one piece
    /// of real logic in the shell, so it is the one piece with a check.
    static func selfCheck() {
        let old = Date(timeIntervalSinceReferenceDate: 0)
        let new = Date(timeIntervalSinceReferenceDate: 100)

        assert(owner(of: []) == nil)

        let media = stub("media", .persistent, .media, startedAt: old)
        let volume = stub("volume", .contextual, .systemFeedback, startedAt: new)
        assert(owner(of: [media, volume])?.id == "volume", "lower band wins regardless of order")
        assert(owner(of: [volume, media])?.id == "volume")

        let older = stub("older", .persistent, .media, startedAt: old)
        let newer = stub("newer", .persistent, .media, startedAt: new)
        assert(owner(of: [older, newer])?.id == "newer", "ties go to the most recent")

        assert(owner(of: [older, newer], priority: ["older"])?.id == "older", "the user's order beats recency")
        assert(owner(of: [media, volume], priority: ["media"])?.id == "volume", "but never the band")

        let drag = stub("drag", .persistent, .drag, startedAt: old)
        assert(owner(of: [media, volume, drag])?.id == "drag", "nothing outranks a drag")
    }
}
#endif
