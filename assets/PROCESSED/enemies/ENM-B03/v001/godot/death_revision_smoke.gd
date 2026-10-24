extends SceneTree
const SCENE = preload("EnemyPresentation.tscn")
var issues: Array[String] = []
var completed: Array[StringName] = []
func _initialize() -> void:
	call_deferred("_run")
func _run() -> void:
	var actor: Node2D = SCENE.instantiate()
	root.add_child(actor)
	await process_frame
	actor.action_completed.connect(func(action: StringName) -> void: completed.append(action))
	for enemy: String in ["ENM-01", "ENM-09", "ENM-10"]:
		if not actor.select_enemy(enemy) or not actor.play_action(&"death", true, 100.0):
			issues.append(enemy + " selection/play")
		if actor.body.sprite_frames.get_frame_count(&"death") != 8:
			issues.append(enemy + " death count")
		var paths: Dictionary = {}
		for index: int in range(8):
			var texture: Texture2D = actor.body.sprite_frames.get_frame_texture(&"death", index)
			if texture == null:
				issues.append(enemy + " missing texture")
			else:
				paths[texture.resource_path] = true
		if paths.size() != 8:
			issues.append(enemy + " texture identity")
		if actor.body.offset != -Vector2(actor.current.anchor[0], actor.current.anchor[1]) or actor.root.scale.x != -1.0:
			issues.append(enemy + " root/mirror")
		var old_count: int = completed.size()
		await create_timer(0.08).timeout
		if completed.size() != old_count + 1 or completed.back() != &"death":
			issues.append(enemy + " completion")
		if actor.body.modulate.a > 0.01:
			issues.append(enemy + " final opacity")
	var file := FileAccess.open("res://qa/death-revision-smoke.json", FileAccess.WRITE)
	file.store_string(JSON.stringify({"enemies": 3, "deathFramesEach": 8, "issues": issues}, "  "))
	quit(0 if issues.is_empty() else 1)
