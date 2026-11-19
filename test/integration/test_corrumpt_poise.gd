extends SceneTree
## 扇形直射、实体反弹、真实削韧与血条双向提示。
var passed := 0
var failed := 0
var boss: Node
var dummy: Target

class Target extends Node2D:
	var hits: Array[DamagePacket] = []
	func _ready() -> void:
		var area := HurtboxComponent.new()
		area.owner_actor = self
		area.collision_layer = 32
		area.collision_mask = 0
		var shape := CollisionShape2D.new()
		var rect := RectangleShape2D.new()
		rect.size = Vector2(20,34)
		shape.shape = rect
		area.add_child(shape)
		add_child(area)
	func apply_hit(packet: DamagePacket) -> int:
		hits.append(packet)
		return packet.amount

func _initialize() -> void:
	call_deferred("_run")

func _run() -> void:
	create_timer(45,true,false,true).timeout.connect(func() -> void:quit(2))
	change_scene_to_file("res://test/scenes/previews/corrumpt_arena.tscn")
	await _frames(8)
	boss = current_scene.boss
	boss.set_physics_process(false)
	current_scene.player.set_physics_process(false)
	current_scene.player.position = Vector2(100,180)
	dummy = Target.new()
	dummy.position = Vector2(1400,300)
	current_scene.add_child(dummy)
	boss.target = dummy
	boss.begin_phase_two()
	boss.phase_two.entry_left = 0
	await _frames(2)
	var bar: Control
	for layer in boss.get_children():
		for node in layer.get_children():
			if node.get_script() != null and node.get_script().get_global_name() == "CorrumptHealthBar":bar = node
	bar.set_process(false)
	bar._process(0)
	_check(boss.poise.maximum == 450 and boss.poise.current == 450,"二阶段Boss初始韧性450")
	var notices := [0,0]
	boss.poise_broken.connect(func() -> void:notices[0]+=1)
	boss.poise_restored.connect(func() -> void:notices[1]+=1)
	var packet := DamagePacket.new(1)
	packet.poise_key = &"normal:hammer_01:1"
	_check(PoiseRules.damage(packet) == 40,"已接入制作人表中锤第一击40削韧")
	for index in 11:boss.receive_hit(packet)
	_check(boss.poise.current == 10 and boss.brain.state == &"ready","十一次命中累计440削韧，尚不瘫痪")
	boss.receive_hit(packet)
	_check(boss.poise.current == 0 and boss.brain.state == &"paralyzed" and notices[0] == 1,"清空450韧性触发一次瘫痪与提示")
	_check(bar._poise_state == &"break" and bar._shake_left > 0 and bar._poise_texture() != null,"破韧时血条震动并播放破裂逐帧素材")
	bar._process(0.25)
	_check(bar._poise_state == &"broken" and bar._poise_texture() != null,"破裂过程结束后保持裂纹状态")
	boss._physics_process(5.49)
	var before_hp: int = boss.hp
	boss.receive_hit(DamagePacket.new(10))
	_check(boss.brain.state == &"paralyzed" and notices[0] == 1 and before_hp-boss.hp == 13,"5.5秒内保持瘫痪且伤害增加30%，不重启提示")
	boss._physics_process(0.011)
	_check(boss.poise.current == 450 and not boss.poise.broken and notices[1] == 1,"5.5秒结束回满450韧性，恢复提示只触发一次")
	_check(bar._poise_state == &"recover" and bar._shake_left > 0 and bar._poise_texture() != null,"恢复时血条再次震动并播放修复素材")
	_check(boss.phase_two.skill != &"" and boss.brain.state == &"casting","瘫痪恢复后按当前模式立即起手")
	bar._process(0.29)
	_check(bar._poise_state == &"normal" and bar._poise_texture() == null and bar.position == bar._base_position,"修复后恢复正常血条形态和原锚点")
	for animation in [&"break",&"broken",&"recover"]:
		for index in bar._poise_frames.get_frame_count(animation):
			_check(bar._poise_frames.get_frame_texture(animation,index).get_size() == Vector2(350,16),"%s帧%d使用统一透明画布" % [animation,index])
	boss.hp = 0
	bar._process(0)
	_check(bar._trail == 0,"破韧/修复素材不影响最后一击血条归零")
	boss.hp = 1000
	var motion: CorrumptPhaseTwo = boss.phase_two
	motion.skill = &""
	motion.mode = &"close"
	motion.mode_casts = 0
	motion._finish()
	motion.tick(0.001)
	_check(motion.skill == &"" and motion.stage in [&"land",&"ground_stagger"] and boss.brain.state == &"cooldown","收招后先落地，再进入可削韧的硬直窗口")
	_check(motion.warning.scale == Vector2.ONE*4 and DamageFeedback.config().danger_warning.seconds == 0.2,"危险预警尺寸4倍，持续时间仍0.2秒")
	# 真实墙体、上下双向单向平台和45度斜面，均用圆形扫掠反射。
	_wall(Vector2(700,200),Vector2(10,240))
	_wall(Vector2(480,210),Vector2(120,8),true)
	_wall(Vector2(1120,250),Vector2(200,8),false,PI/4)
	await _frames(2)
	var spore := _spore(Vector2(600,150),Vector2(1,0.3).normalized())
	var incoming := spore.direction
	spore._physics_process(1)
	_check(spore.bounce_count == 1 and not spore.is_queued_for_deletion(),"第一次触及实心墙反弹后继续飞行")
	_check(spore.direction.is_equal_approx(Vector2(-incoming.x,incoming.y)),"墙面反弹入射角等于出射角，切向分量不变")
	spore.position = Vector2(600,150)
	spore.direction = Vector2.RIGHT
	spore._physics_process(1)
	_check(spore.bounce_count == 2 and spore.is_queued_for_deletion(),"第二次触及实体后销毁")
	spore = _spore(Vector2(480,150),Vector2.DOWN)
	spore._physics_process(0.5)
	_check(spore.bounce_count == 1 and spore.direction.y < 0,"孢子从上方接触空心平台会反弹")
	spore = _spore(Vector2(480,270),Vector2.UP)
	spore._physics_process(0.5)
	_check(spore.bounce_count == 1 and spore.direction.y > 0,"孢子从下方接触空心平台也会反弹")
	spore = _spore(Vector2(1120,120),Vector2.DOWN)
	spore._physics_process(1)
	_check(spore.bounce_count == 1 and absf(spore.direction.x) > 0.99 and absf(spore.direction.y) < 0.01,"45度斜面将竖直孢子正确反射为水平，不按轴粗略翻转")
	spore = _spore(Vector2(1500,150),Vector2.LEFT)
	spore.age = 7.98
	spore._physics_process(0.01)
	_check(not spore.is_queued_for_deletion(),"8秒前孢子继续存在")
	spore._physics_process(0.011)
	_check(spore.is_queued_for_deletion(),"达到8秒后销毁，无需等到反弹")
	dummy.position = Vector2(750,150)
	await _frames(2)
	dummy.hits.clear()
	spore = _spore(Vector2(600,150),Vector2.RIGHT)
	spore._physics_process(1)
	_check(dummy.hits.is_empty() and spore.bounce_count == 1,"墙体先于玩家截住孢子，不穿墙误伤后方玩家")
	dummy.position = Vector2(1400,300)
	await _frames(2)
	spore = _spore(dummy.position,Vector2.RIGHT)
	spore._physics_process(0)
	_check(dummy.hits.size() == 1 and spore.is_queued_for_deletion(),"接触玩家造成一次伤害后立即消失")
	print("CORRUMPT POISE/BOUNCE: %d PASS, %d FAIL" % [passed,failed])
	quit(1 if failed else 0)

func _spore(point: Vector2, direction: Vector2) -> CorrumptEntity:
	var cfg: Dictionary = boss.profile.combat.moves.spores
	var entity: CorrumptEntity = boss._entity(&"spore",cfg,point,float(cfg.lifetime))
	entity.direction = direction
	entity.radius = float(cfg.radius)
	current_scene.add_child(entity)
	entity.set_physics_process(false)
	return entity

func _wall(point: Vector2, size: Vector2, oneway: bool = false, angle: float = 0) -> void:
	var body := StaticBody2D.new()
	body.position = point
	body.rotation = angle
	body.collision_layer = 128 if oneway else 1
	body.collision_mask = 0
	var collision := CollisionShape2D.new()
	var rectangle := RectangleShape2D.new()
	rectangle.size = size
	collision.shape = rectangle
	collision.one_way_collision = oneway
	body.add_child(collision)
	current_scene.add_child(body)

func _frames(count: int) -> void:
	for index in count:await physics_frame

func _check(value: bool, message: String) -> void:
	if value:passed += 1
	else:failed += 1
	print("%s: %s" % ["PASS" if value else "FAIL",message])
