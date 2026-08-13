# The Lower Worlds: Awakening — Visual Styleguide

This document owns what the world and HUD must communicate. Exact renderer and
UI implementation contracts belong to [CONTRACT.md](CONTRACT.md), which names
their executable code owners. Stable source frames and capture commands live in
the [visual reference catalogue](../refs/style/README.md).

## 1. Thesis and reference hierarchy

> **PS2-era stylized realism: bright above, warm below.** Highbridge is a clear,
> optimistic frontier home under a generous sun. The Sunken Cut is dangerous,
> shadowed, and warmed by inhabited or functional light—never unreadable.

The target uses clean silhouettes, grounded materials, authored texture, and
restrained polygonal detail. It is neither toy-like cel art nor photorealism.
Every visual choice serves the Ocarina-like combat, targeting, item and puzzle
verbs, greed/extraction loop, and living-garrison fantasy in
[GDD.md](GDD.md).

References have narrow, non-interchangeable jobs:

- **Final Fantasy X:** [bright color optimism and clear natural exteriors](../refs/style/ffx_sunny_field_combat.png),
  plus [readable character/creature scale and color blocking](../refs/style/ffx_behemoth_scale.png).
- **Final Fantasy XII:** [lived-in architecture, civic density, vertical
  landmarks, and grounded weathered material culture](../refs/style/ffxii_archades_day.png).
- **Devil May Cry 1:** [dungeon massing and localized warm light](../refs/style/dmc1_warm_corridor.png),
  dark-but-readable danger, and clear combat floors.
- The [night-town frame](../refs/style/night_town_warm_lamps.png) is only a reference for inhabited warm lamps at
  night. It is not the exterior baseline.
- The [smoother DMC combat frame](../refs/style/dmc1_combat_chamber.png) is only a room-staging reference. It is not a
  rendering-technology target.

Do not average these into reference soup. Name the reference role being used
when reviewing a frame.

## 2. Zone contracts

### Sunny exteriors and the garrison

The exterior promise is a **bright, happy, clear sunny day**. Highbridge reads
as inhabited at first glance: working routes, active residents, useful
structures, visible improvements, and a strong skyline landmark. Sunlight
reveals the place rather than bleaching it. Exterior danger may interrupt a
welcoming home, but permanent gloom may not redefine it.

### Dark-but-warm dungeons

The dungeon promise is **dark but warm**. Torch, fire, and amber pools carve
readable rooms out of neutral or cool shadow. The player, enemy, combat floor,
door approaches, and at least one retreat exit remain readable. Darkness
creates danger and depth; it does not become horror-black concealment.

### Night

Night is a secondary state, not the exterior baseline. Warm lamps show
continued habitation and guide local movement while moonlight or neutral-cool
ambient light preserves massing and routes. Night must still look like the same
garrison, not a horror reskin.

## 3. Form, surface, and place

### Shape and architecture

- Establish large masses and clean silhouettes before secondary detail.
- Use restrained polygonal detail: enough planes to describe weight, wear, and
  identity, without PSX abstraction or modern scan-density noise.
- Keep combat floors open and visually calm. Put civic density and prop clusters
  at edges, bays, overlooks, and non-blocking work areas.
- Highbridge combines practical circulation, signs of labor, and vertical
  landmarks. It must feel lived in rather than arranged as an empty postcard.
- Dungeon architecture carries weight: strong wall masses, thresholds, stairs,
  supports, and localized chambers shaped around combat and puzzle verbs.

### Materials and texture

- Use authored diffuse texture with broad material groups and readable wear:
  stone, plaster, timber, leather, cloth, fired clay, weathered metal, bone.
- Use selective low-frequency material response to distinguish those groups.
  Broad highlights or roughness shifts may support form; they may not become a
  showcase of rendering effects.
- Keep texture frequency low enough that actors, doors, pickups, and mechanisms
  retain a clear contrast margin.
- Avoid physically based micro-noise, procedural grunge everywhere, uniform wet
  sheen, and the photogrammetry look.

### Actors and creatures

- Hero, residents, enemies, and creature tiers must separate first by silhouette
  and proportion, then by broad color blocking, then by surface detail.
- Faces, hands, held tools, weapons, and attack limbs receive the clearest local
  value organization because they carry intent.
- Weathering grounds a character in the world; it does not erase their color
  identity. Enemies may be strange, but their attack state must remain fair.

## 4. Gameplay readability

**Readability first, personality second, fidelity never.** Every element should
answer a gameplay question or support the place without competing with one.

- Standard enemies and their telegraphs must read at 8–10 m in normal play.
- Encounter staging preserves open dodge and targeting space, clear door
  approaches, and visible exits during retreat.
- Puzzle verbs read through shape, placement, material logic, repetition, and
  composition—not glow, outlines, floating labels, or paint spam.
- The garrison shows life and change through people doing things, functional
  landmarks, altered structures, supplies, damage, and repair.
- Loot earns salience through silhouette, placement, local contrast, motion, and
  the established signal registry. Do not recolor the whole world to make loot
  visible.
- Ambient props never obstruct targeting lanes, puzzle footprints, doors, or
  the decision to escape.

## 5. Color and light

The world palette is broad enough to portray sunlit nature, skin, cloth,
weathered construction, firelight, and distinct creatures. `Pal` is the UI and
gameplay signal registry, **not the world's pigment box**.

- Use a warm key against cool or neutral shadow. Preserve local material color
  instead of imposing a full-frame grade.
- Exterior sunlight supports bright midtones, clean sky separation, and
  welcoming natural color. Avoid sepia nostalgia and perpetual sunset.
- Dungeon warmth comes from one or two localized light pools per room, not from
  turning every surface orange.
- **GOLD** means authored value or progression signal. It is not ambient flame,
  brass, sunlight, masonry, or decorative trim.
- **CYAN** means directed pull or way-out signaling. It is not ambient water,
  sky, mineral stain, or decorative magic.
- Other reserved gameplay colors likewise stay out of ambient decoration.
  Shape, value, and material do the ordinary world-building work.
- Avoid crushed blacks and broad red, blue, orange, or teal grading. A shadow
  should keep enough color and value to describe the play space.

## 6. HUD and UI relationship

The HUD is terse, readable, and subordinate to the fight. It should clarify
state and action without competing with the target, telegraph, route, or room.
The current HUD structure remains authoritative until a separate redesign is
claimed and approved.

This art bible does not own exact coordinates, font sizes, meter geometry,
animation timings, or implementation values. Those belong in code, directors,
and [CONTRACT.md](CONTRACT.md). UI may use the `Pal` registry more densely than
the world because it communicates abstract state, but signal meanings remain
consistent.

## 7. Validation targets

These are acceptance targets for future slices and reviews. They are **not a
claim that the current build passes**.

1. At three fixed noon exterior poses, world-only mean luma is at least 70/255,
   fewer than 20% of pixels are below 32, and at least 10% are above 160.
2. Each exterior frame contains a route, inhabited midground, and skyline
   landmark; 4 of 5 cold viewers identify the destination within 3 seconds.
3. Fixed dungeon environment poses keep the combat floor and one exit readable,
   with no more than 35% of world pixels below luma 16. Player and enemy
   separation use the normal-gameplay actor proof in gate 5.
4. Each dungeon room uses one or two localized warm pools against neutral or
   cool shadow. A full-frame orange, red, or blue grade fails.
5. Four of five cold viewers identify the standard enemy and its attack state
   at 10 m without health bars.
6. Existing combat, traversal, puzzle, fishing, and garrison-route directors
   stay green. Visual dressing adds no collision and does not move authored
   ports, doors, interactions, actors, or room topology.
7. Four of five cold viewers find puzzle targets and exits within 5 seconds
   without bloom, outlines, or floating labels.
8. In HUD-off grayscale captures, 4 of 5 cold viewers distinguish the exterior,
   garrison, and dungeon by silhouette and massing alone.
9. Arrival, improved, and post-raid garrison frames use existing actors, state,
   and behavior to show inhabited activity, a functional landmark, and the
   relevant visible change. A visual card does not invent those states.

The fixed poses, commands, crop, and measurement tool are named in the
[reference catalogue](../refs/style/README.md); choose no replacement pose after
seeing a failure. Gates 1, 3, 4, 6 and the named environment/gameplay directors
block an autonomous slice. Gates requiring five cold viewers are later human-validation targets:
they do not block autonomous iteration, and they do block declaring the art
direction human-proven. A gate cannot replace looking at the frame.

## 8. Anti-targets

- **PSX simulation:** pixelation, ordered dither, framebuffer quantization,
  vertex wobble, affine texture warp, and hardware-artifact nostalgia.
- **Generic modern-indie PBR:** wet stone everywhere, heavy SSAO, bloom,
  volumetric rays, uniform microdetail, and photogrammetry-like surfaces.
- **Horror drift:** crushed blacks, blood or blue full-frame grades, corpse
  clutter, unreadable threat, and darkness used as content.
- **Cozy toy/cel/candy drift:** toy proportions, candy saturation, cel bands,
  outline rendering, and soft diorama staging that removes danger or weight.
- **Reference soup:** mixing all reference traits into every zone or using a
  narrow night/staging image as the global rendering target.
- **Play-space clutter:** prop scatter that blocks combat, targeting, retreat,
  puzzle use, or door approaches.
- **Readability crutches:** new emissive rims, universal glow, outlines, bloom,
  interaction paint, or extra labels applied instead of fixing composition.
  Existing prompts, world captions, loot names, and quest punctuation remain
  gameplay UI and are not removed by an area-art card.
- **Empty postcard exteriors:** attractive scenery without civic activity,
  destination clarity, functional landmarks, or visible change.

## 9. Migration and scope

The current build still contains a 480×270 quantized/internal presentation path
and PSX-era authoring constraints. They are **legacy migration debt**, not the
target and not evidence of conformance to this guide. New work must not cite
those constraints as art direction.

[NOW.md](NOW.md) authorizes a bounded visual-cohesion initiative across the
shared renderer, existing garrison, implemented dungeon, and existing outdoor
area. Work remains divided into separately claimed area slices with native-
resolution visual proof and independent criticism. The initiative changes
presentation, not gameplay scope; [SCOPE.md](SCOPE.md) still governs content.

## 10. Legacy citation index

Code comments written before issue #205 may cite the former guide. Interpret
those citations through this map until their owning visual slice touches them.

| Old citation | Current owner |
|---|---|
| §1 thesis/light | This guide §§1–2 and §5 |
| §2 palette | This guide §5; `scripts/ui/style.gd` for signal/UI tokens |
| §3 type | This guide §6; `scripts/ui/style.gd` and `scripts/ui/ui_theme.gd` |
| §4 renderer/PSX | [CONTRACT.md](CONTRACT.md) renderer target and `ScreenPresent` debt |
| §5 HUD | This guide §6; [CONTRACT.md](CONTRACT.md) and named UI code owners |
| §6 shapes/departures | This guide §§3–4 |
| §7 anti-slop | This guide §8 |
| §8+ deltas/history | Git history or the owning issue; not current canon |
