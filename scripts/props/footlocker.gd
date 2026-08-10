class_name Footlocker
extends Interactable
## The chest at the foot of the bed. What you carried home and did not sell.
##
## ## The hole it fills
##
## `Run.extract()` brings the bag home intact — the fee is paid, the components
## are sorted onto the bench, and everything else is still merchandise sitting in
## `Run.bag`. `Run.enter()` then **clears the bag**, so anything you did not sell
## before the next run is destroyed with no event, no notice and no receipt. That
## is the correct rule for the dungeon (the bag is what you are gambling) and a
## silent one in town, where the bag is just the thing you are holding.
##
## So this is the shelf you put it on. Not more storage — *somewhere to put the
## thing down.*
##
## ## Why it does not break the one question
##
## `docs/GDD.md` §2 is the test every feature has to pass: does it make *"is what
## I am carrying worth more than the walk back"* harder to answer? A locker in
## town is unreachable from the shaft — you have already made the walk, paid the
## fee and won the bag before you can touch it — so it moves nothing on either
## axis of §2. It is finite anyway (`K.STASH_SLOTS`, and see the note there),
## because the same section names infinite storage as one of the three features
## that delete the game and the cheap way to keep faith with that is to not build
## the infinite version.
##
## ## Both doors go through `Run`
##
## Deposit is `Run.consume()` and withdrawal is `Run.collect()`, which is not a
## convenience: the bag's bookkeeping — the erase, the slot arithmetic, the heat
## premium — is `Run`'s and nobody else's (its own note on `consume` says so). A
## locker that reached into `Run.bag` directly would be a second writer, and the
## first thing to disagree would be the heat pot: sell half a bag you had stashed
## the hot half of, and the vendor pays a premium the remaining stacks never
## earned.
##
## The model is `Chest` (`scripts/world/chest.gd`) turned inside out: same lid,
## same hinge, and it opens every time instead of once.

## The lid angle when the locker is being used. Same as `Chest.LID_OPEN`'s
## intent — far enough to read as open from the third-person camera, short of
## the ninety degrees that makes a lid look unhinged.
const LID_OPEN := -1.15
const LID_SHUT := 0.0

const MAT_WOOD := preload("res://assets/materials/mat_wood.tres")
const MAT_IRON := preload("res://assets/materials/mat_iron.tres")

const WIDE := 1.05
const DEEP := 0.62
const BODY_H := 0.46
const LID_H := 0.20

var _lid: Node3D
var _rim: MeshInstance3D
var _screen: StashScreen = null


func _ready() -> void:
	prompt = "OPEN"
	radius = 1.6
	super()
	_build()


func activate(by: Node3D) -> void:
	if is_instance_valid(_screen):
		return
	activated.emit(by)
	_screen = StashScreen.open(self)
	# The lid follows the screen rather than a timer, so a player who closes the
	# locker and walks off never leaves it standing open behind them. `tree_exited`
	# and not `close()`, because the screen also dies with a scene change and that
	# path has no polite exit.
	_screen.tree_exited.connect(_shut)
	_swing(LID_OPEN)


func _shut() -> void:
	_screen = null
	if is_inside_tree():
		_swing(LID_SHUT)


func _swing(to: float) -> void:
	if _lid == null:
		return
	var tw := create_tween()
	tw.tween_property(_lid, "rotation:x", to, 0.28) \
		.set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)


## The rim brightens when this is the prop the player is addressing, which is the
## whole of `on_focus` in this project — see `Chest`. Two objects within reach of
## each other in a room this small (the cot is a metre away) makes "which one am
## I about to press" a real question, and `Prompt` answers it in text at the
## bottom of the screen. This answers it where the player is looking.
func on_focus(on: bool) -> void:
	if _rim != null:
		_rim.visible = on


# --- Look --------------------------------------------------------------------

func _build() -> void:
	var body := MeshInstance3D.new()
	var bm := BoxMesh.new()
	bm.size = Vector3(WIDE, BODY_H, DEEP)
	body.mesh = bm
	body.material_override = MAT_WOOD
	body.position.y = BODY_H * 0.5
	add_child(body)

	# The lid hinges on its own BACK edge, which is what makes this a chest
	# rather than a barrel — `docs/METAGAME.md` says exactly that about `Chest`,
	# and the pivot is the whole of it. A lid that rotated about its centre reads
	# as a plank spinning in the air.
	_lid = Node3D.new()
	_lid.position = Vector3(0.0, BODY_H, -DEEP * 0.5)
	add_child(_lid)

	var lid_mesh := MeshInstance3D.new()
	var lm := BoxMesh.new()
	lm.size = Vector3(WIDE, LID_H, DEEP)
	lid_mesh.mesh = lm
	lid_mesh.material_override = MAT_WOOD
	lid_mesh.position = Vector3(0.0, LID_H * 0.5, DEEP * 0.5)
	_lid.add_child(lid_mesh)

	# Two iron bands over the lid seam. The one detail worth a draw call: it is
	# what separates this silhouette from the crates at the vendor's stall at the
	# fourteen metres `TownLight` calls the only distance that matters.
	for sx in [-0.28, 0.28]:
		var band := MeshInstance3D.new()
		var am := BoxMesh.new()
		am.size = Vector3(0.10, LID_H + 0.02, DEEP + 0.02)
		band.mesh = am
		band.material_override = MAT_IRON
		band.position = Vector3(WIDE * sx, LID_H * 0.5, DEEP * 0.5)
		_lid.add_child(band)

	# The focus rim: an unshaded wireframe box a hair proud of the body, hidden
	# until `on_focus`. Unshaded because it is UI drawn in the world and has to
	# look the same in the roof's shade as it does in the sun.
	_rim = MeshInstance3D.new()
	var rm := BoxMesh.new()
	rm.size = Vector3(WIDE + 0.06, BODY_H + LID_H + 0.06, DEEP + 0.06)
	_rim.mesh = rm
	var rim_mat := StandardMaterial3D.new()
	rim_mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	rim_mat.albedo_color = Color(Pal.GOLD, 0.16)
	rim_mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	# Backfaces only, so the rim is a halo the body sits inside rather than a
	# gold box the locker disappears into.
	rim_mat.cull_mode = BaseMaterial3D.CULL_FRONT
	_rim.material_override = rim_mat
	_rim.position.y = (BODY_H + LID_H) * 0.5
	_rim.visible = false
	add_child(_rim)
