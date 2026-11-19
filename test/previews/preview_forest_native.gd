extends SceneTree
## 森林重制后实际地图全景与640×360原生近景，背景保持独立屏幕层。
func _initialize() -> void:
	call_deferred("_capture")

func _capture() -> void:
	var destination := "res://docs/previews/forest_v002/"
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(destination))
	for id in ["forest_01","forest_02","forest_03"]:
		var cfg: Dictionary = JSON.parse_string(FileAccess.get_file_as_string("res://data/maps/%s.json" % id))
		for mode in ["full","close"]:
			var viewport := SubViewport.new()
			viewport.size = Vector2i(cfg.bounds[0],cfg.bounds[1]) if mode=="full" else Vector2i(640,360)
			viewport.disable_3d = true
			viewport.render_target_update_mode=SubViewport.UPDATE_ALWAYS
			root.add_child(viewport)
			var scene := (load("res://scenes/maps/%s.tscn" % id) as PackedScene).instantiate()
			viewport.add_child(scene)
			var player := scene.get_node("Player")
			player.set_physics_process(false)
			player.get_node("Camera").enabled=false
			player.get_node("Camera").set_physics_process(false)
			for enemy in get_nodes_in_group(&"enemies"):enemy.set_physics_process(false)
			for child in scene.get_children():
				if child is CanvasLayer and child.layer>=0:child.hide()
			var camera := Camera2D.new()
			camera.position = Vector2(cfg.bounds[0],cfg.bounds[1])/2.0 if mode=="full" else player.position-Vector2(0,95)
			viewport.add_child(camera)
			for tick in 6:await process_frame
			await RenderingServer.frame_post_draw
			var error := viewport.get_texture().get_image().save_png(ProjectSettings.globalize_path(destination+id+"_"+mode+".png"))
			if error!=OK:
				quit(error)
				return
			viewport.queue_free()
			for tick in 2:await process_frame
	print("FOREST NATIVE CAPTURE: 3 full maps + 3 native closeups")
	quit(0)
