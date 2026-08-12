extends RefCounted
## Lookdev for the charged spin's water sheet, rounded contact head, and aligned
## directional sparks. It preserves the top/edge and full-turn coverage while
## proving the moving seam under normal frame deltas.
##
## **Why this exists when spin_attack.gd already photographs the spin.** That
## director shoots a CONTACT SHEET: six captures a few frames apart, all inside
## one 0.48 s sweep. `capture()` encodes a PNG and writes it to disk inside the
## frame, so the frame AFTER every capture has a delta of a tenth of a second or
## more — and a GPU particle emitter handed a fat delta emits that whole slice of
## its rate at ONE emitter position. The ribbon comes out as five clumps of blue
## with gaps between them, which is an artefact of the camera, not of the effect.
## Every judgement about a moving seam made off those frames is wrong.
##
## So: ONE capture per spin, and the shot is the last thing in each cycle. The
## frames leading up to it all ran at a normal delta, so the arc, contact head,
## and sparks in the picture are what the player sees. Eight spins, each
## photographed a little later than the last, is the sweep.
##
##   tools/quiet.sh --path . -s tools/shoot.gd -- \
##     --scene=res://scenes/rooms/training.tscn \
##     --director=res://tools/directors/spin_rings.gd --out=/tmp/rings/x.png
##
## NEVER pass --headless (CLAUDE.md §2).

## The button the spin is a HOLD OF. `heavy` (Shift+LMB), not `attack` — the
## layout moved and this director did not follow it, so every frame it shot for a
## while was a light swing with no ring in it at all and the only complaint was
## one line of FAIL text. If this file ever prints "the hold never armed" again,
## check this constant against `HeroCombat._tick_heavy_button` before touching
## the effect.
const HOLD := "heavy"

## When each shot is taken, seconds after the button comes up. SWEEP_TIME is
## 0.48 and sparks live 0.42 s, so the first five show the moving head and the
## last three show the tail burning down.
const SHOTS: Array[float] = [0.06, 0.14, 0.24, 0.34, 0.46, 0.60, 0.75, 1.00]
const CONTACT_EPS := 0.0001

## Long enough for the swing, the mote lifetimes and the glow fade to all be over
## before the next hold starts, so no shot has the previous spin in it.
const SETTLE := 2.2


func run(rig) -> void:
	var out: String = rig.arg("out", "/tmp/rings/x.png").get_base_dir()
	var scene: Node = rig.scene()

	var hero: Node3D = scene.get_node_or_null(^"Hero") as Node3D
	if hero == null:
		rig.fail("RINGS no Hero in the scene")
		return
	var combat: Node = hero.get(&"combat")
	if combat == null:
		rig.fail("RINGS no HeroCombat on the Hero")
		return

	await rig.wait_frames(24)

	# Stable construction names are part of the proof: the shot must fail rather
	# than silently photographing an old ring with no requested seam.
	var contact_head := combat.get_node_or_null(
		^"SpinVfx/SpinSweep/ContactHead") as MeshInstance3D
	if contact_head == null:
		rig.fail("RINGS missing SpinVfx/SpinSweep/ContactHead")
		return
	var sparks := combat.get_node_or_null(
		^"SpinVfx/SpinSweep/SpinSparks") as GPUParticles3D
	if sparks == null:
		rig.fail("RINGS missing SpinVfx/SpinSweep/SpinSparks")
		return
	var fails := 0
	if contact_head.position.distance_to(sparks.position) > CONTACT_EPS:
		rig.fail("RINGS contact head and sparks do not share one local position")
		fails += 1

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
		rig.fail("RINGS no camera")
		return
	# GameCamera re-derives its transform every physics frame, so it has to be
	# switched off before it is placed or it walks straight back to the shoulder.
	cam.set_physics_process(false)

	var charge_time: float = float(combat.get(&"charge_time"))
	var seam_checked := false

	# --- 1. from above: is it a CIRCLE, and how much of one is lit at once? -----
	for i in SHOTS.size():
		_look(cam, centre, Vector3(0.0, 4.4, 3.4))
		await rig.wait_seconds(SETTLE)
		_refill()
		await rig.hold_seconds([HOLD], charge_time + 0.35)
		await rig.wait_seconds(SHOTS[i])
		# 140 ms leaves enough normal-delta frames for sparse sparks to separate
		# while the first-turn contact head is still plainly visible.
		if i == 1:
			seam_checked = true
			if contact_head.position.distance_to(sparks.position) > CONTACT_EPS:
				rig.fail("RINGS release moved head and spark emitter off their shared point")
				fails += 1
			if not contact_head.visible or not sparks.emitting:
				rig.fail("RINGS contact head and spark emitter were not active together")
				fails += 1
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
		_refill()
		await rig.hold_seconds([HOLD], charge_time + 0.35)
		await rig.wait_seconds(t)
		await rig.capture(out.path_join("r_edge_%d_%03dms.png" % [i, int(t * 1000.0)]))
	if not seam_checked:
		rig.fail("RINGS never checked the moving contact seam")
		fails += 1

	print("RINGS %s (fails=%d)" % ["OK" if fails == 0 else "FAIL", fails])


## Park the camera at `centre + offset` looking at `centre`. Re-applied before
## every shot: the capture stall is not the only thing that can move a camera,
## and a lookdev frame taken from somewhere unknown is not evidence.
func _look(cam: Camera3D, centre: Vector3, offset: Vector3) -> void:
	cam.global_position = centre + offset
	cam.look_at(centre, Vector3.UP)


## Every lookdev beat spends a real spin. Refill the finite trip budget so later
## labelled frames cannot silently degrade into tap-heavy swings.
func _refill() -> void:
	Game.fill_magic()
	Game.stamina = Game.max_stamina
	Bus.stamina_changed.emit(Game.stamina, Game.max_stamina)
