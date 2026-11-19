extends SceneTree
## 离屏捕获每张原生逐帧姿势，供 ffmpeg 编码循环预览；不通过程序变形制造动作。
func _initialize() -> void:
	call_deferred("_capture")

func _capture() -> void:
	change_scene_to_file("res://test/scenes/previews/claffert_art_preview.tscn")
	for frame in 5:
		await process_frame
	var output := "res://work/claffert/capture"
	var profile: Dictionary = JSON.parse_string(FileAccess.get_file_as_string("res://data/bosses/claffert.json"))
	var preview_name := "corrumpt_pixel_idle" if profile.art.has("pixel") else "claffert_idle_v2"
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(output))
	for sprite: AnimatedSprite2D in current_scene.sprites:
		sprite.pause()
	for index in 8:
		for sprite: AnimatedSprite2D in current_scene.sprites:
			sprite.frame = index
		for frame in 2:
			await process_frame
		await RenderingServer.frame_post_draw
		var image := root.get_texture().get_image()
		image.save_png(ProjectSettings.globalize_path(output+"/%02d.png" % index))
		if index == 0:
			image.save_png(ProjectSettings.globalize_path("res://docs/previews/%s.png" % preview_name))
	print("CLAFFERT PREVIEW: 8 native poses rendered")
	quit()
