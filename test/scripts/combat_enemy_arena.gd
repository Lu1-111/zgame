extends Node2D
## 敌人战斗演练场：敌人出生即追击并攻击玩家；切换敌人时清理上一轮弹道。
const ENEMY_SCENE := preload("res://scenes/enemies/combat_enemy.tscn")
var tuning: Dictionary
var selected := 0
var enemy: CombatEnemy
var _status: Label
var _selector: OptionButton

func _ready() -> void:
	tuning = JSON.parse_string(FileAccess.get_file_as_string(CombatEnemy.CONFIG_PATH))
	var arena: Dictionary = tuning.arena
	var rectangles: Array = [arena.floor_rect]
	rectangles.append_array(arena.wall_rects)
	for rect: Array in rectangles:
		var solid := StaticBody2D.new()
		solid.collision_layer = 1
		solid.collision_mask = 0
		var shape := CollisionShape2D.new()
		var box := RectangleShape2D.new()
		box.size = Vector2(rect[2], rect[3])
		shape.shape = box
		solid.position = Vector2(rect[0], rect[1]) + box.size / 2.0
		solid.add_child(shape)
		add_child(solid)
	$Player.position = Vector2(arena.player_spawn[0], arena.player_spawn[1])
	$Player.checkpoint_position = $Player.position
	($Player/Camera as CameraRig).set_bounds(Rect2(Vector2.ZERO, Vector2(arena.room_size[0], arena.room_size[1])))
	_make_controls()
	_spawn()

func _make_controls() -> void:
	var canvas := CanvasLayer.new()
	add_child(canvas)
	var panel := VBoxContainer.new()
	canvas.add_child(panel)
	panel.position = Vector2(8, 8)
	var row := HBoxContainer.new()
	panel.add_child(row)
	_selector = OptionButton.new()
	for id: String in tuning.enemy_order:
		_selector.add_item(str(DataDB.get_enemy(StringName(id)).get("name", id)))
	_selector.item_selected.connect(func(index: int) -> void: selected = index; _spawn())
	row.add_child(_selector)
	var reset := Button.new()
	reset.text = "重置战斗 R"
	reset.pressed.connect(_spawn)
	row.add_child(reset)
	_status = Label.new()
	_status.add_theme_font_size_override("font_size", 12)
	panel.add_child(_status)
	var help := Label.new()
	help.text = "A/D移动 · 空格跳跃 · 左键攻击 · 右键防御 · Q技能 · Esc返回"
	help.add_theme_font_size_override("font_size", 10)
	panel.add_child(help)

func _spawn() -> void:
	for child: Node in get_children():
		if child is CombatEnemy or child is CombatEnemyProjectile or child is ProjectileBubble:
			remove_child(child)
			child.queue_free()
	GameState.hp = GameState.hp_max
	GameState.sta = GameState.sta_max
	GameState.mana = GameState.mana_max
	var old_player := get_node("Player")
	remove_child(old_player)
	old_player.queue_free()
	var player := preload("res://scenes/player/player.tscn").instantiate()
	player.name = "Player"
	add_child(player)
	player.position = Vector2(tuning.arena.player_spawn[0], tuning.arena.player_spawn[1])
	player.checkpoint_position = player.position
	(player.get_node("Camera") as CameraRig).set_bounds(Rect2(Vector2.ZERO, Vector2(tuning.arena.room_size[0], tuning.arena.room_size[1])))
	enemy = ENEMY_SCENE.instantiate()
	enemy.enemy_id = StringName(str(tuning.enemy_order[selected]))
	enemy.target = $Player
	var definition := DataDB.get_enemy(enemy.enemy_id)
	var spawn: Array = tuning.arena.enemy_fly_spawn if str(definition.ai.type) in ["fly", "float"] else tuning.arena.enemy_ground_spawn
	enemy.position = Vector2(spawn[0], spawn[1])
	add_child(enemy)
	$Player.position = Vector2(tuning.arena.player_spawn[0], tuning.arena.player_spawn[1])
	$Player.velocity = Vector2.ZERO

func _process(_delta: float) -> void:
	if _status == null:
		return
	_status.text = "HP %d/%d  |  %s" % [GameState.hp, GameState.hp_max, "已击败：R重置" if not is_instance_valid(enemy) else "%s  HP %d  [%s]" % [enemy.definition.get("name", ""), enemy.hp, enemy.state]]

func _unhandled_input(event: InputEvent) -> void:
	if event.is_action_pressed(&"pause"):
		SceneRouter.change_scene("res://scenes/main.tscn")
	elif event is InputEventKey and event.pressed and not event.echo and event.physical_keycode == KEY_R:
		_spawn()

func _draw() -> void:
	if tuning.is_empty():
		return
	var room: Array = tuning.arena.room_size
	var floor: Array = tuning.arena.floor_rect
	draw_rect(Rect2(Vector2.ZERO, Vector2(room[0], room[1])), Color("16241a"))
	draw_rect(Rect2(floor[0], floor[1], floor[2], floor[3]), Color("3b4a3b"))
