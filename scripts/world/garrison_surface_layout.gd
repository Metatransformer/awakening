class_name GarrisonSurfaceLayout
extends RefCounted
## One coordinate authority for the standalone-outskirts compatibility shell
## and its embedded position inside the seamless garrison surface.
##
## Keep the numeric local landmarks here rather than preloading
## `OutskirtsHomestead`: Flow is an autoload, and making save migration depend on
## the scene package would turn a pure coordinate conversion into a load cycle.

const OUTSKIRTS_EMBED_YAW: float = -2.145101157
const LEGACY_BRIDGE_END := Vector3(-42.2, -0.18, 31.0)
## The fort ground slab ends at z=18. Mapping the bridge deck to the same line
## makes the collision seam continuous instead of leaving a one-metre crack.
const EMBEDDED_BRIDGE_END := Vector3(0.0, -0.10, 18.0)

## Authored Hero transform from the legacy standalone scene. Slots old enough
## not to carry a proven transform still need to arrive at this same doorway,
## expressed in the combined world's coordinates.
const LEGACY_ARRIVAL_POSITION := Vector3(-29.2, 0.17, 22.4)
const LEGACY_ARRIVAL_YAW: float = 0.0


static func outskirts_world_transform() -> Transform3D:
	var basis := Basis(Vector3.UP, OUTSKIRTS_EMBED_YAW)
	# Derive the origin from the authored seam instead of keeping a rounded
	# translation beside it. This yields approximately
	# `(3.101470933, 0.08, 70.270650255)` while the bridge endpoints stay exact.
	return Transform3D(basis, EMBEDDED_BRIDGE_END - basis * LEGACY_BRIDGE_END)


static func transform_legacy_position(legacy_position: Vector3) -> Vector3:
	return outskirts_world_transform() * legacy_position


static func transform_legacy_yaw(legacy_yaw: float) -> float:
	return wrapf(legacy_yaw + OUTSKIRTS_EMBED_YAW, -PI, PI)
