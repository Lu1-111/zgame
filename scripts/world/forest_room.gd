extends Node2D
## 草图关卡运行层：镜头边界、篝火、宝箱、捷径开关与地图预览。

@export var connection_preview := false
const CONFIG := "res://data/maps/forest_01.json"
var config: Dictionary
var _gate: StaticBody2D
var _prompt: Label
var _map: TextureRect


func _ready() -> void:
	config = JSON.parse_string(FileAccess.get_file_as_string(CONFIG))
	var room: Dictionary = config.connection_preview if connection_preview else config
	$Player/Camera.set_bounds(Rect2(Vector2.ZERO, Vector2(room.bounds[0], room.bounds[1])))
	GameState.current_room = &"forest_02" if connection_preview else &"forest_01"
	if not GameState.visited_rooms.has(GameState.current_room):
		GameState.visited_rooms.append(GameState.current_room)
	_gate = get_node_or_null("ShortcutGate") as StaticBody2D
	_prompt = $InteractionPrompt
	_apply_gate_state()
	if not connection_preview:
		$Chest.visible = not GameState.opened_chests.has(StringName(config.chest.id))
		$Campfire.play(&"burn")
	var canvas := CanvasLayer.new()
	add_child(canvas)
	if not connection_preview:
		_map = TextureRect.new()
		_map.texture = load("res://docs/previews/forest_01_layout.png")
		_map.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
		_map.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
		_map.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
		_map.mouse_filter = Control.MOUSE_FILTER_IGNORE
		_map.visible = false
		canvas.add_child(_map)


func _process(_delta: float) -> void:
	_prompt.text = ""
	var at := _nearest_interaction()
	if at == "":
		return
	if at == "Campfire":
		return
	var target: Node2D = get_node(at)
	_prompt.position = target.position + Vector2(config.interaction.prompt_offset[0], config.interaction.prompt_offset[1])
	_prompt.text = {"Campfire":"E 坐火休息", "Chest":"E 打开宝箱", "ShortcutSwitch":"E 拉动机关"}[at]


func _unhandled_input(event: InputEvent) -> void:
	if event.is_action_pressed(&"map") and _map != null:
		_map.visible = not _map.visible
	if event.is_action_pressed(&"interact"):
		interact_nearby()


## 执行最近的地图交互；返回是否成功，供物理验收与输入共同调用。
func interact_nearby() -> bool:
	match _nearest_interaction():
		"Campfire":
			return GameUI.begin_rest()
		"Chest":
			if not InventoryService.add_item(str(config.chest.item),int(config.chest.count)):
				GameUI.toast("行囊已满，宝箱仍保留")
				return true
			GameState.opened_chests.append(StringName(config.chest.id))
			$Chest.hide()
			EventBus.chest_opened.emit(StringName(config.chest.id))
			return true
		"ShortcutSwitch":
			GameState.opened_shortcuts.append(StringName(config.connection_preview.shortcut))
			_apply_gate_state()
			return true
	return false


func _nearest_interaction() -> String:
	var candidates: Array = ["ShortcutSwitch"] if connection_preview else ["Campfire", "Chest"]
	for candidate: String in candidates:
		var point := get_node_or_null(candidate) as Node2D
		if point == null or not point.visible:
			continue
		if candidate == "ShortcutSwitch" and GameState.opened_shortcuts.has(StringName(config.connection_preview.shortcut)):
			continue
		if $Player.position.distance_to(point.position) <= float(config.interaction.range):
			return candidate
	return ""


func _apply_gate_state() -> void:
	if _gate == null:
		return
	var opened := GameState.opened_shortcuts.has(StringName(config.connection_preview.shortcut))
	_gate.set_deferred("collision_layer", 0 if opened else 1)
	_gate.visible = not opened
