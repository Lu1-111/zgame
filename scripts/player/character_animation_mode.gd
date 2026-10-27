class_name CharacterAnimationMode
extends RefCounted
## 仅在本次进程保存展示方案；不读写角色存档和用户设置。

const CONFIG_PATH := "res://data/skeleton_test.json"
const FRAMES := "frames"
const SKELETON := "skeleton"
static var _initialized := false
static var _backend := FRAMES
static var _config: Dictionary = {}
static var _reported_failure := false


## 读取骨架实验配置，缺少配置时使用逐帧方案。
static func configuration() -> Dictionary:
	_initialize()
	return _config


## 返回进程内当前展示方案，首次读取时接受命令行覆盖。
static func current() -> String:
	_initialize()
	return _backend


## 切换本进程展示方案，跨房间沿用但不写入存档。
static func select(mode: String) -> void:
	_initialize()
	_backend = SKELETON if mode == SKELETON else FRAMES


## 返回界面使用的展示方案名称。
static func display_name(mode: String = "") -> String:
	return "骨骼动画 · 测试版" if (current() if mode.is_empty() else mode) == SKELETON else "原逐帧动画"


## 骨架资源不可用时只报告一次并回退原逐帧方案。
static func report_fallback() -> void:
	select(FRAMES)
	if not _reported_failure:
		_reported_failure = true
		push_warning("骨骼动画测试资源不可用，已恢复原逐帧动画。")


static func _initialize() -> void:
	if _initialized:
		return
	_initialized = true
	if FileAccess.file_exists(CONFIG_PATH):
		var parsed: Variant = JSON.parse_string(FileAccess.get_file_as_string(CONFIG_PATH))
		if parsed is Dictionary:
			_config = parsed
	var integration: Dictionary = _config.get("integration", {})
	_backend = SKELETON if str(integration.get("default_backend", FRAMES)) == SKELETON else FRAMES
	for argument in OS.get_cmdline_user_args():
		if argument.begins_with("--animation-backend="):
			var requested := argument.trim_prefix("--animation-backend=")
			if requested in [FRAMES, SKELETON]:
				_backend = requested
