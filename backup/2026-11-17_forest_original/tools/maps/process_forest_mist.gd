extends SceneTree
## 机械裁切八格原画，统一雾墙动画画布；不重绘生成素材。
func _initialize() -> void:
	var cfg: Dictionary = JSON.parse_string(FileAccess.get_file_as_string("res://data/forest_mist.json"))
	var source := Image.load_from_file(ProjectSettings.globalize_path(str(cfg.source)))
	var cell := Vector2i(cfg.cell[0],cfg.cell[1])
	var sheet := Image.create(cell.x*int(cfg.frames),cell.y,false,Image.FORMAT_RGBA8)
	for index in int(cfg.frames):
		var x0 := roundi(float(index%int(cfg.grid[0]))*source.get_width()/float(cfg.grid[0]))
		var y0 := roundi(floorf(float(index)/float(cfg.grid[0]))*source.get_height()/float(cfg.grid[1]))
		var x1 := roundi(float(index%int(cfg.grid[0])+1)*source.get_width()/float(cfg.grid[0]))
		var y1 := roundi((floorf(float(index)/float(cfg.grid[0]))+1)*source.get_height()/float(cfg.grid[1]))
		var frame := source.get_region(Rect2i(x0,y0,x1-x0,y1-y0))
		# 清除各格透明留边，让雾幕的有效上下沿贴合地图定义的封印范围。
		frame = frame.get_region(_visible_rect(frame,float(cfg.crop_alpha_threshold)))
		frame.resize(cell.x,cell.y,Image.INTERPOLATE_NEAREST)
		sheet.blit_rect(frame,Rect2i(Vector2i.ZERO,cell),Vector2i(index*cell.x,0))
	var error := sheet.save_png(ProjectSettings.globalize_path(str(cfg.sheet)))
	print("FOREST MIST: 8 source frames, export=",error)
	quit(error)

func _visible_rect(frame: Image, threshold: float) -> Rect2i:
	# 原画透明区含极低alpha的像素；仅用于确定裁切范围，不改动原画像素。
	var start := Vector2i(frame.get_width(),frame.get_height())
	var end := Vector2i(-1,-1)
	for y in frame.get_height():
		for x in frame.get_width():
			if frame.get_pixel(x,y).a > threshold:
				start.x = mini(start.x,x)
				start.y = mini(start.y,y)
				end.x = maxi(end.x,x)
				end.y = maxi(end.y,y)
	return Rect2i(start,end-start+Vector2i.ONE) if end.x >= 0 else frame.get_used_rect()
