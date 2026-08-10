# Contributing to FlowDock

Thanks for helping improve FlowDock.

## Before you start

- Search existing issues and pull requests to avoid duplicate work.
- Open an issue before starting a major product or interaction change.
- Keep changes focused and aligned with [ROADMAP.md](ROADMAP.md).
- Preserve upstream copyright, license, and attribution notices.

## Build the project

```sh
git clone https://github.com/arnavbonigala/FlowDock.git
cd FlowDock
open FlowDock.xcodeproj
```

FlowDock currently requires macOS 15.6 or later and Xcode 26 or later for development.

Before submitting a change, run:

```sh
./scripts/verify.sh
```

This runs the release-tool tests and builds the app without code signing, matching CI.

## Submit a change

1. Create a focused branch from the appropriate base branch.
2. Build and test the affected behavior.
3. Commit with a concise description of the change.
4. Open a pull request explaining what changed, why, and how it was verified.
5. Include screenshots or a recording for visible interface changes.

Bug reports should include reproduction steps, expected and actual behavior, the FlowDock version, macOS version, and relevant logs. Feature requests should describe the problem before proposing a solution.
