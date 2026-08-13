# Character asset production

This is the canonical reusable process for authored `NpcBody` characters. The
runtime contract is owned by [CONTRACT.md](CONTRACT.md) §1c; this document owns
how a new compatible asset is produced and proved.

## Stable names

Use a person's lowercase name for concept art and the lowercase `NpcBody.PEOPLE`
key for runtime artifacts. For Tamsin, `<person>` is `tamsin` and `<model>` is
`builder`.

| Artifact | Stable path |
|---|---|
| Rendered style reference | `/tmp/character_reference.png` |
| Chroma working image | `/tmp/<person>_tpose_chroma.png` |
| Transparent concept/mockup | `assets/characters/npc/concepts/<person>_tpose.png` |
| Animated runtime figure | `assets/characters/npc/<model>.fbx` |
| Runtime textures | `assets/characters/npc/<model>_0.png` and any additional numbered maps |
| Preserved in-place idle source | `assets/characters/npc/source/<model>_idle.fbx` |
| Tripo provenance | `assets/characters/npc/source/<model>_tripo_tasks.json` |

`assets/characters/npc/source/.gdignore` must remain present. The source folder
retains the idle export and every Tripo task ID without asking Godot to import a
second copy of the character.

## Process

1. Choose another existing authored character in `NpcBody.PEOPLE`. Render that
   shipped model through `tools/scenes/_character_reference.tscn`; do not use
   screenshots from another game, loose mood art, or a text-only style guess.
   For Tamsin, the exact reference command is:

   ```bash
   timeout 400 tools/quiet.sh --path . res://tools/scenes/_character_reference.tscn -- \
     --who=lanternkeeper --out=/tmp/character_reference.png
   ```

   A future character may replace only the `--who` value with another shipped
   `NpcBody` model. Pass the resulting `/tmp/character_reference.png` to ChatGPT
   Image as an explicit image reference. All new concept and mockup art must use
   another shipped character model this way; never ask the image model to guess
   the project's style from text alone.

2. In ChatGPT Image, generate exactly one full-body, straight-on front T-pose on
   a flat chroma background. Keep the whole silhouette in frame and do not make
   a turnaround, alternate pose, prop sheet, or environmental scene. Save the
   generated working image as `/tmp/<person>_tpose_chroma.png`, remove the chroma
   to transparent alpha, and save the clean mockup at
   `assets/characters/npc/concepts/<person>_tpose.png`.

3. Send that alpha mockup, not the chroma image or a text prompt alone, to Tripo
   image-to-model. Record the image-to-model task ID and model version in
   `<model>_tripo_tasks.json`.

4. Run Tripo's rig check on the image-to-model result. Continue only when it is
   riggable as a biped, and record the rig-check task ID and result.

5. Rig it as a Tripo biped with model version `v1.0-20240301`, spec `tripo`, and
   FBX output. This version is pinned because it is the compatible input to the
   idle stage and preserves the 41-bone named core understood by `NpcBody`;
   newer v2 creates a different hierarchy. Record the rig task ID and version.

6. From that compatible rig, generate `preset:idle` in place with geometry
   included and export FBX. Record the animation task ID, preset, `in_place`
   value, and format. Use that geometry-bearing animated export as the runtime
   `assets/characters/npc/<model>.fbx`, and retain the same output as
   `.gdignore`d source `<model>_idle.fbx`. Point the body's `authored_idle` and
   role `idle` at its imported `preset_idle` clip. The animation export may add
   leaf end-bones or use a different skeleton frame; that is safe because its
   own animation plays on its own rig and is not fed through the legacy shared
   retarget map.

7. Put the runtime FBX and its external numbered textures at their stable paths,
   then run `pnpm run import`. Do not use raw `godot --import`; the repository
   wrapper preserves `project.godot` and proves a clean boot.

8. Add exactly one `NpcBody.PEOPLE` row with the runtime FBX filename and measured
   height in metres. Use the raw front/side/back proof to measure the exported
   facing; omit `yaw` when it is already +Z, or record the measured correction
   that sends its front to +Z. Point the role's `Npc.LOOKS` row at that `model`;
   authored figures do not receive a `race`, `suit`, or `tint`.

9. Run the raw import, animated lookdev, real garrison, and quest-marker proofs:

   ```bash
   timeout 400 tools/quiet.sh --path . -s tools/shoot.gd -- \
     --scene=res://scenes/rooms/_lookdev.tscn \
     --director=res://tools/directors/npc_raw.gd --out=/tmp/npc/x.png

   timeout 400 tools/quiet.sh --path . -s tools/shoot.gd -- \
     --scene=res://scenes/rooms/_lookdev.tscn \
     --director=res://tools/directors/npc_lookdev.gd --out=/tmp/npc/x.png

   timeout 400 tools/quiet.sh --path . -s tools/shoot.gd -- \
     --scene=res://scenes/rooms/garrison.tscn \
     --director=res://tools/directors/garrison_raid.gd \
     --out=/tmp/garrison-raid/raid.png --warmup=90

   timeout 240 tools/quiet.sh --path . -s tools/shoot.gd -- \
     --scene=res://scenes/rooms/garrison.tscn \
     --director=res://tools/directors/quest_journal.gd \
     --out=/tmp/quest-journal/quest.png --size=1280x720 --warmup=90
   ```

   Inspect every produced frame. Logs establish that the rig, clips, raid role,
   and quest markers exist; the frames establish the raw art axis, that the
   integrated figure faces forward, is framed, holds the intended idle, and
   reads correctly in the real yard.
