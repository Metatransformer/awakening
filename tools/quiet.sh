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

# Print the SCRIPT ERROR lines this run buried, loudly, with a count and one
# entry per distinct site. On stderr, because it is a verdict about the run and
# not part of it, and after the run, because that is the only moment the whole
# log exists.
#
# REPORT ONLY, for now: the run's own exit status is passed through untouched.
# The gate is the second half of card #63 and lands once the survey it exists to
# produce has been taken -- turning the whole harness red in one commit is how a
# guard gets deleted at 3am by whoever needed a green run.
_script_errors() {
	[ -s "$ERRLOG" ] || return 0
	local report
	report=$(awk '
		/^SCRIPT ERROR: / {
			msg = substr($0, 15)
			site = ""
			if ((getline nxt) > 0) {
				sub(/^[ \t]*/, "", nxt)
				if (nxt ~ /^at: /) site = nxt
			}
			key = msg "\t" site
			n[key]++
			total++
			next
		}
		END {
			if (total == 0) exit 1
			printf "%d\n", total
			for (k in n) {
				split(k, p, "\t")
				printf "  %dx  %s\n", n[k], p[1]
				if (p[2] != "") printf "        %s\n", p[2]
			}
		}
	' "$ERRLOG") || return 0
	local count=${report%%$'\n'*}
	{
		print -r -- "------------------------------------------------------------"
		print -r -- "quiet.sh: $count SCRIPT ERROR line(s) in this run. Whatever the"
		print -r -- "director said above, it did not account for these (card #63):"
		print -r -- "${report#*$'\n'}"
		print -r -- "------------------------------------------------------------"
	} >&2
}
_script_errors

exit $rc
