extends SceneTree
## 以实际13张烘焙场景核查前景比例、原生背景、地形材质及迷雾动画。
var checks := 0
var failures := 0
var surfaces := 0

func _initialize() -> void:
	call_deferred("_run")

func _run() -> void:
	var paths: Array[String] = []
	for id in ["forest_01","forest_02","forest_03"]:paths.append("res://scenes/maps/%s.tscn" % id)
	var candidates: Dictionary = JSON.parse_string(FileAccess.get_file_as_string("res://test/data/forest_candidates/manifest.json"))
	for row: Dictionary in candidates.candidates:paths.append(str(row.scene))
	for path in paths:
		change_scene_to_file(path)
		for tick in 4:await process_frame
		var room := current_scene
		var bg := room.get_node("NativeForestBackground")
		_expect(bg.texture.get_size()==Vector2(640,360),"背景像素数："+path)
		for child in bg.get_children():_expect(child.scale==Vector2.ONE and child.texture_filter==CanvasItem.TEXTURE_FILTER_NEAREST,"背景原生平铺")
		_inspect(room)
	_expect(surfaces>0,"真实使用原生平台脚本")
	print("FOREST NATIVE ART: %d checks / %d failures / %d maps / %d surfaces" % [checks,failures,paths.size(),surfaces])
	quit(1 if failures else 0)

func _inspect(node: Node) -> void:
	if node.get_script()!=null:
		var path := str(node.get_script().resource_path)
		if path.ends_with("forest_native_surface.gd"):
			surfaces+=1
			_expect(node.scale==Vector2.ONE and node.texture_filter==CanvasItem.TEXTURE_FILTER_NEAREST,"平台原生平铺")
			_expect(node._field.get_size()==Vector2(256,256),"平台填充实际256px")
		if path.ends_with("forest_mist_gate.gd"):
			var visual := node.get_node("WhiteMist") as AnimatedSprite2D
			_expect(visual.scale==Vector2.ONE and visual.sprite_frames.get_frame_count("default")==8,"白雾原生裁片平铺、八帧")
	if node is Sprite2D:
		var sprite := node as Sprite2D
		if sprite.texture!=null and sprite.texture.resource_path.contains("/forest/v002/"):
			_expect(sprite.scale==Vector2.ONE,"装饰固定1:1："+str(node.name))
			_expect(_is_nearest(sprite),"装饰nearest："+str(node.name))
	if node is TileMapLayer and node.material is ShaderMaterial:
		var material := node.material as ShaderMaterial
		if material.shader.resource_path.contains("/forest/v002/"):
			var texture := material.get_shader_parameter("albedo_texture") as Texture2D
			_expect(material.get_shader_parameter("texture_world_size")==texture.get_size(),"岩壁采样尺寸等于实际像素")
	for child in node.get_children():_inspect(child)

func _is_nearest(node: Node) -> bool:
	var current := node
	while current!=null:
		if current is CanvasItem and current.texture_filter!=CanvasItem.TEXTURE_FILTER_PARENT_NODE:
			return current.texture_filter==CanvasItem.TEXTURE_FILTER_NEAREST
		current=current.get_parent()
	return int(ProjectSettings.get_setting("rendering/textures/canvas_textures/default_texture_filter"))==0

func _expect(condition: bool,label: String) -> void:
	checks+=1
	if not condition:
		failures+=1
		printerr("FAIL: "+label)
