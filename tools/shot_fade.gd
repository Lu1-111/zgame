extends SceneTree
## 截取转场过程：全黑帧 + 落点帧，用于验证黑场效果。
## 用法：godot --path . --script res://tools/shot_fade.gd

func _initialize() -> void:
	change_scene_to_file("res://scenes/rooms/camp_01.tscn")
	for i in 10:
		await process_frame

	var router := root.get_node_or_null("SceneRouter")
	if router == null:
		print("no router")
		quit(1)
		return

	router.goto_room(&"forest_01", &"DoorWest")

	# 等到最黑的一帧
	var frames := 0
	while frames < 600:
		await process_frame
		frames += 1
		if router.fade_alpha() >= 0.98:
			break
	await RenderingServer.frame_post_draw
	var black := root.get_texture().get_image()
	black.save_png(ProjectSettings.globalize_path("res://fade_black.png"))
	print("black frame at %d, alpha=%.2f" % [frames, router.fade_alpha()])

	# 等转场结束
	frames = 0
	while router.is_transitioning() and frames < 600:
		await process_frame
		frames += 1
	for i in 6:
		await process_frame
	await RenderingServer.frame_post_draw
	var after := root.get_texture().get_image()
	after.save_png(ProjectSettings.globalize_path("res://fade_after.png"))
	print("after: scene=%s alpha=%.2f" % [current_scene.name, router.fade_alpha()])
	quit()
