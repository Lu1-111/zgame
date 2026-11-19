class_name WeaponAttributes
extends RefCounted
## 武器类别基础属性与具体武器倍率；仅影响普通攻击，技能保持独立配置。
static var _data: Dictionary = {}

## 读取冻结的四类基础削韧和完整攻击阶段时间。
static func config() -> Dictionary:
	if _data.is_empty():_data=JSON.parse_string(FileAccess.get_file_as_string("res://data/weapon_attributes.json"))
	return _data

## 本段基础削韧乘当前武器削韧倍率。
static func poise_damage(weapon: Dictionary, combo: int) -> float:
	var entry: Dictionary=config().types.get(str(weapon.get("weapon_type","")),{})
	var values: Array=entry.get("base_poise",[])
	if values.is_empty():return 0.0
	return float(values[clampi(combo-1,0,values.size()-1)])*float(weapon.get("poise_multiplier",1.0))

## 普通攻击完整用时：基础时间除以攻速倍率，倍率越大用时越短。
static func duration(weapon: Dictionary, effective_speed: float = 0.0) -> float:
	var entry: Dictionary=config().types.get(str(weapon.get("weapon_type","")),{})
	var speed := effective_speed if effective_speed > 0.0 else float(weapon.get("attack_speed_multiplier", 1.0))
	return float(entry.get("base_total_seconds", 0)) / speed

## 满弹药储量对应的整数单位。
static func ammo_capacity() -> int:
	return int(config().rifle.ammo_capacity_units)

## 百分比损耗换算为整数单位，霰弹每次射击只扣一次。
static func ammo_cost(weapon: Dictionary) -> int:
	return roundi(float(weapon.get("ammo_cost_pct", 0)) * ammo_capacity() / 100.0)

## 按能力类别查询独立条目，状态与武器技能占位不参与实际结算。
static func effect(weapon: Dictionary, kind: String) -> Dictionary:
	for entry: Dictionary in weapon.get("special_effects",[]):
		if str(entry.kind)==kind and bool(entry.get("implemented",false)):return entry
	return {}

## 伤害加成只检测命中前已有的破韧/破防状态。
static func target_is_broken(target: Node) -> bool:
	if not is_instance_valid(target):return false
	var poise: Variant=target.get("poise")
	return poise!=null and bool(poise.get("broken"))
