class_name StorageService
extends RefCounted
## 仓库把分类映射到真实物品来源，筛选不会改变物品下标。

## 所有道具、材料、快捷道具与未装备武器统一列出。
static func bag_entries() -> Array[Dictionary]:
	InventoryService.ensure_state()
	var result: Array[Dictionary] = []
	for source in ["inventory","materials","hotbar","owned_weapons"]:
		var entries: Array = GameState.get(source)
		for index in entries.size():
			var value: Variant = entries[index]
			if source == "owned_weapons":
				if str(value) != "":
					result.append(_entry(str(value),1,source,index))
			elif value is Dictionary and int(value.get("count",0)) > 0:
				result.append(_entry(str(value.id),int(value.count),source,index))
	return result

## 无限仓库仅展示有效堆叠，保留真实下标供点击操作。
static func stored_entries() -> Array[Dictionary]:
	var result: Array[Dictionary] = []
	for index in GameState.storage.size():
		var value: Variant = GameState.storage[index]
		if value is Dictionary and int(value.get("count",0)) > 0:
			result.append(_entry(str(value.id),int(value.count),"storage",index))
	return result

## 按物品定义分类；护甲饰品与以后新增物品共用通路。
static func category(id: String) -> String:
	if not DataDB.get_weapon(StringName(id)).is_empty():
		return "weapon"
	var kind := str(DataDB.get_item(StringName(id)).get("type","item"))
	return kind if kind in ["armor","accessory"] else "item"

## 点击转移整格，失败时不改变任何来源物品。
static func transfer(entry: Dictionary) -> bool:
	var index := int(entry.index)
	if str(entry.source) == "storage":
		return _withdraw(index)
	if str(entry.source) != "owned_weapons":
		return InventoryService.deposit(index,str(entry.source))
	if index < 0 or index >= GameState.owned_weapons.size() or GameState.owned_weapons[index] == &"":
		return false
	GameState.storage.append({"id":str(GameState.owned_weapons[index]),"count":1})
	GameState.owned_weapons[index] = &""
	return true

static func _withdraw(index: int) -> bool:
	if index < 0 or index >= GameState.storage.size() or not GameState.storage[index] is Dictionary:
		return false
	var entry: Dictionary = GameState.storage[index]
	if category(str(entry.id)) != "weapon":
		# 材料旧页可以堆叠，但满包时不能凭空开出一个新材料格。
		if str(DataDB.get_item(StringName(entry.id)).get("type","")) == "material" and not GameState.inventory.has(null):
			var room := 0
			var limit := int(DataDB.get_item(StringName(entry.id)).get("stack",1))
			for value: Variant in GameState.materials:
				if value is Dictionary and str(value.id) == str(entry.id):
					room += maxi(0,limit-int(value.count))
			if room < int(entry.count):
				return false
		return InventoryService.withdraw(index)
	if not GameState.inventory.has(null):
		return false
	var free := GameState.owned_weapons.find(&"")
	if free < 0:
		if GameState.owned_weapons.size() >= int(ProgressionService.config().weapon_bag_slots):
			return false
		free = GameState.owned_weapons.size()
		GameState.owned_weapons.append(&"")
	GameState.owned_weapons[free] = StringName(entry.id)
	entry.count = int(entry.count)-1
	if int(entry.count) <= 0:
		GameState.storage.remove_at(index)
	return true

static func _entry(id: String, count: int, source: String, index: int) -> Dictionary:
	return {"id":id,"count":count,"source":source,"index":index,"category":category(id)}
