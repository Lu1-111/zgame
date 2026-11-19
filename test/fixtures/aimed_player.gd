extends "res://scripts/player/player.gd"
## 无图形测试中以确定的世界瞄准点替代不存在的系统鼠标，其他玩家逻辑保持原样。
var aim_point := Vector2(122,246)


## 提供测试注入的鼠标世界方向。
func aim_vector() -> Vector2:
	return aim_point-global_position
