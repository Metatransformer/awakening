class_name LoadingCard
extends Control
## The screen you look at on the way down. It names the place.
##
## Raised by `Flow` on every transition INTO the dungeon -- walking in from the
## garrison and taking the stair both -- and it is the whole of what a loading
## screen is for here: the fade already covered the load, so this covers the
## *arrival*. Between two rooms of identical grey stone, the only thing that
## says you went somewhere is being told where you went.
##
## **The backdrop is `ui_title_backdrop.gdshader`, and it was written for this.**
## The shader shipped with the foundation commit, its own header describes "a
## dark stone wall with something burning below it ... full-screen behind a menu
## on the loading frame", `DESIGN.md` §10 lists it against "floor title" -- and
## nothing had ever instanced it. It draws three analytic terms and an ordered
## dither, no texture and no sampling, which is exactly what you want running
## while a scene is being built.
##
## The fire sits BELOW the frame on purpose (`glow_center.y = 1.16`), so the
## title reads as something lit from underneath by a room you have not reached
## yet. That is why the type sits high on the card and the bottom two thirds are
## left to the glow: the empty space under the name is the effect, not padding.
##
## Drawn with PixelFont and Pal for the reason every other screen in this project
## is (docs/STYLEGUIDE.md bans the engine's fallback font). `Flow` owns its life:
## it is created after the veil is black, it is what the new floor fades in from,
## and it frees itself when that fade ends.

const BACKDROP := preload("res://assets/shaders/ui_title_backdrop.gdshader")

## Baselines as fractions of the card, top-down. The title is above centre
## rather than on it: centred type over a bottom glow puts the brightest part of
## the frame directly behind the words.
const TITLE_Y := 0.300
const RULE_Y := 0.392
const LEVEL_Y := 0.424

## Reference px at 720p, run through `Pal.px` like every other measurement here.
const TITLE_PX := 32.0
const LEVEL_PX := 16.0
## Half the width of the rule between the two lines, as a fraction of the card.
const RULE_HALF := 0.115

var title: String = Prog.NAME
var level_line: String = ""

var _ink: Control


## Put one on `layer` (a CanvasLayer that already exists -- Flow's) and return it.
## The caller owns it from here: it is a plain child and it does not free itself.
static func open(layer: CanvasLayer, name_line: String,
		sub_line: String) -> LoadingCard:
	var card := LoadingCard.new()
	card.title = name_line
	card.level_line = sub_line
	layer.add_child(card)
	return card


func _ready() -> void:
	name = "LoadingCard"
	# It covers the screen while the world underneath is being replaced, but it is
	# not a UI you can touch. Prompt.blocked is what actually holds input during a
	# transition; this only makes sure the card never eats a click on its own.
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	process_mode = Node.PROCESS_MODE_ALWAYS
	_fit()
	get_viewport().size_changed.connect(_fit)

	# The backdrop is a child rather than something this node's `_draw` produces,
	# because a CanvasItem draws itself BEFORE its children -- a full-rect shader
	# drawn by a child of the text would cover the text. Order here is the whole
	# z-order: wall first, ink second.
	var wall := ColorRect.new()
	wall.name = "Backdrop"
	wall.mouse_filter = Control.MOUSE_FILTER_IGNORE
	wall.set_anchors_preset(Control.PRESET_FULL_RECT)
	var mat := ShaderMaterial.new()
	mat.shader = BACKDROP
	wall.material = mat
	add_child(wall)

	_ink = Control.new()
	_ink.name = "Ink"
	_ink.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_ink.set_anchors_preset(Control.PRESET_FULL_RECT)
	_ink.draw.connect(_draw_ink)
	add_child(_ink)


## A Control parented straight to a CanvasLayer is outside the viewport's Control
## tree, so its anchors never resolve and it sits at size (0,0). Size it from the
## viewport and keep it there. (Same note as RunEndScreen and TradeScreen.)
func _fit() -> void:
	position = Vector2.ZERO
	size = get_viewport_rect().size
	if _ink != null:
		_ink.queue_redraw()


func _draw_ink() -> void:
	var s := size
	if s.x < 1.0 or s.y < 1.0:
		return

	var t := Pal.px(TITLE_PX / PixelFont.H, s.y)
	PixelFont.draw_centred(_ink, title, Vector2(s.x * 0.5, s.y * TITLE_Y), t,
		Pal.BONE)

	# A rule, not a box. The name wants something under it that says "and now the
	# specifics", and a full panel border here would fight the vignette the
	# backdrop is already drawing.
	var rule_w := s.x * RULE_HALF
	_ink.draw_rect(Rect2(s.x * 0.5 - rule_w, s.y * RULE_Y, rule_w * 2.0,
		Pal.px(1.0, s.y)), Color(Pal.ASH, 0.8))

	if not level_line.is_empty():
		var lt := Pal.px(LEVEL_PX / PixelFont.H, s.y)
		PixelFont.draw_centred(_ink, level_line,
			Vector2(s.x * 0.5, s.y * LEVEL_Y), lt, Pal.MOTH)
