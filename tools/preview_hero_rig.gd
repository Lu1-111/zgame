extends SceneTree
## 单个限帧离屏进程导出原生密度动作。96画布仅增加武器留白，人物不缩放。
func _initialize() -> void:
	call_deferred("_capture")

func _capture() -> void:
	var viewport := SubViewport.new()
	viewport.size = Vector2i(768,960)
	viewport.transparent_bg = true
	viewport.render_target_update_mode = SubViewport.UPDATE_ALWAYS
	root.add_child(viewport)
	var bg := ColorRect.new()
	bg.color = Color("#22241f")
	bg.size = Vector2(viewport.size)
	viewport.add_child(bg)
	var original := Sprite2D.new()
	original.texture = load("res://assets/PROCESSED/characters/CHR-01/v001/frames/CHR-01_player_idle_right_v001_f01.png")
	original.centered = false
	original.position = Vector2(16,26)
	original.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	viewport.add_child(original)
	for combo in 3:
		for frame in 8:
			var rig: Node2D = load("res://scripts/player/pixel_hero_rig.gd").new()
			rig.position = Vector2(frame*96+48,96+combo*96+84)
			viewport.add_child(rig)
			rig.combo = combo+1
			rig.progress = float(frame)/7
			rig.apply_pose()
	for row in 5:
		for frame in 8:
			var rig: Node2D = load("res://scripts/player/pixel_hero_rig.gd").new()
			rig.position = Vector2(frame*96+48,384+row*96+84)
			viewport.add_child(rig)
			rig.kind = "rifle"
			rig.aim = Vector2.from_angle(deg_to_rad(float(row-2)*45))
			rig.release_time = -1.0 if frame < 3 else float(frame-3)*0.06
			rig.apply_pose()
	for index in 8:
		var frame: int = [0,1,2,2,2,1,0,3][index]
		var guard := Sprite2D.new()
		guard.texture = load("res://assets/PROCESSED/characters/CHR-01/v001/frames/CHR-01_player_guard_right_v001_f%02d.png" % (frame+1))
		guard.position = Vector2(index*96+16,890)
		guard.centered = false
		guard.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
		viewport.add_child(guard)
	for frame in 4:
		await process_frame
	await RenderingServer.frame_post_draw
	var screenshot := viewport.get_texture().get_image()
	screenshot.resize(1536,1920,Image.INTERPOLATE_NEAREST)
	var error := screenshot.save_png(ProjectSettings.globalize_path("res://docs/previews/hero_sword_rifle_v6.png"))
	bg.hide()
	await process_frame
	await RenderingServer.frame_post_draw
	var sheet := viewport.get_texture().get_image()
	var destination := "res://assets/PROCESSED/characters/CHR-01/rpg_v6/"
	for combo in 3:
		for frame in 8:
			sheet.get_region(Rect2i(frame*96,96+combo*96,96,96)).save_png(ProjectSettings.globalize_path(destination+"sword_%d_%02d.png" % [combo+1,frame]))
	for row in 5:
		for frame in 8:
			sheet.get_region(Rect2i(frame*96,384+row*96,96,96)).save_png(ProjectSettings.globalize_path(destination+"rifle_%d_%02d.png" % [row,frame]))
	print("Sword/rifle/guard preview: %d" % error)
	quit(error)
