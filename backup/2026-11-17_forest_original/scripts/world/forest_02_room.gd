extends Node2D
## 苔甲小径运行层：独立宝箱、共用机关、初次穿越根部捷径和洞室地图。

const CONFIG := "res://data/maps/forest_02.json"
var config: Dictionary


func _ready() -> void:
	config = JSON.parse_string(FileAccess.get_file_as_string(CONFIG))
	$Player/Camera.set_bounds(Rect2(Vector2.ZERO, Vector2(config.bounds[0], config.bounds[1])))
	GameState.current_room = &"forest_02"
	if not GameState.visited_rooms.has(&"forest_02"):
		GameState.visited_rooms.append(&"forest_02")
	for chest: Dictionary in config.chests:
		get_node(str(chest.node)).visible = not GameState.opened_chests.has(StringName(chest.id))
	$Campfire.play(&"burn")
	_apply_mechanism_state()
	if config.has("shortcut_gate"):
		get_node(str(config.shortcut_gate.id)).set_open(GameState.opened_shortcuts.has(StringName(config.shortcut_gate.clear_flag)))


## 执行最近的机关或宝箱交互；战斗封印箱预留遭遇组契约，未放怪时保持封印。
func interact_nearby() -> bool:
	var candidate := _nearest_interaction()
	if candidate == "":
		return false
	if candidate == str(config.switch.node):
		var id := StringName(config.switch.id)
		if not GameState.opened_shortcuts.has(id):
			GameState.opened_shortcuts.append(id)
		_apply_mechanism_state()
		GameUI.toast("古根机关已激活 · 两处封印门已开启")
		return true
	for chest: Dictionary in config.chests:
		if str(chest.node) != candidate:
			continue
		if bool(chest.requires_clear) and not _encounter_cleared(str(chest.encounter_id)):
			GameUI.toast("此箱由战斗封印守护，需清除周围敌人")
			return true
		if not InventoryService.add_item(str(chest.item), int(chest.count)):
			GameUI.toast("行囊已满，宝箱仍保留")
			return true
		GameState.opened_chests.append(StringName(chest.id))
		get_node(candidate).hide()
		EventBus.chest_opened.emit(StringName(chest.id))
		GameUI.toast("已收取宝箱中的补给")
		return true
	return false


func _nearest_interaction() -> String:
	var nearest := ""
	var distance := float(config.interaction.range)
	var candidates: Array[String] = []
	if not GameState.opened_shortcuts.has(StringName(config.switch.id)):
		candidates.append(str(config.switch.node))
	for chest: Dictionary in config.chests:
		if not GameState.opened_chests.has(StringName(chest.id)):
			candidates.append(str(chest.node))
	for candidate in candidates:
		var node := get_node(candidate) as Node2D
		var delta: float = $Player.position.distance_to(node.position)
		if node.visible and delta <= distance:
			distance = delta
			nearest = candidate
	return nearest


func _encounter_cleared(id: String) -> bool:
	# 按草图指定的守箱遭遇组判断，不把远处普通巡逻怪计入封印。
	for encounter: Dictionary in config.encounters:
		if str(encounter.id) != id or encounter.get("spawn_ids", []).is_empty():
			continue
		for spawn_id: String in encounter.spawn_ids:
			for enemy in get_tree().get_nodes_in_group(&"enemies"):
				if str(enemy.get_meta("spawn_id", "")) == spawn_id and int(enemy.get("hp")) > 0:
					return false
		return true
	return false


func _apply_mechanism_state() -> void:
	var opened := GameState.opened_shortcuts.has(StringName(config.switch.id))
	$ShortcutSwitch.set("activated", opened)
	for definition: Dictionary in config.gates:
		var gate := get_node(str(definition.id)) as StaticBody2D
		gate.set_deferred("collision_layer", 0 if opened else 1)
		gate.visible = not opened
