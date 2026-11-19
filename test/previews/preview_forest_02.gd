extends SceneTree
## 用 Godot 实际渲染 forest_02 全图和关键洞室；隐藏窗口只生成预览，不运行游玩实例。


func _initialize() -> void:
	call_deferred("_capture")


func _capture() -> void:
	var args := OS.get_cmdline_user_args()
	var mode := args[0] if not args.is_empty() else "full"
	var config: Dictionary = JSON.parse_string(FileAccess.get_file_as_string("res://data/maps/forest_02.json"))
	var viewport := SubViewport.new()
	viewport.size = Vector2i(config.bounds[0], config.bounds[1]) if mode == "full" else Vector2i(640, 360)
	viewport.render_target_update_mode = SubViewport.UPDATE_ALWAYS
	viewport.disable_3d = true
	root.add_child(viewport)
	var scene := (load("res://scenes/maps/forest_02.tscn") as PackedScene).instantiate()
	viewport.add_child(scene)
	scene.get_node("Player").set_physics_process(false)
	scene.get_node("Player/Camera").enabled = false
	scene.get_node("Player/Camera").set_physics_process(false)
	var camera := Camera2D.new()
	viewport.add_child(camera)
	var centers := {"full": Vector2(config.bounds[0], config.bounds[1]) / 2.0, "switch": Vector2(944, 624), "hollow": Vector2(1584, 1060), "rest": Vector2(480, 1620), "gallery": Vector2(1808, 592), "cavern": Vector2(1880, 1100)}
	camera.position = centers.get(mode, centers.full)
	for frame in 5:
		await process_frame
	await RenderingServer.frame_post_draw
	var output := "res://docs/previews/forest_02_%s.png" % mode
	var error := viewport.get_texture().get_image().save_png(ProjectSettings.globalize_path(output))
	print("Godot render: %s (%dx%d), error=%d" % [output, viewport.size.x, viewport.size.y, error])
	quit(error)
