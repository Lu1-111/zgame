class_name InventoryService
extends RefCounted
## 背包规则：固定格、堆叠、拖拽移动、独立快捷物品、仓库守恒与数据驱动物品效果。

const CONFIG_PATH := "res://data/gameplay_ui.json"
static var _config: Dictionary = {}


## 读取系统和表现配置，游戏数值统一取自 JSON。
static func config() -> Dictionary:
	if _config.is_empty():
		_config = JSON.parse_string(FileAccess.get_file_as_string(CONFIG_PATH))
	return _config


## 当前可用行囊格子数。
static func capacity() -> int:
	var limits: Dictionary = config().inventory
	return int(limits.base_slots) + int(limits.extra_slots) * GameState.bag_upgrades


## 兼容旧存档的紧凑数组，并保持空格位置；材料迁入独立页。
static func ensure_state() -> void:
	RPGService.ensure_state()
	GameState.bag_upgrades = clampi(GameState.bag_upgrades,0,int(config().inventory.max_upgrades))
	for index in GameState.inventory.size():
		var entry: Variant = GameState.inventory[index]
		if entry is Dictionary and str(DataDB.get_item(StringName(entry.get("id",""))).get("type","")) == "material":
			_put_unlimited(GameState.materials,str(entry.id),int(entry.get("count",0)))
			GameState.inventory[index] = null
	while GameState.inventory.size() > capacity():
		var overflow: Variant = GameState.inventory.pop_back()
		if overflow is Dictionary:
			_put_unlimited(GameState.storage,str(overflow.id),int(overflow.count))
	GameState.inventory.resize(capacity())
	GameState.hotbar.resize(int(config().inventory.hotbar_slots))
	for index in GameState.hotbar.size():
		var entry: Variant = GameState.hotbar[index]
		if entry is String or entry is StringName:
			GameState.hotbar[index] = null
			for bag_index in GameState.inventory.size():
				var stack: Variant = GameState.inventory[bag_index]
				if stack is Dictionary and str(stack.id) == str(entry):
					GameState.hotbar[index] = stack
					GameState.inventory[bag_index] = null
					break
	_cleanup_hotbar()


## 查询持有数量；包含行囊、材料页和独立快捷栏中的实际堆叠。
static func count_item(id: String) -> int:
	var total := 0
	for array: Array in [GameState.inventory,GameState.materials,GameState.hotbar]:
		for entry: Variant in array:
			if entry is Dictionary and str(entry.get("id","")) == id:
				total += int(entry.get("count",0))
	return total


## 整批接收道具；容量不足时原子失败，来源掉落与宝箱不得消失。
static func add_item(id: String, count: int) -> bool:
	ensure_state()
	var definition := DataDB.get_item(StringName(id))
	if definition.is_empty() and not DataDB.get_weapon(StringName(id)).is_empty() and count > 0:
		if GameState.weapon_id != StringName(id) and not GameState.owned_weapons.has(StringName(id)):
			GameState.owned_weapons.append(StringName(id))
		EventBus.item_picked.emit(StringName(id),count)
		return true
	if definition.is_empty() or count <= 0:
		return false
	if str(definition.type) == "material":
		_put_unlimited(GameState.materials, id, count)
	else:
		var copy := GameState.inventory.duplicate(true)
		if not _put_slots(copy, id, count):
			return false
		GameState.inventory = copy
	EventBus.item_picked.emit(StringName(id), count)
	return true


static func _put_slots(array: Array, id: String, count: int) -> bool:
	var limit := int(DataDB.get_item(StringName(id)).get("stack", 1))
	for entry: Variant in array:
		if entry is Dictionary and str(entry.id) == id:
			var fill := mini(count, maxi(0, limit - int(entry.count)))
			entry.count = int(entry.count) + fill
			count -= fill
	for index in array.size():
		if count <= 0:
			return true
		if array[index] == null:
			var fill := mini(count, limit)
			array[index] = {"id":id,"count":fill}
			count -= fill
	return count == 0


static func _put_unlimited(array: Array, id: String, count: int) -> void:
	var limit := int(DataDB.get_item(StringName(id)).get("stack", 99))
	for entry: Variant in array:
		if entry is Dictionary and str(entry.id) == id:
			var fill := mini(count, maxi(0, limit - int(entry.count)))
			entry.count = int(entry.count) + fill
			count -= fill
	for index in array.size():
		if count <= 0:
			return
		if array[index] == null:
			var fill := mini(count,limit)
			array[index] = {"id":id,"count":fill}
			count -= fill
	while count > 0:
		var fill := mini(count, limit)
		array.append({"id":id,"count":fill})
		count -= fill


## 在背包格间拖拽；同类优先合并，否则交换，空格仍为空格。
static func move_slot(from: int, to: int, page: String = "inventory") -> bool:
	var array: Array = GameState.hotbar if page == "hotbar" else (GameState.materials if page == "materials" else GameState.inventory)
	if page == "materials" and from >= 0 and from < array.size() and to >= array.size():
		array.resize(to + 1)
	if from < 0 or to < 0 or from >= array.size() or to >= array.size() or from == to:
		return false
	if not array[from] is Dictionary:
		return false
	if array[to] is Dictionary and str(array[from].id) == str(array[to].id):
		var limit := int(DataDB.get_item(StringName(array[from].id)).get("stack", 1))
		var amount := mini(int(array[from].count), maxi(0, limit - int(array[to].count)))
		array[to].count = int(array[to].count) + amount
		array[from].count = int(array[from].count) - amount
		if int(array[from].count) <= 0:
			array[from] = null
	else:
		var hold: Variant = array[to]
		array[to] = array[from]
		array[from] = hold
	return true


## 消耗品整格搬入固定五格快捷栏，腾出原背包格；替换时交换旧堆叠。
static func register_hotbar(id: String, slot: int, from_index: int = -1) -> bool:
	ensure_state()
	if slot < 0 or slot >= GameState.hotbar.size() or str(DataDB.get_item(StringName(id)).get("type","")) != "consumable":
		return false
	if from_index < 0:
		for index in GameState.inventory.size():
			if GameState.inventory[index] is Dictionary and str(GameState.inventory[index].id) == id:
				from_index = index
				break
	if from_index < 0 or from_index >= GameState.inventory.size() or not GameState.inventory[from_index] is Dictionary or str(GameState.inventory[from_index].id) != id:
		return false
	var old: Variant = GameState.hotbar[slot]
	var incoming: Dictionary = GameState.inventory[from_index]
	if old is Dictionary and str(old.id) == id:
		var fill := mini(int(incoming.count),maxi(0,int(DataDB.get_item(StringName(id)).stack)-int(old.count)))
		if fill == 0:
			return false
		old.count = int(old.count)+fill
		incoming.count = int(incoming.count)-fill
		if int(incoming.count) <= 0:
			GameState.inventory[from_index] = null
	else:
		GameState.hotbar[slot] = incoming
		GameState.inventory[from_index] = old
	return true


## 快捷物品拖回背包时检查容量，移动或交换真实堆叠。
static func unregister_hotbar(slot: int, to_index: int = -1) -> bool:
	ensure_state()
	if slot < 0 or slot >= GameState.hotbar.size() or not GameState.hotbar[slot] is Dictionary:
		return false
	var stack: Dictionary = GameState.hotbar[slot]
	if to_index >= 0:
		if to_index >= GameState.inventory.size():
			return false
		var old: Variant = GameState.inventory[to_index]
		if old is Dictionary and str(DataDB.get_item(StringName(old.id)).get("type","")) != "consumable":
			return false
		GameState.inventory[to_index] = stack
		GameState.hotbar[slot] = old
	else:
		var copy := GameState.inventory.duplicate(true)
		if not _put_slots(copy,str(stack.id),int(stack.count)):
			return false
		GameState.inventory = copy
		GameState.hotbar[slot] = null
	return true


## 丢弃直接销毁所选格的全部物品，并清理失效快捷栏引用。
static func discard_slot(slot: int, page: String = "inventory") -> bool:
	var array: Array = GameState.hotbar if page == "hotbar" else (GameState.materials if page == "materials" else GameState.inventory)
	if slot < 0 or slot >= array.size() or not array[slot] is Dictionary:
		return false
	array[slot] = null
	_cleanup_hotbar()
	return true


## 使用指定物品；无效果、资源已满或扩容达上限时不扣数量。
static func use_slot(slot: int, actor: Node = null) -> bool:
	ensure_state()
	return _use_from(GameState.inventory,slot,actor)


## 使用已注册快捷栏物品，与背包按钮共用扣除逻辑。
static func use_hotbar(slot: int, actor: Node = null) -> bool:
	ensure_state()
	return _use_from(GameState.hotbar,slot,actor)


static func _cleanup_hotbar() -> void:
	for index in GameState.hotbar.size():
		var entry: Variant = GameState.hotbar[index]
		if not entry is Dictionary or int(entry.get("count",0)) <= 0 or str(DataDB.get_item(StringName(entry.get("id",""))).get("type","")) != "consumable":
			GameState.hotbar[index] = null


## 整格存入无限仓库，数量守恒；空格与非法下标不做任何操作。
static func deposit(slot: int, page: String = "inventory") -> bool:
	var array: Array = GameState.hotbar if page == "hotbar" else (GameState.materials if page == "materials" else GameState.inventory)
	if slot < 0 or slot >= array.size() or not array[slot] is Dictionary:
		return false
	var entry: Dictionary = array[slot]
	_put_unlimited(GameState.storage, str(entry.id), int(entry.count))
	array[slot] = null
	_cleanup_hotbar()
	return true


## 仓库取回整格；背包不足时保持仓库原样。
static func withdraw(slot: int) -> bool:
	if slot < 0 or slot >= GameState.storage.size() or not GameState.storage[slot] is Dictionary:
		return false
	var entry: Dictionary = GameState.storage[slot]
	if not add_item(str(entry.id), int(entry.count)):
		return false
	GameState.storage.remove_at(slot)
	return true


## 汇总已经激活的天赋加成；预留且 enabled=false 的节点不生效。
static func talent_effect(key: String, fallback: float = 0.0) -> float:
	var result := fallback
	for id in GameState.talents:
		var effect: Dictionary = DataDB.get_talent(id).get("effect", {})
		if effect.get("enabled", true) and effect.has(key):
			result += float(effect[key])
	return result


## 可用天赋点由等级与首杀奖励扣除已消费点数，重置自动返还。
static func available_points() -> int:
	var spent := 0
	for id in GameState.talents:
		spent += int(DataDB.get_talent(id).get("cost_point", 1))
	return maxi(0, GameState.level - 1 + GameState.defeated_bosses.size() - spent)


## 校验前置、点数、奶币和预留状态后购买天赋，并实时应用上限增量。
static func buy_talent(id: StringName) -> bool:
	var node := DataDB.get_talent(id)
	if node.is_empty() or GameState.talents.has(id) or not bool(node.get("effect", {}).get("enabled", true)):
		return false
	var prerequisite := StringName(node.get("requires", ""))
	if prerequisite != &"" and not GameState.talents.has(prerequisite):
		return false
	if available_points() < int(node.cost_point) or GameState.coin < int(node.cost_coin):
		return false
	GameState.coin -= int(node.cost_coin)
	GameState.talents.append(id)
	if node.effect.has("mana_max"):
		GameState.mana_max += int(node.effect.mana_max)
	return true


## 重置退还点数、不退购买奶币；扣除重置费用并撤销上限增量。
static func reset_talents() -> bool:
	var cost := int(config().inventory.reset_cost)
	if GameState.coin < cost or GameState.talents.is_empty():
		return false
	GameState.coin -= cost
	GameState.mana_max -= int(talent_effect("mana_max"))
	GameState.mana = mini(GameState.mana, GameState.mana_max)
	GameState.talents.clear()
	return true


## 技能解锁条件与数据表一致，天赋技能自动随天赋获得。
static func skill_unlocked(id: StringName) -> bool:
	var definition := DataDB.get_skill(id)
	if definition.is_empty() or bool(definition.get("placeholder",false)):
		return false
	var rule := str(definition.get("unlock",""))
	return rule == "initial" or GameState.learned_skills.has(id) or (rule.begins_with("talent_") and GameState.talents.has(StringName(rule.trim_prefix("talent_"))))


## 获取三个主动技能栏当前装备的技能，空槽返回空 ID。
static func equipped_skill(index: int) -> StringName:
	return GameState.equipped_skills[index] if index >= 0 and index < GameState.equipped_skills.size() else &""


## 把已解锁主动技能装到指定格，滚轮与侧键共用当前装配。
static func equip_skill(id: StringName, index: int) -> bool:
	return RPGService.equip_skill(id,index)


## 施法与 HUD 共用天赋修正后的实际奶力消耗。
static func skill_mana_cost(id: StringName) -> int:
	return ceili(float(DataDB.get_skill(id).get("mana_cost",0)) * (1.0 + talent_effect("skill_mana_pct") / 100.0))


static func _use_from(array: Array, slot: int, actor: Node = null) -> bool:
	if slot < 0 or slot >= array.size() or not array[slot] is Dictionary:
		return false
	var entry: Dictionary = array[slot]
	var id := str(entry.id)
	var effect: Dictionary = DataDB.get_item(StringName(id)).get("effect", {})
	var used := false
	for resource in ["hp", "sta", "mana"]:
		var key: String = "restore_" + str(resource)
		if effect.has(key):
			var old := int(GameState.get(resource))
			var maximum := int(GameState.get(resource + "_max"))
			if old < maximum:
				GameState.set(resource, mini(maximum, old + int(effect[key])))
				used = true
	for resource in ["hp", "sta", "mana"]:
		var key: String = str(resource) + "_max"
		if effect.has(key):
			GameState.set(key, int(GameState.get(key)) + int(effect[key]))
			GameState.set(resource, int(GameState.get(resource)) + int(effect[key]))
			used = true
	if effect.has("bag_slots") and GameState.bag_upgrades < int(config().inventory.max_upgrades):
		GameState.bag_upgrades += 1
		used = true
	if effect.has("reveal_map") and not GameState.map_revealed:
		GameState.map_revealed = true
		used = true
	if effect.has("unlock_ability") and not GameState.abilities.has(StringName(effect.unlock_ability)):
		GameState.abilities.append(StringName(effect.unlock_ability))
		EventBus.ability_unlocked.emit(StringName(effect.unlock_ability))
		used = true
	if effect.has("damage") and actor != null and actor.has_method("throw_inventory_item"):
		actor.throw_inventory_item(id, int(effect.damage))
		used = true
	if not used:
		return false
	entry.count = int(entry.count) - 1
	if int(entry.count) <= 0:
		array[slot] = null
	ensure_state()
	if actor != null and actor.has_method("play_item_animation"):
		actor.play_item_animation(id)
	EventBus.item_picked.emit(StringName(id), -1)
	return true


## 物理技能只消耗体力；奶术技能同时消耗少量体力。
static func skill_stamina_cost(id: StringName) -> int:
	return int(DataDB.get_skill(id).get("stamina_cost",0))
