#!/usr/bin/env bash
set -euo pipefail
cd -- "$(dirname -- "$0")"
exec "${GODOT_BIN:-$HOME/.local/bin/godot}" --path . --resolution 1280x720 --max-fps 60 res://scenes/testing/skeleton_lab.tscn "$@" -- --animation-backend=skeleton
