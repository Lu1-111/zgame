extends SceneTree
## 营地冒烟测试：加载 camp_01，模拟输入，验证玩家能移动、落地、摄像机跟随。
## 用法：godot --headless --path . --script res://tools/test_camp_player.gd

var _player: CharacterBody2D
var _camera: Camera2D
var _start_x := 0.0
var _start_cam_x := 0.0
var _frames := 0


func _initialize() -> void:
	var packed: PackedScene = load("res://scenes/rooms/camp_01.tscn")
	var room := packed.instantiate()
	root.add_child(room)
	_player = room.get_node_or_null("Player")
	_camera = room.get_node_or_null("Player/Camera")
	if _player == null:
		push_error("FAIL: 场景里没有 Player")
		quit(1)
		return

	for i in 30:                                   # 先落稳
		await physics_frame
	_start_x = _player.global_position.x
	_start_cam_x = _camera.global_position.x
	Input.action_press("move_right")
	for i in 90:                                   # 向右走 1.5 秒
		await physics_frame
	Input.action_release("move_right")
	for i in 30:
		await physics_frame

	var dx := _player.global_position.x - _start_x
	var dcx := _camera.global_position.x - _start_cam_x
	var y := _player.global_position.y
	print("player_dx=%.1f  camera_dx=%.1f  player_y=%.1f  on_floor=%s" % [
		dx, dcx, y, str(_player.is_on_floor())])
	# 玩家原点在身体中心（脚底 = y + 17），地面 304 → 静止时 y ≈ 287
	var ok := dx > 40.0 and dcx > 20.0 and y > 275.0 and y < 315.0 and _player.is_on_floor()
	print("RESULT: %s" % ("PASS" if ok else "FAIL"))
	quit(0 if ok else 1)
