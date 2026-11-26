
extends Node3D

# KINGDOMS OF THE DESERT
# Godot 4.3

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
var touch_points: Dictionary = {}
var touch_starts: Dictionary = {}

const ZOOM_MIN := 12.0
const ZOOM_MAX := 100.0
const CAMERA_SPEED := 30.0
const TOUCH_ROTATION_SPEED := 0.004
const TOUCH_ZOOM_SPEED := 0.06

# --------------------------------------------------
# WORLD
# --------------------------------------------------

var world_config: Dictionary = {}
var placed_objects: Array[Node3D] = []

const HOUSE_TARGET_HEIGHT := 8.0
const CASTLE_TARGET_HEIGHT := 25.0

# --------------------------------------------------
# BUILDING
# --------------------------------------------------

var selected_building := ""
var selected_object: Node3D

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

var sunlight_strength := 0.75
var ambient_strength := 0.65

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

	if current_language == "ar":
		return arabic

	return english


func apply_font(control: Control):

	if arabic_font != null:

		control.add_theme_font_override(
			"font",
			arabic_font
		)


func register_text(control: Control, arabic: String, english: String):

	localized_controls.append({
		"control": control,
		"ar": arabic,
		"en": english
	})

	control.text = tr_text(arabic, english)

	apply_font(control)


func set_language(language: String):

	current_language = language

	for item in localized_controls:

		var control: Control = item["control"]

		if is_instance_valid(control):

			control.text = tr_text(
				item["ar"],
				item["en"]
			)

	update_status_language()


func toggle_language():

	if current_language == "ar":

		set_language("en")

	else:

		set_language("ar")


func update_status_language():

	if status_label == null:
		return

	if selected_building == "castle":

		status_label.text = tr_text(
			"اختر مكان القلعة",
			"Choose castle location"
		)

	elif selected_building == "house":

		status_label.text = tr_text(
			"اختر مكان المنزل",
			"Choose house location"
		)

	elif selected_building == "palm":

		status_label.text = tr_text(
			"اختر مكان النخلة",
			"Choose palm location"
		)

	elif is_instance_valid(selected_object):

		status_label.text = tr_text(
			"تم تحديد العنصر",
			"Object selected"
		)

	else:

		status_label.text = tr_text(
			"اختر عنصرًا للبناء أو حدد مبنى موجودًا",
			"Choose an object to build or select an existing one"
		)


# --------------------------------------------------
# WORLD CONFIG
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
# ENVIRONMENT
# --------------------------------------------------

func create_environment():

	world_environment = WorldEnvironment.new()

	var environment := Environment.new()

	var sky := Sky.new()
	var sky_material := ProceduralSkyMaterial.new()

	sky_material.sky_top_color = Color(0.13, 0.35, 0.62)
	sky_material.sky_horizon_color = Color(0.78, 0.78, 0.75)

	sky_material.ground_bottom_color = Color(0.78, 0.72, 0.60)
	sky_material.ground_horizon_color = Color(0.78, 0.72, 0.60)

	sky.sky_material = sky_material

	environment.background_mode = Environment.BG_SKY
	environment.sky = sky

	environment.ambient_light_source = Environment.AMBIENT_SOURCE_SKY
	environment.ambient_light_energy = ambient_strength

	environment.tonemap_mode = Environment.TONE_MAPPER_FILMIC

	world_environment.environment = environment

	add_child(world_environment)


# --------------------------------------------------
# TERRAIN
# --------------------------------------------------

func create_terrain():

	var ground := MeshInstance3D.new()

	ground.name = "DesertTerrain"

	var plane := PlaneMesh.new()

	plane.size = Vector2(3000.0, 3000.0)
	plane.subdivide_width = 150
	plane.subdivide_depth = 150

	ground.mesh = plane

	var material := StandardMaterial3D.new()

	material.albedo_color = Color.WHITE

	var diffuse = load(
		"res://assets/materials/sand_diffuse.png"
	)

	if diffuse:
		material.albedo_texture = diffuse

	material.texture_filter = BaseMaterial3D.TEXTURE_FILTER_LINEAR_WITH_MIPMAPS_ANISOTROPIC
	material.uv1_scale = Vector3(100.0, 100.0, 1.0)

	var normal_map = load(
		"res://assets/materials/sand_normal.png"
	)

	if normal_map:

		material.normal_enabled = true
		material.normal_texture = normal_map
		material.normal_scale = 0.35

	var roughness_map = load(
		"res://assets/materials/sand_roughness.png"
	)

	if roughness_map:

		material.roughness = 1.0
		material.roughness_texture = roughness_map

	var ao_map = load(
		"res://assets/materials/sand_ao.png"
	)

	if ao_map:

		material.ao_enabled = true
		material.ao_texture = ao_map

	ground.material_override = material

	add_child(ground)


# --------------------------------------------------
# MODEL BOUNDS
# --------------------------------------------------

func get_model_bounds(root: Node3D) -> AABB:

	var result := AABB()
	var found := false

	var meshes = root.find_children(
		"*",
		"MeshInstance3D",
		true,
		false
	)

	for node in meshes:

		var mesh_node := node as MeshInstance3D

		if mesh_node == null:
			continue

		if mesh_node.mesh == null:
			continue

		var local_transform = (
			root.global_transform.affine_inverse()
			* mesh_node.global_transform
		)

		var transformed = local_transform * mesh_node.get_aabb()

		if not found:

			result = transformed
			found = true

		else:

			result = result.merge(transformed)

	if not found:

		return AABB(Vector3.ZERO, Vector3.ONE)

	return result


func normalize_model(root: Node3D, target_height: float):

	var bounds := get_model_bounds(root)

	var height := maxf(bounds.size.y, 0.01)

	var factor := target_height / height

	root.scale = Vector3.ONE * factor

	var center_x = bounds.position.x + bounds.size.x * 0.5
	var bottom_y = bounds.position.y
	var center_z = bounds.position.z + bounds.size.z * 0.5

	root.position = Vector3(
		-center_x * factor,
		-bottom_y * factor,
		-center_z * factor
	)


# --------------------------------------------------
# CASTLE
# --------------------------------------------------

func create_castle(position_value: Vector3) -> Node3D:

	var path := "res://scenes/Castle.tscn"

	if not ResourceLoader.exists(path):

		push_error("Castle scene not found")
		return null

	var packed_scene := load(path) as PackedScene

	if packed_scene == null:
		return null

	var castle := packed_scene.instantiate() as Node3D

	if castle == null:
		return null

	castle.name = "PlayerCastle"

	add_child(castle)

	castle.global_position = position_value

	placed_objects.append(castle)

	return castle


# --------------------------------------------------
# HOUSE
# --------------------------------------------------

func create_real_house(position_value: Vector3) -> Node3D:

	var path := "res://scenes/House.tscn"

	if not ResourceLoader.exists(path):

		push_error("House scene not found")
		return null

	var packed_scene := load(path) as PackedScene

	if packed_scene == null:
		return null

	var house := packed_scene.instantiate() as Node3D

	if house == null:
		return null

	house.name = "PlayerHouse"

	add_child(house)

	house.global_position = position_value

	await get_tree().process_frame

	if not is_instance_valid(house):
		return null

	normalize_model(house, HOUSE_TARGET_HEIGHT)

	house.global_position = position_value

	placed_objects.append(house)

	return house


# --------------------------------------------------
# PALM TREE
# Temporary procedural model until a real palm GLB
# is added to the project.
# --------------------------------------------------

func create_palm(position_value: Vector3) -> Node3D:

	var palm := Node3D.new()

	palm.name = "PlayerPalm"

	add_child(palm)

	palm.global_position = position_value

	var trunk := MeshInstance3D.new()
	var trunk_mesh := CylinderMesh.new()

	trunk_mesh.top_radius = 0.22
	trunk_mesh.bottom_radius = 0.42
	trunk_mesh.height = 6.0
	trunk_mesh.radial_segments = 16

	trunk.mesh = trunk_mesh
	trunk.position.y = 3.0

	trunk.material_override = make_material(
		Color(0.35, 0.20, 0.10)
	)

	palm.add_child(trunk)

	for i in range(9):

		var angle := TAU * float(i) / 9.0

		var leaf := MeshInstance3D.new()
		var leaf_mesh := BoxMesh.new()

		leaf_mesh.size = Vector3(4.0, 0.12, 0.55)

		leaf.mesh = leaf_mesh

		leaf.position = Vector3(
			cos(angle) * 1.2,
			5.8,
			sin(angle) * 1.2
		)

		leaf.rotation.y = -angle
		leaf.rotation.z = -0.22

		leaf.material_override = make_material(
			Color(0.13, 0.32, 0.13)
		)

		palm.add_child(leaf)

	placed_objects.append(palm)

	return palm


# --------------------------------------------------
# INTERFACE
# --------------------------------------------------

func create_interface():

	canvas = CanvasLayer.new()

	canvas.name = "GameInterface"

	add_child(canvas)

	create_main_menu()
	create_settings_panel()
	create_build_panel()


func make_panel(parent: Control, panel_name: String,
		position_value: Vector2, width: float) -> PanelContainer:

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


func make_button(parent: VBoxContainer, node_name: String,
		arabic: String, english: String,
		callback: Callable) -> Button:

	var button := Button.new()

	button.name = node_name
	button.custom_minimum_size = Vector2(220, 44)

	register_text(button, arabic, english)

	parent.add_child(button)

	button.pressed.connect(callback)

	return button


func make_label(parent: VBoxContainer, node_name: String,
		arabic: String, english: String) -> Label:

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

	main_menu = make_panel(
		canvas,
		"MainMenu",
		Vector2(20, 20),
		300
	)

	main_menu.set_anchors_and_offsets_preset(
		Control.PRESET_CENTER
	)

	var content := make_layout(main_menu)

	make_label(
		content,
		"Title",
		"ممالك الصحراء",
		"KINGDOMS OF THE DESERT"
	)

	make_button(
		content,
		"Start",
		"بدء اللعبة",
		"START GAME",
		start_game
	)

	make_button(
		content,
		"Settings",
		"الإعدادات",
		"SETTINGS",
		open_settings
	)

	make_button(
		content,
		"Exit",
		"إغلاق القائمة",
		"CLOSE MENU",
		close_main_menu
	)


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
# SETTINGS PANEL
# --------------------------------------------------

func create_settings_panel():

	settings_panel = make_panel(
		canvas,
		"SettingsPanel",
		Vector2(340, 20),
		300
	)

	var scroll := ScrollContainer.new()

	scroll.custom_minimum_size = Vector2(280, 380)

	settings_panel.add_child(scroll)

	var content := VBoxContainer.new()

	content.add_theme_constant_override("separation", 8)

	scroll.add_child(content)

	make_label(
		content,
		"SettingsTitle",
		"إعدادات اللعبة",
		"GAME SETTINGS"
	)

	make_button(
		content,
		"Language",
		"تغيير اللغة",
		"CHANGE LANGUAGE",
		toggle_language
	)

	add_slider(
		content,
		"SunlightLabel",
		"شدة ضوء الشمس",
		"Sunlight strength",
		0.0,
		2.0,
		sunlight_strength,
		set_sunlight
	)

	add_slider(
		content,
		"AmbientLabel",
		"الإضاءة العامة",
		"Ambient lighting",
		0.0,
		2.0,
		ambient_strength,
		set_ambient
	)

	add_slider(
		content,
		"MasterLabel",
		"الصوت الرئيسي",
		"Master volume",
		0.0,
		1.0,
		master_volume,
		set_master_volume
	)

	add_slider(
		content,
		"MusicLabel",
		"صوت الموسيقى",
		"Music volume",
		0.0,
		1.0,
		music_volume,
		set_music_volume
	)

	add_slider(
		content,
		"EffectsLabel",
		"المؤثرات الصوتية",
		"Effects volume",
		0.0,
		1.0,
		effects_volume,
		set_effects_volume
	)

	make_button(
		content,
		"SettingsBack",
		"عودة",
		"BACK",
		close_settings
	)

	settings_panel.visible = false


func add_slider(parent: VBoxContainer, node_name: String,
		arabic: String, english: String,
		minimum: float, maximum: float,
		initial: float, callback: Callable):

	make_label(
		parent,
		node_name,
		arabic,
		english
	)

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
# LIGHTING SETTINGS
# --------------------------------------------------

func create_lighting():

	sun = DirectionalLight3D.new()

	sun.rotation_degrees = Vector3(-48, -35, 0)

	sun.light_energy = sunlight_strength
	sun.shadow_enabled = true

	sun.directional_shadow_max_distance = 100

	add_child(sun)


func set_sunlight(value: float):

	sunlight_strength = value

	if is_instance_valid(sun):
		sun.light_energy = value


func set_ambient(value: float):

	ambient_strength = value

	if is_instance_valid(world_environment):

		world_environment.environment.ambient_light_energy = value


# --------------------------------------------------
# AUDIO SETTINGS
# --------------------------------------------------

func setup_audio_buses():

	var master_index := AudioServer.get_bus_index("Master")

	if master_index >= 0:

		AudioServer.set_bus_volume_linear(
			master_index,
			master_volume
		)

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

		AudioServer.set_bus_volume_linear(
			index,
			value
		)


func set_music_volume(value: float):

	music_volume = value

	if music_bus >= 0:

		AudioServer.set_bus_volume_linear(
			music_bus,
			value
		)


func set_effects_volume(value: float):

	effects_volume = value

	if effects_bus >= 0:

		AudioServer.set_bus_volume_linear(
			effects_bus,
			value
		)


# --------------------------------------------------
# BUILD PANEL
# --------------------------------------------------

func create_build_panel():

	build_panel = make_panel(
		canvas,
		"BuildPanel",
		Vector2(15, 15),
		245
	)

	var content := make_layout(build_panel)

	make_label(
		content,
		"BuildTitle",
		"قائمة البناء",
		"BUILD MENU"
	)

	make_button(
		content,
		"Castle",
		"بناء قلعة",
		"BUILD CASTLE",
		func(): choose_building("castle")
	)

	make_button(
		content,
		"House",
		"بناء منزل",
		"BUILD HOUSE",
		func(): choose_building("house")
	)

	make_button(
		content,
		"Palm",
		"زراعة نخلة",
		"PLANT PALM",
		func(): choose_building("palm")
	)

	make_button(
		content,
		"Cancel",
		"إلغاء الاختيار",
		"CANCEL",
		cancel_building
	)

	status_label = Label.new()

	status_label.autowrap_mode = TextServer.AUTOWRAP_WORD
	status_label.custom_minimum_size = Vector2(220, 48)

	content.add_child(status_label)

	make_button(
		content,
		"Settings",
		"الإعدادات",
		"SETTINGS",
		open_settings
	)

	build_panel.visible = false


func choose_building(kind: String):

	selected_building = kind
	selected_object = null

	update_status_language()


func cancel_building():

	selected_building = ""

	update_status_language()


# --------------------------------------------------
# GROUND POSITION
# --------------------------------------------------

func screen_to_ground(screen_position: Vector2):

	if not is_instance_valid(camera):
		return null

	var ray_origin := camera.project_ray_origin(screen_position)
	var ray_direction := camera.project_ray_normal(screen_position)

	var ground_plane := Plane(Vector3.UP, 0.0)

	return ground_plane.intersects_ray(
		ray_origin,
		ray_direction
	)


# --------------------------------------------------
# PLACE OBJECT
# --------------------------------------------------

func place_selected_building(screen_position: Vector2):

	if selected_building == "":
		return

	var hit = screen_to_ground(screen_position)

	if hit == null:
		return

	var build_position: Vector3 = hit

	if selected_building == "castle":

		var castle := create_castle(build_position)

		if castle != null:

			status_label.text = tr_text(
				"تم وضع القلعة",
				"Castle placed"
			)

	elif selected_building == "house":

		var house = await create_real_house(build_position)

		if house != null:

			status_label.text = tr_text(
				"تم وضع المنزل",
				"House placed"
			)

	elif selected_building == "palm":

		var palm := create_palm(build_position)

		if palm != null:

			status_label.text = tr_text(
				"تمت زراعة النخلة",
				"Palm planted"
			)

	selected_building = ""


# --------------------------------------------------
# OBJECT SELECTION
# --------------------------------------------------

func find_object_at_screen_position(screen_position: Vector2) -> Node3D:

	var best_object: Node3D = null
	var best_distance := 90.0

	for object in placed_objects:

		if not is_instance_valid(object):
			continue

		var screen_point := camera.unproject_position(
			object.global_position
		)

		if camera.is_position_behind(object.global_position):
			continue

		var distance := screen_point.distance_to(screen_position)

		if distance < best_distance:

			best_distance = distance
			best_object = object

	return best_object


func select_object(object: Node3D):

	selected_object = object

	if object == null:

		update_status_language()
		remove_object_controls()

		return

	status_label.text = tr_text(
		"تم تحديد العنصر. استخدم أدوات التحكم.",
		"Object selected. Use the editing controls."
	)

	show_object_controls()


# --------------------------------------------------
# OBJECT EDITING CONTROLS
# --------------------------------------------------

func remove_object_controls():

	if not is_instance_valid(build_panel):
		return

	var content := build_panel.get_child(0)

	for child in content.get_children():

		if child.name.begins_with("Edit_"):

			child.queue_free()


func show_object_controls():

	remove_object_controls()

	var content := build_panel.get_child(0) as VBoxContainer

	add_edit_button(
		content,
		"Edit_Left",
		"تحريك يسار",
		"Move left",
		"move_left"
	)

	add_edit_button(
		content,
		"Edit_Right",
		"تحريك يمين",
		"Move right",
		"move_right"
	)

	add_edit_button(
		content,
		"Edit_Forward",
		"تحريك للأمام",
		"Move forward",
		"move_forward"
	)

	add_edit_button(
		content,
		"Edit_Back",
		"تحريك للخلف",
		"Move backward",
		"move_back"
	)

	add_edit_button(
		content,
		"Edit_RotateLeft",
		"تدوير يسار",
		"Rotate left",
		"rotate_left"
	)

	add_edit_button(
		content,
		"Edit_RotateRight",
		"تدوير يمين",
		"Rotate right",
		"rotate_right"
	)

	add_edit_button(
		content,
		"Edit_Bigger",
		"تكبير",
		"Increase size",
		"bigger"
	)

	add_edit_button(
		content,
		"Edit_Smaller",
		"تصغير",
		"Decrease size",
		"smaller"
	)

	add_edit_button(
		content,
		"Edit_Delete",
		"حذف العنصر",
		"Delete object",
		"delete"
	)


func add_edit_button(parent: VBoxContainer,
		node_name: String,
		arabic: String,
		english: String,
		operation: String):

	var button := Button.new()

	button.name = node_name
	button.custom_minimum_size = Vector2(220, 40)

	register_text(button, arabic, english)

	parent.add_child(button)

	button.pressed.connect(
		func(): edit_selected_object(operation)
	)


func edit_selected_object(operation: String):

	if not is_instance_valid(selected_object):
		return

	match operation:

		"move_left":
			selected_object.global_position.x -= 2.0

		"move_right":
			selected_object.global_position.x += 2.0

		"move_forward":
			selected_object.global_position.z -= 2.0

		"move_back":
			selected_object.global_position.z += 2.0

		"rotate_left":
			selected_object.rotate_y(deg_to_rad(15.0))

		"rotate_right":
			selected_object.rotate_y(deg_to_rad(-15.0))

		"bigger":

			selected_object.scale *= 1.1

		"smaller":

			selected_object.scale *= 0.9

		"delete":

			delete_selected_object()


func delete_selected_object():

	if not is_instance_valid(selected_object):
		return

	placed_objects.erase(selected_object)

	selected_object.queue_free()

	selected_object = null

	remove_object_controls()

	status_label.text = tr_text(
		"تم حذف العنصر",
		"Object deleted"
	)


# --------------------------------------------------
# INPUT
# UI controls receive their events before this function.
# --------------------------------------------------

func _unhandled_input(event):

	if not is_game_started:
		return

	if event is InputEventScreenTouch:

		if event.pressed:

			touch_points[event.index] = event.position
			touch_starts[event.index] = event.position

		else:

			if touch_points.has(event.index):

				var start_position: Vector2 = touch_starts.get(
					event.index,
					event.position
				)

				var movement := start_position.distance_to(
					event.position
				)

				if movement < 15.0 and touch_points.size() == 1:

					handle_world_tap(event.position)

			touch_points.erase(event.index)
			touch_starts.erase(event.index)

		return

	if event is InputEventScreenDrag:

		if not touch_points.has(event.index):
			return

		var old_positions: Dictionary = touch_points.duplicate()

		touch_points[event.index] = event.position

		var ids = touch_points.keys()

		if ids.size() == 1:

			if selected_building == "":

				camera_pivot.rotate_y(
					-event.relative.x * TOUCH_ROTATION_SPEED
				)

				camera_pitch.rotation.x = clamp(
					camera_pitch.rotation.x
					- event.relative.y * TOUCH_ROTATION_SPEED,
					deg_to_rad(-80),
					deg_to_rad(-10)
				)

		elif ids.size() >= 2:

			var id_a = ids[0]
			var id_b = ids[1]

			var old_a: Vector2 = old_positions[id_a]
			var old_b: Vector2 = old_positions[id_b]

			var new_a: Vector2 = touch_points[id_a]
			var new_b: Vector2 = touch_points[id_b]

			var old_distance := old_a.distance_to(old_b)
			var new_distance := new_a.distance_to(new_b)

			zoom_distance = clamp(
				zoom_distance
				+ (old_distance - new_distance) * TOUCH_ZOOM_SPEED,
				ZOOM_MIN,
				ZOOM_MAX
			)

			camera.position.z = zoom_distance

			var old_center := (old_a + old_b) * 0.5
			var new_center := (new_a + new_b) * 0.5

			var movement := new_center - old_center

			camera_pivot.translate(
				Vector3(
					-movement.x * zoom_distance * 0.0015,
					0,
					-movement.y * zoom_distance * 0.0015
				)
			)

		return

	if event is InputEventMouseButton:

		if event.button_index == MOUSE_BUTTON_LEFT:

			if event.pressed:

				mouse_down = true
				mouse_dragged = false
				mouse_start = event.position

			else:

				if mouse_down and not mouse_dragged:

					handle_world_tap(event.position)

				mouse_down = false

		if event.pressed:

			if event.button_index == MOUSE_BUTTON_WHEEL_UP:

				change_zoom(-4.0)

			elif event.button_index == MOUSE_BUTTON_WHEEL_DOWN:

				change_zoom(4.0)

		if event.button_index == MOUSE_BUTTON_RIGHT:

			panning = event.pressed

	elif event is InputEventMouseMotion:

		if mouse_down:

			if mouse_start.distance_to(event.position) > 8.0:

				mouse_dragged = true

				camera_pivot.rotate_y(
					-event.relative.x * 0.004
				)

				camera_pitch.rotation.x = clamp(
					camera_pitch.rotation.x
					- event.relative.y * 0.004,
					deg_to_rad(-80),
					deg_to_rad(-10)
				)

		elif panning:

			camera_pivot.translate(
				Vector3(
					-event.relative.x * 0.05,
					0,
					-event.relative.y * 0.05
				)
			)


# --------------------------------------------------
# WORLD TAP
# --------------------------------------------------

func handle_world_tap(position_value: Vector2):

	if selected_building != "":

		place_selected_building(position_value)

	else:

		var object := find_object_at_screen_position(position_value)

		select_object(object)


# --------------------------------------------------
# CAMERA ZOOM
# --------------------------------------------------

func change_zoom(amount: float):

	zoom_distance = clamp(
		zoom_distance + amount,
		ZOOM_MIN,
		ZOOM_MAX
	)

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
	camera.near = 0.1
	camera.far = 1500.0

	camera_pitch.add_child(camera)


# --------------------------------------------------
# KEYBOARD MOVEMENT
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

		camera_pivot.translate(
			movement.normalized() * CAMERA_SPEED * delta
		)
