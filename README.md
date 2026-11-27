# Creatorize Suite without the Skool login (macOS, Apple Silicon)

A patched build of [Creatorize Suite](https://www.skool.com/creatorize) that starts straight to Home
with Premium unlocked, and never asks for a Skool account.

- The **app** makes the videos with your own Claude Code login. That sign-in stays: Home → Connect Claude.
- Everything Premium is on: Routines, custom styles, characters designed with Claude, 4K, other languages, unlimited exports.
- No Skool window, no membership check, no licence server.
- Updates: this build checks **this repo's releases** and installs a new version itself. See *Updates* below.
- Personal share build, not affiliated with Creatorize. Not signed with an Apple Developer ID.

## Install

1. Download the latest release: **Creatorize-Suite-…-mac-arm64.zip** (Assets).
2. Unzip, double-click `Install Creatorize Suite.command` (Terminal opens; Mac password if it asks).
3. If macOS says the app cannot be verified, once: Done → System Settings → Privacy & Security → Open Anyway.

`installer/` in this repo holds copies of the same installer and a longer README if a release asset is missing.

Requirements: macOS 12+, Apple Silicon, internet, your own Claude account.

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
