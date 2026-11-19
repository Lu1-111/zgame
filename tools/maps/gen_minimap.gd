extends SceneTree
## 小地图生成：每个房间一张局部小地图 + 一张拼接后的大地图。
## 用法：godot --headless --path . --script res://tools/maps/gen_minimap.gd
## 产物：
##   res://assets/ui/map/minimaps/minimap_<id>.png   单房间小地图
##   res://assets/ui/map/minimaps/world_map.png      拼接大地图
##   res://data/world/map_layout.json       地图布局数据（供游戏内小地图 UI 使用）

const TILE := 16
const SCALE := 8                      # 世界 8px = 地图 1px（16px 图块 = 2px）
const OUT_DIR := "res://assets/ui/map/minimaps"

const ROOMS := [
	{"id": "camp_01", "scene": "res://scenes/maps/camp_01.tscn", "name": "奶族营地"},
	{"id": "forest_01", "scene": "res://scenes/maps/forest_01.tscn", "name": "始点森林"},
	{"id": "forest_02", "scene": "res://scenes/maps/forest_02.tscn", "name": "苔甲小径"},
	{"id": "forest_03", "scene": "res://scenes/maps/forest_03.tscn", "name": "藤影回廊"},
]

const C_BG := Color(0.06, 0.09, 0.08, 1.0)
const C_GROUND := Color(0.29, 0.42, 0.30, 1.0)
const C_EDGE := Color(0.45, 0.62, 0.46, 1.0)
const C_DOOR := Color(0.31, 0.88, 0.80, 1.0)
const C_FIRE := Color(1.0, 0.70, 0.28, 1.0)
const C_CHEST := Color(1.0, 0.82, 0.29, 1.0)
const C_PLAYER := Color(0.55, 0.85, 1.0, 1.0)


func _initialize() -> void:
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(OUT_DIR))
	var layout := {"scale": SCALE, "tile": TILE, "rooms": []}
	var ui: Dictionary = JSON.parse_string(FileAccess.get_file_as_string("res://data/world/world_map_ui.json"))
	var world_min := Vector2(1e9, 1e9)
	var world_max := Vector2(-1e9, -1e9)

	var scanned := []
	for room in ROOMS:
		var info := _scan_room(room)
		if info.is_empty():
			continue
		var map_origin: Array = ui.room_origins.get(str(info.id), [info.origin.x, info.origin.y])
		info["map_origin"] = Vector2(map_origin[0], map_origin[1])
		scanned.append(info)
		world_min.x = minf(world_min.x, info.map_origin.x)
		world_min.y = minf(world_min.y, info.map_origin.y)
		world_max.x = maxf(world_max.x, info.map_origin.x + info.size.x)
		world_max.y = maxf(world_max.y, info.map_origin.y + info.size.y)

	for info in scanned:
		var img := _render_room(info)
		var path := "%s/minimap_%s.png" % [OUT_DIR, info.id]
		img.save_png(ProjectSettings.globalize_path(path))
		print("minimap: %s  %dx%d" % [path, img.get_width(), img.get_height()])
		layout.rooms.append({
			"id": info.id, "name": info.name,
			"origin": [info.origin.x, info.origin.y],
			"map_origin": [info.map_origin.x, info.map_origin.y],
			"size": [info.size.x, info.size.y],
			"scene": info.scene,
			"doors": info.doors,
			"markers": info.markers,
		})
	layout["connections"] = _connections(scanned)

	# 拼接大地图
	var pad := 4
	var w := int(ceil((world_max.x - world_min.x) / SCALE)) + pad * 2
	var h := int(ceil((world_max.y - world_min.y) / SCALE)) + pad * 2
	var world := Image.create(w, h, false, Image.FORMAT_RGBA8)
	world.fill(C_BG)
	for info in scanned:
		var sub := _render_room(info)
		var ox := int((info.map_origin.x - world_min.x) / SCALE) + pad
		var oy := int((info.map_origin.y - world_min.y) / SCALE) + pad
		_blit(world, sub, ox, oy)
		_draw_border(world, ox, oy, sub.get_width(), sub.get_height(), C_EDGE)
	for connection: Dictionary in layout.connections:
		var points := PackedVector2Array()
		for side in ["from", "to"]:
			for info: Dictionary in scanned:
				if str(info.id) != str(connection[side + "_room"]):
					continue
				for door: Dictionary in info.doors:
					if str(door.id) == str(connection[side + "_door"]):
						points.append((info.map_origin + Vector2(door.pos[0], door.pos[1]) - world_min) / SCALE + Vector2.ONE * pad)
		if points.size() == 2:
			var count := maxi(1, ceili(points[0].distance_to(points[1])))
			for step in range(count + 1):
				var point := points[0].lerp(points[1], float(step) / count)
				_put_px(world, int(point.x), int(point.y), C_DOOR)
	var wpath := OUT_DIR + "/world_map.png"
	world.save_png(ProjectSettings.globalize_path(wpath))
	print("world map: %s  %dx%d" % [wpath, w, h])

	var f := FileAccess.open("res://data/world/map_layout.json", FileAccess.WRITE)
	if f != null:
		f.store_string(JSON.stringify(layout, "  "))
		f.close()
		print("layout: res://data/world/map_layout.json")
	quit()


func _scan_room(room: Dictionary) -> Dictionary:
	var packed: PackedScene = load(room.scene)
	if packed == null:
		push_error("load failed: " + room.scene)
		return {}
	var inst := packed.instantiate()
	var info := {
		"id": room.id, "name": room.get("name", room.id), "scene": room.scene,
		"origin": Vector2.ZERO, "size": Vector2.ZERO,
		"cells": [], "doors": [], "markers": [],
		"min_x": 99999, "min_y": 99999, "max_x": -99999, "max_y": -99999,
	}
	var origin: Vector2i = inst.get_meta("world_origin", Vector2i.ZERO)
	info.origin = Vector2(origin)
	var room_rect: Rect2i = inst.get_meta("room_rect", Rect2i())
	_walk(inst, info)
	if info.cells.is_empty():
		push_error("no cells in " + room.id)
		inst.free()
		return {}
	var bbox: Rect2i
	if room_rect.size != Vector2i.ZERO:
		bbox = room_rect
	else:
		bbox = Rect2i(Vector2i(info.min_x, info.min_y),
			Vector2i(info.max_x - info.min_x + 1, info.max_y - info.min_y + 1))
	info["_bbox"] = bbox
	info.size = Vector2(bbox.size) * TILE
	inst.free()
	return info


func _walk(node: Node, info: Dictionary, parent_offset := Vector2.ZERO) -> void:
	var offset := parent_offset + ((node as Node2D).position if node is Node2D else Vector2.ZERO)
	if node is TileMapLayer:
		var layer := node as TileMapLayer
		for cell in layer.get_used_cells():
			var world_cell := cell + Vector2i(offset / TILE)
			var kind := str(layer.get_meta("platform_type", "solid"))
			info.cells.append([world_cell.x, world_cell.y, kind])
			info.min_x = mini(info.min_x, world_cell.x)
			info.min_y = mini(info.min_y, world_cell.y)
			info.max_x = maxi(info.max_x, world_cell.x)
			info.max_y = maxi(info.max_y, world_cell.y)
	if node.has_meta("target_room"):
		var shortcut: Variant = node.get("shortcut_id")
		info.doors.append({"id": str(node.name), "target": str(node.get_meta("target_room")),
			"target_door": str(node.get_meta("target_door", "")),
			"shortcut_id": "" if shortcut == null else str(shortcut),
			"reserved": bool(node.get_meta("reserved", false)),
			"pos": [int(offset.x), int(offset.y)]})
	# 静态底图只收集地形；篝火由运行时根据解锁存档绘制。
	for c in node.get_children():
		_walk(c, info, offset)


func _connections(scanned: Array) -> Array:
	var rooms := {}
	var paired := {}
	var result: Array = []
	for room: Dictionary in scanned:
		rooms[str(room.id)] = room
	for room: Dictionary in scanned:
		for door: Dictionary in room.doors:
			if bool(door.reserved) or not rooms.has(str(door.target)):
				continue
			for other: Dictionary in rooms[str(door.target)].doors:
				if str(other.id) != str(door.target_door) or str(other.target) != str(room.id) or str(other.target_door) != str(door.id):
					continue
				var keys := ["%s/%s" % [room.id, door.id], "%s/%s" % [door.target, other.id]]
				keys.sort()
				var key := "|".join(keys)
				if not paired.has(key):
					result.append({"from_room": room.id, "from_door": door.id, "to_room": door.target, "to_door": other.id, "shortcut_id": door.shortcut_id if str(door.shortcut_id) != "" else other.shortcut_id})
					paired[key] = true
	return result


func _render_room(info: Dictionary) -> Image:
	var bbox: Rect2i = info["_bbox"] if info.has("_bbox") else Rect2i()
	var w := maxi(1, int(ceil(bbox.size.x * TILE / float(SCALE))))
	var h := maxi(1, int(ceil(bbox.size.y * TILE / float(SCALE))))
	var img := Image.create(w, h, false, Image.FORMAT_RGBA8)
	img.fill(C_BG)
	var ox := -bbox.position.x
	var oy := -bbox.position.y
	for cell in info.cells:
		var px := int((cell[0] + ox) * TILE / float(SCALE))
		var py := int((cell[1] + oy) * TILE / float(SCALE))
		var thin: bool = cell.size() > 2 and cell[2] == "oneway"
		_fill(img, px, py, 2, 1 if thin else 2, C_DOOR if thin else C_GROUND)
	return img


func _fill(img: Image, x: int, y: int, w: int, h: int, color: Color) -> void:
	for yy in range(y, y + h):
		for xx in range(x, x + w):
			if xx >= 0 and yy >= 0 and xx < img.get_width() and yy < img.get_height():
				img.set_pixel(xx, yy, color)


func _blit(dst: Image, src: Image, ox: int, oy: int) -> void:
	for y in src.get_height():
		for x in src.get_width():
			var c := src.get_pixel(x, y)
			if c == C_BG:
				continue
			var dx := ox + x
			var dy := oy + y
			if dx >= 0 and dy >= 0 and dx < dst.get_width() and dy < dst.get_height():
				dst.set_pixel(dx, dy, c)


func _draw_border(img: Image, x: int, y: int, w: int, h: int, color: Color) -> void:
	for xx in range(x, x + w):
		_put_px(img, xx, y, color)
		_put_px(img, xx, y + h - 1, color)
	for yy in range(y, y + h):
		_put_px(img, x, yy, color)
		_put_px(img, x + w - 1, yy, color)


func _put_px(img: Image, x: int, y: int, color: Color) -> void:
	if x >= 0 and y >= 0 and x < img.get_width() and y < img.get_height():
		img.set_pixel(x, y, color)
