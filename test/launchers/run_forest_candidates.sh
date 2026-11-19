#!/usr/bin/env bash
set -euo pipefail
cd "$(dirname "$0")/../.."
export XDG_DATA_HOME="$PWD/work/forest_candidates/data"
export XDG_CONFIG_HOME="$PWD/work/forest_candidates/config"
export XDG_CACHE_HOME="$PWD/work/forest_candidates/cache"
exec "${GODOT_BIN:-$HOME/.local/bin/godot}" --path "$PWD" --rendering-method gl_compatibility --windowed --resolution 1280x720 --max-fps 60 res://test/scenes/forest_candidates.tscn
