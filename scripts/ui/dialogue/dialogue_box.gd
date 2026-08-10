class_name DialogueBox
extends Control
## Somebody talking to you: the JRPG two-shot.
##
##     ┌──────────────────────────────────────────────────────────┐
##     │                  (the yard, still there)                 │
##     │                                       ┌────────────────┐ │
##     │                                       │ Trade   Forge  │ │  ← only on
##     │  ▟█▙                            ▟█▙   │ Leave          │ │    the last
##     │ ▟███▙   ┌───────────────────┐  ▟███▙  └────────────────┘ │    page
##     │▟█████▙  │ BRANNOC           │ ▟██████▙                   │
##     │█████████│ I've the finest…▍ │ ████████                   │
##     └─────────└───────────────────┘────────────────────────────┘
##       listener          the words          the speaker
##
## Three decisions, and the first is the one everything else follows from.
##
## **The figures are PAINTED PORTRAITS**, one per person, in
## `assets/ui/portraits/`. The first cut of this box rendered the game's own rigs
## through two `DollStage`s cropped to the head and shoulders, on the reasoning
## that a model can never disagree with the person standing in front of you. It
## worked, and it was replaced the same day (2026-08-10, owner's call) because the
## owner drew six portraits: a rest-pose rig with its arms out is a mannequin, and
## a drawing of somebody with an expression on their face is a character. The
## drawings win, and the rule they cost is written down in `docs/CONTRACT.md`.
##
## The listener is on the LEFT and the speaker on the RIGHT, which is the
## arrangement the reference uses and the one that puts the name plate under the
## face it belongs to. A speaker with no portrait gets no figure at all, and that
## is a legible degrade rather than a reason to refuse the conversation.
##
## **The words are typed, and the button that types them is the button that opened
## the box.** One key does the whole conversation: it fills the line if it is
## still arriving, turns the page if it is not, and picks the option when the
## options are up. A player never has to learn a second verb to get out of a
## conversation they entered with `interact`.
##
## **This file does not choose a line and does not play a sound.** `DialogueDb`
## owns the words, `Voice` owns the mouth, and the caller hands over the pages
## already resolved (`DialogueDb.speak`). The box is a presenter -- which is what
## lets the same box carry the arrival beat, a counter's greeting and a farewell
## with no branch in it.
##
## Input is POLLED, not event-driven, for `TradeScreen._tick_input`'s reason: the
## capture harness drives the game with `Input.action_press`, which sets action
## state and synthesises no `InputEvent` (CLAUDE.md §3), so a screen that only
## listens to `_unhandled_input` is a screen no director can exercise.

const UITheme := preload("res://scripts/ui/ui_theme.gd")

## Characters a second. Fast enough that a reader is never waiting on a short
## line, slow enough that the arrival of the words is a thing you watch -- the
## whole point of typing them rather than showing them.
const TYPE_CPS := 46.0
## Seconds the caret takes to blink once it is done.
const CARET_PERIOD := 0.9

## Layer 55: over the HUD (50) and under the trade screen (60). The order only
## matters for the one frame in which a Trade choice has opened a counter and this
## box has not yet been freed.
const LAYER := 55

## The portrait's height as a fraction of the viewport, and the panel's width.
## Every number in `_layout` is a fraction, because the harness shoots at 1280x720
## and the game is played at 1080p and above: a box laid out in pixels is a box
## that is either unreadable in one of those or clipped in the other.
const BUST_H := 0.49
const PANEL_W := 0.52
const PANEL_H := 0.24
## How far the panel floats off the bottom edge, and how far the figures hang PAST
## it. The portraits are cut by the frame on purpose -- a figure standing clear of
## the bottom edge reads as a sticker on a shelf.
const PANEL_BOTTOM := 0.055
const BUST_BLEED := 0.03
## How far each portrait hangs off its own side of the frame, as a fraction of its
## width. They are drawn square and the interesting half is the face: pushing the
## outer shoulder off the edge is what makes them read as people leaning into the
## shot rather than as two cards laid on the screen.
const BUST_OFF := 0.14


## Who is talking, as `DialogueDb`/`Voice` key them. Read by the directors.
var speaker: StringName = &""

var _pages: PackedStringArray = PackedStringArray()
var _page: int = 0
## Characters revealed so far, as a float so the reveal is frame-rate independent.
var _typed: float = 0.0
var _choices: Array = []
var _cursor: int = 0
var _choosing: bool = false
var _closing: bool = false
## Latched the instant a choice is taken. A focused Button ALSO fires `pressed`
## off Godot's own `ui_accept` handling, so a keyboard confirm arrives twice --
## once through `_tick_input` and once through the Button. This is what makes the
## second one a no-op rather than a second purchase screen.
var _picked: bool = false
var _age: float = 0.0

var _panel: PanelContainer
var _choice_panel: PanelContainer
var _choice_box: VBoxContainer
## Null when that person has no portrait -- see `_portrait`.
var _left: TextureRect
var _right: TextureRect
var _scrim: TextureRect
var _name: Label
var _body: RichTextLabel
var _hint: Label
var _caret: Label

## What the pointer was doing before this box took the viewport. Same contract as
## `TradeScreen`: saved and put back, never forced, because the box can be up over
## a captured-pointer garrison or over a menu that already freed it.
var _prev_mouse: int = Input.MOUSE_MODE_VISIBLE


## Put `who` on the screen saying `pages`, with `choices` at the end of them.
##
## `choices` is an Array of Dictionaries:
##   label : String    what the option says. Directors find an option by this.
##   meta  : String    the right-hand column -- the counter's name, a cost.
##   act   : Callable  run when it is picked. **Returns the pages to say next**
##                     (a `PackedStringArray`), or nothing to end the conversation.
##
## An empty `choices` is a statement rather than a question: the last page ends
## the conversation on the next press. That is the arrival beat.
##
## Returns null for an empty `pages`, and that is not an error -- it is a speaker
## with nothing written for this cue, and an empty box is a UI that appeared in
## order to say nothing. Callers should treat null as "they had nothing to say".
static func open(host: Node, who: StringName, pages: PackedStringArray,
		choices: Array = []) -> DialogueBox:
	if pages.is_empty():
		return null
	var layer := CanvasLayer.new()
	layer.name = "DialogueLayer"
	layer.layer = LAYER
	var box := DialogueBox.new()
	box.speaker = who
	box._pages = pages
	box._choices = choices
	layer.add_child(box)
	host.get_tree().current_scene.add_child(layer)
	return box


func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_STOP
	process_mode = Node.PROCESS_MODE_ALWAYS
	UITheme.prewarm()
	theme = UITheme.theme()
	_build()
	_fit()
	get_viewport().size_changed.connect(_fit)
	_show_page(0)

	_prev_mouse = Input.mouse_mode
	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
	# Blocks the interact button AND the hero's own movement -- `hero.gd` reads
	# `Prompt.blocked` for exactly this. A conversation you can walk away from
	# mid-sentence while the other person keeps talking is not a conversation.
	Prompt.block(self)
	# The HUD stands down for the length of a conversation, and it does that
	# ITSELF off this signal (`Hud._refresh_visibility`) rather than being switched
	# off from here -- it forces its own `visible` on every tree change, and the
	# construction of this box is a tree change.
	Bus.screen_opened.emit(&"dialogue")


func _exit_tree() -> void:
	Prompt.unblock(self)
	Bus.screen_closed.emit(&"dialogue")
	# ...unless something else took the screen on the way out, which is exactly
	# what the Trade option does: `TradeScreen._ready` has already run by the time
	# this box is freed, so it has already saved the pointer state THIS box set and
	# put the pointer where it wants it. Restoring here would capture the cursor
	# under an open shop.
	if not Prompt.screen_up:
		Input.mouse_mode = _prev_mouse as Input.MouseMode


func close() -> void:
	if _closing:
		return
	_closing = true
	var layer := get_parent()
	if layer is CanvasLayer:
		layer.queue_free()
	else:
		queue_free()


# --- What a director asks ------------------------------------------------------
## Five readers and one verb, because a director has to be able to hold a
## conversation without knowing how this file is built. `tools/shoot.gd`'s `talk`
## finds this node by `has_method("choice_labels")` -- it is loaded with `-s` and
## cannot name a `class_name` (CLAUDE.md §3) -- so these names are the interface
## and renaming one silently unhooks every counter director.

## True while the line is still arriving.
func is_typing() -> bool:
	return not _choosing and _body != null \
		and _body.visible_characters < _body.text.length()


## True once the options are up.
func is_choosing() -> bool:
	return _choosing


func choice_labels() -> PackedStringArray:
	var out := PackedStringArray()
	for c in _choices:
		out.append(String(c.get("label", "")))
	return out


## Which option the cursor is on, or -1 before the options are up.
func choice_index() -> int:
	return _cursor if _choosing else -1


## The name on the plate.
func speaker_name() -> String:
	return _name.text if _name != null else ""


## The page being said, in full, whether or not it has finished arriving.
func text() -> String:
	return _body.text if _body != null else ""


# --- The conversation ----------------------------------------------------------

func _show_page(i: int) -> void:
	_page = clampi(i, 0, maxi(_pages.size() - 1, 0))
	_body.text = _pages[_page] if _page < _pages.size() else ""
	_body.visible_characters = 0
	_typed = 0.0


## Replace what is being said and start typing again. The choices come down with
## it: this is the farewell, and there is nothing left to choose.
func _say(pages: PackedStringArray) -> void:
	_pages = pages
	_choosing = false
	_choice_panel.visible = false
	_show_page(0)


## Put the options up. Built here rather than at `_ready` so the panel cannot be
## on screen half a beat before the line that asks the question.
func _ask() -> void:
	if _choices.is_empty():
		close()
		return
	_choosing = true
	UITheme.clear_children(_choice_box)
	for i in _choices.size():
		var c: Dictionary = _choices[i]
		var row := UiKit.verb_row(_choice_box, {
			"label": String(c.get("label", "")),
			"meta": String(c.get("meta", "")),
			# The first option is the one you came here for -- Trade at a counter.
			# Exactly one primary per panel, which is the kit's rule.
			"primary": i == 0,
			"on_press": _take.bind(i),
		})
		if row != null:
			# The mouse is also a cursor. Without this, hovering one row and
			# clicking it would take the option the STICK was on.
			row.mouse_entered.connect(_point_at.bind(i))
	_choice_panel.visible = true
	# The panel is as tall as its rows and the rows only exist now, so the layout
	# has to be re-asked. Deferred as well as immediate: `get_combined_minimum_size`
	# is exact once the container has sorted, and the first answer on the frame the
	# rows are added can be a row short.
	_layout()
	_layout.call_deferred()
	_point_at(0)


func _point_at(i: int) -> void:
	if not _choosing or _choices.is_empty():
		return
	_cursor = clampi(i, 0, _choices.size() - 1)
	var row := _choice_box.get_child(_cursor) as Control
	if row != null and row.get_viewport() != null:
		row.grab_focus()


## Take option `i` -- the one place a choice happens, whether it arrived from the
## stick, the mouse or a director.
func _take(i: int) -> void:
	if _picked or _closing or i < 0 or i >= _choices.size():
		return
	_picked = true
	var act: Variant = (_choices[i] as Dictionary).get("act")
	var next := PackedStringArray()
	if act is Callable and (act as Callable).is_valid():
		var said: Variant = (act as Callable).call()
		if said is PackedStringArray:
			next = said
		elif said is Array:
			next = PackedStringArray(said)
	if next.is_empty():
		close()
		return
	# There is more to hear, so the box stays and the next press ends it. The
	# latch comes off with the options -- nothing left to pick twice.
	_picked = false
	_choices = []
	_say(next)


## The one button. See the header: fill the line, turn the page, ask the question,
## take the answer, in that order, because that is the order they can be wanted in.
func _advance() -> void:
	if _choosing:
		_take(_cursor)
		return
	if is_typing():
		_body.visible_characters = _body.text.length()
		_typed = float(_body.text.length())
		return
	if _page + 1 < _pages.size():
		_show_page(_page + 1)
		return
	_ask()


# --- Input ---------------------------------------------------------------------
## Both edges start DISARMED. The press that opened this box is still down --
## `Npc.activate` fires on it -- and without arming it would fill the first line
## and turn the page on the same frame the box appeared.

const REPEAT_DELAY := 0.38
const REPEAT_RATE := 0.11

var _armed_accept: bool = false
var _armed_cancel: bool = false
var _repeat: float = 0.0


func _tick_input(delta: float) -> void:
	if _closing:
		return

	# Cancel ENDS IT, wherever you are. Not "pick Leave" -- the farewell is what
	# you get for choosing to say goodbye, and this is the button for a player who
	# has decided the conversation is over.
	var cancel := Input.is_action_pressed(&"ui_cancel") or Input.is_action_pressed(&"pause")
	if not cancel:
		_armed_cancel = true
	elif _armed_cancel:
		_armed_cancel = false
		close()
		return

	var accept := Input.is_action_pressed(&"ui_accept") or Input.is_action_pressed(&"interact")
	if not accept:
		_armed_accept = true
	elif _armed_accept:
		_armed_accept = false
		_advance()
		return

	if not _choosing:
		return
	var step := _step(delta)
	if step != 0:
		_point_at((_cursor + step + _choices.size()) % _choices.size())


## Which way the stick went this frame, one press or one repeat tick. Down and up
## only: the options are a column, and a list that also answered left/right would
## be claiming a shape it does not have.
func _step(delta: float) -> int:
	var d := 0
	if Input.is_action_just_pressed(&"ui_down"):
		d = 1
	elif Input.is_action_just_pressed(&"ui_up"):
		d = -1
	if d != 0:
		_repeat = REPEAT_DELAY
		return d
	var held := 0
	if Input.is_action_pressed(&"ui_down"):
		held = 1
	elif Input.is_action_pressed(&"ui_up"):
		held = -1
	if held == 0:
		return 0
	_repeat -= delta
	if _repeat > 0.0:
		return 0
	_repeat = REPEAT_RATE
	return held


func _process(delta: float) -> void:
	_age += delta
	_tick_input(delta)
	if _closing:
		return

	if not _choosing and _body.visible_characters < _body.text.length():
		_typed += TYPE_CPS * delta
		_body.visible_characters = mini(int(_typed), _body.text.length())

	_paint_chrome()


func _paint_chrome() -> void:
	# The caret says "there is more, and it is waiting for you". It cannot come up
	# while the line is still arriving -- that would be the box asking for a press
	# it is going to swallow.
	var waiting := not _choosing and not is_typing()
	_caret.visible = waiting and sin(_age * TAU / CARET_PERIOD) > -0.2

	# Buttons off the live InputMap through `Glyph`, never written in: this line
	# said ENTER on a pad in every screen that learned it the hard way.
	var cap := Glyph.cap(&"interact")
	if cap.is_empty():
		cap = "E"
	var leave := Glyph.cap(&"ui_cancel")
	if leave.is_empty():
		leave = "ESC"
	if _choosing:
		_hint.text = "%s  Choose      %s  Leave" % [cap, leave]
	elif is_typing():
		_hint.text = "%s  Skip" % cap
	elif _page + 1 < _pages.size() or not _choices.is_empty():
		_hint.text = "%s  Next" % cap
	else:
		_hint.text = "%s  Close" % cap


# --- Construction --------------------------------------------------------------

func _build() -> void:
	# A dark wash rising from the bottom edge, and NOT the trade screen's
	# full-frame dim. You are being spoken to in the middle of the yard and the
	# yard should stay lit; what the wash is for is the text, which has to be
	# legible over whatever happens to be behind the panel -- at the smith that is
	# a lit forge.
	_scrim = TextureRect.new()
	_scrim.texture = _wash()
	_scrim.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	_scrim.stretch_mode = TextureRect.STRETCH_SCALE
	_scrim.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(_scrim)

	# The listener is always the hero: this box is somebody talking to YOU.
	_left = _portrait(&"hero")
	_right = _portrait(speaker)

	_build_panel()
	_build_choices()


## One painted figure, or null when nobody drew them.
##
## `KEEP_ASPECT` and no clipping, because `_layout` gives the rect the drawing's
## own aspect: there is nothing to crop. The only thing that cuts a portrait is
## the bottom of the screen, and that one is on purpose.
func _portrait(who: StringName) -> TextureRect:
	var path := DialogueDb.portrait_of(who)
	if path.is_empty() or not ResourceLoader.exists(path):
		return null
	var art := load(path) as Texture2D
	if art == null:
		return null
	var rect := TextureRect.new()
	rect.texture = art
	rect.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	rect.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT
	rect.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(rect)
	return rect


func _build_panel() -> void:
	_panel = PanelContainer.new()
	_panel.name = "Words"
	UITheme.style_panel(_panel, UITheme.FRAME_FACE_SOLID)
	add_child(_panel)

	var col := VBoxContainer.new()
	col.add_theme_constant_override("separation", 4)
	_panel.add_child(col)

	# The plate. Their NAME, not their trade -- the sign over their head says
	# SMITH and this says who is wearing the apron (`DialogueDb`).
	_name = Label.new()
	_name.text = DialogueDb.name_of(speaker)
	UITheme.apply_text_style(_name, UITheme.TYPE_H2, UITheme.ACCENT)
	_name.visible = not _name.text.is_empty()
	col.add_child(_name)

	# A RichTextLabel and not a Label, for `visible_characters` -- and with
	# `VC_CHARS_AFTER_SHAPING`, which is the whole trick. The default shapes only
	# the visible part, so a word that is about to wrap JUMPS to the next line as
	# its last character arrives, and every line of dialogue in the game would
	# twitch while it typed.
	_body = RichTextLabel.new()
	_body.bbcode_enabled = false
	_body.fit_content = false
	_body.scroll_active = false
	_body.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_body.visible_characters_behavior = TextServer.VC_CHARS_AFTER_SHAPING
	_body.size_flags_vertical = Control.SIZE_EXPAND_FILL
	_body.add_theme_font_size_override("normal_font_size", UITheme.TYPE_PARAGRAPH_1["size"] + 3)
	_body.add_theme_color_override("default_color", UITheme.TEXT)
	_body.mouse_filter = Control.MOUSE_FILTER_IGNORE
	col.add_child(_body)

	var foot := HBoxContainer.new()
	foot.add_theme_constant_override("separation", 12)
	col.add_child(foot)

	_hint = Label.new()
	_hint.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	UITheme.apply_text_style(_hint, UITheme.TYPE_CAPTION, UITheme.TEXT_DIM)
	foot.add_child(_hint)

	_caret = Label.new()
	_caret.text = "▼"
	UITheme.apply_text_style(_caret, UITheme.TYPE_CAPTION, UITheme.ACCENT)
	foot.add_child(_caret)


## The options, in their own small panel ABOVE the words.
##
## Not inside the box, which was the first cut: the choice list appears on the
## last page and only then, so putting it in the box means the box grows a third
## of its height at the exact moment the player is reading it, and the sentence
## they are half way through moves. `FooterToast` states the same rule for the
## same reason. Its own panel, floated over the top-right corner, costs one node
## and the words never move.
func _build_choices() -> void:
	_choice_panel = PanelContainer.new()
	_choice_panel.name = "Options"
	UITheme.style_panel(_choice_panel, UITheme.FRAME_FACE_SOLID)
	_choice_panel.visible = false
	add_child(_choice_panel)

	_choice_box = VBoxContainer.new()
	_choice_box.add_theme_constant_override("separation", 2)
	_choice_panel.add_child(_choice_box)


# --- Layout --------------------------------------------------------------------
## Everything is a fraction of the viewport (see the constants). A Control
## parented straight to a CanvasLayer is outside the viewport's Control tree, so
## anchors never resolve and it sits at (0,0) -- `TradeScreen` has the same note.
## Size from the viewport, and do it again whenever the window changes.

func _fit() -> void:
	position = Vector2.ZERO
	size = get_viewport_rect().size
	_layout()


func _layout() -> void:
	var w := size.x
	var h := size.y
	if w <= 0.0 or h <= 0.0:
		return

	# The wash covers the bottom half, which is where everything is.
	var wash_h := h * 0.56
	_scrim.position = Vector2(0.0, h - wash_h)
	_scrim.size = Vector2(w, wash_h)

	# Sized off the HEIGHT of the frame and hung off both sides. Height and never
	# width, because a wide window must not make the faces grow -- the panel
	# between them is what the extra width belongs to.
	#
	# **The rect takes the DRAWING's aspect** rather than being square. They are
	# not all square (the alchemist is 786x1024) and a square rect crops whichever
	# axis overflows -- which flattened the top of his hood off with a straight
	# horizontal line, the one edge in the frame that could not be anything but a
	# bug. Matching the aspect means the fit is exact and nothing is cropped
	# except by the bottom of the screen, which is deliberate.
	var bleed := h * BUST_BLEED
	for rect: TextureRect in [_left, _right]:
		if rect == null or rect.texture == null:
			continue
		var art := rect.texture.get_size()
		var bust := Vector2(h * BUST_H * (art.x / maxf(art.y, 1.0)), h * BUST_H)
		var x := -bust.x * BUST_OFF if rect == _left else w - bust.x * (1.0 - BUST_OFF)
		rect.position = Vector2(x, h + bleed - bust.y)
		rect.size = bust

	var panel := Vector2(maxf(w * PANEL_W, 480.0), maxf(h * PANEL_H, 158.0))
	_panel.position = Vector2((w - panel.x) * 0.5, h - panel.y - h * PANEL_BOTTOM)
	_panel.size = panel

	# Sitting on the panel's top-right corner, growing upward: the list is short
	# and its length is not known until it is built, so it is pinned by the corner
	# that does not move.
	var opts := Vector2(maxf(panel.x * 0.42, 220.0), _choice_box.get_combined_minimum_size().y + 24.0)
	_choice_panel.position = Vector2(_panel.position.x + panel.x - opts.x,
		_panel.position.y - opts.y - 10.0)
	_choice_panel.size = opts


## A vertical wash, transparent at the top and near-black at the bottom. Built
## once for the whole game: it is four pixels wide and the 9-patch stretch is
## what makes it a gradient across the frame.
static var _wash_tex: ImageTexture = null


static func _wash() -> ImageTexture:
	if _wash_tex != null:
		return _wash_tex
	var h := 64
	var img := Image.create(4, h, false, Image.FORMAT_RGBA8)
	for y in h:
		var t := float(y) / float(h - 1)
		# Squared, so the dark stays down at the bottom where the panel is instead
		# of drawing a grey band across the middle of the courtyard.
		var a := t * t * 0.72
		for x in 4:
			img.set_pixel(x, y, Color(Pal.VOID.r, Pal.VOID.g, Pal.VOID.b, a))
	_wash_tex = ImageTexture.create_from_image(img)
	return _wash_tex
