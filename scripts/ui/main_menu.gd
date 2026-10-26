extends Node2D
## 标题屏：开始新旅途、校验存档后继续，以及独立演练场入口。


func _ready() -> void:
	var root_ui := $UI/Root as Control
	var frame := RPGSkin.frame(root_ui,"title",Rect2(Vector2(10,10),get_viewport_rect().size-Vector2(20,20)))
	root_ui.move_child(frame,1)
	var theme := Theme.new()
	theme.default_font = RPGSkin.font()
	root_ui.theme = theme
	$UI/Root/Center/Title.add_theme_color_override("font_color",Color("#ded8c3"))
	$UI/Root/Center/Subtitle.add_theme_color_override("font_color",Color("#929588"))
	$UI/Root/Hint.add_theme_color_override("font_color",Color("#929588"))
	$UI/Root/Version.add_theme_color_override("font_color",Color("#6f7569"))
	root_ui.resized.connect(func() -> void: frame.size = root_ui.size-Vector2(20,20))
	var start := Button.new()
	start.text = "开始新旅途"
	start.custom_minimum_size.y = 30
	$UI/Root/Center.add_child(start)
	RPGSkin.dress_button(start)
	start.pressed.connect(_start_journey)
	if SaveSystem.has_save():
		var button := Button.new()
		button.text = "继续旅途"
		button.custom_minimum_size.y = 30
		$UI/Root/Center.add_child(button)
		RPGSkin.dress_button(button)
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
