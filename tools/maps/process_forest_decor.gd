extends SceneTree
## 将重绘的像素素材机械裁切到原生画布、二值透明与森林色板，保留原画。
func _initialize() -> void:
	var path := "res://docs/art/drafts/forest_decorations.json"
	var cfg: Dictionary = JSON.parse_string(FileAccess.get_file_as_string(path))
	var palette: Array[Color] = []
	for hex: String in cfg.palette:
		palette.append(Color(hex))
	for key: String in cfg.props:
		var definition: Dictionary = cfg.props[key]
		var source := Image.load_from_file(ProjectSettings.globalize_path(str(definition.source)))
		if source == null:
			push_error("Missing pixel-art source: "+key)
			quit(1)
			return
		var bounds := _visible_rect(source,float(cfg.alpha_cutoff))
		var sprite := source.get_region(bounds)
		var size := Vector2i(definition.size[0],definition.size[1])
		var ratio := minf(float(size.x)/sprite.get_width(),float(size.y)/sprite.get_height())
		var fitted := Vector2i(maxi(1,roundi(sprite.get_width()*ratio)),maxi(1,roundi(sprite.get_height()*ratio)))
		sprite.resize(fitted.x,fitted.y,Image.INTERPOLATE_NEAREST)
		var output := Image.create(size.x,size.y,false,Image.FORMAT_RGBA8)
		var offset := Vector2i((size.x-fitted.x)/2,0 if str(definition.anchor) == "ceiling" else size.y-fitted.y)
		for y in fitted.y:
			for x in fitted.x:
				var color := sprite.get_pixel(x,y)
				if color.a < float(cfg.alpha_cutoff):
					continue
				output.set_pixelv(Vector2i(x,y)+offset,_nearest(color,palette))
		var error := output.save_png(ProjectSettings.globalize_path(str(definition.texture)))
		if error != OK:
			push_error("Cannot export pixel-art: "+key)
			quit(error)
			return
		var used := output.get_used_rect()
		definition["visible_rect"] = [used.position.x,used.position.y,used.size.x,used.size.y]
		definition["anchor_pixel"] = [roundi(used.get_center().x),used.position.y if str(definition.anchor) == "ceiling" else used.end.y]
	var file := FileAccess.open(path,FileAccess.WRITE)
	file.store_string(JSON.stringify(cfg,"  ")+"\n")
	print("FOREST PIXEL DECOR: ",cfg.props.size()," native sprites, 32 colors, binary alpha")
	quit(0)

func _visible_rect(source: Image, threshold: float) -> Rect2i:
	var start := Vector2i(source.get_width(),source.get_height())
	var end := Vector2i(-1,-1)
	for y in source.get_height():
		for x in source.get_width():
			if source.get_pixel(x,y).a >= threshold:
				start = Vector2i(mini(start.x,x),mini(start.y,y))
				end = Vector2i(maxi(end.x,x),maxi(end.y,y))
	return Rect2i(start,end-start+Vector2i.ONE)

func _nearest(color: Color, palette: Array[Color]) -> Color:
	var nearest := palette[0]
	var distance := INF
	for candidate: Color in palette:
		var delta := Vector3(color.r-candidate.r,color.g-candidate.g,color.b-candidate.b).length_squared()
		if delta < distance:
			distance = delta
			nearest = candidate
	return nearest
