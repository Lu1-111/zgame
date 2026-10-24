extends Node
## AudioManager —— 音频容错播放（autoload 单例）
## 本期 assets/ 为空：按 id 找不到资源属正常，同一 id 只 push_warning 一次后静默返回。

const SFX_DIR := "res://assets/audio/sfx/"   ## 音效目录（按 id 同名查找）
const BGM_DIR := "res://assets/audio/bgm/"   ## 音乐目录（按 id 同名查找）
const AUDIO_EXTS: Array[String] = ["ogg", "wav", "mp3"]  ## 依次尝试的扩展名
const BGM_FADE_MIN_DB := -40.0               ## 淡出终点音量（近似静音）

var _warned: Dictionary = {}                          ## "类型/id" → true，保证同一 id 只警告一次
var _bgm_player: AudioStreamPlayer
var _sfx_players: Array[AudioStreamPlayer] = []       ## 简单 SFX 播放器池，M2 视需要扩容

func _ready() -> void:
	_bgm_player = AudioStreamPlayer.new()
	add_child(_bgm_player)

func play_sfx(id: StringName) -> void:
	## 播放一条音效；资源缺失时同一 id 只警告一次，随后静默返回
	var stream := _find_stream(SFX_DIR, id)
	if stream == null:
		_warn_missing("sfx", id, SFX_DIR)
		return
	var player := _acquire_sfx_player()
	player.stream = stream
	player.play()

func play_bgm(id: StringName) -> void:
	## 播放背景音乐；资源缺失时同一 id 只警告一次，随后静默返回
	var stream := _find_stream(BGM_DIR, id)
	if stream == null:
		_warn_missing("bgm", id, BGM_DIR)
		return
	_bgm_player.stream = stream
	_bgm_player.volume_db = 0.0
	_bgm_player.play()

func stop_bgm(fade: float = 0.5) -> void:
	## 停止背景音乐；fade 为淡出秒数（≤ 0 立即停止）
	if not _bgm_player.playing:
		return
	if fade <= 0.0:
		_bgm_player.stop()
		return
	var tween := create_tween()
	tween.tween_property(_bgm_player, "volume_db", BGM_FADE_MIN_DB, fade)
	tween.tween_callback(_bgm_player.stop)

func _find_stream(base_dir: String, id: StringName) -> AudioStream:
	## 在目录下按 id 同名查找音频资源（依次尝试 ogg/wav/mp3）；找不到返回 null
	for ext in AUDIO_EXTS:
		var path := base_dir + String(id) + "." + ext
		if ResourceLoader.exists(path):
			return load(path) as AudioStream
	return null

func _acquire_sfx_player() -> AudioStreamPlayer:
	## 取一个空闲的 SFX 播放器；全部在播则新建一个
	for p in _sfx_players:
		if not p.playing:
			return p
	var p := AudioStreamPlayer.new()
	add_child(p)
	_sfx_players.append(p)
	return p

func _warn_missing(kind: String, id: StringName, dir: String) -> void:
	## 同一 "类型/id" 只警告一次（灰盒期资源缺失属预期，不刷屏）
	var key := "%s/%s" % [kind, String(id)]
	if _warned.has(key):
		return
	_warned[key] = true
	push_warning("AudioManager: 找不到音频资源 %s:%s（%s 下无同名 ogg/wav/mp3），本期静默跳过" % [kind, String(id), dir])
