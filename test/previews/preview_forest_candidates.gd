extends SceneTree
## 隐藏窗口实际渲染十个场景；全图取独立SubViewport，另保存正常游戏画面和选图入口。
var _manifest: Dictionary
var _rules: Dictionary

func _initialize() -> void:
	call_deferred("_capture")

func _capture() -> void:
	_manifest = JSON.parse_string(FileAccess.get_file_as_string("res://test/data/forest_candidates/manifest.json"))
	_rules = JSON.parse_string(FileAccess.get_file_as_string("res://test/data/forest_candidates_rules.json"))
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path("res://test/previews/forest_candidates"))
	for row: Dictionary in _manifest.candidates:
		var viewport := SubViewport.new()
		viewport.size = Vector2i(int(_rules.bounds[0])/2,int(_rules.bounds[1])/2)
		viewport.render_target_update_mode = SubViewport.UPDATE_ALWAYS
		viewport.disable_3d = true
		root.add_child(viewport)
		var scene := (load(str(row.scene)) as PackedScene).instantiate()
		viewport.add_child(scene)
		scene.set_physics_process(false)
		scene.get_node("Player").set_physics_process(false)
		scene.get_node("Player/Camera").enabled = false
		scene.get_node("Player/Camera").set_physics_process(false)
		for enemy in get_nodes_in_group(&"enemies"):
			enemy.set_physics_process(false)
		var camera := Camera2D.new()
		camera.position = Vector2(_rules.bounds[0],_rules.bounds[1])/2
		camera.zoom = Vector2.ONE/2
		viewport.add_child(camera)
		await _frames(int(_rules.physics_test.screenshot_frames))
		await RenderingServer.frame_post_draw
		var output := "res://test/previews/forest_candidates/%s_full.png" % row.id
		var error := viewport.get_texture().get_image().save_png(ProjectSettings.globalize_path(output))
		if error != OK:
			quit(error)
			return
		print("CAPTURE "+str(row.id))
		viewport.queue_free()
		await _frames(2)
	change_scene_to_file("res://test/scenes/forest_candidates/forest_05A.tscn")
	await _frames(int(_rules.physics_test.screenshot_frames))
	await RenderingServer.frame_post_draw
	root.get_texture().get_image().save_png(ProjectSettings.globalize_path("res://test/previews/forest_candidates/play_05A.png"))
	change_scene_to_file("res://test/scenes/forest_candidates.tscn")
	await _frames(int(_rules.physics_test.screenshot_frames))
	await RenderingServer.frame_post_draw
	root.get_texture().get_image().save_png(ProjectSettings.globalize_path("res://test/previews/forest_candidates/gallery.png"))
	quit(0)

func _frames(count: int) -> void:
	for index in count:
		await process_frame
