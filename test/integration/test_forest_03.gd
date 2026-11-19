extends "res://test/integration/test_forest_02.gd"
## 真实物理：逐段单跳、清怪雾墙、空箱、篝火、双通道及从03侧解锁的捷径。
var gs: Node

func _run() -> void:
	create_timer(100,true,false,true).timeout.connect(func() -> void: quit(2))
	gs = root.get_node("GameState")
	gs.reset()
	config = JSON.parse_string(FileAccess.get_file_as_string("res://data/maps/forest_03.json"))
	await _enter03()
	_expect(current_scene.get_node("MistGateRoot").collision_layer == 1 and current_scene.get_node("MistGateMiddle").collision_layer == 1,"两道白雾墙初始有实体阻挡")
	var mist := current_scene.get_node("MistGateRoot/WhiteMist") as AnimatedSprite2D
	var first := mist.frame
	await _frames(14)
	_expect(mist.sprite_frames.get_frame_count(&"default") == 8 and mist.frame != first,"白色雾墙播放八帧循环")
	await _place(Vector2(1752,1359))
	Input.action_press("move_right")
	await _frames(24)
	_release()
	_expect(player.position.x < 1790,"未清场时下层雾墙确实挡住移动")
	await _place(Vector2(1752,1727))
	Input.action_press("move_right")
	await _frames(24)
	_release()
	_expect(player.position.x < 1790,"雾墙延伸到洞底，不能从下沿绕过")
	var root_chest: Dictionary = config.chests[3]
	await _place(Vector2(root_chest.pos[0],root_chest.pos[1]-HALF))
	current_scene.interact_nearby()
	_expect(not gs.opened_chests.has(StringName(root_chest.id)),"附近守箱怪存活时紫箱不能开启")
	_clear_group("f03_middle_trial")
	await _frames(10)
	_expect(current_scene.get_node("MistGateMiddle").collision_layer == 0 and current_scene.get_node("MistGateRoot").collision_layer == 1,"中层清场只解除本区域封印")
	_clear_group("f03_root_trial",true)
	await _frames(10)
	_expect(current_scene.get_node("MistGateRoot").collision_layer == 1,"苔甲卫未死时仍保持雾墙")
	_clear_group("f03_root_trial")
	await _frames(40)
	_expect(current_scene.get_node("MistGateRoot").collision_layer == 0 and not current_scene.get_node("MistGateRoot").visible,"完整清场后雾墙消散且失去碰撞")
	for chest: Dictionary in config.chests:
		var before: String = JSON.stringify(gs.inventory)
		await _place(Vector2(chest.pos[0],chest.pos[1]-HALF))
		_expect(current_scene.interact_nearby() and gs.opened_chests.has(StringName(chest.id)),"空宝箱可正常开启 "+str(chest.id))
		_expect(JSON.stringify(gs.inventory) == before,"空箱不会生成占位物品 "+str(chest.id))
	var snapshot: Dictionary = gs.to_save_dict()
	gs.reset()
	gs.load_from_dict(snapshot)
	await _enter03()
	_expect(current_scene.get_node("MistGateRoot").collision_layer == 0 and current_scene.get_node("MistGateMiddle").collision_layer == 0,"重进时即使怪物刷新，已解除的雾墙仍永久开放")
	_expect(not current_scene.get_node("Chest_root_trial").visible,"空箱开启状态随存档保留")
	for surface: Dictionary in config.platforms:
		surfaces[surface.id] = surface.rect
	for surface: Dictionary in config.floor_samples:
		surfaces[surface.id] = surface.rect
	for route: Array in config.routes:
		var start := _rect(surfaces[route[0]])
		var goal := _rect(surfaces[route[1]])
		_expect(await _try_route(start,goal,not _is_platform(str(route[1]))),"真实单跳 %s -> %s" % route)
	await _links()
	await _place(Vector2(1988,895))
	var ui := root.get_node("GameUI")
	_expect(ui.begin_rest() and gs.checkpoint_id == &"cp_forest_03_gallery","新篝火进入坐火菜单并设置本图复活点")
	_expect(gs.unlocked_campfires.has(&"cp_forest_03_gallery"),"篝火接入解锁与旅行记录")
	ui._force_close()
	player.stop_presentation_animation()
	await _frames(2)
	print("FOREST_03 PHYSICS: %d failures" % failures)
	quit(1 if failures else 0)

func _enter03() -> void:
	change_scene_to_file("res://scenes/maps/forest_03.tscn")
	await _frames(12)
	player = current_scene.get_node("Player")
	while root.get_node("GameUI").player != player:
		await process_frame
	_freeze_enemies()
	player.set("_invuln",99999.0)
	await _frames(4)

func _freeze_enemies() -> void:
	for enemy in get_nodes_in_group(&"enemies"):
		enemy.set_physics_process(false)
		enemy.collision_layer = 0

func _clear_group(id: String, preserve_elite: bool = false) -> void:
	for group: Dictionary in config.encounters:
		if str(group.id) != id:
			continue
		for enemy in get_nodes_in_group(&"enemies"):
			if str(enemy.get_meta("spawn_id","")) in group.spawn_ids and int(enemy.hp) > 0:
				if preserve_elite and enemy.enemy_id == &"moss_guard":
					continue
				enemy.receive_hit(DamagePacket.new(100000,DamagePacket.DamageType.PHYSICAL,0,player.position,&"qa_clear"))

func _links() -> void:
	change_scene_to_file("res://scenes/maps/forest_02.tscn")
	await _frames(16)
	player = current_scene.get_node("Player")
	_freeze_enemies()
	await _place(Vector2(2664,287))
	Input.action_press("move_right")
	await _frames(50)
	_release()
	_expect(current_scene.name == &"Forest02" and not gs.opened_shortcuts.has(&"forest_02_canopy_link") and player.position.x < 2710,"02上方新通道不能从02侧自行开启")
	await _place(Vector2(2664,1695))
	Input.action_press("move_right")
	await _frames(85)
	_release()
	_expect(current_scene.name == &"Forest03","02右下进入03左下")
	if current_scene.name != &"Forest03":
		return
	player = current_scene.get_node("Player")
	_freeze_enemies()
	_expect(absf(player.position.y+HALF-1744) < 3,"03左下到达后落在安全地面")
	await _frames(35)
	await _place(Vector2(64,1727))
	Input.action_press("move_left")
	await _frames(70)
	_release()
	_expect(current_scene.name == &"Forest02","03左下可返回02右下")
	await _enter03()
	await _place(Vector2(80,207))
	Input.action_press("move_left")
	await _frames(75)
	_release()
	_expect(current_scene.name == &"Forest02" and gs.opened_shortcuts.has(&"forest_02_canopy_link"),"首次从03左上通过，永久解锁上层捷径")
	if current_scene.name != &"Forest02":
		return
	player = current_scene.get_node("Player")
	_freeze_enemies()
	_expect(not current_scene.get_node("CanopyShortcutGate").visible,"返回02时上方捷径屏障消失")
	await _frames(35)
	await _place(Vector2(2664,287))
	Input.action_press("move_right")
	await _frames(90)
	_release()
	_expect(current_scene.name == &"Forest03","解锁后02右上可以双向进入03左上")
	if current_scene.name != &"Forest03":
		return
	player = current_scene.get_node("Player")
	_freeze_enemies()
	_expect(player.position.y < 300,"上方捷径没有误用下方出生点")
	await _place(Vector2(2480,207))
	Input.action_press("move_right")
	await _frames(65)
	_release()
	_expect(current_scene.name == &"Forest03" and player.position.x < 2560,"03右上只保留出口，不会切图或掉出边界")
	var saved: Dictionary = gs.to_save_dict()
	gs.reset()
	gs.load_from_dict(saved)
	_expect(gs.opened_shortcuts.has(&"forest_02_canopy_link"),"上层捷径解锁状态写入存档")

func _is_platform(id: String) -> bool:
	for platform: Dictionary in config.platforms:
		if str(platform.id) == id:
			return true
	return false

func _rect(raw: Array) -> Rect2:
	return Rect2(raw[0],raw[1],raw[2],raw[3])
