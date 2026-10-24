extends SceneTree
## 攀爬可达性实测：站在第 1 块平台左缘外起跳，看能否登上平台（间距 64px）。
## 用法：godot --headless --path . --script res://tools/test_climb.gd

func _initialize() -> void:
	change_scene_to_file("res://scenes/rooms/forest_01.tscn")
	for i in 20:
		await physics_frame
	var player: CharacterBody2D = current_scene.get_node("Player")

	# 第 1 块平台 row=102, x 8..22（像素 128..352）。站到它左边缘外 x=100。
	player.position = Vector2(100, 1696 - 17)
	for i in 20:
		await physics_frame
	var start_y := player.position.y

	# 起跳 + 向右推进，尝试登上平台
	Input.action_press("jump")
	Input.action_press("move_right")
	var lowest := start_y
	for i in 80:
		await physics_frame
		lowest = minf(lowest, player.position.y)
	Input.action_release("jump")
	Input.action_release("move_right")
	for i in 30:
		await physics_frame

	var platform_feet_y := 102 * 16 - 17     # 站上平台时玩家 y
	print("起跳 y=%.1f  最高点 y=%.1f  上升 %.1f px" % [start_y, lowest, start_y - lowest])
	print("平台顶面对应 y=%.1f（需要上升 %.1f px）" % [platform_feet_y, start_y - platform_feet_y])
	var short_by := lowest - platform_feet_y
	if short_by > 0.5:
		print("结论: 差 %.1f px 够不到" % short_by)
	else:
		print("结论: 够得到")
	quit()
