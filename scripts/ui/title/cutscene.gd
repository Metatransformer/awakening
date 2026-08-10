class_name Cutscene
extends Control
## A still image, a recorded narration, and the words of it on screen.
##
## The whole cutscene system, and it is deliberately this small. `docs/SCOPE.md`
## §1 freezes cutscenes at **0** and calls the opening "the existing `Flow` veil
## held down over one recorded line" -- this does not break that count, it is
## the same held veil with a painting behind it and the line written out. There
## is no camera here, no choreography, no actor: a `TextureRect`, a `Label`, and
## a clock.
##
## ## The clock, and the one thing it has to get right
##
## **The unit is a BEAT: one line of text.** A beat may name the recorded `cue`
## it starts; a beat that names none rides on the clip the beat above it
## started, and the clip's length is divided evenly between everything sharing
## it. That is the "50%" in the opening below -- one 15-second take covering two
## sentences gets 7.5 seconds each.
##
## An even split is a stand-in and it is written down as one, because the real
## rule is **one clip per line**: give a beat its own `cue` and it is timed by
## its own recording, exactly, with no arithmetic. Every beat in a future scene
## carrying its own cue is the state this is built to arrive at, and it needs no
## change here -- a group of one divides by one.
##
## ## Why the length is taken from `Voice.say` and not awaited
##
## Same reason `Garrison._open_the_game` gives: `Voice.say` hands back the length
## of what it started the instant it starts it, and hands back 0.0 when the file
## is missing. Awaiting a `finished` that a missing import would never emit is
## how a broken asset becomes a screen the player cannot leave. A missing clip
## here costs a cutscene timed off reading speed instead -- see `READ_*`.
##
## ## Who owns it
##
## `Flow`, and only `Flow` (docs/CONTRACT.md §7). It is raised onto Flow's own
## CanvasLayer at 200 the way `LoadingCard` is, over a world that is paused and
## already built behind it, and the fade out of this image IS the fade into the
## garrison. A cutscene that was its own scene would be a second thing calling
## `change_scene_to_file`.

## Emitted when the last beat has had its time, or when the player skips.
signal finished

## The opening. Kael, the road, and the garrison he has been posted to.
##
## **One clip, two beats.** `narrator/opening` is a single take covering both
## sentences, so the second beat carries no cue and the take is halved. When the
## line is re-cut as two files this becomes two cues and the arithmetic stops
## happening at all.
const OPENING := {
	"image": "res://assets/ui/title/intro_trail.jpg",
	"speaker": &"narrator",
	"beats": [
		{
			"cue": &"opening",
			"text": "We encounter our hero Kael on this unremarkable day, "
				+ "in the outskirts of the Vale.",
		},
		{
			"text": "Having been recently assigned for military duty with the "
				+ "Highbridge guard, there is no telling what adventures await.",
		},
	],
}

## Fallback timing, for a beat whose clip is missing or silent. A comfortable
## read is around 12 characters a second and no line should be gone before it
## can be looked at, hence the floor.
const READ_PER_CHAR := 1.0 / 12.0
const READ_MIN := 2.4
## Beat between one line leaving and the next arriving. Short: it is a breath in
## the narration, not a scene change.
const GAP := 0.35
## How long a line takes to arrive and to leave.
const TEXT_FADE := 0.30

## Seconds before a press will skip. The same guard `RunEndScreen` puts on its
## button and for the same reason: the ENTER that pressed NEW GAME must not also
## dismiss the thing that NEW GAME opened. The skip is release-armed as well --
## this is for the player still leaning on the key.
const SETTLE := 0.6

## Letterbox depth, as a fraction of the frame's height, top and bottom. It is
## what says "this is being shown to you" before a word is read, and it is also
## honest housekeeping: the art is 3:2 and the window is not, so the bars cover
## the crop rather than pretending it is not happening.
const BAR := 0.085

## The scene being played. One of the constants above, or the same shape.
var scene: Dictionary = OPENING

var _beats: Array = []
var _i: int = -1
## Seconds left on the current beat.
var _hold: float = 0.0
## The share of the current clip one beat gets. Held across beats because every
## beat after a cued one reuses it -- that IS the split.
var _share: float = 0.0
var _age: float = 0.0
var _armed: bool = false
var _done: bool = false

var _label: Label
var _hint: Label


## Put one on `layer` (Flow's) and return it. The caller owns it: it does not
## free itself, because the caller is fading it out and needs it alive to do so.
static func open(layer: CanvasLayer, config: Dictionary) -> Cutscene:
	var c := Cutscene.new()
	c.scene = config
	layer.add_child(c)
	return c


func _ready() -> void:
	name = "Cutscene"
	# ALWAYS, because the world underneath is stopped for the whole of this --
	# the garrison is already built behind the image and a running one would be a
	# hero walking off a gamepad's stick drift for fifteen seconds while his
	# player reads (CLAUDE.md §3, and the same trap `Flow`'s LOAD_HOLD closes).
	# `Voice` is ALWAYS for the same reason, so the narration keeps talking.
	process_mode = Node.PROCESS_MODE_ALWAYS
	# It covers the screen, but it is not a UI you can touch. `Prompt.blocked` is
	# what actually holds input during a transition; this only makes sure the
	# image never eats a click on its own.
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	UITheme.prewarm()
	theme = UITheme.theme()
	_fit()
	get_viewport().size_changed.connect(_fit)

	_beats = scene.get("beats", [])
	_build()
	_advance()


## A Control parented straight to a CanvasLayer is outside the viewport's Control
## tree, so its anchors never resolve and it sits at size (0,0). Size it from the
## viewport and keep it there. (Same note as `LoadingCard` and `RunEndScreen`.)
func _fit() -> void:
	position = Vector2.ZERO
	size = get_viewport_rect().size


# --- Look -------------------------------------------------------------------

func _build() -> void:
	var art := TextureRect.new()
	art.name = "Plate"
	art.mouse_filter = Control.MOUSE_FILTER_IGNORE
	art.set_anchors_preset(Control.PRESET_FULL_RECT)
	# COVERED and not KEEP_ASPECT: the paintings are 3:2 and no window is, so the
	# choice is crop or letterbox-with-grey-in-it. A full-bleed crop with the
	# bars drawn ON TOP is the one that reads as a shot rather than as an image
	# that did not fit.
	art.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	art.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_COVERED
	var path: String = scene.get("image", "")
	if ResourceLoader.exists(path):
		art.texture = load(path) as Texture2D
	else:
		# Loud. A cutscene with no plate is a black screen with subtitles on it,
		# and it should read as the missing import it is.
		push_error("Cutscene: no such image %s" % path)
	add_child(art)

	# The scrim, bottom only. The narration sits over the darkest third of both
	# paintings already; this is the guarantee, not the effect. A flat wash over
	# the whole frame would grey out the sky, which is the half of these images
	# worth showing.
	var scrim := TextureRect.new()
	scrim.name = "Scrim"
	scrim.mouse_filter = Control.MOUSE_FILTER_IGNORE
	scrim.set_anchors_preset(Control.PRESET_FULL_RECT)
	scrim.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	scrim.stretch_mode = TextureRect.STRETCH_SCALE
	var ramp := GradientTexture2D.new()
	ramp.fill_from = Vector2(0.0, 0.52)
	ramp.fill_to = Vector2(0.0, 1.0)
	var g := Gradient.new()
	g.set_color(0, Color(Pal.VOID, 0.0))
	g.set_color(1, Color(Pal.VOID, 0.88))
	ramp.gradient = g
	scrim.texture = ramp
	add_child(scrim)

	_bar(0.0)
	_bar(1.0 - BAR)

	# Centred in the bottom quarter, inside the bars and well clear of them.
	_label = Label.new()
	_label.name = "Line"
	_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_label.set_anchors_and_offsets_preset(Control.PRESET_BOTTOM_WIDE)
	_label.offset_left = 120.0
	_label.offset_right = -120.0
	_label.offset_top = -230.0
	_label.offset_bottom = -110.0
	_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	UITheme.apply_text_style(_label, UITheme.TYPE_PARAGRAPH_1, UITheme.TEXT)
	_label.add_theme_font_size_override("font_size", 22)
	# An outline as well as the scrim. Narration over a painting is the one place
	# in this game where the type sits on something that was not designed to have
	# type on it, and the sky behind a wrapped second line is not always dark.
	_label.add_theme_constant_override("outline_size", 6)
	_label.add_theme_color_override("font_outline_color", Color(Pal.VOID, 0.85))
	_label.modulate.a = 0.0
	add_child(_label)

	_hint = Label.new()
	_hint.name = "Skip"
	_hint.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_hint.set_anchors_and_offsets_preset(Control.PRESET_BOTTOM_WIDE)
	_hint.offset_top = -74.0
	_hint.offset_bottom = -44.0
	_hint.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	UITheme.apply_text_style(_hint, UITheme.TYPE_CAPTION, UITheme.TEXT_DIM)
	_hint.add_theme_constant_override("outline_size", 4)
	_hint.add_theme_color_override("font_outline_color", Color(Pal.VOID, 0.8))
	_hint.text = _skip_hint()
	_hint.modulate.a = 0.0
	add_child(_hint)


func _bar(top: float) -> void:
	var bar := ColorRect.new()
	bar.mouse_filter = Control.MOUSE_FILTER_IGNORE
	bar.color = Pal.VOID
	bar.anchor_left = 0.0
	bar.anchor_right = 1.0
	bar.anchor_top = top
	bar.anchor_bottom = top + BAR
	add_child(bar)


## "PRESS ENTER TO SKIP", or A on a pad. Read off the live InputMap through
## `Glyph` like every other prompt in the game, so a pad player is not told to
## press a key they do not have.
##
## `to_upper` on the WHOLE line, not on the template: `Glyph.long` hands back the
## key's own capitalisation ("Enter", "Space"), which came out as
## "PRESS Enter TO SKIP" the first time this was photographed.
func _skip_hint() -> String:
	var e := Glyph.event_for(&"ui_accept", Settings != null and Settings.using_pad)
	return "" if e == null else ("PRESS %s TO SKIP" % Glyph.long(e)).to_upper()


# --- The clock --------------------------------------------------------------

func _process(delta: float) -> void:
	if _done:
		return
	_age += delta

	# The skip offers itself once, quietly, after the first line has landed.
	if _age >= SETTLE + 1.2 and _hint.modulate.a < 1.0:
		_hint.modulate.a = minf(1.0, _hint.modulate.a + delta * 1.6)

	_hold -= delta
	if _hold <= 0.0:
		_advance()

	# Release-armed, and polled rather than event-driven, for the reason
	# `trade_screen.gd` sets out at length: `Input.action_press()` from the
	# capture harness never synthesises an InputEvent, so a screen that only
	# listens to `_unhandled_input` cannot be exercised by a director.
	var down := Input.is_action_pressed(&"ui_accept") \
		or Input.is_action_pressed(&"interact")
	if not down:
		_armed = true
	elif _armed and _age >= SETTLE:
		_armed = false
		skip()


## End it now. Stops the narration -- the line belongs to the image, and a voice
## that outlives the picture it was describing is worse than no voice.
func skip() -> void:
	if _done:
		return
	_done = true
	Voice.stop()
	finished.emit()


## Move to the next beat, or finish. Also the entry point for the first one.
func _advance() -> void:
	_i += 1
	if _i >= _beats.size():
		_done = true
		finished.emit()
		return

	var beat: Dictionary = _beats[_i]
	var text: String = beat.get("text", "")

	# A cue starts a new clip and therefore a new share. A beat with no cue is
	# riding the one above it and keeps the share already worked out -- that is
	# the whole of the split.
	if beat.has("cue"):
		var length := Voice.say(scene.get("speaker", &"narrator"), beat["cue"])
		_share = length / float(_group_size(_i)) if length > 0.0 else 0.0

	# 0.0 means the take is missing, and the scene is timed off reading speed
	# instead. Per beat rather than shared, because without a clip there is
	# nothing to divide and the honest number is how long this line takes to
	# read.
	_hold = _share if _share > 0.0 else maxf(READ_MIN, text.length() * READ_PER_CHAR)

	# Out, then in. The gap is inside this beat's time rather than added to it,
	# so the words track the take instead of drifting a third of a second later
	# with every line.
	var tw := create_tween().set_ignore_time_scale(true)
	tw.tween_property(_label, "modulate:a", 0.0, TEXT_FADE if _i > 0 else 0.0)
	tw.tween_callback(func() -> void: _label.text = text)
	tw.tween_interval(GAP if _i > 0 else 0.0)
	tw.tween_property(_label, "modulate:a", 1.0, TEXT_FADE)


## How many beats share the clip that beat `from` starts: itself, plus every
## beat after it that names no cue of its own.
func _group_size(from: int) -> int:
	var n := 1
	for j in range(from + 1, _beats.size()):
		if (_beats[j] as Dictionary).has("cue"):
			break
		n += 1
	return n
