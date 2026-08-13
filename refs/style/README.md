# Visual reference catalogue

These are the owner-supplied frames governed by
[`docs/STYLEGUIDE.md`](../../docs/STYLEGUIDE.md). Each frame has one narrow job;
none is a complete target by itself.

| File | Use | Reject |
|---|---|---|
| [`ffx_sunny_field_combat.png`](ffx_sunny_field_combat.png) | Bright natural exterior, clean ground plane, readable party/monster color blocking | Turn-based staging, UI layout, literal tropical biome |
| [`ffx_behemoth_scale.png`](ffx_behemoth_scale.png) | Large-monster scale, silhouette separation, attack-limb readability | Industrial room theme, camera angle, turn-based presentation |
| [`ffxii_archades_day.png`](ffxii_archades_day.png) | Sunny civic density, vertical landmarks, grounded ornament, inhabited architecture | Exact city style, crowd density everywhere, brown full-frame grade |
| [`dmc1_warm_corridor.png`](dmc1_warm_corridor.png) | Warm localized dungeon light, strong thresholds, readable route through darkness | Crushed blacks, red full-frame grade, horror clutter |
| [`dmc1_combat_chamber.png`](dmc1_combat_chamber.png) | Clear central combat floor, perimeter detail, doorway and enemy separation | Rendering smoothness, gunplay framing, gothic props in every room |
| [`night_town_warm_lamps.png`](night_town_warm_lamps.png) | Inhabited warm lamps and layered night depth only | Exterior baseline, blue night grade, empty medieval-street content |

Reviewers name the file and the allowed trait they are comparing. “Looks like
the references” is not a verdict.

## Canonical proof suite

All captures are 1280×720 with the HUD hidden by the director.

```bash
timeout 400 tools/quiet.sh --path . -s tools/shoot.gd -- --scene=res://scenes/rooms/garrison.tscn --director=res://tools/directors/garrison_layout.gd --out=/tmp/style/garrison/x.png --size=1280x720 --warmup=60
timeout 400 tools/quiet.sh --path . -s tools/shoot.gd -- --scene=res://scenes/rooms/garrison_outskirts.tscn --director=res://tools/directors/garrison_outskirts.gd --out=/tmp/style/outskirts/x.png --size=1280x720 --warmup=60
timeout 400 tools/quiet.sh --path . -s tools/shoot.gd -- --scene=res://scenes/rooms/dungeon.tscn --director=res://tools/directors/floor_lookdev.gd --out=/tmp/style/dungeon/x.png --size=1280x720 --warmup=60
```

Blocking exterior luma poses are `layout_01_elder_at_entrance.png`,
`layout_03_craft_buildings.png`, and `outskirts_01_central_clearing.png`.
Blocking dungeon poses are all five `floor_look_*.png` frames. Measure the full
HUD-free RGB image with [`tools/frame_luma.py`](../../tools/frame_luma.py).

```bash
python3 tools/frame_luma.py \
  /tmp/style/garrison/layout_01_elder_at_entrance.png \
  /tmp/style/garrison/layout_03_craft_buildings.png \
  /tmp/style/outskirts/outskirts_01_central_clearing.png \
  --dark=32 --bright=160 --min-mean=70 --max-dark=20 --min-bright=10

python3 tools/frame_luma.py /tmp/style/dungeon/floor_look_*.png \
  --dark=16 --bright=255 --min-mean=0 --max-dark=35 --min-bright=0
```
