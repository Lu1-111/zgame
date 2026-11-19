class_name ProgressionService
extends RefCounted
## 点数、奶能、基础属性与额外加成的唯一计算入口。
static var _config: Dictionary = {}

## 读取成长规则，所有加点数值来自数据表。
static func config() -> Dictionary:
	if _config.is_empty():
		_config = JSON.parse_string(FileAccess.get_file_as_string("res://data/progression.json"))
	return _config

## 旧存档按已有等级补发奶能，并保留已消费道具产生的永久上限。
static func ensure_state() -> void:
	for spec: Dictionary in config().attributes:
		GameState.attribute_points[spec.id] = maxi(0,int(GameState.attribute_points.get(spec.id,0)))
	if GameState.progression_revision < int(config().revision):
		var base := base_stats()
		for key: String in config().defaults:
			GameState.permanent_bonuses[key] = maxi(0,int(GameState.get(key))-int(base[key])-int(RPGService.passive_effect(key))-int(InventoryService.talent_effect(key)))
		GameState.progression_revision = int(config().revision)

## 取得某个加点对属性的累计作用。
static func point_effect(key: String) -> float:
	var result := 0.0
	for spec: Dictionary in config().attributes:
		result += float(spec.effects.get(key,0))*int(GameState.attribute_points.get(spec.id,0))
	return result

## 基础值包含等级和已分配点数，排除武器、道具与技能加成。
static func base_stats() -> Dictionary:
	var base: Dictionary = RPGService.config().base_attributes
	var growth: Dictionary = InventoryService.config().growth
	var result := base.duplicate(true)
	for key: String in config().defaults:
		var per_level := float(growth.get(key.trim_suffix("_max")+"_per_level",0))
		result[key] = float(config().defaults[key])+per_level*(GameState.level-1)+point_effect(key)
	for key in ["physical_attack","magic_attack"]:
		result[key] = roundi((float(base[key])+float(base.attack_per_level)*(GameState.level-1))*(1.0+point_effect(key+"_pct")/100.0))
	result.sta_regen = PlayerTuning.STA_REGEN*float(result.sta_max)/float(config().defaults.sta_max)
	result.cooldown_reduction = point_effect("cooldown_reduction")
	return result

## 合并永久道具、已装备技能与旧天赋，返回实际生效值。
static func total_stats() -> Dictionary:
	var result := base_stats()
	for key: String in result:
		result[key] = float(result[key])+float(GameState.permanent_bonuses.get(key,0))+RPGService.passive_effect(key)
	result.physical_attack = RPGService.attack_power("physical")
	result.magic_attack = RPGService.attack_power("magic")
	for key: String in config().defaults:
		result[key] = float(result[key])+InventoryService.talent_effect(key)
	result.damage_reduction = clampf(float(result.damage_reduction)-InventoryService.talent_effect("damage_taken_pct"),0,float(RPGService.config().base_attributes.max_damage_reduction))
	result.damage_reduction = clampf(float(result.damage_reduction)+float(GameState.skill_buffs.get("endurance",{}).get("damage_reduction_pct",0)),0,float(RPGService.config().base_attributes.max_damage_reduction))
	result.hp_max = float(result.hp_max) * (1.0 + AccessoryRules.effect("hp_max_pct") / 100.0)
	result.damage_reduction = minf(float(result.damage_reduction) + AccessoryRules.effect("damage_reduction_pct"), float(RPGService.config().base_attributes.max_damage_reduction))
	result.sta_regen = PlayerTuning.STA_REGEN*float(result.sta_max)/float(config().defaults.sta_max) * (1.0 + AccessoryRules.effect("stamina_regen_pct") / 100.0)
	return result

## 基础和加成分列；生命等资源显示最大值。
static func breakdown() -> Dictionary:
	var base := base_stats()
	var total := total_stats()
	var bonus := {}
	for row: Array in config().stat_rows:
		bonus[row[0]] = float(total[row[0]])-float(base[row[0]])
	return {"base":base,"bonus":bonus,"total":total}

## 更新三项资源上限，保留当前资源，防止换被动白赚恢复。
static func refresh_limits() -> void:
	var values := total_stats()
	for key: String in config().defaults:
		GameState.set(key,roundi(values[key]))
		var current := key.trim_suffix("_max")
		GameState.set(current,mini(int(GameState.get(current)),int(GameState.get(key))))

## 坐火时消费奶能升一级；其他界面不能调用加点成功。
static func allocate(id: String, at_fire: bool = false) -> bool:
	if not at_fire or not GameUI.is_resting() or GameUI.mode != "talents":
		return false
	var valid := false
	for spec: Dictionary in config().attributes:
		valid = valid or str(spec.id) == id
	var cost := int(config().point_cost)
	if not valid or GameState.milk_energy < cost:
		return false
	GameState.milk_energy -= cost
	GameState.attribute_points[id] = int(GameState.attribute_points.get(id,0))+1
	refresh_limits()
	return true

## 升级统一发放奶能并刷新基础上限。
static func on_level_up() -> void:
	GameState.milk_energy += int(config().energy_per_level)
	refresh_limits()

## 技能实际冷却，感知线性缩减并保留正值下限。
static func skill_cooldown(id: StringName) -> float:
	var multiplier := maxf(float(config().minimum_cooldown_multiplier),1.0-float(total_stats().cooldown_reduction)/100.0)
	return float(DataDB.get_skill(id).get("cooldown",0))*multiplier
