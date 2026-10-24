extends SceneTree
## 加载场景并截图。
## 用法：godot --path . --script res://tools/shot.gd -- <scene> <out.png> [宽 高]
## 给了宽高就用离屏 SubViewport 渲染整张（可大于窗口）。

func _initialize() -> void:
	var args := OS.get_cmdline_user_args()
	var scene_path: String = args[0] if args.size() > 0 else "res://scenes/rooms/camp_01.tscn"
	var out_path: String = args[1] if args.size() > 1 else "res://.tmp_shot.png"
	var wanted := Vector2i(int(args[2]), int(args[3])) if args.size() > 3 else Vector2i.ZERO

	var packed: PackedScene = load(scene_path)
	var inst := packed.instantiate()

	var holder: Node = root
	if wanted != Vector2i.ZERO:
		var vp := SubViewport.new()
		vp.size = wanted
		vp.render_target_update_mode = SubViewport.UPDATE_ALWAYS
		vp.disable_3d = true
		vp.transparent_bg = false
		root.add_child(vp)
		holder = vp

	holder.add_child(inst)

	# 可选：把玩家挪到指定 x，用于验证遮挡关系  args[4] = player_x
	if args.size() > 4:
		var player := inst.get_node_or_null("Player")
		if player != null:
			player.position.x = float(args[4])
			player.set_physics_process(false)
			player.set_meta("moved_for_shot", true)

	var cam := _find_camera(inst)
	if cam and wanted != Vector2i.ZERO:
		cam.set_physics_process(false)          # 关掉跟随，避免与截图机位打架
		cam.position = Vector2(wanted) * 0.5
		cam.limit_left = int(cam.position.x - wanted.x * 0.5)
		cam.limit_right = int(cam.position.x + wanted.x * 0.5)
		cam.limit_top = int(cam.position.y - wanted.y * 0.5)
		cam.limit_bottom = int(cam.position.y + wanted.y * 0.5)

	for i in 5:
		await process_frame
	await RenderingServer.frame_post_draw

	var target: Viewport = holder as Viewport if holder is Viewport else root
	var img := target.get_texture().get_image()
	var abs_path := ProjectSettings.globalize_path(out_path)
	var err := img.save_png(abs_path)
	print("shot: %s (%dx%d) err=%d" % [abs_path, img.get_width(), img.get_height(), err])
	quit()


func _find_camera(n: Node) -> Camera2D:
	if n is Camera2D:
		return n
	for c in n.get_children():
		var found := _find_camera(c)
		if found:
			return found
	return null
