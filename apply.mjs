#!/usr/bin/env node
// Creatorize Suite — no-Skool patch
//
// Takes an EXTRACTED app.asar directory and removes the Skool membership gate:
// the app opens straight to Home, always runs as Premium, never opens a Skool
// window, and does not update itself (an update would replace the patch).
//
//   npx @electron/asar extract "Creatorize Suite.app/Contents/Resources/app.asar" x
//   node apply.mjs x                  # updates stay ON (point app-update.yml at your own release repo)
//   node apply.mjs x --no-updates     # updates OFF, no launcher (fully offline-heirloom build)
//   npx @electron/asar pack x app.asar
//
// Idempotent: running it twice is a no-op. Tested on 0.20.1 and 0.27.0.
// Exits 1 if an anchor no longer matches (upstream moved) — read the anchor,
// adjust, re-run.

import { readFileSync, writeFileSync, readdirSync } from "node:fs";
import { join } from "node:path";

const dir = process.argv[2];
const KEEP_UPDATES = !process.argv.includes("--no-updates");
if (!dir) {
  console.error("usage: node apply.mjs <extracted-asar-dir>");
  process.exit(1);
}

const failures = [];
let applied = 0;

// one edit = { label, file, variants: [{ find (regex or string), replace }], patch (string to look for once applied) }
const MAIN = () => join(dir, "out/main/index.js");

const FAKE_CHECK =
  '  if (SKOOL_OFF) return { offline: false, online: true, signedIn: true, member: true, plan: "premium", name: "", at: (/* @__PURE__ */ new Date()).toISOString(), detail: ["Skool check: off (this build needs no sign-in)", "plan: premium (unlocked)"] };\n';

const edits = [
  {
    label: "switch",
    file: MAIN,
    patch: 'const SKOOL_OFF = process.env.CZ_SKOOL !== "1";',
    variants: [
      {
        find: 'const PARTITION = "persist:skool";',
        replace:
          'const PARTITION = "persist:skool";\n' +
          '// Creatorize no-Skool patch: the Skool membership gate is off, the plan is always Premium\n' +
          '// (set CZ_SKOOL=1 to get the original, login-gated behaviour back)\n' +
          'const SKOOL_OFF = process.env.CZ_SKOOL !== "1";',
      },
    ],
  },
  {
    label: "check: never touch Skool, always a premium member",
    file: MAIN,
    patch: "if (SKOOL_OFF) return { offline: false, online: true",
    variants: [
      // 0.27.x calls it doCheck$1 (the updater has its own doCheck); 0.20.x calls it doCheck
      { find: /^async function doCheck\$1\(\) \{\n/m, replace: (m) => m + FAKE_CHECK },
      {
        find: /^async function doCheck\(\) \{\n  const at = [^\n]*keep = presenceOn;\n/m,
        replace: (m) => m + FAKE_CHECK,
      },
    ],
  },
  {
    label: "gate: no window at all",
    file: MAIN,
    patch: "if (SKOOL_OFF) return Promise.resolve(true);",
    variants: [
      {
        find: /^function runSkoolGate\(\) \{\n/m,
        replace: () => "function runSkoolGate() {\n  if (SKOOL_OFF) return Promise.resolve(true);\n",
      },
    ],
  },
  ...(KEEP_UPDATES ? [] : [{
    label: "updates: off, so nothing replaces the patch",
    file: MAIN,
    patch: "if (SKOOL_OFF) return \"no-Skool build: updates are off",
    variants: [
      {
        find: /^function updatable\(\) \{\n/m,
        replace: () =>
          "function updatable() {\n  if (SKOOL_OFF) return \"no-Skool build: updates are off so nothing replaces the unlocked app (ask whoever gave you this copy for a new one)\";\n",
      },
    ],
  }]),
  ...(KEEP_UPDATES ? [] : [{
    label: "launcher: do not auto-install it (it repairs from stock releases)",
    file: MAIN,
    patch: 'if (SKOOL_OFF) return log2(',
    variants: [
      {
        find: /^async function ensureLauncher\([^)]*\) \{\n/m,
        replace: (m) =>
          m +
          '  if (SKOOL_OFF) return log2(fs.existsSync(LAUNCHER_EXE()) ? "launcher: installed, the no-Skool build keeps it" : "launcher: skipped (not needed by the no-Skool build)");\n',
      },
    ],
  }]),
  {
    label: 'start breadcrumb: $TMPDIR/creatorize-no-skool-start.log (triage for "it will not start")',
    file: MAIN,
    patch: "creatorize-no-skool-start.log",
    variants: [
      {
        find: 'const PRIMARY = electron.app.requestSingleInstanceLock();',
        replace:
          'try {\n' +
          '  require("node:fs").appendFileSync(require("node:path").join(require("node:os").tmpdir(), "creatorize-no-skool-start.log"), (/* @__PURE__ */ new Date()).toISOString() + " start " + electron.app.getVersion() + " " + JSON.stringify(process.argv.slice(1)) + "\\n");\n' +
          "} catch {\n" +
          "}\n" +
          "const PRIMARY = electron.app.requestSingleInstanceLock();",
      },
    ],
  },
];

function patchOne(edit, file) {
  let s = readFileSync(file, "utf8");
  if (s.includes(edit.patch)) {
    console.log(`  = already patched: ${edit.label}`);
    return;
  }
  for (const v of edit.variants) {
    const regex = v.find instanceof RegExp ? v.find : new RegExp(v.find.replace(/[.*+?^${}()|[\]\\]/g, "\\$&"));
    const m = s.match(regex);
    if (!m) continue;
    const replacement = typeof v.replace === "function" ? v.replace(m[0]) : v.replace;
    writeFileSync(file, s.replace(m[0], () => replacement));
    applied++;
    console.log(`  + ${edit.label}`);
    return;
  }
  console.error(`  ! anchor not found: ${edit.label}`);
  failures.push(edit.label);
}

console.log(`main process (${MAIN()})`);
for (const e of edits) patchOne(e, e.file());

const assets = join(dir, "out/renderer/assets");
// 0.20-0.27 keep one index-<hash>.js; 0.28+ split into many chunks, so search all of them
const renderer = readdirSync(assets).filter((n) => n.endsWith(".js"));
if (!renderer.length) {
  console.error("  ! no renderer chunk with the Skool copy found");
  failures.push("renderer chunks");
} else {
  const file = join(assets, renderer[0]);
  console.log(`renderer (${renderer.join(", ")})`);
  const rendererEdits = [
    {
      label: "settings: the Skool page is never opened",
      patch: "This copy of Creatorize has no Skool sign-in",
      variants: [
        {
          find: 'description: "Keep the Creatorize community on Skool open in the background so members see you online."',
          replace:
            'description: "This copy of Creatorize has no Skool sign-in (Premium unlocked, updates off). The Skool page is not opened at all, so this setting only matters if you put the original app back."',
        },
      ],
    },
    {
      label: "plan badge: say what this copy is",
      patch: "Premium unlocked: this is a no-Skool copy",
      variants: [
        {
          find: '"Premium plan: everything unlocked"',
          replace:
            '"Premium unlocked: this is a no-Skool copy, everything is on. Updates are off in this copy, so a new version has to be copied in by hand."',
        },
      ],
    },
    {
      label: "premium messages: they should not point at an upgrade",
      patch: "but this copy runs as Premium",
      variants: [
        {
          find: "const premiumMsg = (what) => `${what} is a Premium feature. Upgrade to Premium on Skool to unlock it.`;",
          replace:
            "const premiumMsg = (what) => `${what} is a Premium feature, but this copy runs as Premium: reload the app if you see this.`;",
        },
      ],
    },
  ];
  for (const e of rendererEdits) {
    const read = (n) => readFileSync(join(assets, n), "utf8");
    // already patched? find it by the marker, else by the anchor
    const hit =
      renderer.find((n) => read(n).includes(e.patch)) ??
      renderer.find((n) => read(n).includes(e.variants[0].find)) ??
      renderer[0];
    patchOne(e, join(assets, hit));
  }
}

console.log(`\n${applied} edit(s) applied, ${failures.length} anchor(s) missing`);
process.exit(failures.length ? 1 : 0);
