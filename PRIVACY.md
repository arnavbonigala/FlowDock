# Privacy

FlowDock has no account, no analytics, no crash reporting, and no server of its own. It
is a local app that reads what your Mac is already doing and draws it near the notch.

This document lists every permission it asks for, every byte that leaves the machine, and
what is written to disk. It describes the app as it is built from this repository; if you
find something here that the code contradicts, that is a bug worth reporting.

## What leaves your Mac

Four things, three of them optional, all of them off unless the feature is on:

| Request | When | What is sent | To |
|---|---|---|---|
| Update check | On launch and periodically, unless you turn automatic updates off | Nothing but the request itself | `arnavbonigala.github.io`, the appcast |
| Lyrics lookup | Only while **Lyrics** is on, which it is not by default | The current track's title and artist | `lrclib.net`, no account, no key |
| Album artwork | Only when the player gives a URL instead of an image, which Spotify and YouTube Music do | The request for that image | The music service's own artwork host |
| YouTube Music | Only with that source selected | Playback commands | `localhost` — your own Mac, not the network |

Nothing else. FlowDock does not send your calendar, your notifications, your files, your
shelf, your device names, or the fact that you use it, anywhere. There is no telemetry to
opt out of because none was written.

## What FlowDock asks macOS for

| Permission | Why | If you deny it |
|---|---|---|
| Accessibility | Reading notifications as they appear, and the media keys | Notification activities do not appear; nothing else changes |
| Calendar and Reminders | The agenda, the meeting countdown, and the join button | The calendar column is empty; nothing else changes |
| Apple Events, limited to Music and Spotify | Playback control and now-playing detail those apps only expose that way | Playback falls back to the system's Now Playing, with fewer controls |
| Files you drop | The shelf holds what you put in it | The shelf holds nothing |

FlowDock is sandboxed. It has no camera entitlement, no microphone entitlement, and no
ability to read files you did not hand it.

Accessibility is held by a separate helper process, `FlowDockXPCHelper`, so the trust you
grant is scoped to the thing that needs it. Notification text passes from that helper to
the app and is shown; it is not stored, not indexed, and not sent.

## What is written to disk

| What | Where | Lifetime |
|---|---|---|
| Your settings | The app's preferences domain | Until you change them or delete the app |
| Shelf items | Security-scoped bookmarks in the app's container — pointers to your files, not copies | Until you remove the item or clear the shelf |
| Artwork cache | The app's container, capped at 100 MB on disk | Evicted by the system's URL cache |

There is no database, no log of what you played or read, and no history of anything.

## Extensions

A third-party extension runs in its own sandboxed process and can see nothing of your
music, notifications, calendar, or shelf — only what it brought itself. What an extension
sends anywhere is between you and its developer, which is why
[DIRECTORY.md](DIRECTORY.md) requires a listed extension to say so in plain words.
FlowDock does not proxy an extension's network access and does not report which
extensions you have installed.

## Removing everything

Delete FlowDock.app, then:

```sh
defaults delete com.arnavbonigala.flowdock
rm -rf ~/Library/Containers/com.arnavbonigala.flowdock
```

That is the whole footprint. Revoke the Accessibility and Calendar entries in System
Settings ▸ Privacy & Security if you want the permission rows gone too.

## Reporting a privacy problem

Security issues go through [SECURITY.md](SECURITY.md). A privacy problem that is not a
vulnerability — data crossing a boundary this document says it does not cross — is a bug
report, and a valid one.
