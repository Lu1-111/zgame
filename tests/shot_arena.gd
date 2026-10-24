extends Node2D
## 视觉验收工具（QA）：窗口模式运行，加载试玩场后分三拍抓图（待机/空中跳/普攻判定窗），
## 保存 /tmp/shot_idle.png、/tmp/shot_jump.png、/tmp/shot_attack.png 后自动退出。
## 运行：~/.local/bin/godot --path . res://tests/shot_arena.tscn

## 攻击抓拍：鼠标移到屏幕右侧（朝假人方向）→ 按住左键普攻 → 轮询 attack_phase，
## 进入判定窗（"active"，特效实体已生成）后稍等 2 帧让挥击动画展开，抓图存盘。
const ATTACK_PHASE_WAIT_MAX := 60    ## 等待进入判定窗的物理帧上限（防死等）
const ATTACK_SHOT_DELAY := 2         ## 进入判定窗后再等的物理帧数（挥击动画前段）
const MOUSE_WINDOW_TARGET := Vector2(1000.0, 400.0)  ## 窗口坐标（视口 640×360 ×2 拉伸 → 右侧偏上）


func _ready() -> void:
	var arena: Node = (load("res://scenes/levels/test_arena.tscn") as PackedScene).instantiate()
	add_child(arena)
	await _frames(40)
	await _shot("/tmp/shot_idle.png")
	Input.action_press(&"jump")
	await _frames(8)
	Input.action_release(&"jump")
	await _frames(2)
	await _shot("/tmp/shot_jump.png")

	# ---- M1.5 攻击抓拍：鼠标瞄准右侧 → 左键普攻 → 判定窗内抓图 ----
	Input.warp_mouse(MOUSE_WINDOW_TARGET)
	await _frames(5)  # 等鼠标位置生效（摄像机/朝向稳定）
	var player: Node = arena.get_node("Player")
	Input.action_press(&"attack")   # 左键（attack 映射鼠标左键），按住保持到抓拍后
	for i in ATTACK_PHASE_WAIT_MAX:
		await get_tree().physics_frame
		if String(player.attack_phase) == &"active":
			break
	await _frames(ATTACK_SHOT_DELAY)
	# 目视验收辅助：判定窗内应存在 AttackEffect 特效实体（近战判定已实体化；
	# spawn 父节点 = get_tree().current_scene = 本工具根节点，故扫描本节点的子级）
	var fx_count := 0
	for child in get_children():
		if child is AttackEffect:
			fx_count += 1
	print("判定窗内 AttackEffect 实体数：", fx_count)
	await _shot("/tmp/shot_attack.png")
	Input.action_release(&"attack")
	await _frames(40)  # 等特效实体（最长 0.5s 动画）播完

	# ---- 平台探针：传送正下方起跳，逐帧打印（诊断实机穿平台）----
	var plat: Node2D = arena.get_node("Player")
	plat.global_position = Vector2(270, 663)   # 平台 [180,560,180,14] 正下方
	plat.velocity = Vector2.ZERO
	await _frames(5)
	print("[PROBE] 起点 y=%.1f mask=%d" % [plat.global_position.y, plat.collision_mask])
	Input.action_press(&"jump")
	for i in 30:
		await get_tree().physics_frame
		if i % 5 == 0:
			print("[PROBE] f%02d y=%.1f vy=%.1f mask=%d state=%s floor=%s" % [i,
					plat.global_position.y, plat.velocity.y, plat.collision_mask,
					String(plat.sm.current_name()), plat.is_on_floor()])
	Input.action_release(&"jump")
	await _frames(40)
	print("[PROBE] 终点 y=%.1f floor=%s（登上平台=543 / 落回地面=663）" % [plat.global_position.y, plat.is_on_floor()])
	get_tree().quit(0)


func _shot(path: String) -> void:
	await RenderingServer.frame_post_draw
	get_viewport().get_texture().get_image().save_png(path)
	print("已保存截图：", path)


func _frames(n: int) -> void:
	for i in n:
		await get_tree().process_frame
