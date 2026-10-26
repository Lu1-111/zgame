extends SceneTree
## 用实际武器碰撞链路验证伤害、击杀、隔层视野、混合平台和身体阻挡。
var passed := 0
var failed := 0
var actor: Node
var victim: Node
var gs: Node


func _initialize() -> void:
	call_deferred("_run")


func _run() -> void:
	create_timer(90,true,false,true).timeout.connect(func() -> void: quit(2))
	gs = root.get_node("GameState")
	gs.reset()
	var room := Node2D.new()
	room.name = "CombatRegressionRoom"
	root.add_child(room)
	current_scene = room
	_floor(room,Rect2(0,260,220,40),false)
	_floor(room,Rect2(220,260,180,4),true)
	_floor(room,Rect2(400,260,220,40),false)
	actor = load("res://scenes/player/player.tscn").instantiate()
	actor.set_script(load("res://tools/fixtures/aimed_player.gd"))
	actor.name = "Player"
	actor.position = Vector2(80,243)
	room.add_child(actor)
	await _frames(8)
	gs.hp_max = 999
	gs.hp = 999
	victim = _spawn(Vector2(122,260))
	victim.set_physics_process(false)
	await _frames(3)
	_aim_at(victim.global_position+Vector2(0,-14))
	actor.sm.to(&"Attack",{"combo":1})
	await _frames(25)
	_expect(victim.hp > 0 and victim.hp < 30,"真实锤击经武器碰撞框扣血，一次挥击只结算一次")
	_expect(victim._feedback_left > 0 and victim._flash_left > 0,"扣血触发敌人血条、受击闪光与独立反馈计时")
	var saw_number := false
	for child in room.get_children():
		saw_number = saw_number or child is DamageNumber
	_expect(saw_number,"实际命中产生伤害飘字")
	await _frames(15)
	var exp_before: int = gs.exp
	actor.sm.to(&"Attack",{"combo":1})
	await _frames(25)
	_expect(victim.hp == 0 and gs.exp > exp_before,"第二次真实锤击能击杀并结算经验")
	var exp_after: int = gs.exp
	actor.spawn_melee_effect(1)
	await _frames(8)
	_expect(gs.exp == exp_after,"死亡后剩余攻击不会重复发奖励")
	if is_instance_valid(victim):
		victim.queue_free()
	await _frames(3)
	actor.cancel_weapon_action()
	gs.weapon_id = &"sword_01"
	victim = _spawn(Vector2(122,260))
	victim.set_physics_process(false)
	_aim_at(victim.global_position+Vector2(0,-14))
	for combo in [1,2,3]:
		actor.sm.to(&"Attack",{"combo":combo})
		await _frames(29)
	_expect(victim.hp == 0,"三段剑击使用真实碰撞并能击杀小怪")
	if is_instance_valid(victim):
		victim.queue_free()
	await _frames(3)
	actor.cancel_weapon_action()
	for weapon in [&"bow_01",&"milk_staff"]:
		gs.weapon_id = weapon
		victim = _spawn(Vector2(160,260))
		victim.set_physics_process(false)
		_aim_at(victim.global_position+Vector2(0,-14))
		var first_hit := false
		var ranged_exp: int = gs.exp
		for shot in 4:
			if not is_instance_valid(victim) or victim.hp <= 0:
				break
			if weapon == &"bow_01":
				Input.action_press("attack")
			actor.sm.to(&"Attack")
			await _frames(35 if weapon == &"bow_01" else 2)
			Input.action_release("attack")
			await _frames(45)
			first_hit = first_hit or not is_instance_valid(victim) or victim.hp < 30
		_expect(first_hit and gs.exp > ranged_exp,"%s 真实投射物能够扣血并击杀" % weapon)
		if is_instance_valid(victim):
			victim.queue_free()
		await _frames(3)
		actor.cancel_weapon_action()
	gs.weapon_id = &"bow_01"
	victim = _spawn(Vector2(80,145))
	victim.set_physics_process(false)
	_aim_at(victim.global_position+Vector2(0,-14))
	Input.action_press("attack")
	actor.sm.to(&"Attack")
	await _frames(5)
	_expect(actor._pixel_rig.visible and not actor.sprite.visible and actor._pixel_rig._whole_body.rotation < 0 and actor._pixel_rig.kind == "rifle","向上持枪双臂与完整人物随枪口同步瞄准")
	_expect(actor._pixel_rig._source_rect.size == Vector2(64,64) and actor._pixel_rig._whole_body.scale == Vector2.ONE and actor._pixel_rig.source.resource_path.begins_with("res://assets/PROCESSED/characters/CHR-01/v001/frames/"),"新动作直接使用正式完整人物母版，只替换双臂，不缩放和拼接头身")
	_aim_at(actor.global_position+Vector2(-50,-100))
	await _frames(2)
	_expect(actor.facing == -1 and actor._pixel_rig.facing == -1,"持枪期间向左移光标会实时切换人物朝向")
	_aim_at(victim.global_position+Vector2(0,-14))
	await _frames(2)
	Input.action_release("attack")
	await _frames(35)
	_expect(victim.hp < 30,"垂直瞄准时子弹由对应枪口位置发射，能命中上方目标")
	victim.queue_free()
	await _frames(3)
	actor.cancel_weapon_action()
	actor.set_physics_process(false)
	actor.collision_layer = 0
	victim = _spawn(Vector2(180,260))
	victim.patrol_bounds = Vector2(160,195)
	actor.position = Vector2(250,147)
	await _frames(30)
	_expect(victim.state not in [&"chase",&"attack",&"telegraph"],"横向很近但隔一层平台时不会索敌或攻击")
	victim.position = Vector2(180,260)
	for frame in 200:
		actor.position = victim.position+Vector2(100,-17)
		await physics_frame
	_expect(victim.position.x > 420 and victim.is_on_floor(),"追击能跨过实心→空心→实心交界，不被巡逻边界卡住")
	var wall := _floor(room,Rect2(victim.position.x+30,170,12,90),false)
	actor.position = victim.position+Vector2(80,-17)
	await _frames(8)
	_expect(victim.state not in [&"chase",&"attack",&"telegraph"],"实心墙遮挡时丢失视线，不隔墙攻击")
	wall.queue_free()
	actor.position = victim.position+Vector2(300,-17)
	await _frames(4)
	_expect(victim.state != &"chase","超过近距离感知范围后恢复巡逻")
	victim.set_physics_process(false)
	victim.position = Vector2(350,260)
	actor.position = Vector2(280,243)
	actor.velocity = Vector2.ZERO
	actor.collision_layer = 2
	actor.set_physics_process(true)
	actor.sm.to(&"Idle")
	Input.action_press("move_right")
	var bounced := false
	var max_x := actor.position.x as float
	for frame in 45:
		await physics_frame
		max_x = maxf(max_x,actor.position.x)
		bounced = bounced or actor._contact_left > 0 and actor.velocity.x < 0
	Input.action_release("move_right")
	_expect(max_x < victim.position.x-20 and bounced,"持续向怪物移动会被身体挡住并反弹，不能穿过去")
	actor.position = Vector2(295,243)
	actor.velocity = Vector2.ZERO
	actor._contact_left = 0.0
	actor.sm.to(&"Idle")
	await _frames(4)
	Input.action_press("move_right")
	Input.action_press("jump")
	await _frames(65)
	Input.action_release("jump")
	Input.action_release("move_right")
	_expect(actor.position.x > victim.position.x+35,"保持身体碰撞时仍能从上方跳过敌怪")
	print("COMBAT REGRESSIONS: %d PASS, %d FAIL" % [passed,failed])
	quit(1 if failed else 0)


func _spawn(pos: Vector2) -> Node:
	var enemy: Node = load("res://scripts/enemies/combat_enemy.gd").new()
	enemy.position = pos
	enemy.enemy_id = &"moss_beetle"
	enemy.target = actor
	current_scene.add_child(enemy)
	return enemy


func _floor(parent: Node, rect: Rect2, oneway: bool) -> StaticBody2D:
	var floor := StaticBody2D.new()
	floor.collision_layer = 128 if oneway else 1
	floor.position = rect.position
	var shape := CollisionShape2D.new()
	var rectangle := RectangleShape2D.new()
	rectangle.size = rect.size
	shape.shape = rectangle
	shape.position = rect.size/2
	shape.one_way_collision = oneway
	floor.add_child(shape)
	parent.add_child(floor)
	return floor


func _frames(count: int) -> void:
	for frame in count:
		await physics_frame


func _aim_at(point: Vector2) -> void:
	actor.aim_point = point


func _expect(ok: bool, label: String) -> void:
	print("%s: %s" % ["PASS" if ok else "FAIL",label])
	if ok:
		passed += 1
	else:
		failed += 1
