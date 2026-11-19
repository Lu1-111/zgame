extends "res://scripts/player/player.gd"
## Headless 没有系统光标，固定瞄准用于确定性技能空间验收；不改变正式输入代码。
var test_aim := Vector2.RIGHT

func aim_vector() -> Vector2:
	return test_aim
