extends RefCounted
## 验证实际绘制轮廓与接触轮廓同源，并覆盖边界与少量外扩容差。


## 检查三个剑光的方向、地面范围与逐帧精确判定。
func run(host) -> bool:
	var cfg: Dictionary = JSON.parse_string(FileAccess.get_file_as_string("res://data/sword_contact.json"))
	host.expect_eq(float(cfg.contact_padding),2.0,"剑光与剑刃边界向外保留 2 像素接触容差")
	host.expect_eq(cfg.frames.size(),24,"接触轮廓与 24 张完整人物帧逐一对应")
	for combo in range(1,4):
		var covered := true
		var narrow := true
		var above_floor := true
		var blade_covered := true
		for index in 8:
			var frame: Dictionary = cfg.frames["sword_%d_%02d" % [combo,index]]
			for contact: Dictionary in frame.contacts:
				var shape := _polygon(contact.polygon)
				var visible := _polygon(frame.blade if str(contact.source) == "blade" else frame.visuals[int(contact.visual_index)].polygon)
				for point in visible:
					covered = covered and _distance(point,shape) < 0.001
				for point in shape:
					narrow = narrow and _distance(point,visible) <= float(cfg.contact_padding)*sqrt(2.0)+0.001
				if str(contact.source) == "blade":
					for point in frame.blade:
						blade_covered = blade_covered and _distance(Vector2(point[0],point[1]),shape) < 0.001
			for visual: Dictionary in frame.visuals:
				for point in _polygon(visual.polygon):
					above_floor = above_floor and point.y <= float(cfg.floor_y)+0.001
		host.expect_true(covered,"第%d段：所有剑光边缘都被实际接触轮廓覆盖" % combo)
		host.expect_true(narrow,"第%d段：接触外扩始终只在约定容差内，不扩成整块矩形" % combo)
		host.expect_true(blade_covered,"第%d段：可见剑身也参与精确接触判定" % combo)
		host.expect_true(above_floor,"第%d段：可见剑光止于脚底地面，不穿入地下" % combo)
	var down := _bounds(cfg.frames.sword_1_05.visuals)
	var up := _bounds(cfg.frames.sword_2_05.visuals)
	var thrust := _bounds(cfg.frames.sword_3_04.visuals)
	host.expect_true(absf(down.end.y) < 0.001 and down.position.y < -40,"下劈剑光从头顶沿刃下落并触及地面")
	host.expect_true(absf(up.end.y) < 0.001 and up.position.y < -50,"上挑剑光在同一帧从地面连续延伸至半空")
	host.expect_true(thrust.size.x > thrust.size.y*3 and thrust.end.x > 45,"突刺剑光呈向前延伸的狭长尖刺")
	return true


func _polygon(values: Array) -> PackedVector2Array:
	var result := PackedVector2Array()
	for p: Array in values:
		result.append(Vector2(p[0],p[1]))
	return result


func _distance(point: Vector2, polygon: PackedVector2Array) -> float:
	if Geometry2D.is_point_in_polygon(point,polygon):
		return 0
	var result := INF
	for index in polygon.size():
		result = minf(result,point.distance_to(Geometry2D.get_closest_point_to_segment(point,polygon[index],polygon[(index+1)%polygon.size()])))
	return result


func _bounds(visuals: Array) -> Rect2:
	var first := true
	var result := Rect2()
	for visual: Dictionary in visuals:
		for point in _polygon(visual.polygon):
			if first:
				result = Rect2(point,Vector2.ZERO)
				first = false
			else:
				result = result.expand(point)
	return result
