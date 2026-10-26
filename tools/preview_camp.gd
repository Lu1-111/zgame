extends SceneTree
## 通过 Godot 实际渲染营地全图、下层与上层实机视口。

func _initialize() -> void:
	call_deferred("_capture")


func _capture() -> void:
	var args := OS.get_cmdline_user_args()
	var mode := str(args[0]) if args.size() else "full"
	var error := OK
	if mode == "full":
		var viewport := SubViewport.new()
		viewport.size = Vector2i(1280,640)
		viewport.disable_3d = true
		viewport.render_target_update_mode = SubViewport.UPDATE_ALWAYS
		root.add_child(viewport)
		var room := (load("res://scenes/rooms/camp_01.tscn") as PackedScene).instantiate()
		viewport.add_child(room)
		room.get_node("Player").set_physics_process(false)
		room.get_node("Player/Camera").enabled = false
		room.get_node("Player/Camera").set_physics_process(false)
		var camera := Camera2D.new()
		viewport.add_child(camera)
		camera.position = Vector2(640,320)
		for frame in 16:
			await process_frame
		await RenderingServer.frame_post_draw
		error = viewport.get_texture().get_image().save_png(ProjectSettings.globalize_path("res://docs/previews/camp_01_full.png"))
	else:
		change_scene_to_file("res://scenes/rooms/camp_01.tscn")
		for frame in 8:
			await physics_frame
		root.size = Vector2i(1280,720)
		var actor := current_scene.get_node("Player") as CharacterBody2D
		actor.position = Vector2(1000,239) if mode == "trade" else Vector2(384,527)
		actor.velocity = Vector2.ZERO
		actor.cam.position = Vector2.ZERO
		for frame in 70:
			await physics_frame
		if mode == "rest":
			root.get_node("GameUI").begin_rest()
			for frame in 60:
				await process_frame
		await RenderingServer.frame_post_draw
		error = root.get_texture().get_image().save_png(ProjectSettings.globalize_path("res://docs/previews/camp_01_%s.png" % mode))
	print("Camp render: %s, error=%d" % [mode,error])
	quit(error)
