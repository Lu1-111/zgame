extends SceneTree
## 调用Godot原生Skeleton2D/Bone2D、蒙皮与AnimationPlayer，生成可编辑测试场景。
const CONFIG := "res://data/skeleton_test.json"
const OUTPUT := "res://scenes/player/skeletal/hero_skeleton_test.tscn"
const LIBRARY := "res://assets/PROCESSED/characters/CHR-01/skeleton_test/hero_bone_animations.tres"
var model: Node2D
var skeleton: Skeleton2D
var bone_nodes: Dictionary = {}
var rest_global: Dictionary = {"":Transform2D.IDENTITY}

func _initialize() -> void:
	call_deferred("_build")

func _build() -> void:
	if FileAccess.file_exists(OUTPUT) and not "--force" in OS.get_cmdline_user_args():
		print("Existing skeleton retained. Use -- --force only to regenerate from the data table.")
		quit(2)
		return
	var cfg: Dictionary = JSON.parse_string(FileAccess.get_file_as_string(CONFIG))
	model = Node2D.new()
	model.name = "HeroSkeletonTest"
	model.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	skeleton = Skeleton2D.new()
	skeleton.name = "Skeleton2D"
	_add(model,skeleton)
	for definition: Dictionary in cfg.bones:
		var node := Bone2D.new()
		node.name = str(definition.path).get_file()
		node.position = _vec(definition.position)
		node.rotation = deg_to_rad(float(definition.rotation_degrees))
		node.set_autocalculate_length_and_angle(false)
		node.length = float(definition.length)
		node.set_bone_angle(0.0)
		node.rest = node.transform
		var parent: Node = skeleton if str(definition.parent) == "" else bone_nodes[str(definition.parent)]
		_add(parent,node)
		bone_nodes[str(definition.path)] = node
		rest_global[str(definition.path)] = rest_global[str(definition.parent)]*node.rest
	for definition: Dictionary in cfg.endpoints:
		var marker := Marker2D.new()
		marker.name = str(definition.path).get_file()
		marker.position = _vec(definition.position)
		marker.rotation = deg_to_rad(float(definition.rotation_degrees))
		_add(bone_nodes[str(definition.parent)],marker)
		bone_nodes[str(definition.path)] = marker
	var mount := Marker2D.new()
	mount.name = "WeaponMount"
	mount.position = Vector2(float(cfg.runtime.hand_mount_offset),0)
	_add(bone_nodes["Root/Torso/FrontUpperArm/FrontForearm/FrontHand"],mount)
	var meshes := Node2D.new()
	meshes.name = "Meshes"
	_add(model,meshes)
	for definition: Dictionary in cfg.meshes:
		var mesh := Polygon2D.new()
		mesh.name = str(definition.name)
		mesh.texture = load(str(cfg.sources[str(definition.source)].path))
		mesh.z_index = int(definition.z)
		mesh.color = Color(float(definition.shade),float(definition.shade),float(definition.shade),1)
		var points := PackedVector2Array()
		var uv := PackedVector2Array()
		for point: Array in definition.polygon:
			points.append(_vec(point)-_vec(cfg.source_anchor) if str(definition.space) == "reference" else rest_global[str(definition.bone)]*_vec(point))
		for point: Array in definition.uv:
			uv.append(_vec(point)+_vec(cfg.sources[str(definition.source)].origin))
		mesh.polygon = points
		mesh.uv = uv
		mesh.skeleton = NodePath("../../Skeleton2D")
		if definition.has("blend_root"):
			var root_weights := PackedFloat32Array()
			var torso_weights := PackedFloat32Array()
			for weight in definition.blend_root:
				root_weights.append(float(weight))
				torso_weights.append(1.0-float(weight))
			mesh.add_bone(NodePath("Root"),root_weights)
			mesh.add_bone(NodePath(str(definition.bone)),torso_weights)
		else:
			var weights := PackedFloat32Array()
			weights.resize(points.size())
			weights.fill(1)
			mesh.add_bone(NodePath(str(definition.bone)),weights)
		_add(meshes,mesh)
	var controls := Node2D.new()
	controls.name = "Controls"
	_add(model,controls)
	for entry in [["Grip",cfg.defaults["Controls/Grip:position"]],["FrontTarget",cfg.controls.FrontTarget],["BackTarget",cfg.controls.BackTarget],["BackFoot",cfg.defaults["Controls/BackFoot:position"]],["FrontFoot",cfg.defaults["Controls/FrontFoot:position"]]]:
		var marker := Marker2D.new()
		marker.name = entry[0]
		marker.position = _vec(entry[1])
		_add(controls,marker)
	var library := AnimationLibrary.new()
	for name: String in cfg.clips:
		var spec: Dictionary = cfg.clips[name]
		var animation := Animation.new()
		animation.resource_name = name
		animation.length = float(spec.length)
		animation.loop_mode = Animation.LOOP_LINEAR if bool(spec.loop) else Animation.LOOP_NONE
		for path: String in cfg.defaults:
			var track := animation.add_track(Animation.TYPE_VALUE)
			animation.track_set_path(track,NodePath(path))
			animation.track_set_interpolation_type(track,Animation.INTERPOLATION_LINEAR)
			var keys: Array = spec.tracks.get(path,[[0,cfg.defaults[path]],[1,cfg.defaults[path]]])
			for key: Array in keys:
				var value: Variant = _vec(key[1]) if key[1] is Array else deg_to_rad(float(key[1]))
				animation.track_insert_key(track,float(key[0])*float(spec.length),value)
		library.add_animation(StringName(name),animation)
	var reset := Animation.new()
	reset.length = 0.001
	for path: String in cfg.defaults:
		var track := reset.add_track(Animation.TYPE_VALUE)
		reset.track_set_path(track,NodePath(path))
		var value: Variant = _vec(cfg.defaults[path]) if cfg.defaults[path] is Array else deg_to_rad(float(cfg.defaults[path]))
		reset.track_insert_key(track,0,value)
	library.add_animation(&"RESET",reset)
	var lib_error := ResourceSaver.save(library,LIBRARY)
	if lib_error != OK:
		push_error("Cannot save skeletal animation library: %d" % lib_error)
		quit(1)
		return
	library.take_over_path(LIBRARY)
	var player := AnimationPlayer.new()
	player.name = "AnimationPlayer"
	player.root_node = NodePath("..")
	player.callback_mode_process = AnimationMixer.ANIMATION_CALLBACK_MODE_PROCESS_MANUAL
	player.add_animation_library(&"",library)
	_add(model,player)
	var weapon := Node2D.new()
	weapon.name = "WeaponVisual"
	weapon.z_index = 3
	if ResourceLoader.exists("res://scripts/player/skeletal_weapon.gd"):
		weapon.set_script(load("res://scripts/player/skeletal_weapon.gd"))
	_add(model,weapon)
	root.add_child(model)
	current_scene = model
	var stack := SkeletonModificationStack2D.new()
	stack.resource_local_to_scene = true
	stack.enabled = true
	for spec: Dictionary in cfg.ik:
		var ik := SkeletonModification2DTwoBoneIK.new()
		ik.resource_local_to_scene = true
		ik.execution_mode = 0
		ik.set_joint_one_bone2d_node(NodePath(spec.upper))
		ik.set_joint_two_bone2d_node(NodePath(spec.lower))
		ik.target_nodepath = NodePath("../Controls/"+str(spec.target))
		ik.flip_bend_direction = bool(spec.flip)
		ik.target_maximum_distance = float(spec.maximum_distance)
		ik.target_minimum_distance = float(spec.minimum_distance)
		stack.add_modification(ik)
	skeleton.set_modification_stack(stack)
	for tick in 3:
		await process_frame
	if ResourceLoader.exists("res://scripts/player/skeletal_hero_rig.gd"):
		model.set_script(load("res://scripts/player/skeletal_hero_rig.gd"))
	else:
		print("Runtime controller pending; raw native skeleton exported.")
	var packed := PackedScene.new()
	var pack_error := packed.pack(model)
	var scene_error := ResourceSaver.save(packed,OUTPUT) if pack_error == OK else pack_error
	print("Native skeleton: %d bones, %d weighted meshes, %d clips; scene=%d" % [skeleton.get_bone_count(),meshes.get_child_count(),cfg.clips.size(),scene_error])
	quit(0 if scene_error == OK else 1)

func _add(parent: Node, child: Node) -> void:
	parent.add_child(child)
	child.owner = model

func _vec(value: Array) -> Vector2:
	return Vector2(value[0],value[1])
