extends SceneTree
const PRESENTATION = preload("EnemyPresentation.tscn")
const CATALOG = preload("Catalog.gd")
var problems: Array[String] = []

func _initialize() -> void:
	call_deferred("_run")

func _run() -> void:
	for entry: Dictionary in CATALOG.ENTRIES:
		var resource_name: String = entry.enemyId if entry.kind == "body" else entry.id
		var frames: SpriteFrames = load(get_script().resource_path.get_base_dir().path_join(resource_name + ".tres"))
		if frames == null or not frames.has_animation(entry.name):
			problems.append("resource " + entry.id)
		elif frames.get_frame_count(entry.name) != entry.frameCount:
			problems.append("frame count " + entry.id)
	var actor: Node2D = PRESENTATION.instantiate()
	root.add_child(actor)
	await process_frame
	var completions: Array = []
	actor.action_completed.connect(func(action: StringName) -> void: completions.append(action))
	for entry: Dictionary in CATALOG.ENTRIES:
		if entry.kind != "body":
			continue
		if not actor.select_enemy(entry.gameEnemyId):
			problems.append("select " + entry.id)
		if not actor.play_action(StringName(entry.name), true, 100.0):
			problems.append("play " + entry.id)
		if actor.body.offset != -Vector2(entry.anchor[0], entry.anchor[1]) or actor.root.scale.x != -1.0:
			problems.append("anchor/mirror " + entry.id)
		actor.body.set_frame_and_progress(1, 0.5)
		actor.play_action(StringName(entry.name), true, 100.0)
		if actor.body.frame != 0:
			problems.append("replay " + entry.id)
		if not entry.loop:
			var old: int = completions.size()
			await create_timer(0.05).timeout
			if completions.size() <= old:
				problems.append("completion " + entry.id)
		if entry.name == "death":
			actor.play_action(&"death")
			actor.body.pause()
			actor.body.set_frame_and_progress(entry.frameCount - 1, 0.99)
			actor._process(0.0)
			if actor.body.modulate.a > 0.02:
				problems.append("death fade " + entry.id)
		if entry.name == "attack":
			for fx_entry: Dictionary in CATALOG.ENTRIES:
				if fx_entry.kind == "effect" and fx_entry.enemyId == entry.enemyId:
					actor.play_action(&"attack")
					if not actor.fx.visible or actor.fx.frame != 0:
						problems.append("FX sync " + entry.id)
					if actor.fx.offset != -Vector2(fx_entry.anchor[0], fx_entry.anchor[1]):
						problems.append("FX anchor " + entry.id)
					var offset: Array = fx_entry.get("triggerOffset", [0, 0])
					if actor.fx.position != Vector2(offset[0], offset[1]):
						problems.append("FX attach offset " + entry.id)
					actor.fx.pause()
					actor.fx.set_frame_and_progress(fx_entry.frameCount - 1, 0.99)
					actor._process(0.0)
					if actor.fx.modulate.a > 0.02:
						problems.append("FX fade " + entry.id)
	var seen_enemies: Dictionary = {}
	for entry: Dictionary in CATALOG.ENTRIES:
		if entry.kind != "body" or seen_enemies.has(entry.enemyId):
			continue
		seen_enemies[entry.enemyId] = true
		actor.select_enemy(entry.enemyId)
		if not actor.play_action(&"attack"):
			problems.append("chain attack missing " + entry.enemyId)
			continue
		var attack_duration: float = float(actor.current.frameCount) / float(actor.current.fps)
		await create_timer(attack_duration + 0.03).timeout
		var fx_was_visible: bool = actor.fx.visible
		actor.play_action(&"recover")
		if fx_was_visible:
			if not actor.fx.visible:
				problems.append("recover truncated FX " + entry.enemyId)
			await create_timer(0.6).timeout
			if actor.fx.visible:
				problems.append("FX natural finish " + entry.enemyId)
	actor.play_action(&"missing_action")
	if actor.current.get("name") != "idle":
		problems.append("fallback")
	var report := {"issues": problems, "entries": CATALOG.ENTRIES.size()}
	var file := FileAccess.open("res://smoke-report.json", FileAccess.WRITE)
	file.store_string(JSON.stringify(report, "  "))
	quit(0 if problems.is_empty() else 1)
