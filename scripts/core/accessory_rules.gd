class_name AccessoryRules
extends RefCounted

## 从已装备的不同饰品累计指定属性。
static func effect(key: String) -> float:
	var value := 0.0
	for id in GameState.equipped_accessories:
		value += float(DataDB.get_accessory(id).get("effects", {}).get(key, 0))
	return value

## 交换背包与已装备饰品，刷新资源上限。
static func swap(carried_index: int, equipped_index: int) -> bool:
	if carried_index < 0 or equipped_index < 0 or equipped_index >= GameState.equipped_accessories.size():
		return false
	var carried := GameState.owned_accessories
	var equipped := GameState.equipped_accessories
	var incoming := carried[carried_index] if carried_index < carried.size() else &""
	if incoming == &"" and equipped[equipped_index] == &"":
		return false
	if incoming != &"" and (DataDB.get_accessory(incoming).is_empty() or equipped.has(incoming)):
		return false
	while carried.size() <= carried_index:
		carried.append(&"")
	carried[carried_index] = equipped[equipped_index]
	equipped[equipped_index] = incoming
	ProgressionService.refresh_limits()
	return true

## 伤害项按同一百分比合计，按攻击形式区分近战与远程。
static func damage_multiplier(range_type: String, post_dodge: bool) -> float:
	var bonus := effect("damage_pct")
	if range_type in ["melee", "ranged"]:
		bonus += effect(range_type + "_damage_pct")
	if bool(DataDB.get_weapon(GameState.weapon_id).get("mechanical", false)):
		bonus += effect("mechanical_damage_pct")
	if GameState.hp_max > 0:
		bonus += (1.0 - float(GameState.hp) / GameState.hp_max) * 100.0 * effect("damage_pct_per_missing_hp_pct")
	if post_dodge:
		bonus += effect("post_dodge_damage_pct")
	return maxf(0.0, 1.0 + bonus / 100.0)

## 生命恢复倍率，持续恢复在累计小数前使用。
static func healing_multiplier() -> float:
	return 1.0 + effect("heal_pct") / 100.0

## 统一扣费前的体力修正，保留整数资源规则。
static func stamina_cost(base: float) -> int:
	return maxi(0, ceili(base * (1.0 + effect("stamina_cost_pct") / 100.0)))

## 奶力消耗在天赋修正之后应用饰品折扣。
static func mana_cost(base: int) -> int:
	return maxi(0, ceili(base * (1.0 + InventoryService.talent_effect("skill_mana_pct") / 100.0) * (1.0 + effect("mana_cost_pct") / 100.0)))
