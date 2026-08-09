extends Node
## Autoload `Atlas`. The floor's plan, and how much of it the player has seen.
##
## Two surfaces read this and nothing else: the HUD's corner minimap
## (`Hud._draw_minimap`) and the pause menu's MAP screen (`MenuMapPanel`). Both
## of them draw through `MapDraw`, so there is one map in this game rendered at
## two sizes -- never two maps that agree today.
##
## **Why an autoload and not a method on `Dungeon`.** The map is asked for from
## two places that cannot see the dungeon node: the HUD is an autoload that
## outlives every scene, and the pause menu is a separate `CanvasLayer` at layer
## 100. Both would otherwise have to go hunting through the tree for a `Dungeon`
## and cope with not finding one, which is three copies of the same null check
## and a fourth one waiting to be written. The generator publishes here once, on
## the way up, and everything downstream reads a plain dictionary.
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
## I been here" sitting next to `Run.descend()`'s.

## Marker ids. Deliberately a short closed set: the map is a schematic, and a
## schematic with nine symbols is a legend the player has to learn rather than a
## picture they can read. `MapDraw.MARK_DRAW` is the other half of this list --
## an id with no glyph draws nothing, silently, so add to both.
const M_CHEST := &"chest"
const M_CHEST_OPEN := &"chest_open"
const M_STAIRS := &"stairs"
const M_ARROWS := &"arrows"
const M_ENTRANCE := &"entrance"

## cell -> Array[StringName] of the four compass doors out of it.
var rooms: Dictionary[Vector2i, Array] = {}
## cell -> Array[StringName] of marker ids standing in it.
var marks: Dictionary[Vector2i, Array] = {}
## cell -> true once the player has stood in it. Absent means fogged.
var seen: Dictionary[Vector2i, bool] = {}
## The cell the player arrived on.
var entrance: Vector2i = Vector2i.ZERO
## Which floor this plan is of. 0 when there is no floor -- in town, in a lookdev
## scene, or before the first descent. `has_floor()` is the question to ask.
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
	level = floor_level
	spacing = maxf(cell_spacing, 0.001)
	room_frac = clampf(room_size / spacing, 0.05, 1.0)
	door_frac = clampf(door_span / maxf(room_size, 0.001), 0.05, 0.9)
	entrance = arrival


func add_room(cell: Vector2i, doors: Array) -> void:
	rooms[cell] = doors.duplicate()


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
	level = 0
	_changed()


func _ready() -> void:
	# Both endings of a run, and the only two. `Run.extract()` and `Run.die()`
	# both emit this, so there is no third path where the map survives into town.
	Bus.run_ended.connect(func(_e: bool, _c: Dictionary, _v: int) -> void:
		close_floor())


func _changed() -> void:
	Bus.map_changed.emit()


# --- Reading ----------------------------------------------------------------

func has_floor() -> bool:
	return level > 0 and not rooms.is_empty()


func is_seen(cell: Vector2i) -> bool:
	return seen.has(cell)


func doors_of(cell: Vector2i) -> Array:
	return rooms.get(cell, [])


func marks_of(cell: Vector2i) -> Array:
	return marks.get(cell, [])


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
