#!/bin/bash
# One-line install of the newest Creatorize Suite no-Skool build:
#
#   curl -fsSL https://raw.githubusercontent.com/marifaceless/creatorize-noskool/main/get.sh | bash
#
# Downloads the latest release, checks it against the release's own sha256, and runs its installer.
# macOS 12+, Apple Silicon.

set -uo pipefail
REPO="marifaceless/creatorize-noskool"
red=$(printf '\033[31m'); dim=$(printf '\033[2m'); off=$(printf '\033[0m')

die() { printf '\n%sStopped:%s %s\n' "$red" "$off" "$1"; exit 1; }

[ "$(uname -s)" = "Darwin" ] || die "this is macOS only."
[ "$(uname -m)" = "arm64" ] || die "this build is for Apple Silicon Macs (M1 and newer)."
[ "$(/usr/bin/sw_vers -productVersion | cut -d. -f1)" -ge 12 ] || die "macOS 12 (Monterey) or newer is needed."

API="https://api.github.com/repos/$REPO/releases?per_page=5"
printf 'Looking up the newest build …\n'
TAG=$(/usr/bin/curl -fsSL -H "accept: application/vnd.github+json" -H "user-agent: creatorize-noskool" "$API" |
  /usr/bin/python3 -c 'import json,sys
for r in json.load(sys.stdin):
    if not r["draft"] and not r["prerelease"]: print(r["tag_name"]); break') || die "GitHub could not be read."
[ -n "$TAG" ] || die "no release found."
printf '%snewest build: %s%s\n' "$dim" "$TAG" "$off"

BASE="https://github.com/$REPO/releases/download/$TAG"
TMP=$(mktemp -d); trap 'rm -rf "$TMP"' EXIT
/usr/bin/curl -fL --progress-bar --retry 3 -o "$TMP/m.json" "$BASE/update-manifest.json" || die "the manifest did not download."
NAME=$(/usr/bin/python3 -c 'import json,sys
m=json.load(open(sys.argv[1]))
print(next(k for k in m["assets"] if k.endswith("-mac-arm64.zip")))' "$TMP/m.json") || die "the manifest is unreadable."
WANT=$(/usr/bin/python3 -c 'import json,sys
m=json.load(open(sys.argv[1]))
print(m["assets"][sys.argv[2]]["sha256"])' "$TMP/m.json" "$NAME") || die "the manifest is unreadable."

printf 'Downloading %s (about 630 MB) …\n' "$NAME"
/usr/bin/curl -fL --progress-bar --retry 4 --retry-all-errors -o "$TMP/a.zip" "$BASE/$NAME" || die "the download failed. Run it again."

HAVE=$(/usr/bin/shasum -a 256 "$TMP/a.zip" | cut -d' ' -f1)
[ "$HAVE" = "$WANT" ] || die "the download does not match its checksum ($HAVE). Run it again."
printf '%schecksum ok%s\n' "$dim" "$off"

/usr/bin/ditto -x -k "$TMP/a.zip" "$TMP/x" || die "the download could not be unpacked."
INSTALLER=$(/usr/bin/find "$TMP/x" -maxdepth 2 -name "Install Creatorize Suite.command" -print -quit)
[ -n "$INSTALLER" ] || die "the release has no installer (report it)."

CZ_NO_PAUSE=${CZ_NO_PAUSE:-} CZ_APP_SRC="$(dirname "$INSTALLER")/Creatorize Suite.app" /bin/bash "$INSTALLER"
