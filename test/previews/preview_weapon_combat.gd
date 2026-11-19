extends Node
## 操作实际演练面板并逐段/连段推进正式Player，保存真实1×引擎画面。
var failures := 0
var played := 0

func _ready() -> void:
	call_deferred("_run")

func _run() -> void:
	var gallery := (load("res://test/scenes/weapon_combat_gallery.tscn") as PackedScene).instantiate()
	get_tree().root.add_child(gallery)
	get_tree().current_scene=gallery
	for i in 8:await get_tree().physics_frame
	gallery.set_physics_process(false)
	gallery.player.set_physics_process(false)
	for index in gallery.weapons.size():
		gallery.choices.select(index)
		gallery._select(index)
		for segment in gallery.player.max_combo():
			gallery._play(segment+1,false)
			_advance(gallery)
		gallery._play(1,true)
		_advance(gallery)
		await get_tree().process_frame
	for index in gallery.weapons.size():
		if str(gallery.weapons[index].id)=="sword_03":
			gallery.choices.select(index)
			gallery._select(index)
			gallery._play(1,true)
			for i in 14:
				gallery._physics_process(1.0/60)
				gallery.player._physics_process(1.0/60)
	for i in 3:await get_tree().process_frame
	if DisplayServer.get_name()!="headless":
		await RenderingServer.frame_post_draw
		var folder := "res://docs/previews/weapons_v001"
		DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(folder))
		get_viewport().get_texture().get_image().save_png(ProjectSettings.globalize_path(folder+"/combat_gallery.png"))
		await _capture_arsenal(gallery)
	print("WEAPON COMBAT GALLERY: %d playbacks / %d failures / all weapon segments and full chains" % [played,failures])
	get_tree().quit(1 if failures else 0)

func _capture_arsenal(gallery: Node) -> void:
	var folder := "res://docs/previews/arsenal_v001/"
	for index in gallery.weapons.size():
		if str(gallery.weapons[index].id) != "rifle_06":
			continue
		gallery.choices.select(index)
		gallery._select(index)
		gallery._play(1, false)
		for frame in 11:
			gallery._physics_process(1.0 / 60)
			gallery.player._physics_process(1.0 / 60)
		await RenderingServer.frame_post_draw
		get_viewport().get_texture().get_image().save_png(ProjectSettings.globalize_path(folder + "rifle_gallery.png"))
		break
	GameUI.show()
	var panel := CharacterPanel.new()
	panel.ui = GameUI
	panel.gear_page = "accessory"
	panel.selected_accessory = &"accessory_02"
	panel.open()
	await RenderingServer.frame_post_draw
	get_viewport().get_texture().get_image().save_png(ProjectSettings.globalize_path(folder + "accessory_panel.png"))
	GameUI.close_menu()

func _advance(gallery: Node) -> void:
	played+=1
	var ticks := 0
	var max_ticks := ceili(WeaponAttributes.duration(gallery.player.weapon_cfg()) * gallery.player.max_combo() * 60) + 4
	while gallery._playing and ticks < max_ticks:
		gallery._physics_process(1.0/60)
		gallery.player._physics_process(1.0/60)
		ticks+=1
	if gallery._playing or gallery.player.sm.current_name()==&"Attack":
		failures+=1
		printerr("FAIL: playback did not finish")
	gallery.player.cancel_weapon_action()
