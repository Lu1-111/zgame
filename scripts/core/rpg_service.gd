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
		GameState.equipment_revision = int(cfg.revision)
	GameState.equipped_skills.resize(int(cfg.active_slots))
	GameState.equipped_passives.resize(int(cfg.passive_slots))
	GameState.selected_skill = clampi(GameState.selected_skill,0,int(cfg.active_slots)-1)


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
	var base: Dictionary = config().base_attributes
	var weapon := DataDB.get_weapon(GameState.weapon_id)
	var result := float(base.magic_attack if kind == "magic" else base.physical_attack)
	result += float(base.attack_per_level) * (GameState.level-1)
	if str(weapon.get("damage_type","")) == kind:
		result += float(weapon.get("attack",0))
	var key := "magic_damage_pct" if kind == "magic" else "physical_damage_pct"
	return roundi(result * (1.0+InventoryService.talent_effect(key)/100.0))


## 返回人物当前实际生效的全部派生属性。
static func stats() -> Dictionary:
	var base: Dictionary = config().base_attributes
	return {"physical_attack":attack_power("physical"),"magic_attack":attack_power("magic"),"defense":float(base.defense)+passive_effect("defense"),"damage_reduction":clampf(float(base.damage_reduction)-InventoryService.talent_effect("damage_taken_pct")+passive_effect("damage_reduction"),0,float(base.max_damage_reduction)),"life_steal":float(base.life_steal)+passive_effect("life_steal"),"hp_regen":float(base.hp_regen)+passive_effect("hp_regen"),"mana_regen":float(base.mana_regen)+passive_effect("mana_regen")}


## 计算当前等级内已积累经验和升至下一级的经验需求。
static func experience_progress() -> Vector2i:
	var growth: Dictionary = InventoryService.config().growth
	var table: Array = growth.cumulative_exp
	if GameState.level >= int(growth.level_cap):
		return Vector2i(1,1)
	var lower := int(table[GameState.level-1])
	var upper := int(table[GameState.level])
	return Vector2i(maxi(0,GameState.exp-lower),maxi(1,upper-lower))
