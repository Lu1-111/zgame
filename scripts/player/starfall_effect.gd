extends Node2D
## 星乳坠落：独立三段范围判定与原创符文光雨，所有战斗参数取自数据表。
var source: Node
var packet: DamagePacket
var elapsed := 0.0
var _hit_count := 0
var _skill: Dictionary
var _presentation: Dictionary


func _ready() -> void:
	_skill = DataDB.get_skill(&"skill_starfall")
	_presentation = InventoryService.config().combat
	z_index = 1


func _physics_process(delta: float) -> void:
	elapsed += delta
	if _hit_count < int(_skill.hits) and elapsed >= _hit_count * float(_presentation.starfall_interval):
		_hit_count += 1
		var query := PhysicsShapeQueryParameters2D.new()
		var circle := CircleShape2D.new()
		circle.radius = float(_presentation.starfall_radius)
		query.shape = circle
		query.transform = Transform2D(0,global_position)
		query.collision_mask = 32
		query.collide_with_areas = true
		query.collide_with_bodies = false
		for hit in get_world_2d().direct_space_state.intersect_shape(query,64):
			var hurtbox: Object = hit.collider
			if hurtbox is HurtboxComponent and hurtbox.owner_actor != source:
				hurtbox.receive_hit(packet)
	queue_redraw()
	if elapsed >= float(_presentation.starfall_duration):
		queue_free()


func _draw() -> void:
	var radius := float(_presentation.starfall_radius)
	var life := 1.0 - elapsed / float(_presentation.starfall_duration)
	draw_circle(Vector2.ZERO,radius,Color(0.5,0.4,0.8,life * 0.09))
	draw_arc(Vector2.ZERO,radius,0,TAU,96,Color(0.8,0.75,1.0,life * 0.6),2,true)
	for index in 9:
		var x := (float(index) / 8 - 0.5) * radius * 1.6
		var y := -radius + fmod(elapsed * 470 + index * 31, radius * 1.7)
		draw_line(Vector2(x,y - 30),Vector2(x,y),Color(1.0,0.9,0.6,life),2,true)
		draw_circle(Vector2(x,y),3,Color(1.0,0.95,0.8,life))
