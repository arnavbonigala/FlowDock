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

## Current boundary

Artifacts use Apple development signing and are not notarized. They are suitable for internal verification, not a polished public distribution path. Developer ID signing, notarization, Sparkle appcast publication, and release rollback remain release-readiness work.
