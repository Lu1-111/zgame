extends Node2D
const PRESENTATION = preload("EnemyPresentation.tscn")
const CATALOG = preload("Catalog.gd")
var actors: Array[Node2D] = []
var selected_action: StringName = &"idle"

func _ready() -> void:
	RenderingServer.set_default_clear_color(Color("202631"))
	var seen: Dictionary = {}
	for entry: Dictionary in CATALOG.ENTRIES:
		if entry.kind != "body" or seen.has(entry.enemyId):
			continue
		seen[entry.enemyId] = true
		var actor: Node2D = PRESENTATION.instantiate()
		actor.enemy_id = entry.enemyId
		var bounds: Rect2 = Rect2()
		var first_bound: bool = true
		for item: Dictionary in CATALOG.ENTRIES:
			if item.enemyId != entry.enemyId:
				continue
			var shift: Array = item.get("triggerOffset", [0, 0]) if item.kind == "effect" else [0, 0]
			var rect := Rect2(Vector2(shift[0] - item.anchor[0], shift[1] - item.anchor[1]), Vector2(item.target[0], item.target[1]))
			bounds = rect if first_bound else bounds.merge(rect)
			first_bound = false
		var display_scale: float = minf(3.0, minf(300.0 / bounds.size.x, 260.0 / bounds.size.y))
		actor.position = Vector2(175 + (actors.size() % 3) * 350 - bounds.get_center().x * display_scale, 50 + floorf(actors.size() / 3.0) * 330 - bounds.position.y * display_scale)
		actor.scale = Vector2(display_scale, display_scale)
		add_child(actor)
		actors.append(actor)
		var label := Label.new()
		label.text = entry.enemyId + " / " + entry.gameEnemyId
		label.position = Vector2(70 + (actors.size() - 1) % 3 * 350, 315 + floorf((actors.size() - 1) / 3.0) * 330)
		add_child(label)
	var bar := HBoxContainer.new()
	add_child(bar)
	for action: String in ["idle", "move", "telegraph", "attack", "recover", "hurt", "death", "combo"]:
		var button := Button.new()
		button.text = action
		button.pressed.connect(_play_all.bind(action))
		bar.add_child(button)
	var mirror := Button.new()
	mirror.text = "镜像"
	mirror.pressed.connect(func() -> void:
		for actor: Node2D in actors:
			actor.play_action(selected_action, not actor.facing_left)
	)
	bar.add_child(mirror)

func _play_all(action: String) -> void:
	selected_action = StringName("telegraph" if action == "combo" else action)
	for actor: Node2D in actors:
		if actor.action_completed.is_connected(_chain.bind(actor)):
			actor.action_completed.disconnect(_chain.bind(actor))
		if action == "combo":
			actor.action_completed.connect(_chain.bind(actor))
		actor.play_action(selected_action, actor.facing_left)

func _chain(action: StringName, actor: Node2D) -> void:
	if action == &"telegraph":
		actor.play_action(&"attack", actor.facing_left)
	elif action == &"attack":
		actor.play_action(&"recover", actor.facing_left)
	elif action == &"recover":
		actor.play_action(&"idle", actor.facing_left)
