extends SceneTree
## 营地实机验收：连续单跳上楼、薄台下穿、安全重生、NPC 交互与补给。
var config: Dictionary
var actor: CharacterBody2D
var failed := 0
var passed := 0
var gs: Node
var ui: Node
var service: GDScript


func _initialize() -> void:
	call_deferred("_run")


func _run() -> void:
	create_timer(30,true,false,true).timeout.connect(func() -> void: quit(2))
	gs = root.get_node("GameState")
	ui = root.get_node("GameUI")
	service = load("res://scripts/core/inventory_service.gd")
	service.config().save.directory = "user://qa_camp_saves/"
	gs.reset()
	config = JSON.parse_string(FileAccess.get_file_as_string("res://data/maps/camp_01.json"))
	change_scene_to_file("res://scenes/rooms/camp_01.tscn")
	await _frames(12)
	actor = current_scene.get_node("Player")
	_expect(actor.is_on_floor() and absf(actor.position.y + 17 - 544) < 2,"新旅途出生在下层平地")
	_expect(gs.checkpoint_room == &"camp_01" and gs.checkpoint_position == config.spawn,"初始营地重生点写入跨房间状态")
	_expect(current_scene.get_meta("safe_zone") and get_nodes_in_group(&"enemies").is_empty(),"营地为无敌人的安全区")
	_expect(actor.cam.limit_left == 0 and actor.cam.limit_right == 1280 and actor.cam.limit_bottom == 640,"运行时镜头边界正确，视口不露灰底")
	_expect(current_scene.has_node("TentA") and current_scene.has_node("TentB"),"下层具有两顶正式帐篷")
	_expect(current_scene.get_node("Platform_step_01").get_meta("platform_type") == "oneway" and current_scene.get_node("Platform_step_02").get_meta("platform_type") == "oneway","恰有连续两层空心平台")
	_expect(current_scene.get_node("Platform_trade_foundation").get_meta("platform_type") == "solid","二层地基为实心平台")
	_expect(get_nodes_in_group(&"npc").size() == 6,"六位已有 NPC 均进入营地")
	for entry: Dictionary in config.npcs:
		var npc := current_scene.get_node(str(entry.node))
		_expect(npc.z_index == 20 and npc.sprite.sprite_frames.has_animation(&"idle"),"%s 正式动画与角色渲染层正确" % entry.name)
	_expect(current_scene.get_node("MilkCow").position.y == 256 and current_scene.get_node("MilkMouse").position.y == 256,"商人和铁匠位于二层交易区")
	_expect(current_scene.has_node("SmithAnvil") and current_scene.has_node("SmithWeaponRack") and current_scene.has_node("MerchantCargo"),"NPC 职业对应的铁砧、武器架和货箱存在")
	var checkpoint: Array = gs.checkpoint_position.duplicate()
	actor.position = Vector2(520,527)
	actor.velocity = Vector2.ZERO
	await _frames(8)
	for route: Dictionary in config.jump_route:
		var from := _platform(str(route.from))
		var target := _platform(str(route.to))
		_expect(absf(from.position.y-target.position.y) == 96,"%s 高差为单跳高度的约 85%%" % route.to)
		await _walk_to(float(route.start_x))
		Input.action_press("jump")
		var landed := false
		for frame in 70:
			_release_horizontal()
			if absf(actor.position.x-float(route.target_x)) > 3:
				Input.action_press("move_right" if actor.position.x < float(route.target_x) else "move_left")
			await physics_frame
			if frame > 5 and actor.is_on_floor():
				landed = absf(actor.position.y+17-target.position.y) < 2 and actor.position.x > target.position.x and actor.position.x < target.end.x
				break
		Input.action_release("jump")
		_release_horizontal()
		_expect(landed,"连续真实单跳到达 %s" % route.to)
		await _frames(4)
		if not landed:
			break
	_expect(actor.position.y < 256 and actor.is_on_floor(),"不授予二段跳即可从一层连续到达二层")
	actor.position = Vector2(620,335)
	actor.velocity = Vector2.ZERO
	await _frames(8)
	Input.action_press("move_down")
	await _frames(20)
	Input.action_release("move_down")
	_expect(actor.position.y+17 > 360,"按 S 可从空心平台下穿")
	actor.position = Vector2(662,527)
	actor.velocity = Vector2.ZERO
	await _frames(15)
	_press_e()
	await _frames(2)
	_release_e()
	_expect(gs.opened_chests.has(&"camp_supplies") and service.count_item("potion_small") == 3 and not current_scene.get_node("ChestA").visible,"初始补给箱只开启一次并真正进入背包")
	_expect(service.count_item("potion_mana") == 2 and service.count_item("milk_bomb") == 2,"补给箱保留原有初始药剂和奶弹")
	gs.level = 3
	gs.coin = 500
	service.buy_talent(&"milk_1")
	service.buy_talent(&"milk_2")
	actor.position = Vector2(426,527)
	actor.velocity = Vector2.ZERO
	await _frames(10)
	_press_e()
	await _frames(2)
	_release_e()
	_expect(current_scene.get_node("NPCDialogue/Panel").visible and current_scene.get_node("NPCDialogue/Panel/Speaker").text == "奶兔向导","篝火旁奶兔可通过 E 交谈")
	_expect(actor.skill_cooldown(&"skill_shield") == 0,"NPC 交互优先，E 不会同时施放第二技能")
	ui.open_inventory()
	_expect(current_scene.get_node("NPCDialogue/Panel").visible and ui.mode == "","对话独占输入，不能直接打开行囊")
	current_scene.get_node("MilkRabbit")._close_dialogue()
	actor.position = Vector2(340,527)
	actor.velocity = Vector2.ZERO
	await _frames(10)
	_expect(ui.begin_rest() and ui.mode == "rest","新营地篝火可坐下休息与保存")
	ui.close_menu()
	await _frames(40)
	gs.checkpoint_position = checkpoint
	gs.checkpoint_room = &"camp_01"
	change_scene_to_file("res://scenes/rooms/forest_01.tscn")
	await _frames(10)
	actor = current_scene.get_node("Player")
	actor.respawn()
	for frame in 80:
		await physics_frame
		if current_scene.scene_file_path.ends_with("camp_01.tscn") and not root.get_node("SceneRouter").is_transitioning():
			break
	_expect(current_scene.scene_file_path.ends_with("camp_01.tscn") and absf(current_scene.get_node("Player").position.x-112) < 2,"未坐火的初始检查点支持从森林跨房间重生回营地")
	print("CAMP REDESIGN: %d PASS, %d FAIL" % [passed,failed])
	quit(1 if failed else 0)


func _platform(id: String) -> Rect2:
	for entry: Dictionary in config.platforms:
		if str(entry.id) == id:
			return Rect2(entry.rect[0],entry.rect[1],entry.rect[2],entry.rect[3])
	return Rect2()


func _walk_to(x: float) -> void:
	for frame in 120:
		if absf(actor.position.x-x) <= 3:
			break
		_release_horizontal()
		Input.action_press("move_right" if actor.position.x < x else "move_left")
		await physics_frame
	_release_horizontal()
	await _frames(2)


func _release_horizontal() -> void:
	Input.action_release("move_left")
	Input.action_release("move_right")


func _press_e() -> void:
	var event := InputEventKey.new()
	event.physical_keycode = KEY_E
	event.pressed = true
	Input.parse_input_event(event)


func _release_e() -> void:
	var event := InputEventKey.new()
	event.physical_keycode = KEY_E
	event.pressed = false
	Input.parse_input_event(event)


func _frames(count: int) -> void:
	for frame in count:
		await physics_frame


func _expect(ok: bool, text: String) -> void:
	print("%s: %s" % ["PASS" if ok else "FAIL",text])
	if ok:
		passed += 1
	else:
		failed += 1
