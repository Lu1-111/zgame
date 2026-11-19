extends SceneTree
## 真实角色回归：逐段单跳、单向平台上穿下穿、斜坡、机关与宝箱、两层通道及存档。

var config: Dictionary
var player: CharacterBody2D
var failures := 0
var surfaces := {}
const HALF := 17.0


func _initialize() -> void:
	call_deferred("_run")


func _run() -> void:
	config = JSON.parse_string(FileAccess.get_file_as_string("res://data/maps/forest_02.json"))
	root.get_node("GameState").reset()
	change_scene_to_file("res://scenes/maps/forest_01.tscn")
	await process_frame
	await process_frame
	player = current_scene.get_node("Player")
	for child in current_scene.get_children():
		if child is CharacterBody2D and child.has_meta("spawn_id"):
			child.set_physics_process(false)
	await _frames(40)
	await _place(Vector2(1120, 1807))
	Input.action_press("move_right")
	await _frames(50)
	_release()
	_expect(current_scene.name == &"Forest01" and player.position.x < 1168, "forest_01 lower shortcut remains physically blocked before first crossing")
	await _place(Vector2(1228, 655))
	Input.action_press("move_right")
	await _frames(90)
	_release()
	_expect(current_scene.name == &"Forest02", "forest_01 upper exit enters the new forest_02")
	if current_scene.name != &"Forest02":
		quit(1)
		return
	player = current_scene.get_node("Player")
	await _frames(20)
	# 路线回归只测地形；怪物接触和战斗单独由 test_fixes_1030 覆盖。
	for enemy in get_nodes_in_group("enemies"):
		enemy.set_physics_process(false)
		enemy.collision_layer = 0
	_expect(absf(player.position.y + HALF - float(config.spawn[1]) - HALF) < 2, "upper arrival stands on the actual wall floor")
	var gs := root.get_node("GameState")
	_expect(not gs.opened_shortcuts.has(&"forest_01_roots"), "upper route does not unlock the lower shortcut")
	var map_event := InputEventAction.new()
	map_event.action = &"map"
	map_event.pressed = true
	var map_ui := root.get_node("GameUI")
	map_ui._input(map_event)
	await process_frame
	var map_view := map_ui.modal.get_node("WorldMapView") as Control
	_expect(map_ui.mode == "map" and map_view.size.x > 0, "M opens the connected world overview")
	map_ui._input(map_event)
	_expect(map_ui.mode == "" and not paused, "M closes the map overview")
	for definition: Dictionary in config.platforms + config.floor_samples:
		surfaces[definition.id] = Rect2(definition.rect[0], definition.rect[1], definition.rect[2], definition.rect[3])
	for route: Array in config.routes:
		_expect(await _try_route(surfaces[route[0]], surfaces[route[1]], str(route[1]).ends_with("floor")), "single_jump %s -> %s" % route)
	await _place(Vector2(760, 304 - HALF))
	Input.action_press("jump")
	var best := player.position.y
	for frame in 45:
		await physics_frame
		best = minf(best, player.position.y)
	_release()
	await _frames(18)
	_expect(best + HALF < 224 and absf(player.position.y + HALF - 224) < 2, "oneway platform passes upward and catches falling player")
	Input.action_press("move_down")
	await _frames(20)
	_release()
	_expect(absf(player.position.y + HALF - 304) < 2, "S drops through the thin platform onto the wall floor")
	await _place(Vector2(960, 1695))
	Input.action_press("move_right")
	await _frames(180)
	_release()
	_expect(player.position.x > 1220 and player.is_on_floor(), "root road diagonal is walkable without jumping or catching tile seams")
	for x in [2314, 2336, 2366, 2378]:
		await _place(Vector2(x, 1280))
		await _frames(45)
		_expect(player.position.y + HALF < 1360, "rounded root gate stays physically sealed at x=%d" % x)
	await _place(Vector2(config.switch.pos[0], config.switch.pos[1] - HALF))
	_expect(current_scene.interact_nearby(), "large emerald switch accepts interaction")
	await _frames(3)
	_expect(gs.opened_shortcuts.has(StringName(config.switch.id)), "linked mechanism state is recorded")
	for gate: Dictionary in config.gates:
		var node := current_scene.get_node(str(gate.id)) as StaticBody2D
		_expect(not node.visible and node.collision_layer == 0, "%s loses both visual seal and collision" % gate.id)
	await _place(Vector2(2336, 1280))
	await _frames(45)
	_expect(player.position.y + HALF >= 1390, "activated root gate allows passage through the rounded shaft")
	for chest: Dictionary in config.chests:
		await _place(Vector2(chest.pos[0], chest.pos[1] - HALF))
		_expect(current_scene.interact_nearby(), "%s is interactable" % chest.id)
		_expect(gs.opened_chests.has(StringName(chest.id)) != bool(chest.requires_clear), "%s obeys ordinary or combat-sealed rules" % chest.id)
	var fire: Array = config.campfire.pos
	await _place(Vector2(fire[0] + 32, fire[1] - HALF))
	gs.hp = 1
	var ui := root.get_node("GameUI")
	_expect(ui.begin_rest(), "forest_02 bonfire opens the existing rest system")
	_expect(gs.hp == 1 and gs.checkpoint_id == StringName(config.campfire.id), "opening rest binds checkpoint without healing")
	ui._rest_action("休息")
	_expect(gs.hp == gs.hp_max,"clicking rest heals")
	ui._force_close()
	player.stop_presentation_animation()
	await _frames(3)
	await _place(Vector2(64, fire[1] - HALF))
	Input.action_press("move_left")
	await _frames(90)
	_release()
	_expect(current_scene.name == &"Forest01" and gs.opened_shortcuts.has(&"forest_01_roots"), "first lower crossing unlocks the forest_01 shortcut automatically")
	if current_scene.name == &"Forest01":
		player = current_scene.get_node("Player")
		_expect(not current_scene.get_node("ShortcutGate").visible and player.position.y > 1760, "forest_01 lower barricade disappears and arrival is at roots")
		await _frames(35)
		await _place(Vector2(1210, 1807))
		Input.action_press("move_right")
		await _frames(90)
		_release()
		_expect(current_scene.name == &"Forest02", "unlocked lower connection returns to forest_02")
		if current_scene.name == &"Forest02":
			player = current_scene.get_node("Player")
			_expect(not current_scene.get_node("RootGate").visible, "mechanism remains open after revisiting the room")
			_expect(not current_scene.get_node("Chest_root_supplies").visible, "looted chest remains absent after revisiting")
			await _frames(35)
			await _place(Vector2(64, config.spawn[1]))
			Input.action_press("move_left")
			await _frames(90)
			_release()
			_expect(current_scene.name == &"Forest01", "upper connection also returns to forest_01")
			if current_scene.name == &"Forest01":
				_expect(current_scene.get_node("Player").position.y < 700, "upper return uses the upper portal, not the root portal")
	var saved: Dictionary = gs.to_save_dict()
	gs.reset()
	gs.load_from_dict(saved)
	_expect(gs.opened_shortcuts.has(&"forest_01_roots") and gs.opened_shortcuts.has(StringName(config.switch.id)), "both kinds of unlock survive save serialization")
	print("FOREST_02 PHYSICS: %d failures" % failures)
	quit(1 if failures else 0)


func _try_route(start: Rect2, target: Rect2, solid_target: bool) -> bool:
	var left := maxf(start.position.x + 12, target.position.x + 12)
	var right := minf(start.end.x - 12, target.end.x - 12)
	var candidates: Array[float] = []
	if left <= right:
		candidates.append((left + right) / 2.0)
	candidates.append(clampf(target.get_center().x, start.position.x + 12, start.end.x - 12))
	candidates.append(start.end.x - 12)
	candidates.append(start.position.x + 12)
	for x in candidates:
		await _place(Vector2(x, start.position.y - HALF))
		if not player.is_on_floor() or absf(player.position.y + HALF - start.position.y) > 2:
			continue
		var aim := clampf(x, target.position.x + 20, target.end.x - 20)
		Input.action_press("jump")
		for frame in 58:
			Input.action_release("move_left")
			Input.action_release("move_right")
			if absf(player.position.x - aim) > 3 and (not solid_target or player.position.y + HALF <= target.position.y):
				Input.action_press("move_right" if player.position.x < aim else "move_left")
			await physics_frame
			if frame > 5 and player.is_on_floor():
				if absf(player.position.y + HALF - target.position.y) < 2 and player.position.x > target.position.x and player.position.x < target.end.x:
					_release()
					return true
				break
		_release()
	return false


func _place(pos: Vector2) -> void:
	_release()
	player.position = pos
	player.velocity = Vector2.ZERO
	player.set("_drop_through", 0.0)
	player.set("_jumped", false)
	player.set("_coyote", 0.0)
	player.sm.to(&"Idle")
	await _frames(8)


func _release() -> void:
	for action in ["jump", "move_left", "move_right", "move_down", "dodge"]:
		Input.action_release(action)


func _frames(count: int) -> void:
	for frame in count:
		await physics_frame


func _expect(ok: bool, label: String) -> void:
	print("%s: %s" % ["PASS" if ok else "FAIL", label])
	if not ok:
		failures += 1
