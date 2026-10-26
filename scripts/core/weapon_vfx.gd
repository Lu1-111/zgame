class_name WeaponVFX
extends Node2D
## 剑刃、拉弓释放与奶杖施法的生成特效播放器。
signal finished
var kind := "sword"
var visual: AnimatedSprite2D


func _ready() -> void:
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
	visual.speed_scale = rate
