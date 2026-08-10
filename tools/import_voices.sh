#!/usr/bin/env bash
#
# Re-import the recorded voice lines from the masters into res://audio/voice/.
#
# The masters live OUTSIDE the repo (they are the recording session's output, not
# a build artefact of it) and this script is the only thing that knows how they
# become the .ogg files the game loads. Run it again whenever a line is re-cut;
# do not hand-convert one file, because the two things it does are both global.
#
#   1. **mp3 -> ogg.** Not taste and not consistency with the rest of audio/:
#      an mp3 frame is 1152 samples and every encoder pads the start of the
#      stream, so an mp3 begins with up to ~30 ms of silence that Godot faithfully
#      plays. On a 0.8 s line ("hail") that is audible slack between the button
#      and the voice.
#
#   2. **One loudness for every line.** The masters span 20 dB integrated --
#      -11.2 LUFS for the elder's "hail" against -31.3 for the alchemist's
#      farewell -- which on the same bus is one line that startles you and one you
#      cannot hear over the forge. -18 LUFS puts speech just above the music bed
#      (the tracks are ~-11 LUFS with `Music.TRACK_DB` -8 on top, so ~-19), which
#      is where dialogue belongs.
#
# Two-pass loudnorm, because single-pass is a dynamic normaliser: it rides the
# gain within the file and squashes the shape of a delivered line.
#
# Nothing in the game reads the master names -- `Voice.LINES` maps a cue to a
# file name, and the file name is the WORDS, so the table reads as a script.

set -euo pipefail

SRC="${1:-$HOME/SFX/Voices}"
DST="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)/audio/voice"

# Integrated target, true peak ceiling, loudness range. Speech, so LRA is tight.
I=-18
TP=-1.5
LRA=7

# master directory -> speaker id (the folder under audio/voice/, and the key in
# `Voice.LINES`). "Village  Elder" has two spaces in it; that is why this is a
# table and not a `tr '[:upper:]' '[:lower:]'`.
speakers=(
  "Narrator:narrator"
  "Village  Elder:elder"
  "Smith:smith"
  "Pawnbroker:pawnbroker"
  "Alchemist:alchemist"
  "Jewelcrafter:jewelcrafter"
)

for row in "${speakers[@]}"; do
  from="$SRC/${row%%:*}"
  who="${row##*:}"
  mkdir -p "$DST/$who"
  for f in "$from"/*.mp3; do
    [ -e "$f" ] || continue
    # snake_case the words: "there you go.mp3" and "thats_a_good_Deal.mp3" both
    # came off the recorder as typed.
    base="$(basename "$f" .mp3 | tr '[:upper:] ' '[:lower:]_')"
    out="$DST/$who/$base.ogg"

    stats="$(ffmpeg -hide_banner -nostats -i "$f" \
      -af "loudnorm=I=$I:TP=$TP:LRA=$LRA:print_format=json" -f null - 2>&1 \
      | sed -n '/^{/,/^}/p')"
    get() { echo "$stats" | grep "\"$1\"" | sed 's/.*: *"\(.*\)".*/\1/'; }

    ffmpeg -hide_banner -loglevel error -y -i "$f" \
      -af "loudnorm=I=$I:TP=$TP:LRA=$LRA:measured_I=$(get input_i):measured_TP=$(get input_tp):measured_LRA=$(get input_lra):measured_thresh=$(get input_thresh):offset=$(get target_offset):linear=true:print_format=summary" \
      -ac 1 -ar 44100 -c:a libvorbis -q:a 6 "$out"
    echo "  $who/$base.ogg"
  done
done

echo "Now run:  godot --path . --import   (and see CLAUDE.md §3 about project.godot)"
