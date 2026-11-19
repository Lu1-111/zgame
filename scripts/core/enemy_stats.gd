class_name EnemyStats
extends RefCounted
static var _boss_rules: Dictionary = {}
static var _scaling_rules: Dictionary = {}

## 首领破韧时长统一由1+韧性×0.01计算，显式paralysis_seconds可特例覆盖。
static func paralysis_seconds(definition: Dictionary) -> float:
	if definition.has("paralysis_seconds"):
		return float(definition.paralysis_seconds)
	if _boss_rules.is_empty():
		_boss_rules = JSON.parse_string(FileAccess.get_file_as_string("res://data/boss_rules.json"))
	return float(_boss_rules.paralysis.base_seconds)+float(definition.poise)*float(_boss_rules.paralysis.poise_factor)

## 抗性为百分比减伤；与区域倍率无关，忽略防御的攻击仍计算抗性。
static func damage_taken(definition: Dictionary, packet: DamagePacket, defense_constant: float, physical_ignore_pct: float = 0.0) -> int:
	var key := "magic" if packet.type == DamagePacket.DamageType.MAGIC else "physical"
	var resistance := clampf(float(definition.get("resist",{}).get(key,0.0)),0.0,100.0)
	var defense := 0.0 if packet.ignore_defense else maxf(0,float(definition.get("defense",0)))
	if packet.type == DamagePacket.DamageType.PHYSICAL:
		defense *= 1.0-clampf(physical_ignore_pct/100.0,0.0,1.0)
	return maxi(0,roundi(float(packet.amount)*(1.0-resistance/100.0)*defense_constant/(defense+defense_constant)))
## 数据表只保存基础值；出生时按房间所属区域生成独立的最终属性副本。

## 仅带 base_ 前缀的数值受区域倍率影响，防御、韧性、速度与奖励不隐式缩放。
static func resolve(base: Dictionary, region: Dictionary, policy: Dictionary = {}) -> Dictionary:
	if base.is_empty():
		return {}
	var result := base.duplicate(true)
	if policy.is_empty():
		if _scaling_rules.is_empty():
			_scaling_rules = JSON.parse_string(FileAccess.get_file_as_string("res://data/enemy_scaling.json"))
		policy = _scaling_rules
	var tier_factor := float(policy.default_tier_multiplier)
	if region.has("tier"):
		var tier_key := str(int(region.tier))
		if not policy.tier_multipliers.has(tier_key) or policy.tier_multipliers[tier_key] == null:
			return {}
		tier_factor = float(policy.tier_multipliers[tier_key])
	var region_factor := maxf(0,float(region.get(str(policy.region_multiplier_field),1.0)))
	var multiplier := tier_factor*region_factor
	for key: String in base:
		if not key.begins_with("base_") or not (base[key] is int or base[key] is float):
			continue
		var field := key.trim_prefix("base_")
		var value := float(base[key])*multiplier
		result[field] = roundi(value) if field in policy.rounded_fields else value
	result["region_multiplier"] = multiplier
	result["region_factor"] = region_factor
	result["region_tier_multiplier"] = tier_factor
	result["region_tier"] = region.get("tier",null)
	result["region_id"] = str(region.get("id",""))
	return result
