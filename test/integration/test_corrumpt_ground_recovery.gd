extends SceneTree
## 真实地形验收：落地后完整四秒、双倍削韧、破韧衔接及地刺红光后延迟。
var passed := 0
var failed := 0
var boss: Node

func _initialize() -> void:
	call_deferred("_run")

func _run() -> void:
	create_timer(60,true,false,true).timeout.connect(func() -> void:quit(2))
	change_scene_to_file("res://test/scenes/previews/corrumpt_arena.tscn")
	await _frames(8)
	boss = current_scene.boss
	boss.set_physics_process(false)
	current_scene.player.set_physics_process(false)
	current_scene.player.position = Vector2(1400,543)
	boss.begin_phase_two()
	var motion: CorrumptPhaseTwo = boss.phase_two
	motion.entry_left = 0
	motion.mode = &"close"
	motion.mode_casts = 0
	boss.position = Vector2(840,200)
	motion._finish()
	_check(motion.stage == &"land" and boss.brain.state == &"cooldown","近身招式完整收招后开始降落，仍可正常削韧")
	var packet := DamagePacket.new(1)
	packet.poise_key = &"normal:hammer_01:1"
	boss.receive_hit(packet)
	_check(boss.poise.current == 410 and motion.poise_damage_multiplier() == 1,"降落途中沿用锤第一击40削韧，不提前翻倍")
	motion.tick(0.5)
	_check(motion.stage == &"land" and is_equal_approx(boss.position.y,320),"降落按表中速度推进，不瞬移且不提前计硬直时间")
	_land(motion)
	_check(motion.stage == &"ground_stagger" and is_equal_approx(_visible_bottom(),560),"花体可见底部贴合真实实心地面，才开始四秒硬直")
	_check(not boss.visual.is_playing() and motion.elapsed == 0,"落地硬直冻结原逐帧姿态，计时从零开始")
	var hp: int = boss.hp
	boss.receive_hit(packet)
	_check(boss.poise.current == 330 and hp-boss.hp == 1 and PoiseRules.damage(packet) == 40,"硬直内40削韧变80，生命伤害和原始伤害包不变")
	var point: Vector2 = boss.position
	motion.tick(3.999)
	_check(motion.stage == &"ground_stagger" and motion.skill == &"" and boss.position == point,"落地满四秒前保持原地硬直，不调位、不出招")
	motion.tick(0.002)
	_check(motion.skill == &"impact" and motion.stage == &"reposition" and motion.poise_damage_multiplier() == 1,"四秒后恢复，先调位再发动下一招，关闭双倍削韧")
	# 高处有空心平台时落在脚下平台，不穿平台掉到整张地图底部。
	motion.skill = &""
	motion.mode_casts = 1
	boss.position = Vector2(400,300)
	motion._finish()
	_land(motion)
	_check(is_equal_approx(_visible_bottom(),425),"降落检测脚下空心平台的真实表面，花瓣可见下缘不悬空")
	# 普通四秒恢复不是破韧瘫痪；期间清空韧性后使用独立5.5秒瘫痪。
	boss.poise.current = 60
	boss.receive_hit(packet)
	_check(boss.brain.state == &"paralyzed" and boss.poise.current == 0,"落地硬直内双倍削韧可以正常打出真正破韧")
	boss._physics_process(5.499)
	_check(boss.brain.state == &"paralyzed","破韧后使用本阶段5.5秒规则，不被普通四秒窗口提前结束")
	boss._physics_process(0.002)
	_check(boss.poise.current == 450 and boss.brain.state == &"casting" and motion.stage == &"reposition" and motion.skill == &"impact","破韧恢复后回满韧性并接下一招，不补等另一段四秒")
	# 近身最后一招直接切回巡空，不插入不存在的下一招。
	motion.skill = &""
	motion.mode_casts = 4
	motion._finish()
	_check(motion.mode == &"roam" and motion.stage == &"idle","近身第五招完成正常回巡空，四秒窗口仅位于两次近身招式之间")
	# 新的一阶段实体测试红光与第一道地刺的精确时间边界。
	var phase_one: Node = (load("res://scenes/enemies/corrumpt.tscn") as PackedScene).instantiate()
	phase_one.position = Vector2(840,560)
	phase_one.target = current_scene.player
	phase_one.arena_bounds = boss.arena_bounds
	current_scene.add_child(phase_one)
	phase_one.set_physics_process(false)
	phase_one.request_attack(&"spikes")
	_check(phase_one.spike_warning.visible and _spikes(phase_one) == 0,"决定使用地刺时立即显示原通用危险红光")
	var warning_seconds := float(DamageFeedback.config().danger_warning.seconds)
	phase_one.brain.elapsed = warning_seconds-0.001
	phase_one._tick_attack()
	_check(phase_one.spike_warning.visible and _spikes(phase_one) == 0,"红光消失前不进入地刺攻击")
	phase_one.brain.elapsed = warning_seconds
	phase_one._tick_attack()
	_check(not phase_one.spike_warning.visible and _spikes(phase_one) == 0,"红光结束后进入独立等待，不生成尖刺")
	phase_one.brain.elapsed = warning_seconds+1.499
	phase_one._tick_attack()
	_check(_spikes(phase_one) == 0,"红光消失后1.5秒未满仍无地刺")
	phase_one.brain.elapsed = warning_seconds+1.5
	phase_one._tick_attack()
	_check(_spikes(phase_one) == 1,"红光消失恰好1.5秒时生成第一道，入地动作不额外叠加延迟")
	phase_one.request_attack(&"spikes")
	phase_one.hp = 1
	phase_one.receive_hit(DamagePacket.new(10))
	_check(not phase_one.spike_warning.visible,"转阶段立即清除未完成的地刺预警")
	_check(boss.profile.sequence.defeat.radius_multiplier == 10,"虚空湮灭最大半径为原半径十倍")
	print("CORRUMPT GROUND RECOVERY: %d PASS, %d FAIL" % [passed,failed])
	quit(1 if failed else 0)

func _land(motion: CorrumptPhaseTwo) -> void:
	for index in 300:
		if motion.stage != &"land":return
		motion.tick(1.0/60)
	_check(false,"未在限定时间内落地")

func _spikes(actor: Node) -> int:
	return get_nodes_in_group(&"corrumpt_entities").filter(func(entity):return entity.source == actor and entity.kind == &"spike" and not entity.is_queued_for_deletion()).size()

func _visible_bottom() -> float:
	var texture: Texture2D = boss.visual.sprite_frames.get_frame_texture(boss.visual.animation,boss.visual.frame)
	return boss.visual.global_position.y+boss.visual.offset.y+texture.get_image().get_used_rect().end.y

func _frames(count: int) -> void:
	for index in count:await physics_frame

func _check(value: bool, message: String) -> void:
	if value:passed += 1
	else:failed += 1
	print("%s: %s" % ["PASS" if value else "FAIL",message])
