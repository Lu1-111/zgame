class_name WeaponVFX
extends Node2D
## 三段剑刃、步枪枪焰与奶杖施法的生成特效播放器。
signal finished
var kind := "sword"
var visual: AnimatedSprite2D
var _age := 0.0


func _ready() -> void:
	if kind == "rifle_muzzle":
		queue_redraw()
		return
	visual = AnimatedSprite2D.new()
	visual.name = "Sprite"
	visual.sprite_frames = WeaponRuntime.effect_frames(kind)
	visual.scale = WeaponRuntime.effect_scale(kind)
	visual.texture_filter = CanvasItem.TEXTURE_FILTER_LINEAR
	add_child(visual)
	visual.animation_finished.connect(func() -> void: finished.emit())
	visual.play(&"default")


## 调整播放速度，和攻击生效时序一致。
func set_rate(rate: float) -> void:
	if visual != null:
		visual.speed_scale = rate


func _process(delta: float) -> void:
	if kind != "rifle_muzzle":
		return
	_age += delta
	modulate.a = maxf(0,1-_age/0.08)
	if _age >= 0.08:
		finished.emit()
		queue_free()


func _draw() -> void:
	if kind == "rifle_muzzle":
		draw_colored_polygon(PackedVector2Array([Vector2(-2,-2),Vector2(4,-4),Vector2(2,-1),Vector2(13,0),Vector2(2,2),Vector2(4,4),Vector2(-2,2)]),Color("#ede4c3"))
