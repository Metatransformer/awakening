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
##   Bus.request_shake.emit(0.55, 0.18)
##
## **What the strength number means.** Trauma is 0..1 where 1 is the biggest
## shake the game has, and it is SQUARED before it moves anything -- so pick from
## the top half of the range or you are asking for nothing. The first pass here
## used 0.24-0.45, which reads as "a bit less than half" and arrives as 6-20% of
## an already-subtle maximum; measured peak on a landed blow was 2%, i.e. a shake
## that shipped, passed its own beat, and could not be seen. Landing a blow is
## ~0.5, killing something ~0.65, being hit yourself ~0.8.
##
## A CanvasLayer rather than a plain Node because the damage vignette is a
## full-screen overlay this owns. Layer 60: above the HUD (50), below the pause
## menu (100) and Flow's fade (200) -- being hurt should tint the health bar, and
## should not tint the menu you opened to look at it.

## Frustum shift at full trauma. h_offset moves the VIEW, not the eye, so the
## shake can be as big as it likes without ever clipping the boom through a wall
## the way shoving global_position would.
##
## MEASURED, not guessed: `tools/directors/monster_feel.gd` renders the same shot
## at a set of offsets and cross-correlates them, and at 1280x720 with this
## project's FOV one unit of h_offset is **37.5 px** of image shift. The first
## pass here used 0.16 -- six pixels at FULL trauma, and 0.6 px on a landed blow,
## which is why every attempt to fix the shake by raising the request numbers
## made no visible difference. 1.4 puts full trauma at ~50 px per axis, which is
## a hit you feel, and a landed blow at ~5 px, which is a hit you notice.
const MAX_OFFSET := 1.4
## Roll at full trauma, radians. ~4 degrees; roll reads far more strongly than
## offset does, so this does not scale with it.
const MAX_ROLL := 0.07
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
## The slow-motion, on the same wall clock and for the same reason (`_tick_stop`).
## Zero when time is running at speed.
var _slow_until: int = 0
var _slow_scale: float = 1.0
## The roll `_tick_shake` computed this frame, restamped just before the draw.
## See `_on_pre_draw`.
var _roll: float = 0.0

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
	# MUST be set, and this is the whole shake. FastNoiseLite defaults to 0.01,
	# where one feature of the field spans ~100 coordinate units -- and a 0.16 s
	# shake walks `_noise_t` a grand total of 3.5. So every sample came off one
	# nearly-flat patch: the camera did not wobble, it leaned by whatever
	# arbitrary value sat at that spot, and the measured peak was 8% of the
	# nominal maximum. At 1.0 a unit of `_noise_t` is a feature, which is what
	# makes SHAKE_HZ mean hertz and the comment on it true.
	_noise.frequency = 1.0

	# The ROLL has to be written last or it does not exist.
	#
	# `GameCamera` works in _physics_process and ends on `look_at(pivot, UP)`,
	# which rebuilds the entire basis and throws any rotation.z away. h_offset and
	# v_offset are separate properties and survive that; the roll does not, so it
	# lived or died on whether Feel happened to run after the camera in a given
	# frame, and measured 1.6% of its ceiling where the offsets measured 20%.
	# frame_pre_draw is the one hook that is guaranteed to be after every process
	# and physics callback and before the picture is taken.
	RenderingServer.frame_pre_draw.connect(_on_pre_draw)

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
	_apply_time_scale()


## Run the world slow for `seconds` of REAL time. `scale` is the multiplier —
## `K.SLOWMO_SCALE` (0.34) is the perfect dodge's dip.
##
## Two things make this different from `hitstop` rather than a softer version of
## it, and both are why they are separate verbs:
##
##   A stop is an IMPACT and a dip is a WINDOW. `hitstop` takes the later of two
##   deadlines because three deaths in one frame must not multiply; this takes
##   the SLOWER of two scales and the later deadline, because a second perfect
##   dodge inside the first one's window is a player doing well and the answer to
##   that is more time, not a scale that fights itself.
##
##   A stop outranks a dip. Land a blow during the slow-motion and the world
##   still freezes on the contact frame — see `_apply_time_scale`, which is why
##   neither of these writes `Engine.time_scale` directly any more. The first cut
##   did, and a hit-stop that ended inside a dip restored time to 1.0 and
##   cancelled the rest of the dodge's reward.
##
## `seconds` is wall-clock and NOT scaled by `scale`: 0.55 s at a third speed is
## 0.55 s of the player's life either way, and it is the player's life this is
## budgeted against.
func slowmo(scale: float, seconds: float) -> void:
	if seconds <= 0.0:
		return
	var s := clampf(scale, 0.05, 1.0)
	var until := Time.get_ticks_msec() + int(seconds * 1000.0)
	if _slow_until == 0:
		_slow_scale = s
	else:
		_slow_scale = minf(_slow_scale, s)
	_slow_until = maxi(_slow_until, until)
	_apply_time_scale()


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
	_tick_time()
	_tick_shake(delta)
	_tick_vignette(delta)


## Both clocks end on the WALL clock, not on a timer awaited inside the freeze.
## `Engine.time_scale = 0.0` stops the entire simulation, so a stop that failed
## to lift would not be a missing effect -- it would be the game hung solid with
## no error printed. This runs every idle frame (delta is 0 while frozen, but the
## callback still fires) and cannot be orphaned by a scene change or a pause.
##
## The dip is on the same clock for the same reason and for one more: a slow
## world would stretch a timer measured in game seconds by exactly the factor
## the dip applies, so `K.SLOWMO_TIME` would mean 1.6 s rather than 0.55.
func _tick_time() -> void:
	var now := Time.get_ticks_msec()
	var changed := false
	if _stop_until != 0 and now >= _stop_until:
		_stop_until = 0
		changed = true
	if _slow_until != 0 and now >= _slow_until:
		_slow_until = 0
		_slow_scale = 1.0
		changed = true
	if changed:
		_apply_time_scale()


## The ONE writer of `Engine.time_scale`, and the only reason both effects can
## coexist. A stop outranks a dip: an impact frame during a perfect dodge's
## slow-motion still freezes, and when it lifts, time goes back to the DIP
## rather than to full speed.
##
## Written as a recompute from both deadlines rather than as "restore what it
## was", because "what it was" is a fourth piece of state and the bug it ships
## is a world permanently stuck at a third speed after two effects overlap once.
func _apply_time_scale() -> void:
	if _stop_until != 0:
		Engine.time_scale = 0.0
	elif _slow_until != 0:
		Engine.time_scale = _slow_scale
	else:
		Engine.time_scale = 1.0


func _tick_shake(delta: float) -> void:
	var cam := get_viewport().get_camera_3d()
	if cam == null:
		return

	# Walked EVERY frame, not only while a shake is live.
	#
	# Advancing it only during a shake means every shake starts at the same place
	# in the field, so every blow in the game shakes identically -- and if that
	# one spot happens to sit near a zero crossing on a line, that component is
	# missing from every blow, for ever. It did: the roll measured 1% of its
	# ceiling while the offsets measured 20%, not because the roll was being lost
	# but because its line was flat exactly where every shake began. Free-running
	# makes each blow sample an arbitrary phase, which is both correct and the
	# reason two hits in a row do not feel like the same hit twice.
	var walk := delta if Engine.time_scale > 0.0 else 1.0 / 60.0
	_noise_t += walk * SHAKE_HZ

	if _trauma <= 0.0:
		# Only write when there is something to clear, so a game with no shake in
		# it is not fighting anything else that might want these.
		if cam.h_offset != 0.0 or cam.v_offset != 0.0 or cam.rotation.z != 0.0:
			cam.h_offset = 0.0
			cam.v_offset = 0.0
			cam.rotation.z = 0.0
		_roll = 0.0
		return

	# Wall-clock delta: while a hit-stop is up, `delta` is zero, and a shake that
	# froze mid-wobble for the length of the stop would read as a stutter rather
	# than as impact. The two effects fire together on almost every blow.
	var dt := delta if Engine.time_scale > 0.0 else 1.0 / 60.0
	_trauma = maxf(0.0, _trauma - _decay * dt)

	# Squared: a small trauma should be a twitch, not a small earthquake.
	var s := _trauma * _trauma
	# Three parallel lines through the field, none of them through the origin.
	# Simplex noise is exactly zero at (0,0) and `_noise_t` starts at zero, so
	# sampling (t, 0) would make the first shake of a session begin from a dead
	# frame -- which reads as the shake having missed rather than started. The
	# lines are far apart so the two offsets and the roll are decorrelated; three
	# samples of one line would be a lean, not a wobble.
	cam.h_offset = MAX_OFFSET * s * _noise.get_noise_2d(_noise_t, 11.7)
	cam.v_offset = MAX_OFFSET * s * _noise.get_noise_2d(_noise_t, 53.1)
	_roll = MAX_ROLL * s * _noise.get_noise_2d(_noise_t, 97.3)
	cam.rotation.z = _roll


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


## Restamp the roll onto the camera immediately before the frame is drawn.
##
## Everything else the shake does is a property `look_at` does not touch, so it
## survives being written in _process. The roll is a rotation, and the camera
## rebuilds its whole basis every physics tick -- so the only way the tilt
## reaches the picture is to write it after everyone else has finished and
## before the picture is taken. This is not belt and braces; without it the roll
## is simply absent from most frames.
func _on_pre_draw() -> void:
	if _roll == 0.0:
		return
	var cam := get_viewport().get_camera_3d()
	if cam != null:
		cam.rotation.z = _roll
