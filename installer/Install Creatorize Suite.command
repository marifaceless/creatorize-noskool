#!/bin/bash
# Installs this copy of Creatorize Suite into /Applications.
#
# This copy needs no Skool account: it starts straight to Home with Premium unlocked.
# Double-click this file (Terminal opens), or run: bash "Install Creatorize Suite.command"
#
# Safe to run again: it replaces an older copy. Your projects in ~/Documents/Creatorize Suite are never touched.

set -uo pipefail
cd "$(dirname "$0")" || exit 1

APP_SRC="Creatorize Suite.app"
APP_DST="/Applications/Creatorize Suite.app"
LAUNCHER="/Applications/Creatorize Launcher.app"

bold=$(printf '\033[1m'); dim=$(printf '\033[2m'); green=$(printf '\033[32m'); yellow=$(printf '\033[33m'); red=$(printf '\033[31m'); off=$(printf '\033[0m')
say() { printf '\n%s%s%s\n' "$bold" "$1" "$off"; }
ok() { printf '  %s[ok]%s %s\n' "$green" "$off" "$1"; }
warn() { printf '  %s[!]%s %s\n' "$yellow" "$off" "$1"; }
die() { printf '\n%sStopped:%s %s\n\n' "$red" "$off" "$1"; printf 'Press Return to close.\n'; read -r _; exit 1; }

printf '%sCreatorize Suite — install (no Skool login)%s\n' "$bold" "$off"
printf '%sThis copy runs as Premium and never asks you to sign in to Skool. You still sign in with your own Claude Code account inside the app: that is what makes the videos.%s\n' "$dim" "$off"

[ -d "$APP_SRC" ] || die "“$APP_SRC” is not next to this script. Unzip the download again and double-click the file inside the folder."

[ "$(uname -s)" = "Darwin" ] || die "this is a macOS build."
[ "$(uname -m)" = "arm64" ] || die "this build is for Apple Silicon Macs (M1 and newer). Ask for the Intel copy."

MACOS_MAJOR=$(sw_vers -productVersion | cut -d. -f1)
[ "$MACOS_MAJOR" -ge 12 ] || die "Creatorize Suite needs macOS 12 (Monterey) or newer. This Mac has $(sw_vers -productVersion)."

say "Quitting Creatorize Suite"
if pgrep -xq "Creatorize Suite"; then
  osascript -e 'tell application "Creatorize Suite" to quit' >/dev/null 2>&1 || true
  for _ in $(seq 1 20); do pgrep -xq "Creatorize Suite" || break; sleep 0.5; done
  if pgrep -xq "Creatorize Suite"; then
    warn "it is still open: quitting it the hard way"
    pkill -x "Creatorize Suite" || true
    sleep 1
  fi
  ok "Creatorize Suite is closed"
else
  ok "not running"
fi

# the Creatorize Launcher is what installs the updates of this copy: keep it, just close it while replacing the app
if pgrep -fq "Creatorize Launcher.app/Contents/MacOS"; then
  pkill -f "Creatorize Launcher.app/Contents/MacOS" || true
  sleep 1
  ok "closed the Creatorize Launcher while replacing the app (it reopens by itself)"
fi

say "Copying Creatorize Suite into Applications"
NEW="$APP_DST.new"
rm -rf "$NEW" 2>/dev/null || true
if ! ditto "$APP_SRC" "$NEW" 2>/dev/null; then
  rm -rf "$NEW" 2>/dev/null
  sudo -p "Mac password to write into Applications: " ditto "$APP_SRC" "$NEW" || die "the copy failed (disk full?)."
fi
[ -s "$NEW/Contents/Resources/app.asar" ] || { rm -rf "$NEW"; die "the copy is incomplete. Unzip the download again and retry."; }
ok "copied"

# not signed with an Apple Developer ID: drop the quarantine flag and re-seal it, so macOS opens it without a fuss
xattr -dr com.apple.quarantine "$NEW" 2>/dev/null || sudo xattr -dr com.apple.quarantine "$NEW" 2>/dev/null || true
codesign --force --deep --sign - "$NEW" >/dev/null 2>&1 || true
codesign --verify --deep "$NEW" >/dev/null 2>&1 && ok "signature sealed" || warn "could not re-seal it (macOS may ask to confirm, see below)"
chmod -R u+w "$NEW" 2>/dev/null || true

if [ -e "$APP_DST" ]; then
  rm -rf "$APP_DST.old" 2>/dev/null || true
  mv "$APP_DST" "$APP_DST.old" 2>/dev/null || sudo mv "$APP_DST" "$APP_DST.old" || { rm -rf "$NEW"; die "could not move the old copy aside (is it still open?)."; }
fi
mv "$NEW" "$APP_DST" 2>/dev/null || sudo mv "$NEW" "$APP_DST" || {
  [ -e "$APP_DST.old" ] && { mv "$APP_DST.old" "$APP_DST" 2>/dev/null || sudo mv "$APP_DST.old" "$APP_DST"; }
  die "could not put Creatorize Suite in Applications; the old copy is back."
}
rm -rf "$APP_DST.old" 2>/dev/null || sudo rm -rf "$APP_DST.old" 2>/dev/null || true
ok "installed"

say "Opening it"
open "$APP_DST" || warn "open it yourself from Applications"

printf '\n%sdone.%s It opens on Home, Premium unlocked, no sign-in.\n' "$green" "$off"
printf '%sNext: on the Home page follow “Getting started” — sign in with your own Claude account and let it install the tools it needs (git, ffmpeg, Python).%s\n' "$dim" "$off"
printf '%sIf macOS says "Apple could not verify Creatorize Suite" (only on the first start after this): click Done, then System Settings > Privacy & Security > scroll down > Open Anyway, and enter your Mac password.%s\n' "$yellow" "$off"
printf '%sNew versions install from inside the app (Settings > Updates, or it offers them). Nothing to do for that.%s\n' "$dim" "$off"
printf '\nPress Return to close.\n'
read -r _
