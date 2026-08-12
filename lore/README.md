# Awakening lore subset

This directory is the machine-readable canon subset for **The Lower Worlds:
Awakening** and its prologue. It is not a second world bible. The parent
Valenfeld canon graph, entered through
`../../valenfeld/world/LORE_INDEX.md`, remains authoritative for shared people,
places, factions, history, and cosmology.

The files here freeze only facts that Awakening currently commits to or reveals.
`world.yml` also records every known collision with the parent graph. Those
collisions are unresolved design dependencies: tooling, dialogue, items, and
environmental text must never silently choose either side. A shared-world change
is made in Valenfeld first and then reconciled here through
`docs/CANON_BRIDGE.md`.

Generation may read these files but may not invent or alter their roots. Surface
dialogue and other player-facing artifacts must cite frozen facts, remain within
the prologue reveal budget, and introduce no new person, place, deity, history,
or cosmology. Unknown is not permission to improvise. `gods.yml` freezes the
small parent-canon subset now revealed by the Votive Court; no deity outside
that list may be named or attributed by Awakening surface content.

Run `npm run lore:check` (or `python3 tools/validate_lore.py`) after changing the
subset. The validator uses PyYAML when present and macOS Ruby's standard YAML
parser otherwise; no project package install is required. It checks the file
manifest and sources, entity ids, person records, pronouns, and the live
`DialogueDb.PEOPLE` contract.
