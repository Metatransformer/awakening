extends CanvasLayer
## Autoload `Feel`. The screen's reaction to a blow: hit-stop, camera shake, and
## the red edge flash when it is the hero who got hit.
##
## `Bus.request_hitstop` and `Bus.request_shake` were declared in event_bus.gd
## and emitted from four places -- the hero, the enemy, the arrow, the sword --
## with **no listener anywhere in the project**. Every impact in the game has
## been asking for a reaction and getting silence. This is that listener. It is
## the same hole `Sfx` filled for `request_sfx`, and it is filled the same way:
## one implementation, chosen here, so nothing else owns a piece of the feel.
##
## Emit at it. Never hold a reference to it:
##   Bus.request_hitstop.emit(K.HITSTOP_LIGHT)
##   Bus.request_shake.emit(0.4, 0.2)
##
## A CanvasLayer rather than a plain Node because the damage vignette is a
## full-screen overlay this owns. Layer 60: above the HUD (50), below the pause
## menu (100) and Flow's fade (200) -- being hurt should tint the health bar, and
## should not tint the menu you opened to look at it.

## Frustum shift at full trauma, in the camera's near-plane units. Small on
## purpose: h_offset moves the VIEW, not the eye, so it stays subtle and never
## clips the boom through a wall the way shoving global_position would.
const MAX_OFFSET := 0.16
## Roll at full trauma, radians.
const MAX_ROLL := 0.055
## How fast the noise field is walked. Too slow reads as a drift, too fast as
## static; this is roughly a 20 Hz wobble.
const SHAKE_HZ := 22.0
## Ceiling on a single stop. Nothing in the game asks for more than HITSTOP_HEAVY
## (9 frames), and a bug that asked for a thousand would freeze the game solid.
const MAX_STOP_SECONDS := 0.25

var _trauma: float = 0.0
var _decay: float = 1.0
var _noise: FastNoiseLite
var _noise_t: float = 0.0
## Wall-clock deadline for the current hit-stop, in msec. Zero when not stopped.
var _stop_until: int = 0

var _vignette: ColorRect
var _vig: float = 0.0
## Mirrored so a health signal reads as "he was hurt" rather than "health is now
## N" -- Bus.player_health_changed carries no delta. Seeded from Game for the
## reason heat.gd documents: nothing emits the signal at spawn, so a sentinel
## makes the FIRST blow of a session look like a heal and eat its own feedback.
var _last_quarters: int = 0


func _ready() -> void:
	layer = 60
	# The stop has to be able to end while the world is frozen, and the vignette
	# has to be able to fade while the pause menu is up.
	process_mode = Node.PROCESS_MODE_ALWAYS

	_noise = FastNoiseLite.new()
	_noise.noise_type = FastNoiseLite.TYPE_SIMPLEX
	_noise.seed = 0x5EED

	_vignette = ColorRect.new()
	_vignette.name = "Vignette"
	_vignette.color = Color(Pal.VITAL, 0.0)
	_vignette.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_vignette.set_anchors_preset(Control.PRESET_FULL_RECT)
	_vignette.material = _edge_only()
	add_child(_vignette)

	Bus.request_hitstop.connect(hitstop)
	Bus.request_shake.connect(shake)
	Bus.player_health_changed.connect(_on_health_changed)
	# Both ends of a run heal the hero, and neither is a blow. Re-read rather
	# than let the heal register as a delta.
	Bus.run_started.connect(func(_s: int) -> void: _last_quarters = Game.quarters)
	Bus.run_ended.connect(func(_e: bool, _c: Dictionary, _v: int) -> void:
		_last_quarters = Game.quarters)
	_last_quarters = Game.quarters


# --- The public verbs -------------------------------------------------------

## Freeze the world for `frames` at 60 Hz. See K.HITSTOP_LIGHT / _HEAVY.
##
## GLOBAL, deliberately. A hit-stop that freezes only the two participants is
## the right call in a big simulation -- valenfeld does exactly that, because
## stopping its whole world would stop unrelated AI a hundred metres away. This
## game is one room at a time with one hero in it, so the honest impact frame is
## the cheap one: everything stops, including him, which is what makes a landed
## blow feel like it cost something.
##
## Requests do not stack, they take the LATER deadline. Three enemies dying in
## the same frame is a common event and it must not multiply into a freeze.
func hitstop(frames: int) -> void:
	if frames <= 0:
		return
	var seconds := minf(float(frames) / 60.0, MAX_STOP_SECONDS)
	var until := Time.get_ticks_msec() + int(seconds * 1000.0)
	_stop_until = maxi(_stop_until, until)
	Engine.time_scale = 0.0


## Shake the camera. `strength` is trauma in 0..1 (0.2 a tap, 0.5 a solid hit,
## 1.0 a boss landing), `duration` roughly how long it takes to bleed off.
##
## Additive, because two things exploding at once is worse than one. Clamped,
## because it has to stay legible.
func shake(strength: float, duration: float) -> void:
	# The accessibility setting is a multiplier, and zero means the player turned
	# it off. Hit-stop, flashes and sound still play -- shake is the one that
	# makes people ill, so it is the only one this gate touches.
	var scale := Settings.camera_shake
	if scale <= 0.0:
		return
	_trauma = clampf(_trauma + strength * scale, 0.0, 1.0)
	# Bleed off the trauma there is NOW over `duration`, not a notional full
	# tank over `duration`. `1.0 / duration` is the tempting form and it is
	# wrong: the enemy asks for (0.22, 0.12), which under that rate loses 0.139
	# of trauma per frame and is gone in 1.6 frames -- a shake nobody could see
	# and, at 60 Hz, one the capture rig could not catch either. Scaling by the
	# trauma present makes `duration` mean what the caller plainly meant by it.
	_decay = _trauma / maxf(duration, 0.05)


## Red at the edges of the screen. Fired by the health signal below rather than
## called, so nothing has to remember to ask.
func damage_vignette(strength: float = 0.55) -> void:
	_vig = maxf(_vig, clampf(strength, 0.0, 0.85))


# --- Frame ------------------------------------------------------------------

## `_process`, not `_physics_process`, and that is load-bearing for the roll.
##
## GameCamera does its work in `_physics_process` and ends it with
## `look_at(pivot, Vector3.UP)`, which writes the WHOLE basis and therefore
## zeroes any roll that was already on it. Godot runs every physics step of a
## frame before that frame's `_process`, so a roll written here is the last word
## before the frame is drawn. Write it from physics and the camera silently eats
## it -- the offsets would still work and only the roll would go missing, which
## is the kind of half-working that takes an afternoon to see.
func _process(delta: float) -> void:
	_tick_hitstop()
	_tick_shake(delta)
	_tick_vignette(delta)


## The stop ends on the WALL clock, not on a timer awaited inside the freeze.
## `Engine.time_scale = 0.0` stops the entire simulation, so a stop that failed
## to lift would not be a missing effect -- it would be the game hung solid with
## no error printed. This runs every idle frame (delta is 0 while frozen, but the
## callback still fires) and cannot be orphaned by a scene change or a pause.
func _tick_hitstop() -> void:
	if _stop_until == 0:
		return
	if Time.get_ticks_msec() < _stop_until:
		return
	_stop_until = 0
	Engine.time_scale = 1.0


func _tick_shake(delta: float) -> void:
	var cam := get_viewport().get_camera_3d()
	if cam == null:
		return
	if _trauma <= 0.0:
		# Only write when there is something to clear, so a game with no shake in
		# it is not fighting anything else that might want these.
		if cam.h_offset != 0.0 or cam.v_offset != 0.0 or cam.rotation.z != 0.0:
			cam.h_offset = 0.0
			cam.v_offset = 0.0
			cam.rotation.z = 0.0
		return

	# Wall-clock delta: while a hit-stop is up, `delta` is zero, and a shake that
	# froze mid-wobble for the length of the stop would read as a stutter rather
	# than as impact. The two effects fire together on almost every blow.
	var dt := delta if Engine.time_scale > 0.0 else 1.0 / 60.0
	_trauma = maxf(0.0, _trauma - _decay * dt)
	_noise_t += dt * SHAKE_HZ

	# Squared: a small trauma should be a twitch, not a small earthquake.
	var s := _trauma * _trauma
	# Three parallel lines through the field, none of them through the origin.
	# Simplex noise is exactly zero at (0,0), and `_noise_t` starts at zero and
	# only advances while a shake is live -- so sampling (t, 0) would make the
	# FIRST shake of a session begin from a dead frame, which reads as the shake
	# having missed rather than as it having started.
	cam.h_offset = MAX_OFFSET * s * _noise.get_noise_2d(_noise_t, 11.7)
	cam.v_offset = MAX_OFFSET * s * _noise.get_noise_2d(_noise_t, 53.1)
	cam.rotation.z = MAX_ROLL * s * _noise.get_noise_2d(_noise_t, 97.3)


func _tick_vignette(delta: float) -> void:
	if _vig <= 0.0:
		if _vignette.color.a != 0.0:
			_vignette.color.a = 0.0
		return
	var dt := delta if Engine.time_scale > 0.0 else 1.0 / 60.0
	_vig = maxf(0.0, _vig - dt * 1.9)
	_vignette.color.a = _vig


func _on_health_changed(quarters: int, _max_quarters: int) -> void:
	var hurt := quarters < _last_quarters
	_last_quarters = quarters
	if hurt:
		damage_vignette()


## A radial gradient in a shader rather than a generated texture: the fade has to
## follow the window when it resizes, and a baked 192px image stretched to
## ultrawide bands visibly. Also nothing to import.
func _edge_only() -> ShaderMaterial:
	var sh := Shader.new()
	sh.code = """
shader_type canvas_item;

void fragment() {
	// UV is 0..1 across the rect, so this is aspect-stretched on purpose -- the
	// dark band should hug the frame's edges, not describe a circle inside it.
	float d = distance(UV, vec2(0.5)) * 1.41421;
	COLOR.a *= smoothstep(0.45, 1.0, d);
}
"""
	var m := ShaderMaterial.new()
	m.shader = sh
	return m
