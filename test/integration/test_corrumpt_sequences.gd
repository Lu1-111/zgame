extends SceneTree
## 真实玩家与Boss验收：入场反应、近身节奏、分阶段破韧、CG、逐帧虚空伤害及胜负延迟。
var passed := 0
var failed := 0
var boss: Node
var player: Node
var gs: Node
var ui: Node

func _initialize() -> void:
	call_deferred("_run")

func _run() -> void:
	create_timer(60,true,false,true).timeout.connect(func() -> void:quit(2))
	change_scene_to_file("res://test/scenes/previews/corrumpt_arena.tscn")
	await _frames(8)
	boss = current_scene.boss
	player = current_scene.player
	gs = root.get_node("GameState")
	ui = root.get_node("GameUI")
	boss.set_physics_process(false)
	player.set_physics_process(false)
	_check(boss.poise.maximum == 300 and boss.brain.paralysis_seconds == 4,"一阶段300韧性，对应4秒破韧")
	_check(EnemyStats.paralysis_seconds({"poise":450}) == 5.5 and EnemyStats.paralysis_seconds({"poise":450,"paralysis_seconds":2.3}) == 2.3,"统一公式支持450韧性5.5秒及显式特例")
	# 进入近战范围立即随机选砸击/地刺，近距离内也保留地刺候选。
	for fraction in [0.1,0.25,0.5]:
		player.position = boss.position+Vector2(float(boss.profile.combat.melee_range)*fraction,-17)
		var brain := CorrumptBrain.new()
		brain.configure(boss.profile.combat,42)
		var context: Dictionary = boss.context()
		var events := brain.tick(0.001,context)
		_check(context.near and brain.eligible_weights(context).has("spikes") and events.size() == 1 and events[0] in [&"slam",&"spikes"],"射程%.0f%%内地刺可用，入场立即出招" % [fraction*100])
		boss.request_attack(&"spikes")
		boss._tick_spikes(0,boss.profile.combat.moves.spikes)
		_check(boss._spikes_spawned == 1,"射程%.0f%%内正常生成首道地刺" % [fraction*100])
		boss.clear_combat_entities()
	# 累计而非连续4秒，施法期间仍可独立震退；没有冷却。
	var rules: Dictionary = boss.profile.combat.duplicate(true)
	rules.attack_chance = 0
	var brain := CorrumptBrain.new()
	brain.configure(rules,42)
	brain.state = &"casting"
	var close := {"alive":true,"near":false,"close":true}
	var far := {"alive":true,"near":false,"close":false}
	_check(not brain.tick(2,close).has(&"repel"),"累计近距离2秒不提前震退")
	brain.tick(8,far)
	_check(brain.tick(2,close).has(&"repel") and brain.close_accumulated == 0,"分两次累计4秒立即震退并清零")
	_check(brain.tick(4,close).has(&"repel"),"再次累计4秒即可震退，无额外冷却")
	player.position = boss.position+Vector2(50,-17)
	player._invuln = 0
	player.dodge_iframe = false
	player.sm.to(&"Idle")
	boss._repel()
	for index in 23:player._physics_process(1.0/60)
	_check(absf(player.position.x-boss.position.x) > float(boss.profile.combat.melee_range),"真实玩家被震退到砸击与地刺范围之外")
	boss.clear_combat_entities()
	# 一阶段归零进入完整CG，不立即跳阶段或结算击败。
	player.position = Vector2(320,530)
	player._boss_force_left = 0
	player.sm.to(&"Idle")
	gs.hp = 80
	var notifications := [0,0]
	root.get_node("EventBus").enemy_died.connect(func(id,_point):
		if id == &"corrumpt":notifications[0]+=1)
	root.get_node("EventBus").boss_defeated.connect(func(id):
		if id == &"corrumpt":notifications[1]+=1)
	boss.hp = 1
	boss.receive_hit(DamagePacket.new(10))
	_check(boss.sequence.active and boss.sequence.mode == &"transition" and boss.phase_index == 1,"一阶段归零先进入转阶段CG")
	_check(not boss.sequence._opening.centered and boss.sequence._opening.offset == boss.visual.offset and boss.sequence._opening.sprite_frames.get_frame_texture(&"opening",0).get_size() == boss.visual.sprite_frames.get_frame_texture(boss.visual.animation,boss.visual.frame).get_size(),"过场首帧沿用原画布及根座，不因Sprite居中设置发生64像素跳变")
	_check(player.cinematic_locked and ui.cinematic_active and boss.sequence._top.size.y > 0 and player.cam.focus_target == boss.sequence._focus,"CG禁止操作、增加黑边、摄像机追踪Boss")
	var before: Vector2 = player.position
	Input.action_press(&"move_right")
	Input.action_press(&"attack")
	player._physics_process(0.1)
	_check(player.position == before and player.input_dir() == 0 and not player.hitbox.monitoring,"CG中移动和攻击均不生效")
	Input.action_release(&"move_right")
	Input.action_release(&"attack")
	_until(boss.sequence,&"hover")
	_check(is_equal_approx(boss.sequence._initial.y-boss.position.y,128),"绽开和枯萎后花体上升128像素")
	boss.sequence.tick(1.99)
	_check(boss.sequence.stage == &"hover" and boss.phase_index == 1,"升空后停顿完整2秒")
	boss.sequence.tick(0.02)
	_until(boss.sequence,&"opaque")
	_check(boss.sequence._flash.modulate.a == 1 and boss.phase_index == 1,"先形成完全遮屏紫光，再允许切换")
	boss.sequence.tick(0.001)
	_check(boss.phase_index == 2 and boss.hp == 1000 and boss.poise.maximum == 450 and boss.sequence._flash.modulate.a == 1,"仅在全不透明紫光内换为二阶段450韧性")
	_finish(boss.sequence)
	_check(not player.cinematic_locked and not ui.cinematic_active and player.cam.focus_target == null and not boss.sequence._layer.visible,"CG结束恢复操作、摄像机及正常画面")
	_check(boss.brain.paralysis_seconds == 5.5 and notifications == [0,0],"二阶段破韧5.5秒，转阶段不发击败事件")
	var motion: CorrumptPhaseTwo = boss.phase_two
	motion.mode = &"close"
	motion.skill = &""
	motion.mode_casts = 0
	motion._finish()
	motion.tick(0.001)
	_check(motion.skill == &"" and motion.stage == &"land","近身收招后先落地，不在空中等待")
	_check(motion.config.moves.needles.round_interval == 0.7 and motion.config.moves.spores.lifetime == 15 and motion.config.moves.spores.terrain_areas,"巡空针弹0.7秒，孢子15秒且检测场景交互物碰撞")
	# 场景Area也可以反弹，原有墙/平台反弹由另一套实测覆盖。
	var prop := Area2D.new()
	prop.position = Vector2(600,100)
	prop.collision_layer = 64
	var collision := CollisionShape2D.new()
	var rectangle := RectangleShape2D.new()
	rectangle.size = Vector2(10,100)
	collision.shape = rectangle
	prop.add_child(collision)
	current_scene.add_child(prop)
	await _frames(2)
	var cfg: Dictionary = boss.profile.combat.moves.spores.duplicate(true)
	cfg.merge(motion.config.moves.spores,true)
	var spore: CorrumptEntity = boss._entity(&"spore",cfg,Vector2(520,100),float(cfg.lifetime))
	spore.radius = float(cfg.radius)
	spore.direction = Vector2.RIGHT
	current_scene.add_child(spore)
	spore.set_physics_process(false)
	spore._physics_process(1)
	_check(spore.bounce_count == 1 and spore.direction.x < 0,"巡空孢子接触交互物Area也会反弹")
	spore.age = 14.98
	spore._physics_process(0.01)
	_check(not spore.is_queued_for_deletion(),"巡空孢子在15秒前仍存在")
	spore._physics_process(0.011)
	_check(spore.is_queued_for_deletion(),"巡空孢子达到15秒后销毁")
	# 最后一击不立即胜利；黑洞伤害逐物理帧累计，且不阻断玩家操作。
	gs.hp = 80
	player.position = Vector2(1400,320)
	player.sm.to(&"Idle")
	player.dodge_iframe = false
	boss.hp = 1
	boss.receive_hit(DamagePacket.new(10))
	_check(boss.hp == 0 and boss.sequence.mode == &"defeat" and notifications == [0,0] and not player.cinematic_locked,"二阶段归零启动虚空湮灭，玩家可操作且尚未胜利")
	_until(boss.sequence,&"grow")
	_check(boss.position == boss.arena_bounds.get_center(),"最终招式先移动至场地中央")
	boss.sequence.tick(0.01)
	_check(boss.sequence.gravity_pulses == 1,"扩张时持续施放引力表现")
	player.position = boss.position
	player._invuln = 100
	player.dodge_iframe = true
	await _frames(2)
	var hp: int = gs.hp
	for index in 10:boss.sequence.tick(1.0/60)
	_check(gs.hp == hp-10 and player.sm.current_name() != &"Hurt","黑洞接触每物理帧扣1生命，不走普通无敌间隔或强制硬直")
	player.position = Vector2(1450,320)
	await _frames(2)
	_until(boss.sequence,&"flash_in")
	_check(is_equal_approx(boss.sequence.radius,60),"黑洞从半径6扩大到60，恰好10倍")
	var pulses: int = boss.sequence.gravity_pulses
	boss.sequence.tick(0.1)
	_check(boss.sequence.gravity_pulses == pulses and boss.sequence._pull_left == 0 and notifications == [0,0],"达到最大后停止引力及吸引，尚未结算胜利")
	_until(boss.sequence,&"opaque")
	boss.sequence.tick(0.01)
	_check(not boss.visual.visible and not boss.sequence._core.visible and boss.sequence._flash.modulate.a == 1,"在完全不透光的紫光内移除Boss及黑洞")
	_finish(boss.sequence)
	_check(boss.brain.state == &"dead" and notifications == [1,1],"紫光散去且玩家存活，才发出一次击败事件")
	# 玩家死于最终招式不判胜，重生后可重试。
	var retry: Node = (load("res://scenes/enemies/corrumpt.tscn") as PackedScene).instantiate()
	retry.position = Vector2(840,560)
	retry.target = player
	retry.arena_bounds = boss.arena_bounds
	current_scene.add_child(retry)
	retry.set_physics_process(false)
	retry.begin_phase_two()
	retry.phase_two.entry_left = 0
	current_scene.boss = retry
	gs.hp = 1
	player.sm.to(&"Idle")
	retry.hp = 1
	retry.receive_hit(DamagePacket.new(10))
	_until(retry.sequence,&"grow")
	player.position = retry.position
	await _frames(2)
	retry.sequence.tick(0.02)
	_check(gs.hp == 0 and retry.sequence._failed,"虚空接触可杀死玩家，并锁存本次失败")
	for index in 1000:
		if retry.sequence.mode == &"failed":break
		retry.sequence.tick(1.0/60)
	_check(notifications == [1,1] and retry.brain.state == &"failed","玩家死亡后不提前奖励，不判定为Boss胜利")
	gs.hp = 80
	player.sm.to(&"Idle")
	retry.sequence.tick(0)
	_check(current_scene.boss != retry and current_scene.boss.hp == 600,"玩家重生后首领恢复，允许重新挑战")
	print("CORRUMPT SEQUENCES: %d PASS, %d FAIL" % [passed,failed])
	quit(1 if failed else 0)

func _until(sequence: CorrumptSequence, stage: StringName) -> void:
	for index in 1000:
		if sequence.stage == stage:return
		sequence.tick(1.0/60)
	_check(false,"无法到达阶段："+str(stage))

func _finish(sequence: CorrumptSequence) -> void:
	for index in 1000:
		if not sequence.active:return
		sequence.tick(1.0/60)
	_check(false,"演出未能结束")

func _frames(count: int) -> void:
	for index in count:await physics_frame

func _check(value: bool, message: String) -> void:
	if value:passed += 1
	else:failed += 1
	print("%s: %s" % ["PASS" if value else "FAIL",message])
