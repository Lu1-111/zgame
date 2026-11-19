class_name PoiseRules
extends RefCounted
## 削韧独立于生命伤害；制作人未填写的 null 占位按零处理。
static var _data: Dictionary = {}

## 读取敌人韧性上限、反馈参数和所有玩家攻击的削韧表。
static func config() -> Dictionary:
	if _data.is_empty():
		_data = JSON.parse_string(FileAccess.get_file_as_string("res://data/poise.json"))
	return _data

## 查询精确攻击键；未登记或尚未填写的攻击均不暗中套用削韧值。
static func damage(packet: DamagePacket) -> float:
	if packet.normal_poise>=0:return packet.normal_poise
	var row: Dictionary = config().attacks.get(str(packet.poise_key),{})
	var value: Variant = row.get("poise_damage")
	return maxf(0,float(value)) if value is float or value is int else 0.0
