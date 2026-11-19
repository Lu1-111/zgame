extends SceneTree
## 真实怪物破韧、所有入口标记、任务条件和奖励、L输入及地图/HUD追踪回归。
var actor: Node
var ui: Node
var gs: Node
var quests: GDScript
var rules: GDScript
var failed := 0
var passed := 0

func _initialize() -> void:
	call_deferred("_run")

func _run() -> void:
	create_timer(60,true,false,true).timeout.connect(func() -> void: quit(2))
	gs = root.get_node("GameState")
	ui = root.get_node("GameUI")
	quests = load("res://scripts/core/quest_service.gd")
	rules = load("res://scripts/core/poise_rules.gd")
	gs.reset()
	change_scene_to_file("res://scenes/maps/camp_01.tscn")
	await _frames(12)
	actor = current_scene.get_node("Player")
	actor.set_physics_process(false)
	actor.skills.set_physics_process(false)
	await _poise()
	await _quests()
	ui._force_close()
	print("QUESTS AND POISE: %d PASS, %d FAIL" % [passed,failed])
	quit(1 if failed else 0)

func _poise() -> void:
	var config: Dictionary = rules.config()
	var defaults: Dictionary = config.attacks.duplicate(true)
	for type in ["combat_enemy","enemy"]:
		var enemy: Node = load("res://scenes/enemies/%s.tscn" % type).instantiate()
		enemy.position = Vector2(448,544)
		enemy.target = actor
		current_scene.add_child(enemy)
		enemy.set_physics_process(false)
		enemy.definition = enemy.definition.duplicate(true)
		enemy.definition.hp = 500
		enemy.hp = 500
		await _frames(3)
		enemy._set_state(&"attack")
		enemy.elapsed = 0.05
		enemy.velocity.x = 30
		var packet := DamagePacket.new(2,DamagePacket.DamageType.PHYSICAL,100,actor.position,&"hammer_01")
		packet.poise_key = &"normal:hammer_01:1"
		_check(enemy.poise.current == 100,"%s 初始100韧性" % type)
		enemy.receive_hit(packet)
		_check(enemy.poise.current == 100 and enemy.state == &"attack" and enemy.elapsed == 0.05 and enemy.velocity.x == 30,"%s 待填削韧值为零，受击不打断攻击或改变速度" % type)
		config.attacks[str(packet.poise_key)].poise_damage = 35
		enemy.receive_hit(packet)
		_check(enemy.poise.current == 65 and enemy.state == &"attack","%s 未破韧保持原行动" % type)
		enemy._physics_process(0.01)
		_check(not enemy.visual.position.is_zero_approx(),"%s 未破韧仍产生美术节点震动" % type)
		config.attacks[str(packet.poise_key)].poise_damage = 65
		enemy.receive_hit(packet)
		_check(enemy.poise.current == 0 and enemy.poise.broken and enemy.state == &"hurt" and enemy.visual.body.animation == &"hurt","%s 破韧立即中断并播放硬直" % type)
		enemy.elapsed = 0.08
		var hp: int = enemy.hp
		enemy.receive_hit(packet)
		_check(enemy.hp < hp and enemy.elapsed == 0.08 and enemy.poise.current == 0,"%s 硬直内继续扣生命但不重启硬直" % type)
		await _frames(20)
		_check(enemy.poise.current == 100 and not enemy.poise.broken and enemy.state != &"hurt","%s 真实硬直动画结束回满韧性" % type)
		config.attacks[str(packet.poise_key)].poise_damage = 100
		enemy.receive_hit(packet)
		gs.hp = 0
		enemy._physics_process(float(enemy.tuning.hurt_duration))
		_check(enemy.poise.current == 100 and enemy.state != &"hurt","%s 玩家死亡也不阻止硬直结束恢复韧性" % type)
		gs.hp = 80
		enemy.queue_free()
		await _frames(2)
		config.attacks = defaults.duplicate(true)
	gs.weapon_id = &"sword_01"
	for combo in [1,2,3]:
		var packet: DamagePacket = actor.build_attack_packet(combo)
		_check(str(packet.poise_key) == "normal:sword_01:%d" % combo,"剑第%d段绑定独立削韧键" % combo)
	# 对照运行时所有技能事件键与表，不允许遗漏任何段。
	var runtime: Dictionary = JSON.parse_string(FileAccess.get_file_as_string("res://data/skill_runtime.json"))
	for id: String in runtime.skills:
		var skill: Dictionary = runtime.skills[id]
		match str(skill.behavior):
			"slash","prison":
				for index in skill.hits.size():
					_check(config.attacks.has("%s:hit_%d" % [id,index+1]),"%s 事件%d 已登记削韧" % [id,index+1])
			"beam":
				for tier: Dictionary in skill.charge.tiers:
					_check(config.attacks.has(id+":"+str(tier.name)),"光炮%s 档已登记" % tier.name)
			"dash","slam","quickdraw","mirror": _check(config.attacks.has(id+":hit"),id+" 主命中已登记")
			"orb": _check(config.attacks.has(id+":contact") and config.attacks.has(id+":explosion"),"光球接触和爆炸独立登记")
	_check(config.attacks["normal:hammer_01:1"].poise_damage == null,"QA临时削韧值已还原，不应用任何测试数值")

func _quests() -> void:
	quests.refresh()
	_check(quests.list_quests().size() == 3,"三条可运行示例任务初始化")
	var all: Array = quests.list_quests()
	_check(all[0].category == "main" and all[1].category == "side" and all[2].category == "exploration","全部页签按主线支线探索排序")
	_check(quests.list_quests("side").size() == 1 and quests.list_quests("exploration").size() == 1,"分类仅列出符合的任务")
	await _press("quests")
	_check(ui.mode == "quests" and paused and ui.modal.has_node("Quest_main_forest_fire") == false,"L打开模态任务面板并暂停")
	_check(ui.modal.find_child("Quest_main_forest_fire",true,false) != null and ui.modal.find_child("TrackQuest",true,false) != null,"任务列表和详情追踪按钮存在")
	ui.modal.find_child("TrackQuest",true,false).pressed.emit()
	_check(gs.tracked_quest == &"main_forest_fire" and ui.modal.find_child("TrackQuest",true,false).text == "取消追踪","点击追踪将任务置为唯一当前任务并更新按钮")
	ui.modal.find_child("TrackQuest",true,false).pressed.emit()
	_check(gs.tracked_quest == &"","再次点击取消追踪将当前任务置空")
	quests.toggle_tracking(&"main_forest_fire")
	await _press("quests")
	await _frames(2)
	_check(ui.mode == "" and not paused and ui._quest_tracker.visible and "林间的星火" in ui._quest_title.text,"L关闭面板，HUD左侧显示当前任务")
	_check(ui._quest_objective.get_line_count() >= 2 and ui._quest_objective.get_visible_line_count() >= 2,"HUD任务框显示全部两条条件，文字不被裁掉")
	ui.open_world_map()
	var view: Node = ui.modal.get_node("WorldMapView")
	var marker: Dictionary = view.tracked_quest_marker()
	_check(marker.room == "forest_01" and marker.position == view.project_room_position("forest_01",Vector2(1088,672)),"小地图任务标记投影到真实目标房间")
	var quest: Dictionary = quests.definition(&"main_forest_fire")
	var location: Dictionary = quest.location
	quest.erase("location")
	_check(view.tracked_quest_marker().is_empty() and quests.tracked().name == "林间的星火","无地点任务仍可追踪且不画伪造标记")
	quest.location = location
	await _press("pause")
	_check(ui.mode == "" and not paused,"Esc关闭地图没有残留暂停")
	var before: int = gs.coin
	_check(not quests.claim(&"main_forest_fire") and gs.coin == before,"任务未完成不能领取奖励")
	gs.visited_rooms.append(&"forest_01")
	quests.refresh()
	_check(not gs.quest_state.main_forest_fire.completed,"只满足部分条件不会提前完成")
	gs.unlocked_campfires.append(&"cp_forest_01_tree")
	quests.refresh()
	_check(gs.quest_state.main_forest_fire.completed,"真实世界进度全部满足后完成任务")
	_check(quests.claim(&"main_forest_fire") and gs.coin == before+30 and gs.exp == 10,"领取任务奖励只结算配置的奶币与经验")
	_check(not quests.claim(&"main_forest_fire") and gs.coin == before+30 and gs.tracked_quest == &"","重复领取被拒绝且领取后清除追踪")
	quests.toggle_tracking(&"explore_ancient_roots")
	_check(gs.tracked_quest == &"explore_ancient_roots","切换追踪替换当前任务")
	var snapshot: Dictionary = gs.to_save_dict()
	gs.reset()
	gs.load_from_dict(snapshot)
	quests.refresh()
	_check(gs.tracked_quest == &"explore_ancient_roots" and gs.quest_state.main_forest_fire.claimed,"任务追踪和已领奖状态可以存档往返")
	ui.open_quests()
	ui._quest_panel.category = "side"
	ui._quest_panel.open()
	_check(ui.modal.find_child("Quest_side_camp_supplies",true,false) != null and ui.modal.find_child("Quest_main_forest_fire",true,false) == null,"侧栏页签只渲染对应分类")
	await _press("pause")
	_check(ui.mode == "" and not paused,"Esc关闭任务面板并恢复游戏")
	quests.toggle_tracking(&"explore_ancient_roots")
	await _frames(2)
	_check(not ui._quest_tracker.visible,"取消追踪后HUD任务框隐藏")
	var original: Array = quests.config().quests.duplicate(true)
	quests.config().quests.append({"id":"qa_kills","name":"QA击杀条件","category":"side","initial":false,"conditions":[{"kind":"kill","id":"moss_beetle","count":2,"text":"击败苔甲虫"}],"rewards":{"coin":0,"exp":0}})
	quests.accept(&"qa_kills")
	root.get_node("EventBus").emit_signal("enemy_died",&"moss_beetle",Vector2.ZERO)
	_check(quests.condition_progress(&"qa_kills",quests.definition(&"qa_kills").conditions[0]) == 1 and not gs.quest_state.qa_kills.completed,"真实死亡事件推进击杀任务且不提前完成")
	root.get_node("EventBus").emit_signal("enemy_died",&"moss_beetle",Vector2.ZERO)
	_check(gs.quest_state.qa_kills.completed,"累计击杀条件达到目标后完成")
	quests.config().quests = original

func _press(action: String) -> void:
	var event := InputEventAction.new()
	event.action = StringName(action)
	event.pressed = true
	Input.parse_input_event(event)
	await process_frame
	event = event.duplicate()
	event.pressed = false
	Input.parse_input_event(event)
	await process_frame

func _frames(count: int) -> void:
	for frame in count:
		await process_frame

func _check(ok: bool, label: String) -> void:
	print("%s: %s" % ["PASS" if ok else "FAIL",label])
	if ok:
		passed += 1
	else:
		failed += 1
