class_name EnemyPoise
extends RefCounted
## 内置韧性池：破韧只触发一次，硬直结束回满；非破韧命中只震动表现节点。
var maximum := 0.0
var current := 0.0
var broken := false
var _shake_left := 0.0
var _shake_time := 0.0

## 从统一数值表初始化，每个敌人持有独立实例。
func configure(override_maximum: float = -1.0) -> void:
	maximum = override_maximum if override_maximum > 0 else float(PoiseRules.config().enemy_max)
	recover()

## 返回本次是否首次破韧；易削韧窗口只倍率化本次削韧，不改写原伤害包。
func receive(packet: DamagePacket, damage_multiplier: float = 1.0) -> bool:
	_shake_left = float(PoiseRules.config().feedback.seconds)
	_shake_time = 0
	if broken:
		return false
	current = maxf(0,current-PoiseRules.damage(packet)*maxf(0,damage_multiplier))
	if current <= 0:
		broken = true
		return true
	return false

## 硬直动作结束时恢复满韧性。
func recover() -> void:
	current = maximum
	broken = false

## 只移动美术节点，碰撞体、攻击窗口和 AI 时序保持稳定。
func feedback_offset(delta: float) -> Vector2:
	_shake_left = maxf(0,_shake_left-delta)
	_shake_time += delta
	if _shake_left <= 0:
		return Vector2.ZERO
	var cfg: Dictionary = PoiseRules.config().feedback
	return Vector2(sin(_shake_time*TAU*float(cfg.frequency))*float(cfg.amplitude)*_shake_left/float(cfg.seconds),0)
