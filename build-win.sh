#!/bin/bash
# Builds the Windows copy of the no-Skool patch from the official win-x64 zip.
#
#   bash build-win.sh "/path/to/Creatorize-Suite-0.27.0-win-x64.zip" [version]
#
# Writes dist/: Creatorize-Suite-<v>-win-x64.zip (portable), Creatorize-Suite-Setup-<v>.exe
# (NSIS, built from the patched app with electron-builder --prepackaged) and latest.yml
# (what the Windows updater reads; sha512 of the Setup exe).
#
# Needs: node, npx. Runs fine on macOS; produces Windows binaries (no Windows needed).

set -euo pipefail
SRC="${1:?usage: bash build-win.sh \"/path/to/Creatorize-Suite-<v>-win-x64.zip\" [version]}"
REPO_SLUG="marifaceless/creatorize-noskool"
HERE="$(cd "$(dirname "$0")" && pwd)"
OUT="$HERE/dist"
WORK="$(mktemp -d)"
trap 'rm -rf "$WORK"' EXIT

VER="${2:-}"
if [ -z "$VER" ]; then
  VER=$(/usr/bin/basename "$SRC" | /usr/bin/sed -E 's/^Creatorize-Suite-([0-9.]+)-win-x64\.zip$/\1/')
  case "$VER" in *[!0-9.]*) echo "could not read the version from $SRC — pass it: bash build-win.sh <zip> 0.28.0"; exit 1;; esac
fi
echo "==> version $VER"

echo "==> unpack (the upstream zip stores \\ as the separator; normalise it)"
/usr/bin/python3 - "$SRC" "$WORK/wu" <<'PY'
import zipfile, os, sys
z = zipfile.ZipFile(sys.argv[1])
for info in z.infolist():
    name = info.filename.replace("\\", "/")
    if name.endswith("/"): continue
    t = os.path.join(sys.argv[2], name)
    os.makedirs(os.path.dirname(t), exist_ok=True)
    with open(t, "wb") as f: f.write(z.read(info))
print("    done")
PY
RES="$WORK/wu/resources"

echo "==> patch the asar (every anchor must match; adjust apply.mjs on a new upstream version)"
npx --yes @electron/asar extract "$RES/app.asar" "$WORK/x"
node "$HERE/apply.mjs" "$WORK/x"

echo "==> stamp the version where Electron reads it (package.json inside the asar)"
node -e '
const { readFileSync, writeFileSync } = require("node:fs");
const p = process.argv[1], v = process.argv[2];
const j = JSON.parse(readFileSync(p, "utf8")); j.version = v;
writeFileSync(p, JSON.stringify(j, null, 2) + "\n");
' "$WORK/x/package.json" "$VER"
npx --yes @electron/asar pack "$WORK/x" "$RES/app.asar"
rm -rf "$WORK/x"

echo "==> check the stamp survived the repack (a stale one makes the updater loop)"
node -e '
const { execFileSync } = require("node:child_process"), { readFileSync, mkdtempSync, rmSync } = require("node:fs"), os = require("node:os"), path = require("node:path");
const [asar, want] = process.argv.slice(1);
const d = mkdtempSync(path.join(os.tmpdir(), "cz-"));
execFileSync("npx", ["--yes", "@electron/asar", "extract", asar, d], { stdio: "ignore" });
const got = JSON.parse(readFileSync(path.join(d, "package.json"), "utf8")).version;
rmSync(d, { recursive: true, force: true });
if (got !== want) { console.error(`package.json inside the asar says ${got}, expected ${want} — the update would loop`); process.exit(1); }
console.log(`    version ok: ${got}`);
' "$RES/app.asar" "$VER"

echo "==> point the update source at this repo"
printf 'owner: %s\nrepo: %s\nprovider: github\nreleaseType: release\nupdaterCacheDirName: creatorize-suite-updater\n' \
  "${REPO_SLUG%%/*}" "${REPO_SLUG##*/}" > "$RES/app-update.yml"

echo "==> keep the app's file list honest (size + sha256 of the two files we replaced)"
node -e '
const { createHash } = require("node:crypto"), { readFileSync, writeFileSync, statSync } = require("node:fs");
const res = process.argv[2];
const j = JSON.parse(readFileSync(`${res}/files.json`, "utf8"));
for (const f of j.files) {
  if (f.path.endsWith("app.asar") || f.path.endsWith("app-update.yml")) {
    const p = `${res}/${f.path.split("/").pop()}`;
    f.size = statSync(p).size; f.sha256 = createHash("sha256").update(readFileSync(p)).digest("hex");
  }
}
writeFileSync(`${res}/files.json`, JSON.stringify(j));
' "$RES"

echo "==> NSIS installer (electron-builder --prepackaged, runs on macOS, no Windows needed)"
EB="$WORK/eb"; mkdir -p "$EB"
cp "$HERE/installer/eb-package.json" "$EB/package.json"
[ -f "$WORK/wu/resources/resources/icon.ico" ] || { echo "no icon.ico in the app — put one next to this script as installer/eb-icon.ico"; exit 1; }
cp "$WORK/wu/resources/resources/icon.ico" "$EB/icon.ico"
(cd "$EB" && npx --yes electron-builder@26 --win nsis --prepackaged "$WORK/wu" -c.electronVersion=44.4.5 >/dev/null 2>&1) \
  || { echo "electron-builder failed — publish the portable zip + latest.yml anyway (Windows friends then update by hand)"; }
SETUP="$EB/dist/Creatorize-Suite-Setup-$VER.exe"
[ -f "$SETUP" ] || { echo "no Setup.exe was built"; exit 1; }

echo "==> zip + latest.yml + manifest"
mkdir -p "$OUT"
rm -f "$OUT/Creatorize-Suite-$VER-win-x64.zip" "$OUT/latest.yml"
/usr/bin/python3 - "$WORK/wu" "$OUT/Creatorize-Suite-$VER-win-x64.zip" <<'PY'
import zipfile, os, sys
root, out = sys.argv[1], sys.argv[2]
with zipfile.ZipFile(out, "w", zipfile.ZIP_DEFLATED, compresslevel=6) as z:
    for dirpath, dirs, files in os.walk(root):
        for f in sorted(files):
            p = os.path.join(dirpath, f)
            z.write(p, os.path.relpath(p, root))
print("    zipped")
PY
node -e '
const { createHash } = require("node:crypto"), { readFileSync, writeFileSync } = require("node:fs");
const [out, ver] = process.argv.slice(1);
const exe = `${out}/Creatorize-Suite-Setup-${ver}.exe`;
const b64 = createHash("sha512").update(readFileSync(exe)).digest("base64");
writeFileSync(`${out}/latest.yml`, `version: ${ver}\nfiles:\n  - url: Creatorize-Suite-Setup-${ver}.exe\n    sha512: ${b64}\npath: Creatorize-Suite-Setup-${ver}.exe\nsha512: ${b64}\nreleaseDate: \x27${new Date().toISOString()}\x27\n`);
' "$OUT" "$VER"

echo
echo "done. upload alongside the mac assets of the same release:"
echo "  gh release upload v$VER -R $REPO_SLUG --clobber \\"
echo "    \"$OUT/Creatorize-Suite-$VER-win-x64.zip\" \"$SETUP\" \"$OUT/latest.yml\" \"$OUT/update-manifest.json\""
