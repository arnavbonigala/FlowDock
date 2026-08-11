# Building a FlowDock extension

This is the how. The why, and the limits you are agreeing to, are in
[EXTENSIONS.md](EXTENSIONS.md) — read that first, because a declaration that asks for
something it forbids is simply not shown.

A FlowDock extension is a macOS app extension that ships inside an app you distribute.
It declares one activity and renders that activity's content in its own process.

## The shape of it

| Piece | What it is |
|---|---|
| Extension point | `com.arnavbonigala.flowdock.activity` |
| Declaration | One JSON object, returned over XPC when FlowDock asks |
| Scenes | `chin.leading`, `chin.trailing`, and optionally `panel` |

## 1. Add the target

In your app's project, **File ▸ New ▸ Target ▸ Generic Extension**. Then in the new
target's `Info.plist`:

```xml
<key>EXAppExtensionAttributes</key>
<dict>
    <key>EXExtensionPointIdentifier</key>
    <string>com.arnavbonigala.flowdock.activity</string>
</dict>
```

The extension is discovered when your app is in `/Applications` and has been launched
once. Nothing is registered with FlowDock and nothing is copied anywhere.

## 2. Declare the activity

FlowDock opens a connection and asks once, each time it refreshes. Reply with JSON:

```json
{
  "id": "focus",
  "presentation": "persistent",
  "rank": "progress",
  "label": "Focus session",
  "showsPanel": true,
  "live": true
}
```

| Field | Values | Meaning |
|---|---|---|
| `id` | any stable string | Namespaced with your bundle identifier, so it cannot collide |
| `presentation` | `contextual`, `persistent` | Contextual shows for 1.5 s and leaves; persistent stays while it is true |
| `rank` | `progress`, `media`, `ambient` | The band it competes in. The three above these are the system's |
| `label` | plain text | What VoiceOver says. Required |
| `showsPanel` | bool | Whether you also supply a `panel` scene |
| `live` | bool | Whether the activity is happening right now |

Return `live: false` — or nothing at all — and the activity ends. That is the whole
lifecycle: there is no separate begin and end call, and no state FlowDock keeps for you
between refreshes.

## 3. Supply the scenes

Each scene is a SwiftUI view rendered in your process and composited into FlowDock's
window. The chin scenes are drawn at roughly 40 × 22 points on a black background; the
panel is one full-width row of about 34 points. FlowDock chooses those sizes, and a view
that wants more is clipped rather than obeyed.

```swift
struct Scenes: AppExtensionScene {
    @AppExtensionSceneBuilder var body: some AppExtensionScene {
        PrimitiveAppExtensionScene(id: "chin.leading", content: {
            Image(systemName: "timer").foregroundStyle(.white)
        }, onConnection: accept)
    }
}
```

`onConnection` is where you export the declaration object:

```swift
let accept: @Sendable (NSXPCConnection) -> Bool = { connection in
    connection.exportedInterface = NSXPCInterface(with: FlowDockActivityExtensionProtocol.self)
    connection.exportedObject = Declaration()
    connection.resume()
    return true
}
```

## 4. The protocol

Copy this into your target. It is the entire interface between us:

```swift
@objc protocol FlowDockActivityExtensionProtocol {
    func activityDeclaration(reply: @escaping (String?) -> Void)
}
```

## Examples

Two, both of which type-check against the macOS 14 SDK:

- [`examples/Smallest`](examples/Smallest) — the least an extension can be: a contextual
  ambient activity, two chin views, no panel.
- [`examples/FocusTimer`](examples/FocusTimer) — a persistent progress activity with a
  countdown in the chin and a panel row with a control.

Each is a single file. Drop it into a Generic Extension target, set the extension point
identifier, and it runs.

## What will get your extension dropped

Not judgement calls — these are enforced:

- A `rank` of `drag`, `systemFeedback`, or `power`. The declaration fails to decode and
  the activity never begins.
- A missing `label`, or any missing field. Same outcome.
- Trying to open the panel, take focus, present a window, or handle a media key. There is
  no API for it, by design.
- Holding a process open to poll. FlowDock launches you to ask and lets the system
  terminate you when your activity is not on the chin.

## Testing it

Build and run your host app once, then turn the extension on in FlowDock ▸ Settings ▸
Activities. It appears in the same list as the built-in activities, with the same switch
and the same drag handle — if it is missing there, FlowDock never got a usable
declaration, and your extension's own log will say why.
