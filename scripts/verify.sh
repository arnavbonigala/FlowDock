#!/usr/bin/env bash
set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
cd "$ROOT"

python3 -m unittest discover -s tests -p 'test_*.py'

if [[ "${1:-}" == "--scripts-only" ]]; then
  exit 0
fi

if ! command -v xcodebuild >/dev/null 2>&1 || ! xcodebuild -version >/dev/null 2>&1; then
  echo "Xcode $(<.xcode-version) is required. Select it with xcode-select before running verification." >&2
  exit 1
fi

required_xcode="$(<.xcode-version)"
actual_xcode="$(xcodebuild -version | awk '/^Xcode / { split($2, version, "."); print version[1] }')"
if [[ "$actual_xcode" != "$required_xcode" ]]; then
  echo "Expected Xcode $required_xcode, found Xcode $actual_xcode." >&2
  exit 1
fi

derived_data="${FLOWDOCK_DERIVED_DATA:-$ROOT/DerivedData/Verification}"

xcodebuild \
  -resolvePackageDependencies \
  -project FlowDock.xcodeproj \
  -clonedSourcePackagesDirPath "$derived_data/SourcePackages"

xcodebuild \
  -project FlowDock.xcodeproj \
  -scheme FlowDock \
  -configuration Debug \
  -destination 'generic/platform=macOS' \
  -derivedDataPath "$derived_data" \
  -clonedSourcePackagesDirPath "$derived_data/SourcePackages" \
  CODE_SIGNING_ALLOWED=NO \
  build
