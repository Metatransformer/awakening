#!/bin/zsh
# Run directors and record one verdict line each. Card #75.
#
#   tools/sweep.sh                       every director in tools/directors/
#   tools/sweep.sh a_button voices       just these
#   OUT=/tmp/sweep tools/sweep.sh ...    where the logs and PNGs go
#
# The invocation comes from the DIRECTOR'S OWN HEADER, because that is the only
# record of which scene a director wants and card #63's survey had to guess for
# twelve of them. A director with no `tools/quiet.sh` block in its header is
# reported as SKIP/no-invocation rather than run against a guessed scene -- a
# guessed scene is how you get a red run that is about the sweep.
#
# Sequential on purpose. Four or five directors at once on this Mac is the thing
# §2 of CLAUDE.md is about, and a GPU-contended run is not a measurement.
#
# Verdicts, one line per director in $OUT/summary.tsv:
#
#   OK        exit 0 -- and `DIRECTOR OK` printed, so the tally was reached
#   FAIL      exit 66 -- the director failed its own checks (card #72)
#   ERROR     exit 65 -- a SCRIPT ERROR that is not exempt (card #63)
#   TIMEOUT   exit 124 -- still running at the limit, killed
#   SETUP     exit 2-6 -- shoot.gd refused the arguments
#   MUTE      exit 0 with no `DIRECTOR OK` -- reached quit() some other way
#   SKIP      no invocation in the header
set -u

HERE=${0:A:h}
ROOT=${HERE:h}
OUT=${OUT:-/tmp/sweep}
LIMIT=${LIMIT:-400}

mkdir -p $OUT
SUMMARY=$OUT/summary.tsv
: > $SUMMARY

# A director run holds a window and a GPU share until someone kills it, and
# there was a nine-minute zombie on this Mac while #63 was being written. Refuse
# to add to a pile rather than measure through one.
#
# `ps -Ao pid,comm`, not `pgrep -f shoot.gd` and not `ps -o command`: both of
# those match the agent tooling's own command line -- including this script --
# and false-positive every time.
if ps -Ao pid,comm | grep -qi godot; then
	print -u2 "sweep.sh: godot is already running. Kill it before measuring:"
	ps -Ao pid,comm | grep -i godot >&2
	exit 1
fi

if [ $# -gt 0 ]; then
	names=($@)
else
	names=(${${(f)"$(cd $ROOT/tools/directors && ls *.gd)"}:r})
fi

for name in $names; do
	src=$ROOT/tools/directors/$name.gd
	if [ ! -f $src ]; then
		printf "%s\t%s\t%s\n" "$name" SKIP "no such director" >> $SUMMARY
		continue
	fi

	# The header block, de-commented and line-continuations joined. Only the
	# flags are taken from it: --scene and everything after --director is the
	# director's own business (--warmup, --size, --settings, --run-seed).
	inv=$(awk '
		/^##.*(tools\/quiet\.sh|godot --path)/ { grab = 1 }
		grab && /^##/ { sub(/^## ?/, ""); sub(/\\$/, ""); printf "%s ", $0; next }
		grab { exit }
	' $src)

	if [[ "$inv" != *"--scene="* ]]; then
		printf "%s\t%s\t%s\n" "$name" SKIP "no invocation in header (CLAUDE.md §2)" >> $SUMMARY
		continue
	fi

	# Rewrite --out into this sweep's own directory so runs cannot overwrite each
	# other's frames, and drop the leading `tools/quiet.sh --path . -s tools/shoot.gd --`.
	flags=(${(z)inv})
	flags=(${flags:#tools/quiet.sh} )
	args=()
	seen_sep=0
	for f in $flags; do
		case $f in
			--path|.|-s|tools/shoot.gd) continue ;;
			--) seen_sep=1; continue ;;
			--out=*) args+=(--out=$OUT/$name/x.png); continue ;;
		esac
		[[ $f == --* ]] && args+=($f)
	done
	mkdir -p $OUT/$name

	log=$OUT/$name.log
	print -n "  $name … "
	timeout $LIMIT $ROOT/tools/quiet.sh --path $ROOT -s $ROOT/tools/shoot.gd -- $args > $log 2>&1
	rc=$?

	case $rc in
		0)  if grep -q '^DIRECTOR OK' $log; then v=OK; else v=MUTE; fi ;;
		66) v=FAIL ;;
		65) v=ERROR ;;
		124) v=TIMEOUT ;;
		2|3|4|5|6) v=SETUP ;;
		*) v="EXIT$rc" ;;
	esac

	# What it said, for the summary: the canonical line if there is one, else the
	# first thing that looks like a complaint.
	said=$(grep -m1 '^DIRECTOR FAIL' $log || grep -m1 -iE '(FAIL|ABORT)' $log || true)
	printf "%s\t%s\t%s\n" "$name" "$v" "${said:0:120}" >> $SUMMARY
	print -- "$v"
done

print -- "\n--- $SUMMARY"
sort -k2 $SUMMARY | column -t -s$'\t'
print -- "\ntotals:"
awk -F'\t' '{n[$2]++} END {for (k in n) printf "  %-8s %d\n", k, n[k]}' $SUMMARY
