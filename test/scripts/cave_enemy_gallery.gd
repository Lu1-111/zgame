extends Node2D
## 七种洞穴敌怪的纯美术检视：完整动作、原生像素与独立弹幕，不使用占位战斗数值。
var cfg: Dictionary
var actor: AnimatedSprite2D
var effect: AnimatedSprite2D
var enemy_choice: OptionButton
var action_choice: OptionButton
var effect_choice: OptionButton
var description: Label
var _index := 0
var _clock := 0.0
var _fx_start := Vector2.ZERO
var _ui: CanvasLayer
var rules: Dictionary
var ground_texture: Texture2D

func _ready() -> void:
	cfg = JSON.parse_string(FileAccess.get_file_as_string("res://data/enemy_designs/cave_v001.json"))
	texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	rules = JSON.parse_string(FileAccess.get_file_as_string("res://test/data/cave_enemy_gallery.json"))
	ground_texture=load(str(rules.ground_texture))
	var bg := Sprite2D.new()
	bg.texture = load(str(rules.background))
	bg.centered = false
	bg.modulate = Color(str(rules.background_tint))
	bg.z_index = -30
	add_child(bg)
	actor = AnimatedSprite2D.new()
	actor.centered = false
	actor.position = Vector2(rules.actor_origin[0],rules.actor_origin[1])
	actor.z_index = 20
	add_child(actor)
	var standard: Dictionary = JSON.parse_string(FileAccess.get_file_as_string("res://data/art/pixel_standards.json"))
	var reference := Sprite2D.new()
	reference.texture=load(str(standard.reference.player_path))
	reference.position=Vector2(rules.player_reference_origin[0],rules.player_reference_origin[1])
	reference.z_index=20
	add_child(reference)
	effect = AnimatedSprite2D.new()
	effect.centered = false
	effect.z_index = 20
	add_child(effect)
	_ui = CanvasLayer.new()
	_ui.layer = 30
	add_child(_ui)
	var column := VBoxContainer.new()
	column.position = Vector2(rules.ui_pos[0],rules.ui_pos[1])
	column.add_theme_font_override("font",RPGSkin.font())
	column.add_theme_font_size_override("font_size",int(rules.font_size))
	_ui.add_child(column)
	var title := Label.new()
	title.text = "洞穴敌怪 · 原生逐帧美术检视"
	column.add_child(title)
	enemy_choice = OptionButton.new()
	for row: Dictionary in cfg.enemies:enemy_choice.add_item(str(row.name))
	enemy_choice.item_selected.connect(select_enemy)
	column.add_child(enemy_choice)
	action_choice = OptionButton.new()
	action_choice.item_selected.connect(select_action)
	column.add_child(action_choice)
	effect_choice = OptionButton.new()
	effect_choice.add_item("不显示弹幕/效果")
	for row: Dictionary in cfg.effects:effect_choice.add_item(str(row.name))
	effect_choice.item_selected.connect(select_effect)
	column.add_child(effect_choice)
	description = Label.new()
	column.add_child(description)
	var restart := Button.new()
	restart.text = "重新播放（Space）"
	restart.pressed.connect(func() -> void: actor.frame=0;actor.play())
	column.add_child(restart)
	select_enemy(0)
	select_effect(0)
	queue_redraw()

## 选择设计敌怪，保留文件原生尺寸与固定锚点。
func select_enemy(index: int) -> void:
	_index = index
	enemy_choice.select(index)
	var row: Dictionary = cfg.enemies[index]
	actor.sprite_frames = (load(str(row.sprite_frames)) as SpriteFrames).duplicate()
	actor.offset = -Vector2(row.anchor[0],row.anchor[1])
	actor.scale = Vector2.ONE
	actor.position.y = float(rules.flying_y if row.id=="animated_crystal" else rules.ground_y)
	action_choice.clear()
	for action: Dictionary in row.actions:action_choice.add_item(str(rules.action_labels.get(str(action.id),action.id)))
	description.text = "%s · %d×%d\n基础生命/攻击/韧性/抗性：待定\n本页仅检视美术，不写旅途存档" % [row.name,row.canvas[0],row.canvas[1]]
	select_action(0)

## 按目录中的真实动作名播放，每套独立帧完整循环便于观察。
func select_action(index: int) -> void:
	action_choice.select(index)
	var row: Dictionary = cfg.enemies[_index]
	var action := StringName(str(row.actions[index].id))
	actor.sprite_frames.set_animation_loop(action,true)
	actor.play(action)
	actor.frame = 0
	description.text = "%s · %d×%d\n播放0.75× · %s fps · %.3f秒\n基础生命/攻击/韧性/抗性：待定\n本页仅检视美术，不写旅途存档" % [row.name,row.canvas[0],row.canvas[1],str(row.actions[index].fps),float(row.actions[index].duration_seconds)]

## 独立检查箭矢、丝线、晶石弹与震荡波，速度只用于检视页演示。
func select_effect(index: int) -> void:
	effect_choice.select(index)
	effect.visible = index>0
	_clock = 0.0
	if index==0:return
	var row: Dictionary = cfg.effects[index-1]
	effect.sprite_frames = (load(str(row.sprite_frames)) as SpriteFrames).duplicate()
	effect.offset = -Vector2(row.anchor[0],row.anchor[1])
	effect.position = _vector(rules.effect_origin)
	_fx_start = effect.position
	var names := effect.sprite_frames.get_animation_names()
	effect.sprite_frames.set_animation_loop(names[0],true)
	effect.play(names[0])

func _process(delta: float) -> void:
	if effect!=null and effect.visible:
		_clock = fmod(_clock+delta,float(rules.effect_demo_seconds))
		effect.position = _fx_start+Vector2(_clock*float(rules.effect_demo_speed),0)

func _unhandled_key_input(event: InputEvent) -> void:
	if event is InputEventKey and event.pressed and not event.echo and event.physical_keycode==KEY_SPACE:
		actor.frame = 0
		actor.play()

func _draw() -> void:
	var tex := ground_texture
	for x in range(0,int(rules.stage_width),tex.get_width()):
		draw_texture_rect_region(tex,Rect2(Vector2(x,float(rules.ground_y)),Vector2(mini(tex.get_width(),int(rules.stage_width)-x),float(rules.stage_height)-float(rules.ground_y))),Rect2(0,0,mini(tex.get_width(),int(rules.stage_width)-x),float(rules.stage_height)-float(rules.ground_y)))

func _vector(value: Array) -> Vector2:
	return Vector2(value[0],value[1])
