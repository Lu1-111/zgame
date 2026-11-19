#!/usr/bin/env sh
set -eu
cd "$(dirname "$0")/../.."
GODOT_BIN="${GODOT_BIN:-$HOME/.local/bin/godot}"
exec "$GODOT_BIN" --path . --rendering-method gl_compatibility --max-fps 60 res://scenes/maps/forest_03.tscn

