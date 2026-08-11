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
	_cast_a_freed_object(rig)
	# A script error ABORTS THE FUNCTION IT HAPPENS IN and returns to the caller,
	# which is the whole reason #47 got away with it: the failure was inside
	# `Hero.lock_target`, so the director above it carried on, checked everything
	# it meant to check, and printed its OK line. Put the error in `run` itself
	# and this director would stop here -- which would prove nothing, because the
	# case that matters is the one where the run looks finished.
	print("selftest: still going, and about to claim a pass")
	await rig.capture(rig.out_base())
	print("SELFTEST OK -- every check passed")


func _cast_a_freed_object(rig) -> void:
	var doomed := Node3D.new()
	rig.scene().add_child(doomed)
	doomed.free()
	var revived := doomed as Node3D
	print("selftest: unreachable -- the cast above aborted this function, %s" % [revived])
