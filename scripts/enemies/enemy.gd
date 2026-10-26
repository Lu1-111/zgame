class_name GameEnemy
extends CharacterBody2D
## 数据驱动敌人实体；出生即追击玩家，判定与动画解耦，死亡奖励仅结算一次。
signal defeated(enemy: GameEnemy)
const CONFIG_PATH := "res://data/enemy_presentation.json"
@export var enemy_id: StringName = &"moss_beetle"
var target: Node2D
var tuning: Dictionary = {}
var definition: Dictionary = {}
var state: StringName = &"patrol"
var hp := 0
var facing := 1
var elapsed := 0.0
var origin := Vector2.ZERO
var visual: EnemyVisual
var hurtbox: HurtboxComponent
var _attack_area: Area2D
var _hit_in_attack := false
var _rewarded := false
var _flying := false
var _slow_left := 0.0
var _time := 0.0
var _body_offset := Vector2.ZERO
var _body_size := Vector2.ZERO

func _ready() -> void:
	tuning = JSON.parse_string(FileAccess.get_file_as_string(CONFIG_PATH))
	tuning.merge(tuning.get("per_enemy", {}).get(String(enemy_id), {}), true)
	tuning.detect_range = float(EncounterRules.config().perception.detect_range)
	tuning.lose_range = float(EncounterRules.config().perception.lose_range)
	definition = DataDB.get_enemy(enemy_id)
	if definition.is_empty():
		queue_free()
		return
	hp = int(definition.hp)
	add_to_group(&"enemies")
	origin = global_position
	_flying = str(definition.ai.type) in ["fly", "float"]
	collision_layer = 4
	collision_mask = 129 | 2 | 4
	floor_snap_length = float(EncounterRules.config().navigation.floor_snap)
	var size: Array = tuning.fly_body_size if _flying else tuning.body_size
	_body_size = Vector2(size[0], size[1])
	_body_offset = Vector2.ZERO if _flying else Vector2(0, -_body_size.y / 2.0)
	if tuning.has("body_offset"):
		_body_offset = _vector(tuning.body_offset)
	_add_shape(self, _body_size, _body_offset)
	hurtbox = HurtboxComponent.new()
	hurtbox.collision_layer = 32
	hurtbox.collision_mask = 0
	hurtbox.owner_actor = self
	hurtbox.hit_callback = receive_hit
	_add_shape(hurtbox, _body_size, _body_offset)
	add_child(hurtbox)
	_attack_area = Area2D.new()
	_attack_area.collision_layer = 16
	_attack_area.collision_mask = 32
	_add_shape(_attack_area, _vector(tuning.hitbox_size), Vector2.ZERO)
	add_child(_attack_area)
	visual = EnemyVisual.new()
	add_child(visual)
	visual.configure(
		enemy_id,
		tuning.catalog_paths,
		tuning.aliases,
		float(tuning.sprite_scale),
		tuning.get("sprite_resources", {})
	)
	visual.action_completed.connect(_on_animation_completed)
	_set_state(&"patrol")

func _add_shape(parent: Node, size: Vector2, offset: Vector2) -> void:
	var shape := CollisionShape2D.new()
	var rect := RectangleShape2D.new()
	rect.size = size
	shape.shape = rect
	shape.position = offset
	parent.add_child(shape)

func _vector(value: Array) -> Vector2:
	return Vector2(value[0], value[1])

func _physics_process(delta: float) -> void:
	if definition.is_empty():
		return
	elapsed += delta
	_time += delta
	_slow_left = maxf(0.0, _slow_left - delta)
	if not _flying:
		velocity.y += float(tuning.gravity) * delta
	if state == &"death":
		velocity.x = 0.0
		move_and_slide()
		if elapsed >= float(tuning.death_duration):
			queue_free()
		return
	if not is_instance_valid(target) or GameState.hp <= 0:
		_return_home()
	else:
		_update_state(delta)
	if not _flying and state not in [&"hurt",&"death"] and not EnemyAwareness.has_support_ahead(self,velocity.x,_body_size.x):
		facing = -1 if velocity.x > 0 else 1
		velocity.x = 0
	move_and_slide()
	queue_redraw()

func _update_state(delta: float) -> void:
	var distance := global_position.distance_to(target.global_position)
	var sees := EnemyAwareness.can_sense(self,target,_body_offset,_flying,state == &"chase")
	match state:
		&"idle":
			velocity.x = 0.0
			_set_state(&"chase" if sees else &"patrol")
		&"patrol", &"chase":
			if sees and state == &"patrol":
				_set_state(&"chase")
			if state == &"chase" and not sees:
				_set_state(&"patrol")
			if state == &"chase":
				facing = -1 if target.global_position.x < global_position.x else 1
			elif is_on_wall():
				facing *= -1
			elif absf(global_position.x-origin.x) >= float(tuning.patrol_distance):
				facing = -1 if global_position.x > origin.x else 1
			var speed := float(definition.ai.chase_speed if state == &"chase" else definition.ai.patrol_speed)
			if _slow_left > 0.0:
				speed *= float(tuning.slow_multiplier)
			velocity.x = facing * speed
			if _flying:
				var goal_y := target.global_position.y + _body_offset.y if state == &"chase" else origin.y
				velocity.y = clampf(goal_y - global_position.y, -float(tuning.flying_vertical_speed), float(tuning.flying_vertical_speed))
				if definition.ai.features.has("sine"):
					velocity.y += sin(_time * float(tuning.sine_frequency)) * float(tuning.sine_amplitude)
			visual.play_action(&"move", facing < 0)
			if state == &"chase" and distance <= float(tuning.get("attack_range", definition.ai.attack_range)):
				_set_state(&"telegraph")
		&"telegraph":
			velocity = Vector2.ZERO
			if elapsed >= _telegraph_duration():
				_set_state(&"attack")
		&"attack":
			velocity.x = 0.0
			if _flying:
				velocity.y = 0.0
			if elapsed >= float(tuning.attack_hit_start) and elapsed <= float(tuning.attack_hit_end):
				_attack()
			if elapsed >= float(tuning.attack_duration):
				_set_state(&"recover")
		&"recover":
			velocity.x = 0.0
			if elapsed >= float(tuning.recover_duration):
				_set_state(&"chase")
		&"hurt":
			velocity.x = move_toward(velocity.x, 0.0, float(tuning.knockback_decay) * delta)
			if elapsed >= float(tuning.hurt_duration):
				_set_state(&"chase")

func _return_home() -> void:
	if global_position.distance_to(origin) <= _body_size.x:
		velocity.x = 0.0
		if _flying:
			velocity.y = 0.0
		if state != &"idle":
			_set_state(&"idle")
		return
	facing = -1 if origin.x < global_position.x else 1
	velocity.x = facing * float(definition.ai.patrol_speed)
	if _flying:
		velocity.y = clampf(origin.y - global_position.y, -float(tuning.flying_vertical_speed), float(tuning.flying_vertical_speed))
	visual.play_action(&"move", facing < 0)

# 预警时长可被单敌素材时序覆盖，默认沿用AI数据并守住最小预警窗口。
func _telegraph_duration() -> float:
	return maxf(float(tuning.minimum_telegraph), float(tuning.get("telegraph_duration", definition.ai.telegraph_time)))

func _set_state(value: StringName) -> void:
	state = value
	elapsed = 0.0
	var duration := 0.0
	var action := value
	if value in [&"chase", &"patrol"]:
		action = &"move"
	elif value == &"telegraph":
		duration = _telegraph_duration()
	elif value in [&"attack", &"recover", &"hurt", &"death"]:
		duration = float(tuning[String(value) + "_duration"])
	if value in [&"telegraph", &"attack"]:
		_attack_area.position = _vector(tuning.hitbox_offset) * Vector2(facing, 1)
	if value == &"attack":
		_hit_in_attack = false
	var animation_map: Dictionary = tuning.get("animation_map", {})
	action = StringName(str(animation_map.get(String(action), String(action))))
	visual.action = &""
	visual.play_action(action, facing < 0, duration)

func _packet() -> DamagePacket:
	return DamagePacket.new(int(definition.damage), DamagePacket.DamageType.PHYSICAL, float(tuning.attack_knockback), global_position, enemy_id)

func _attack() -> void:
	if _hit_in_attack:
		return
	if float(definition.ai.attack_range) >= float(tuning.ranged_threshold):
		_hit_in_attack = true
		var projectile := EnemyProjectile.new()
		projectile.packet = _packet()
		projectile.target = target
		projectile.tuning = tuning
		var start := global_position + _body_offset
		projectile.direction = (target.global_position - start).normalized()
		get_parent().add_child(projectile)
		projectile.global_position = start
		return
	_attack_area.position = _vector(tuning.hitbox_offset) * Vector2(facing, 1)
	for area: Area2D in _attack_area.get_overlapping_areas():
		if area is HurtboxComponent and area.owner_actor == target:
			area.receive_hit(_packet())
			_hit_in_attack = true
			break

## 受击统一处理防御、抗性与击退；死亡期间重复命中不会重复发放掉落。
func receive_hit(packet: DamagePacket) -> int:
	if state == &"death" or packet == null:
		return 0
	var resist_key := "magic" if packet.type == DamagePacket.DamageType.MAGIC else "physical"
	var resist := float(definition.resist.get(resist_key, 1.0))
	var defense := float(definition.defense)
	if packet.type == DamagePacket.DamageType.PHYSICAL:
		defense *= 1.0 - InventoryService.talent_effect("defense_ignore_pct") / 100.0
	var damage := maxi(0, roundi(float(packet.amount) * resist * (1.0 - defense / (defense + float(tuning.defense_constant)))))
	if damage == 0:
		return 0
	hp = maxi(0, hp - damage)
	if str(packet.source_id).begins_with("skill_"):
		GameState.mana = mini(GameState.mana_max,GameState.mana + int(InventoryService.talent_effect("skill_hit_mana_regen")))
	if packet.source_id == &"skill_bubble":
		_slow_left = float(tuning.slow_duration)
	if hp == 0:
		_die()
	else:
		if visual.entries.has(&"hurt"):
			_set_state(&"hurt")
		velocity.x = signf(global_position.x - packet.from_position.x) * packet.knockback
	return damage

func _die() -> void:
	if _rewarded:
		return
	_rewarded = true
	_set_state(&"death")
	collision_layer = 0
	hurtbox.set_deferred("monitorable", false)
	GameState.exp += int(definition.exp)
	var coins: Array = definition.coin_drop
	GameState.coin += randi_range(int(coins[0]), int(coins[1]))
	EventBus.exp_gained.emit(int(definition.exp))
	EventBus.coin_changed.emit(GameState.coin)
	EventBus.enemy_died.emit(enemy_id, global_position)
	if str(definition.rank) == "boss":
		EventBus.boss_defeated.emit(enemy_id)
	defeated.emit(self)

func _on_animation_completed(action: StringName) -> void:
	if state == &"death" and action == &"death":
		queue_free()

func _draw() -> void:
	if visual == null or visual.body.visible:
		return
	draw_rect(Rect2(_body_offset - _body_size / 2.0, _body_size), Color.DARK_OLIVE_GREEN)
