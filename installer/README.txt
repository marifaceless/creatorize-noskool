Creatorize Suite 0.27.0 — copy without the Skool login
======================================================

What this is
------------
Creatorize Suite normally asks you to sign in with a Skool account and checks
that you are a member of the Creatorize community on every start. This copy has
that check taken out: it opens straight to Home, always runs as Premium
(Routines, custom styles, 4K, other languages, unlimited exports — everything),
and never opens a Skool window.

Requirements
------------
- macOS 12 (Monterey) or newer, Apple Silicon (M1 and newer).
  Intel Macs: this build does not run there.
- Your own Claude account. The Suite makes the videos with Claude Code, which
  runs on your login (a Claude Pro/Max plan or your own API key). That sign-in
  is inside the app and has nothing to do with Skool: Home > Connect Claude.
- internet

Install
-------
1. Unzip the download (double-click the .zip).
2. Double-click "Install Creatorize Suite.command". It asks for your Mac
   password if it has to write into Applications.
3. It copies Creatorize Suite into Applications and opens it. Follow
   "Getting started" on Home to connect Claude and let it install the tools
   (git, ffmpeg, Python).

If macOS says "Apple could not verify Creatorize Suite" on the first start:
click Done (not Move to Trash), open System Settings > Privacy & Security,
scroll down, "Open Anyway", enter your Mac password. Once only.

You can also skip the installer and drag "Creatorize Suite.app" into
Applications yourself — then right-click it > Open the first time.

Good to know
------------
- Projects live in ~/Documents/Creatorize Suite, exactly like the normal app.
  If you switch back to the normal app your projects are still there.
- Updates are switched off in this copy, so nothing silently replaces the
  unlocked app. A newer version has to be installed the same way as this one
  (ask whoever gave you this file).
- The official Creatorize Launcher is removed by the installer: it would
  re-download the login-gated version.
- Everything is local apart from Claude. Nothing is phoned home, no account,
  no licence server, no keys inside the app.
- Without a Skool login the Help > Report a problem panel cannot post to the
  community. It still writes the report and puts it on your clipboard so you
  can paste it there by hand.
- The app description, help text and Premium hints here and there still
  mention Skool — that is only wording, nothing is enforced.

Uninstall
---------
Drag /Applications/Creatorize Suite.app to the Bin. Your projects stay in
~/Documents/Creatorize Suite, settings in
~/Library/Application Support/Creatorize Suite (delete that folder too for a
clean slate).

Checksums
---------
See CHECKSUMS.txt (shasum -a 256). Verify before installing if you got this
from someone you don't know well.
