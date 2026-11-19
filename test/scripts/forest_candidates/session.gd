extends RefCounted
## 备选地图试玩只保存本进程评审状态；离开后恢复原旅途，不写正式存档。
const MANIFEST := "res://test/data/forest_candidates/manifest.json"
const RULES := "res://test/data/forest_candidates_rules.json"
const KEY := &"forest_candidate_session"
static var _rules: Dictionary = {}
static var _manifest: Dictionary = {}

## 读取统一的试玩参数。
static func rules() -> Dictionary:
	if _rules.is_empty():
		_rules = JSON.parse_string(FileAccess.get_file_as_string(RULES))
	return _rules

## 返回十个可独立打开的实际场景。
static func candidates() -> Array:
	if _manifest.is_empty():
		_manifest = JSON.parse_string(FileAccess.get_file_as_string(MANIFEST))
	return _manifest.candidates

## 首次进入时保留当前旅途，后续切图共用本次试玩进度。
static func begin(tree: SceneTree) -> Dictionary:
	if not tree.root.has_meta(KEY):
		tree.root.set_meta(KEY,{"original":GameState.to_save_dict(),"maps":{},"double_jump":false,"choices":{},"arrival":{}})
		var guard := Node.new()
		guard.name = "ForestCandidateSessionGuard"
		guard.set_script(load("res://test/scripts/forest_candidates/session_guard.gd"))
		tree.root.add_child.call_deferred(guard)
	return tree.root.get_meta(KEY)

## 获取一张备选地图的机关、宝箱与清场记录。
static func progress(tree: SceneTree, id: String) -> Dictionary:
	var session := begin(tree)
	if not session.maps.has(id):
		session.maps[id] = {"flags":{},"killed":[],"opened":[],"values":{},"checkpoint":[]}
	return session.maps[id]

## 按同组已选版本解析新图接口，未选过的组沿用当前A/B版本。
static func target_id(tree: SceneTree, group: String, variant: String) -> String:
	return str(begin(tree).choices.get(group,group+variant))

## 切换试玩场景；接口落点由目标场景自己的平台数据决定。
static func enter(tree: SceneTree, id: String, port: String = "") -> void:
	var session := begin(tree)
	session.choices[id.left(2)] = id
	session.arrival = {"candidate":id,"port":port}
	GameUI._force_close()
	tree.paused = false
	tree.change_scene_to_file("res://test/scenes/forest_candidates/forest_%s.tscn" % id)

## 返回正式标题前恢复原旅途，避免试玩装备与击杀写回正式进度。
static func finish(tree: SceneTree) -> void:
	if tree.root.has_meta(KEY):
		var session: Dictionary = tree.root.get_meta(KEY)
		GameState.load_from_dict(session.original)
		tree.root.remove_meta(KEY)
	GameUI._force_close()
	tree.paused = false
	tree.change_scene_to_file("res://scenes/main.tscn")
