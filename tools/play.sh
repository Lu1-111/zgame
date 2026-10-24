#!/usr/bin/env bash
# 一键启动游戏（标题屏；Enter 进试玩场）
# 用法：bash tools/play.sh          或   ./tools/play.sh
# 直接进试玩场：bash tools/play.sh arena
cd "$(dirname "$0")/.." || exit 1
GODOT="$HOME/.local/bin/godot"
if [ "$1" = "arena" ]; then
	exec "$GODOT" --path . res://scenes/levels/test_arena.tscn
else
	exec "$GODOT" --path .
fi
