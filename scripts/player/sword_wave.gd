class_name SwordWave
extends Node2D
## 大型贯穿剑气；同一次施放对每名敌人只结算一次，实心墙阻挡飞行。
signal hit_landed(target: Node, final_damage: int)
var direction := Vector2.RIGHT
var packet: DamagePacket
var source_actor: Node
var specification: Dictionary
var travelled := 0.0
var hitbox: HitboxComponent

func _ready() -> void:
	z_index = 21
	rotation = direction.angle()
	hitbox = HitboxComponent.new()
	hitbox.source_actor = source_actor
	var shape := CollisionShape2D.new()
	var rectangle := RectangleShape2D.new()
	rectangle.size = Vector2(specification.hitbox[0],specification.hitbox[1])
	shape.shape = rectangle
	hitbox.add_child(shape)
	add_child(hitbox)
	hitbox.hit_landed.connect(func(target: Node, amount: int) -> void: hit_landed.emit(target,amount))
	hitbox.activate(packet)
	var visual := AnimatedSprite2D.new()
	visual.sprite_frames = WeaponRuntime.effect_frames("sword_wave",true)
	visual.scale = WeaponRuntime.effect_scale("sword_wave")
	visual.texture_filter = CanvasItem.TEXTURE_FILTER_LINEAR
	add_child(visual)
	visual.play()

func _physics_process(delta: float) -> void:
	var distance := float(specification.speed)*delta
	var next := global_position+direction*distance
	var query := PhysicsRayQueryParameters2D.create(global_position,next,1)
	if not get_world_2d().direct_space_state.intersect_ray(query).is_empty():
		queue_free()
		return
	global_position = next
	travelled += distance
	if travelled >= float(specification.range):
		queue_free()
