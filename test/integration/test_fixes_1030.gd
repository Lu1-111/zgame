extends SceneTree
## 使用真实场景、侧键状态、怪物碰撞与地图点击覆盖 2026-10-30 制作人回归。
var actor: Node
var ui: Node
var gs: Node
var failures := 0
var passed := 0

func _initialize() -> void:
	call_deferred("_run")

func _run() -> void:
	create_timer(60,true,false,true).timeout.connect(func() -> void: quit(2))
	ui = root.get_node("GameUI")
	gs = root.get_node("GameState")
	gs.reset()
	await _room("camp_01")
	actor.position = Vector2(312,527)
	await _frames(8)
	actor.set_physics_process(false)
	actor.skills.set_physics_process(false)
	await _quickdraw()
	await _dodge()
	await _enemy_attacks()
	await _rest_and_travel()
	ui._force_close()
	Input.action_release("cast_selected")
	print("FIXES 1030: %d PASS, %d FAIL" % [passed,failures])
	quit(1 if failures else 0)

func _quickdraw() -> void:
	gs.weapon_id = &"sword_01"
	for moment in [0.0,0.19,0.21,0.69]:
		_reset_action()
		Input.action_press("cast_selected")
		_check(actor.cast_ui_skill(&"skill_nb_quickdraw"),"拔刀按住侧键开始 %.2f" % moment)
		actor.skills.tick(moment)
		var hp: int = gs.hp
		_check(actor.apply_hit(_packet()) == 0 and gs.hp == hp and actor.skills._counter_triggered,"架势进入与维持 %.2f 秒受击立即反击免伤" % moment)
		_check(not actor.skills.parry(_packet()),"一次架势只触发一次反击")
	for moment in [0.1,0.35]:
		_reset_action()
		Input.action_press("cast_selected")
		actor.cast_ui_skill(&"skill_nb_quickdraw")
		actor.skills.tick(moment)
		Input.action_release("cast_selected")
		_check(not actor.skills.parry(_packet()),"%.2f 秒松键即取消反击窗口" % moment)
		actor.sm.tick(0.001)
		_check(actor.sm.current_name() == &"Idle","松键后一帧内离开架势")
	_reset_action()
	Input.action_press("cast_selected")
	actor.cast_ui_skill(&"skill_nb_quickdraw")
	actor.sm.tick(0.699)
	_check(actor.sm.current_name() == &"Skill","架势在0.7秒前持续保持")
	actor.sm.tick(0.002)
	_check(actor.sm.current_name() == &"Idle" and not actor.skills._counter_triggered,"0.7秒未受击直接取消，不自动攻击")
	_reset_action()

func _dodge() -> void:
	gs.sta = gs.sta_max
	var origin: Vector2 = actor.position
	actor.sm.to(&"Dodge",{"dir":1})
	_check(actor.dodge_iframe and actor.apply_hit(_packet()) == 0,"闪避起始帧立即无敌")
	for frame in 20:
		actor.sm.tick(0.01)
		if actor.sm.current_name() == &"Dodge":
			actor.move_and_collide(actor.velocity*0.01)
			_check(actor.dodge_iframe and actor.apply_hit(_packet()) == 0,"闪避第%d帧保持无敌" % frame)
	actor.sm.tick(0.001)
	_check(actor.sm.current_name() != &"Dodge" and not actor.dodge_iframe,"闪避0.2秒结束并解除无敌")
	_check(actor.position.x-origin.x <= 82.6 and actor.position.x-origin.x >= 78,"闪避位移约82.5像素，为上一版1.5倍")
	actor.position = origin
	_reset_action()

func _enemy_attacks() -> void:
	for id in [&"moss_beetle",&"milk_slime",&"vine_flower"]:
		var enemy := _enemy(id,Vector2(440,544))
		actor.position = Vector2(416,527)
		actor.collision_layer = 0
		await _frames(5)
		_check(enemy.state == &"telegraph","%s 能从贴身距离主动进入攻击预警" % id)
		enemy.set_physics_process(false)
		for variant in (2 if id == &"milk_slime" else 1):
			if variant > 0:
				enemy._set_state(&"telegraph")
			actor._invuln = 0
			actor.sm.to(&"Idle")
			gs.hp = 80
			var near := 45 if id == &"milk_slime" and variant == 0 else 24
			actor.position = enemy.position+Vector2(near,-17)
			enemy.facing = 1
			if id == &"vine_flower":
				enemy._set_state(&"telegraph")
			enemy._set_state(&"attack")
			var expected := &"grab_attack" if id == &"milk_slime" and variant == 0 else &"attack"
			_check(enemy.visual.body.visible and enemy.visual.body.animation == expected,"%s 第%d招播放自己的完整攻击动作" % [id,variant])
			var frame_start: int = enemy.visual.body.frame
			await _frames(8)
			_check(enemy.visual.body.frame > frame_start,"%s 攻击逐帧向前播放" % id)
			enemy._physics_process(float(enemy._combat_value("attack_hit_start"))+0.001)
			if id == &"vine_flower":
				await _frames(6)
			_check(gs.hp < 80,"%s 接触有效攻击框或投射物才受到伤害" % id)
			# 重新开始同招并把玩家放远；只触发动画不能直接扣血。
			actor._invuln = 0
			actor.sm.to(&"Idle")
			gs.hp = 80
			actor.position = Vector2(300,527)
			enemy._set_state(&"attack")
			await _frames(3)
			enemy._physics_process(float(enemy._combat_value("attack_hit_start"))+0.001)
			_check(gs.hp == 80,"%s 攻击未接触不会直接扣血" % id)
		if id == &"vine_flower":
			var projectile_seen := false
			for child in current_scene.get_children():
				if child.get_script() == load("res://scripts/enemies/combat_enemy_projectile.gd"):
					projectile_seen = true
					child.queue_free()
			_check(projectile_seen,"藤鞭花在攻击时发出可碰撞投射物")
		var killing := _packet()
		killing.amount = 999
		enemy.receive_hit(killing)
		_check(enemy.hp == 0 and enemy._health_trail == 0 and enemy.state == &"death","%s 最后一击血量与血条尾迹同时清空" % id)
		enemy.queue_free()
		await _frames(2)
	actor.collision_layer = 2
	_reset_action()

func _rest_and_travel() -> void:
	await _room("forest_02")
	_check(get_nodes_in_group("enemies").size() == 25,"forest_02 25个草图红三角均生成小怪")
	var cfg: Dictionary = current_scene.config
	var types := {}
	var contacts_ok := true
	for enemy in get_nodes_in_group("enemies"):
		types[enemy.enemy_id] = true
		contacts_ok = contacts_ok and absf(enemy.position.y-enemy.origin.y) < 2 and enemy.is_on_floor()
		_check(str(enemy.definition.rank) == "small","%s 不混入精英" % enemy.get_meta("spawn_id"))
	_check(types.size() == 3 and contacts_ok,"三种小怪均在指定地面或空心平台落稳")
	var victim := current_scene.get_node("Enemy_f02_cave_floor_l") as Node
	victim.set_physics_process(false)
	victim.receive_hit(DamagePacket.new(8))
	var damaged: int = victim.hp
	actor.position = Vector2(304,1695)
	await _frames(8)
	gs.hp = 12
	gs.sta = 13
	gs.mana = 14
	_check(ui.begin_rest(),"forest_02 可坐火")
	_check(gs.hp == 12 and gs.sta == 13 and gs.mana == 14 and victim.hp == damaged,"只进菜单既不回资源也不刷新敌人")
	_check(gs.unlocked_campfires == [&"cp_forest_02_roots"],"初次互动解锁该篝火")
	ui.open_fast_travel()
	var view := ui.modal.get_node("WorldMapView") as WorldMapView
	_check(ui.mode == "travel" and view.travel_mode and view.unlocked_fire_markers().size() == 1,"快速旅行只标识已解锁的火")
	var close_event := InputEventAction.new()
	close_event.action = &"map"
	close_event.pressed = true
	ui._input(close_event)
	_check(ui.mode == "rest" and paused,"旅行关闭返回坐火菜单")
	ui.open_fast_travel()
	close_event.action = &"pause"
	ui._input(close_event)
	_check(ui.mode == "rest" and paused,"Esc 关闭快速旅行，不叠加暂停菜单")
	ui.open_fast_travel()
	var original_scene := current_scene
	ui._travel_to_campfire(&"forest_02",&"cp_forest_02_roots")
	for frame in 120:
		await process_frame
		if not root.get_node("SceneRouter").is_transitioning():
			break
	_check(current_scene == original_scene and is_instance_valid(victim) and victim.hp == damaged and gs.hp == 12,"当前房间火点旅行保留受损怪物和玩家资源")
	_check(ui.begin_rest(),"同房间旅行后可再次坐火")
	ui._rest_action("休息")
	await _frames(3)
	_check(gs.hp == gs.hp_max and gs.sta == gs.sta_max and gs.mana == gs.mana_max,"点击休息才回满三种状态")
	var refreshed := true
	for enemy in get_nodes_in_group("enemies"):
		refreshed = refreshed and enemy.hp == int(enemy.definition.hp)
	_check(get_nodes_in_group("enemies").size() == 25 and refreshed,"休息刷新所有普通敌人为出生状态")
	var west_ids: Array = cfg.encounters[0].spawn_ids
	for enemy in get_nodes_in_group("enemies"):
		if west_ids.has(str(enemy.get_meta("spawn_id"))):
			enemy.set_physics_process(false)
			enemy.receive_hit(DamagePacket.new(999))
	_check(current_scene._encounter_cleared("f02_west_trial"),"守箱怪生命归零即解除封印，不必等尸体消失")
	gs.unlocked_campfires.append(&"cp_camp_01")
	var snapshot: Dictionary = gs.to_save_dict()
	gs.load_from_dict(snapshot)
	_check(gs.unlocked_campfires.size() == 2,"已解锁篝火列表可存档往返")
	ui.open_fast_travel()
	view = ui.modal.get_node("WorldMapView")
	_check(view.unlocked_fire_markers().size() == 2,"未互动的 forest_01 篝火仍隐藏")
	var rect := view.fire_view_rect("camp_01")
	var mouse := InputEventMouseButton.new()
	mouse.button_index = MOUSE_BUTTON_LEFT
	mouse.position = rect.get_center()
	mouse.pressed = true
	view.handle_map_pointer(mouse)
	mouse = mouse.duplicate()
	mouse.pressed = false
	view.handle_map_pointer(mouse)
	for frame in 180:
		await process_frame
		if not root.get_node("SceneRouter").is_transitioning():
			break
	_check(gs.current_room == &"camp_01" and current_scene.scene_file_path.ends_with("camp_01.tscn"),"点击篝火图标完成跨地图快速旅行")
	actor = current_scene.get_node("Player")
	var destination: Dictionary = load("res://scripts/core/campfire_service.gd").destination(&"camp_01")
	_check(actor.position.distance_to(Vector2(destination.position[0],destination.position[1])) < 2,"旅行落点在目标篝火旁")
	_check(gs.checkpoint_id == &"cp_camp_01" and gs.checkpoint_room == &"camp_01" and not paused,"旅行同步复活点并解除菜单暂停")
	_check(not root.get_node("SceneRouter").goto_checkpoint(&"forest_01",&"cp_forest_01_tree",Vector2.ZERO),"未解锁篝火不能经路由绕过校验")

func _room(id: String) -> void:
	ui._force_close()
	change_scene_to_file("res://scenes/maps/%s.tscn" % id)
	await _frames(12)
	actor = current_scene.get_node("Player")

func _enemy(id: StringName, position: Vector2) -> Node:
	var enemy := (load("res://scenes/enemies/combat_enemy.tscn") as PackedScene).instantiate() as Node
	enemy.enemy_id = id
	enemy.position = position
	enemy.target = actor
	current_scene.add_child(enemy)
	return enemy

func _reset_action() -> void:
	Input.action_release("cast_selected")
	actor.sm.to(&"Idle")
	actor.clear_action_buffers()
	actor.reset_cooldowns()
	actor._invuln = 0
	actor.dodge_iframe = false
	gs.hp = 80
	gs.sta = 100
	gs.mana = 60

func _packet() -> DamagePacket:
	return DamagePacket.new(20,DamagePacket.DamageType.PHYSICAL,0,actor.position+Vector2.RIGHT*30)

func _frames(count: int) -> void:
	for frame in count:
		await process_frame

func _check(ok: bool, label: String) -> void:
	print("%s: %s" % ["PASS" if ok else "FAIL",label])
	if ok:
		passed += 1
	else:
		failures += 1
