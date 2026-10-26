extends SceneTree
## 通过 Godot 渲染全图或游戏视口截图；不依赖系统截图工具。
## 用法：Godot --path . --script res://tools/preview_forest_sketch.gd -- [full|roots|rest|crown]

func _initialize() -> void:
	call_deferred("_capture")


func _capture() -> void:
	var args := OS.get_cmdline_user_args()
	var mode := args[0] if not args.is_empty() else "full"
	var config: Dictionary = JSON.parse_string(FileAccess.get_file_as_string("res://data/maps/forest_01.json"))
	var viewport := SubViewport.new()
	viewport.size = Vector2i(config.bounds[0], config.bounds[1]) if mode == "full" else (Vector2i(640,448) if mode == "encounters" else Vector2i(640,360))
	viewport.render_target_update_mode = SubViewport.UPDATE_ALWAYS
	viewport.disable_3d = true
	root.add_child(viewport)
	var scene := (load("res://scenes/rooms/forest_01.tscn") as PackedScene).instantiate()
	viewport.add_child(scene)
	scene.get_node("Player").set_physics_process(false)
	scene.get_node("Player/Camera").enabled = false
	scene.get_node("Player/Camera").set_physics_process(false)
	for child in scene.get_children():
		if child is CharacterBody2D and child.has_meta("spawn_id"):
			child.set_physics_process(false)
	for child in scene.get_children():
		if child is CanvasLayer:
			child.hide()
	var camera := Camera2D.new()
	viewport.add_child(camera)
	var centers := {"full": Vector2(config.bounds[0], config.bounds[1]) / 2, "roots": Vector2(640, 1676), "rest": Vector2(960, 600), "crown": Vector2(640, 280), "encounters": Vector2(640,1000)}
	camera.position = centers[mode]
	if mode == "rest":
		scene.get_node("Player").position = Vector2(1040, 655)
	for frame in 8:
		await process_frame
	await RenderingServer.frame_post_draw
	var output := "res://docs/previews/forest_01_%s.png" % mode
	var error := viewport.get_texture().get_image().save_png(ProjectSettings.globalize_path(output))
	print("Godot render: %s (%dx%d), error=%d" % [output, viewport.size.x, viewport.size.y, error])
	quit(error)
