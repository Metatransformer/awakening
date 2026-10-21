# The Lower Worlds: Awakening

A third-person dungeon-adventure prototype built with Godot 4.7 and typed
GDScript. Prepare at Highbridge, explore the Sunken Cut, bring discoveries home,
and decide when to return to defend the garrison.

**Status:** playable pre-production prototype. The implemented raid loop,
Field Notes progression, and boss dynamics still have pending human playtest
gates. See [the current scope and proof questions](docs/NOW.md).

- [Download for macOS and Windows on itch.io](https://metatransformer.itch.io/the-lower-worlds-awakening)
- [Illustrated project article](https://metatransformer.com/blog/the-lower-worlds-awakening)
- [Design documentation](docs/README.md)

## Run from source

Install Godot 4.7 (this release was built with 4.7.2), Node.js 18 or later,
and pnpm. The project uses the Forward+ renderer and requires compatible
graphics hardware. Open `project.godot` in Godot, or run:

```sh
pnpm run import
pnpm run game
```

The shipping entry point is `scenes/ui/title/title_screen.tscn`. The development
launcher can select other scenes; restore that entry point before exporting.
Read [CLAUDE.md](CLAUDE.md) before changing the project.

## Export

Install matching Godot export templates. The committed presets build a universal
macOS app and a Windows x86-64 executable with its PCK:

```sh
pnpm run deploy --dry-run
```

Outputs are placed under `build/`. Publishing without `--dry-run` also requires
Butler authenticated to the project's itch.io account. The macOS build is ad-hoc
signed, not notarized; macOS may require explicit user approval to open it.

## Verification

```sh
pnpm run import
timeout 400 tools/quiet.sh --path . -s tools/shoot.gd -- \
  --scene=res://scenes/rooms/garrison.tscn \
  --director=res://tools/directors/mvp_loop.gd \
  --out=/tmp/awakening-mvp/x.png --warmup=60 --run-seed=4242
```

The director exercises service purchases, descent, combat, extraction, and
return. Inspect the resulting images as well as its exit status. Automated
checks do not establish whether the game is enjoyable.

## Assets and references

This repository includes original project work and third-party assets and
reference material. Existing asset license notices remain in their directories,
including Kenney and Kyle Fuji CC0 packs. Reference screenshots under `refs/`
are study material, not original game artwork. Public repository access does
not grant a blanket license to every included asset; consult the relevant
notices before reuse.
