extends SceneTree
## 仅为造型核对排版正式原始动作，不改动任何原像素。
func _initialize() -> void:
	var sheet := Image.create(256,256,false,Image.FORMAT_RGBA8)
	sheet.fill(Color("#142528"))
	var actions := ["idle","hammer_1","hammer_2","staff_sweep"]
	for row in actions.size():
		for frame in 4:
			var path := "res://assets/PROCESSED/characters/CHR-01/v001/frames/CHR-01_player_%s_right_v001_f%02d.png" % [actions[row],frame+1]
			var image := Image.load_from_file(ProjectSettings.globalize_path(path))
			var origin := Vector2i((image.get_width()-64)/2,image.get_height()-64)
			sheet.blend_rect(image,Rect2i(origin,Vector2i(64,64)),Vector2i(frame*64,row*64))
	sheet.resize(1536,1536,Image.INTERPOLATE_NEAREST)
	sheet.save_png(ProjectSettings.globalize_path("res://work/fixes_v3/reference_attacks.png"))
	quit()
