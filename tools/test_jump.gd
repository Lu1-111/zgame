extends SceneTree
## 跳跃高度实测：单跳 vs 二段跳，用于判断平台间距是否可达。
## 用法：godot --headless --path . --script res://tools/test_jump.gd

var _fails := 0


func _initialize() -> void:
	await _run()
	quit(0 if _fails == 0 else 1)


func _run() -> void:
	change_scene_to_file("res://scenes/rooms/camp_01.tscn")
	for i in 20:
		await physics_frame
	var player: CharacterBody2D = current_scene.get_node("Player")

	var single := await _measure(player, false)
	print("单跳高度: %.1f px" % single)

	# 临时解锁二段跳后重载场景，让玩家在 _ready 时读到新能力（不写回存档）
	var gs := root.get_node_or_null("GameState")
	if gs != null and not gs.abilities.has(&"double_jump"):
		gs.abilities.append(&"double_jump")
	change_scene_to_file("res://scenes/rooms/camp_01.tscn")
	for i in 20:
		await physics_frame
	player = current_scene.get_node("Player")
	var dbl := await _measure(player, true)
	print("二段跳高度: %.1f px" % dbl)

	print("平台间距: 96 px（6 格）")
	print("单跳可达: %s" % ("是" if single >= 96.0 else "否"))
	print("二段跳可达: %s" % ("是" if dbl >= 96.0 else "否"))


func _measure(player: CharacterBody2D, use_double: bool) -> float:
	while not player.is_on_floor():
		await physics_frame
	var y0 := player.position.y
	var lowest := y0

	Input.action_press("jump")
	for i in 45:
		await physics_frame
		lowest = minf(lowest, player.position.y)
		if use_double and i == 20:
			Input.action_release("jump")
			await physics_frame
			Input.action_press("jump")
	Input.action_release("jump")

	# 落地恢复
	var guard := 0
	while not player.is_on_floor() and guard < 240:
		await physics_frame
		guard += 1
	for i in 10:
		await physics_frame
	return y0 - lowest
