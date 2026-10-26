extends SceneTree
## 系统验收：背包数量守恒、拖拽、快捷栏、拾取失败、坐火动画、仓库、天赋与 CRC 容错。
var gs: Node
var ui: Node
var service: GDScript
var saves: Node
var actor: CharacterBody2D
var failed := 0
var passed := 0


func _initialize() -> void:
	call_deferred("_run")


func _run() -> void:
	get_tree_watchdog()
	gs = root.get_node("GameState")
	ui = root.get_node("GameUI")
	saves = root.get_node("SaveSystem")
	service = load("res://scripts/core/inventory_service.gd")
	service.config().save.directory = "user://qa_gameplay_ui_saves/"
	gs.reset()
	change_scene_to_file("res://scenes/rooms/camp_01.tscn")
	await _frames(10)
	actor = current_scene.get_node("Player")
	_reset()
	_expect(gs.inventory.size() == 15 and gs.hotbar.size() == 5,"15 个行囊格 / 固定五个快捷格")
	_expect(service.add_item("potion_small",12),"获得物品可进入背包")
	_expect(gs.inventory[0].count == 5 and gs.inventory[1].count == 5 and gs.inventory[2].count == 2,"消耗品按 5 个堆叠")
	_expect(service.move_slot(0,10) and gs.inventory[0] == null and gs.inventory[10].count == 5,"拖拽移动保留空位")
	_expect(service.move_slot(1,2) and gs.inventory[1].count == 2 and gs.inventory[2].count == 5,"相同物品拖拽合并且总数守恒")
	_expect(service.count_item("potion_small") == 12,"移动合并不复制物品")
	_expect(service.register_hotbar("potion_small",0),"背包消耗品可登录快捷栏")
	_expect(service.move_slot(0,4,"hotbar") and gs.hotbar[0] == null and gs.hotbar[4].count == 2,"快捷栏之间移动真实堆叠")
	service.add_item("mushroom",101)
	_expect(gs.materials.size() == 2 and service.count_item("mushroom") == 101,"材料独立页按 99 堆叠")
	_expect(not service.register_hotbar("mushroom",1),"材料不可登录快捷栏")
	for index in gs.inventory.size():
		if gs.inventory[index] == null:
			gs.inventory[index] = {"id":"milk_bomb","count":5}
	var snapshot := JSON.stringify(gs.inventory)
	_expect(not service.add_item("potion_mana",1) and JSON.stringify(gs.inventory) == snapshot,"背包满时接收原子失败")
	service.discard_slot(10)
	_expect(gs.hotbar[4].count == 2,"销毁背包堆叠不影响独立快捷物品")
	service.discard_slot(1)
	service.discard_slot(2)
	_expect(service.count_item("potion_small") == 2 and service.discard_slot(4,"hotbar") and gs.hotbar[4] == null and service.count_item("potion_small") == 0,"丢弃快捷堆叠仅销毁其中真实物品")
	_reset()
	service.add_item("potion_small",8)
	service.register_hotbar("potion_small",0)
	_expect(service.deposit(0,"hotbar") and gs.storage[0].count == 5 and service.count_item("potion_small") == 3,"独立快捷物品整格存入仓库守恒")
	_expect(service.withdraw(0) and gs.storage.is_empty() and service.count_item("potion_small") == 8,"仓库取回与背包堆叠守恒")
	service.add_item("mushroom",101)
	_expect(service.deposit(0,"materials") and service.count_item("mushroom") == 2,"材料可存入仓库")
	_expect(service.withdraw(0) and service.count_item("mushroom") == 101,"材料可从仓库取回")
	service.deposit(0)
	for index in gs.inventory.size():
		gs.inventory[index] = {"id":"milk_bomb","count":5}
	snapshot = JSON.stringify(gs.storage)
	_expect(not service.withdraw(0) and JSON.stringify(gs.storage) == snapshot,"背包不足时仓库物品保留")
	_reset()
	gs.hp = 1
	service.add_item("potion_small",3)
	_expect(service.use_slot(0,actor) and gs.hp == 31 and gs.inventory[0].count == 2,"背包使用回复道具并仅扣 1 个")
	gs.hp = gs.hp_max
	_expect(not service.use_slot(0,actor) and gs.inventory[0].count == 2,"生命满时不浪费回复道具")
	service.add_item("bag_expand",1)
	_expect(service.use_slot(1,actor) and service.capacity() == 20 and gs.inventory.size() == 20,"扩容道具真实增加五格")
	service.add_item("hp_fragment",1)
	_expect(service.use_slot(1,actor) and gs.hp_max == 90,"永久属性道具生效")
	gs.bag_upgrades = 3
	service.ensure_state()
	service.add_item("bag_expand",1)
	_expect(not service.use_slot(1,actor) and gs.inventory[1].count == 1,"扩容达上限后不消耗卷轴")
	_reset()
	for index in gs.inventory.size():
		gs.inventory[index] = {"id":"milk_bomb","count":5}
	var pickup_script: GDScript = load("res://scripts/world/world_pickup.gd")
	var pickup: Area2D = pickup_script.new()
	pickup.item_id = "potion_small"
	pickup.count = 1
	pickup.position = Vector2(500,260)
	current_scene.add_child(pickup)
	_expect(not pickup.collect() and not pickup.is_queued_for_deletion(),"满包地面掉落不会消失")
	service.discard_slot(0)
	_expect(pickup.collect() and not pickup.collect() and service.count_item("potion_small") == 1,"拾取成功仅结算一次")
	await _frames(2)
	_reset()
	service.add_item("potion_small",3)
	service.add_item("potion_mana",2)
	var tab := InputEventAction.new()
	tab.action = &"inventory"
	tab.pressed = true
	ui._input(tab)
	await _frames(2)
	_expect(ui.mode == "inventory" and paused,"Tab 打开背包并冻结世界")
	_expect(ui._view_slots.size() == 16 and ui._view_slots[15].locked,"4×4 网格含十五格和一个锁定格")
	ui._slot_activated("inventory",0)
	_expect(ui._details.get_child_count() > 0,"点击物品显示详情和操作")
	ui._slot_activated("inventory",8)
	_expect(ui._details.get_child_count() == 0,"点击空格清空详情")
	ui._slot_dropped({"source":"inventory","index":0,"id":"potion_small"},"hotbar",2)
	_expect(gs.hotbar[2].id == "potion_small" and gs.inventory[0] == null and service.count_item("potion_small") == 3,"拖入快捷栏搬移实际物品且腾空背包格")
	ui._slot_dropped({"source":"hotbar","index":2,"id":"potion_small"},"inventory",8)
	_expect(gs.hotbar[2] == null and gs.inventory[8].id == "potion_small" and service.count_item("potion_small") == 3,"拖回指定行囊格卸载且不销毁物品")
	ui._slot_dropped({"source":"inventory","index":8,"id":"potion_small"},"inventory",6)
	_expect(gs.inventory[8] == null and gs.inventory[6].id == "potion_small","UI 拖拽整理实际修改格位置")
	var frozen: Vector2 = actor.position
	Input.action_press(&"move_right")
	await _frames(12)
	Input.action_release(&"move_right")
	_expect(actor.position == frozen,"打开菜单后角色不能移动")
	ui._input(tab)
	_expect(ui.mode == "" and not paused,"再次 Tab 关闭背包恢复世界")
	_reset()
	gs.level = 4
	gs.coin = 500
	_expect(not service.buy_talent(&"brute_2"),"天赋未满足前置时不能购买")
	var damage_before: int = actor.attack_damage()
	_expect(service.buy_talent(&"brute_1") and gs.coin == 400 and service.available_points() == 2,"天赋消费点数和奶币")
	_expect(actor.attack_damage() > damage_before,"天赋物攻加成实时影响伤害")
	_expect(service.buy_talent(&"milk_1") and gs.mana_max == 80,"天赋上限增量生效")
	_expect(service.buy_talent(&"milk_2") and service.skill_unlocked(&"skill_shield"),"前置天赋解锁第二技能")
	gs.coin = 500
	_expect(service.reset_talents() and gs.coin == 300 and gs.mana_max == 60 and service.available_points() == 3,"重置退点不退奶币并撤销上限加成")
	_expect(not service.skill_unlocked(&"skill_shield"),"重置后撤销天赋技能")
	_reset()
	actor.position = Vector2(service.config().campfires.camp_01.ground[0]-12,service.config().campfires.camp_01.ground[1]-17)
	actor.velocity = Vector2.ZERO
	await _frames(8)
	gs.hp = 1
	gs.sta = 1
	gs.mana = 1
	_expect(ui.begin_rest(),"E 交互可进入坐火机制")
	_expect(ui.mode == "rest" and paused and actor.sprite.animation == &"rest_enter","坐下动画与休息菜单同时开启")
	_expect(gs.hp == 80 and gs.sta == 100 and gs.mana == 60,"坐火恢复三种资源")
	_expect(gs.checkpoint_id == &"cp_camp_01" and actor.checkpoint_position == actor.position,"坐火绑定真实复活点")
	await _frames(60)
	_expect(actor.sprite.animation == &"rest","暂停世界时仍播放坐姿循环")
	_expect(saves.has_save(),"坐火立即产生可校验存档")
	ui._show_talents()
	_expect(ui.mode == "talents" and paused,"休息菜单可打开天赋")
	ui.close_menu()
	_expect(ui.mode == "rest","天赋关闭后返回坐火菜单")
	ui._show_storage()
	_expect(ui.mode == "storage" and ui._view_slots.size() >= 32,"休息菜单可打开双栏仓库")
	ui.close_menu()
	ui.close_menu()
	await _frames(40)
	_expect(ui.mode == "" and not paused and actor.sprite.process_mode == Node.PROCESS_MODE_INHERIT,"起身后关闭菜单并恢复游戏")
	_reset()
	gs.in_combat = true
	_expect(not ui.begin_rest(),"战斗中不能坐火")
	_expect(saves.save_game(95) == ERR_BUSY,"战斗中禁止自动存档")
	gs.in_combat = false
	saves.delete_save(95)
	service.add_item("potion_small",2)
	gs.coin = 10
	_expect(saves.save_game(95) == OK,"首次保存 A 槽成功")
	gs.coin = 77
	_expect(saves.save_game(95) == OK,"第二次保存 B 槽成功")
	gs.coin = 123
	_expect(saves.save_game(95) == OK,"轮换保存并保留备份成功")
	var corrupt := FileAccess.open(saves._slot_path(95,0),FileAccess.WRITE)
	corrupt.store_string("{ broken")
	corrupt.close()
	_expect(saves.load_game(95) and gs.coin == 77,"最新槽 JSON 损坏可回退另一槽")
	corrupt = FileAccess.open(saves._slot_path(95,1),FileAccess.WRITE)
	corrupt.store_string("{}")
	corrupt.close()
	_expect(saves.load_game(95) and gs.coin == 10,"两个主槽损坏仍可恢复 bak")
	_expect(service.count_item("potion_small") == 2,"存档恢复背包数量")
	saves.restoring = false
	saves.delete_save(95)
	_expect(not saves.has_save(95),"QA 档位清理完成")
	_reset()
	_expect(service.add_item("milk_staff",1) and gs.owned_weapons.has(&"milk_staff") and service.count_item("milk_staff") == 0,"武器进入独立装备栏而不占行囊")
	gs.level = 5
	gs.coin = 1000
	for id in [&"milk_1",&"milk_2",&"milk_3",&"milk_4"]:
		service.buy_talent(id)
	_expect(service.skill_unlocked(&"skill_starfall") and service.equip_skill(&"skill_starfall",2),"第五个奶术可解锁并装备至第三主动槽")
	_expect(service.skill_mana_cost(&"skill_starfall") == 26,"技能奶力消耗与天赋减耗一致")
	actor.position = Vector2(100,service.config().campfires.camp_01.ground[1]-17)
	gs.mana = gs.mana_max
	_expect(actor.cast_ui_skill(&"skill_starfall"),"星乳坠落有真实施法入口")
	await _frames(65)
	_expect(actor.skill_cooldown(&"skill_starfall") > 0,"星乳坠落进入独立冷却")
	gs.mana = gs.mana_max
	var e := InputEventKey.new()
	e.physical_keycode = KEY_E
	e.pressed = true
	Input.parse_input_event(e)
	await _frames(3)
	e.pressed = false
	Input.parse_input_event(e)
	_expect(actor.skill_cooldown(&"skill_shield") == 0,"新键位下 E 只负责交互，不再施放技能")
	await _frames(30)
	actor.reset_cooldowns()
	actor.position = Vector2(service.config().campfires.camp_01.ground[0]-12,service.config().campfires.camp_01.ground[1]-17)
	actor.velocity = Vector2.ZERO
	await _frames(8)
	e.pressed = true
	Input.parse_input_event(e)
	await _frames(2)
	e.pressed = false
	Input.parse_input_event(e)
	_expect(ui.mode == "rest" and actor.skill_cooldown(&"skill_shield") == 0,"附近有篝火时 E 优先交互且不施法")
	ui.close_menu()
	await _frames(40)
	change_scene_to_file("res://scenes/rooms/forest_01.tscn")
	await _frames(10)
	var outside := [Vector2(16,120),Vector2(16,1500),Vector2(1264,400),Vector2(1264,1200),Vector2(400,24)]
	for point: Vector2 in outside:
		var query := PhysicsPointQueryParameters2D.new()
		query.position = point
		query.collision_mask = 1
		_expect(not current_scene.get_world_2d().direct_space_state.intersect_point(query).is_empty(),"外部空白区域 %s 已填为实心墙" % point)
	for door in ["DoorWest","DoorEast","DoorEastShortcut"]:
		_expect(not current_scene.get_node(door).has_node("Label"),"%s 不显示通道说明文字" % door)
	_expect(current_scene.get_node("Wall_west_trunk").material.get_shader_parameter("coverage_texture") != null,"墙体边缘过渡具有完整占用遮罩")
	print("GAMEPLAY SYSTEMS: %d PASS, %d FAIL" % [passed,failed])
	quit(1 if failed else 0)


func get_tree_watchdog() -> void:
	create_timer(25,true).timeout.connect(func() -> void:
		print("FAIL: gameplay test timed out")
		quit(1))


func _reset() -> void:
	gs.reset()
	service.ensure_state()


func _frames(count: int) -> void:
	for frame in count:
		await process_frame


func _expect(ok: bool, label: String) -> void:
	print("%s: %s" % ["PASS" if ok else "FAIL",label])
	if ok:
		passed += 1
	else:
		failed += 1
