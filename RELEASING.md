# Releasing FlowDock

FlowDock uses one verification command locally and in CI:

```sh
./scripts/verify.sh
```

It runs the release-tool tests and an unsigned debug build with the Xcode major version in `.xcode-version`.

## Build an artifact

Run the **Manual Build** workflow with a branch, optional version, and optional build number. The workflow signs the app with the configured development certificate and uploads the `.app` and `.dmg` as workflow artifacts. Version values are passed to the build and do not modify the branch.

Required repository configuration:

- `BUILD_CERTIFICATE_BASE64`, `P12_PASSWORD`, and `KEYCHAIN_PASSWORD` secrets
- `DEVELOPMENT_TEAM_ID` variable

## Publish a release

Releases are built only from version tags. Tag the exact commit to release and push the tag:

```sh
git tag v0.1.0
git push origin v0.1.0
```

Tags must use `v<major>.<minor>.<patch>`. A tag such as `v1.2.0-beta.1` creates a GitHub prerelease. The workflow checks out the immutable tag, builds its app and DMG, and attaches the DMG to a generated GitHub release. Ordinary branch commits only run verification and never create releases.

## Publish the update feed

The app reads `SUFeedURL` from `FlowDock/Info.plist`: `https://arnavbonigala.github.io/FlowDock/appcast.xml`. `updater/appcast.xml` is the checked-in skeleton of that feed and currently has no `<item>`, so a running copy of FlowDock will never see an update until the feed is generated and published. Nothing in CI does this yet; it is a manual step.

Sparkle ships the tool, so do not write one:

```sh
# Sparkle's binaries land in the resolved package checkout
generate_appcast --ed-key-file <private-key-file> updater/
```

Put every released DMG in `updater/` before running it. `generate_appcast` writes the `<item>`, the length, and the `sparkle:edSignature` for each archive it finds. The signature must be made with the private half of the `SUPublicEDKey` already in `FlowDock/Info.plist` (`B1Y47t8C/…`); Sparkle's `generate_keys` stores that key in the login keychain of whoever created it. **FlowDock has no published private key and no CI secret holding one.** Until one is available, the feed cannot be signed and the updater cannot ship an update, no matter how the app is built.

Publish the resulting `appcast.xml` and the DMG at the `SUFeedURL` host (a `gh-pages` branch or `docs/` folder — neither exists in this repo yet).

## Uninstall and permission reset

```sh
./scripts/uninstall.sh                     # app, preferences, caches, shelf data, TCC grants
./scripts/uninstall.sh --permissions-only  # only clear the stale Accessibility entry
./scripts/uninstall.sh --dry-run           # print what it would do
```

macOS keys the Accessibility grant to the code signature and path of `FlowDockXPCHelper`. Move the app, replace it with a differently signed build, or let Sparkle install one, and the existing entry stops matching. The in-app prompt then does nothing, because from TCC's point of view an entry already exists. FlowDock detects the loss (the authorization monitor runs for the life of the app, not only while a window is open), stops the event tap so macOS draws its own HUD again, and offers "Open Accessibility settings" in both onboarding and settings. Removing and re-adding the entry there — or running `--permissions-only` — is the way back.

## Current boundary

Artifacts use Apple development signing and are not notarized. They are suitable for internal verification, not a polished public distribution path. The following need real credentials and a real install/update cycle, and cannot be closed in the repository alone:

- **Developer ID signing.** `CODE_SIGN_IDENTITY` is `Apple Development` in `project.pbxproj` and in both workflows. Development certificates are per-developer and expire, so every build has a different signing identity — which is exactly why the Accessibility grant does not survive an update today. A stable `Developer ID Application` certificate is the fix; it requires a paid Apple Developer account.
- **Notarization and stapling.** No `notarytool` step exists. Without it, a downloaded DMG is quarantined and Gatekeeper refuses the app.
- **Sparkle EdDSA private key.** See above.
- **Feed hosting and rollback.** Nothing publishes to the `SUFeedURL` host, and there is no procedure for withdrawing a bad release from the feed.
