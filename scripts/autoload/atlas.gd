extends Node
## Autoload `Atlas`. The active map, and how much of a dungeon the player has
## seen.
##
## Two surfaces read this and nothing else: the HUD's corner minimap
## (`Hud._draw_minimap`) and the pause menu's MAP screen (`MenuMapPanel`). Both
## of them draw through `MapDraw`, so there is one map in this game rendered at
## two sizes -- never two maps that agree today.
##
## **Why an autoload and not a method on a zone.** The map is asked for from two
## places that cannot own the playable scene: the HUD outlives every scene, and
## the pause menu is a separate `CanvasLayer` at layer 100. Dungeon generators
## publish their plan here; authored surface zones register one live provider
## after their map-relevant nodes exist and unregister it on exit. Atlas asks
## that provider for the current immutable snapshot, so moving landmarks remain
## current without either renderer hunting through the scene tree.
##
## **What this is NOT.** It is not a second copy of the layout that the dungeon
## could disagree with -- `Dungeon._plan` is the only writer of the room graph,
## and it writes it here in the same pass it builds the geometry. And it is not
## persisted: a floor is a floor, `open_floor` wipes the previous one, and
## leaving the dungeon wipes it entirely. The Descent is not a world you re-map.
##
## **Fog of war lives here, not in the drawing code.** `seen` is written by the
## room trigger the generator already had (`Dungeon._add_room_trigger`), so a
## room is on the map for exactly the same reason it counts toward the
## extraction fee: the player walked into it. Anything that decided to reveal a
## room by proximity, or by line of sight, would be a second definition of "have
## I been here" sitting next to `Run.descend()`'s. `annexes` -- everything behind
## an anchored door -- fogs by the same rule and through the same kind of
## trigger; see `add_annex`.

## Marker ids. Deliberately a short closed set: the map is a schematic, and a
## schematic with nine symbols is a legend the player has to learn rather than a
## picture they can read. `MapDraw.MARK_DRAW` is the other half of this list --
## an id with no glyph draws nothing, silently, so add to both.
const M_CHEST := &"chest"
const M_CHEST_OPEN := &"chest_open"
const M_STAIRS := &"stairs"
const M_ARROWS := &"arrows"
const M_ENTRANCE := &"entrance"

const KIND_NONE := &""
const KIND_DUNGEON := &"dungeon"
const KIND_SURFACE := &"surface"

## cell -> Array[StringName] of the four compass doors out of it.
var rooms: Dictionary[Vector2i, Array] = {}
## Everything the floor has that is NOT on the room grid: the landing behind a
## boss door, the shortcut's landing, the treasure chamber, and the vault's three
## rooms. They hang off one wall of one room and run away from it in a straight
## line, and none of them lands on a cell -- the vault's second and third rooms
## are 1.25 and 1.83 cells out, so rounding them onto the grid would put two
## rooms in one square and call it a map.
##
## So an annex is METRIC where the rest of this file is a grid: a chain of boxes
## measured in cells-from-the-host-room's-centre, drawn at the same pitch as
## everything else and aligned to nothing.
##
##   {"cell": Vector2i, "dir": StringName, "boxes": Array[Dictionary]}
##
## and a box is `{"near", "far", "wide": float, "room": bool, "seen": bool}` --
## `near`/`far` along `dir`, `wide` across it, all three in cells. `room` is what
## gets an outline and a trigger; the links between are corridor, exactly as on
## the grid.
##
## Fog is per box and written by the same rule as `seen`: you walked into it.
var annexes: Array[Dictionary] = []
## cell -> Array[StringName] of marker ids standing in it.
var marks: Dictionary[Vector2i, Array] = {}
## cell -> true once the player has stood in it. Absent means fogged.
var seen: Dictionary[Vector2i, bool] = {}
## The cell the player arrived on.
var entrance: Vector2i = Vector2i.ZERO
## Which floor this plan is of. 0 when there is no floor -- in the garrison, in
## a lookdev scene, or before the first descent. `has_floor()` is the question
## to ask.
var level: int = 0

## Centre-to-centre spacing of the room grid, in metres. The only number that
## turns a world position into a cell, so it has to come from the generator
## rather than be assumed.
var spacing: float = 26.0
## The room's own footprint as a fraction of `spacing`. Corridors are the
## difference. Kept as a fraction rather than in metres because everything
## downstream is drawing at an arbitrary pixel pitch.
var room_frac: float = 0.615
## A doorway's span as a fraction of the room's width -- the gap `MapDraw` cuts
## in a wall, and the width it draws a corridor at.
var door_frac: float = 0.375

## Exactly one of these sources is active. Dungeon data above remains public for
## its established writers/readers; surface data is deliberately private so a
## second consumer cannot quietly become another authority.
var _active_kind: StringName = KIND_NONE
var _surface_provider: Node = null


# --- Publishing -------------------------------------------------------------
# Called by `scripts/world/dungeon.gd` as it plans and populates. Nothing else
# writes the plan.

## Start a new floor. Wipes the previous one -- including its fog, which is the
## point: you have not been anywhere on this floor yet.
func open_floor(floor_level: int, cell_spacing: float, room_size: float,
		door_span: float, arrival: Vector2i) -> void:
	rooms.clear()
	marks.clear()
	seen.clear()
	annexes.clear()
	level = floor_level
	spacing = maxf(cell_spacing, 0.001)
	room_frac = clampf(room_size / spacing, 0.05, 1.0)
	door_frac = clampf(door_span / maxf(room_size, 0.001), 0.05, 0.9)
	entrance = arrival
	_surface_provider = null
	_active_kind = KIND_DUNGEON
	_changed()


func add_room(cell: Vector2i, doors: Array) -> void:
	rooms[cell] = doors.duplicate()


## Publish a structure hanging off `cell`'s `dir` wall. `face` is metres from the
## room's centre to that wall, and `parts` is the chain outward from it --
## `[{"len": float, "wide": float, "room": bool}, ...]`, in METRES, because that
## is the only unit the generator has and converting here is the one place that
## has `spacing` to convert with.
##
## Returns the annex's index, which is half of the handle `see_annex` wants. The
## builder keeps it and hands it to the triggers it is about to hang, the same
## way `_add_room_trigger` closes over a cell.
##
## Called from the BUILDERS and not from `Dungeon._publish`, for the reason that
## function's own note gives about markers: a shortcut whose prefab failed to
## load builds no landing, and a map that drew one anyway because the anchor was
## planned is a map that lies about a wall you can walk through.
func add_annex(cell: Vector2i, dir: StringName, face: float,
		parts: Array) -> int:
	var boxes: Array[Dictionary] = []
	var at := face
	for part: Dictionary in parts:
		var run := float(part.get("len", 0.0))
		boxes.append({
			"near": at / spacing,
			"far": (at + run) / spacing,
			"wide": float(part.get("wide", 1.0)) / spacing,
			"room": bool(part.get("room", false)),
			"seen": false,
		})
		at += run
	annexes.append({"cell": cell, "dir": dir, "boxes": boxes})
	_changed()
	return annexes.size() - 1


## The player is standing in box `box` of annex `a`. The annex twin of `see`, and
## idempotent for the same reason: it is an `Area3D` the player walks in and out
## of all the way back down the vault.
func see_annex(a: int, box: int) -> void:
	if a < 0 or a >= annexes.size():
		return
	var boxes: Array = annexes[a]["boxes"]
	if box < 0 or box >= boxes.size():
		return
	# Bound to a name rather than written through `boxes[box]["seen"]`: a
	# Dictionary is a reference either way, and this is the form the type checker
	# can see the `bool` in.
	var it: Dictionary = boxes[box]
	if bool(it["seen"]):
		return
	it["seen"] = true
	_changed()


## Put a marker in a room. Silently ignores a duplicate: the generator places a
## chest and the chest itself has no reason to know whether it was already
## announced, and two chest glyphs in one room is a bug the player can see.
func mark(cell: Vector2i, id: StringName) -> void:
	var list: Array = marks.get(cell, [])
	if list.has(id):
		return
	list.append(id)
	marks[cell] = list
	_changed()


## Swap one marker for another in whatever room `at` falls in. This is how a
## chest goes from "there is treasure here" to "you already had it" without the
## chest node needing to know its own cell -- it knows where it is standing, and
## that is the same fact.
func replace_at(at: Vector3, from: StringName, to: StringName) -> void:
	var cell := cell_of(at)
	var list: Array = marks.get(cell, [])
	var i := list.find(from)
	if i < 0:
		return
	if to == &"":
		list.remove_at(i)
	elif list.has(to):
		list.remove_at(i)
	else:
		list[i] = to
	marks[cell] = list
	_changed()


## The player is standing in this room. Idempotent, because the trigger that
## calls it is the room trigger and rooms get re-entered constantly.
func see(cell: Vector2i) -> void:
	if seen.has(cell):
		return
	seen[cell] = true
	_changed()


## Leaving the dungeon. There is no floor to draw and the two map surfaces have
## to say so rather than keep showing the one you died on.
func close_floor() -> void:
	rooms.clear()
	marks.clear()
	seen.clear()
	annexes.clear()
	level = 0
	if _active_kind == KIND_DUNGEON:
		_active_kind = KIND_NONE
	_changed()


## Make one authored zone the active source. Atlas retains the provider rather
## than a plan snapshot because garrison services move with their staff. Each
## read asks the registered owner for a fresh immutable snapshot; the HUD and MAP
## still consume that one Atlas result and never discover the scene themselves.
func register_surface(provider: Node) -> void:
	if provider == null or not is_instance_valid(provider):
		push_error("Atlas.register_surface: provider is not live")
		return
	if not provider.has_method(&"surface_map_plan"):
		push_error("Atlas.register_surface: '%s' has no surface_map_plan" % provider.name)
		return
	var plan_value: Variant = provider.call(&"surface_map_plan")
	if not plan_value is Dictionary or not _valid_surface_plan(plan_value as Dictionary):
		push_error("Atlas.register_surface: '%s' supplied an invalid plan" % provider.name)
		return
	_surface_provider = provider
	_active_kind = KIND_SURFACE
	_changed()


## Only the provider that owns the active plan may clear it. A late `_exit_tree`
## from an outgoing scene therefore cannot erase the next scene's registration.
func unregister_surface(provider: Node) -> void:
	if _active_kind != KIND_SURFACE or provider != _surface_provider:
		return
	_surface_provider = null
	_active_kind = KIND_NONE
	_changed()


func _ready() -> void:
	# Both endings of a run, and the only two. `Run.extract()` and `Run.die()`
	# both emit this, so there is no third path where the map survives into the
	# garrison.
	Bus.run_ended.connect(func(_e: bool, _c: Dictionary, _v: int) -> void:
		close_floor())


func _changed() -> void:
	Bus.map_changed.emit()


# --- Reading ----------------------------------------------------------------

func has_floor() -> bool:
	return level > 0 and not rooms.is_empty()


func has_map() -> bool:
	match _active_kind:
		KIND_DUNGEON:
			return has_floor()
		KIND_SURFACE:
			return not surface_plan().is_empty()
	return false


func map_kind() -> StringName:
	return _active_kind if has_map() else KIND_NONE


func map_title() -> String:
	if not has_map():
		return ""
	if _active_kind == KIND_DUNGEON:
		return FloorDb.name_of(level)
	return String(surface_plan().get(&"title", ""))


## The current authored snapshot, only while its registered scene is still
## alive. Returning empty after exit is what makes a stale surface impossible
## even if a scene is freed before its `_exit_tree` callback can finish.
func surface_plan() -> Dictionary:
	if _active_kind != KIND_SURFACE or not _surface_live() \
			or not _surface_provider.has_method(&"surface_map_plan"):
		return {}
	var plan_value: Variant = _surface_provider.call(&"surface_map_plan")
	if not plan_value is Dictionary:
		return {}
	var plan := plan_value as Dictionary
	return plan if _valid_surface_plan(plan) else {}


func map_provider() -> Node:
	if not has_map():
		return null
	return _surface_provider if _active_kind == KIND_SURFACE else self


func map_provider_id() -> int:
	var provider := map_provider()
	return provider.get_instance_id() if provider != null else 0


func map_provider_name() -> String:
	var provider := map_provider()
	return String(provider.name) if provider != null else ""


func _surface_live() -> bool:
	return _surface_provider != null and is_instance_valid(_surface_provider) \
		and _surface_provider.is_inside_tree()


func _valid_surface_plan(plan: Dictionary) -> bool:
	if plan.is_empty() or String(plan.get(&"title", "")).is_empty() \
			or float(plan.get(&"view_range", 0.0)) <= 0.0:
		return false
	return plan.get(&"paths", null) is Array \
		and plan.get(&"areas", null) is Array \
		and plan.get(&"landmarks", null) is Array


func is_seen(cell: Vector2i) -> bool:
	return seen.has(cell)


func doors_of(cell: Vector2i) -> Array:
	return rooms.get(cell, [])


func marks_of(cell: Vector2i) -> Array:
	return marks.get(cell, [])


## The wall sides of `cell` that an annex leaves by. `MapDraw` cuts a doorway in
## each of them for exactly the reason it cuts one for a corridor: an unbroken
## square with a passage touching it reads as a box with a pipe stuck on the
## side. That the passage is behind a locked door changes nothing the player does
## not already know -- they are in the room, they can see the door.
func annex_dirs_of(cell: Vector2i) -> Array[StringName]:
	var out: Array[StringName] = []
	for a: Dictionary in annexes:
		var dir: StringName = a["dir"]
		if a["cell"] == cell and not out.has(dir):
			out.append(dir)
	return out


## The compass step for a door id. It lives here rather than in `MapDraw`
## because `bounds()` needs it too, and two copies of this match is two answers
## to which way north is.
static func step_of(d: StringName) -> Vector2i:
	match d:
		&"n": return Vector2i(0, -1)
		&"s": return Vector2i(0, 1)
		&"w": return Vector2i(-1, 0)
	return Vector2i(1, 0)


func explored_count() -> int:
	return seen.size()


## The bounding box of the WHOLE floor, in cells, fogged rooms included.
##
## Deliberately not the bounds of what has been explored. A map fitted to the
## explored subset re-scales and re-centres itself every time you open a door,
## which makes the one instrument whose job is orientation the least stable
## thing on the screen. Fitting to the full floor costs nothing in secrets -- a
## rectangle says how big the floor is and not one thing about where anything in
## it stands -- and buys a map that sits still while it fills in.
##
## Annexes are folded in because the vault reaches 2.04 cells out of its host
## room's centre, and a box fitted to the grid alone cropped its last room off
## the bottom of the MAP screen.
func bounds() -> Rect2i:
	if rooms.is_empty():
		return Rect2i(0, 0, 1, 1)
	var lo := Vector2i(2147483647, 2147483647)
	var hi := Vector2i(-2147483648, -2147483648)
	for cell: Vector2i in rooms:
		lo.x = mini(lo.x, cell.x)
		lo.y = mini(lo.y, cell.y)
		hi.x = maxi(hi.x, cell.x)
		hi.y = maxi(hi.y, cell.y)
	for a: Dictionary in annexes:
		var cell: Vector2i = a["cell"]
		var axis := Vector2(step_of(a["dir"]))
		var side := Vector2(-axis.y, axis.x)
		for box: Dictionary in a["boxes"]:
			# The far corners are the only two that can be outside a box the near
			# end is already inside, and `wide` is symmetric about the axis.
			for s: float in [-1.0, 1.0]:
				var p := Vector2(cell) + axis * float(box["far"]) \
					+ side * float(box["wide"]) * 0.5 * s
				lo.x = mini(lo.x, int(floor(p.x)))
				lo.y = mini(lo.y, int(floor(p.y)))
				hi.x = maxi(hi.x, int(ceil(p.x)))
				hi.y = maxi(hi.y, int(ceil(p.y)))
	return Rect2i(lo, hi - lo + Vector2i.ONE)


## A world position as fractional cell coordinates -- (1.5, -0.25) is halfway
## along the east wall of the cell east of the entrance. Fractional and not
## rounded because the hero marker has to move INSIDE a room; a marker that
## snapped to the room centre would sit still for the whole length of a walk and
## then jump, which reads as the map being broken rather than coarse.
func cellf_of(at: Vector3) -> Vector2:
	return Vector2(at.x, at.z) / spacing


func cell_of(at: Vector3) -> Vector2i:
	return Vector2i(cellf_of(at).round())
