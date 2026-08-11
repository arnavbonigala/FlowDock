#!/usr/bin/env bash
set -euo pipefail

# Removes FlowDock and everything it leaves behind: the app, its preferences,
# its caches, its shelf storage, and the Accessibility grant held by the XPC
# helper. Also useful as a permission reset: run with --permissions-only to
# clear a stale Accessibility entry without removing the app. macOS keeps that
# entry keyed to the code signature and path, so moving or replacing the app
# leaves an entry that no longer matches and can no longer be granted from
# inside FlowDock.
#
# Usage: ./scripts/uninstall.sh [--permissions-only] [--dry-run]

APP_ID="com.arnavbonigala.flowdock"
HELPER_ID="com.arnavbonigala.flowdock.FlowDockXPCHelper"

permissions_only=false
dry_run=false
for arg in "$@"; do
  case "$arg" in
    --permissions-only) permissions_only=true ;;
    --dry-run) dry_run=true ;;
    *) echo "Unknown argument: $arg" >&2; exit 2 ;;
  esac
done

run() {
  if $dry_run; then
    echo "would run: $*"
  else
    "$@" >/dev/null 2>&1 || true
  fi
}

echo "Quitting FlowDock…"
run osascript -e 'tell application "FlowDock" to quit'
run pkill -x FlowDock
run pkill -x FlowDockXPCHelper

echo "Resetting Accessibility access…"
run tccutil reset Accessibility "$HELPER_ID"
run tccutil reset Accessibility "$APP_ID"

if $permissions_only; then
  echo "Done. Relaunch FlowDock and grant Accessibility again."
  exit 0
fi

echo "Resetting Calendar and Reminders access…"
run tccutil reset Calendar "$APP_ID"
run tccutil reset Reminders "$APP_ID"

echo "Removing the app…"
for app in /Applications/FlowDock.app "$HOME/Applications/FlowDock.app"; do
  [ -e "$app" ] && run rm -rf "$app"
done

echo "Removing preferences, caches, and stored data…"
# FlowDock is sandboxed, so its preferences, caches, and shelf bookmarks live in
# its container rather than in ~/Library. The paths below it cover copies built
# before the sandbox and cost nothing when they are absent.
run rm -rf "$HOME/Library/Containers/$APP_ID"
run rm -rf "$HOME/Library/Containers/$HELPER_ID"
run defaults delete "$APP_ID"
run rm -rf "$HOME/Library/Preferences/$APP_ID.plist"
run rm -rf "$HOME/Library/Caches/$APP_ID"
run rm -rf "$HOME/Library/HTTPStorages/$APP_ID"
run rm -rf "$HOME/Library/HTTPStorages/$APP_ID.binarycookies"
run rm -rf "$HOME/Library/Application Support/FlowDock"
run rm -rf "$HOME/Library/Saved Application State/$APP_ID.savedState"

echo "Done. The login item disappears with the app; log out and back in if it lingers."
