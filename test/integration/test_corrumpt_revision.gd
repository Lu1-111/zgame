extends SceneTree
## 多轮弹幕、调位、预警、闪避及实际生命损失提示的真实场景验收。
var passed := 0
var failed := 0
var boss: Node
var motion: CorrumptPhaseTwo
var target: Target

class Target extends CharacterBody2D:
	func movement_speed() -> float:
		return 160.0

func _initialize() -> void:
	call_deferred("_run")

func _run() -> void:
	create_timer(50,true,false,true).timeout.connect(func() -> void:quit(2))
	change_scene_to_file("res://test/scenes/previews/corrumpt_arena.tscn")
	await _frames(8)
	boss = current_scene.boss
	boss.set_physics_process(false)
	var player: Node = current_scene.player
	player.set_physics_process(false)
	player.position = Vector2(100,180)
	target = Target.new()
	target.position = Vector2(900,350)
	current_scene.add_child(target)
	boss.target = target
	boss.begin_phase_two()
	motion = boss.phase_two
	motion.entry_left = 0
	await _barrage(&"spores",10,3,2.0,5)
	await _barrage(&"needles",10,4,0.7,2)
	_check(boss.profile.combat.moves.spores.count == 7 and boss.profile.combat.moves.spores.damage_multiplier == 1.0 and boss.profile.combat.moves.needles.damage_multiplier == 0.5,"二阶段强化不改写一阶段孢子/针弹参数")
	_reset()
	boss.position = Vector2(600,250)
	var before: Vector2 = boss.position
	motion._idle_move(0.1)
	_check(is_equal_approx(boss.position.distance_to(before),16.0),"巡空常态速度160，与玩家常态速度一致，可追上")
	motion.start_skill(&"spores")
	before = boss.position
	motion.tick(0.1)
	_check(is_equal_approx(boss.position.distance_to(before),32.0),"每招起手前调位320，为玩家速度2倍")
	_reset(&"close")
	before = boss.position
	target.position += Vector2(120,0)
	motion.tick(1)
	_check(boss.position == before,"近身待机不再时刻追踪调整位置")
	_check(is_equal_approx(motion._skill_speed(900),675.0) and is_equal_approx(motion._skill_speed(1150),862.5) and is_equal_approx(motion._skill_speed(750),562.5),"近身旋刃、冲击及收招所有技能移速统一乘75%")
	# 两种冲撞都仅在冲撞前最后0.2秒显示六帧预警。
	motion.skill = &"blade"
	motion._set_stage(&"hover")
	motion.elapsed = 1.27
	motion.tick(0.01)
	_check(not motion.warning.visible,"旋刃提前超过0.2秒时不显示红光")
	motion.tick(0.04)
	var first := motion.warning.frame
	_check(motion.warning.visible and first <= 1,"旋刃最后0.2秒开始产生红光")
	motion.tick(0.10)
	_check(motion.warning.visible and motion.warning.frame > first,"预警按产生、停留、消失推进逐帧")
	motion.tick(0.09)
	_check(motion.stage == &"dash" and not motion.warning.visible,"冲撞开始即清除预警")
	motion.skill = &"impact"
	motion._set_stage(&"hold")
	motion.tick(0.02)
	_check(motion.warning.visible and boss.collision_layer == 0,"冲击0.2秒蓄势有预警，并可穿玩家")
	motion.tick(0.19)
	_check(motion.stage == &"dash" and not motion.warning.visible,"冲击起冲即结束红光")
	for state in [&"align",&"charge",&"hold",&"dash",&"recover_side"]:
		motion._set_stage(state)
		_check(boss.collision_layer == 0,"冲击%s阶段可直接穿过玩家" % state)
	# 强制换到另一边，检查收招路径避开玩家，且持续无实体阻挡。
	target.position = Vector2(900,350)
	boss.position = target.position+Vector2(350,0)
	motion.recovery_side = -1
	motion._plan_route(motion._side_point(180,-1))
	motion._set_stage(&"recover_side")
	var clearance := INF
	for index in 300:
		if motion.skill == &"":break
		before = boss.position
		motion.tick(1.0/60)
		var closest := Geometry2D.get_closest_point_to_segment(target.position,before,boss.position)
		clearance = minf(clearance,closest.distance_to(target.position))
	_check(motion.skill == &"" and boss.position == target.position+Vector2(-180,0) and clearance >= 70,"冲击换边收招绕过玩家并停在安全一侧")
	_reset()
	motion._finish()
	_check(motion.wait_left == 3.0,"巡空技能完成后间隔缩短至3秒")
	_reset(&"close")
	motion._finish()
	_check(motion.stage == &"land" and motion.skill == &"","近身收招后进入落地恢复流程")
	# 使用真实玩家结算，不能把格挡、护盾吸收和过量伤害算入损失。
	boss.target = player
	_check(is_equal_approx(motion._player_speed(),player.movement_speed()),"Boss速度实时读取玩家常态移速，含天赋")
	var gs: Node = root.get_node("GameState")
	var ui: Node = root.get_node("GameUI")
	gs.hp_max = 80
	gs.hp = 80
	gs.sta = gs.sta_max
	player.position = Vector2(250,350)
	player._boss_force_left = 0
	player._contact_left = 0
	player._invuln = 0
	player.sm.to(&"Dodge",{"dir":1})
	before = player.position
	var invincible := true
	for index in 12:
		player._physics_process(1.0/60)
		invincible = invincible and player.dodge_iframe and player.apply_hit(DamagePacket.new(10)) == 0
	_check(invincible and gs.hp == 80,"闪避延长至12个60Hz帧，全部无敌")
	_check(absf(player.position.x-before.x-82.5) <= 1,"真实闪避位移82.5像素，为上一版1.5倍")
	player._physics_process(1.0/60)
	_check(player.sm.current_name() != &"Dodge" and not player.dodge_iframe,"延长闪避结束后按时解除无敌")
	var events: Array[int] = []
	root.get_node("EventBus").player_damaged.connect(func(loss: int) -> void:events.append(loss))
	player.cam._shake_left = 0
	player._invuln = 0
	player.sm.to(&"Idle")
	_check(player.apply_hit(DamagePacket.new(4)) == 4 and ui._damage_seconds == 0.05 and player.cam._shake_left == 0,"4/80恰好5%为轻受击，红边0.05秒、不震屏")
	ui._process(0.051)
	_check(ui._damage_overlay.modulate.a == 0,"轻受击红边0.05秒后完全消失")
	player._invuln = 0
	player.sm.to(&"Idle")
	_check(player.apply_hit(DamagePacket.new(5)) == 5 and ui._damage_seconds == 0.1 and player.cam._shake_left == 0.1,"5/80为重受击，红边0.1秒、微弱震屏")
	ui._process(0.101)
	_check(ui._damage_overlay.modulate.a == 0,"重受击红边0.1秒后完全消失")
	player._invuln = 0
	player.sm.to(&"Idle")
	player._shield_hp = 100
	player._shield_until = player._clock+5
	var count := events.size()
	_check(player.apply_hit(DamagePacket.new(20)) == 0 and events.size() == count and ui._damage_overlay.modulate.a == 0,"护盾全额吸收不发出受击提示")
	player._shield_hp = 0
	gs.hp = 3
	_check(player.apply_hit(DamagePacket.new(20)) == 3 and events[-1] == 3 and ui._damage_seconds == 0.05,"过量20伤害只损失剩余3生命，按实际损失判为轻受击")
	print("CORRUMPT REVISION: %d PASS, %d FAIL" % [passed,failed])
	quit(1 if failed else 0)

func _barrage(name: StringName, count: int, rounds: int, interval: float, damage: int) -> void:
	_reset()
	boss.position = Vector2(600,200)
	motion.start_skill(name)
	for index in 500:
		if motion.stage != &"reposition":break
		motion.tick(1.0/60)
	_check(motion.stage == &"projectile_windup","%s先完成快速调位才起手" % name)
	var point: Vector2 = boss.position
	var cfg: Dictionary = boss.profile.combat.moves[String(name)]
	motion.tick(float(cfg.windup_seconds)-0.001)
	_check(_bullets().is_empty(),"%s起手未完成不提前发射" % name)
	motion.tick(0.001)
	for round_index in rounds:
		var bullets := _bullets()
		for bullet in bullets:bullet.set_physics_process(false)
		_check(bullets.size() == count*(round_index+1) and bullets.all(func(b):return b.damage == damage),"%s第%d轮，数量与逐发伤害正确" % [name,round_index+1])
		if round_index+1 < rounds:
			target.position += Vector2(20,0)
			motion.tick(interval-0.001)
			_check(_bullets().size() == count*(round_index+1) and boss.position == point,"%s完整轮间隔未到不再发射，玩家移动也不调位" % name)
			motion.tick(0.001)
	motion.tick(float(cfg.recovery_seconds))
	_check(motion.skill == &"" and boss.position == point,"%s全部轮次完成才收招且全程固定位置" % name)
	for bullet in _bullets():bullet.queue_free()
	await _frames(2)

func _bullets() -> Array[Node]:
	return get_nodes_in_group(&"corrumpt_entities").filter(func(node):return node.source == boss and not node.is_queued_for_deletion())

func _reset(value: StringName = &"roam") -> void:
	motion.skill = &""
	motion.stage = &"idle"
	motion.mode = value
	motion.mode_casts = 0
	motion.switch_left = -1
	motion.wait_left = 1000
	motion.warning.clear()
	motion.airflow.hide()

func _frames(count: int) -> void:
	for index in count:await physics_frame

func _check(value: bool, message: String) -> void:
	if value:passed += 1
	else:failed += 1
	print("%s: %s" % ["PASS" if value else "FAIL",message])
