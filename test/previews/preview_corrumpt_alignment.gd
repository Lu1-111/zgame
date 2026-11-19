extends SceneTree
## 以真实一比一像素显示中性姿态，并在同一根座旁放玩家和小怪作密度参照。
class Board extends Node2D:
	var entries: Array = []
	var font: Font
	var hero: Texture2D
	var beetle: Texture2D
	var preview_root := Vector2.ZERO
	func _draw() -> void:
		draw_rect(Rect2(0,0,1280,640),Color("#10151b"))
		draw_string(font,Vector2(18,24),"Boss 84 px = 角色 42 px × 2 / 与小怪同为 1:1 像素 / 共同本体不镜像、不换形",HORIZONTAL_ALIGNMENT_LEFT,-1,18,Color("#e1d4b8"))
		draw_string(font,Vector2(18,46),"八种状态的本体截取对照；外伸触手完整动作见演示动画。横线为共同地面，十字为固定根座。",HORIZONTAL_ALIGNMENT_LEFT,-1,14,Color("#a9acb5"))
		for index in entries.size():
			var column := index%4
			var row := floori(index/4.0)
			var corner := Vector2(column*320,row*280+64)
			var root_point := corner+Vector2(218,216)
			var entry: Dictionary = entries[index]
			draw_string(font,corner+Vector2(12,20),str(entry.name),HORIZONTAL_ALIGNMENT_LEFT,-1,15,Color("#e1d4b8"))
			draw_texture(hero,corner+Vector2(40,216)-Vector2(30,59))
			draw_texture(beetle,corner+Vector2(100,216)-Vector2(32,56))
			draw_texture_rect_region(entry.texture,Rect2(root_point-Vector2(90,174),Vector2(180,190)),Rect2(preview_root-Vector2(90,174),Vector2(180,190)))
			draw_line(corner+Vector2(12,216),corner+Vector2(308,216),Color("#527d7d"),1)
			draw_line(root_point+Vector2(-6,0),root_point+Vector2(6,0),Color("#e9ce64"),1)
			draw_line(root_point+Vector2(0,-6),root_point+Vector2(0,6),Color("#e9ce64"),1)
			draw_string(font,corner+Vector2(12,247),"角色42px  /  小怪39px  /  Boss84px",HORIZONTAL_ALIGNMENT_LEFT,-1,13,Color("#a9acb5"))

func _initialize() -> void:
	call_deferred("_capture")

func _capture() -> void:
	root.content_scale_size = Vector2i(1280,640)
	root.size = Vector2i(1280,640)
	var profile: Dictionary = JSON.parse_string(FileAccess.get_file_as_string("res://data/bosses/claffert.json"))
	var frames := load(str(profile.art.root)+"godot/Corrumpt_preview_frames.tres") as SpriteFrames
	var board := Board.new()
	board.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	board.preview_root = Vector2(profile.art.unified.preview_anchor[0],profile.art.unified.preview_anchor[1])
	var skin: GDScript = load("res://scripts/ui/rpg_skin.gd")
	board.font = skin.font()
	board.hero = load("res://assets/PROCESSED/characters/CHR-01/v001/frames/CHR-01_player_idle_right_v001_f01.png")
	board.beetle = load("res://assets/PROCESSED/enemies/ENM-B03/v001/frames/ENM-01_idle/ENM-01_idle_00.png")
	for entry in [["phase_1_idle",0,"闲置"],["slam",3,"砸击·高举"],["slam_downstroke",3,"砸击·挥落"],["spikes",3,"地刺"],["needles",2,"针弹"],["gravity",2,"引力"],["spores",2,"孢子囊"],["repel",2,"震退"]]:
		board.entries.append({"name":entry[2],"texture":frames.get_frame_texture(StringName(entry[0]),int(entry[1]))})
	root.add_child(board)
	for index in 3:
		await process_frame
	await RenderingServer.frame_post_draw
	root.get_texture().get_image().save_png(ProjectSettings.globalize_path("res://docs/previews/corrumpt_anchor_comparison.png"))
	print("CORRUMPT ALIGNMENT: persistent shared body 84px / hero 42px / 1:1 pixels / fixed root")
	quit()
