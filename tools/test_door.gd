extends SceneTree
## 门转场冒烟测试：营地东门 → 森林西门 → 返回，并检查左侧边界不可穿越。
## 用法：godot --headless --path . --script res://tools/test_door.gd

var _fails := 0


func _initialize() -> void:
	await _run()
	print("RESULT: %s" % ("PASS" if _fails == 0 else "FAIL(%d)" % _fails))
	quit(0 if _fails == 0 else 1)


func _check(cond: bool, label: String, detail: String = "") -> void:
	if cond:
		print("  ok   ", label)
	else:
		_fails += 1
		print("  FAIL ", label, "  ", detail)


func _router() -> Node:
	return root.get_node_or_null("SceneRouter")


func _wait_idle(max_frames := 6000) -> void:
	var r := _router()
	for k in 12:
		await process_frame
	var i := 0
	while r != null and r.is_transitioning() and i < max_frames:
		await process_frame
		i += 1
	for k in 6:
		await process_frame


func _run() -> void:
	change_scene_to_file("res://scenes/rooms/camp_01.tscn")
	for i in 8:
		await process_frame
	_check(current_scene != null and current_scene.name == "Camp01", "初始在营地", str(current_scene))

	var camp := current_scene
	_check(camp.get_node_or_null("DoorWest") == null, "营地左侧没有门（是边界）")
	_check(camp.get_node_or_null("WestBoundary") != null, "左侧有边界墙")

	# 左边界：按住左键走 1.5 秒，不能穿出房间
	var player: Node2D = camp.get_node("Player")
	Input.action_press("move_left")
	for i in 90:
		await physics_frame
	Input.action_release("move_left")
	for i in 10:
		await physics_frame
	_check(player.position.x > 6.0, "左边界挡住了角色", "x=%.1f" % player.position.x)

	# 东门 → 森林
	var east: Node2D = camp.get_node("DoorEast")
	player.position = east.position
	await _wait_idle()

	_check(current_scene.name == "Forest01", "营地东门 → 森林", str(current_scene))
	if current_scene.name == "Forest01":
		var forest := current_scene
		var p2: Node2D = forest.get_node("Player")
		var back: Node2D = forest.get_node("DoorWest")
		var expect := back.position + Vector2(44, -9)
		var d := p2.position.distance_to(expect)
		_check(d <= 4.0, "落点在森林西门内侧（误差 ≤4px）",
			"dist=%.1f pos=%s expect=%s" % [d, p2.position, expect])

		p2.position = back.position
		await _wait_idle()
		_check(current_scene.name == "Camp01", "森林西门 → 营地", str(current_scene))
		if current_scene.name == "Camp01":
			var p3: Node2D = current_scene.get_node("Player")
			var camp_east: Node2D = current_scene.get_node("DoorEast")
			var expect3 := camp_east.position + Vector2(-44, -9)
			var d3 := p3.position.distance_to(expect3)
			_check(d3 <= 4.0, "落点在营地东门内侧", "dist=%.1f" % d3)
