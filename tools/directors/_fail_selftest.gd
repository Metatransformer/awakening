extends RefCounted
## A director that FAILS ON PURPOSE, so card #72's exit-code gate can be watched
## firing. The sibling of `_error_selftest.gd`, which does the same job for
## #63's SCRIPT ERROR gate.
##
##   tools/quiet.sh --path . -s tools/shoot.gd -- \
##     --scene=res://scenes/_smoke.tscn \
##     --director=res://tools/directors/_fail_selftest.gd \
##     --out=/tmp/failtest/x.png --warmup=4
##
## Expect `DIRECTOR FAIL 3` and **exit 66**. Pass `--pass` and expect
## `DIRECTOR OK` and exit 0 -- that is the null case, and it is the half that
## catches a gate which fails everything. CLAUDE.md §2: a director pointed at a
## known answer in only one direction has been half tested, and every one of the
## six instrument defects this repo has paid for was a false POSITIVE.
##
## It exercises all three routes into the tally at once, because the harvest of
## the older two is the part with a live risk of double-counting:
##
##   1. `rig.fail()`      -- the protocol
##   2. `_fails`          -- harvested from the director, 66 files already keep one
##   3. `return N`        -- an int return from `run()`
##
## Keep it failing. A gate nobody can watch fire is a gate nobody has tested.

## Route 2. `shoot.gd._harvest_failures` reads this by name.
var _fails := 0


func run(rig) -> int:
	await rig.wait_frames(2)
	await rig.capture(rig.out_base())

	if rig.arg("pass", "") != "":
		# The null case. Nothing reports anything, the counters stay at zero, and
		# a correct gate has to let this through -- including the `_fails` harvest,
		# which must not read a DECLARED-and-zero counter as a failure.
		print("FAILTEST: the passing case -- expect DIRECTOR OK and exit 0")
		return 0

	rig.fail("route 1: reported through rig.fail()")
	_fails += 1
	print("FAILTEST: route 2 -- _fails is now %d, for shoot.gd to harvest" % _fails)

	# And the thing that made #72 possible in the first place: a director can
	# print whatever it likes and still be finished. This line is the shape of all
	# 136 old ones, and on its own it must NOT move the tally -- the count below
	# has to come from the routes above, or the gate is a grep after all.
	print("FAILTEST FAIL -- a bare print, which is not a report")

	print("FAILTEST OK -- every check passed")  # a lie, on purpose, exactly like #47's
	return 1  # route 3
