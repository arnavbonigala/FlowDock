# The extension directory

FlowDock does not host, sell, sign, or install extensions. What it can do is tell a user
that a particular one has been looked at. This file is that list, and this document is
what being on it means.

An extension is an app you download from its own developer, the way you download any Mac
app. Listing changes nothing about how it is installed, updated, or removed — it is a
statement that a person read the source and ran the thing.

## The list

| Extension | What it shows | Source | Reviewed |
|---|---|---|---|
| _None yet_ | | | |

The three examples in [`examples/`](examples) are reference code rather than products, and
are deliberately not listed here.

## Getting listed

Open a pull request adding a row. It is accepted when all of the following are true, and
the review is a person checking each one:

1. **Source is public and the listed build comes from it.** Not "open core", not a
   published subset. If the source cannot be built into the binary being distributed,
   there is nothing to review.
2. **Signed with a Developer ID and notarized.** FlowDock will not host an extension from
   an app macOS did not validate, so an unnotarized submission cannot work anyway.
3. **One activity, declared honestly.** The band matches what the activity is; the label
   says what a screen reader should hear; `live` is false when nothing is happening.
4. **It states what leaves the machine.** A network call, a service, an account, or
   telemetry — named in the README, in plain words. "None" is an answer, and the common
   one.
5. **It is idle when idle.** No login item, no background polling to keep a number warm,
   no work while its activity is not on the chin.
6. **Removing the app removes the extension.** Nothing is left in FlowDock's settings but
   a row that disappears, and no state is left anywhere else.

A listing is removed, without discussion, if the extension later violates any of these, or
if it takes the chin for something the user did not ask for — advertising, upsell, or a
notification wearing an activity's clothes.

## What the directory deliberately is not

- **Not a store.** No payments, no accounts, no ratings, no install button. A row is a
  link to someone else's release page.
- **Not an endorsement of the software's quality.** It says the six checks above passed on
  a given date, at a given version, and nothing more.
- **Not automatic.** Nothing is fetched, and no extension list is downloaded at runtime.
  FlowDock ships no directory URL it polls; the user opens this page, or does not.
- **Not a lock-in.** An extension that is never listed works exactly as well. Listing
  grants no capability, no priority, and no badge in the interface.

## For users

FlowDock discovers an extension because you installed the app it came in. It stays off
until you turn it on in Settings ▸ Activities, it runs in its own sandbox, and it can see
nothing of your music, notifications, calendar, or shelf. If an extension misbehaves, turn
it off there; to be rid of it, delete the app that carries it.
