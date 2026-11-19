extends Node
## 通过原有暂停菜单离开试玩时，也恢复进入前的旅途。
const SESSION := preload("res://test/scripts/forest_candidates/session.gd")

func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS

func _process(_delta: float) -> void:
	if not get_tree().root.has_meta(SESSION.KEY):
		queue_free()
		return
	var scene := get_tree().current_scene
	if scene == null or bool(scene.get_meta("forest_candidate",false)):
		return
	var session: Dictionary = get_tree().root.get_meta(SESSION.KEY)
	GameState.load_from_dict(session.original)
	get_tree().root.remove_meta(SESSION.KEY)
	queue_free()
