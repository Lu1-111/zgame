#!/usr/bin/env sh
set -eu
cd "$(dirname "$0")/../.."
export XDG_DATA_HOME="$PWD/work/weapon_appearances/userdata"
mkdir -p "$XDG_DATA_HOME"
exec "${GODOT_BIN:-godot}" --path "$PWD" --rendering-method gl_compatibility --windowed --resolution 1280x720 --max-fps 60 res://test/scenes/weapon_appearance_gallery.tscn
