class_name BossKey
extends SmallKey
## The gate-room prize that admits one boss chamber. Its body, reveal, hover,
## trigger, persistence and pickup ceremony are all SmallKey's; only the size,
## finish and inventory grant differ.


func rest_scale() -> float:
	return 2.0


func key_hue() -> Color:
	return Pal.GOLD


func key_material() -> StandardMaterial3D:
	var gold := _glow_mat(Pal.GOLD, 2.4)
	gold.metallic = 0.78
	gold.roughness = 0.30
	return gold


func grant_pickup() -> void:
	Game.add_boss_key()
