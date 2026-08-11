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

set -u
ROOT=${ZL_ROOT:-${0:A:h:h}}
OVERRIDE=$ROOT/override.cfg
LOCKS=$ROOT/.godot-quiet
GODOT=${GODOT:-godot}

mkdir -p $LOCKS

# A run that died without its trap left a pidfile behind. Sweep those first, or
# the first crash of the session pins override.cfg until someone notices.
for f in $LOCKS/*(N); do
	kill -0 ${f:t} 2>/dev/null || rm -f $f
done

touch $LOCKS/$$
printf '[display]\n\nwindow/size/no_focus=true\n' > $OVERRIDE

cleanup() {
	rm -f $LOCKS/$$
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

$GODOT "${HUSH[@]}" "$@"
