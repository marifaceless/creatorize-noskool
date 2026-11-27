# Creatorize Suite without the Skool login (macOS, Apple Silicon)

A patched build of [Creatorize Suite](https://www.skool.com/creatorize) that starts straight to Home
with Premium unlocked, and never asks for a Skool account.

| platform | install | updates |
|---|---|---|
| macOS, Apple Silicon | one-liner below, or the zip + `Install Creatorize Suite.command` | automatic |
| macOS, Intel | same, it picks the x64 build | automatic |
| Windows 10/11 x64 | `Creatorize-Suite-Setup-<v>.exe` from the release (unsigned: More info → Run anyway) | automatic |
| Linux | — | the app itself has no Linux build |

- The **app** makes the videos with your own Claude Code login. That sign-in stays: Home → Connect Claude.
- Everything Premium is on: Routines, custom styles, characters designed with Claude, 4K, other languages, unlimited exports.
- No Skool window, no membership check, no licence server.
- Updates: this build checks **this repo's releases** and installs a new version itself. See *Updates* below.
- Personal share build, not affiliated with Creatorize. Not signed with an Apple Developer ID.

## Install (macOS)

One line in Terminal:

```bash
curl -fsSL https://raw.githubusercontent.com/marifaceless/creatorize-noskool/main/get.sh | bash
```

It downloads the newest release, checks it against the release's sha256, and installs it
(Mac password if it asks). Or by hand: Assets → `Creatorize-Suite-…-mac-arm64.zip` → unzip →
`Install Creatorize Suite.command` → if macOS complains once: Done → Privacy & Security → Open Anyway.

Requirements: macOS 12+ or Windows 10/11, internet, your own Claude account. Windows needs nothing
else; on macOS you also need git/ffmpeg/Python, which the app installs and checks for.

## Updates

Automatic and hands-off, like any normal app: the app checks here every 6 hours, downloads a new version,
sha256-verifies it against `update-manifest.json`, runs it in a sandbox first, then hands it to the
Creatorize Launcher to swap in. `Settings → Updates` has *Check now*.

This repo only contains **our** patched builds, so an upstream release arrives here after it has been
rebuilt from the official `.dmg` (see `PATCH.md`, `build.sh`). `versions.json` at the repo root is the
kill switch: `{"0.28.0": "why"}` makes clients skip that version.

## What is patched

Nine anchored edits, all idempotent and reversible at runtime (`CZ_SKOOL=1`): the membership check
returns a premium member without touching the network, the gate window never opens, plan stays
`premium`, the update source points here. Details, anchors and the rebuild runbook: `PATCH.md`.

Not patched: **Help → Report a problem** still fills the post into the real Skool editor, so without a
login it leaves the report on your clipboard instead.

## Credit

App © Creatorize (therussellchris). This repo only carries patched copies of the official release.
