# Valenfeld Cistern Visual Kit Sources

This folder packages the licensed floor-1 cistern visual kit from the local
Valenfeld source tree. Source assets were copied without Godot `.import`
sidecars, and the Retro Fantasy Kit models retain their original relative
`Textures/` directory.

## Licences

- **Kenney Retro Fantasy Kit 2.0 — CC0 1.0.** The local source licence at
  `/Users/nickbryant/valenfeld/assets/models/retrokit/License.txt` is copied as
  `LICENSE-KENNEY.txt` and identifies the kit as Creative Commons Zero (CC0).
- **Kyle Fuji Rock Pack — CC0 1.0.** The local source licence at
  `/Users/nickbryant/valenfeld/assets/models/rockpack/KyleFuji_license.txt` is
  copied as `LICENSE-KYLE-FUJI.txt` and identifies all pack assets as CC0 1.0.

## Source manifest

| Packaged path | Upstream source path | Treatment |
| --- | --- | --- |
| `pulley.glb` | `/Users/nickbryant/valenfeld/assets/models/retrokit/pulley.glb` | Copied unchanged |
| `pulley-crate.glb` | `/Users/nickbryant/valenfeld/assets/models/retrokit/pulley-crate.glb` | Copied unchanged |
| `column-damaged.glb` | `/Users/nickbryant/valenfeld/assets/models/retrokit/column-damaged.glb` | Copied unchanged |
| `bricks.glb` | `/Users/nickbryant/valenfeld/assets/models/retrokit/bricks.glb` | Copied unchanged |
| `detail-crate-ropes.glb` | `/Users/nickbryant/valenfeld/assets/models/retrokit/detail-crate-ropes.glb` | Copied unchanged |
| `water.glb` | `/Users/nickbryant/valenfeld/assets/models/retrokit/water.glb` | Copied unchanged |
| `LICENSE-KENNEY.txt` | `/Users/nickbryant/valenfeld/assets/models/retrokit/License.txt` | Copied unchanged and renamed |
| `Textures/barrel.png` | `/Users/nickbryant/valenfeld/assets/models/retrokit/Textures/barrel.png` | 64×64 copy, palette-quantized in place to at most 16 colours with alpha preserved |
| `Textures/cobblestone.png` | `/Users/nickbryant/valenfeld/assets/models/retrokit/Textures/cobblestone.png` | 64×64 copy, palette-quantized in place to at most 16 colours with alpha preserved |
| `Textures/cobblestoneAlternative.png` | `/Users/nickbryant/valenfeld/assets/models/retrokit/Textures/cobblestoneAlternative.png` | 64×64 copy, palette-quantized in place to at most 16 colours with alpha preserved |
| `Textures/details.png` | `/Users/nickbryant/valenfeld/assets/models/retrokit/Textures/details.png` | 64×64 copy, palette-quantized in place to at most 16 colours with alpha preserved |
| `Textures/planks.png` | `/Users/nickbryant/valenfeld/assets/models/retrokit/Textures/planks.png` | 64×64 copy, palette-quantized in place to at most 16 colours with alpha preserved |
| `Textures/water.png` | `/Users/nickbryant/valenfeld/assets/models/retrokit/Textures/water.png` | 64×64 copy, palette-quantized in place to at most 16 colours with alpha preserved |
| `rock_4_bl.glb` | `/Users/nickbryant/valenfeld/assets/models/rockpack/rock_4_bl.glb` | Copied unchanged |
| `boulder_3_tr.glb` | `/Users/nickbryant/valenfeld/assets/models/rockpack/boulder_3_tr.glb` | Copied unchanged |
| `LICENSE-KYLE-FUJI.txt` | `/Users/nickbryant/valenfeld/assets/models/rockpack/KyleFuji_license.txt` | Copied unchanged and renamed |
| `Textures/rock_mossy_atlas.png` | `/Users/nickbryant/valenfeld/assets/models/rockpack/T_mossy_atlas_diffuse_roughness_1.png` | Diffuse RGB downsampled to 64×64 and palette-authored to at most 16 opaque colours; packed roughness alpha discarded |
| `Textures/cistern_wall.png` | `/Users/nickbryant/valenfeld/assets/textures/environment/rock_wall_mortar.jpg` | Target-native 128×128, 16-colour palette-authored derivative preserving the source composition |
| `Textures/cistern_floor.png` | `/Users/nickbryant/valenfeld/assets/textures/environment/cobblestone_large_01.jpg` | Target-native 128×128, 16-colour palette-authored derivative preserving the source composition |
| `Textures/cistern_moss.png` | `/Users/nickbryant/valenfeld/assets/textures/environment/moss_green.png` | Target-native 128×128, 16-colour palette-authored derivative preserving the source composition |

The rock-pack normal map is intentionally excluded. No normal, ORM, or other
PBR maps belong in runtime materials for this kit.

## Target import contract

- Filtering: **Nearest**
- Mipmaps: **On**
- Anisotropic filtering: **Off**
- Compression: **Lossless**
- Runtime materials: albedo only; **no normal, ORM, or PBR maps**
