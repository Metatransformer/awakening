#!/usr/bin/env node
// Launcher for `pnpm game`.
//
// The build is in flight, so the "most playable" scene changes from hour to
// hour: the hero + camera scene appears partway through, the real dungeon
// later. Rather than hardcode one and break, pick the best scene that actually
// exists right now, and tell the player what they got.

import { existsSync } from 'node:fs'
import { spawn, spawnSync } from 'node:child_process'
import { dirname, join } from 'node:path'
import { fileURLToPath } from 'node:url'

const ROOT = dirname(dirname(fileURLToPath(import.meta.url)))

// Best first. The first one that exists on disk wins.
const CANDIDATES = [
  ['scenes/rooms/dungeon.tscn', 'the full dungeon'],
  ['scenes/rooms/training.tscn', 'the training area — hero, camera, and practice posts to hit'],
  ['scenes/rooms/playtest.tscn', 'the playable slice — hero + camera in the proving ground'],
  ['scenes/rooms/proving_ground.tscn', 'the proving-ground room (no hero yet — still building)'],
  ['scenes/rooms/_lookdev.tscn', 'the bare lookdev box (nothing built yet)'],
]

const GODOTS = [
  '/opt/homebrew/bin/godot',
  '/usr/local/bin/godot',
  '/Applications/Godot.app/Contents/MacOS/Godot',
]

const CONTROLS = `
  move          W A S D  /  left stick        look        mouse  /  right stick
  Z-TARGET      Q  /  right mouse  /  LT      sword       J  /  left mouse  /  X
  shield        K  /  Ctrl  /  RT             roll        Space  /  A
  interact      E  /  F                       items       1  2  3   (C-buttons)
  first person  R                             pause/map   Esc  /  Tab      reload  F5
`

function findGodot() {
  for (const g of GODOTS) if (existsSync(g)) return g
  const which = spawnSync('which', ['godot'], { encoding: 'utf8' })
  if (which.status === 0 && which.stdout.trim()) return which.stdout.trim()
  console.error(
    'Could not find Godot. Install it with `brew install --cask godot`,\n' +
      'or set GODOT=/path/to/Godot in your environment.'
  )
  process.exit(1)
}

function pickScene() {
  const explicit = process.argv.slice(2).find((a) => a.endsWith('.tscn'))
  if (explicit) {
    const rel = explicit.replace(/^res:\/\//, '')
    if (!existsSync(join(ROOT, rel))) {
      console.error(`No such scene: ${rel}`)
      process.exit(1)
    }
    return [rel, 'scene you asked for']
  }
  for (const [rel, label] of CANDIDATES) {
    if (existsSync(join(ROOT, rel))) return [rel, label]
  }
  console.error('No scenes found at all. Has anything been built yet?')
  process.exit(1)
}

// There used to be a syncMainScene() here that rewrote run/main_scene in
// project.godot to whatever room this launcher picked, to keep the editor's F5
// in step with `pnpm game`. It is gone, and it must not come back.
//
// dungeon.tscn is first in CANDIDATES, so every single run of this script left
// the project pointed underground -- and project.godot's own comment records
// that line drifting to dungeon.tscn three times, the third of which SHIPPED.
// This script was the mechanism the whole time. It bought a convenience for the
// editor by mutating the one setting that decides what a player boots into.
//
// Nothing is lost: the scene is passed to Godot on the command line below, so
// `pnpm game` plays the right room regardless of what that line says. If you
// want the editor's F5 to match, open the scene and set it there yourself.
// `pnpm deploy` refuses to build unless the line reads garrison.tscn.

const godot = process.env.GODOT || findGodot()
const [scene, label] = pickScene()

console.log(`\n  The Lower Worlds: Awakening`)
console.log(`  playing ${scene}`)
console.log(`  ${label}\n`)
console.log(CONTROLS)

const extra = process.argv.slice(2).filter((a) => !a.endsWith('.tscn'))
const child = spawn(godot, ['--path', ROOT, `res://${scene}`, ...extra], {
  stdio: 'inherit',
})
child.on('exit', (code) => process.exit(code ?? 0))
