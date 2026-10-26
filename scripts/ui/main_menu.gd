extends Node2D
## 标题屏：开始新旅途、校验存档后继续，以及独立演练场入口。


func _ready() -> void:
	var start := Button.new()
	start.text = "开始新旅途"
	$UI/Root/Center.add_child(start)
	start.pressed.connect(_start_journey)
	if SaveSystem.has_save():
		var button := Button.new()
		button.text = "继续旅途"
		$UI/Root/Center.add_child(button)
		button.pressed.connect(func() -> void:
			if SaveSystem.load_game():
				SceneRouter.goto_room(GameState.current_room))


func _start_journey() -> void:
	GameState.reset()
	SaveSystem.restoring = false
	SceneRouter.goto_room(&"camp_01")


func _unhandled_input(event: InputEvent) -> void:
	if event is InputEventKey and event.pressed and event.physical_keycode == KEY_F2:
		SceneRouter.change_scene("res://scenes/levels/combat_enemy_arena.tscn")
	elif event is InputEventKey and event.pressed and event.physical_keycode == KEY_F3:
		SceneRouter.change_scene("res://scenes/levels/enemy_arena.tscn")
	elif event.is_action_pressed(&"pause"):
		get_tree().quit()
	elif event.is_action_pressed(&"attack") \
			or event.is_action_pressed(&"jump") \
			or event.is_action_pressed(&"ui_accept"):
		_start_journey()
