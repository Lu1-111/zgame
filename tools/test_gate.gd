extends SceneTree
## 能力门实测：从上段长平台（row 43）起跳，看能否够到树顶平台（row 35，间距 128px）。
## 用法：godot --headless --path . --script res://tools/test_gate.gd

func _initialize() -> void:
	change_scene_to_file("res://scenes/rooms/forest_01.tscn")
	for i in 20:
		await physics_frame
	var player: CharacterBody2D = current_scene.get_node("Player")

	# 站到上段长平台（row 43 顶面 y=688）；树顶平台在 x 448..848，站到其左缘外 x=400 起跳（上方无遮挡）
	player.position = Vector2(400, 688 - 17)
	for i in 20:
		await physics_frame
	var start_y := player.position.y

	Input.action_press("jump")
	var lowest := start_y
	for i in 90:
		await physics_frame
		lowest = minf(lowest, player.position.y)
	Input.action_release("jump")
	for i in 30:
		await physics_frame

	var roof_feet_y := 35 * 16 - 17
	var need := start_y - roof_feet_y
	var got := start_y - lowest
	print("起跳 y=%.1f  最高 y=%.1f  上升 %.1f px" % [start_y, lowest, got])
	print("树顶需要上升 %.1f px（间距 128px）" % need)
	print("单跳上得去: %s" % ("是" if got >= need else "否（差 %.1f px）" % (need - got)))
	print("二段跳参考高度: 138.6 px")
	quit()
