extends SceneTree
## One-shot asset bake for the shared enclosed-valley terrain. The image-model
## heightmap is source art; exterior rooms ship and render these saved meshes.

const SOURCE: Texture2D = preload("res://assets/terrain/enclosed_valley_heightmap.png")
const OUT_DIR := "res://assets/terrain"


func _init() -> void:
	var standalone := EnclosedValleyTerrain.bake_meshes(
		SOURCE, 58.0, 440.0, -9.0, 38.0, 20.0, 14.0,
		PI * 0.75, 0.0)
	var combined := EnclosedValleyTerrain.bake_meshes(
		SOURCE, 112.0, 560.0, -9.0, 42.0, 23.0, 16.0,
		0.0, 0.0)
	if standalone.size() != 3 or combined.size() != 3:
		push_error("enclosed valley bake returned %d standalone / %d combined bands" \
			% [standalone.size(), combined.size()])
		quit(1)
		return
	for band: StringName in [&"inner", &"mid", &"far"]:
		var path := "%s/enclosed_valley_%s.res" % [OUT_DIR, band]
		var error := ResourceSaver.save(standalone[band], path)
		if error != OK:
			push_error("failed to save %s: %s" % [path, error_string(error)])
			quit(1)
			return
		print("baked ", path)
		var combined_path := "%s/enclosed_valley_combined_%s.res" % [OUT_DIR, band]
		error = ResourceSaver.save(combined[band], combined_path)
		if error != OK:
			push_error("failed to save %s: %s" % [combined_path, error_string(error)])
			quit(1)
			return
		print("baked ", combined_path)
	quit()
