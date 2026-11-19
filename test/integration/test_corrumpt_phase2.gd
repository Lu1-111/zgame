extends SceneTree
## 二阶段真实场景验收：模式顺序、逐段冲撞、扫掠命中、边界与标准素材。
var passed := 0
var failed := 0
var boss: Node
var target: Target

class Target extends CharacterBody2D:
	var hits: Array[DamagePacket] = []
	func _ready() -> void:
		collision_layer = 2
		collision_mask = 0
		var area := HurtboxComponent.new()
		area.owner_actor = self
		area.collision_layer = 32
		area.collision_mask = 0
		var shape := CollisionShape2D.new()
		var rectangle := RectangleShape2D.new()
		rectangle.size = Vector2(20,34)
		shape.shape = rectangle
		area.add_child(shape)
		add_child(area)
	func apply_hit(packet: DamagePacket) -> int:
		hits.append(packet)
		return packet.amount

func _initialize() -> void:
	call_deferred("_run")

func _run() -> void:
	create_timer(50,true,false,true).timeout.connect(func() -> void: quit(2))
	change_scene_to_file("res://test/scenes/previews/corrumpt_arena.tscn")
	await _frames(8)
	boss = current_scene.boss
	boss.set_physics_process(false)
	var player: Node = current_scene.player
	player.set_physics_process(false)
	player.position = Vector2(90,180)
	target = Target.new()
	target.position = Vector2(900,350)
	current_scene.add_child(target)
	boss.target = target
	boss.hp = 1
	boss.receive_hit(DamagePacket.new(10))
	for index in 1000:
		if not boss.sequence.active:break
		boss.sequence.tick(1.0/60)
	_check(boss.phase_index == 2 and boss.hp == 1000 and boss.definition.hp == 1000,"一阶段死亡自动进入1000生命二阶段")
	var motion: CorrumptPhaseTwo = boss.phase_two
	motion.entry_left = 0
	_check(not boss.visual.left_arm.visible and not boss.visual.right_arm.visible,"二阶段仅花体，无根部触手")
	_check(boss.collision_mask == 0 and boss.hurtbox.owner_actor == boss,"二阶段可穿墙且仍可被攻击")
	for name in [&"phase_2_idle",&"phase_2_extend",&"phase_2_spin",&"phase_2_retract",&"phase_2_spin_stop"]:
		boss.visual.flower_pose(name,0.6)
		_check(boss.visual.scale == Vector2.ONE and boss.visual.offset == Vector2(-64,-64),"%s沿用1:1纹素与同一花心锚点" % name)
		var texture: Texture2D = boss.visual.sprite_frames.get_frame_texture(name,boss.visual.frame)
		_check(texture.get_size() == Vector2(128,128),"%s完整128×128逐帧画布" % name)
	boss.brain.rng.seed = 42
	motion.mode = &"close"
	motion.start_skill(&"blade")
	for index in 300:
		if motion.stage != &"reposition":break
		motion.tick(1.0/60)
	var cycles := motion.cycles_left
	_check(cycles >= 3 and cycles <= 5,"旋刃每次随机循环3至5次")
	motion.tick(0.5)
	motion.tick(0.25)
	for index in 100:
		if motion.stage == &"hover":break
		motion.tick(1.0/60)
	_check(motion.stage == &"hover" and boss.position.is_equal_approx(target.position+Vector2(-200,-160)),"第一次冲撞前先移至玩家左上方")
	motion.tick(1.49)
	_check(motion.stage == &"hover","旋转停顿1.5秒未满不冲撞")
	motion.tick(0.02)
	_check(motion.stage == &"dash" and boss.collision_layer == 0 and motion.airflow.visible,"旋刃冲撞穿过玩家，并显示破空气流")
	var direction := motion.dash_direction
	var before: Vector2 = boss.position
	target.position = before+direction*80
	await _frames(2)
	motion.tick(0.1)
	_check(absf((boss.position-before).cross(direction)) < 0.01 and boss.position.distance_to(before) > 50,"旋刃按停顿结束时的方向直线移动，近身速度降为75%")
	_check(target.hits.size() == 1 and target.hits[0].amount == 15 and target.hits[0].knockback == 700,"旋刃扫掠接触一次1.5攻击力，附带大幅击退")
	motion.tick(0.1)
	_check(target.hits.size() == 1,"同一冲撞持续接触不会重复扣血")
	var dash_count := 1
	for index in 3000:
		if motion.skill == &"":break
		var previous := motion.stage
		motion.tick(1.0/60)
		if motion.stage == &"dash" and previous != &"dash":dash_count += 1
	_check(motion.skill == &"" and dash_count == cycles,"完成随机指定的全部冲撞后才减速、收瓣、回闲置")
	_check(boss.visual.animation == &"phase_2_idle" and not motion.airflow.visible,"旋刃结束恢复常态并关闭气流")
	# 冲击的水平对齐、后撤、0.2秒蓄势与长冲刺。
	target.hits.clear()
	target.position = Vector2(900,350)
	boss.position = Vector2(600,180)
	motion.start_skill(&"impact")
	for index in 300:
		if motion.stage == &"hold":break
		motion.tick(1.0/60)
	_check(motion.stage == &"hold" and is_equal_approx(boss.position.y,target.position.y) and is_equal_approx(absf(boss.position.x-target.position.x),230),"冲击先以2倍玩家速度调位，再对齐并向远端后撤")
	motion.tick(0.199)
	_check(motion.stage == &"hold","冲击蓄势完整0.2秒")
	motion.tick(0.002)
	_check(motion.stage == &"dash" and motion.dash_direction == Vector2.RIGHT,"蓄势后水平朝玩家方向冲刺")
	await _frames(2)
	for index in 300:
		if motion.skill == &"":break
		motion.tick(1.0/60)
	_check(target.hits.size() == 1 and target.hits[0].amount == 20,"冲击接触造成一次2.0攻击力")
	_check(motion.skill == &"" and is_equal_approx(absf(boss.position.x-target.position.x),180),"冲击收尾随机快速移动到玩家一侧")
	# 边界会截停冲撞，墙体不会阻止移动。
	motion.skill = &"impact"
	motion.dash_direction = Vector2.RIGHT
	motion.dash_left = 480
	motion._set_stage(&"dash")
	boss.position = Vector2(1600,350)
	motion.tick(1)
	_check(boss.position.x <= boss.arena_bounds.end.x-64,"冲撞不能把花体带出地图边界")
	motion.skill = &""
	motion.airflow.hide()
	# 从巡空开始完整运行两种模式，验证3次远程→4秒→1/2/2/2/1→巡空。
	target.position = Vector2(900,350)
	motion.history.clear()
	motion.set_mode(&"roam")
	target.position = Vector2(900,80)
	for index in 180:motion._idle_move(1.0/60)
	_check(absf(boss.position.y-target.position.y) >= 100 and boss.position.distance_to(target.position) >= 260,"玩家靠近上边界时巡空选择下方高差位置，仍保持距离")
	target.position = Vector2(900,350)
	for index in 4000:
		if motion.mode_casts == 3 and motion.skill == &"":break
		motion.tick(1.0/60)
	_check(motion.history.size() == 3 and motion.history.all(func(name):return name in [&"needles",&"spores"]),"巡空只随机施放飞针/孢子，共三次")
	motion.tick(3.99)
	_check(motion.mode == &"roam","第三次远程完成后等待4秒再切模式")
	motion.tick(0.02)
	_check(motion.mode == &"close" and motion.skill == &"blade","进入近身模式立即发动旋刃")
	for index in 8000:
		if motion.mode == &"roam":break
		motion.tick(1.0/60)
	_check(motion.mode == &"roam" and motion.history.slice(3) == [&"blade",&"impact",&"impact",&"impact",&"blade"],"近身严格按1/2/2/2/1完成后立即切回巡空")
	# 正常受伤结算后才击退，闪避和无敌不会被绕过。
	var gs: Node = root.get_node("GameState")
	gs.hp = 80
	player._invuln = 0
	player.dodge_iframe = false
	var packet := DamagePacket.new(20,DamagePacket.DamageType.PHYSICAL,700,player.position-Vector2.RIGHT*60,&"corrumpt")
	_check(player.apply_boss_charge(packet,0.35,0.35) == 20 and player.velocity.x > 600,"真实玩家被冲击命中后产生大幅击退")
	var hp: int = gs.hp
	player._invuln = 0
	player.dodge_iframe = true
	_check(player.apply_boss_charge(packet,0.35,0.35) == 0 and gs.hp == hp,"闪避无敌可以规避冲撞伤害和击退")
	print("CORRUMPT PHASE2: %d PASS, %d FAIL" % [passed,failed])
	quit(1 if failed else 0)

func _frames(count: int) -> void:
	for index in count:await physics_frame

func _check(value: bool, message: String) -> void:
	if value:passed += 1
	else:failed += 1
	print("%s: %s" % ["PASS" if value else "FAIL",message])
