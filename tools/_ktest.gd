extends SceneTree
## Throwaway: prints the OOT-derived constants so a human can sanity-check the
## unit conversion. Safe to delete.
func _initialize() -> void:
	print("U=%.6f m/unit  (%.1f units/m)" % [K.U, 1.0 / K.U])
	print("RUN=%.2f  ROLL=%.2f  SIDEHOP=%.2f m/s" % [K.RUN_SPEED, K.ROLL_SPEED, K.SIDEHOP_SPEED])
	print("CAM dist %.2f..%.2f m  pitch %.0f  fov %.0f/%.0f/%.0f" % [K.CAM_DIST_MIN, K.CAM_DIST_MAX, K.CAM_PITCH, K.CAM_FOV, K.CAM_FOV_LOCK, K.CAM_FOV_PARALLEL])
	print("LOCK acquire %.2f m  break %.2f m  cone +-%.0f" % [K.LOCK_RANGE, K.LOCK_BREAK_RANGE, K.LOCK_CONE])
	print("HOOK %.2f m  BOMB r=%.2f m fuse=%.1fs owner=%s" % [K.HOOK_RANGE, K.BOMB_RADIUS, K.BOMB_FUSE, K.BOMB_HURTS_OWNER])
	print("letterbox %.4f over %.2fs   iframes %.2fs" % [K.LETTERBOX_FRAC, K.LETTERBOX_TIME, K.IFRAME_TIME])
	print("speed curve: 0.2->%.2f 0.5->%.2f 0.9->%.2f 1.0->%.2f" % [K.speed_for_stick(0.2), K.speed_for_stick(0.5), K.speed_for_stick(0.9), K.speed_for_stick(1.0)])
	quit(0)
