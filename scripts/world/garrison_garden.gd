class_name GarrisonGarden
extends Node3D
## The authored playable layer inside GarrisonCompound's fenced garden.
## Children present Game's stable slots; this manager owns placement and the one
## garrison-state subscription that repaints them.

const PLOT_POSITIONS: Array[Vector3] = [
	Vector3(-8.85, 0.03, 0.65),
	Vector3(-7.15, 0.03, 0.65),
	Vector3(-8.85, 0.03, 2.35),
	Vector3(-7.15, 0.03, 2.35),
]
const TREE_POSITIONS: Array[Vector3] = [
	Vector3(-10.35, 0.03, -2.55),
	Vector3(-10.25, 0.03, 3.25),
]

var plots: Array[GardenPlot] = []
var tree_sites: Array[FruitTreeSite] = []


func _ready() -> void:
	_build_children()
	Game.garrison_changed.connect(_repaint)
	_repaint()


func _build_children() -> void:
	for slot: int in GardenDb.PLOT_SLOTS:
		var plot := GardenPlot.new()
		plot.name = StringName("GardenPlot%d" % (slot + 1))
		plot.configure(slot)
		plot.position = PLOT_POSITIONS[slot]
		add_child(plot)
		plots.append(plot)
	for slot: int in GardenDb.TREE_SITES:
		var site := FruitTreeSite.new()
		site.name = StringName("FruitTreeSite%d" % (slot + 1))
		site.configure(slot)
		site.position = TREE_POSITIONS[slot]
		add_child(site)
		tree_sites.append(site)


func _repaint() -> void:
	for plot: GardenPlot in plots:
		plot.repaint()
	for site: FruitTreeSite in tree_sites:
		site.repaint()
