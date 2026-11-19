class_name EnemyStatusEffects
extends Node2D
## 怪物异常状态按战斗时间结算，动作减速不延长状态本身。

static var _rules: Dictionary
var _active: Dictionary = {}
var _body_size := Vector2.ZERO
var _particle_time := 0.0

## 读取状态数值和粒子素材。
static func config() -> Dictionary:
	if _rules.is_empty():
		_rules = JSON.parse_string(FileAccess.get_file_as_string("res://data/status_effects.json"))
	return _rules

## 对齐角色受击范围，在原生像素网格绘制状态粒子。
func configure(size_value: Vector2, center: Vector2) -> void:
	_body_size = size_value
	position = center
	texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	z_index = 1
	set_physics_process(false)

## 同类异常刷新时长，保留当前跳伤节奏和小数伤害。
func apply(id: String, duration: float, source_multiplier: float = 1.0) -> void:
	var definition: Dictionary = config().statuses.get(id, {})
	if duration <= 0 or definition.is_empty():
		return
	if _active.is_empty():
		_particle_time = 0
		set_physics_process(true)
	if not _active.has(id):
		_active[id] = {"left": 0.0, "tick": 0.0, "carry": 0.0, "texture": load(str(definition.particle))}
	var effect: Dictionary = _active[id]
	effect.left = maxf(float(effect.left), duration)
	effect.multiplier = source_multiplier

## 流血期间额外承受削韧，生命伤害仍由原流程计算。
func poise_multiplier() -> float:
	return float(config().statuses.bleeding.poise_taken_multiplier) if _active.has("bleeding") else 1.0

## 中毒阻止当前生命池内的一切生命恢复。
func healing_blocked() -> bool:
	return _active.has("poison") and bool(config().statuses.poison.block_healing)

## 冰缓同时降低动作时钟和逐帧播放速度。
func action_speed() -> float:
	return float(config().statuses.chill.action_speed_multiplier) if _active.has("chill") else 1.0

## 怪物死亡或首领切换独立阶段生命池时清除当前异常。
func clear() -> void:
	_active.clear()
	set_physics_process(false)
	queue_redraw()

func _physics_process(delta: float) -> void:
	var enemy := get_parent()
	if int(enemy.get("hp")) <= 0:
		clear()
		return
	var definition: Dictionary = enemy.get("definition")
	var rules := config()
	var rank := "boss" if enemy.is_in_group(&"bosses") else str(definition.get("rank", "small"))
	var rank_multiplier := float(rules.rank_damage_multiplier.get(rank, 1.0))
	for id: String in _active.keys():
		var effect: Dictionary = _active[id]
		var step := minf(float(effect.left), delta)
		effect.left = maxf(0, float(effect.left) - delta)
		effect.tick = float(effect.tick) + step
		var rate := float(rules.statuses[id].get("max_hp_pct_per_tick", 0))
		var interval := float(rules.tick_seconds)
		while rate > 0 and (float(effect.tick) >= interval or is_equal_approx(float(effect.tick), interval)):
			effect.tick = maxf(0, float(effect.tick) - interval)
			effect.carry = float(effect.carry) + float(definition.hp) * rate / 100.0 * rank_multiplier * float(effect.multiplier)
			var damage := roundi(float(effect.carry))
			effect.carry = float(effect.carry) - damage
			if damage > 0:
				enemy.apply_status_damage(damage)
				if int(enemy.get("hp")) <= 0:
					clear()
					return
		if is_zero_approx(float(effect.left)):
			_active.erase(id)
	if _active.is_empty():
		clear()
		return
	_particle_time += delta
	queue_redraw()

func _draw() -> void:
	if _active.is_empty():
		return
	var rules := config()
	var period := float(rules.particle_period)
	var life := float(rules.particle_seconds)
	var index := 0
	for id: String in _active:
		var phase := fposmod(_particle_time + index * period / rules.statuses.size(), period)
		if phase < life:
			var sprite: Texture2D = _active[id].texture
			var event := floori(_particle_time / period)
			for side in [-1, 1]:
				var spread: Array = rules.particle_spread
				var placement := Vector2(side * _body_size.x * float(spread[0]), -_body_size.y * float(spread[1]))
				placement.x += sin(event * 1.8 + side) * _body_size.x * float(spread[2])
				placement.y -= phase / life * float(rules.particle_drift)
				draw_texture(sprite, (placement - sprite.get_size() / 2.0).round())
		index += 1
