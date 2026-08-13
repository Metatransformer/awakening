#!/bin/zsh
# Audit the failure-reporting contract for every runnable shoot.gd director.
#
# A director is self-tallied when shoot.gd can receive its failures through one
# of the three routes documented in `_harvest_failures`: rig.fail/check, an int
# returned by run(), or a top-level integer `_fails` / `_fail` / `fails` field.
# Merely printing FAIL or ABORT is not a route; that director exits 0.
#
# Some look-dev and measurement sheets deliberately make no binary claim. Their
# output is a contact sheet or a table for a human to judge, and their FAIL text
# only says the requested observation could not be produced. Keep those names
# explicit here: otherwise a new assertion can hide by being mistaken for
# look-dev, which is the exact hazard this audit exists to expose (card #141).

set -u

ROOT=${ZL_ROOT:-${0:A:h:h}}
DIRECTORS=$ROOT/tools/directors

# Visual decision sheets: the frames or printed measurements are the result.
# None has a pass/fail threshold for the thing it observes.
OBSERVATION_ONLY=(
	bow_grip
	bow_stow_lookdev
	dodge_lookdev
	flurry_lookdev
	fog_crawl
	internal_res
	jump_pose_trace
	npc_lookdev
	npc_raw
	race_lookdev
	ranged_anim_lookdev
	run_lookdev
	shield_arm_fit
	slam_lookdev
	strafe_lookdev
	swing_lookdev
	sword_grip
)

typeset -A observation_names
for name in "${OBSERVATION_ONLY[@]}"; do
	observation_names[$name]=1
done

typeset -a tallied observation unwired
for file in $DIRECTORS/*.gd(N); do
	# Helpers such as _hud_layout.gd report into the director that calls them;
	# shoot.gd cannot run a file without run(rig), so it is not a director here.
	rg -q '^func run\([^,()]+\)([[:space:]]*->[^:]*)?:' $file || continue
	name=${file:t:r}

	if rg -q '^[[:space:]]*[^#].*(_?rig)\.(fail|check)\(' $file \
			|| rg -q '^var (_fails|_fail|fails)(: int)?[[:space:]]*(:=|=)[[:space:]]*0([[:space:]]*#.*)?$' $file \
			|| rg -q '^func run\([^,()]+\)[[:space:]]*->[[:space:]]*int:' $file; then
		tallied+=($name)
	elif (( ${+observation_names[$name]} )); then
		observation+=($name)
	elif rg -q '^[[:space:]]*print\(\(?"[^"]*(FAIL|ABORT)' $file; then
		unwired+=($name)
	else
		observation+=($name)
	fi
done

print -r -- "SELF-TALLIED (${#tallied})"
for name in "${tallied[@]}"; do
	print -r -- "  $name"
done

print -r -- "OBSERVATION-ONLY (${#observation})"
for name in "${observation[@]}"; do
	print -r -- "  $name"
done

print -r -- "PRINTS FAILURE BUT EXITS 0 (${#unwired})"
for name in "${unwired[@]}"; do
	print -r -- "  $name"
done

if (( ${#unwired} > 0 )); then
	print -u2 -r -- "director_selftally: FAILED -- migrate the directors above to rig.fail()"
	exit 1
fi

print -r -- "director_selftally: OK -- every assertion-bearing director reaches the gate"
