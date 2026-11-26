extends Node3D

# KINGDOMS OF THE DESERT
# Godot 4.3

# --------------------------------------------------
# QUALITY SWITCHES (turn off on weak phones)
# --------------------------------------------------
const ENABLE_FOG := true
const ENABLE_MSAA := true
const ENABLE_DISTANT_DUNES := true
const HOUSE_FORCE_DOUBLE_SIDED := true

# --------------------------------------------------
# CAMERA
# --------------------------------------------------
var camera_pivot: Node3D
var camera_pitch: Node3D
var camera: Camera3D
var sun: DirectionalLight3D
var world_environment: WorldEnvironment

var zoom_distance := 48.0
var mouse_down := false
var mouse_dragged := false
var mouse_start := Vector2.ZERO
var panning := false
var touch_points: Dictionary = {}
var touch_starts: Dictionary = {}
var consumed_touches: Dictionary = {}

const ZOOM_MIN := 12.0
const ZOOM_MAX := 100.0
const CAMERA_SPEED := 30.0
const CAMERA_LIMIT := 320.0
const TOUCH_ROTATION_SPEED := 0.004
const TOUCH_ZOOM_SPEED := 0.06

# --------------------------------------------------
# WORLD AND BUILDING
# --------------------------------------------------
var world_config: Dictionary = {}
var placed_objects: Array[Node3D] = []
var selected_building := ""
var selected_object: Node3D
var house_fallback_used := false
var model_path_cache: Dictionary = {}

const HOUSE_TARGET_HEIGHT := 8.0
const HOUSE_MAX_FOOTPRINT := 16.0
const CASTLE_TARGET_HEIGHT := 25.0
const CASTLE_MAX_FOOTPRINT := 40.0
# false = the castle keeps its original size exactly as before.
# true  = the castle is auto-fitted (height 25, centered, sitting on the ground).
const CASTLE_AUTO_FIT := false

const HOUSE_SCENE_CANDIDATES = [
	"res://scenes/House.tscn",
	"res://scenes/house.tscn",
	"res://scenes/House.glb",
	"res://scenes/house.glb",
	"res://assets/models/House.glb",
	"res://assets/models/house.glb",
]
const CASTLE_SCENE_CANDIDATES = [
	"res://scenes/Castle.tscn",
	"res://scenes/castle.tscn",
	"res://scenes/Castle.glb",
	"res://scenes/castle.glb",
	"res://assets/models/Castle.glb",
	"res://assets/models/castle.glb",
]
const MODEL_EXTENSIONS = ["tscn", "scn", "glb", "gltf"]

# --------------------------------------------------
# 3D OBJECT GIZMO
# --------------------------------------------------
var gizmo_root: Node3D
var gizmo_handles: Dictionary = {}        # name -> local position (Vector3)
var gizmo_handle_nodes: Dictionary = {}   # name -> Node3D (billboard)
var gizmo_ring: MeshInstance3D
var gizmo_ghost_ring: MeshInstance3D
var gizmo_ticks: Node3D
var gizmo_disc: MeshInstance3D
var gizmo_front_line: MeshInstance3D
var gizmo_front_arrow: MeshInstance3D
var gizmo_stem: MeshInstance3D
var gizmo_local_bounds := AABB()
var gizmo_radius := 4.0
var gizmo_height := 6.0

var gizmo_dragging := false
var gizmo_operation := ""
var gizmo_touch_index := -1
var gizmo_start_screen := Vector2.ZERO
var gizmo_start_position := Vector3.ZERO
var gizmo_start_rotation := 0.0
var gizmo_start_scale := Vector3.ONE
var gizmo_start_ground := Vector3.ZERO
var gizmo_move_plane_y := 0.0
var gizmo_start_angle := 0.0
var gizmo_last_angle := 0.0
var gizmo_rotation_accum := 0.0
var gizmo_start_distance := 1.0
var delete_armed_until := 0

const GIZMO_HANDLE_PIXELS := 30.0   # handle radius on screen (constant size)
const GIZMO_HIT_RADIUS := 56.0      # touch radius in pixels
const GIZMO_MIN_SCALE := 0.08
const GIZMO_MAX_SCALE := 8.0
const GIZMO_RING_LIFT := 0.18
const GIZMO_MOVE_MARGIN := 2.2

# --------------------------------------------------
# LANGUAGE AND UI
# --------------------------------------------------
var current_language := "ar"
var arabic_font: FontFile
var canvas: CanvasLayer
var main_menu: PanelContainer
var settings_panel: PanelContainer
var build_panel: PanelContainer
var status_label: Label
var localized_controls: Array[Dictionary] = []
var is_game_started := false

# --------------------------------------------------
# SETTINGS
# --------------------------------------------------
var sunlight_strength := 1.0
var ambient_strength := 0.6
var master_volume := 0.8
var music_volume := 0.7
var effects_volume := 0.8
var music_bus := -1
var effects_bus := -1


# --------------------------------------------------
# READY
# --------------------------------------------------
func _ready():
	load_world_config()
	load_arabic_font()
	setup_audio_buses()
	create_environment()
	create_terrain()
	if ENABLE_DISTANT_DUNES:
		create_distant_dunes()
	create_lighting()
	create_camera()
	create_interface()
	show_main_menu()
	print("Kingdoms of the Desert ready")


# --------------------------------------------------
# LANGUAGE
# --------------------------------------------------
func load_arabic_font():
	var path := "res://assets/fonts/NotoSansArabic-Regular.ttf"
	if ResourceLoader.exists(path):
		arabic_font = load(path) as FontFile
		if arabic_font == null:
			push_warning("Arabic font could not be loaded.")
	else:
		push_warning("Arabic font not found: " + path)


func tr_text(arabic: String, english: String) -> String:
	return arabic if current_language == "ar" else english


func apply_font(control: Control):
	if arabic_font != null:
		control.add_theme_font_override("font", arabic_font)


func register_text(control: Control, arabic: String, english: String):
	localized_controls.append({"control": control, "ar": arabic, "en": english})
	control.text = tr_text(arabic, english)
	apply_font(control)


func set_language(language: String):
	current_language = language
	for item in localized_controls:
		var control: Control = item["control"]
		if is_instance_valid(control):
			control.text = tr_text(item["ar"], item["en"])
	update_status_language()


func toggle_language():
	set_language("en" if current_language == "ar" else "ar")


func update_status_language():
	if not is_instance_valid(status_label):
		return
	if selected_building == "castle":
		status_label.text = tr_text("اختر مكان القلعة", "Choose castle location")
	elif selected_building == "house":
		status_label.text = tr_text("اختر مكان المنزل", "Choose house location")
	elif selected_building == "palm":
		status_label.text = tr_text("اختر مكان النخلة", "Choose palm location")
	elif is_instance_valid(selected_object):
		status_label.text = tr_text("أخضر: تحريك | برتقالي: تدوير | أزرق: تكبير | أحمر: حذف", "Green: move | Orange: rotate | Blue: scale | Red: delete")
	else:
		status_label.text = tr_text("اختر عنصرًا للبناء أو حدد مبنى موجودًا", "Choose an object to build or select an existing one.")


# --------------------------------------------------
# WORLD CONFIG AND MATERIALS
# --------------------------------------------------
func load_world_config():
	var path := "res://data/world_config.json"
	if not FileAccess.file_exists(path):
		return
	var file := FileAccess.open(path, FileAccess.READ)
	if file == null:
		return
	var parsed = JSON.parse_string(file.get_as_text())
	if parsed is Dictionary:
		world_config = parsed.get("world", {})


func make_material(color: Color, roughness := 0.9) -> StandardMaterial3D:
	var material := StandardMaterial3D.new()
	material.albedo_color = color
	material.roughness = roughness
	return material


# --------------------------------------------------
# ENVIRONMENT AND TERRAIN
# --------------------------------------------------
func create_environment():
	world_environment = WorldEnvironment.new()
	world_environment.name = "WorldEnvironment"
	var environment := Environment.new()
	var sky := Sky.new()
	var sky_material := ProceduralSkyMaterial.new()
	sky_material.sky_top_color = Color(0.16, 0.38, 0.68)
	sky_material.sky_horizon_color = Color(0.88, 0.82, 0.70)
	sky_material.sky_curve = 0.18
	sky_material.ground_bottom_color = Color(0.80, 0.70, 0.54)
	sky_material.ground_horizon_color = Color(0.88, 0.82, 0.70)
	sky_material.ground_curve = 0.05
	sky.sky_material = sky_material
	environment.background_mode = Environment.BG_SKY
	environment.sky = sky
	environment.ambient_light_source = Environment.AMBIENT_SOURCE_SKY
	environment.ambient_light_energy = ambient_strength
	environment.tonemap_mode = Environment.TONE_MAPPER_ACES
	environment.adjustment_enabled = true
	environment.adjustment_contrast = 1.06
	environment.adjustment_saturation = 1.10
	if ENABLE_FOG:
		# Warm desert haze that melts the terrain edge into the horizon.
		environment.fog_enabled = true
		environment.fog_light_color = Color(0.88, 0.81, 0.68)
		environment.fog_density = 0.0011
		environment.fog_sky_affect = 0.0
	# SSAO only exists in the Forward+ renderer; skipped elsewhere.
	if RenderingServer.get_current_rendering_method() == "forward_plus":
		environment.ssao_enabled = true
		environment.ssao_radius = 2.0
		environment.ssao_intensity = 1.5
	world_environment.environment = environment
	add_child(world_environment)
	if ENABLE_MSAA:
		get_viewport().msaa_3d = Viewport.MSAA_4X


func create_terrain():
	var ground := MeshInstance3D.new()
	ground.name = "DesertTerrain"
	var plane := PlaneMesh.new()
	plane.size = Vector2(3000.0, 3000.0)
	plane.subdivide_width = 150
	plane.subdivide_depth = 150
	ground.mesh = plane
	ground.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	var material := StandardMaterial3D.new()
	material.albedo_color = Color.WHITE
	var diffuse = load("res://assets/materials/sand_diffuse.png")
	if diffuse:
		material.albedo_texture = diffuse
	else:
		material.albedo_color = Color(0.80, 0.68, 0.47)
	material.texture_filter = BaseMaterial3D.TEXTURE_FILTER_LINEAR_WITH_MIPMAPS_ANISOTROPIC
	material.uv1_scale = Vector3(100.0, 100.0, 1.0)
	var normal_map = load("res://assets/materials/sand_normal.png")
	if normal_map:
		material.normal_enabled = true
		material.normal_texture = normal_map
		material.normal_scale = 0.35
	var roughness_map = load("res://assets/materials/sand_roughness.png")
	if roughness_map:
		material.roughness = 1.0
		material.roughness_texture = roughness_map
	var ao_map = load("res://assets/materials/sand_ao.png")
	if ao_map:
		material.ao_enabled = true
		material.ao_texture = ao_map
	ground.material_override = material
	add_child(ground)


func create_distant_dunes():
	# Big sand dunes on the horizon: gives depth like a real strategy game map.
	var rng := RandomNumberGenerator.new()
	rng.seed = 20260
	var container := Node3D.new()
	container.name = "DistantDunes"
	add_child(container)
	var sand := make_material(Color(0.82, 0.69, 0.47), 1.0)
	var sphere := SphereMesh.new()
	sphere.radius = 1.0
	sphere.height = 2.0
	sphere.radial_segments = 32
	sphere.rings = 16
	for ring_index in range(2):
		var count := 26 + ring_index * 10
		var base_distance := 420.0 + float(ring_index) * 300.0
		var size_boost := 1.0 + float(ring_index) * 0.6
		for i in range(count):
			var angle := TAU * float(i) / float(count) + rng.randf_range(-0.08, 0.08)
			var distance := base_distance + rng.randf_range(-60.0, 80.0)
			var dune := MeshInstance3D.new()
			dune.mesh = sphere
			dune.material_override = sand
			dune.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
			var width := rng.randf_range(120.0, 220.0) * size_boost
			dune.scale = Vector3(width, rng.randf_range(18.0, 46.0) * size_boost, width * rng.randf_range(0.5, 0.9))
			dune.position = Vector3(cos(angle) * distance, -2.0, sin(angle) * distance)
			dune.rotation.y = rng.randf_range(0.0, TAU)
			container.add_child(dune)


# --------------------------------------------------
# MODEL FINDING, BOUNDS AND FITTING
# --------------------------------------------------
func find_model_path(keyword: String, preferred: Array) -> String:
	if model_path_cache.has(keyword):
		return str(model_path_cache[keyword])
	var result := ""
	for candidate in preferred:
		if ResourceLoader.exists(str(candidate)):
			result = str(candidate)
			break
	if result == "":
		# Case-insensitive search for any scene/model with the keyword in its name.
		var matches: Array = []
		collect_model_files("res://", keyword.to_lower(), 0, matches)
		matches.sort_custom(func(a, b): return a["rank"] < b["rank"])
		for entry in matches:
			if ResourceLoader.exists(str(entry["path"])):
				result = str(entry["path"])
				break
	model_path_cache[keyword] = result
	if result == "":
		push_warning("No model found for keyword: " + keyword)
	else:
		print("Model for '", keyword, "': ", result)
	return result


func collect_model_files(directory: String, keyword: String, depth: int, matches: Array):
	if depth > 5:
		return
	for file_name in DirAccess.get_files_at(directory):
		var clean: String = file_name
		if clean.ends_with(".remap"):
			clean = clean.trim_suffix(".remap")
		if clean.ends_with(".import"):
			clean = clean.trim_suffix(".import")
		var rank := MODEL_EXTENSIONS.find(clean.get_extension().to_lower())
		if rank == -1:
			continue
		if clean.get_basename().to_lower().find(keyword) == -1:
			continue
		matches.append({"path": directory.path_join(clean), "rank": rank})
	for sub_directory in DirAccess.get_directories_at(directory):
		if sub_directory.begins_with(".") or sub_directory == "addons":
			continue
		collect_model_files(directory.path_join(sub_directory), keyword, depth + 1, matches)


func load_model_instance(keyword: String, preferred: Array) -> Node3D:
	var path := find_model_path(keyword, preferred)
	if path == "":
		return null
	var packed := load(path) as PackedScene
	if packed == null:
		push_warning("Could not load as scene: " + path)
		return null
	var instance := packed.instantiate()
	if instance is Node3D:
		return instance as Node3D
	push_warning("Model root is not Node3D: " + path)
	instance.free()
	return null


# Bounds of every visible mesh, expressed in the local space of `root`.
# Returns an empty AABB (size zero) when the root has no meshes.
func get_model_bounds(root: Node3D) -> AABB:
	var result := AABB()
	var found := false
	var inverse := root.global_transform.affine_inverse()
	for node in root.find_children("*", "MeshInstance3D", true, false):
		var mesh_node := node as MeshInstance3D
		if mesh_node == null or mesh_node.mesh == null:
			continue
		if not mesh_node.is_visible_in_tree():
			continue
		var local_transform := inverse * mesh_node.global_transform
		var transformed := local_transform * mesh_node.get_aabb()
		if not found:
			result = transformed
			found = true
		else:
			result = result.merge(transformed)
	return result


# Scales the model so its height = target_height, centers it on the holder
# and places its lowest point exactly on the holder's origin (the ground).
# Works with any rotation/scale the model already has.
func fit_model_to_holder(holder: Node3D, model: Node3D, target_height: float, max_footprint: float) -> bool:
	var bounds := get_model_bounds(holder)
	if not bounds.size.is_finite() or bounds.size.y < 0.001:
		push_warning("Model has no usable bounds: " + str(bounds))
		return false
	var factor := target_height / bounds.size.y
	var footprint := maxf(bounds.size.x, bounds.size.z) * factor
	if footprint > max_footprint:
		factor *= max_footprint / footprint
	var center := Vector3(bounds.position.x + bounds.size.x * 0.5, bounds.position.y, bounds.position.z + bounds.size.z * 0.5)
	var fit := Transform3D(Basis.from_scale(Vector3.ONE * factor), -center * factor)
	model.transform = fit * model.transform
	print("Fitted model. bounds=", bounds, " factor=", factor)
	return true


func make_double_sided(root: Node):
	for node in root.find_children("*", "MeshInstance3D", true, false):
		var mesh_node := node as MeshInstance3D
		if mesh_node == null or mesh_node.mesh == null:
			continue
		for surface in range(mesh_node.mesh.get_surface_count()):
			var material := mesh_node.get_active_material(surface)
			if material is BaseMaterial3D:
				var copy := material.duplicate() as BaseMaterial3D
				copy.cull_mode = BaseMaterial3D.CULL_DISABLED
				mesh_node.set_surface_override_material(surface, copy)


func get_object_metrics(object: Node3D, bounds: AABB) -> Dictionary:
	var result := {
		"radius": 3.0,
		"height": 4.0,
		"center": object.global_position + Vector3.UP * 2.0,
	}
	if bounds.size.length() < 0.001:
		return result
	var object_scale := object.global_transform.basis.get_scale().abs()
	var max_x := maxf(absf(bounds.position.x), absf(bounds.end.x)) * object_scale.x
	var max_z := maxf(absf(bounds.position.z), absf(bounds.end.z)) * object_scale.z
	result["radius"] = clampf(Vector2(max_x, max_z).length() + 0.6, 2.5, 90.0)
	result["height"] = maxf(bounds.end.y * object_scale.y, 1.0)
	result["center"] = object.global_transform * bounds.get_center()
	return result


# --------------------------------------------------
# PLACEABLE MODELS
# --------------------------------------------------
func create_castle(position_value: Vector3) -> Node3D:
	var model := load_model_instance("castle", CASTLE_SCENE_CANDIDATES)
	if model == null:
		push_error("Castle scene not found")
		return null
	var holder := Node3D.new()
	holder.name = "PlayerCastle"
	add_child(holder)
	holder.global_position = position_value
	holder.add_child(model)
	if CASTLE_AUTO_FIT:
		fit_model_to_holder(holder, model, CASTLE_TARGET_HEIGHT, CASTLE_MAX_FOOTPRINT)
	placed_objects.append(holder)
	return holder


func create_real_house(position_value: Vector3) -> Node3D:
	house_fallback_used = false
	var holder := Node3D.new()
	holder.name = "PlayerHouse"
	add_child(holder)
	holder.global_position = position_value
	var model := load_model_instance("house", HOUSE_SCENE_CANDIDATES)
	if model != null:
		holder.add_child(model)
		if HOUSE_FORCE_DOUBLE_SIDED:
			make_double_sided(model)
		if not fit_model_to_holder(holder, model, HOUSE_TARGET_HEIGHT, HOUSE_MAX_FOOTPRINT):
			holder.remove_child(model)
			model.free()
			model = null
	if model == null:
		# The real house could not be used: build a desert house so something always appears.
		house_fallback_used = true
		holder.add_child(build_procedural_house())
	placed_objects.append(holder)
	return holder


func add_box(parent: Node3D, position_value: Vector3, size_value: Vector3, material: Material) -> MeshInstance3D:
	var mesh := BoxMesh.new()
	mesh.size = size_value
	var instance := MeshInstance3D.new()
	instance.mesh = mesh
	instance.material_override = material
	instance.position = position_value
	parent.add_child(instance)
	return instance


func build_procedural_house() -> Node3D:
	var root := Node3D.new()
	root.name = "ProceduralHouse"
	var wall := make_material(Color(0.82, 0.68, 0.46), 0.95)
	var trim := make_material(Color(0.62, 0.47, 0.30), 0.95)
	var dark := make_material(Color(0.20, 0.12, 0.07), 0.9)
	var dome_material := make_material(Color(0.74, 0.56, 0.30), 0.7)
	add_box(root, Vector3(0, 2.6, 0), Vector3(10.0, 5.2, 8.0), wall)
	add_box(root, Vector3(0, 5.4, 0), Vector3(10.6, 0.4, 8.6), trim)
	add_box(root, Vector3(-1.5, 6.5, -0.5), Vector3(4.4, 1.8, 4.2), wall)
	# Door (front = +Z) with an arch.
	add_box(root, Vector3(0, 1.4, 4.02), Vector3(1.8, 2.8, 0.2), dark)
	var arch_mesh := CylinderMesh.new()
	arch_mesh.top_radius = 0.9
	arch_mesh.bottom_radius = 0.9
	arch_mesh.height = 0.2
	var arch := MeshInstance3D.new()
	arch.mesh = arch_mesh
	arch.material_override = dark
	arch.rotation_degrees.x = 90.0
	arch.position = Vector3(0, 2.8, 4.02)
	root.add_child(arch)
	add_box(root, Vector3(-3.3, 2.9, 4.02), Vector3(1.1, 1.3, 0.2), dark)
	add_box(root, Vector3(3.3, 2.9, 4.02), Vector3(1.1, 1.3, 0.2), dark)
	add_box(root, Vector3(-1.5, 6.6, 1.65), Vector3(0.9, 1.0, 0.2), dark)
	var dome_mesh := SphereMesh.new()
	dome_mesh.radius = 1.5
	dome_mesh.height = 3.0
	dome_mesh.radial_segments = 24
	dome_mesh.rings = 12
	var dome := MeshInstance3D.new()
	dome.mesh = dome_mesh
	dome.material_override = dome_material
	dome.position = Vector3(-1.5, 7.4, -0.5)
	root.add_child(dome)
	return root


# A palm tree built from a curved segmented trunk and drooping fronds.
func create_palm(position_value: Vector3) -> Node3D:
	var palm := Node3D.new()
	palm.name = "PlayerPalm"
	add_child(palm)
	palm.global_position = position_value
	var trunk_dark := make_material(Color(0.33, 0.20, 0.10))
	var trunk_light := make_material(Color(0.43, 0.28, 0.15))
	var leaf_material := make_material(Color(0.14, 0.36, 0.12), 0.8)
	leaf_material.cull_mode = BaseMaterial3D.CULL_DISABLED
	var segment_count := 6
	var segment_height := 1.0
	for i in range(segment_count):
		var t0 := float(i) / float(segment_count)
		var t1 := float(i + 1) / float(segment_count)
		var segment_mesh := CylinderMesh.new()
		segment_mesh.bottom_radius = lerpf(0.42, 0.24, t0)
		segment_mesh.top_radius = lerpf(0.42, 0.24, t1)
		segment_mesh.height = segment_height * 1.04
		segment_mesh.radial_segments = 14
		var segment := MeshInstance3D.new()
		segment.mesh = segment_mesh
		segment.material_override = trunk_dark if i % 2 == 0 else trunk_light
		segment.position = Vector3(0.018 * float(i * i) + 0.01, segment_height * (float(i) + 0.5), 0.0)
		palm.add_child(segment)
	var crown := Node3D.new()
	crown.position = Vector3(0.018 * float(segment_count * segment_count), segment_height * float(segment_count), 0.0)
	palm.add_child(crown)
	var frond_count := 11
	for i in range(frond_count):
		var pivot := Node3D.new()
		pivot.rotation.y = TAU * float(i) / float(frond_count)
		crown.add_child(pivot)
		var parent_node: Node3D = pivot
		var lift_bias := 4.0 * sin(float(i) * 2.3)
		for j in range(4):
			var piece := Node3D.new()
			piece.position.x = 0.0 if j == 0 else 1.1
			piece.rotation.z = deg_to_rad(24.0 + lift_bias) if j == 0 else deg_to_rad(-17.0)
			parent_node.add_child(piece)
			var leaf_mesh := BoxMesh.new()
			leaf_mesh.size = Vector3(1.15, 0.05, lerpf(0.62, 0.22, float(j) / 3.0))
			var leaf := MeshInstance3D.new()
			leaf.mesh = leaf_mesh
			leaf.position.x = 0.55
			leaf.material_override = leaf_material
			piece.add_child(leaf)
			parent_node = piece
	placed_objects.append(palm)
	return palm


# --------------------------------------------------
# USER INTERFACE HELPERS
# --------------------------------------------------
func create_interface():
	canvas = CanvasLayer.new()
	canvas.name = "GameInterface"
	add_child(canvas)
	create_main_menu()
	create_settings_panel()
	create_build_panel()


func make_panel(parent: Node, panel_name: String, position_value: Vector2, width: float) -> PanelContainer:
	var panel := PanelContainer.new()
	panel.name = panel_name
	panel.position = position_value
	panel.custom_minimum_size = Vector2(width, 0)
	parent.add_child(panel)
	return panel


func make_layout(parent: Control) -> VBoxContainer:
	var layout := VBoxContainer.new()
	layout.add_theme_constant_override("separation", 8)
	parent.add_child(layout)
	return layout


func make_button(parent: VBoxContainer, node_name: String, arabic: String, english: String, callback: Callable) -> Button:
	var button := Button.new()
	button.name = node_name
	button.custom_minimum_size = Vector2(220, 44)
	register_text(button, arabic, english)
	parent.add_child(button)
	button.pressed.connect(callback)
	return button


func make_label(parent: VBoxContainer, node_name: String, arabic: String, english: String) -> Label:
	var label := Label.new()
	label.name = node_name
	label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	register_text(label, arabic, english)
	parent.add_child(label)
	return label


# --------------------------------------------------
# MAIN MENU
# --------------------------------------------------
func create_main_menu():
	main_menu = make_panel(canvas, "MainMenu", Vector2(20, 20), 300)
	main_menu.set_anchors_and_offsets_preset(Control.PRESET_CENTER)
	var content := make_layout(main_menu)
	make_label(content, "Title", "ممالك الصحراء", "KINGDOMS OF THE DESERT")
	make_button(content, "Start", "بدء اللعبة", "START GAME", start_game)
	make_button(content, "Settings", "الإعدادات", "SETTINGS", open_settings)
	make_button(content, "Exit", "إغلاق القائمة", "CLOSE MENU", close_main_menu)


func show_main_menu():
	main_menu.visible = true
	settings_panel.visible = false
	build_panel.visible = false
	is_game_started = false


func start_game():
	main_menu.visible = false
	settings_panel.visible = false
	build_panel.visible = true
	is_game_started = true
	update_status_language()


func close_main_menu():
	main_menu.visible = false


# --------------------------------------------------
# SETTINGS
# --------------------------------------------------
func create_settings_panel():
	settings_panel = make_panel(canvas, "SettingsPanel", Vector2(340, 20), 300)
	var scroll := ScrollContainer.new()
	scroll.custom_minimum_size = Vector2(280, 380)
	settings_panel.add_child(scroll)
	var content := VBoxContainer.new()
	content.add_theme_constant_override("separation", 8)
	scroll.add_child(content)
	make_label(content, "SettingsTitle", "إعدادات اللعبة", "GAME SETTINGS")
	make_button(content, "Language", "تغيير اللغة", "CHANGE LANGUAGE", toggle_language)
	add_slider(content, "SunlightLabel", "شدة ضوء الشمس", "Sunlight strength", 0.0, 2.0, sunlight_strength, set_sunlight)
	add_slider(content, "AmbientLabel", "الإضاءة العامة", "Ambient lighting", 0.0, 2.0, ambient_strength, set_ambient)
	add_slider(content, "MasterLabel", "الصوت الرئيسي", "Master volume", 0.0, 1.0, master_volume, set_master_volume)
	add_slider(content, "MusicLabel", "صوت الموسيقى", "Music volume", 0.0, 1.0, music_volume, set_music_volume)
	add_slider(content, "EffectsLabel", "المؤثرات الصوتية", "Effects volume", 0.0, 1.0, effects_volume, set_effects_volume)
	make_button(content, "SettingsBack", "عودة", "BACK", close_settings)
	settings_panel.visible = false


func add_slider(parent: VBoxContainer, node_name: String, arabic: String, english: String, minimum: float, maximum: float, initial: float, callback: Callable):
	make_label(parent, node_name, arabic, english)
	var slider := HSlider.new()
	slider.min_value = minimum
	slider.max_value = maximum
	slider.step = 0.05
	slider.value = initial
	slider.custom_minimum_size = Vector2(230, 28)
	parent.add_child(slider)
	slider.value_changed.connect(callback)


func open_settings():
	main_menu.visible = false
	build_panel.visible = false
	settings_panel.visible = true


func close_settings():
	settings_panel.visible = false
	if is_game_started:
		build_panel.visible = true
	else:
		main_menu.visible = true


# --------------------------------------------------
# LIGHTING AND AUDIO
# --------------------------------------------------
func create_lighting():
	sun = DirectionalLight3D.new()
	sun.name = "Sun"
	sun.rotation_degrees = Vector3(-48, -35, 0)
	sun.light_energy = sunlight_strength
	sun.light_color = Color(1.0, 0.93, 0.80)
	sun.shadow_enabled = true
	sun.shadow_blur = 1.4
	sun.directional_shadow_mode = DirectionalLight3D.SHADOW_PARALLEL_2_SPLITS
	sun.directional_shadow_max_distance = 160.0
	add_child(sun)


func set_sunlight(value: float):
	sunlight_strength = value
	if is_instance_valid(sun):
		sun.light_energy = value


func set_ambient(value: float):
	ambient_strength = value
	if is_instance_valid(world_environment):
		world_environment.environment.ambient_light_energy = value


func setup_audio_buses():
	var master_index := AudioServer.get_bus_index("Master")
	if master_index >= 0:
		AudioServer.set_bus_volume_db(master_index, linear_to_db(maxf(master_volume, 0.0001)))
	music_bus = AudioServer.get_bus_index("Music")
	if music_bus == -1:
		AudioServer.add_bus()
		music_bus = AudioServer.bus_count - 1
		AudioServer.set_bus_name(music_bus, "Music")
		AudioServer.set_bus_send(music_bus, "Master")
	effects_bus = AudioServer.get_bus_index("Effects")
	if effects_bus == -1:
		AudioServer.add_bus()
		effects_bus = AudioServer.bus_count - 1
		AudioServer.set_bus_name(effects_bus, "Effects")
		AudioServer.set_bus_send(effects_bus, "Master")
	set_music_volume(music_volume)
	set_effects_volume(effects_volume)


func set_master_volume(value: float):
	master_volume = value
	var index := AudioServer.get_bus_index("Master")
	if index >= 0:
		AudioServer.set_bus_volume_db(index, linear_to_db(maxf(value, 0.0001)))


func set_music_volume(value: float):
	music_volume = value
	if music_bus >= 0:
		AudioServer.set_bus_volume_db(music_bus, linear_to_db(maxf(value, 0.0001)))


func set_effects_volume(value: float):
	effects_volume = value
	if effects_bus >= 0:
		AudioServer.set_bus_volume_db(effects_bus, linear_to_db(maxf(value, 0.0001)))


# --------------------------------------------------
# BUILD PANEL
# --------------------------------------------------
func create_build_panel():
	build_panel = make_panel(canvas, "BuildPanel", Vector2(15, 15), 245)
	var content := make_layout(build_panel)
	make_label(content, "BuildTitle", "قائمة البناء", "BUILD MENU")
	make_button(content, "Castle", "بناء قلعة", "BUILD CASTLE", func(): choose_building("castle"))
	make_button(content, "House", "بناء منزل", "BUILD HOUSE", func(): choose_building("house"))
	make_button(content, "Palm", "زراعة نخلة", "PLANT PALM", func(): choose_building("palm"))
	make_button(content, "Cancel", "إلغاء الاختيار", "CANCEL", cancel_building)
	status_label = Label.new()
	apply_font(status_label)
	status_label.autowrap_mode = TextServer.AUTOWRAP_WORD
	status_label.custom_minimum_size = Vector2(220, 54)
	content.add_child(status_label)
	make_button(content, "Settings", "الإعدادات", "SETTINGS", open_settings)
	build_panel.visible = false


func choose_building(kind: String):
	selected_building = kind
	select_object(null)
	update_status_language()


func cancel_building():
	selected_building = ""
	update_status_language()


# --------------------------------------------------
# GROUND POSITION AND PLACEMENT
# --------------------------------------------------
func screen_to_ground(screen_position: Vector2, height: float = 0.0):
	if not is_instance_valid(camera):
		return null
	var ray_origin := camera.project_ray_origin(screen_position)
	var ray_direction := camera.project_ray_normal(screen_position)
	var ground_plane := Plane(Vector3.UP, height)
	return ground_plane.intersects_ray(ray_origin, ray_direction)


func place_selected_building(screen_position: Vector2):
	if selected_building == "":
		return
	var hit = screen_to_ground(screen_position)
	if hit == null:
		return
	var build_position: Vector3 = hit
	var new_object: Node3D = null
	var note := ""
	if selected_building == "castle":
		new_object = create_castle(build_position)
		if new_object == null:
			note = tr_text("تعذر تحميل نموذج القلعة. تأكد من ملف Castle.tscn", "Castle model failed to load. Check Castle.tscn")
	elif selected_building == "house":
		new_object = create_real_house(build_position)
		if house_fallback_used:
			note = tr_text("لم يُحمَّل نموذج المنزل فتم وضع منزل بديل. تأكد من ملف House.tscn", "House model failed to load, a fallback house was used. Check House.tscn")
	elif selected_building == "palm":
		new_object = create_palm(build_position)
	selected_building = ""
	if is_instance_valid(new_object):
		select_object(new_object)
		if note != "":
			status_label.text = note
	elif note != "":
		status_label.text = note


# --------------------------------------------------
# OBJECT SELECTION
# --------------------------------------------------
func find_object_at_screen_position(screen_position: Vector2) -> Node3D:
	var best_object: Node3D = null
	var best_distance := 90.0
	for object in placed_objects:
		if not is_instance_valid(object):
			continue
		var points: Array[Vector3] = [object.global_position]
		var bounds := get_model_bounds(object)
		if bounds.size.length() > 0.001:
			points.append(object.global_transform * bounds.get_center())
		for world_point in points:
			if camera.is_position_behind(world_point):
				continue
			var distance := camera.unproject_position(world_point).distance_to(screen_position)
			if distance < best_distance:
				best_distance = distance
				best_object = object
	return best_object


func select_object(object: Node3D):
	selected_object = object
	if object == null:
		remove_object_controls()
		update_status_language()
		return
	show_object_controls()
	update_status_language()


# --------------------------------------------------
# 3D GIZMO: MATERIALS AND SHAPES
# --------------------------------------------------
func make_gizmo_material(color: Color, alpha: float = 1.0, on_top: bool = false, priority: int = 0) -> StandardMaterial3D:
	var material := StandardMaterial3D.new()
	material.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	material.albedo_color = Color(color.r, color.g, color.b, alpha)
	if alpha < 1.0:
		material.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	material.no_depth_test = on_top
	material.render_priority = priority
	material.disable_receive_shadows = true
	return material


func add_gizmo_mesh(parent: Node3D, mesh: Mesh, material: Material, position_value: Vector3 = Vector3.ZERO) -> MeshInstance3D:
	var instance := MeshInstance3D.new()
	instance.mesh = mesh
	instance.material_override = material
	instance.position = position_value
	instance.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	parent.add_child(instance)
	return instance


func add_icon_bar(parent: Node3D, material: Material, length: float, thickness: float, position_value: Vector2, rotation_deg: float):
	var mesh := BoxMesh.new()
	mesh.size = Vector3(length, thickness, 0.06)
	var bar := add_gizmo_mesh(parent, mesh, material, Vector3(position_value.x, position_value.y, 0.08))
	bar.rotation_degrees.z = rotation_deg


func add_icon_arrow(parent: Node3D, material: Material, position_value: Vector2, rotation_deg: float, size_value: float = 0.34):
	var mesh := CylinderMesh.new()
	mesh.top_radius = 0.0
	mesh.bottom_radius = size_value * 0.6
	mesh.height = size_value
	mesh.radial_segments = 3
	var cone := add_gizmo_mesh(parent, mesh, material, Vector3(position_value.x, position_value.y, 0.09))
	cone.rotation_degrees.z = rotation_deg


# A handle is a camera-facing disc with an icon. Its size is kept constant on screen.
func create_gizmo_handle(handle_name: String, color: Color, icon: String):
	var handle := Node3D.new()
	handle.name = "Handle_" + handle_name
	gizmo_root.add_child(handle)
	var outline_mesh := CylinderMesh.new()
	outline_mesh.top_radius = 1.14
	outline_mesh.bottom_radius = 1.14
	outline_mesh.height = 0.05
	outline_mesh.radial_segments = 40
	var disc_mesh := CylinderMesh.new()
	disc_mesh.top_radius = 1.0
	disc_mesh.bottom_radius = 1.0
	disc_mesh.height = 0.05
	disc_mesh.radial_segments = 40
	var outline := add_gizmo_mesh(handle, outline_mesh, make_gizmo_material(Color(0.05, 0.05, 0.07), 0.995, true, 20))
	outline.rotation_degrees.x = 90.0
	var disc := add_gizmo_mesh(handle, disc_mesh, make_gizmo_material(color, 0.995, true, 21), Vector3(0, 0, 0.03))
	disc.rotation_degrees.x = 90.0
	var white := make_gizmo_material(Color.WHITE, 0.995, true, 22)
	match icon:
		"move":
			add_icon_bar(handle, white, 1.0, 0.13, Vector2.ZERO, 0.0)
			add_icon_bar(handle, white, 1.0, 0.13, Vector2.ZERO, 90.0)
			add_icon_arrow(handle, white, Vector2(0.52, 0.0), -90.0)
			add_icon_arrow(handle, white, Vector2(-0.52, 0.0), 90.0)
			add_icon_arrow(handle, white, Vector2(0.0, 0.52), 0.0)
			add_icon_arrow(handle, white, Vector2(0.0, -0.52), 180.0)
		"rotate":
			var arc_mesh := TorusMesh.new()
			arc_mesh.inner_radius = 0.34
			arc_mesh.outer_radius = 0.5
			arc_mesh.rings = 32
			arc_mesh.ring_segments = 8
			var arc := add_gizmo_mesh(handle, arc_mesh, white, Vector3(0, 0, 0.08))
			arc.rotation_degrees.x = 90.0
			add_icon_arrow(handle, white, Vector2(0.42, 0.1), 0.0, 0.4)
		"scale":
			add_icon_bar(handle, white, 1.15, 0.13, Vector2.ZERO, 45.0)
			add_icon_arrow(handle, white, Vector2(0.45, 0.45), -45.0)
			add_icon_arrow(handle, white, Vector2(-0.45, -0.45), 135.0)
		"delete":
			add_icon_bar(handle, white, 1.1, 0.17, Vector2.ZERO, 45.0)
			add_icon_bar(handle, white, 1.1, 0.17, Vector2.ZERO, -45.0)
	gizmo_handle_nodes[handle_name] = handle


# --------------------------------------------------
# 3D GIZMO: CREATE, LAYOUT, UPDATE
# --------------------------------------------------
func remove_object_controls():
	if is_instance_valid(gizmo_root):
		gizmo_root.queue_free()
	gizmo_root = null
	gizmo_ring = null
	gizmo_ghost_ring = null
	gizmo_ticks = null
	gizmo_disc = null
	gizmo_front_line = null
	gizmo_front_arrow = null
	gizmo_stem = null
	gizmo_handles.clear()
	gizmo_handle_nodes.clear()
	delete_armed_until = 0


func show_object_controls():
	remove_object_controls()
	if not is_instance_valid(selected_object):
		return
	gizmo_local_bounds = get_model_bounds(selected_object)
	gizmo_root = Node3D.new()
	gizmo_root.name = "ObjectTransformGizmo"
	add_child(gizmo_root)
	gizmo_root.global_position = selected_object.global_position
	gizmo_root.rotation.y = selected_object.rotation.y

	var gold := Color(1.0, 0.80, 0.22)

	# Rotation ring lying flat on the ground around the object (solid + see-through copy).
	var ring_mesh := TorusMesh.new()
	ring_mesh.inner_radius = 0.96
	ring_mesh.outer_radius = 1.04
	ring_mesh.rings = 96
	ring_mesh.ring_segments = 12
	gizmo_ring = add_gizmo_mesh(gizmo_root, ring_mesh, make_gizmo_material(gold, 1.0, false, 2))
	gizmo_ghost_ring = add_gizmo_mesh(gizmo_root, ring_mesh, make_gizmo_material(gold, 0.35, true, 1))

	# Soft glowing disc under the object.
	var disc_mesh := CylinderMesh.new()
	disc_mesh.top_radius = 1.0
	disc_mesh.bottom_radius = 1.0
	disc_mesh.height = 0.02
	disc_mesh.radial_segments = 64
	gizmo_disc = add_gizmo_mesh(gizmo_root, disc_mesh, make_gizmo_material(gold, 0.13, false, 0))

	# Degree ticks every 15 degrees (longer every 90).
	gizmo_ticks = Node3D.new()
	gizmo_root.add_child(gizmo_ticks)
	var tick_material := make_gizmo_material(Color(1.0, 0.95, 0.70), 1.0, false, 3)
	for i in range(24):
		var angle := TAU * float(i) / 24.0
		var tick_mesh := BoxMesh.new()
		if i % 6 == 0:
			tick_mesh.size = Vector3(0.025, 0.02, 0.13)
		else:
			tick_mesh.size = Vector3(0.015, 0.015, 0.06)
		var tick := add_gizmo_mesh(gizmo_ticks, tick_mesh, tick_material, Vector3(sin(angle), 0.0, cos(angle)) * 0.88)
		tick.rotation.y = angle

	# Facing direction: line from the center + arrow head pointing to the object's front (+Z).
	var line_material := make_gizmo_material(gold, 0.9, false, 3)
	gizmo_front_line = add_gizmo_mesh(gizmo_root, BoxMesh.new(), line_material)
	var arrow_mesh := CylinderMesh.new()
	arrow_mesh.top_radius = 0.0
	arrow_mesh.bottom_radius = 0.5
	arrow_mesh.height = 1.0
	arrow_mesh.radial_segments = 3
	arrow_mesh.rings = 1
	gizmo_front_arrow = add_gizmo_mesh(gizmo_root, arrow_mesh, line_material)
	gizmo_front_arrow.rotation_degrees.x = 90.0

	# Vertical stem going up to the move handle above the object.
	gizmo_stem = add_gizmo_mesh(gizmo_root, BoxMesh.new(), make_gizmo_material(Color(0.35, 1.0, 0.5), 0.9, false, 3))

	create_gizmo_handle("move", Color(0.18, 0.80, 0.33), "move")
	create_gizmo_handle("rotate", Color(1.0, 0.55, 0.10), "rotate")
	create_gizmo_handle("scale", Color(0.20, 0.55, 1.0), "scale")
	create_gizmo_handle("delete", Color(0.92, 0.22, 0.20), "delete")

	layout_gizmo()
	update_gizmo_visuals()


func layout_gizmo():
	if not is_instance_valid(gizmo_root) or not is_instance_valid(selected_object):
		return
	if gizmo_ring == null:
		return
	var metrics := get_object_metrics(selected_object, gizmo_local_bounds)
	var radius: float = metrics["radius"]
	var height: float = metrics["height"]
	gizmo_radius = radius
	gizmo_height = height
	var lift := GIZMO_RING_LIFT

	gizmo_ring.scale = Vector3.ONE * radius
	gizmo_ring.position.y = lift
	gizmo_ghost_ring.scale = Vector3.ONE * radius
	gizmo_ghost_ring.position.y = lift
	gizmo_ticks.scale = Vector3.ONE * radius
	gizmo_ticks.position.y = lift
	gizmo_disc.scale = Vector3(radius, 1.0, radius)
	gizmo_disc.position.y = 0.06

	var line_width := maxf(0.08, radius * 0.012)
	gizmo_front_line.scale = Vector3(line_width, 0.03, radius * 0.9)
	gizmo_front_line.position = Vector3(0.0, lift + 0.02, radius * 0.45)
	var arrow_width := maxf(0.7, radius * 0.11)
	var arrow_length := maxf(1.1, radius * 0.18)
	gizmo_front_arrow.scale = Vector3(arrow_width, arrow_length, arrow_width)
	gizmo_front_arrow.position = Vector3(0.0, lift + 0.03, radius * 0.78)

	var stem_top := height + GIZMO_MOVE_MARGIN
	var stem_length := stem_top - lift
	var stem_width := maxf(0.1, radius * 0.01)
	gizmo_stem.scale = Vector3(stem_width, stem_length, stem_width)
	gizmo_stem.position = Vector3(0.0, lift + stem_length * 0.5, 0.0)

	var diagonal := 0.7071
	gizmo_handles["move"] = Vector3(0.0, stem_top, 0.0)
	gizmo_handles["rotate"] = Vector3(0.0, lift, radius)
	gizmo_handles["scale"] = Vector3(diagonal * radius, lift, -diagonal * radius)
	gizmo_handles["delete"] = Vector3(-diagonal * radius, lift, -diagonal * radius)


# Runs every frame: follows the object and keeps the handles a constant size on screen.
func update_gizmo_visuals():
	if not is_instance_valid(gizmo_root) or not is_instance_valid(selected_object) or not is_instance_valid(camera):
		return
	gizmo_root.global_position = selected_object.global_position
	gizmo_root.rotation.y = selected_object.rotation.y
	var viewport_height := maxf(get_viewport().get_visible_rect().size.y, 1.0)
	var tan_half := tan(deg_to_rad(camera.fov * 0.5))
	var camera_basis := camera.global_transform.basis.orthonormalized()
	var now := Time.get_ticks_msec()
	for handle_name in gizmo_handle_nodes.keys():
		var node: Node3D = gizmo_handle_nodes[handle_name]
		if not is_instance_valid(node) or not gizmo_handles.has(handle_name):
			continue
		var local_point: Vector3 = gizmo_handles[handle_name]
		var world_point := gizmo_root.to_global(local_point)
		var distance := camera.global_position.distance_to(world_point)
		var world_per_pixel := 2.0 * distance * tan_half / viewport_height
		var handle_scale := world_per_pixel * GIZMO_HANDLE_PIXELS
		if handle_name == gizmo_operation:
			handle_scale *= 1.25
		if handle_name == "delete" and now < delete_armed_until:
			handle_scale *= 1.0 + 0.18 * sin(float(now) * 0.014)
		node.global_transform = Transform3D(camera_basis.scaled(Vector3.ONE * handle_scale), world_point)


# --------------------------------------------------
# 3D GIZMO: INPUT
# --------------------------------------------------
func get_gizmo_handle_at(screen_position: Vector2) -> String:
	if not is_instance_valid(gizmo_root) or not is_instance_valid(selected_object):
		return ""
	var best_name := ""
	var best_distance := GIZMO_HIT_RADIUS
	for handle_name in gizmo_handles.keys():
		var local_point: Vector3 = gizmo_handles[handle_name]
		var world_point := gizmo_root.to_global(local_point)
		if camera.is_position_behind(world_point):
			continue
		var point := camera.unproject_position(world_point)
		var distance := point.distance_to(screen_position)
		if distance < best_distance:
			best_distance = distance
			best_name = handle_name
	return best_name


func begin_gizmo_drag(screen_position: Vector2, touch_index: int = -1) -> bool:
	var operation := get_gizmo_handle_at(screen_position)
	if operation == "":
		return false
	if operation == "delete":
		# Two taps are needed so a building is never deleted by accident.
		var now := Time.get_ticks_msec()
		if now < delete_armed_until:
			delete_selected_object()
		else:
			delete_armed_until = now + 2500
			status_label.text = tr_text("اضغط زر الحذف الأحمر مرة أخرى للتأكيد", "Tap the red delete button again to confirm")
		return true
	var center := selected_object.global_position
	gizmo_start_screen = screen_position
	gizmo_start_position = center
	gizmo_start_rotation = selected_object.rotation.y
	gizmo_start_scale = selected_object.scale
	gizmo_touch_index = touch_index
	match operation:
		"move":
			var move_local: Vector3 = gizmo_handles["move"]
			gizmo_move_plane_y = center.y + move_local.y
			var move_hit = screen_to_ground(screen_position, gizmo_move_plane_y)
			if move_hit == null:
				return true
			gizmo_start_ground = move_hit
		"rotate":
			var rotate_hit = screen_to_ground(screen_position, center.y)
			if rotate_hit == null:
				return true
			var rotate_point: Vector3 = rotate_hit
			gizmo_start_angle = atan2(rotate_point.x - center.x, rotate_point.z - center.z)
			gizmo_last_angle = gizmo_start_angle
			gizmo_rotation_accum = 0.0
		"scale":
			var scale_hit = screen_to_ground(screen_position, center.y)
			if scale_hit == null:
				return true
			var scale_point: Vector3 = scale_hit
			gizmo_start_distance = maxf(Vector2(scale_point.x - center.x, scale_point.z - center.z).length(), 0.5)
	gizmo_dragging = true
	gizmo_operation = operation
	return true


func snap_angle(angle: float) -> float:
	var step := deg_to_rad(15.0)
	var nearest := roundf(angle / step) * step
	if absf(angle - nearest) < deg_to_rad(3.0):
		return nearest
	return angle


func update_gizmo_drag(screen_position: Vector2):
	if not gizmo_dragging or not is_instance_valid(selected_object):
		return
	var center := gizmo_start_position
	match gizmo_operation:
		"move":
			var move_hit = screen_to_ground(screen_position, gizmo_move_plane_y)
			if move_hit != null:
				var move_point: Vector3 = move_hit
				var offset := move_point - gizmo_start_ground
				selected_object.global_position = Vector3(gizmo_start_position.x + offset.x, gizmo_start_position.y, gizmo_start_position.z + offset.z)
		"rotate":
			var rotate_hit = screen_to_ground(screen_position, center.y)
			if rotate_hit != null:
				var rotate_point: Vector3 = rotate_hit
				var angle := atan2(rotate_point.x - center.x, rotate_point.z - center.z)
				gizmo_rotation_accum += wrapf(angle - gizmo_last_angle, -PI, PI)
				gizmo_last_angle = angle
				selected_object.rotation.y = snap_angle(gizmo_start_rotation + gizmo_rotation_accum)
		"scale":
			var scale_hit = screen_to_ground(screen_position, center.y)
			if scale_hit != null:
				var scale_point: Vector3 = scale_hit
				var distance := Vector2(scale_point.x - center.x, scale_point.z - center.z).length()
				var factor := distance / gizmo_start_distance
				var base := maxf(gizmo_start_scale.x, 0.0001)
				factor = clampf(factor, GIZMO_MIN_SCALE / base, GIZMO_MAX_SCALE / base)
				selected_object.scale = gizmo_start_scale * factor
				layout_gizmo()
	update_gizmo_visuals()


func end_gizmo_drag():
	gizmo_dragging = false
	gizmo_operation = ""
	gizmo_touch_index = -1


func delete_selected_object():
	if not is_instance_valid(selected_object):
		return
	placed_objects.erase(selected_object)
	selected_object.queue_free()
	selected_object = null
	remove_object_controls()
	end_gizmo_drag()
	status_label.text = tr_text("تم حذف العنصر", "Object deleted")


# --------------------------------------------------
# INPUT
# --------------------------------------------------
func _unhandled_input(event):
	if not is_game_started:
		return

	# On phones Godot also sends fake mouse events for every touch.
	# Ignoring them prevents every tap from being processed twice.
	if event is InputEventMouseButton or event is InputEventMouseMotion:
		if event.device == InputEvent.DEVICE_ID_EMULATION:
			return

	if event is InputEventScreenTouch:
		if event.pressed:
			touch_points[event.index] = event.position
			touch_starts[event.index] = event.position
			if touch_points.size() == 1 and begin_gizmo_drag(event.position, event.index):
				consumed_touches[event.index] = true
				return
		else:
			var was_consumed: bool = consumed_touches.has(event.index)
			consumed_touches.erase(event.index)
			if gizmo_dragging and gizmo_touch_index == event.index:
				end_gizmo_drag()
			elif touch_points.has(event.index) and not was_consumed:
				var start_position: Vector2 = touch_starts.get(event.index, event.position)
				if start_position.distance_to(event.position) < 15.0 and touch_points.size() == 1:
					handle_world_tap(event.position)
			touch_points.erase(event.index)
			touch_starts.erase(event.index)
		return

	if event is InputEventScreenDrag:
		if gizmo_dragging and gizmo_touch_index == event.index:
			update_gizmo_drag(event.position)
			return
		if gizmo_dragging:
			return
		if not touch_points.has(event.index):
			return
		var old_positions: Dictionary = touch_points.duplicate()
		touch_points[event.index] = event.position
		var ids = touch_points.keys()
		if ids.size() == 1:
			if selected_building == "":
				camera_pivot.rotate_y(-event.relative.x * TOUCH_ROTATION_SPEED)
				camera_pitch.rotation.x = clampf(camera_pitch.rotation.x - event.relative.y * TOUCH_ROTATION_SPEED, deg_to_rad(-80), deg_to_rad(-10))
		elif ids.size() >= 2:
			var id_a = ids[0]
			var id_b = ids[1]
			var old_a: Vector2 = old_positions[id_a]
			var old_b: Vector2 = old_positions[id_b]
			var new_a: Vector2 = touch_points[id_a]
			var new_b: Vector2 = touch_points[id_b]
			var old_distance := old_a.distance_to(old_b)
			var new_distance := new_a.distance_to(new_b)
			zoom_distance = clampf(zoom_distance + (old_distance - new_distance) * TOUCH_ZOOM_SPEED, ZOOM_MIN, ZOOM_MAX)
			camera.position.z = zoom_distance
			var movement := (new_a + new_b - old_a - old_b) * 0.5
			camera_pivot.translate(Vector3(-movement.x * zoom_distance * 0.0015, 0, -movement.y * zoom_distance * 0.0015))
		return

	if event is InputEventMouseButton:
		if event.button_index == MOUSE_BUTTON_LEFT:
			if event.pressed:
				mouse_down = true
				mouse_dragged = false
				mouse_start = event.position
				if begin_gizmo_drag(event.position):
					mouse_down = false
					return
			else:
				if gizmo_dragging:
					end_gizmo_drag()
				elif mouse_down and not mouse_dragged:
					handle_world_tap(event.position)
				mouse_down = false
		if event.pressed:
			if event.button_index == MOUSE_BUTTON_WHEEL_UP:
				change_zoom(-4.0)
			elif event.button_index == MOUSE_BUTTON_WHEEL_DOWN:
				change_zoom(4.0)
			elif event.button_index == MOUSE_BUTTON_RIGHT:
				panning = true
		elif event.button_index == MOUSE_BUTTON_RIGHT:
			panning = false
		return

	if event is InputEventMouseMotion:
		if gizmo_dragging:
			update_gizmo_drag(event.position)
		elif mouse_down:
			if mouse_start.distance_to(event.position) > 8.0:
				mouse_dragged = true
				camera_pivot.rotate_y(-event.relative.x * 0.004)
				camera_pitch.rotation.x = clampf(camera_pitch.rotation.x - event.relative.y * 0.004, deg_to_rad(-80), deg_to_rad(-10))
		elif panning:
			camera_pivot.translate(Vector3(-event.relative.x * 0.05, 0, -event.relative.y * 0.05))


# --------------------------------------------------
# WORLD TAP AND ZOOM
# --------------------------------------------------
func handle_world_tap(position_value: Vector2):
	if selected_building != "":
		place_selected_building(position_value)
	else:
		select_object(find_object_at_screen_position(position_value))


func change_zoom(amount: float):
	zoom_distance = clampf(zoom_distance + amount, ZOOM_MIN, ZOOM_MAX)
	if is_instance_valid(camera):
		camera.position.z = zoom_distance


# --------------------------------------------------
# CAMERA
# --------------------------------------------------
func create_camera():
	camera_pivot = Node3D.new()
	camera_pivot.name = "CameraPivot"
	add_child(camera_pivot)
	camera_pitch = Node3D.new()
	camera_pitch.name = "CameraPitch"
	camera_pitch.rotation.x = deg_to_rad(-40)
	camera_pivot.add_child(camera_pitch)
	camera = Camera3D.new()
	camera.name = "StrategyCamera"
	camera.position = Vector3(0, 0, zoom_distance)
	camera.fov = 50
	camera.current = true
	camera.near = 0.5
	camera.far = 2500.0
	camera_pitch.add_child(camera)


# --------------------------------------------------
# PROCESS AND KEYBOARD MOVEMENT
# --------------------------------------------------
func _process(delta):
	if not is_game_started:
		return
	var movement := Vector3.ZERO
	if Input.is_key_pressed(KEY_W):
		movement.z -= 1
	if Input.is_key_pressed(KEY_S):
		movement.z += 1
	if Input.is_key_pressed(KEY_A):
		movement.x -= 1
	if Input.is_key_pressed(KEY_D):
		movement.x += 1
	if Input.is_key_pressed(KEY_Q):
		camera_pivot.position.y += CAMERA_SPEED * delta
	if Input.is_key_pressed(KEY_E):
		camera_pivot.position.y -= CAMERA_SPEED * delta
	if movement.length() > 0:
		camera_pivot.translate(movement.normalized() * CAMERA_SPEED * delta)
	camera_pivot.position.x = clampf(camera_pivot.position.x, -CAMERA_LIMIT, CAMERA_LIMIT)
	camera_pivot.position.z = clampf(camera_pivot.position.z, -CAMERA_LIMIT, CAMERA_LIMIT)
	camera_pivot.position.y = clampf(camera_pivot.position.y, -10.0, 80.0)
	update_gizmo_visuals()
