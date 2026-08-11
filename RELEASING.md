# Releasing FlowDock

FlowDock uses one verification command locally and in CI:

```sh
./scripts/verify.sh
```

It runs the release-tool tests and an unsigned debug build with the Xcode major version in `.xcode-version`.

## Secrets and variables

The release path degrades honestly: with no secrets it still builds, and every step that had to be skipped prints a warning saying the artifact is not releasable. Configure these to get a real release.

| Name | Kind | Where it comes from |
| --- | --- | --- |
| `DEVELOPMENT_TEAM_ID` | variable | Apple Developer account → Membership → Team ID |
| `DEVELOPER_ID_CERTIFICATE_BASE64` | secret | A `Developer ID Application` certificate exported from Keychain Access as `.p12`, then `base64 -i cert.p12 \| pbcopy` |
| `DEVELOPER_ID_CERTIFICATE_PASSWORD` | secret | The password chosen during that `.p12` export |
| `KEYCHAIN_PASSWORD` | secret | Any random string; it only unlocks the temporary keychain on the runner |
| `NOTARY_APPLE_ID` | secret | The Apple ID of the account that owns the certificate |
| `NOTARY_PASSWORD` | secret | An app-specific password from appleid.apple.com → Sign-In and Security → App-Specific Passwords (not the account password) |
| `SPARKLE_ED_PRIVATE_KEY` | secret | See "Sparkle signing key" below |
| `BUILD_CERTIFICATE_BASE64`, `P12_PASSWORD` | secret | Optional. An `Apple Development` certificate, used only when no Developer ID certificate is configured. Never releasable. |

The Developer ID certificate requires a paid Apple Developer Program membership. Without it, and without notarization, macOS quarantines the downloaded DMG and refuses to open the app.

### Sparkle signing key

`FlowDock/Info.plist` already pins `SUPublicEDKey` to `B1Y47t8C/v8ImurYA+9arEsuCrpxwJSviekiflMElbI=`. Sparkle only accepts an update whose signature was made with the private half of **that** key. If you hold it, export it and store it as `SPARKLE_ED_PRIVATE_KEY`:

```sh
# Sparkle's tools live in the resolved package checkout
find ~/Library/Developer/Xcode/DerivedData -name generate_keys -type f
./generate_keys -x sparkle_private_key.txt   # writes the private key held in the login keychain
```

If that key is lost, generate a new pair and replace `SUPublicEDKey` in `FlowDock/Info.plist` in the same commit. Every copy of FlowDock already installed with the old public key will then stop accepting updates and has to be reinstalled by hand, so do this only once and keep the key safe.

## Build an artifact

Run the **Manual Build** workflow with a branch, optional version, and optional build number. It uploads the `.app` and `.dmg` as workflow artifacts. Version values are passed to the build and do not modify the branch.

The workflow picks its signing mode from the secrets that exist:

| Mode | Condition | Result |
| --- | --- | --- |
| `developer-id` | `DEVELOPER_ID_CERTIFICATE_BASE64` is set | Hardened runtime, secure timestamp, notarized and stapled when the notary secrets are also set |
| `development` | Only `BUILD_CERTIFICATE_BASE64` is set | Builds and exports, cannot be notarized, quarantined after download |
| `adhoc` | Neither is set | Unsigned build, quarantined after download, for local verification only |

## Publish a release

Releases are built only from version tags. Tag the exact commit to release and push the tag:

```sh
git tag v0.1.0
git push origin v0.1.0
```

Tags must use `v<major>.<minor>.<patch>`. A tag such as `v1.2.0-beta.1` creates a GitHub prerelease. The workflow checks out the immutable tag, builds and signs its app, notarizes and staples the DMG, attaches the DMG to a generated GitHub release, and publishes the appcast entry. Ordinary branch commits only run verification and never create releases.

## The update feed

The app reads `SUFeedURL` from `FlowDock/Info.plist`: `https://arnavbonigala.github.io/FlowDock/appcast.xml`. GitHub Pages serves that from a `gh-pages` branch which has no source in this repository — the release workflow creates and maintains it, seeding it from the checked-in `updater/appcast.xml` skeleton the first time. DMGs stay on GitHub releases; only `appcast.xml` lives on the branch.

Each release the build signs the DMG with `sign_update` from the resolved Sparkle package, and `scripts/appcast.py` writes the resulting `<item>` into the feed. Re-running the same version replaces its item rather than duplicating it, and items stay newest-first.

GitHub Pages has to be enabled once, by hand: repository Settings → Pages → Source: "Deploy from a branch", branch `gh-pages`, folder `/`. Until that is done the feed is committed but not served.

**Rollback.** Sparkle offers whatever is newest in the feed. To withdraw a bad release, delete its `<item>` from `appcast.xml` on `gh-pages` and push; installs that have not updated yet stop being offered it. Anyone already updated must be given a higher version, so follow a withdrawal with a fixed release rather than a re-tag.

## Verify a release

On a Mac that has never had this build:

```sh
# 1. The DMG is signed, notarized, and stapled
spctl --assess --type open --context context:primary-signature -v FlowDock.dmg
stapler validate FlowDock.dmg

# 2. The app inside is signed with a Developer ID and hardened
codesign --verify --deep --strict --verbose=2 /Volumes/FlowDock*/FlowDock.app
codesign -dv --verbose=4 /Volumes/FlowDock*/FlowDock.app 2>&1 | grep -E 'Authority|flags'

# 3. The feed is live and signed
curl -fsSL https://arnavbonigala.github.io/FlowDock/appcast.xml
```

Then run a real update cycle, which is the only test that proves the release: install the **previous** version, launch it, grant Accessibility, quit, publish the new release, launch the old version again, and take the update from "Check for Updates…". Afterwards confirm that HUD replacement still works without re-granting anything. A stable Developer ID identity is what makes that grant survive; an `Apple Development` build will lose it every time.

## Uninstall and permission reset

```sh
./scripts/uninstall.sh                     # app, preferences, caches, shelf data, TCC grants
./scripts/uninstall.sh --permissions-only  # only clear the stale Accessibility entry
./scripts/uninstall.sh --dry-run           # print what it would do
```

macOS keys the Accessibility grant to the code signature and path of `FlowDockXPCHelper`. Move the app, replace it with a differently signed build, or let Sparkle install one, and the existing entry stops matching. The in-app prompt then does nothing, because from TCC's point of view an entry already exists. FlowDock detects the loss (the authorization monitor runs for the life of the app, not only while a window is open), stops the event tap so macOS draws its own HUD again, and offers "Open Accessibility settings" in both onboarding and settings. Removing and re-adding the entry there — or running `--permissions-only` — is the way back.

## Current boundary

The plumbing is in place and unexercised. Nothing here has produced a signed, notarized release or a real in-place update yet, and these cannot be closed from inside the repository:

- No Developer ID certificate, notary credentials, or Sparkle private key exist, so every build so far has been `development` or `adhoc` — not releasable.
- GitHub Pages has never been enabled, and the `gh-pages` branch does not exist yet.
- The full update cycle above has never been run, so `SUEnableInstallerLauncherService` and the helper's TCC identity across an in-place update remain untested.
