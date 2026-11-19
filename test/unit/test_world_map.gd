extends RefCounted
## 地图投影保持房间内相对位置，连接保留实际门名，双通道不能被错误合并。


func run(ctx) -> bool:
	var view := WorldMapView.new()
	view.refresh_map()
	var layout: Dictionary = JSON.parse_string(FileAccess.get_file_as_string("res://data/world/map_layout.json"))
	ctx.expect_eq(layout.rooms.size(), 4, "四张已制作地图统一注册")
	ctx.expect_eq(layout.connections.size(), 5, "营地与森林两组上下连接均独立保留")
	var forest_links := 0
	var shortcuts := 0
	for link: Dictionary in layout.connections:
		var points := view.connection_endpoints(link)
		ctx.expect_eq(points.size(), 2, "%s/%s 有可解析的双侧通道端点" % [link.from_room, link.from_door])
		if str(link.from_room) == "forest_01" and str(link.to_room) == "forest_02":
			forest_links += 1
		if str(link.shortcut_id) != "":
			shortcuts += 1
	ctx.expect_eq(forest_links, 2, "forest_01 与 forest_02 上下两条通道分别显示")
	ctx.expect_eq(shortcuts, 2, "根部与新上层捷径均保留锁定标识")
	for room: Dictionary in layout.rooms:
		var a := Vector2(80, 100)
		var b := Vector2(320, 260)
		ctx.expect_eq(view.project_room_position(str(room.id), b) - view.project_room_position(str(room.id), a), b - a, "%s 玩家运动按实际坐标投影" % room.id)
		ctx.expect_eq(view.project_room_position(str(room.id), Vector2.ZERO), view.room_origin(str(room.id)), "%s 的局部原点和总览原点一致" % room.id)
	view.free()
	return true
