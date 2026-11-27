#!/bin/bash
# One-line install of the newest Creatorize Suite no-Skool build (macOS arm64 + Intel).
#
#   curl -fsSL https://raw.githubusercontent.com/marifaceless/creatorize-noskool/main/get.sh | bash
#
# Downloads the newest release, checks it against the release's own sha256, installs it.
# On Windows (Git Bash / WSL) it just hands you the Setup.exe link: no bash needed there.

set -uo pipefail
REPO="marifaceless/creatorize-noskool"
red=$(printf '\033[31m'); dim=$(printf '\033[2m'); off=$(printf '\033[0m')

die() { printf '\n%sStopped:%s %s\n' "$red" "$off" "$1"; exit 1; }

API="https://api.github.com/repos/$REPO/releases?per_page=5"
latest_tag() {
  /usr/bin/curl -fsSL -H "accept: application/vnd.github+json" -H "user-agent: creatorize-noskool" "$API" 2>/dev/null |
    /usr/bin/python3 -c 'import json,sys
for r in json.load(sys.stdin):
    if not r["draft"] and not r["prerelease"]: print(r["tag_name"]); break' 2>/dev/null
}

case "$(uname -s)" in
  MINGW*|MSYS*|CYGWIN*)
    TAG=$(latest_tag) || true
    printf '\nWindows: this build installs with the Setup.exe, not a shell script.\n'
    if [ -n "${TAG:-}" ]; then printf '  https://github.com/%s/releases/download/%s/Creatorize-Suite-Setup-%s.exe\n\n' "$REPO" "$TAG" "${TAG#v}"
    else printf '  https://github.com/%s/releases/latest\n\n' "$REPO"; fi
    printf '%sWindows may warn that the app is unsigned: More info > Run anyway.%s\n' "$dim" "$off"
    printf 'It updates itself from then on. Your own Claude account is still needed inside the app.\n'
    exit 0 ;;
  Darwin) ;;
  *) printf '\nLinux: Creatorize Suite itself ships for macOS and Windows only (no Linux build), so there is nothing to install here.\n\n'; exit 0 ;;
esac

case "$(uname -m)" in
  arm64|aarch64) ARCH=arm64 ;;
  x86_64|amd64) ARCH=x64 ;;
  *) die "unknown Mac CPU: $(uname -m)" ;;
esac
[ "$(/usr/bin/sw_vers -productVersion | cut -d. -f1)" -ge 12 ] || die "macOS 12 (Monterey) or newer is needed."

printf 'Looking up the newest build …\n'
TAG=$(latest_tag) || die "GitHub could not be read."
[ -n "$TAG" ] || die "no release found."
printf '%snewest build: %s (%s)%s\n' "$dim" "$TAG" "$ARCH" "$off"

BASE="https://github.com/$REPO/releases/download/$TAG"
TMP=$(mktemp -d); trap 'rm -rf "$TMP"' EXIT
/usr/bin/curl -fL --progress-bar --retry 3 -o "$TMP/m.json" "$BASE/update-manifest.json" || die "the manifest did not download."
NAME=$(/usr/bin/python3 -c 'import json,sys
m=json.load(open(sys.argv[1])); want="-mac-" + sys.argv[2] + ".zip"
print(next(k for k in m["assets"] if k.endswith(want)))' "$TMP/m.json" "$ARCH") || die "this release has no $ARCH build."
WANT=$(/usr/bin/python3 -c 'import json,sys
print(json.load(open(sys.argv[1]))["assets"][sys.argv[2]]["sha256"])' "$TMP/m.json" "$NAME") || die "the manifest is unreadable."

printf 'Downloading %s (about %s MB) …\n' "$NAME" "$(/usr/bin/python3 -c 'import json,sys;print(round(json.load(open(sys.argv[1]))["assets"][sys.argv[2]]["size"]/1e6))' "$TMP/m.json" "$NAME")"
/usr/bin/curl -fL --progress-bar --retry 4 --retry-all-errors -o "$TMP/a.zip" "$BASE/$NAME" || die "the download failed. Run it again."

HAVE=$(/usr/bin/shasum -a 256 "$TMP/a.zip" | cut -d' ' -f1)
[ "$HAVE" = "$WANT" ] || die "the download does not match its checksum ($HAVE). Run it again."
printf '%schecksum ok%s\n' "$dim" "$off"

/usr/bin/ditto -x -k "$TMP/a.zip" "$TMP/x" || die "the download could not be unpacked."
[ -d "$TMP/x/Creatorize Suite.app" ] || die "the download does not contain the app (report it)."

/usr/bin/curl -fsSL -o "$TMP/i.command" "https://raw.githubusercontent.com/$REPO/main/installer/Install%20Creatorize%20Suite.command" || die "the installer did not download."
/bin/bash -n "$TMP/i.command" || die "the installer is unreadable."
CZ_NO_PAUSE=${CZ_NO_PAUSE:-} CZ_APP_SRC="$TMP/x/Creatorize Suite.app" /bin/bash "$TMP/i.command"
