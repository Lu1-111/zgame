extends SceneTree
## 固定帧率的离屏短预览：原闲置与原像素骨骼动作同倍率对照，渲染后自行退出。
func _initialize() -> void:
	call_deferred("_capture")


func _capture() -> void:
	var viewport := SubViewport.new()
	viewport.size = Vector2i(512,576)
	viewport.transparent_bg = true
	viewport.render_target_update_mode = SubViewport.UPDATE_ALWAYS
	root.add_child(viewport)
	var bg := ColorRect.new()
	bg.color = Color("#142528")
	bg.size = Vector2(512,576)
	viewport.add_child(bg)
	var original := Sprite2D.new()
	original.texture = load("res://assets/PROCESSED/characters/CHR-01/v001/frames/CHR-01_player_idle_right_v001_f01.png")
	original.centered = false
	original.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	viewport.add_child(original)
	for combo in 3:
		for frame in 8:
			var rig: Node2D = load("res://scripts/player/pixel_hero_rig.gd").new()
			rig.position = Vector2(frame*64+32,64+combo*64+58)
			viewport.add_child(rig)
			rig.combo = combo+1
			rig.progress = float(frame)/7
			rig.apply_pose()
	for row in 5:
		for frame in 8:
			var rig: Node2D = load("res://scripts/player/pixel_hero_rig.gd").new()
			rig.position = Vector2(frame*64+32,256+row*64+58)
			viewport.add_child(rig)
			rig.kind = "bow"
			rig.aim = Vector2.from_angle(deg_to_rad(float(row-2)*45))
			rig.charge = minf(float(frame)/4,1)
			rig.release_time = -1.0 if frame < 5 else float(frame-5)*0.1
			rig.apply_pose()
	for frame in 4:
		await process_frame
	await RenderingServer.frame_post_draw
	var image := viewport.get_texture().get_image()
	image.resize(1536,1728,Image.INTERPOLATE_NEAREST)
	var error := image.save_png(ProjectSettings.globalize_path("res://docs/previews/hero_fullframe_v4.png"))
	bg.hide()
	await process_frame
	await RenderingServer.frame_post_draw
	image = viewport.get_texture().get_image()
	var destination := "res://assets/PROCESSED/characters/CHR-01/rpg_v4/"
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(destination))
	for combo in 3:
		for frame in 8:
			image.get_region(Rect2i(frame*64,64+combo*64,64,64)).save_png(ProjectSettings.globalize_path(destination+"sword_%d_%02d.png" % [combo+1,frame]))
	for row in 5:
		for frame in 8:
			image.get_region(Rect2i(frame*64,256+row*64,64,64)).save_png(ProjectSettings.globalize_path(destination+"bow_%d_%02d.png" % [row,frame]))
	print("Rig contact sheet: error=%d" % error)
	quit(error)
