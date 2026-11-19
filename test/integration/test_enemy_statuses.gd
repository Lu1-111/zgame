extends Node2D
## 检查武器施加异常、分级跳伤、毒性封疗与怪物本地动作时钟。

var checks := 0
var failures := 0

func _ready() -> void:
	call_deferred("_run")

func _run() -> void:
	GameUI.hide()
	GameState.reset()
	var player := (load("res://scenes/player/player.tscn") as PackedScene).instantiate() as Player
	add_child(player)
	player.set_physics_process(false)
	player.cam.enabled = false
	player.position = Vector2(300, 270)
	var small := _enemy(&"moss_beetle", Vector2(120, 240), 100)
	var elite := _enemy(&"moss_guard", Vector2(225, 240), 100)
	var boss := (load("res://scenes/enemies/corrumpt.tscn") as PackedScene).instantiate() as CorrumptBoss
	boss.position = Vector2(505, 245)
	add_child(boss)
	boss.set_physics_process(false)
	boss.statuses.set_physics_process(false)
	boss.health_layer.hide()

	GameState.weapon_id = &"sword_02"
	GameState.equipped_accessories.assign([&"accessory_06"])
	player.begin_weapon_attack()
	small.hurtbox.receive_hit(player.build_attack_packet(1))
	player.finish_weapon_attack()
	_expect(small.statuses.poise_multiplier() == 1.1, "残刃有效命中施加流血并提高受削韧")
	var hp := small.hp
	small.statuses._physics_process(0.99)
	_expect(small.hp == hp, "跳伤不早于1秒")
	small.statuses._physics_process(0.01)
	_expect(small.hp == hp - 3, "普通怪流血2%乘弑血护符1.5")
	var poise := small.poise.current
	var hit := DamagePacket.new(1)
	hit.ignore_defense = true
	hit.normal_poise = 10
	small.hurtbox.receive_hit(hit)
	_expect(is_equal_approx(small.poise.current, poise - 11), "流血10%削韧加成进入韧性池")
	small.statuses._physics_process(1.0)
	_expect(small.statuses.poise_multiplier() == 1.0, "残刃两秒后流血过期")

	GameState.weapon_id = &"sword_04"
	player.begin_weapon_attack()
	elite.hurtbox.receive_hit(player.build_attack_packet(1))
	player.finish_weapon_attack()
	hp = elite.hp
	elite.hp += 10
	_expect(elite.hp == hp and elite.statuses.healing_blocked(), "落英中毒阻止任意正向生命写入")
	for tick in 5:
		elite.statuses._physics_process(1.0)
	_expect(elite.hp == hp - 6, "精英中毒5秒共损失最大生命的6%")
	elite.hp += 1
	_expect(elite.hp == hp - 5 and not elite.statuses.healing_blocked(), "中毒结束后恢复可用")

	boss.apply_status("bleeding", 2.0)
	hp = boss.hp
	boss.statuses._physics_process(1.0)
	boss.statuses._physics_process(1.0)
	_expect(boss.hp == hp - 7, "首领600生命两跳累计7.2，按整数资源取7")
	boss.apply_status("poison", 3.0)
	hp = boss.hp
	boss.hp += 30
	_expect(boss.hp == hp, "首领毒性封疗")
	boss.begin_phase_two(false)
	_expect(boss.hp == 1000 and not boss.statuses.healing_blocked(), "新阶段独立生命池与异常清除")

	small._set_state(&"idle")
	small.apply_status("chill", 3.0)
	small.statuses.set_physics_process(false)
	var elapsed := small.elapsed
	small._physics_process(0.05)
	_expect(is_equal_approx(small.elapsed - elapsed, 0.04) and is_equal_approx(small.visual.body.speed_scale, 0.8), "冰缓让小怪动作时钟和动画均降20%")
	boss.phase_two.entry_left = 0.0
	boss.apply_status("chill", 3.0)
	boss.statuses.set_physics_process(false)
	boss.brain.state = &"paralyzed"
	boss.brain.elapsed = 0
	boss._physics_process(0.5)
	_expect(is_equal_approx(boss.brain.elapsed, 0.4), "冰缓降低首领动作计时")
	small.statuses._physics_process(3.0)
	_expect(small.statuses.action_speed() == 1.0, "冰缓持续时间按原战斗时间流逝")

	if DisplayServer.get_name() != "headless":
		await _capture(small, elite, boss, player)
	print("ENEMY STATUSES: %d checks / %d failures" % [checks, failures])
	get_tree().quit(1 if failures else 0)

func _enemy(id: StringName, point: Vector2, max_hp: int) -> CombatEnemy:
	var enemy := CombatEnemy.new()
	enemy.enemy_id = id
	enemy.position = point
	add_child(enemy)
	enemy.set_physics_process(false)
	enemy.definition.hp = max_hp
	enemy.hp = max_hp
	enemy.poise.configure(100)
	return enemy

func _capture(small: CombatEnemy, elite: CombatEnemy, boss: CorrumptBoss, player: Player) -> void:
	RenderingServer.set_default_clear_color(Color("#1b2434"))
	player.hide()
	small.apply_status("bleeding", 2.0)
	elite.apply_status("poison", 2.0)
	boss.statuses.apply("chill", 2.0)
	for enemy in [small, elite, boss]:
		enemy.statuses.set_physics_process(false)
		enemy.statuses._physics_process(0.1)
	var arc := ElectromagneticArc.new()
	arc.position = Vector2(330, 150)
	arc.radius = float(WeaponAttributes.config().rifle.shockwave_radius)
	add_child(arc)
	arc.set_process(false)
	arc._process(0.12)
	_preview_projectile("arrow", Vector2(175, 149))
	_preview_projectile("electromagnetic", Vector2(255, 149))
	await RenderingServer.frame_post_draw
	get_viewport().get_texture().get_image().save_png(ProjectSettings.globalize_path("res://docs/previews/arsenal_v001/status_and_projectiles.png"))

func _preview_projectile(kind: String, point: Vector2) -> void:
	var projectile := ProjectileBubble.new()
	projectile.visual_kind = "bullet"
	projectile.projectile_kind = kind
	projectile.position = point
	add_child(projectile)
	projectile.set_physics_process(false)

func _expect(ok: bool, label: String) -> void:
	checks += 1
	if not ok:
		failures += 1
		printerr("FAIL: " + label)
