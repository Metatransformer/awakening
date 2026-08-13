extends RefCounted
## Runtime proof for issue #207's shared native viewport contract.
##
##   tools/quiet.sh --path . -s tools/shoot.gd -- \
##     --scene=res://scenes/_smoke.tscn \
##     --director=res://tools/directors/renderer_contract.gd \
##     --out=/tmp/renderer-contract/x.png --warmup=4


func run(rig) -> void:
	await rig.wait_frames(4)
	var viewport: Viewport = rig.root
	rig.check(not Settings.internal_render,
		"production starts with the legacy internal renderer disabled")
	rig.check(is_equal_approx(Settings.resolution_scale, 1.0),
		"the production resolution preference starts at 1.0")
	rig.check(Settings._screen != null and not Settings._screen.enabled()
		and not rig.root.disable_3d,
		"native root 3D is active and ScreenPresent is parked")
	if Settings._screen != null:
		rig.check(Settings._screen._sub != null
			and Settings._screen._sub.screen_space_aa == Viewport.SCREEN_SPACE_AA_SMAA,
			"the opt-in ScreenPresent viewport also uses SMAA")
	rig.check(is_equal_approx(viewport.scaling_3d_scale, 1.0),
		"production starts at native 3D scale")
	rig.check(viewport.screen_space_aa == Viewport.SCREEN_SPACE_AA_SMAA,
		"the root viewport uses SMAA")
	rig.check(int(viewport.msaa_3d) == Settings.msaa,
		"root 3D MSAA follows the existing user preference")
	rig.check(Settings.max_msaa() == 1,
		"the only optional MSAA supplement is 2x")
	rig.check(not viewport.use_taa and not viewport.use_debanding,
		"TAA and debanding remain off")
	rig.check(viewport.msaa_2d == Viewport.MSAA_DISABLED,
		"UI remains outside 2D MSAA")
	rig.check(viewport.positional_shadow_atlas_size == 2048,
		"the live positional shadow atlas starts at 2048")
	rig.check(int(ProjectSettings.get_setting(
		"rendering/lights_and_shadows/directional_shadow/size")) == 4096,
		"directional shadow atlas is 4096")
	rig.check(int(ProjectSettings.get_setting(
		"rendering/lights_and_shadows/positional_shadow/atlas_size")) == 2048,
		"positional shadow atlas is 2048")
	rig.check(int(ProjectSettings.get_setting(
		"rendering/anti_aliasing/quality/screen_space_aa")) \
		== int(Viewport.SCREEN_SPACE_AA_SMAA),
		"the project default is SMAA")
	rig.check(int(ProjectSettings.get_setting(
		"rendering/anti_aliasing/quality/msaa_3d")) == 0,
		"the project 3D MSAA default is off")
	rig.check(int(ProjectSettings.get_setting(
		"rendering/textures/default_filters/anisotropic_filtering_level")) \
		== int(Viewport.ANISOTROPY_4X),
		"the project default is 4x anisotropy")
	rig.check(not bool(ProjectSettings.get_setting(
		"rendering/textures/default_filters/use_nearest_mipmap_filter")),
		"world mipmap filtering is linear")
	rig.check(viewport.get_camera_3d() != null,
		"the root viewport retains the live 3D camera")
	if rig.fails == 0:
		print("RENDERER CONTRACT OK")
