extends Node2D
## 标题屏（M0）→ M1 试玩场入口：Enter / 空格 / 鼠标左键 进入；Esc 退出游戏。
## TODO(M2)：接入 SceneRouter 正式主菜单流转（开始/读档/设置）。

const ARENA_SCENE := "res://scenes/rooms/camp_01.tscn"


func _unhandled_input(event: InputEvent) -> void:
	if event is InputEventKey and event.pressed and event.physical_keycode == KEY_F2:
		SceneRouter.change_scene("res://scenes/levels/combat_enemy_arena.tscn")
	elif event is InputEventKey and event.pressed and event.physical_keycode == KEY_F3:
		SceneRouter.change_scene("res://scenes/levels/enemy_arena.tscn")
	elif event.is_action_pressed(&"pause"):
		get_tree().quit()
	elif event.is_action_pressed(&"attack") \
			or event.is_action_pressed(&"jump") \
			or event.is_action_pressed(&"ui_accept"):
		SceneRouter.change_scene(ARENA_SCENE)
