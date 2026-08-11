extends RefCounted
## The kit wheel, end to end: hold LB, point, let go, and the right thing moved.
##
## Point it at GARRISON. It needs a hero in group `player` (the HUD hides
## without one, and a wheel nobody can see is not the thing under test) and it
## needs the real camera in the scene, because beat G is about the camera going
## deaf while the wheel is up.
##
##   godot --path . -s tools/shoot.gd -- \
##     --scene=res://scenes/rooms/garrison.tscn \
##     --director=res://tools/directors/kit_wheel.gd \
##     --out=/tmp/wheel/x.png --warmup=60
##
## What it claims, in the order it proves them:
##
##   A  The model. Eight slots, the sword seeded, and `wheel_bindable` refusing
##      everything that is not a right-hand stop or a bottle you own.
##   B  **Auto-bind on pickup.** A bow granted underground is on the wheel
##      before anything draws, on the LOWEST free slot; a ninth ownable thing
##      finds it full and is refused without displacing anybody.
##   C  The sector maths, calibrated against answers already known — every
##      `direction_of(slot)` reads back as that slot, the centre reads -1, and
##      **straight up is the MIDDLE of sector 0 rather than its edge**, which is
##      the one property `_sector`'s obvious formula gets wrong.
##   D  The real hold, through real `InputEvent`s: LB down, stick over, LB up,
##      and the bow is in the right hand. Nothing here pokes `Game`.
##   E  **The routing.** The same gesture on a bottle moves `item_selected` and
##      leaves the right hand exactly where it was. Both halves are checked —
##      "the bottle was selected" alone would pass on a wheel that put the
##      bottle in the hand as well.
##   F  Cancel. `ui_cancel` while the button is down closes it and commits
##      nothing, which is the only way out of a hold whose release is a commit.
##   G  The camera is deaf while the wheel is up — **and the control runs the
##      other way**: the identical stick hold with LB released MUST move the
##      lens. A camera that never moved would pass the first half on its own.
##   H  The HUD draws it: eight `wheel_N` rects while it is open and none the
##      frame after it shuts, plus the two frames to look at.
##   I  The null case for the whole gesture: open, let go without pointing, and
##      **nothing at all changed** — not the hand, not the item, not the wheel.
##   J  The bind card on the Items screen: eight focusable cells, a confirm that
##      changes the direction under the cursor, and — the half that matters —
##      one that does NOT drag something off the slot it was already on.
##   K  The eight bindings survive a save and a load, and a slot written before
##      the wheel existed does not wipe the wheel it loads into.
##
## G and I are the two that make the rest mean anything. Everything above them
## is an instrument reporting that something happened; those two are the same
## instrument reporting that nothing did (CLAUDE.md §2).

var out := ""
var _fails := 0

## The two directions the input beats aim at. Picked as a cardinal and a
## diagonal on purpose: a cardinal needs one action held and a diagonal needs
## two, and `Input.get_vector` clamps the second case to the unit circle — so a
## wheel that only ever worked on the axes would pass D and fail E.
const SLOT_WEAPON := 2   ## →
const SLOT_BOTTLE := 5   ## ↓←


func run(rig) -> void:
	out = rig.arg("out", "/tmp/wheel/x.png").get_base_dir()
	await rig.wait_frames(24)

	_model()
	_auto_bind()
	_sectors()
	await _commit(rig)
	await _routing(rig)
	await _cancel(rig)
	await _camera(rig)
	await _drawn(rig)
	await _nothing(rig)
	await _bind_card(rig)
	await _save_round_trip(rig)

	if _fails == 0:
		print("WHEEL ok -- every check passed")
	else:
		print("WHEEL FAIL -- %d check(s) failed" % _fails)


func _ck(label: String, ok: bool) -> void:
	if ok:
		print("  ok   %s" % label)
	else:
		_fails += 1
		print("WHEEL FAIL %s" % label)


## Put the wheel in a known state. Every input beat starts from here, because a
## beat that inherited the previous one's bindings would pass or fail depending
## on what ran before it.
func _clear() -> void:
	for i in Game.WHEEL_SLOTS:
		Game.wheel_clear(i)


# --- A. The model -----------------------------------------------------------

func _model() -> void:
	_ck("A0 eight slots, and eight is short of the ten a player can own",
		Game.WHEEL_SLOTS == 8
			and Game.WHEEL_SLOTS < Game.RIGHT_POOL.size() + K.BOTTLE_MAX)
	_ck("A1 the array is that long", Game.wheel.size() == Game.WHEEL_SLOTS)
	_ck("A2 the sword is on it from the starter kit",
		Game.wheel_slot_of(&"sword") >= 0)
	# Bindable is the ROUTING question asked early: everything the wheel accepts
	# has to be something `wheel_select` knows what to do with, or the release
	# would land on a slot that silently does nothing.
	for id: StringName in Game.RIGHT_POOL:
		_ck("A3 %s is bindable" % id, Game.wheel_bindable(id))
	_ck("A4 the shield is not -- the left hand is not on this wheel",
		not Game.wheel_bindable(&"shield"))
	_ck("A5 nor is the map, nor a bottle you have not blown",
		not Game.wheel_bindable(&"map")
			and not Game.wheel_bindable(&"bottle_9")
			and not Game.wheel_bindable(&""))
	_ck("A6 a slot off the end is refused rather than grown",
		not Game.wheel_bind(Game.WHEEL_SLOTS, &"sword")
			and not Game.wheel_bind(-1, &"sword")
			and Game.wheel.size() == Game.WHEEL_SLOTS)


# --- B. Auto-bind on pickup -------------------------------------------------

func _auto_bind() -> void:
	_clear()
	_ck("B0 the wheel is empty to start", Game.wheel_slot_of(&"sword") < 0)

	# Un-owned first. `grant` returns early on something already in `items`, so a
	# director that inherited a bow from an earlier beat would be testing the
	# early return and calling it an auto-bind.
	Game.items.erase(&"bow")
	Game.wheel_bind(0, &"sword")
	Game.grant(&"bow")
	_ck("B1 a bow picked up lands on the wheel by itself",
		Game.wheel_slot_of(&"bow") >= 0)
	_ck("B2 on the LOWEST free slot, not the first one it looked at",
		Game.wheel_slot_of(&"bow") == 1)

	# A bottle is the other kind, and it binds through the same door.
	while Game.bottle_count() < 3:
		if not Game.add_bottle():
			break
	var last := Game.bottle_id(Game.bottle_count() - 1)
	if Game.wheel_slot_of(last) < 0:
		Game.wheel_auto_bind(last)
	_ck("B3 a bottle blown at the counter binds itself too (%s)" % last,
		Game.wheel_slot_of(last) >= 0)

	# Full, with `burst` deliberately left OFF so there is a real pickup left to
	# refuse. Eight distinct ids into eight slots, so nothing swaps on the way in.
	_clear()
	var fill: Array[StringName] = [&"sword", &"bow", &"hookshot", &"sustain",
		&"ballast", Game.bottle_id(0), Game.bottle_id(1), Game.bottle_id(2)]
	for i in Game.WHEEL_SLOTS:
		Game.wheel_bind(i, fill[i])
	var snapshot := Game.wheel.duplicate()
	_ck("B4 the wheel can be filled to all eight", not snapshot.has(&""))
	# The interesting half is not the -1, it is that the eight already there are
	# UNTOUCHED: an auto-bind that evicted somebody to make room would rearrange
	# a wheel the player had curated, silently, on a pickup.
	Game.items.erase(&"burst")
	Game.grant(&"burst")
	_ck("B5 a pickup with nowhere to go is refused, and evicts nobody",
		Game.wheel_slot_of(&"burst") < 0 and Game.wheel == snapshot)


# --- C. The sector maths ----------------------------------------------------

## Calibration, both ways. Every cell's own direction has to read back as that
## cell (the instrument can see what is there), the dead centre has to read -1
## (it does not invent one), and the boundary has to be where the drawing says
## it is.
func _sectors() -> void:
	var round_trip := true
	for slot in Game.WHEEL_SLOTS:
		if KitWheel.sector_of(KitWheel.direction_of(slot)) != slot:
			round_trip = false
			print("WHEEL FAIL C0 slot %d points at %d" % [
				slot, KitWheel.sector_of(KitWheel.direction_of(slot))])
	_ck("C0 every cell's own direction reads back as that cell", round_trip)
	_ck("C1 dead centre is no sector at all",
		KitWheel.sector_of(Vector2.ZERO) == -1
			and KitWheel.sector_of(Vector2(0.0, -0.3)) == -1)

	# **Up is the MIDDLE of sector 0.** A half-sector either side of straight up
	# is still sector 0; a hair past it is not. The obvious formula puts up on
	# the boundary, which makes the most natural flick a thumb makes a coin toss
	# between the first cell and the last -- so this is the check that would
	# catch somebody "simplifying" `sector_of`.
	var half := PI / float(Game.WHEEL_SLOTS)
	var up := Vector2(0.0, -1.0)
	_ck("C2 a half-sector either side of straight up is still sector 0",
		KitWheel.sector_of(up.rotated(half * 0.9)) == 0
			and KitWheel.sector_of(up.rotated(-half * 0.9)) == 0)
	_ck("C3 and just past it is not",
		KitWheel.sector_of(up.rotated(half * 1.1)) == 1
			and KitWheel.sector_of(up.rotated(-half * 1.1)) == Game.WHEEL_SLOTS - 1)


# --- The gesture ------------------------------------------------------------

## Which `cam_*` actions push the stick at `slot`.
##
## Derived from `direction_of` rather than written out as a table: a table would
## be a second copy of the layout, and the first time somebody rotated the ring
## the director would keep passing while pointing at the wrong cell.
static func _stick_for(slot: int) -> Array:
	var d := KitWheel.direction_of(slot)
	var acts: Array = []
	if d.x > 0.3:
		acts.append("cam_right")
	elif d.x < -0.3:
		acts.append("cam_left")
	if d.y > 0.3:
		acts.append("cam_down")
	elif d.y < -0.3:
		acts.append("cam_up")
	return acts


## Hold LB, push the stick at `slot`, wait for the wheel to agree it is pointing
## there, and let go. Returns the sector the wheel believed it was on at the
## moment of release, so the caller can fail on the AIM separately from failing
## on the outcome -- "the bow is not in your hand" and "the thumb was on the
## wrong cell" are different bugs and used to be one red line.
func _flick(rig, slot: int, cancel: bool = false) -> int:
	await rig.press("kit_wheel")
	await rig.wait_frames(4)
	var wheel: KitWheel = Hud.wheel()
	for a in _stick_for(slot):
		await rig.press(a)
	# On the game clock and not a frame count: `_process` polls the stick, and
	# how many rendered frames that takes is a property of the panel.
	await rig.until(func() -> bool: return wheel != null and wheel.sector == slot, 2.0)
	var at: int = wheel.sector if wheel != null else -99
	if cancel:
		await rig.tap(["ui_cancel"])
		await rig.wait_frames(2)
	for a in _stick_for(slot):
		rig.release(a)
	rig.release("kit_wheel")
	await rig.wait_frames(6)
	return at


# --- D. The commit ----------------------------------------------------------

func _commit(rig) -> void:
	_clear()
	Game.grant(&"bow")
	Game.wheel_bind(SLOT_WEAPON, &"bow")
	Game.loadout[Game.loadout_set][Game.HAND_RIGHT] = &"sword"
	_ck("D0 the sword is in hand and the bow is on the wheel",
		Game.armament(Game.HAND_RIGHT) == &"sword"
			and Game.wheel_at(SLOT_WEAPON) == &"bow")

	await rig.press("kit_wheel")
	await rig.wait_frames(4)
	_ck("D1 LB opens it, through a real InputEvent", KitWheel.open)
	rig.release("kit_wheel")
	await rig.wait_frames(4)
	_ck("D2 and letting go shuts it", not KitWheel.open)

	var at: int = await _flick(rig, SLOT_WEAPON)
	_ck("D3 the stick puts the thumb on cell %d (got %d)" % [SLOT_WEAPON, at],
		at == SLOT_WEAPON)
	_ck("D4 and the release puts the bow in the right hand (%s)"
		% Game.armament(Game.HAND_RIGHT), Game.armament(Game.HAND_RIGHT) == &"bow")
	_ck("D5 the wheel is shut afterwards", not KitWheel.open)


# --- E. The routing ---------------------------------------------------------

func _routing(rig) -> void:
	while Game.bottle_count() < 2:
		Game.add_bottle()
	_clear()
	Game.wheel_bind(SLOT_BOTTLE, Game.bottle_id(1))
	Game.item_selected = 0
	var hand := Game.armament(Game.HAND_RIGHT)

	var at: int = await _flick(rig, SLOT_BOTTLE)
	_ck("E0 the diagonal reaches cell %d (got %d)" % [SLOT_BOTTLE, at],
		at == SLOT_BOTTLE)
	_ck("E1 a bottle goes to the ITEM slot (%d)" % Game.item_selected,
		Game.item_selected == 1)
	# The half that makes E1 mean something. One `if` decides this, and a wheel
	# that did both would still pass E1.
	_ck("E2 and NOT into the right hand, which still holds %s"
		% Game.armament(Game.HAND_RIGHT), Game.armament(Game.HAND_RIGHT) == hand)


# --- F. Cancel --------------------------------------------------------------

func _cancel(rig) -> void:
	_clear()
	Game.grant(&"hookshot")
	Game.wheel_bind(SLOT_WEAPON, &"hookshot")
	Game.loadout[Game.loadout_set][Game.HAND_RIGHT] = &"sword"

	var at: int = await _flick(rig, SLOT_WEAPON, true)
	_ck("F0 the thumb was on the hookshot's cell (%d)" % at, at == SLOT_WEAPON)
	_ck("F1 B while the button is down commits nothing (%s)"
		% Game.armament(Game.HAND_RIGHT), Game.armament(Game.HAND_RIGHT) == &"sword")
	_ck("F2 and the wheel is shut, not stuck open", not KitWheel.open)


# --- G. The camera ----------------------------------------------------------

## The lens must not swing while the player is aiming, and it must swing when
## they are not. The second half is the control: a camera that had stopped
## working for an unrelated reason would sail through the first half alone, and
## this project has shipped that exact shape of false pass six times (CLAUDE.md
## §2).
func _camera(rig) -> void:
	var cam: Camera3D = rig.scene().get_viewport().get_camera_3d()
	if cam == null:
		_ck("G0 there is a camera to be deaf", false)
		return

	_clear()
	var before: Basis = cam.global_transform.basis
	await rig.press("kit_wheel")
	await rig.wait_frames(4)
	await rig.press("cam_right")
	await rig.wait_seconds(0.5)
	var held: Basis = cam.global_transform.basis
	rig.release("cam_right")
	rig.release("kit_wheel")
	await rig.wait_frames(6)

	var moved_while_held: float = (held.z - before.z).length()
	_ck("G1 the lens did not move while the wheel was up (%.4f)"
		% moved_while_held, moved_while_held < 0.01)

	# The control. Same stick, same half second, LB never pressed.
	var base: Basis = cam.global_transform.basis
	await rig.press("cam_right")
	await rig.wait_seconds(0.5)
	var after: Basis = cam.global_transform.basis
	rig.release("cam_right")
	await rig.wait_frames(6)
	var moved_free: float = (after.z - base.z).length()
	_ck("G2 CONTROL -- the same push with the wheel down DOES move it (%.4f)"
		% moved_free, moved_free > 0.05)


# --- H. What is on screen ---------------------------------------------------

func _drawn(rig) -> void:
	_clear()
	Game.grant(&"bow")
	Game.wheel_bind(0, &"sword")
	Game.wheel_bind(SLOT_WEAPON, &"bow")
	while Game.bottle_count() < 2:
		Game.add_bottle()
	Game.wheel_bind(SLOT_BOTTLE, Game.bottle_id(1))
	# Something on a slot the hero does NOT own, so the dimmed / NOT YOURS YET
	# state is in the frame rather than only in the code that draws it.
	Game.items.erase(&"burst")
	Game.wheel_bind(4, &"burst")

	await rig.press("kit_wheel")
	await rig.wait_frames(4)
	var wheel: KitWheel = Hud.wheel()
	for a in _stick_for(SLOT_WEAPON):
		await rig.press(a)
	await rig.until(func() -> bool:
		return wheel != null and wheel.sector == SLOT_WEAPON, 2.0)
	await rig.wait_frames(2)
	await rig.capture("w_1_open.png")

	var rects: Dictionary = Hud.layout_rects()
	var cells := 0
	for slot in Game.WHEEL_SLOTS:
		if rects.has(StringName("wheel_%d" % slot)):
			cells += 1
	_ck("H0 the HUD drew all eight cells (%d)" % cells,
		cells == Game.WHEEL_SLOTS)
	_ck("H1 and the caption under them", rects.has(&"wheel_caption"))
	# Two cells sharing pixels would be a real defect and the layout check cannot
	# see it for us -- `wheel` is deliberately not a LAYOUT_ROOT (see
	# `Hud._draw_wheel`), so the sibling test only compares these eight to each
	# other, which is exactly the comparison worth making here.
	var overlaps := 0
	for a in Game.WHEEL_SLOTS:
		for b in range(a + 1, Game.WHEEL_SLOTS):
			var ra: Rect2 = rects[StringName("wheel_%d" % a)][&"rect"]
			var rb: Rect2 = rects[StringName("wheel_%d" % b)][&"rect"]
			if ra.intersects(rb):
				overlaps += 1
	_ck("H2 no two cells overlap (%d pairs)" % overlaps, overlaps == 0)

	for a in _stick_for(SLOT_WEAPON):
		rig.release(a)
	rig.release("kit_wheel")
	await rig.wait_frames(8)
	await rig.capture("w_2_shut.png")
	var after: Dictionary = Hud.layout_rects()
	_ck("H3 and none of it is left on screen after the release",
		not after.has(&"wheel_0") and not after.has(&"wheel_caption"))

	print("WHEEL frames: %s" % out)


# --- I. The null case -------------------------------------------------------

## Open it and let go without pointing. The honest answer is that nothing
## happened, and this is the beat that proves the instrument can say so.
func _nothing(rig) -> void:
	_clear()
	Game.grant(&"bow")
	Game.wheel_bind(SLOT_WEAPON, &"bow")
	Game.loadout[Game.loadout_set][Game.HAND_RIGHT] = &"sword"
	Game.item_selected = 0
	var wheel_before := Game.wheel.duplicate()

	await rig.press("kit_wheel")
	await rig.wait_frames(8)
	var wheel: KitWheel = Hud.wheel()
	var at: int = wheel.sector if wheel != null else -99
	rig.release("kit_wheel")
	await rig.wait_frames(6)

	_ck("I0 it opens pointing at NOTHING, not at whatever the thumb rested on",
		at == -1)
	_ck("I1 so the release commits nothing (%s)" % Game.armament(Game.HAND_RIGHT),
		Game.armament(Game.HAND_RIGHT) == &"sword" and Game.item_selected == 0)
	_ck("I2 and the bindings themselves are untouched", Game.wheel == wheel_before)


# --- J. The bind card -------------------------------------------------------

## The other half of the user's ask: a bind button in the inventory. The wheel
## binds itself on pickup, so this card is for REARRANGING one — which makes the
## check that matters J4, not J3. A cycle that swapped rather than skipping would
## walk the sword off slot 0 while the player was looking at slot 3.
func _bind_card(rig) -> void:
	_clear()
	Game.items.erase(&"bow")
	Game.grant(&"bow")
	Game.wheel_bind(0, &"sword")

	Menu.open()
	await rig.wait_frames(6)
	Menu._push({"screen": PauseMenu.Screen.EQUIP})
	await rig.wait_frames(14)

	var equip: MenuEquipPanel = Menu.get_node("Root/Screens/EquipScreen")
	_ck("J0 the equipment screen is showing", equip.visible)
	_ck("J1 with eight bind cells on it (%d)" % equip._wheel_cells.size(),
		equip._wheel_cells.size() == Game.WHEEL_SLOTS)

	# Focus is the mechanism this screen actually uses -- there is no cursor
	# field to poke -- so grabbing it IS pressing the D-pad here. Checked before
	# the press rather than assumed: a confirm that landed on whatever had focus
	# instead is card #40's shape (CLAUDE.md §3, `screen._cursor`).
	var cell: Button = equip._wheel_cells[3]
	cell.grab_focus()
	await rig.wait_frames(4)
	_ck("J2 a wheel cell takes pad focus", cell.has_focus())

	var before := Game.wheel_at(3)
	await rig.tap(["ui_accept"])
	await rig.wait_frames(8)
	var after := Game.wheel_at(3)
	_ck("J3 confirming puts something on that direction (%s -> %s)"
		% [before, after], after != before and Game.wheel_pool().has(after))
	_ck("J4 and it did NOT take it off the slot it was already on",
		Game.wheel_at(0) == &"sword")
	_ck("J5 the detail pane says which direction it is (%s)"
		% equip._detail_hand.text, equip._detail_hand.text.contains("KIT WHEEL"))

	await rig.capture("w_3_bind.png")
	Menu.close()
	await rig.wait_frames(10)


# --- K. It survives a save ---------------------------------------------------

## The bindings are the one thing on this feature a player CURATES, so losing
## them on a reload would undo the whole point of having a bind card. `VERSION`
## went to 7 for the key; this is the beat that says the key is actually read
## back, and read back through `wheel_bind` so a hand-edited slot cannot put the
## shield on the wheel.
func _save_round_trip(rig) -> void:
	var slot: int = Saves.SLOTS - 1
	Saves.erase(slot)

	_clear()
	while Game.bottle_count() < 2:
		Game.add_bottle()
	Game.items.erase(&"hookshot")
	Game.grant(&"hookshot")
	Game.wheel_clear(Game.wheel_slot_of(&"hookshot"))
	Game.wheel_bind(0, &"sword")
	Game.wheel_bind(3, &"hookshot")
	Game.wheel_bind(6, Game.bottle_id(1))
	var want := Game.wheel.duplicate()

	_ck("K0 the slot was written", Saves.save(slot))
	# Scrambled between the write and the read, so a load that did nothing at all
	# would fail rather than quietly agreeing with a wheel that never changed.
	_clear()
	Game.wheel_bind(7, &"bow")
	_ck("K1 the wheel was scrambled before the read", Game.wheel != want)

	var where := Saves.load_slot(slot)
	await rig.wait_frames(4)
	_ck("K2 the slot was read (%s)" % where.get("scene", ""), not where.is_empty())
	_ck("K3 all eight bindings came back exactly (%s)" % [Game.wheel], Game.wheel == want)

	# A SLOT FROM BEFORE THE WHEEL EXISTED, made by deleting the key rather than
	# by describing one: the whole risk of an additive bump is that the fallback
	# path is the one nobody runs. `wheel` must be left ALONE rather than emptied
	# -- a returning player's seeded sword is the only thing on it, and a load
	# that blanked it would hand them a wheel with nothing to point at.
	var raw := FileAccess.get_file_as_string(Saves.slot_path(slot))
	var d: Dictionary = JSON.parse_string(raw)
	d.erase("wheel")
	var f := FileAccess.open(Saves.slot_path(slot), FileAccess.WRITE)
	f.store_string(JSON.stringify(d))
	f.close()

	_clear()
	Game.wheel_bind(2, &"sword")
	var seeded := Game.wheel.duplicate()
	var old := Saves.load_slot(slot)
	await rig.wait_frames(4)
	_ck("K4 a slot with no wheel key still loads", not old.is_empty())
	_ck("K5 and leaves the wheel it loaded into alone (%s)" % [Game.wheel],
		Game.wheel == seeded)

	Saves.erase(slot)
