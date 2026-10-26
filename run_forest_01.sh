#!/usr/bin/env bash
set -euo pipefail
cd -- "$(dirname -- "$0")"
exec "${GODOT_BIN:-$HOME/.local/bin/godot}" --path . res://scenes/rooms/forest_01.tscn "$@"
