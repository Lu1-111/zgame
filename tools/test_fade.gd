extends SceneTree
## 黑场转场测试：验证「淡出到全黑 → 切房间 → 淡回透明」的时序。
## 用法：godot --headless --path . --script res://tools/test_fade.gd

var _fails := 0


func _initialize() -> void:
	await _run()
	print("RESULT: %s" % ("PASS" if _fails == 0 else "FAIL(%d)" % _fails))
	quit(0 if _fails == 0 else 1)


func _check(cond: bool, label: String, detail: String = "") -> void:
	if cond:
		print("  ok   ", label)
	else:
		_fails += 1
		print("  FAIL ", label, "  ", detail)


func _router() -> Node:
	return root.get_node_or_null("SceneRouter")


func _run() -> void:
	var router := _router()
	if router == null:
		print("  FAIL 找不到 SceneRouter")
		_fails += 1
		return

	change_scene_to_file("res://scenes/rooms/camp_01.tscn")
	for i in 8:
		await process_frame
	_check(router.fade_alpha() < 0.05, "初始为透明", "alpha=%.2f" % router.fade_alpha())

	var ok: bool = router.goto_room(&"forest_01", &"DoorWest")
	_check(ok, "触发转场")

	var peak := 0.0
	var scene_changed_at := -1
	var frames := 0
	while frames < 6000:
		await process_frame
		frames += 1
		peak = maxf(peak, router.fade_alpha())
		if scene_changed_at < 0 and current_scene != null and current_scene.name == "Forest01":
			scene_changed_at = frames
		if not router.is_transitioning():
			break

	print("  peak_alpha=%.2f  changed_frame=%d  frames=%d  final_alpha=%.2f" % [
		peak, scene_changed_at, frames, router.fade_alpha()])
	_check(peak >= 0.95, "淡出到接近全黑", "peak=%.2f" % peak)
	_check(scene_changed_at >= 0, "切到了森林")
	_check(not router.is_transitioning(), "转场结束")
	_check(router.fade_alpha() < 0.05, "淡回透明", "alpha=%.2f" % router.fade_alpha())
