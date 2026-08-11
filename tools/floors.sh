#!/bin/zsh
# The demo, all four floors. `docs/SCOPE.md` §1 freezes the count at 4.
#
#   tools/floors.sh                 levels 1 2 3 4
#   tools/floors.sh 2 4             just those
#   REPEAT=3 tools/floors.sh 1      the same floor three times, for a flaky check
#
# One `cistern_floor.gd --level=N` run per floor, sequentially, and a verdict
# table at the end. Sequential because four director windows at once on this Mac
# is what CLAUDE.md §2 is about.
set -u

HERE=${0:A:h}
ROOT=${HERE:h}
OUT=${OUT:-/tmp/floors}
REPEAT=${REPEAT:-1}
levels=(${@:-1 2 3 4})

# `cistern_floor` asserts BEHAVIOUR, not frame times, so a contended GPU costs it
# wall clock and nothing else -- and this Mac routinely has three or four agents
# running directors at once (CLAUDE.md §2), so a hard refusal here means waiting on
# somebody else's mvp_loop to finish. It is still worth SAYING, because a run that
# took four minutes instead of one is a fact about the machine and not the floor.
#
# The refusal stays for a full house. Four windows plus these is what made the Mac
# unusable in the first place, and `ALLOW_BUSY=1` is the way to say you meant it.
busy=$(ps -Ao pid,comm | grep -ci '[g]odot')
if [ $busy -ge 3 ] && [ -z "${ALLOW_BUSY:-}" ]; then
	print -u2 "floors.sh: $busy godot processes already up. Wait, or ALLOW_BUSY=1."
	exit 1
elif [ $busy -gt 0 ]; then
	print -- "floors.sh: $busy other godot run(s) up -- correctness is unaffected, the clock is not."
fi

mkdir -p $OUT
: > $OUT/summary.tsv

for n in $levels; do
	for r in {1..$REPEAT}; do
		tag=$n; [ $REPEAT -gt 1 ] && tag="$n.$r"
		log=$OUT/floor$tag.log
		print -n "  floor $tag … "
		timeout 500 $ROOT/tools/quiet.sh --path $ROOT -s $ROOT/tools/shoot.gd -- \
			--scene=res://scenes/rooms/dungeon.tscn \
			--director=res://tools/directors/cistern_floor.gd \
			--out=$OUT/$tag/x.png --warmup=60 --level=$n > $log 2>&1
		rc=$?
		name=$(grep -m1 '^FLOOR .* -- .* rooms' $log | sed -E 's/^FLOOR (.*) -- .*/\1/')
		bad=$(grep -c '^FLOOR FAIL ' $log)
		# SCRIPT ERROR gets its OWN column, because it is invisible in the other two.
		# `rc` cannot carry it: quiet.sh's 65 yields to a run that already failed on
		# its own, so a director that both errored and failed a check reports 66 and
		# nothing else. Floor 4 hid `Nonexistent function 'atoms'` behind "3 red"
		# for a whole afternoon that way -- the count was read, the log was not.
		err=$(grep -c 'SCRIPT ERROR' $log)
		printf "%s\t%s\t%s\t%s\t%s\t%s\n" "$tag" "${name:-?}" "rc=$rc" "${bad} red" \
			"$([ $err -gt 0 ] && print -- "$err SCRIPT ERROR" || print -- "-")" \
			"$(grep -m1 '^FLOOR FAIL ' $log)" >> $OUT/summary.tsv
		print -- "rc=$rc, $bad red$([ $err -gt 0 ] && print -- ", $err SCRIPT ERROR")"
	done
done

print -- "\n--- $OUT/summary.tsv"
column -t -s$'\t' $OUT/summary.tsv
print -- "\nevery red check, by floor:"
for n in $levels; do
	for r in {1..$REPEAT}; do
		tag=$n; [ $REPEAT -gt 1 ] && tag="$n.$r"
		grep -H '^FLOOR \(FAIL\|note\) \|SCRIPT ERROR' $OUT/floor$tag.log 2>/dev/null \
			| sed "s|$OUT/floor||"
	done
done
