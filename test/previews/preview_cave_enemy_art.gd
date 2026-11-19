extends SceneTree
## 输出实际引擎中的原生帧检视图，不经过运行时缩放。
func _initialize() -> void:
	call_deferred("_capture")

func _capture() -> void:
	change_scene_to_file("res://test/scenes/cave_enemy_gallery.tscn")
	for tick in 8:await process_frame
	var gallery := current_scene
	var destination := "res://docs/previews/cave_enemies_v001/"
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(destination))
	for index in gallery.cfg.enemies.size():
		gallery.select_enemy(index)
		gallery.actor.pause()
		gallery.actor.frame=0
		for tick in 2:await process_frame
		await RenderingServer.frame_post_draw
		root.get_texture().get_image().save_png(ProjectSettings.globalize_path(destination+str(gallery.cfg.enemies[index].id)+".png"))
	print("CAVE ENEMY CAPTURE: 7 actual gallery renders")
	quit(0)
