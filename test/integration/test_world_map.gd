extends SceneTree
## 从四张实际房间发送 M/Esc 输入，检查连通总览、暂停生命周期和实时角色位置。

var failures := 0


func _initialize() -> void:
	call_deferred("_run")


func _run() -> void:
	root.get_node("GameState").reset()
	var ui := root.get_node("GameUI")
	for room in ["camp_01", "forest_01", "forest_02", "forest_03"]:
		change_scene_to_file("res://scenes/maps/%s.tscn" % room)
		for frame in 5:
			await process_frame
		await _press("map")
		_expect(ui.mode == "map" and paused, "%s M opens the world map with a balanced pause" % room)
		if ui.mode != "map":
			quit(1)
			return
		if not ui.modal.has_node("WorldMapView"):
			_expect(false, "world map control is present")
			ui._force_close()
			quit(1)
			return
		var view := ui.modal.get_node("WorldMapView") as WorldMapView
		var actor := current_scene.get_node("Player") as Node2D
		var point := view.player_map_position()
		_expect(point == view.project_room_position(room, actor.position), "%s marker uses the actual actor position" % room)
		var origin := actor.position
		var movement := Vector2(80, -24)
		actor.position += movement
		for frame in 3:
			await process_frame
		_expect(view.player_map_position() - point == movement, "%s marker updates while the map stays open" % room)
		actor.position = origin
		var wheel := InputEventMouseButton.new()
		wheel.button_index = MOUSE_BUTTON_WHEEL_UP
		wheel.pressed = true
		wheel.position = Vector2(200, 100)
		view.handle_map_pointer(wheel)
		_expect(float(view.get("_zoom")) > 1.0, "%s wheel zoom works" % room)
		view.reset_view()
		_expect(float(view.get("_zoom")) == 1.0, "%s overview reset restores full extent" % room)
		await _press("pause")
		_expect(ui.mode == "" and not paused and ui.modal == null, "%s Esc closes the map without opening pause menu" % room)
		await _press("map")
		await _press("map")
		_expect(ui.mode == "" and not paused, "%s M toggles closed without leaving pause behind" % room)
	print("WORLD MAP INTEGRATION: %d failures" % failures)
	quit(1 if failures else 0)


func _press(action: String) -> void:
	var event := InputEventAction.new()
	event.action = StringName(action)
	event.pressed = true
	Input.parse_input_event(event)
	await process_frame
	event = InputEventAction.new()
	event.action = StringName(action)
	event.pressed = false
	Input.parse_input_event(event)
	await process_frame


func _expect(ok: bool, label: String) -> void:
	print("%s: %s" % ["PASS" if ok else "FAIL", label])
	if not ok:
		failures += 1
