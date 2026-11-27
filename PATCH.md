# Creatorize Suite without the Skool login

What the gate was, what the patch does, and how to redo it on a new version.

Base: Creatorize Suite 0.27.x (arm64, macOS); the anchors are kept as variants for 0.20.x too. The app is an Electron bundle with
one big asar; the gate lives in `out/main/index.js`.

## What the original gate does

`whenReady()` in `out/main/index.js`:

1. `recentPass()` reads `skool-pass.json` from the app's userData (24 h, HMAC'd
   with the user name and the userData path). If a pass is there, `setPlan()` and
   skip the gate.
2. Otherwise `runSkoolGate()` opens a small window, `doCheck()` loads
   `https://www.skool.com/creatorize` in a hidden `persist:skool` session and
   reads `__NEXT_DATA__` out of the page: `self.member`, `self.member.role` and
   `metadata.mmbp.tier`. `planOf()` turns that into `premium`/`standard`.
3. No membership → the window stays and the app stays locked. `startSkoolRecheck()`
   repeats the check every 30–50 min and on focus, and re-locks on a miss.

`plan` is a bare module variable: `premium` unlocks the `CHANNEL_FEATURE`
gates, lifts the 12-exports-a-month cap (`STANDARD_EXPORTS`) and everything
behind `requireFeature()` (Routines, custom styles, characters, 4K, languages,
YouTube text/analytics, Ultraedit).

Note `let plan = process.env.CZ_PLAN === "standard" ? "standard" : "premium";`
already defaults to premium — the gate only ever takes it *away*.

## The patch

Nine anchored edits, `apply.mjs`, all idempotent (`CZ_SKOOL=1` gives the original
behaviour back at runtime):

| what | where |
|---|---|
| `SKOOL_OFF` switch | next to `PARTITION` |
| `doCheck()` returns a premium member, no window, no network | `doCheck` |
| `runSkoolGate()` resolves at once → no gate window ever | `runSkoolGate` |
| `updatable()` → off + no launcher (only with `--no-updates`) | `updatable`, `ensureLauncher` |
| start breadcrumb in `$TMPDIR/creatorize-no-skool-start.log` (triage) | before `PRIMARY` |
| settings text, plan badge, premium messages say what this copy is | renderer bundle |

Dead code stays below each anchor (the original body is still there) — that is
deliberate, it keeps the diff small and reviewable.

Deliberately **not** patched: `help:post` / `help:draft`, which fill a post into
the real Skool editor. Without a login that path fails softly: the report text is
put on the clipboard and the panel says so.

## Two profiles

- default (**updates on**): the build updates itself from this repo's releases — `app-update.yml`
  points here, `updatable()`/`ensureLauncher()` stay stock, the Creatorize Launcher stays (it is what
  swaps the installed app). This is what we share.
- `--no-updates`: `updatable()` returns a reason and the launcher is not auto-installed. For an
  air-gapped copy: nothing can ever replace the patch.

## Build

```
bash build.sh "/Volumes/Creatorize Suite/Creatorize Suite.app"   # not off the live app while it runs
```

extract asar → `node apply.mjs` → repack → rewrite `files.json` (`size`/`sha256`
of `app.asar`, the app and the installer both check sizes) → drop
`ElectronAsarIntegrity` from `Info.plist` (the hash would be stale, and dropping
it is safer than a wrong one) → `codesign --force --deep --sign -` ad hoc with
`entitlements.plist` (JIT / unsigned executable memory / library validation, as
the original) → `ditto` zip.

The release needs three assets: the zip (app + installer + README at the root), a dummy
`Creatorize-Suite-Setup-<v>.exe` (the Windows asset the gate insists on even on mac) and
`update-manifest.json` (version + size/sha256 of both). The updater refuses anything that does not
match the manifest, so a broken upload cannot brick anyone.

Ad hoc is enough; the original was ad hoc too. Nothing is notarised, so the
quarantine flag has to go — `Install Creatorize Suite.command` does that, and
README.txt tells the friend about the right-click → Open fallback.

## On a new upstream version

`apply.mjs` exits 1 and prints the anchor it could not find. Open
`out/main/index.js`, update that anchor (the function keeps the same shape),
re-run. Check especially: `planOf`, `READ$1`/`standGATE` copy, `PASS_MS`, and any
new `requireFeature()` label — new premium features need the plan forced, which
the patched `doCheck` does for all of them at once.
