extends SceneTree
## 使用实际Godot场景输出全景与近景，跳过工程HUD，仅保留游戏美术。
var cfg: Dictionary

func _initialize() -> void:
	call_deferred("_capture")

func _capture() -> void:
	cfg = JSON.parse_string(FileAccess.get_file_as_string("res://test/data/cave_material_preview.json"))
	change_scene_to_file("res://test/scenes/cave_material_preview.tscn")
	await _frames(int(cfg.light_preview_frames))
	var scene := current_scene
	scene.get_node("Player").set_physics_process(false)
	scene.get_node("Player/Camera").set_physics_process(false)
	scene.get_node("Player/Camera").position_smoothing_enabled = false
	scene.set_overview(true)
	for child in scene.get_children():
		if child is CanvasLayer and child.layer>=0: child.hide()
	await _frames(int(cfg.light_preview_frames))
	await RenderingServer.frame_post_draw
	root.get_texture().get_image().save_png(ProjectSettings.globalize_path("res://docs/previews/cave_v001/cave_panorama.png"))
	scene.set_overview(false)
	var camera := scene.get_node("Player/Camera") as Camera2D
	camera.set_physics_process(false)
	camera.position_smoothing_enabled = false
	camera.global_position = Vector2(320,540)
	camera.reset_smoothing()
	await _frames(int(cfg.light_preview_frames))
	await RenderingServer.frame_post_draw
	root.get_texture().get_image().save_png(ProjectSettings.globalize_path("res://docs/previews/cave_v001/cave_closeup.png"))
	print("CAVE CAPTURE: panorama + closeup")
	quit(0)

func _frames(count: int) -> void:
	for index in count:
		await process_frame
