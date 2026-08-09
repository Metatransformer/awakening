extends RefCounted
## Lookdev for the charged spin's ring — is it flat, and does it read as a disc
## lying on the floor rather than a curtain standing on it?
##
## **Why this exists when spin_attack.gd already photographs the spin.** That
## director shoots a CONTACT SHEET: six captures a few frames apart, all inside
## one 0.48 s sweep. `capture()` encodes a PNG and writes it to disk inside the
## frame, so the frame AFTER every capture has a delta of a tenth of a second or
## more — and a GPU particle emitter handed a fat delta emits that whole slice of
## its rate at ONE emitter position. The ribbon comes out as five clumps of blue
## with gaps between them, which is an artefact of the camera, not of the effect.
## Every judgement about ring density made off those frames is wrong.
##
## So: ONE capture per spin, and the shot is the last thing in each cycle. The
## frames leading up to it all ran at a normal delta, so the arc in the picture
## is the arc the player sees. Eight spins, each photographed a little later than
## the last, is the sweep.
##
##   godot --path . -s tools/shoot.gd -- \
##     --scene=res://scenes/rooms/training.tscn \
##     --director=res://tools/directors/spin_rings.gd --out=/tmp/rings/x.png
##
## NEVER pass --headless (CLAUDE.md §2).

## When each shot is taken, seconds after the button comes up. SWEEP_TIME is
## 0.48 and the motes live 0.55 past that, so 0.75 is the arc at its fullest and
## the last two are the burn-down.
const SHOTS: Array[float] = [0.06, 0.14, 0.24, 0.34, 0.46, 0.60, 0.75, 1.00]

## Long enough for the swing, the mote lifetimes and the glow fade to all be over
## before the next hold starts, so no shot has the previous spin in it.
const SETTLE := 2.2


func run(rig) -> void:
	var out: String = rig.arg("out", "/tmp/rings/x.png").get_base_dir()
	var scene: Node = rig.scene()

	var hero: Node3D = scene.get_node_or_null(^"Hero") as Node3D
	if hero == null:
		print("RINGS FAIL no Hero in the scene")
		return
	var combat: Node = hero.get(&"combat")
	if combat == null:
		print("RINGS FAIL no HeroCombat on the Hero")
		return

	await rig.wait_frames(24)

	var centre := Vector3(0.0, 0.05, 0.0)
	hero.global_position = centre
	hero.set(&"facing_yaw", PI)

	# The posts are SHOVED OUT OF REACH rather than left where training.tscn puts
	# them. A struck post flashes white — it is the brightest thing in the room and
	# it sits exactly where the ring is — and a landed heavy blow calls HITSTOP,
	# which freezes the clock mid-sweep and lands the shot at a time that is not
	# the time on the label. This is a lookdev pass; nothing here is meant to hit.
	for name in ["PostA", "PostB", "PostC"]:
		var post: Node3D = scene.get_node_or_null(NodePath(name)) as Node3D
		if post != null:
			post.global_position = centre + Vector3(0.0, 0.0, 18.0)

	var cam := hero.get_viewport().get_camera_3d()
	if cam == null:
		print("RINGS FAIL no camera")
		return
	# GameCamera re-derives its transform every physics frame, so it has to be
	# switched off before it is placed or it walks straight back to the shoulder.
	cam.set_physics_process(false)

	var charge_time: float = float(combat.get(&"charge_time"))
	var fails := 0

	# --- 1. from above: is it a CIRCLE, and how much of one is lit at once? -----
	for i in SHOTS.size():
		_look(cam, centre, Vector3(0.0, 4.4, 3.4))
		await rig.wait_seconds(SETTLE)
		await rig.hold_seconds(["attack"], charge_time + 0.35)
		if i == 0 and not bool(combat.get(&"charged")):
			print("RINGS FAIL the hold never armed — every frame below is of a light swing")
			fails += 1
		await rig.wait_seconds(SHOTS[i])
		await rig.capture(out.path_join("r_top_%d_%03dms.png" % [i, int(SHOTS[i] * 1000.0)]))

	# --- 2. from the floor: is it FLAT? ----------------------------------------
	# The whole Saturn's-rings claim is a claim about the vertical, and no top-down
	# frame can confirm or deny it. Eye height 0.35 m, which is below the ring's
	# own 0.75: a disc reads here as a line with the hero standing through it, and
	# the curtain this used to be reads as a wall.
	for i in 3:
		var t: float = SHOTS[i + 3]
		_look(cam, centre + Vector3(0.0, 0.7, 0.0), Vector3(0.0, 0.35, 4.2))
		await rig.wait_seconds(SETTLE)
		await rig.hold_seconds(["attack"], charge_time + 0.35)
		await rig.wait_seconds(t)
		await rig.capture(out.path_join("r_edge_%d_%03dms.png" % [i, int(t * 1000.0)]))

	print("RINGS %s (fails=%d)" % ["OK" if fails == 0 else "FAIL", fails])


## Park the camera at `centre + offset` looking at `centre`. Re-applied before
## every shot: the capture stall is not the only thing that can move a camera,
## and a lookdev frame taken from somewhere unknown is not evidence.
func _look(cam: Camera3D, centre: Vector3, offset: Vector3) -> void:
	cam.global_position = centre + offset
	cam.look_at(centre, Vector3.UP)
