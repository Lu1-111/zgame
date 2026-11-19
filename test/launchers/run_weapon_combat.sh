#!/usr/bin/env sh
cd "$(dirname "$0")/../.." || exit 1
"${GODOT_BIN:-$HOME/.local/bin/godot}" --path . --rendering-method gl_compatibility --windowed --resolution 1280x720 --max-fps 60 res://test/scenes/weapon_combat_gallery.tscn
