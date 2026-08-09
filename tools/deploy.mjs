#!/usr/bin/env node
// Launcher for `pnpm deploy`: export the mac and windows releases and push both
// to itch.io.
//
//   pnpm deploy                  export both, push both
//   pnpm deploy --dry-run        export both, push nothing (use this first)
//   pnpm deploy --only=mac       just the one platform (mac | windows)
//   pnpm deploy --version=0.2.0  override the version stamped on the upload
//
// Two things about this file are load-bearing and not obvious:
//
// 1. It does NOT run `godot --import` first. The export does its own resource
//    scan anyway, and a standalone `--import` re-serialises project.godot --
//    which DELETES every `;` comment in it, including the autoload load-order
//    notes and the parse-error warning in [input]. See CLAUDE.md §3.
//
// 2. It refuses to build unless run/main_scene is the shipping scene. `pnpm
//    play` rewrites that line to whatever room it launched (tools/play.mjs,
//    syncMainScene) and dungeon.tscn is first in its candidate list, so any
//    playtest leaves the project pointed underground. Shipping that skips the
//    descent gate -- the bug project.godot says has already escaped three
//    times. A deploy is the one command where that must not be silent.

import { existsSync, readFileSync, rmSync, mkdirSync, statSync } from 'node:fs'
import { spawnSync } from 'node:child_process'
import { dirname, join } from 'node:path'
import { fileURLToPath } from 'node:url'

const ROOT = dirname(dirname(fileURLToPath(import.meta.url)))

const ITCH_TARGET = 'metatransformer/the-lower-worlds-awakening'
const ITCH_URL = 'https://metatransformer.itch.io/the-lower-worlds-awakening'

// The scene a player must boot into. See note 2 above.
const SHIP_SCENE = 'res://scenes/rooms/town.tscn'

// The .app / .exe basename. No colon: macOS treats it as a path separator and
// Godot rewrites it to "-", which is why the bundle on disk is "The Lower
// Worlds- Awakening.app". The name players actually see is CFBundleDisplayName,
// which comes from application/config/name and keeps the colon.
const PRODUCT = 'The Lower Worlds Awakening'

const TARGETS = {
  mac: {
    preset: 'macOS',
    channel: 'mac',
    dir: 'build/macos',
    // Export straight to a .zip and push the .zip rather than the .app tree:
    // the archive carries the unix mode bits, so the executable inside the
    // bundle arrives with +x still set. Pushed as a loose directory it does
    // not, and the game will not launch on the player's machine.
    out: `build/macos/${PRODUCT}.zip`,
    push: `build/macos/${PRODUCT}.zip`,
  },
  windows: {
    preset: 'Windows Desktop',
    channel: 'windows',
    dir: 'build/windows',
    out: `build/windows/${PRODUCT}.exe`,
    // The whole folder: the preset keeps the .pck beside the .exe.
    push: 'build/windows',
  },
}

const GODOTS = [
  '/opt/homebrew/bin/godot',
  '/usr/local/bin/godot',
  '/Applications/Godot.app/Contents/MacOS/Godot',
]

const argv = process.argv.slice(2)
const has = (f) => argv.includes(f)
const valueOf = (f) => {
  const hit = argv.find((a) => a.startsWith(`${f}=`))
  return hit ? hit.slice(f.length + 1) : null
}

const dryRun = has('--dry-run')
const allowAnyScene = has('--allow-any-scene')

function die(msg) {
  console.error(`\n  deploy: ${msg}\n`)
  process.exit(1)
}

function findBin(name, candidates = []) {
  for (const c of candidates) if (existsSync(c)) return c
  const which = spawnSync('which', [name], { encoding: 'utf8' })
  if (which.status === 0 && which.stdout.trim()) return which.stdout.trim()
  return null
}

function run(bin, args, label) {
  const res = spawnSync(bin, args, { cwd: ROOT, stdio: 'inherit' })
  if (res.error) die(`${label} could not start: ${res.error.message}`)
  if (res.status !== 0) die(`${label} failed (exit ${res.status})`)
}

function humanSize(bytes) {
  const mb = bytes / 1024 / 1024
  return mb >= 1024 ? `${(mb / 1024).toFixed(2)} GB` : `${mb.toFixed(1)} MB`
}

// --- which platforms -------------------------------------------------------

const only = valueOf('--only')
const platforms = only ? only.split(',').map((s) => s.trim()) : Object.keys(TARGETS)
for (const p of platforms) {
  if (!TARGETS[p]) die(`unknown platform "${p}". Use mac, windows, or both.`)
}

// --- version ---------------------------------------------------------------

// itch shows this string next to the build and uses it to order them, so it has
// to move every push. The git sha is what makes it unique between two deploys
// that both happened at version 0.1.0.
function buildVersion() {
  const override = valueOf('--version')
  if (override) return override

  const pkg = JSON.parse(readFileSync(join(ROOT, 'package.json'), 'utf8'))
  const git = spawnSync('git', ['rev-parse', '--short', 'HEAD'], {
    cwd: ROOT,
    encoding: 'utf8',
  })
  const sha = git.status === 0 ? git.stdout.trim() : null

  const dirty = spawnSync('git', ['status', '--porcelain'], {
    cwd: ROOT,
    encoding: 'utf8',
  })
  const isDirty = dirty.status === 0 && dirty.stdout.trim().length > 0

  if (!sha) return pkg.version
  return `${pkg.version}+${sha}${isDirty ? '.dirty' : ''}`
}

// --- preflight -------------------------------------------------------------

const godot = process.env.GODOT || findBin('godot', GODOTS)
if (!godot) {
  die('could not find Godot. `brew install --cask godot`, or set GODOT=/path/to/Godot.')
}

const butler = process.env.BUTLER || findBin('butler', ['/opt/homebrew/bin/butler'])
if (!butler && !dryRun) {
  die(
    'could not find butler, the itch.io uploader.\n' +
      '  Install it with `brew install butler`, then `butler login` once.\n' +
      '  Re-run with --dry-run to build without uploading.'
  )
}

if (!existsSync(join(ROOT, 'export_presets.cfg'))) {
  die('export_presets.cfg is missing. It is committed -- did something delete it?')
}

// The line that `pnpm play` moves. Note 2 at the top of this file.
{
  const src = readFileSync(join(ROOT, 'project.godot'), 'utf8')
  const found = /run\/main_scene="([^"]*)"/.exec(src)?.[1] ?? '(unset)'
  if (found !== SHIP_SCENE) {
    if (!allowAnyScene) {
      die(
        `run/main_scene is ${found}, not ${SHIP_SCENE}.\n\n` +
          '  Something -- almost certainly `pnpm play`, which rewrites that line to\n' +
          '  whatever room it launched -- has left the project pointed at another\n' +
          '  scene. Shipping it means players boot straight into a run they never\n' +
          '  started, and never meet the descent gate until after their first death.\n\n' +
          `  Fix it:  set run/main_scene="${SHIP_SCENE}" in project.godot\n` +
          '  Or, if you really mean to ship this scene:  pnpm deploy --allow-any-scene'
      )
    }
    console.log(`  ! shipping main_scene=${found} (--allow-any-scene)\n`)
  }
}

// `butler status` on a project you can reach prints its channels; on a bad key
// or a typo'd target it fails. Catching that here beats discovering it after a
// twenty-minute export.
if (!dryRun) {
  const st = spawnSync(butler, ['status', ITCH_TARGET], { encoding: 'utf8' })
  if (st.status !== 0) {
    die(
      `butler cannot reach ${ITCH_TARGET}:\n\n${(st.stderr || st.stdout || '').trim()}\n\n` +
        '  If it is an auth error, run `butler login` once and try again.'
    )
  }
}

// --- go --------------------------------------------------------------------

const version = buildVersion()

console.log(`\n  The Lower Worlds: Awakening`)
console.log(`  deploying ${platforms.join(' + ')} as ${version}`)
console.log(`  to ${ITCH_URL}`)
if (dryRun) console.log(`  DRY RUN -- exports only, nothing is uploaded`)
console.log()

for (const p of platforms) {
  const t = TARGETS[p]

  // Wipe the output dir first. butler uploads whatever is in the folder, so a
  // stale .pck from a renamed build would ride along into the release.
  rmSync(join(ROOT, t.dir), { recursive: true, force: true })
  mkdirSync(join(ROOT, t.dir), { recursive: true })

  console.log(`  --- exporting ${p} (${t.preset}) ---`)
  // --headless is correct here and only here: an export needs no rendering
  // device. Never pass it to a screenshot run -- see CLAUDE.md §2.
  run(godot, ['--headless', '--export-release', t.preset, t.out], `${p} export`)

  const built = join(ROOT, t.out)
  if (!existsSync(built)) die(`${p} export reported success but produced no ${t.out}`)
  console.log(`  ${t.out}  ${humanSize(statSync(built).size)}\n`)
}

if (dryRun) {
  console.log(`  built, not uploaded. Drop --dry-run to push.\n`)
  process.exit(0)
}

for (const p of platforms) {
  const t = TARGETS[p]
  console.log(`  --- pushing ${p} -> ${ITCH_TARGET}:${t.channel} ---`)
  run(
    butler,
    ['push', t.push, `${ITCH_TARGET}:${t.channel}`, '--userversion', version],
    `${p} upload`
  )
  console.log()
}

console.log(`  done. ${version} is live at ${ITCH_URL}`)
console.log(`  builds process for a minute or two before the page updates.\n`)
