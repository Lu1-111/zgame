extends Node2D
## 藤影回廊：遭遇组清场、永久消散雾墙、空宝箱与单向回环捷径。
const CONFIG := "res://data/maps/forest_03.json"
var config: Dictionary
var _poll := 0.0

func _ready() -> void:
	config = JSON.parse_string(FileAccess.get_file_as_string(CONFIG))
	GameState.current_room = &"forest_03"
	if not GameState.visited_rooms.has(&"forest_03"):
		GameState.visited_rooms.append(&"forest_03")
	$Player/Camera.set_bounds(Rect2(Vector2.ZERO,Vector2(config.bounds[0],config.bounds[1])))
	$Campfire.play(&"burn")
	for chest: Dictionary in config.chests:
		get_node(str(chest.node)).visible = not GameState.opened_chests.has(StringName(chest.id))
	_refresh_encounters(false)

func _physics_process(delta: float) -> void:
	_poll += delta
	if _poll >= float(config.encounter_poll_seconds):
		_poll = 0
		_refresh_encounters(true)

func _refresh_encounters(animate: bool) -> void:
	for encounter: Dictionary in config.encounters:
		var flag := StringName(encounter.clear_flag)
		if not GameState.opened_shortcuts.has(flag) and _encounter_cleared(str(encounter.id)):
			GameState.opened_shortcuts.append(flag)
	for gate: Dictionary in config.gates:
		get_node(str(gate.id)).set_open(GameState.opened_shortcuts.has(StringName(gate.clear_flag)),animate)
	for chest: Dictionary in config.chests:
		if not bool(chest.requires_clear):
			continue
		var seal := get_node(str(chest.node)+"/CombatSeal") as Node2D
		seal.visible = not _encounter_cleared(str(chest.encounter_id))

func _encounter_cleared(id: String) -> bool:
	for encounter: Dictionary in config.encounters:
		if str(encounter.id) != id or encounter.spawn_ids.is_empty():
			continue
		if GameState.opened_shortcuts.has(StringName(encounter.clear_flag)):
			return true
		for enemy in get_tree().get_nodes_in_group(&"enemies"):
			if str(enemy.get_meta("spawn_id","")) in encounter.spawn_ids and int(enemy.get("hp")) > 0:
				return false
		return true
	return false

## E键打开最近宝箱；空箱只记录开启，不赠送占位道具或错误消耗背包空间。
func interact_nearby() -> bool:
	var closest := {}
	var distance := float(config.interaction.range)
	for chest: Dictionary in config.chests:
		if GameState.opened_chests.has(StringName(chest.id)):
			continue
		var delta: float = $Player.position.distance_to(get_node(str(chest.node)).position)
		if delta <= distance:
			distance = delta
			closest = chest
	if closest.is_empty():
		return false
	if bool(closest.requires_clear) and not _encounter_cleared(str(closest.encounter_id)):
		GameUI.toast("需先击败附近的守箱怪物")
		return true
	if str(closest.item) != "" and int(closest.count) > 0 and not InventoryService.add_item(str(closest.item),int(closest.count)):
		GameUI.toast("行囊已满，宝箱仍保留")
		return true
	GameState.opened_chests.append(StringName(closest.id))
	get_node(str(closest.node)).hide()
	EventBus.chest_opened.emit(StringName(closest.id))
	GameUI.toast("宝箱目前是空的" if str(closest.item) == "" else "已收取宝箱物品")
	return true
