extends SceneTree
## 隐藏窗口捕获实际Godot材质，核对原生像素触手、弹幕与不同半径的圆环。
class Source extends Node2D:
	var hp := 300

class Board extends Node2D:
	var panels: Array[SubViewport] = []
	var font: Font
	var captions := ["触手 · 纤维、黑纹与花瓣同源","地刺与砸地冲击 · 固定落地基线","针弹 · 40×16原生画布","孢子 · 20×20原生画布","引力环 · 两种半径，纹素与线宽相同","震退环 · 两种半径，纹素与线宽相同"]
	func _draw() -> void:
		draw_rect(Rect2(0,0,1280,1080),Color("#10151b"))
		draw_string(font,Vector2(20,28),"corrumpt · 触手与全套特效材质对照 / 1:1世界像素 / 本体84px、角色42px",HORIZONTAL_ALIGNMENT_LEFT,-1,20,Color("#e1d4b8"))
		for index in panels.size():
			var point := Vector2((index%2)*640,floori(index/2.0)*340+60)
			draw_texture(panels[index].get_texture(),point)
			draw_string(font,point+Vector2(16,24),captions[index],HORIZONTAL_ALIGNMENT_LEFT,-1,16,Color("#e1d4b8"))
		draw_string(font,Vector2(20,1060),"实际SpriteFrames与圆环材质离屏捕获；扩散不再放大整张圆环图片。",HORIZONTAL_ALIGNMENT_LEFT,-1,14,Color("#a9acb5"))

var profile: Dictionary
var source: Node2D

func _initialize() -> void:
	call_deferred("_capture")

func _capture() -> void:
	root.content_scale_size = Vector2i(1280,1080)
	root.size = Vector2i(1280,1080)
	profile = JSON.parse_string(FileAccess.get_file_as_string("res://data/bosses/claffert.json"))
	var board := Board.new()
	board.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	board.font = load("res://scripts/ui/rpg_skin.gd").font()
	root.add_child(board)
	for index in 6:
		var viewport := SubViewport.new()
		viewport.world_2d = World2D.new()
		viewport.size = Vector2i(640,340)
		viewport.transparent_bg = true
		viewport.render_target_update_mode = SubViewport.UPDATE_ALWAYS
		root.add_child(viewport)
		board.panels.append(viewport)
		source = Source.new()
		viewport.add_child(source)
		var body := _body(viewport,Vector2(320,300))
		var hero := Sprite2D.new()
		hero.texture = load(profile.art.unified.player_reference)
		hero.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
		hero.position = Vector2(82,273)
		viewport.add_child(hero)
		match index:
			0:
				body.pose(&"slam",3,1)
			1:
				for x in [128,180,232]:
					var entity := _effect(viewport,&"spike",Vector2(x,300),profile.combat.moves.spikes)
					entity.hit_size = Vector2(32,40)
					entity._visual.position.y = -20
					entity._visual.frame = 2
				var impact := _effect(viewport,&"impact",Vector2(480,300),profile.combat.moves.slam)
				impact._visual.frame = 1
			2:
				for step in 10:
					var entity := _effect(viewport,&"needle",Vector2(140+step*18,150+sin(step*0.5)*30),profile.combat.moves.needles)
					entity.rotation = PI
			3:
				for step in 8:
					_effect(viewport,&"spore",Vector2(320,210)+Vector2.from_angle(step*TAU/8)*78,profile.combat.moves.spores)
			4,5:
				body.position = Vector2(390,225)
				var kind := &"gravity_ring" if index == 4 else &"repel_ring"
				var cfg: Dictionary = profile.combat.moves.gravity if index == 4 else profile.combat.moves.repel
				for sample in [[Vector2(160,185),64],[Vector2(390,185),128]]:
					var entity := _effect(viewport,kind,sample[0],cfg)
					entity.ring_max = float(sample[1])*2
					entity._ring_extent = ceilf(entity.ring_max+float(profile.art.unified.ring_rendering.strip_height))
					entity._ring_material.set_shader_parameter("extent_world",entity._ring_extent)
					entity.age = entity.lifetime*0.5
					entity._tick_ring()
	for frame in 6:
		await process_frame
	await RenderingServer.frame_post_draw
	root.get_texture().get_image().save_png(ProjectSettings.globalize_path("res://docs/previews/corrumpt_effects_v5.png"))
	print("CORRUMPT EFFECTS: native body/tendril/projectiles/spikes and pixel-stable rings rendered")
	quit()

func _body(parent: Node, point: Vector2) -> AnimatedSprite2D:
	var art := AnimatedSprite2D.new()
	art.set_script(load("res://scripts/enemies/corrumpt_art.gd"))
	art.set("profile",profile)
	art.position = point
	parent.add_child(art)
	art.call("freeze")
	return art

func _effect(parent: Node, kind: StringName, point: Vector2, cfg: Dictionary) -> Node2D:
	var entity := Node2D.new()
	entity.set_script(load("res://scripts/enemies/corrumpt_entity.gd"))
	entity.set("kind",kind)
	entity.set("profile",profile)
	entity.set("config",cfg)
	entity.set("source",source)
	entity.set("lifetime",float(cfg.get("active_seconds",cfg.get("duration",12))))
	entity.set("ring_max",280.0)
	entity.set("hit_size",Vector2(32,40) if kind == &"spike" else (Vector2(236,32) if kind == &"impact" else Vector2.ZERO))
	entity.position = point
	parent.add_child(entity)
	entity.set_physics_process(false)
	entity.get("_visual").pause()
	return entity
