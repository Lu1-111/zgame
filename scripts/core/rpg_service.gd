class_name RPGService
extends RefCounted
## 人物面板规则：独立装备交换、技能装配、实时属性与旧存档迁移。
static var _settings := {}


## 读取数据驱动的人物与操作规格。
static func config() -> Dictionary:
	if _settings.is_empty():
		_settings = JSON.parse_string(FileAccess.get_file_as_string("res://data/rpg_systems.json"))
	return _settings


## 迁移旧装备列表并保证三主动、二被动槽；旧物品只搬移一次。
static func ensure_state() -> void:
	var cfg := config()
	if GameState.equipment_revision < int(cfg.revision):
		GameState.owned_weapons.erase(GameState.weapon_id)
		for id: String in cfg.starter_weapons:
			if id != str(GameState.weapon_id) and not GameState.owned_weapons.has(StringName(id)):
				GameState.owned_weapons.append(StringName(id))
		for id: String in cfg.starter_accessories:
			var key := StringName(id)
			if not GameState.owned_accessories.has(key) and not GameState.equipped_accessories.has(key):
				GameState.owned_accessories.append(key)
		GameState.equipment_revision = int(cfg.revision)
	while GameState.equipped_accessories.size() < int(cfg.accessory_slots):
		GameState.equipped_accessories.append(&"")
	GameState.equipped_skills.resize(int(cfg.active_slots))
	GameState.equipped_passives.resize(int(cfg.passive_slots))
	GameState.selected_skill = clampi(GameState.selected_skill,0,int(cfg.active_slots)-1)
	SkillLibrary.migrate_state(GameState)


## 装上武器并将原武器退回同一物品格，交换全程守恒。
static func equip_weapon(index: int) -> bool:
	if index < 0 or index >= GameState.owned_weapons.size():
		return false
	var id := GameState.owned_weapons[index]
	if id == &"" or DataDB.get_weapon(id).is_empty():
		return false
	var old := GameState.weapon_id
	GameState.weapon_id = id
	GameState.owned_weapons[index] = old
	return true


## 从人物武器槽拖回格子；空格卸下，已有武器格与当前武器交换。
static func unequip_weapon(index: int) -> bool:
	if index < 0 or GameState.weapon_id == &"":
		return false
	while GameState.owned_weapons.size() <= index:
		GameState.owned_weapons.append(&"")
	var target := GameState.owned_weapons[index]
	GameState.owned_weapons[index] = GameState.weapon_id
	GameState.weapon_id = target
	return true


## 装备列表中的位置交换，保留空格。
static func move_weapon(from: int, to: int) -> bool:
	if from < 0 or from >= GameState.owned_weapons.size() or to < 0 or from == to:
		return false
	while GameState.owned_weapons.size() <= to:
		GameState.owned_weapons.append(&"")
	var hold := GameState.owned_weapons[from]
	GameState.owned_weapons[from] = GameState.owned_weapons[to]
	GameState.owned_weapons[to] = hold
	return true


## 未解锁技能可查看但不可装备；同一技能不会重复占用两个槽。
static func equip_skill(id: StringName, index: int, passive: bool = false) -> bool:
	id = SkillLibrary.canonical(id)
	var definition := DataDB.get_skill(id)
	var category := "passive" if passive else "active"
	var slots: Array[StringName] = GameState.equipped_passives if passive else GameState.equipped_skills
	if index < 0 or index >= slots.size() or str(definition.get("category","active")) != category or not InventoryService.skill_unlocked(id):
		return false
	var old_index := slots.find(id)
	if old_index == index:
		return true
	if old_index >= 0:
		slots[old_index] = slots[index]
	slots[index] = id
	ProgressionService.refresh_limits()
	return true


## 汇总两个已装备被动的效果。
static func passive_effect(key: String) -> float:
	var total := 0.0
	for id in GameState.equipped_passives:
		if InventoryService.skill_unlocked(id):
			total += float(DataDB.get_skill(id).get("effect",{}).get(key,0))
	return total


## 属性页和战斗共用攻击力，武器加成只加入对应伤害类型。
static func attack_power(kind: String) -> int:
	var key := "magic_attack" if kind == "magic" else "physical_attack"
	var weapon := DataDB.get_weapon(GameState.weapon_id)
	var base: Dictionary = config().base_attributes
	var raw := float(base[key])+float(base.attack_per_level)*(GameState.level-1)
	if str(weapon.get("damage_type","")) == kind:
		raw += float(weapon.get("attack",0))
	var multiplier := 1.0+ProgressionService.point_effect(key+"_pct")/100.0
	var extra := InventoryService.talent_effect("magic_damage_pct" if kind == "magic" else "physical_damage_pct")
	var frenzy: Dictionary = GameState.skill_buffs.get("frenzy",{})
	return roundi(raw*multiplier*(1.0+extra/100.0)*(1.0+float(frenzy.get("damage_bonus_pct",0))/100.0))


## 返回战斗和人物面板共用的实际属性。
static func stats() -> Dictionary:
	return ProgressionService.total_stats()


## 计算当前等级内已积累经验和升至下一级的经验需求。
static func experience_progress() -> Vector2i:
	var growth: Dictionary = InventoryService.config().growth
	var table: Array = growth.cumulative_exp
	if GameState.level >= int(growth.level_cap):
		return Vector2i(1,1)
	var lower := int(table[GameState.level-1])
	var upper := int(table[GameState.level])
	return Vector2i(maxi(0,GameState.exp-lower),maxi(1,upper-lower))
