extends Node2D
## 纯表现检视：逐帧身体+握点占位+具体武器；不产生伤害、不写旅途存档。
var kind := "sword"
var appearance := "placeholder"
var animation := "sword_1"
var elapsed := 0.0
var actor := Sprite2D.new()
var rifle := PixelHeroRig.new()
var actions := OptionButton.new()
var _frames: SpriteFrames
var _info := Label.new()
var mirrored := false

func _ready() -> void:
	_frames=(load("res://assets/PROCESSED/characters/CHR-01/v001/godot/CHR-01_sprite_frames.tres") as SpriteFrames).duplicate(true)
	WeaponRuntime.inject_animations(_frames)
	texture_filter=CanvasItem.TEXTURE_FILTER_NEAREST
	actor.centered=false
	actor.position=Vector2(400,270)
	actor.z_index=20
	add_child(actor)
	rifle.position=Vector2(400,270)
	rifle.z_index=20
	add_child(rifle)
	var ui := CanvasLayer.new()
	add_child(ui)
	var box := VBoxContainer.new()
	box.position=Vector2(12,12)
	box.add_theme_font_override("font",RPGSkin.font())
	box.add_theme_font_size_override("font_size",12)
	ui.add_child(box)
	var title := Label.new()
	title.text="武器模块检视 · 身体 / 握点 / 外观"
	box.add_child(title)
	var types := OptionButton.new()
	for name in WeaponAppearance.config().modules:types.add_item(str(name))
	types.item_selected.connect(func(index: int) -> void:kind=str(WeaponAppearance.config().modules[index]);_reset_actions())
	box.add_child(types)
	var models := OptionButton.new()
	for name in ["placeholder","original","bronze","frost"]:models.add_item(str(WeaponAppearance.config().skins[name].name))
	models.item_selected.connect(func(index: int) -> void:appearance=["placeholder","original","bronze","frost"][index])
	box.add_child(models)
	actions.item_selected.connect(func(index: int) -> void:animation=actions.get_item_text(index);elapsed=0)
	box.add_child(actions)
	var flip := Button.new()
	flip.text="左右镜像"
	flip.pressed.connect(func() -> void:mirrored=not mirrored)
	box.add_child(flip)
	box.add_child(_info)
	_reset_actions()

func _reset_actions() -> void:
	actions.clear()
	for name in WeaponRuntime.module(kind).animations:actions.add_item(str(name))
	actions.add_item("guard_"+kind)
	for name: String in WeaponAppearance.manifest().animations:
		if name.begins_with("SKL-") and str(WeaponAppearance.manifest().animations[name].module)==kind:
			SkillLibrary.ensure_actor(_frames,StringName(name))
			actions.add_item(name)
	animation=actions.get_item_text(0)
	elapsed=0

func _process(delta: float) -> void:
	elapsed+=delta
	var count := _frames.get_frame_count(animation)
	var index := floori(elapsed*_frames.get_animation_speed(animation))%count
	var row: Dictionary=WeaponAppearance.manifest().animations[animation].frames[index]
	actor.visible=animation!="rifle_shot"
	rifle.visible=not actor.visible
	if actor.visible:
		actor.texture=WeaponAppearance.frame_texture(animation,index,_frames.get_frame_texture(animation,index),appearance)
		actor.offset=-Vector2(row.anchor[0],row.anchor[1])
		actor.scale.x=-1 if mirrored else 1
	else:
		rifle.kind="rifle"
		rifle.appearance_id=appearance
		rifle.facing=-1 if mirrored else 1
		rifle.aim=Vector2(-100 if mirrored else 100,0)
		rifle.release_time=fmod(elapsed,0.44)
		rifle.apply_pose()
	_info.text="%s / %s\n帧 %d/%d · 1:1原生像素\n握点与外观不参与伤害计算" % [kind,appearance,index+1,count]
