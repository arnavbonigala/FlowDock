# FlowDock

FlowDock is an open-source activity layer for macOS. It turns the notch—or the top edge of a non-notch display—into a calm home for music, system feedback, calendar context, files, and other timely activities.

FlowDock began as a fork of [BoringNotch](https://github.com/TheBoredTeam/boring.notch) and is built around its own product and interaction model. [ROADMAP.md](ROADMAP.md) tracks direction.

## What it does

Activities appear at the top of the screen when they are relevant, coexist by priority, and expire on their own:

- **Music** — playback, source selection, queues, lyrics, and capability-aware controls
- **System feedback** — volume, brightness, keyboard backlight, and microphone, without displacing the native controls
- **Battery and devices** — charging, Bluetooth and headphone connection, and device status
- **Calendar** — events, reminders, meeting actions, countdowns, and timers
- **Notifications** — grouped, with actions where macOS permits
- **Downloads** — progress for transfers in flight
- **File shelf** — drag files to the top edge, then preview, compress, convert, remove backgrounds, AirDrop, or share them

Which activities appear, and in what order, is yours to set. Third-party activities install as extensions: [EXTENSIONS.md](EXTENSIONS.md) for the safety model, [BUILDING-EXTENSIONS.md](BUILDING-EXTENSIONS.md) to write one.

It works on notch and non-notch displays, across multiple displays, and respects Reduce Motion.

## Requirements

- macOS 14 Sonoma or later
- Apple Silicon or Intel Mac
- macOS 15.6 or later and Xcode 26 or later to build from source

## Install

Download the DMG from the [latest release](https://github.com/arnavbonigala/FlowDock/releases/latest) and drag FlowDock to Applications.

FlowDock ships without an Apple Developer ID, so macOS quarantines it on download and reports on first launch that it cannot check the app for malicious software. That is what an unnotarized build looks like; the release is built by a workflow anyone can read, from a tag anyone can rebuild. To open it the first time:

1. Try to open FlowDock. Dismiss the warning.
2. System Settings → Privacy & Security, scroll to Security. A line names FlowDock. Click **Open Anyway**.
3. Confirm. Every later launch is normal.

Or clear the flag directly:

```sh
xattr -d com.apple.quarantine /Applications/FlowDock.app
```

Updates arrive in the app. FlowDock reads a signed appcast and installs what you approve; the signature is checked against a key that Apple has nothing to do with, and nothing else is downloaded.

## Build from source

```sh
git clone https://github.com/arnavbonigala/FlowDock.git
cd FlowDock
open FlowDock.xcodeproj
```

Select the `FlowDock` scheme in Xcode, then build and run.

Run the same tests and unsigned debug build used by CI:

```sh
./scripts/verify.sh
```

See [RELEASING.md](RELEASING.md) for how releases are built and published.

## Privacy

No account, no analytics, no server of ours. [PRIVACY.md](PRIVACY.md) lists every
permission FlowDock asks for, everything that leaves your Mac, and how to remove all of it.

## Support

Bugs and feature requests go through the issue templates in this repository. Security
reports follow [SECURITY.md](SECURITY.md).

## Contributing

Read [CONTRIBUTING.md](CONTRIBUTING.md) before opening an issue or pull request.

## License and attribution

FlowDock is distributed under the GNU General Public License v3.0. See [LICENSE](LICENSE).

This project is derived from BoringNotch. Copyright and license notices for upstream and third-party work remain in the repository; see [NOTICE.md](NOTICE.md) and [THIRD_PARTY_LICENSES](THIRD_PARTY_LICENSES).
