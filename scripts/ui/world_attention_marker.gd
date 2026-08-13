class_name WorldAttentionMarker
extends WorldCaption
## The one world-attention mark. Owners decide whether attention is warranted;
## this class owns only the mark's shared HUD-canvas styling.

const BREATH_SPEED: float = 2.1
const BREATH_BASE: float = 0.88
const BREATH_DEPTH: float = 0.10

var _breath_age: float = 0.0


func _ready() -> void:
	text = "!"
	tint = Pal.GOLD
	ref_px = 16.0
	plate = true
	declutter = true
	super()


func _process(delta: float) -> void:
	_breath_age += delta
	alpha = BREATH_BASE + sin(_breath_age * BREATH_SPEED) * BREATH_DEPTH
