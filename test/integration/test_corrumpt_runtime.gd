extends SceneTree
## 真实物理验收：左右触手/地刺、针弹实体、孢子边界、破韧保护与首领零血。
var passed := 0
var failed := 0
var boss: Node
var dummy: TestTarget
var gs: Node

class TestTarget extends CharacterBody2D:
	var hits: Array[DamagePacket] = []
	var forces: Array = []
	func _ready() -> void:
		collision_layer = 2
		collision_mask = 0
		var rectangle := RectangleShape2D.new()
		rectangle.size = Vector2(20,34)
		var body := CollisionShape2D.new()
		body.shape = rectangle
		add_child(body)
		var hurt := HurtboxComponent.new()
		hurt.owner_actor = self
		hurt.collision_layer = 32
		hurt.collision_mask = 0
		var shape := CollisionShape2D.new()
		shape.shape = rectangle
		hurt.add_child(shape)
		add_child(hurt)
	func apply_hit(packet: DamagePacket) -> int:
		hits.append(packet)
		return packet.amount
	func apply_boss_force(center: Vector2, speed: float, seconds: float, stun: float, pull: bool, safe_radius: float = 0.0) -> bool:
		forces.append([center,speed,seconds,stun,pull,safe_radius])
		return true

func _initialize() -> void:
	call_deferred("_run")

func _run() -> void:
	create_timer(40,true,false,true).timeout.connect(func() -> void: quit(2))
	gs = root.get_node("GameState")
	change_scene_to_file("res://test/scenes/previews/corrumpt_arena.tscn")
	await _frames(10)
	boss = current_scene.boss
	boss.set_physics_process(false)
	var player: Node = current_scene.player
	player.set_physics_process(false)
	player.position = Vector2(100,543)
	dummy = TestTarget.new()
	current_scene.add_child(dummy)
	boss.target = dummy
	var cfg: Dictionary = boss.profile.combat
	_check(boss.hp == 600 and boss.definition.damage == 10 and boss.poise.maximum == 300,"首领600生命/10攻击/300韧性，物理体积已建立")
	_check(boss.hurtbox.owner_actor == boss and boss.collision_layer == 4,"首领受击框与实体层正确")
	for side in [-1,1]:
		await _airborne_tendril(side)
		await _clear()
		dummy.position = boss.position+Vector2(side*float(cfg.moves.slam.hit_offset[0]),-17)
		await _frames(2)
		boss.request_attack(&"slam")
		_check(boss.facing == side,"砸击按玩家侧起手 %d" % side)
		boss._physics_process(float(cfg.moves.slam.raise_seconds)+float(cfg.moves.slam.hold_seconds)-0.001)
		_check(boss.visual.pose_frame == 3 and _entities(&"impact").is_empty(),"砸击举起后停顿0.2秒，不提前造成伤害")
		var start := float(cfg.moves.slam.raise_seconds)+float(cfg.moves.slam.hold_seconds)
		for index in cfg.moves.slam.swing_frames.size():
			boss.brain.elapsed = start+float(index)/cfg.moves.slam.swing_frames.size()*float(cfg.moves.slam.swing_seconds)+0.001
			boss._tick_attack()
			_check(boss.visual.action == &"slam_downstroke" and boss.visual.pose_frame == index and _entities(&"impact").is_empty(),"挥落中间帧%d实际播放，挥落结束前无砸地伤害" % index)
		boss.brain.elapsed = start+float(cfg.moves.slam.swing_seconds)-0.001
		boss._tick_attack()
		_check(_entities(&"impact").is_empty(),"完整0.5秒挥落期间不会提前触地")
		boss._physics_process(0.002)
		await _frames(4)
		_check(dummy.hits.size() == 1 and dummy.hits[0].amount == 20,"延伸触手在%d方向远端命中20伤害" % side)
		await _clear()
		dummy.position = boss.position+Vector2(side*float(cfg.moves.spikes.first_distance),-17)
		# 测试直接移动假人后，先让物理空间同步，避免旧位置与新位置各被一根地刺采样。
		await _frames(2)
		boss.request_attack(&"spikes")
		boss._physics_process(boss.spike_release_seconds()-0.01)
		_check(_entities(&"spike").is_empty(),"地刺红光后延迟未满1.5秒不产生攻击")
		boss._physics_process(0.02)
		await _frames(4)
		var spikes := _entities(&"spike")
		_check(not spikes.is_empty() and spikes[0]._visual.scale == Vector2.ONE,"地刺原生像素与本体一致，无二次拉伸")
		var correct_side := not spikes.is_empty()
		for spike: CorrumptEntity in spikes:
			correct_side = correct_side and signf(spike.position.x-boss.position.x) == side
		_check(correct_side,"地刺只向玩家所在%d侧扩展" % side)
		_check(dummy.hits.size() == 1 and dummy.hits[0].amount == 25,"地刺实际接触造成25伤害")
		var first: CorrumptEntity = spikes[0]
		var release_time: float = boss.spike_release_seconds()
		boss.brain.elapsed = release_time+0.199
		boss._tick_attack()
		_check(_entities(&"spike").size() == 1,"下一道地刺在0.2秒之前不提前出现")
		boss.brain.elapsed = release_time+0.201
		boss._tick_attack()
		var wave := _entities(&"spike")
		_check(wave.size() == 2 and is_equal_approx(absf(wave[1].position.x-wave[0].position.x),32),"每0.2秒生成向外紧密相邻的独立地刺")
		var next_spike: CorrumptEntity = wave[0] if wave[0] != first else wave[1]
		first.age = 0.399
		first._physics_process(0.002)
		await _frames(1)
		_check(_entities(&"spike").size() == 1 and is_instance_valid(next_spike) and not next_spike.is_queued_for_deletion(),"每道地刺独立存在0.4秒，首道消失不销毁下一道")
		await _clear()
	# 跳跃可躲避地刺。
	dummy.position = boss.position+Vector2(-175,-100)
	boss.facing = -1
	boss._release(&"spikes",cfg.moves.spikes)
	await _frames(4)
	_check(dummy.hits.is_empty(),"空中目标不会被地面尖刺命中")
	await _clear()
	# 针弹一发一实体，中央针定向，其余每15度展开，发射后不追踪。
	dummy.position = boss.position+Vector2(-300,-17)
	boss._release(&"needles",cfg.moves.needles)
	var needles := _entities(&"needle")
	needles.sort_custom(func(a,b):return a.pattern_index < b.pattern_index)
	_check(needles.size() == 10,"一次释放10个独立针弹")
	_check(not needles.is_empty() and needles[0]._visual.scale == Vector2.ONE,"针弹按原生纹素显示")
	for needle: CorrumptEntity in needles:
		needle.set_physics_process(false)
		_check(needle._visual.sprite_frames.get_frame_texture(&"needle",0).get_size() == Vector2(40,16),"飞针原生尺寸翻倍为40×16")
	var aimed := (dummy.global_position-needles[5].global_position).normalized()
	_check(needles[5].direction.is_equal_approx(aimed),"第6枚中央定向针瞄准发射时的玩家")
	for index in range(1,needles.size()):
		_check(is_equal_approx(needles[index-1].direction.angle_to(needles[index].direction),deg_to_rad(15)),"相邻飞针间隔15度")
	var tracking: CorrumptEntity = needles[0]
	tracking.position = boss.position+Vector2(-100,-220)
	dummy.position = boss.position+Vector2(-250,-100)
	tracking.age = 1.49
	var aim := tracking.direction
	tracking._physics_process(0.005)
	_check(tracking.direction.is_equal_approx(aim) and is_equal_approx(tracking.rotation,aim.angle()),"发射后即使玩家移动也不再调整针体方向")
	var locked := tracking.direction
	tracking.age = 1.5
	dummy.position = boss.position+Vector2(200,-100)
	tracking._physics_process(0.01)
	_check(tracking.direction.is_equal_approx(locked),"全程沿最初方向直线飞行")
	tracking.age = 8
	tracking._physics_process(0.01)
	_check(not tracking.is_queued_for_deletion(),"飞针不再被旧五秒寿命提前销毁")
	tracking.position = boss.arena_bounds.end+Vector2.ONE*10
	tracking._physics_process(0.01)
	_check(tracking.is_queued_for_deletion(),"飞针接触地图边界后销毁")
	await _clear()
	dummy.position = boss.position+Vector2(-300,-17)
	await _frames(2)
	var single: Node2D = boss._entity(&"needle",cfg.moves.needles,dummy.position+Vector2(35,0),2)
	single.direction = Vector2.LEFT
	single.radius = float(cfg.moves.needles.radius)
	current_scene.add_child(single)
	await _frames(8)
	_check(dummy.hits.size() == 1 and dummy.hits[0].amount == 5 and _entities(&"needle").is_empty(),"单针接触角色造成5伤害并销毁")
	await _clear()
	var grazing: Node2D = boss._entity(&"needle",cfg.moves.needles,dummy.position+Vector2(50,-23),0)
	grazing.radius = float(cfg.moves.needles.radius)
	grazing.direction = Vector2.LEFT
	current_scene.add_child(grazing)
	await _frames(10)
	_check(dummy.hits.size() == 1 and dummy.hits[0].amount == 5,"放大的针体擦到受击框也会命中，不只检测中心线")
	await _clear()
	boss._release(&"spores",cfg.moves.spores)
	_check(boss.live_spores() == 7,"一次随机选择七个方向生成孢子弹幕")
	var spores := _entities(&"spore")
	for spore in spores:
		spore.set_physics_process(false)
	var contact: CorrumptEntity = spores[0]
	contact.position = dummy.position
	contact._physics_process(0)
	_check(dummy.hits.size() == 1 and dummy.hits[0].amount == 10 and contact.is_queued_for_deletion(),"孢子接触造成1.0攻击伤害并立即销毁")
	var through: CorrumptEntity = spores[1]
	through.position = Vector2(50,100)
	through.direction = Vector2.RIGHT
	through.age = 7.8
	through._physics_process(0.1)
	_check(through.position.x > 50 and not through.is_queued_for_deletion(),"孢子在8秒前仍持续移动")
	through._physics_process(0.11)
	_check(through.is_queued_for_deletion(),"孢子存在达到8秒后消失")
	await _clear()
	dummy.position = boss.position+Vector2(-95,-17)
	boss._repel()
	await _frames(25)
	_check(dummy.forces.size() == 1 and not bool(dummy.forces[0][4]) and dummy.hits.is_empty(),"震退环实际接触只推开一次，不造成生命伤害")
	await _clear()
	# 切换不同帧数的动画，含8帧末尾切到4帧施法，不能取到空贴图。
	for kind: StringName in [&"gravity_ring",&"repel_ring"]:
		var ring_cfg: Dictionary = cfg.moves.gravity if kind == &"gravity_ring" else cfg.moves.repel
		var ring: Node2D = boss._entity(kind,ring_cfg,boss.position,1)
		ring.ring_max = 400
		current_scene.add_child(ring)
		ring.set_physics_process(false)
		for age in [0.2,0.8]:
			ring.age = age
			ring._tick_ring()
			_check(ring._native_ring and ring.scale == Vector2.ONE and ring._visual.scale == Vector2.ONE,"%s半径变化时节点与纹理不放大" % kind)
			_check(float(ring._ring_material.get_shader_parameter("pixel_pitch")) == 1 and float(ring._ring_material.get_shader_parameter("strip_height")) == 12,"%s扩散全程保持原生纹素和固定环带宽度" % kind)
		ring.queue_free()
	await _frames(2)
	for action: StringName in [&"needles",&"gravity",&"spores",&"repel"]:
		boss.visual.pose(&"slam",7,1)
		boss.visual.pose(action,2,-1)
		_check(boss.visual.sprite_frames.get_frame_texture(boss.visual.animation,boss.visual.frame) != null,"8帧切换到%s四帧动画安全" % action)
	for action: String in ["slam","slam_downstroke","spikes","needles","gravity","spores","repel"]:
		for side in [-1,1]:
			boss.visual.set_frame_and_progress(2,0.45)
			var body_texture: Texture2D = boss.visual.sprite_frames.get_frame_texture(&"phase_1_idle",2)
			boss.visual.pose(StringName(action),0,side)
			_check(boss.visual.scale == Vector2.ONE and boss.visual.offset == Vector2(-64,-112) and not boss.visual.flip_h,"%s朝向%d切换时固定根座、1:1像素，本体不镜像" % [action,side])
			_check(boss.visual.animation == &"phase_1_idle" and boss.visual.frame == 2 and is_equal_approx(boss.visual.frame_progress,0.45) and boss.visual.sprite_frames.get_frame_texture(boss.visual.animation,boss.visual.frame) == body_texture,"%s朝向%d保持同一本体贴图与心跳进度" % [action,side])
			boss.visual.show_idle()
			_check(boss.visual.frame == 2 and is_equal_approx(boss.visual.frame_progress,0.45),"收招回闲置不重置心跳进度")
	# 伤害空窗中的韧性可削，招式中锁定，瘫痪不被重置。
	var table: Dictionary = PoiseRules.config().attacks
	var key: String = table.keys()[0]
	var old_value: Variant = table[key].poise_damage
	table[key].poise_damage = 300
	var hit := DamagePacket.new(1)
	hit.poise_key = StringName(key)
	boss.hp = 600
	boss.request_attack(&"slam")
	boss.receive_hit(hit)
	_check(boss.poise.current == 300 and boss.brain.state == &"casting","施法中受到伤害但不削韧不中断")
	boss.brain.state = &"ready"
	boss.receive_hit(hit)
	_check(boss.poise.current == 0 and boss.brain.state == &"paralyzed","准备期清空300韧性，进入瘫痪")
	var damage := int(boss.receive_hit(DamagePacket.new(10)))
	_check(damage == 13,"瘫痪期间受到伤害增加30%")
	boss._physics_process(3.99)
	_check(boss.brain.state == &"paralyzed","重复受击不缩短或延长四秒瘫痪")
	boss._physics_process(0.02)
	_check(boss.poise.current == 300 and boss.brain.state == &"casting","瘫痪四秒结束立即恢复韧性并发动攻击")
	table[key].poise_damage = old_value
	await _clear()
	# 对真实玩家验证无伤控制。
	var hp := int(gs.hp)
	player._invuln = 0
	player.dodge_iframe = false
	_check(player.apply_boss_force(boss.position,560,0.45,0.45,true,110) and player.sm.current_name() == &"Hurt" and gs.hp == hp,"引力对真实玩家产生无伤硬直")
	_check(player.velocity.x > 0,"引力朝boss方向拉近")
	player._invuln = 0
	_check(player.apply_boss_force(boss.position,340,0.25,0.25,false) and player.velocity.x < 0 and gs.hp == hp,"震退向远离boss方向推开，无伤害")
	boss.hp = 1
	boss.receive_hit(DamagePacket.new(10))
	for index in 1000:
		if not boss.sequence.active:break
		boss.sequence.tick(1.0/60)
	_check(boss.phase_index == 2 and boss.hp == 1000,"第一阶段耗尽后自动进入1000生命二阶段")
	boss.phase_two.entry_left = 0
	boss.hp = 1
	boss.receive_hit(DamagePacket.new(10))
	for index in 1000:
		if not boss.sequence.active:break
		boss.sequence.tick(1.0/60)
	_check(boss.hp == 0 and boss.brain.state == &"dead","第二阶段耗尽后真正击败首领")
	await _frames(3)
	_check(_entities(&"spore").is_empty(),"击败第一阶段会清理残留攻击实体")
	print("CORRUMPT RUNTIME: %d PASS, %d FAIL" % [passed,failed])
	quit(1 if failed else 0)

func _entities(kind: StringName) -> Array[CorrumptEntity]:
	var list: Array[CorrumptEntity] = []
	for entity in get_nodes_in_group(&"corrumpt_entities"):
		if entity is CorrumptEntity and entity.kind == kind and not entity.is_queued_for_deletion():
			list.append(entity)
	return list

func _clear() -> void:
	for entity in get_nodes_in_group(&"corrumpt_entities"):
		entity.queue_free()
	if is_instance_valid(boss):
		boss._repel_visual_left = 0
	dummy.hits.clear()
	dummy.forces.clear()
	await _frames(2)

func _airborne_tendril(side: int) -> void:
	dummy.position = boss.position+Vector2(side*300,-17)
	await _frames(2)
	boss.request_attack(&"slam")
	boss.brain.elapsed = float(boss.profile.combat.moves.slam.raise_seconds)+0.1
	boss._tick_attack()
	var hitbox: CorrumptTendrilHitbox = boss.left_tendril if side < 0 else boss.right_tendril
	var other: CorrumptTendrilHitbox = boss.right_tendril if side < 0 else boss.left_tendril
	_check(hitbox.armed and not other.armed and boss.visual.left_arm.visible and boss.visual.right_arm.visible,"左右触手同时保留，仅玩家所在%d侧触手具有砸击判定" % side)
	var point := Vector2.ZERO
	for shape in hitbox._shapes:
		var center := Vector2.ZERO
		for vertex in shape.points:
			center += vertex
		center /= shape.points.size()
		var world := hitbox.global_transform*center
		if absf(world.x-boss.position.x) > 80 and world.y < boss.position.y-60:
			point = world
			break
	_check(point != Vector2.ZERO,"高举触手具有贴合纹理的空中碰撞实体")
	dummy.position = point
	dummy.velocity = Vector2.UP*100
	await _frames(2)
	hitbox.sync_pose(true,boss._attack_serial)
	_check(dummy.hits.size() == 1 and dummy.hits[0].amount == 20 and _entities(&"impact").is_empty(),"向上跳跃碰到高举触手即受20伤害，无需落地")
	dummy.velocity = Vector2.DOWN*100
	hitbox.sync_pose(true,boss._attack_serial+1)
	_check(dummy.hits.size() == 2,"下落时碰到触手同样受到接触伤害")
	hitbox.sync_pose(true,boss._attack_serial+1)
	_check(dummy.hits.size() == 2,"同一次砸击持续接触不逐帧重复扣血")
	dummy.position = boss.position+Vector2(side*150,-45)
	await _frames(2)
	hitbox.sync_pose(true,boss._attack_serial+2)
	_check(dummy.hits.size() == 2,"触手弧线内部空白不会被大矩形误伤")

func _frames(count: int) -> void:
	for index in count:
		await physics_frame

func _check(condition: bool, message: String) -> void:
	if condition:
		passed += 1
	else:
		failed += 1
	print("%s: %s" % ["PASS" if condition else "FAIL",message])
