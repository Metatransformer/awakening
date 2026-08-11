#!/bin/zsh
# Run Godot with the harness window kept off the owner's keyboard.
#
# Use it exactly where you would have said `godot`:
#
#   tools/quiet.sh --path . -s tools/shoot.gd -- \
#       --scene=res://scenes/rooms/garrison.tscn \
#       --director=res://tools/directors/mvp_loop.gd --out=/tmp/mvp/x.png
#
# WHY: a director run opens a real macOS window. It comes up in front of
# whatever the owner is typing into and takes the keystrokes with it, and this
# repo does that dozens of times an hour across several agents at once. The
# machine stopped being usable for anything else.
#
# Two things have to be true for a run to be invisible, and they are delivered
# in two different places because macOS gives us no choice:
#
#   1. `display/window/size/no_focus` -- THIS script's job. The flag is read
#      once, when the window is created, which is before any `-s` script gets
#      to run, so `override.cfg` is the only way in. Setting the flag from
#      GDScript afterwards does nothing at all (measured: 0/240 focused frames
#      when set at creation, 16/240 when set from `_initialize`), and a window
#      created WITHOUT it can never be talked into giving focus up later.
#      `override.cfg` beside the executable is not read -- only the project dir.
#
#   2. Parking the window in the corner -- `shoot.gd`'s job, see
#      `_park_the_window`. no_focus alone still leaves a window sitting on top
#      of the desktop. (Do NOT minimise it instead; that kills capture. The
#      measurement is in shoot.gd's comment and in CLAUDE.md §3.)
#
# Neither half is sufficient. no_focus without parking leaves a window in the
# owner's way; parking without no_focus still steals the keyboard for the second
# before the move lands.
#
# THE THIRD THING IS SILENCE, and it is here rather than only in `shoot.gd`
# because the device is opened before any `-s` script exists. `shoot.gd` mutes
# the MASTER bus in `_initialize` (`_hush_the_speakers`), which covers director
# runs -- but a scene-based harness (`tools/scenes/*.tscn`, launched as
# `godot --path . res://tools/scenes/x.tscn`) never runs shoot.gd at all, boots
# the autoloads, and starts playing the score out of the owner's speakers. The
# driver flag has no such hole: with `Dummy` no audio device is ever opened, so
# there is no window in which anything can leak. AudioServer still works
# normally -- buses, volumes, `AudioStreamPlayer.playing` -- so `music_beats`,
# `sfx_moves` and `critic_menu` still assert what they always did.
#
# `--sound` opts back in, matching shoot.gd's own flag, for a director proving
# that a cue actually reaches the speakers. An explicit `--audio-driver` wins
# over both.
#
# override.cfg is SHARED STATE in a repo that runs several agents at once, and a
# stale one is worse than no feature: the owner's own `pnpm play` would come up
# in a window that cannot be focused or typed into, which reads as "the game is
# broken". So it is refcounted -- every run drops a pidfile, the last one out
# removes the file, and a run that was killed -9 gets swept by the next one
# rather than pinning it forever.
#
# THE FOURTH THING IS THAT A RUN WITH A SCRIPT ERROR IN IT CANNOT PASS, and it
# is here because GDScript cannot see its own error stream -- a director has no
# way to fail itself on one. Card #47's `boss_cistern.gd` printed
# `SCRIPT ERROR: Trying to cast a freed object` out of `Hero.lock_target` and
# `BOSS OK -- every check passed`, in the same output, and the bug shipped. Card
# #63 is this. See `_script_errors` at the bottom.

set -u
ROOT=${ZL_ROOT:-${0:A:h:h}}
OVERRIDE=$ROOT/override.cfg
LOCKS=$ROOT/.godot-quiet
GODOT=${GODOT:-godot}

mkdir -p $LOCKS

# A run that died without its trap left a pidfile behind. Sweep those first, or
# the first crash of the session pins override.cfg until someone notices.
#
# `<->` (any number) and not `*`, because the pidfile is no longer the only
# thing in here: each run also drops `<pid>.log` for the SCRIPT ERROR check at
# the bottom, and a bare `*` would hand `kill -0` the string "39769.log", get a
# refusal, and delete a LIVE run's log out from under it. The dead run's log
# goes with its pidfile, so the "last one out" test below still sees an empty
# directory.
for f in $LOCKS/<->(N); do
	kill -0 ${f:t} 2>/dev/null && continue
	rm -f $f $f.log
done

touch $LOCKS/$$
printf '[display]\n\nwindow/size/no_focus=true\n' > $OVERRIDE

ERRLOG=$LOCKS/$$.log

cleanup() {
	rm -f $LOCKS/$$ $ERRLOG
	# Last one out. `ls -A` rather than a glob: an empty dir must read as empty.
	if [ -z "$(ls -A $LOCKS 2>/dev/null)" ]; then
		rm -f $OVERRIDE
		rmdir $LOCKS 2>/dev/null
	fi
}
trap cleanup EXIT INT TERM

# See the SILENCE note at the top. `$*` is padded so `--sound` matches as a whole
# word and `--soundtrack` does not.
HUSH=(--audio-driver Dummy)
case " $* " in
	*" --sound "*|*" --audio-driver "*) HUSH=() ;;
esac

# `--log-file` and NOT a `| tee`, which is the obvious way to read a run's own
# output and the wrong one here. A pipeline puts godot's stdout on a pipe, and
# the harness's output is a thing PEOPLE read while it runs; a pipe would also
# have to carry the exit status back out through `$pipestatus`, and merging
# stderr into stdout to catch it would reorder the two streams the reader is
# comparing. Godot writes this file itself, both streams, in order, while the
# terminal gets exactly the bytes it always did. An explicit `--log-file` from
# the caller wins -- their file, their business, and no guard rather than a
# guard reading the wrong file.
LOGGING=(--log-file $ERRLOG)
case " $* " in
	*" --log-file "*) LOGGING=() ;;
esac

$GODOT "${HUSH[@]}" "${LOGGING[@]}" "$@"
# `rc`, not `status`: `status` is zsh's own read-only alias for `$?`, and
# assigning to it is a FATAL shell error -- the run had already finished, the
# trap never fired, and override.cfg was left pinned for the next person.
rc=$?

# Fail the run on any SCRIPT ERROR that is not on the exemption list, and say
# which ones and where. On stderr, because it is a verdict about the run rather
# than part of it, and after the run, because that is the only moment the whole
# log exists.
#
# `SCRIPT ERROR:` and nothing wider. Measured over all 136 directors on
# 2026-08-11: EVERY run ends with `ERROR: N resources still in use at exit` and
# `WARNING: N ObjectDB instances were leaked at exit`, so a gate on the bare
# `ERROR:` prefix would have failed all 136 on its first day and been deleted by
# lunchtime. `SCRIPT ERROR` is the prefix that discriminates -- and `push_error`
# prints `USER ERROR`, so the harness's own deliberate refusals do not trip it.
# Compile and parse failures arrive under this prefix too, which is wanted: a
# scene whose script would not compile has been photographed by a director that
# then said OK, twice, during that same survey.
#
# EXIT 65, chosen to collide with nothing a caller already reads: `timeout` owns
# 124, a signal owns 128+n, and shoot.gd's own refusals own 2 through 6. A run
# that already failed on its own keeps ITS status -- the first cause is the
# useful one.
#
# The exemption list is `tools/script_errors.allow`, per DIRECTOR and per
# MESSAGE, never a blanket switch, and every row carries the card that will
# delete it. An exempt error is still printed, still counted and still labelled
# with its card, because the point of the row is that the debt stays visible.
GATE_EXIT=65
ALLOW=${0:A:h}/script_errors.allow

_script_errors() {
	[ -s "$ERRLOG" ] || return 0
	# Which director this was, so an exemption can be scoped to it. A run with no
	# `--director=` (a scene harness) simply has nothing to match, which is the
	# right answer rather than a hole: there is no name to exempt.
	local who=""
	local a
	for a in "$@"; do
		case $a in --director=*) who=${a##*/} ;; esac
	done

	local report
	report=$(awk -v allow="$ALLOW" -v who="$who" '
		# Pass one: the allow file. <director><TAB><message substring><TAB><card>
		#
		# A `#` only starts a comment at the START of a line. Stripping from any
		# `#` is the obvious way to write this and it silently ate the CARD
		# column -- every row is "... <TAB> #70" -- which left the exemption
		# holding an empty card, and the test below reads an empty card as "not
		# exempt". The gate fired on the three directors it was built to spare.
		FILENAME == allow {
			if ($0 ~ /^[ \t]*(#|$)/) next
			split($0, f, "\t")
			gsub(/^[ \t]+|[ \t]+$/, "", f[1])
			gsub(/^[ \t]+|[ \t]+$/, "", f[2])
			gsub(/^[ \t]+|[ \t]+$/, "", f[3])
			if (f[1] != who || f[2] == "") next
			ex[++exn] = f[2]
			card[exn] = (f[3] == "" ? "no card" : f[3])
			next
		}
		/^SCRIPT ERROR: / {
			msg = substr($0, 15)
			site = ""
			if ((getline nxt) > 0) {
				sub(/^[ \t]*/, "", nxt)
				if (nxt ~ /^at: /) site = nxt
			}
			hit = ""
			for (i = 1; i <= exn; i++)
				if (index(msg, ex[i]) > 0) { hit = card[i]; break }
			key = msg "\t" site "\t" hit
			n[key]++
			total++
			if (hit != "") spared++
			next
		}
		END {
			if (total == 0) exit 1
			printf "%d\t%d\n", total, total - spared
			for (k in n) {
				split(k, p, "\t")
				printf "  %dx  %s%s\n", n[k], p[1], \
					(p[3] == "" ? "" : "   [exempt, " p[3] "]")
				if (p[2] != "") printf "        %s\n", p[2]
			}
		}
	' "$ALLOW" "$ERRLOG") || return 0

	local head=${report%%$'\n'*}
	local total=${head%%$'\t'*}
	local live=${head##*$'\t'}
	{
		print -r -- "------------------------------------------------------------"
		if [ "$live" -gt 0 ]; then
			print -r -- "quiet.sh: FAILED -- $total SCRIPT ERROR line(s), $live of them"
			print -r -- "not exempt. Whatever the director said above, it did not"
			print -r -- "account for these, and a run with one in it is not proof"
			print -r -- "(CLAUDE.md §2, card #63):"
		else
			print -r -- "quiet.sh: $total SCRIPT ERROR line(s), all of them exempt in"
			print -r -- "tools/script_errors.allow. The run stands; the debt does not"
			print -r -- "go away (CLAUDE.md §2, card #63):"
		fi
		print -r -- "${report#*$'\n'}"
		print -r -- "------------------------------------------------------------"
	} >&2
	[ "$live" -gt 0 ] && return 1
	return 0
}

if ! _script_errors "$@"; then
	[ $rc -eq 0 ] && rc=$GATE_EXIT
fi

exit $rc
