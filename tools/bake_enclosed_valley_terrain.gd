extends SceneTree
## One-shot asset bake for the shared enclosed-valley terrain. The image-model
## heightmap is source art; exterior rooms ship and render these saved meshes.

const SOURCE: Texture2D = preload("res://assets/terrain/enclosed_valley_heightmap.png")
const OUT_DIR := "res://assets/terrain"


func _init() -> void:
	var meshes := EnclosedValleyTerrain.bake_meshes(
		SOURCE, 58.0, 440.0, -9.0, 38.0, 20.0, 14.0,
		PI * 0.75, 0.0)
	if meshes.size() != 3:
		push_error("enclosed valley bake returned %d bands" % meshes.size())
		quit(1)
		return
	for band: StringName in [&"inner", &"mid", &"far"]:
		var path := "%s/enclosed_valley_%s.res" % [OUT_DIR, band]
		var error := ResourceSaver.save(meshes[band], path)
		if error != OK:
			push_error("failed to save %s: %s" % [path, error_string(error)])
			quit(1)
			return
		print("baked ", path)
	quit()
