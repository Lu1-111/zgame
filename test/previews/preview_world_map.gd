extends SceneTree
## 在 Godot 中渲染真实 M 地图界面，供总览布局验收。


func _initialize() -> void:
	call_deferred("_capture")


func _capture() -> void:
	change_scene_to_file("res://scenes/maps/forest_02.tscn")
	for frame in 5:
		await process_frame
	root.get_node("GameUI").open_world_map()
	for frame in 5:
		await process_frame
	await RenderingServer.frame_post_draw
	var output := "res://docs/previews/world_map_live.png"
	var error := root.get_texture().get_image().save_png(ProjectSettings.globalize_path(output))
	print("World map render: %s, error=%d" % [output, error])
	quit(error)
