extends Node2D
## 两层营地的运行配置：安全区、镜头、初始重生点和补给状态。

const CONFIG := "res://data/maps/camp_01.json"
var config: Dictionary


func _ready() -> void:
	config = JSON.parse_string(FileAccess.get_file_as_string(CONFIG))
	$Player/Camera.set_bounds(Rect2(Vector2.ZERO,Vector2(config.bounds[0],config.bounds[1])))
	GameState.current_room = &"camp_01"
	GameState.in_combat = false
	if not GameState.visited_rooms.has(&"camp_01"):
		GameState.visited_rooms.append(&"camp_01")
	if GameState.checkpoint_room == &"camp_01" and GameState.checkpoint_position.is_empty():
		GameState.checkpoint_position = config.spawn.duplicate()
		$Player.checkpoint_position = Vector2(config.spawn[0],config.spawn[1])
	$ChestA.visible = not GameState.opened_chests.has(&"camp_supplies")
	$Campfire.play(&"burn")
