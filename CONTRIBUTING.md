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

Changes must meet the applicable release gates in [QUALITY.md](QUALITY.md). Interface changes must also follow [DESIGN.md](DESIGN.md) and [INTERACTION.md](INTERACTION.md). New drop workflows must pass the test in [WORKFLOWS.md](WORKFLOWS.md) or ship as an extension, under the boundary in [EXTENSIONS.md](EXTENSIONS.md).

## Submit a change

1. Create a focused branch from the appropriate base branch.
2. Build and test the affected behavior.
3. Commit with a concise description of the change.
4. Open a pull request explaining what changed, why, and how it was verified.
5. Include screenshots or a recording for visible interface changes.

Bug reports should include reproduction steps, expected and actual behavior, the FlowDock version, macOS version, and relevant logs. Feature requests should describe the problem before proposing a solution.

## What happens to what you file

Three intake paths, and one place each ends up:

| You file | It lands as | What happens next |
|---|---|---|
| Bug report | `unconfirmed` | Someone reproduces it. Reproduced, it loses `unconfirmed` and gains the area it lives in; not reproduced, it stays open with a question rather than being closed. |
| Feature request | `Feature` | Weighed against [EXTENSIONS.md](EXTENSIONS.md): things FlowDock builds become roadmap items, everything else becomes an extension proposal. |
| Extension proposal | `extension` | An idea gets a yes or no against the same criteria; a listing request is reviewed against [DIRECTORY.md](DIRECTORY.md) and either listed or told what is missing. |

A request that is declined is answered with which line it fell on, not closed silently. A
report with no reproduction steps is asked for them once and closed if they never arrive —
that is a limit on time, not a judgement about the bug.

Security vulnerabilities never go through issues. [SECURITY.md](SECURITY.md) is the only
path, and it is private.
