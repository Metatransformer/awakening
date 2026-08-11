extends RefCounted
## A director that is WRONG ON PURPOSE. It exists so the harness's stderr guard
## can be demonstrated firing, on demand, without breaking a real director.
##
##   tools/quiet.sh --path . -s tools/shoot.gd -- \
##     --scene=res://scenes/_smoke.tscn \
##     --director=res://tools/directors/_error_selftest.gd \
##     --out=/tmp/selftest/x.png --warmup=4
##
## It does what card #47's `boss_cistern.gd` did by accident: frees a node and
## then casts the dangling reference, which prints
## `SCRIPT ERROR: Trying to cast a freed object` and otherwise carries on. Every
## check below "passes", the director prints its own OK line, and shoot.gd exits
## 0 -- which is exactly the failure this self-test is here to catch. The guard
## in `tools/quiet.sh` is what turns that into a non-zero exit.
##
## Keep it dirty. A guard nobody can watch fire is a guard nobody has tested.


func run(rig) -> void:
	var doomed := Node3D.new()
	rig.scene().add_child(doomed)
	await rig.wait_frames(2)
	doomed.free()
	# The cast is the error. `doomed` still holds the freed instance id, and
	# `as Node3D` on it is what boss_cistern's lock-target path was doing.
	var revived := doomed as Node3D
	print("selftest: cast gave %s" % [revived])
	await rig.capture(rig.out_base())
	print("SELFTEST OK -- every check passed")
