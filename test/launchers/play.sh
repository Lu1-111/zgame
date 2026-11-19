#!/usr/bin/env bash
# 一键启动游戏（标题屏；Enter 进试玩场）
# 用法：bash test/launchers/play.sh          或   ./test/launchers/play.sh
# 直接进试玩场：bash test/launchers/play.sh arena
cd "$(dirname "$0")/../.." || exit 1
GODOT="$HOME/.local/bin/godot"
if [ "${1:-}" = "arena" ]; then
	exec "$GODOT" --path . res://test/scenes/arenas/test_arena.tscn
else
	exec "$GODOT" --path .
fi
