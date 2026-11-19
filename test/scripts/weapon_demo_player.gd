extends Player
## 演练只由面板驱动；人物、动画、碰撞和完整攻击状态机仍使用正式实现。
var demo_facing := 1

func _update_input() -> void:
	pass

func input_dir() -> float:
	return 0.0

func aim_vector() -> Vector2:
	return Vector2(demo_facing,0)
