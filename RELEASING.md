# Releasing FlowDock

FlowDock ships unsigned. It is an open-source app distributed from GitHub releases, built by a workflow anyone can read, from a tag anyone can check out and rebuild. There is no Apple Developer Program membership behind it, no Developer ID certificate, and no notarization step. That is the distribution model, not a gap in it.

What that costs is one extra step for the person installing it, described in "First launch" below. What it buys is that every release is reproducible by anyone with a Mac and this repository.

Updates still work, and they are still signed: Sparkle verifies each update with an EdDSA key pair that FlowDock generates itself and Apple has nothing to do with.

FlowDock uses one verification command locally and in CI:

```sh
./scripts/verify.sh
```

It runs the release-tool tests and an unsigned debug build with the Xcode major version in `.xcode-version`.

## Secrets and variables

One secret matters, and it is free to create.

| Name | Kind | Where it comes from |
| --- | --- | --- |
| `SPARKLE_ED_PRIVATE_KEY` | secret | Generated locally with Sparkle's `generate_keys`. See "Sparkle signing key" below. |

Without it the build still produces a DMG, but no appcast entry can be signed, so installed copies are never offered the release. With it, the release path is complete.

### Sparkle signing key

`FlowDock/Info.plist` pins `SUPublicEDKey` to `B1Y47t8C/v8ImurYA+9arEsuCrpxwJSviekiflMElbI=`. Sparkle only accepts an update whose signature was made with the private half of **that** key. If you hold it, export it and store it as `SPARKLE_ED_PRIVATE_KEY`:

```sh
# Sparkle's tools live in the resolved package checkout
find ~/Library/Developer/Xcode/DerivedData -name generate_keys -type f
./generate_keys -x sparkle_private_key.txt   # writes the private key held in the login keychain
```

If that key is lost, generate a new pair and replace `SUPublicEDKey` in `FlowDock/Info.plist` in the same commit. Every copy of FlowDock already installed with the old public key will then stop accepting updates and has to be reinstalled by hand, so do this only once and keep the key safe.

## Build an artifact

Run the **Manual Build** workflow with a branch, optional version, and optional build number. It uploads the `.app` and `.dmg` as workflow artifacts. Version values are passed to the build and do not modify the branch.

Builds are ad-hoc signed. The workflow still contains a Developer ID path that activates if certificate secrets are ever added, but no release process depends on it and none needs to.

## Publish a release

Releases are built only from version tags. Tag the exact commit to release and push the tag:

```sh
git tag v0.1.0
git push origin v0.1.0
```

Tags must use `v<major>.<minor>.<patch>`. A tag such as `v1.2.0-beta.1` creates a GitHub prerelease. The workflow checks out the immutable tag, builds it, attaches the DMG to a generated GitHub release, and publishes the appcast entry. Ordinary branch commits only run verification and never create releases.

## First launch

macOS quarantines anything downloaded from the internet that Apple has not notarized. On first launch it reports that FlowDock cannot be opened because Apple cannot check it for malicious software. This is expected for an unsigned app and says nothing about what the app does — the build is reproducible from this repository.

Users open it once through System Settings:

1. Try to open FlowDock. Dismiss the warning.
2. System Settings → Privacy & Security, scroll to Security. A line names FlowDock. Click **Open Anyway**.
3. Confirm. FlowDock opens, and every later launch is normal.

Users who prefer the terminal can clear the flag directly:

```sh
xattr -d com.apple.quarantine /Applications/FlowDock.app
```

Keep these instructions in the README and in the release notes of every release. This is the step that loses people, and it costs one paragraph to prevent.

## Accessibility permission across updates

FlowDock's HUD replacement needs Accessibility access, held by `FlowDockXPCHelper`. macOS keys that grant to the code signature and path of the helper. An ad-hoc signature changes with every build, so **an update can invalidate the grant** and the user has to remove and re-add the entry in System Settings.

FlowDock is built to make that survivable rather than mysterious:

- The authorization monitor runs for the life of the app, not only while a window is open, so the loss is noticed immediately.
- Losing access stops the event tap, which hands the HUD back to macOS. The user sees the system volume and brightness overlays return — that is the signal something changed.
- Onboarding and Settings both offer "Open Accessibility settings" and explain that the entry must be removed and re-added, because the in-app prompt cannot fix a stale TCC entry on its own.
- `./scripts/uninstall.sh --permissions-only` does the same reset non-interactively.

Say this plainly in the release notes of any update that changes the helper. A user who is told in advance follows two steps; a user who is surprised files a bug about the app breaking itself.

## The update feed

The app reads `SUFeedURL` from `FlowDock/Info.plist`: `https://arnavbonigala.github.io/FlowDock/appcast.xml`. GitHub Pages serves that from a `gh-pages` branch which has no source in this repository — the release workflow creates and maintains it, seeding it from the checked-in `updater/appcast.xml` skeleton the first time. DMGs stay on GitHub releases; only `appcast.xml` lives on the branch.

Each release the build signs the DMG with `sign_update` from the resolved Sparkle package, and `scripts/appcast.py` writes the resulting `<item>` into the feed. Re-running the same version replaces its item rather than duplicating it, and items stay newest-first.

GitHub Pages has to be enabled once, by hand: repository Settings → Pages → Source: "Deploy from a branch", branch `gh-pages`, folder `/`. Until that is done the feed is committed but not served.

**Rollback.** Sparkle offers whatever is newest in the feed. To withdraw a bad release, delete its `<item>` from `appcast.xml` on `gh-pages` and push; installs that have not updated yet stop being offered it. Anyone already updated must be given a higher version, so follow a withdrawal with a fixed release rather than a re-tag.

## Verify a release

On a Mac that has never had this build:

```sh
# 1. The app is ad-hoc signed and its signature is intact
codesign --verify --deep --strict --verbose=2 /Volumes/FlowDock*/FlowDock.app
codesign -dv --verbose=4 /Volumes/FlowDock*/FlowDock.app 2>&1 | grep -E 'Signature|Identifier'

# 2. Gatekeeper rejects it, which is expected and is what the first-launch steps are for
spctl --assess --type open --context context:primary-signature -v FlowDock.dmg || true

# 3. The feed is live and its entry is signed
curl -fsSL https://arnavbonigala.github.io/FlowDock/appcast.xml
```

Then walk the first-launch steps exactly as written above, on a machine that has never run FlowDock, and confirm they work on the macOS version you are shipping for. Apple changes this flow between releases; the instructions are part of the product.

Finally run a real update cycle, which is the only test that proves the release: install the **previous** version, launch it, grant Accessibility, quit, publish the new release, launch the old version again, and take the update from "Check for Updates…". Confirm the update installs and launches. Then check whether HUD replacement still works or whether Accessibility has to be re-granted, and put the answer in the release notes.

## Release channels and compatibility

**Two channels, one feed.** Stable items carry no `sparkle:channel`, which is what makes them the default: Sparkle offers an unmarked item to every install. Prerelease tags publish with `--channel beta`, and only an install that has turned on "Include beta releases" in Settings is offered them. This is not cosmetic — without the channel a `v1.2.0-beta.1` tag would update every stable user to a beta, and there is no way to take it back once they have it.

Turning the toggle off stops future betas being offered. It does not move that install back to stable; the way down from a beta is the next stable release with a higher version, exactly as under Rollback above.

**What a version number promises.**

| Change | What it means |
|---|---|
| Patch — `1.2.0` → `1.2.1` | Fixes only. No setting moves, no activity changes shape, no extension recompiles. |
| Minor — `1.2.0` → `1.3.0` | New activities and settings. Existing settings keep their meaning, and an extension built against `1.2` still loads. |
| Major — `1.x` → `2.0` | Something on this list breaks. The release notes say exactly what and how to migrate. |

Settings are `Defaults` keys with defaults in `FlowDock/models/Constants.swift`. A key that is renamed or removed in a minor release is a bug — a user who upgrades must never silently lose a preference. Removing a key means giving it a migration, not deleting the line.

**macOS support.** The deployment target is macOS 14, and `sparkle:minimumSystemVersion` in every appcast item repeats it, so an older Mac is never offered a build it cannot run. Raising the floor is a minor release at least, is announced in the release notes of the version before it, and is never done to reach a convenience API. Two versions of macOS are supported at any time; when a third ships, dropping the oldest becomes possible, not automatic.

**Extensions.** The host/extension boundary is the activity declaration in [EXTENSIONS.md](EXTENSIONS.md), decoded by `ActivityExtension.declaration(from:)`. It carries no version field, so compatibility rests entirely on the rule above: within a major version the declaration only ever gains optional keys, and an extension that omits them keeps loading. Adding a required key, renaming one, or changing what a value means is a major version. If the boundary ever needs to change faster than that, it needs a version field first.

## Uninstall and permission reset

```sh
./scripts/uninstall.sh                     # app, preferences, caches, shelf data, TCC grants
./scripts/uninstall.sh --permissions-only  # only clear the stale Accessibility entry
./scripts/uninstall.sh --dry-run           # print what it would do
```

## Current boundary

The plumbing is in place and unexercised. These cannot be closed from inside the repository:

- No Sparkle private key exists yet, so no build has produced a signed appcast entry.
- GitHub Pages has never been enabled, and the `gh-pages` branch does not exist yet.
- The full update cycle above has never been run, so `SUEnableInstallerLauncherService` and the helper's TCC identity across an in-place update remain untested.
