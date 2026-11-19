extends Node2D
## 检查实际长按、方向、射击间隔、弹药与装备结算。

var player: Player
var shots: Array[Dictionary] = []
var failures := 0
var checks := 0

class Target extends Node2D:
	var hp := 500
	var hits := 0
	var poise := {"broken": false}
	func hit(packet: DamagePacket) -> int:
		hits += 1
		hp -= packet.amount
		if PoiseRules.damage(packet) >= 50:
			poise.broken = true
		return packet.amount

func _ready() -> void:
	call_deferred("_run")

func _run() -> void:
	GameUI.hide()
	GameState.reset()
	RPGService.ensure_state()
	child_entered_tree.connect(_record)
	player = (load("res://scenes/player/player.tscn") as PackedScene).instantiate()
	player.set_script(load("res://test/scripts/weapon_demo_player.gd"))
	add_child(player)
	player.set_physics_process(false)
	_expect(GameState.owned_accessories.size() == 16 and GameState.equipped_accessories.size() == 2, "饰品批次和两个可用槽")
	_expect(GameState.owned_weapons.has(&"rifle_06"), "新枪发到原型装备库")
	var original := GameState.to_save_dict()
	var expected := {
		&"bow_01": [1.0, 10], &"rifle_02": [1.0 / 0.75, 20], &"rifle_03": [1.0 / 0.7, 40],
		&"rifle_04": [5.0, 60], &"rifle_05": [1.0 / 3.0, 4], &"rifle_06": [1.0, 30]
	}
	for id: StringName in expected:
		var config := DataDB.get_weapon(id)
		_expect(is_equal_approx(WeaponAttributes.duration(config), expected[id][0]), "基础1秒除以倍率 " + str(id))
		_expect(WeaponAttributes.ammo_cost(config) == int(expected[id][1]), "单次耗弹 " + str(id))

	_equip(&"rifle_05", 12)
	player._attack_held = true
	player.sm.to(&"Attack")
	for frame in 80:
		player._clock += 1.0 / 60
		player.sm.tick(1.0 / 60)
		if shots.size() == 1:
			player.set("demo_facing", -1)
	_expect(shots.size() == 3 and GameState.ammo_units == 0, "长按冲锋枪三发耗尽弹药并停止")
	if shots.size() == 3:
		_expect(is_equal_approx(shots[1].time - shots[0].time, 1.0 / 3), "冲锋枪实际发射间隔1/3秒")
		_expect(shots[0].direction.x > 0 and shots[1].direction.x < 0, "长按期间转向后朝新方向发射")
	_equip(&"sword_01", 0)
	player._attack_held = true
	player.sm.to(&"Attack")
	var passed: Array[int] = []
	for i in 105:
		player._clock += 1.0 / 60
		player.sm.tick(1.0 / 60)
		if passed.is_empty() or passed.back() != player.attack_combo:
			passed.append(player.attack_combo)
	_expect(passed == [1, 2, 3, 1], "剑长按循环保留原三段连击")
	player._attack_held = false
	for i in 40:
		player._clock += 1.0 / 60
		player.sm.tick(1.0 / 60)
	_expect(player.sm.current_name() != &"Attack", "松键后只完成当前段")

	_equip(&"rifle_03", 100)
	player.begin_weapon_attack()
	player.spawn_weapon_projectile()
	_expect(shots.size() == 3 and GameState.ammo_units == 60, "霰弹三发只扣一次4%储量")
	if shots.size() == 3:
		_expect(is_equal_approx(shots[0].direction.angle_to(shots[1].direction), deg_to_rad(20.0))
			and is_equal_approx(shots[0].direction.angle_to(shots[2].direction), deg_to_rad(-20.0)), "霰弹方向为中心、正负20度")
		_expect(shots[0].amount == 28 and shots[1].amount == 28 and shots[2].amount == 28, "每发使用20点武器攻击力与角色攻击公式")
	_clear_shots()
	_equip(&"rifle_04", 1000)
	var first := _target(Vector2(50, 0))
	var second := _target(Vector2(78, 0))
	await _sync_targets()
	player.begin_weapon_attack()
	player.spawn_weapon_projectile()
	if shots.size() == 1:
		var bullet := shots[0].node as ProjectileBubble
		_expect(bullet.speed == 1520 and bullet.pierce, "狙击弹速度翻倍和穿透")
		bullet.global_position = Vector2(36, 0)
		for i in 6:
			await get_tree().physics_frame
		_expect(first.hits == 1 and second.hits == 1, "狙击弹穿过两名目标且各命中一次")
	else:
		_expect(false, "狙击弹实际生成")
	first.queue_free()
	second.queue_free()
	_clear_shots()

	_equip(&"rifle_06", 1000)
	first = _target(Vector2(50, 0))
	second = _target(Vector2(55, 30))
	var distant := _target(Vector2(55, 90))
	await _sync_targets()
	player.begin_weapon_attack()
	player.spawn_weapon_projectile()
	if shots.size() == 1:
		var pulse := shots[0].node as ProjectileBubble
		_expect(pulse.speed == 2280 and pulse.projectile_kind == "electromagnetic", "电磁弹类型与三倍弹速")
		pulse.global_position = Vector2(36, 0)
		for i in 5:
			await get_tree().physics_frame
		_expect(first.hp == 456 and second.hp == 482 and distant.hits == 0,
			"电磁弹命中与40%%范围伤害（主目标生命%d，范围内生命%d，范围外命中%d次）" % [first.hp, second.hp, distant.hits])
	else:
		_expect(false, "电磁弹实际生成")
	first.queue_free()
	second.queue_free()
	distant.queue_free()
	_clear_shots()

	_equip(&"rifle_02", 1000)
	var broken := _target(Vector2(60, 0))
	broken.poise.broken = true
	await _sync_targets()
	player.begin_weapon_attack()
	player.spawn_weapon_projectile()
	if shots.size() == 1:
		var bolt := shots[0].node as ProjectileBubble
		_expect(bolt.projectile_kind == "arrow" and not bolt.find_children("*", "Sprite2D", false, false).is_empty(), "十字弩生成原生弩箭")
		bolt.global_position = Vector2(36, 0)
		for i in 5:
			await get_tree().physics_frame
		_expect(broken.hp == 428, "十字弩对已破韧目标造成150%伤害")
	else:
		_expect(false, "十字弩实际生成弩箭")
	broken.queue_free()

	GameState.load_from_dict(original)
	_expect(GameState.ammo_units == 1000 and GameState.owned_accessories.size() == 16, "弹药和饰品存档回读")
	_put(&"accessory_02", &"accessory_16")
	ProgressionService.refresh_limits()
	_expect(GameState.hp_max == 84 and is_equal_approx(AccessoryRules.healing_multiplier(), 1.25), "回春提升上限与恢复")
	_expect(AccessoryRules.stamina_cost(20) == 16 and is_equal_approx(RPGService.stats().sta_regen, PlayerTuning.STA_REGEN * 1.2), "活力减少体力消耗并加快恢复")
	_put(&"accessory_01", &"accessory_03")
	_expect(is_equal_approx(AccessoryRules.damage_multiplier("melee", false), 1.13)
		and is_equal_approx(AccessoryRules.damage_multiplier("ranged", false), 1.05), "铭牌和近战伤害分类")
	_put(&"accessory_04", &"accessory_05")
	_expect(is_equal_approx(AccessoryRules.damage_multiplier("ranged", false), 1.08) and RPGService.stats().damage_reduction == 8.0, "远程增伤和伤害减免")
	_put(&"accessory_07", &"accessory_09")
	first = _target(Vector2(70, 0))
	var hit := DamagePacket.new(10)
	hit.origin_actor = player
	hit.normal_poise = 50
	first.get_child(0).receive_hit(hit)
	_expect(is_equal_approx(player.take_hunt_bonus(), 1.2) and player.take_hunt_bonus() == 1.0, "新破韧触发追猎一次")
	first.queue_free()
	player.on_dodge_completed()
	_expect(is_equal_approx(player._dodge_bonus_until - player._clock, 1.0) and is_equal_approx(AccessoryRules.damage_multiplier("", true), 1.1), "豪情在闪避后持续1秒")
	_put(&"accessory_10", &"accessory_11")
	GameState.weapon_id = &"sword_06"
	GameState.hp = int(GameState.hp_max / 2.0)
	_expect(is_equal_approx(AccessoryRules.damage_multiplier("", false), 1.25), "半血战意15%和机械共鸣10%")
	_put(&"accessory_12", &"accessory_15")
	player.finish_weapon_attack()
	_expect(is_equal_approx(player.normal_attack_speed(), 1.65) and is_equal_approx(player.movement_speed(), PlayerTuning.MAX_SPEED * 1.05), "超频移速和普攻速度")
	_expect(AccessoryRules.mana_cost(20) == 14 and is_equal_approx(AccessoryRules.damage_multiplier("", false), 0.9), "元素消耗和超频减伤害")
	_put(&"accessory_08", &"accessory_13")
	_expect(is_equal_approx(AccessoryRules.effect("free_shot_probability"), 1.0 / 3.0)
		and is_equal_approx(AccessoryRules.damage_multiplier("", false), 1.25)
		and AccessoryRules.effect("damage_taken_pct") == 20, "弹丸腰带和虚空意志数据生效")
	_put(&"accessory_14", &"accessory_06")
	_expect(AccessoryRules.effect("full_guard") == 1 and AccessoryRules.effect("bleeding_damage_pct") == 50, "坚盾与流血效果登记")
	print("RIFLE ACCESSORIES: %d checks / %d failures" % [checks, failures])
	get_tree().quit(1 if failures else 0)

func _put(first: StringName, second: StringName) -> void:
	GameState.equipped_accessories.assign([first, second])

func _equip(id: StringName, ammo: int) -> void:
	player.cancel_weapon_action()
	GameState.weapon_id = id
	GameState.ammo_units = ammo
	player._rifle_ready_at = 0.0
	player.set("demo_facing", 1)
	_clear_shots()

func _clear_shots() -> void:
	for info in shots:
		if is_instance_valid(info.node):
			info.node.queue_free()
	shots.clear()

func _record(node: Node) -> void:
	if node is ProjectileBubble:
		shots.append({"node": node, "time": player._clock, "direction": node.dir, "amount": node.packet.amount})

func _sync_targets() -> void:
	# 确保上次已排队释放的靶和新靶都完成物理同步。
	for frame in 2:
		await get_tree().physics_frame

func _target(point: Vector2) -> Target:
	var target := Target.new()
	target.position = point
	var hurtbox := HurtboxComponent.new()
	hurtbox.owner_actor = target
	hurtbox.hit_callback = target.hit
	hurtbox.collision_layer = 32
	var collision := CollisionShape2D.new()
	var shape := CircleShape2D.new()
	shape.radius = 6
	collision.shape = shape
	hurtbox.add_child(collision)
	target.add_child(hurtbox)
	add_child(target)
	return target

func _expect(ok: bool, label: String) -> void:
	checks += 1
	if not ok:
		failures += 1
		printerr("FAIL: " + label)
