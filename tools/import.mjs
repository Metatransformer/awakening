#!/usr/bin/env node
// Reimporter for `pnpm import`.
//
// Two things go wrong every time someone runs Godot's importer by hand, and
// this exists to make both of them impossible:
//
//   1. **`--import` rewrites `project.godot`.** It re-serialises the file, and
//      every `;` comment in it is DELETED -- the autoload load-order notes, the
//      reason the game boots into the garrison, the warning that `#` is a parse error
//      there. It has also silently dropped keys (`window/size/resizable`). The
//      file is restored byte-for-byte below, and anything the importer tried to
//      change is printed rather than swallowed, because a genuine settings
//      change made in the editor has to survive too.
//
//   2. **A cold class cache boots into a wall of nonsense.** `class_name` lives
//      in `.godot/global_script_class_cache.cfg`, which is a build artifact and
//      is not committed. Pull a branch that adds one -- `Prog`, `Stairs` -- and
//      the next boot is fifteen lines of `Identifier "Prog" not declared`,
//      `Cannot infer the type of "band"`, `does not inherit from 'Node'`, and
//      a nonexistent method on a class that is fine. None of that is the error;
//      all of it is the cache. Importing rebuilds it, which is the whole reason
//      to run this after every pull.
//
// It then BOOTS the game, because `--import` does not compile anything. A
// script with a syntax error in it imports perfectly happily, and Godot even
// registers its `class_name` -- that cache is harvested by a scan that never
// type-checks a line. So "it imported" is not a claim about the code at all.
//
// What the boot covers is the boot PATH: the autoloads and the main scene with
// everything it pulls in. That is precisely the failure this script exists for
// (a cold cache takes the boot path down), and it is not a whole-project
// compile: Godot never compiles a script nothing loads, so a broken file that
// only a lookdev scene references still slips through here. `--check-only
// --script` is not the missing piece -- autoloads are not registered in that
// mode, so it reports `Identifier not found: Bus` on healthy files (CLAUDE.md
// §3). The directors are what exercise the rest.

import { existsSync, readFileSync, writeFileSync } from 'node:fs'
import { spawnSync } from 'node:child_process'
import { dirname, join, relative } from 'node:path'
import { fileURLToPath } from 'node:url'

const ROOT = dirname(dirname(fileURLToPath(import.meta.url)))

const GODOTS = [
  '/opt/homebrew/bin/godot',
  '/usr/local/bin/godot',
  '/Applications/Godot.app/Contents/MacOS/Godot',
]

const PROJECT = join(ROOT, 'project.godot')
const CACHE = join(ROOT, '.godot', 'global_script_class_cache.cfg')

function findGodot() {
  if (process.env.GODOT && existsSync(process.env.GODOT)) return process.env.GODOT
  for (const g of GODOTS) if (existsSync(g)) return g
  const which = spawnSync('which', ['godot'], { encoding: 'utf8' })
  if (which.status === 0 && which.stdout.trim()) return which.stdout.trim()
  console.error(
    'Could not find Godot. Install it with `brew install --cask godot`,\n' +
      'or set GODOT=/path/to/Godot in your environment.',
  )
  process.exit(1)
}

const countClasses = () =>
  existsSync(CACHE) ? (readFileSync(CACHE, 'utf8').match(/"class"\s*:/g) || []).length : 0

const godot = findGodot()
const classesBefore = countClasses()
const before = readFileSync(PROJECT, 'utf8')

console.log('reimporting…')
// --headless is correct HERE and nowhere near a screenshot: importing needs no
// rendering device, and a shot taken without one comes out empty, silently.
const run = spawnSync(godot, ['--path', ROOT, '--headless', '--import'], {
  encoding: 'utf8',
  stdio: ['ignore', 'pipe', 'pipe'],
})

const failed = (run.stderr || '').split('\n').filter((l) => /SCRIPT ERROR|Parse Error|Failed to/.test(l))
if (run.status !== 0 || failed.length) {
  console.error(failed.length ? failed.join('\n') : run.stderr || 'the importer failed')
  process.exit(1)
}

// --- Put project.godot back -------------------------------------------------

const after = readFileSync(PROJECT, 'utf8')
if (after !== before) {
  const lost = before.split('\n').filter((l) => l.trim() && !after.includes(l.trim()))
  const gained = after.split('\n').filter((l) => l.trim() && !before.includes(l.trim()))
  writeFileSync(PROJECT, before)
  const comments = lost.filter((l) => l.trim().startsWith(';')).length
  const keys = lost.filter((l) => !l.trim().startsWith(';'))
  console.log(
    `project.godot restored (the importer dropped ${comments} comment line(s)` +
      `${keys.length ? ` and ${keys.length} key(s)` : ''})`,
  )
  // A key the importer ADDED is the one case worth a human: it may be a real
  // setting the editor wants, and it has just been thrown away.
  for (const g of gained.filter((l) => !l.trim().startsWith(';'))) {
    console.log(`  note: discarded a line the importer added -> ${g.trim()}`)
    console.log('        if you meant to change that, edit project.godot by hand.')
  }
}

// --- Does it actually start? ------------------------------------------------

if (!existsSync(CACHE)) {
  console.error(`no ${relative(ROOT, CACHE)} after import -- nothing will resolve a class_name`)
  process.exit(1)
}
const classes = countClasses()
const added = classes - classesBefore
console.log(`cache rebuilt: ${classes} classes${added > 0 ? ` (${added} new)` : ''}`)

console.log('booting…')
// --headless is right HERE and nowhere near a screenshot: this run only has to
// compile and start, and a SHOT taken without a rendering device comes out
// empty, silently (CLAUDE.md §3).
const boot = spawnSync(godot, ['--path', ROOT, '--headless', '--quit-after', '120'], {
  encoding: 'utf8',
  stdio: ['ignore', 'pipe', 'pipe'],
})
const bad = `${boot.stdout || ''}\n${boot.stderr || ''}`
  .split('\n')
  .filter((l) => /SCRIPT ERROR|Parse Error|Failed to load|does not inherit/.test(l))

if (bad.length) {
  console.error('\nit imported, but it does not start:\n')
  console.error(bad.slice(0, 12).join('\n'))
  if (bad.length > 12) console.error(`  …and ${bad.length - 12} more`)
  process.exit(1)
}

console.log('ok — imported, boots clean, project.godot intact')
