class_name CorrumptBrain
extends RefCounted
## 首领决策时钟独立于表现：每秒掷一次概率，震退不重置主招式冷却。
var config: Dictionary
var state: StringName = &"ready"
var move: StringName = &""
var previous_move: StringName = &""
var elapsed := 0.0
var close_accumulated := 0.0
var paralysis_seconds := 0.0
var _was_near := false
var rng := RandomNumberGenerator.new()

## 注入数值表；指定种子仅供复现，默认使用独立随机源。
func configure(value: Dictionary, seed_value: int = -1) -> void:
	config = value
	paralysis_seconds = float(value.get("paralysis_seconds",0))
	if seed_value >= 0:
		rng.seed = seed_value
	else:
		rng.randomize()

## 返回本帧需要发动的招式；无目标时不推进战斗。
func tick(delta: float, context: Dictionary) -> Array[StringName]:
	var events: Array[StringName] = []
	if state == &"dead" or not bool(context.get("alive",false)):
		return events
	if state != &"paralyzed" and bool(context.get("close",false)):
		close_accumulated += delta
		if close_accumulated >= float(config.moves.repel.close_accumulation_seconds):
			close_accumulated = 0
			events.append(&"repel")
	var near := bool(context.get("near",false))
	var entered := near and not _was_near
	_was_near = near
	if entered and state in [&"ready",&"cooldown"]:
		events.append(begin_attack(context,_pick(config.entry_melee_weights)))
		return events
	elapsed += delta
	if state == &"paralyzed" and elapsed >= paralysis_seconds:
		events.append(&"recover_poise")
		events.append(begin_attack(context))
	elif state == &"cooldown" and elapsed >= float(config.cooldown):
		state = &"ready"
		elapsed = 0
	elif state == &"ready":
		while elapsed >= float(config.ready_interval):
			elapsed -= float(config.ready_interval)
			if rng.randf() < float(config.attack_chance):
				events.append(begin_attack(context))
				break
	return events

## 主招式按近远条件抽签；范围外飞针/孢子/引力为30/30/40。
func eligible_weights(context: Dictionary) -> Dictionary:
	var result: Dictionary = config.near_weights.duplicate() if bool(context.get("near",false)) else config.far_weights.duplicate()
	return result

## 原子切换到施法态，阻止同一帧重复抽取主招式。
func begin_attack(context: Dictionary, forced: StringName = &"") -> StringName:
	move = forced if forced != &"" else _pick(eligible_weights(context))
	state = &"casting"
	elapsed = 0
	return move

## 引力收尾时重新检测玩家；可接近战时直接串招，其他情况进入数据指定冷却。
func finish_attack(context: Dictionary) -> StringName:
	previous_move = move
	if move == &"gravity" and bool(context.get("near",false)):
		return begin_attack(context,_pick(config.gravity_followup_weights))
	move = &""
	state = &"cooldown"
	elapsed = 0
	return &""

## 只有非施法期才能破韧，重复命中不延长本次由韧性计算的瘫痪。
func paralyze() -> bool:
	if state not in [&"ready",&"cooldown"]:
		return false
	state = &"paralyzed"
	move = &""
	elapsed = 0
	return true

func _pick(weights: Dictionary) -> StringName:
	var total := 0.0
	for weight in weights.values():
		total += float(weight)
	var value := rng.randf()*total
	for key in weights:
		value -= float(weights[key])
		if value < 0:
			return StringName(key)
	return StringName(weights.keys().back())
