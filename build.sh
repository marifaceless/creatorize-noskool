#!/bin/bash
# Builds a shareable "no Skool login" copy of Creatorize Suite from a stock app.
#
#   bash build.sh "/Volumes/Creatorize Suite/Creatorize Suite.app"   # or any copy of the .app
#   bash build.sh --no-updates "/path/to/Creatorize Suite.app"       # updates off, no launcher
#
# Writes dist/: the release zip (app + installer + README at the root), a dummy Setup.exe (the
# Windows asset the updater insists on) and update-manifest.json with sizes + sha256.
# Upload all three as the assets of a release tagged v<version> in THIS repo — installed copies
# then update themselves (check every 6 h, sha256-verified against the manifest, self-tested,
# handed to the Creatorize Launcher).
#
# Needs: node, npx (@electron/asar), codesign. ~6 min and ~2.5 GB temporary disk.

set -euo pipefail

REPO_SLUG="marifaceless/creatorize-noskool"

UPDATES=1
if [ "${1:-}" = "--no-updates" ]; then UPDATES=0; shift; fi
SRC="${1:?usage: bash build.sh [--no-updates] \"/path/to/Creatorize Suite.app\"}"

HERE="$(cd "$(dirname "$0")" && pwd)"
OUT="$HERE/dist"
WORK="$(mktemp -d)"
trap 'rm -rf "$WORK"' EXIT

APP="$WORK/Creatorize Suite.app"
RES="$APP/Contents/Resources"

echo "==> copy the app"
/usr/bin/ditto "$SRC" "$APP"
chmod -R u+w "$APP"
VER=$(/usr/libexec/PlistBuddy -c "Print :CFBundleShortVersionString" "$APP/Contents/Info.plist")
NAME="Creatorize-Suite-$VER-mac-arm64"
[ "$(uname -m)" = "arm64" ] || { echo "build on an Apple Silicon Mac (the bundle is arm64)"; exit 1; }
for f in entitlements.plist apply.mjs "installer/Install Creatorize Suite.command" installer/README.txt; do
  [ -f "$HERE/$f" ] || { echo "missing $f next to build.sh (clone the repo, do not copy build.sh alone)"; exit 1; }
done
echo "    version $VER, updates $([ "$UPDATES" = 1 ] && echo on || echo off)"

echo "==> extract app.asar"
npx --yes @electron/asar extract "$RES/app.asar" "$WORK/x"

echo "==> patch (every anchor must match; adjust apply.mjs on a new upstream version)"
if [ "$UPDATES" = 1 ]; then node "$HERE/apply.mjs" "$WORK/x"; else node "$HERE/apply.mjs" "$WORK/x" --no-updates; fi

echo "==> stamp the version where Electron actually reads it (app.getVersion prefers the asar's package.json)"
node -e '
const { readFileSync, writeFileSync } = require("node:fs");
const p = process.argv[1], v = process.argv[2];
const j = JSON.parse(readFileSync(p, "utf8"));
j.version = v;
writeFileSync(p, JSON.stringify(j, null, 2) + "\n");
console.log(`    package.json -> ${j.version}`);
' "$WORK/x/package.json" "$VER"

echo "==> repack"
npx --yes @electron/asar pack "$WORK/x" "$RES/app.asar"
rm -rf "$WORK/x"

echo "==> point the update source at this repo"
if [ "$UPDATES" = 1 ]; then
  printf 'owner: %s\nrepo: %s\nprovider: github\nreleaseType: release\nupdaterCacheDirName: creatorize-suite-updater\n' \
    "${REPO_SLUG%%/*}" "${REPO_SLUG##*/}" > "$RES/app-update.yml"
fi

echo "==> keep the app's file list honest (size + sha256; the app and the installer both check sizes)"
node -e '
const { createHash } = require("node:crypto"), { readFileSync, writeFileSync, statSync } = require("node:fs");
const [app, jp, yml] = process.argv.slice(1);
const j = JSON.parse(readFileSync(jp, "utf8"));
for (const [p, key] of [[app, "app.asar"], [yml, "app-update.yml"]]) {
  const h = createHash("sha256").update(readFileSync(p)).digest("hex");
  for (const f of j.files) if (f.path === key) { f.size = statSync(p).size; f.sha256 = h; }
}
writeFileSync(jp, JSON.stringify(j));
' "$RES/app.asar" "$RES/files.json" "$RES/app-update.yml"

echo "==> drop the fixed asar hash (it would be stale), sign ad hoc"
/usr/libexec/PlistBuddy -c "Delete :ElectronAsarIntegrity" "$APP/Contents/Info.plist" 2>/dev/null || true
xattr -cr "$APP"
codesign --force --deep --sign - --entitlements "$HERE/entitlements.plist" "$APP"
codesign --verify --deep --strict "$APP"

echo "==> stage the download (installer + README live inside the zip so a one-liner needs nothing else)"
STAGE="$WORK/$NAME"
mkdir -p "$STAGE"
/usr/bin/ditto "$APP" "$STAGE/Creatorize Suite.app"
cp "$HERE/installer/Install Creatorize Suite.command" "$HERE/installer/README.txt" "$STAGE/"
chmod +x "$STAGE/Install Creatorize Suite.command"
[ "$UPDATES" = 1 ] || printf 'no updates\n' > "$STAGE/NO-UPDATES"
( cd "$STAGE" && shasum -a 256 "Install Creatorize Suite.command" README.txt "Creatorize Suite.app/Contents/Resources/app.asar" "Creatorize Suite.app/Contents/Resources/files.json" > CHECKSUMS.txt )

echo "==> zip (ditto keeps the signature; zip does not)"
mkdir -p "$OUT"
rm -f "$OUT/$NAME.zip" "$OUT/update-manifest.json"
/usr/bin/ditto -c -k --sequesterRsrc "$STAGE" "$OUT/$NAME.zip"

echo "==> manifest (the updater refuses a release without these checksums)"
printf 'dummy setup exe (mac-only share build)\n' > "$OUT/Creatorize-Suite-Setup-$VER.exe"
node -e '
const { createHash } = require("node:crypto"), { readFileSync, writeFileSync, statSync, readdirSync } = require("node:fs");
const [dir, ver] = process.argv.slice(1);
const m = { version: ver, assets: {} };
for (const f of readdirSync(dir).filter((n) => n !== "update-manifest.json" && n !== "." && n !== "..")) {
  const p = `${dir}/${f}`;
  if (statSync(p).isDirectory()) continue;
  m.assets[f] = { size: statSync(p).size, sha256: createHash("sha256").update(readFileSync(p)).digest("hex") };
}
writeFileSync(`${dir}/update-manifest.json`, JSON.stringify(m, null, 1));
' "$OUT" "$VER"

echo
echo "done. publish all three:"
echo "  gh release create v$VER -R $REPO_SLUG --title \"$VER\" --notes '<what changed>' \\"
echo "    \"$OUT/$NAME.zip\" \"$OUT/Creatorize-Suite-Setup-$VER.exe\" \"$OUT/update-manifest.json\""
shasum -a 256 "$OUT/$NAME.zip"
