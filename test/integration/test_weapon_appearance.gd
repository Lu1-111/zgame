extends SceneTree
## 实际人物中切换外观，验证模组、伤害、握点和剑接触数据完全不变。
var failures := 0
var checks := 0

func _initialize() -> void:
	call_deferred("_run")

func _run() -> void:
	var state := root.get_node("GameState")
	var player: Variant = (load("res://scenes/player/player.tscn") as PackedScene).instantiate()
	root.add_child(player)
	player.set_physics_process(false)
	var original_id: StringName = state.weapon_id
	_expect(WeaponAppearance.equipped_id({"appearance_id":"missing","weapon_type":"sword"})=="placeholder","缺失具体模型时显示占位，不借用其他武器")
	var keys := {"hammer":"hammer_01","sword":"sword_01","staff":"milk_staff","rifle":"bow_01"}
	for kind: String in keys:
		state.weapon_id=StringName(keys[kind])
		var stats := JSON.stringify(player.weapon_cfg())
		var module := JSON.stringify(WeaponRuntime.module(kind))
		var damage: int = player.attack_damage()
		player.attack_combo=1
		player._last_attack_time=0
		player._clock=0.3
		for appearance in ["placeholder","original","bronze","frost","original"]:
			player.weapon_appearance_override=appearance
			player._sync_weapon_sprite()
			_expect(JSON.stringify(player.weapon_cfg())==stats and JSON.stringify(WeaponRuntime.module(kind))==module,"外观不改变装备数值与攻击模组："+kind+"/"+appearance)
			_expect(player.attack_damage()==damage,"外观不改变伤害")
			for animation: String in WeaponAppearance.manifest().animations:
				if str(WeaponAppearance.manifest().animations[animation].module)!=kind:continue
				var definition: Dictionary=WeaponAppearance.manifest().animations[animation]
				for index in definition.frames.size():
					var frame: Dictionary=definition.frames[index]
					var texture := WeaponAppearance.frame_texture(animation,index,null,appearance)
					_expect(texture!=null and texture.get_size()==Vector2(frame.canvas[0],frame.canvas[1]),"独立帧层保持原生画布")
				if player.sprite.sprite_frames.has_animation(animation):
					player.sprite.animation=animation
					player.sprite.set_frame_and_progress(0,0.37)
					var speed: float = player.sprite.sprite_frames.get_animation_speed(animation)
					player.sprite.remove_meta("weapon_appearance")
					player._sync_weapon_sprite()
					_expect(player.sprite.frame==0 and is_equal_approx(player.sprite.frame_progress,0.37) and player.sprite.sprite_frames.get_animation_speed(animation)==speed,"换层不重置动画帧、进度或攻速")
	state.weapon_id=&"sword_01"
	var contacts := FileAccess.get_sha256("res://data/sword_contact.json")
	var reference := Vector2.ZERO
	for appearance in ["original","placeholder","frost"]:
		player._pixel_rig.appearance_id=appearance
		player._pixel_rig.kind="sword"
		player._pixel_rig.progress=0.45
		player._pixel_rig.apply_pose()
		if appearance=="original":reference=player._pixel_rig._grip
		_expect(player._pixel_rig._grip==reference,"武器层不改变剑持握轨迹")
		_expect(FileAccess.get_sha256("res://data/sword_contact.json")==contacts,"武器外观不改剑刃/剑光碰撞数据")
	var muzzle := Vector2.ZERO
	for appearance in ["original","placeholder","frost"]:
		player._pixel_rig.kind="rifle"
		player._pixel_rig.appearance_id=appearance
		player._pixel_rig.apply_pose()
		if appearance=="original":muzzle=player._pixel_rig.muzzle_global_position()
		_expect(player._pixel_rig.muzzle_global_position()==muzzle,"枪械模型不改变弹幕源点和射击模组")
	state.weapon_id=original_id
	player.queue_free()
	await process_frame
	print("WEAPON APPEARANCE: %d checks / %d failures" % [checks,failures])
	quit(1 if failures else 0)

func _expect(condition: bool,label: String) -> void:
	checks+=1
	if not condition:
		failures+=1
		printerr("FAIL: "+label)
