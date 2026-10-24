extends SceneTree
## 小地图生成：每个房间一张局部小地图 + 一张拼接后的大地图。
## 用法：godot --headless --path . --script res://tools/gen_minimap.gd
## 产物：
##   res://docs/previews/minimap_<id>.png   单房间小地图
##   res://docs/previews/world_map.png      拼接大地图
##   res://data/world/map_layout.json       地图布局数据（供游戏内小地图 UI 使用）

const TILE := 16
const SCALE := 8                      # 世界 8px = 地图 1px（16px 图块 = 2px）
const OUT_DIR := "res://docs/previews"

const ROOMS := [
	{"id": "camp_01", "scene": "res://scenes/rooms/camp_01.tscn", "name": "奶族营地"},
	{"id": "forest_01", "scene": "res://scenes/rooms/forest_01.tscn", "name": "始点森林"},
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
	var world_min := Vector2(1e9, 1e9)
	var world_max := Vector2(-1e9, -1e9)

	var scanned := []
	for room in ROOMS:
		var info := _scan_room(room)
		if info.is_empty():
			continue
		scanned.append(info)
		world_min.x = minf(world_min.x, info.origin.x)
		world_min.y = minf(world_min.y, info.origin.y)
		world_max.x = maxf(world_max.x, info.origin.x + info.size.x)
		world_max.y = maxf(world_max.y, info.origin.y + info.size.y)

	for info in scanned:
		var img := _render_room(info)
		var path := "%s/minimap_%s.png" % [OUT_DIR, info.id]
		img.save_png(ProjectSettings.globalize_path(path))
		print("minimap: %s  %dx%d" % [path, img.get_width(), img.get_height()])
		layout.rooms.append({
			"id": info.id, "name": info.name,
			"origin": [info.origin.x, info.origin.y],
			"size": [info.size.x, info.size.y],
			"scene": info.scene,
			"doors": info.doors,
			"markers": info.markers,
		})

	# 拼接大地图
	var pad := 4
	var w := int(ceil((world_max.x - world_min.x) / SCALE)) + pad * 2
	var h := int(ceil((world_max.y - world_min.y) / SCALE)) + pad * 2
	var world := Image.create(w, h, false, Image.FORMAT_RGBA8)
	world.fill(C_BG)
	for info in scanned:
		var sub := _render_room(info)
		var ox := int((info.origin.x - world_min.x) / SCALE) + pad
		var oy := int((info.origin.y - world_min.y) / SCALE) + pad
		_blit(world, sub, ox, oy)
		_draw_border(world, ox, oy, sub.get_width(), sub.get_height(), C_EDGE)
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


func _walk(node: Node, info: Dictionary) -> void:
	if node is TileMapLayer:
		var layer := node as TileMapLayer
		for cell in layer.get_used_cells():
			info.cells.append([cell.x, cell.y])
			info.min_x = mini(info.min_x, cell.x)
			info.min_y = mini(info.min_y, cell.y)
			info.max_x = maxi(info.max_x, cell.x)
			info.max_y = maxi(info.max_y, cell.y)
	if node.has_meta("target_room"):
		info.doors.append({"target": str(node.get_meta("target_room")),
			"pos": [int(node.position.x), int(node.position.y)]})
	if node.has_meta("save_point"):
		info.markers.append({"type": "campfire", "pos": [int(node.position.x), int(node.position.y)]})
	if node.has_meta("interact") and str(node.get_meta("interact")) == "chest":
		info.markers.append({"type": "chest", "pos": [int(node.position.x), int(node.position.y)]})
	for c in node.get_children():
		_walk(c, info)


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
		_fill(img, px, py, 2, 2, C_GROUND)
	for m in info.markers:
		var px2 := int((m.pos[0] / float(TILE) + ox) * TILE / float(SCALE))
		var py2 := int((m.pos[1] / float(TILE) + oy) * TILE / float(SCALE))
		_fill(img, px2 - 1, py2 - 2, 3, 3, C_FIRE if m.type == "campfire" else C_CHEST)
	for d in info.doors:
		var px3 := int((d.pos[0] / float(TILE) + ox) * TILE / float(SCALE))
		var py3 := int((d.pos[1] / float(TILE) + oy) * TILE / float(SCALE))
		_fill(img, px3 - 1, py3 - 3, 3, 4, C_DOOR)
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
