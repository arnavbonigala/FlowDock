# FlowDock Quality Standards

These are release gates, not claims about the current inherited app. Record the commit, Mac model, macOS version, display setup, and measurement duration with every result. Test release candidates on both Intel and Apple Silicon and across notch, non-notch, and external-display configurations.

## Measurable gates

| Area | Release standard |
|---|---|
| Responsiveness | User input receives visible feedback within 100 ms. Opening or dismissing FlowDock reaches a usable resting state within 500 ms. Core flows produce no main-thread stall of 250 ms or longer. |
| Stability | No crash, hang, data loss, focus theft, or broken native system control during an eight-hour idle soak, one hour of active use, 100 repeated open/dismiss cycles, and 20 cycles each of sleep/wake, screen lock, display reconnect, and audio-device switching. |
| Resource use | After ten idle minutes, median CPU use is at most 1%, resident memory is at most 200 MiB, and wakeups average at most two per second. An eight-hour idle soak grows memory by no more than 25 MiB or 10%, whichever is greater. |
| Accessibility | Every primary action is keyboard reachable and has a useful VoiceOver name, role, value, and focus order. Reduce Motion, Reduce Transparency, increased contrast, and larger text do not hide information or block actions. Accessibility Inspector reports no critical or high-severity issue in a core flow. |
| Visual quality | At least 95% of animation frames meet the active display's frame budget across five repeated runs. Light and dark appearances show no clipping, overlap, flicker, jumps, stale content, or unintended menu-bar obstruction at 1× and 2× scale. Essential text and controls meet 4.5:1 text and 3:1 non-text contrast. |

## Enforcement

- A change must meet the applicable gates on the affected configurations before merge.
- A release candidate must pass every gate across the supported test matrix.
- Any regression involving crashes, data loss, native controls, permissions, focus, or inaccessible primary actions blocks release regardless of averages.
- Store measurements, screenshots, recordings, and failures with the pull request or release-tracking issue so results can be compared over time.
