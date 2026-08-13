# Garrison Valenfeld asset sources

This is a byte-for-byte asset transfer from the local Valenfeld project at
`/Users/nickbryant/valenfeld`. Godot `.import` files were deliberately not
transferred; this project generates its own import metadata.

| Destination | Valenfeld source path | Family | Known licensing evidence | Intended use |
| --- | --- | --- | --- | --- |
| `assets/props/booth/` | `assets/models/propkit/` | KayKit environment/props | Valenfeld's `README.md` identifies its KayKit environment/props as CC0. | Furniture, storage, tableware, tools, banners, produce, and small dressing for the booth and inhabited garrison spaces. |
| `assets/props/garrison_farm/` | `assets/models/polyhaven_farm/` | Poly Haven farm models | The Valenfeld asset catalog records this family as PolyHaven CC0, but its per-file receipts are inconsistent. The transferred GLBs have embedded textures; redundant extracted JPGs were not transferred. | Farm tools and containers for the garrison yard and agricultural dressing. |
| `assets/props/garrison_architecture/` | `assets/models/retrokit/` | Kenney Retro Fantasy Kit 2.0 | The transferred local `License.txt` identifies the kit as Creative Commons Zero (CC0) and names Kenney as its creator/distributor. | Roof, wall, column, fence, pulley, crate, and shrub pieces for garrison architecture and dressing. |
| `assets/props/garrison_rocks/` | `assets/models/rockpack/` | Kyle Fuji rock pack | The transferred local `KyleFuji_license.txt` states that all assets are CC0 1.0 and names Kyle Fuji as the creator. | Rocks, boulders, and their mossy atlas textures for garrison terrain dressing. |

## Deliberate exclusions

- MedievalKit assets were excluded because their provenance was unresolved.
- Deprecated Quaternius village-kit assets were excluded because the kit is
  deprecated and its transfer provenance was unresolved.
- Valenfeld's generic environment textures were removed before merge because
  their specific licensing receipt was unresolved. Garrison materials use this
  project's existing documented cobble, grass, and rock-wall texture families.
