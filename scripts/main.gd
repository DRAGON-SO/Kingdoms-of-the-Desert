
extends Node3D

# KINGDOMS OF THE DESERT
# Godot 4.3

var camera_pivot: Node3D
var camera_pitch: Node3D
var camera: Camera3D
var sun: DirectionalLight3D
var world_environment: WorldEnvironment

var zoom_distance := 48.0
var dragging := false
var panning := false
var touch_points: Dictionary = {}
var touch_start: Dictionary = {}

var world_config: Dictionary = {}

# BUILDING SYSTEM
var selected_building := ""
var placed_buildings: Array[Node3D] = []
var selected_object: Node3D
var selected_object_index := -1

# UI
var canvas: CanvasLayer
var main_menu: PanelContainer
var build_panel: PanelContainer
var settings_panel: PanelContainer
var status_label: Label
var language_button: Button
var font_ar: FontFile

var is_game_started := false
var current_language := "en"

# SETTINGS
var sunlight_strength := 0.75
var ambient_strength := 0.45
var master_volume := 0.8
var music_volume := 0.7
var effects_volume := 0.8

var music_bus := -1
var effects_bus := -1

# INPUT
var mouse_press_position := Vector2.ZERO
var mouse_is_down := false
var touch_moved := false

const ZOOM_MIN := 12.0
const ZOOM_MAX := 100.0
const CAMERA_SPEED := 30.0

const TOUCH_ROTATION_SPEED := 0.004
const TOUCH_ZOOM_SPEED := 0.06
const TOUCH_PAN_SPEED := 0.0015

const HOUSE_TARGET_HEIGHT := 8.0
const CASTLE_TARGET_HEIGHT := 25.0

const GREEN := Color(0.13, 0.32, 0.13)


func _ready():

	load_world_config()
	load_arabic_font()
	setup_audio_buses()

	create_environment()
	create_terrain()
	create_rocks()
	create_oasis()
	create_lighting()
	create_camera()

	create_interface()

	show_main_menu()


# --------------------------------------------------
# LANGUAGE
# --------------------------------------------------

func load_arabic_font():

	var path = "res://assets/fonts/NotoSansArabic.ttf"

	if ResourceLoader.exists(path):

		font_ar = load(path)


func tr_text(arabic: String, english: String) -> String:

	if current_language == "ar":
		return arabic

	return english


func apply_font(control: Control):

	if font_ar != null:
		control.add_theme_font_override("font", font_ar)


func set_language(language: String):

	current_language = language

	update_interface_text()


func update_interface_text():

	if main_menu == null:
		return

	main_menu.get_node("Content/Title").text = tr_text(
		"ممالك الصحراء",
		"KINGDOMS OF THE DESERT"
	)

	main_menu.get_node("Content/Start").text = tr_text(
		"بدء اللعبة",
		"START GAME"
	)

	main_menu.get_node("Content/Settings").text = tr_text(
		"الإعدادات",
		"SETTINGS"
	)

	main_menu.get_node("Content/Exit").text = tr_text(
		"إغلاق القائمة",
		"CLOSE MENU"
	)

	settings_panel.get_node("Content/SettingsTitle").text = tr_text(
		"إعدادات اللعبة",
		"GAME SETTINGS"
	)

	language_button.text = tr_text(
		"اللغة: العربية / English",
		"Language: English / العربية"
	)

	build_panel.get_node("Content/BuildTitle").text = tr_text(
		"قائمة البناء",
		"BUILD MENU"
	)

	build_panel.get_node("Content/Castle").text = tr_text(
		"بناء قلعة",
		"Build Castle"
	)

	build_panel.get_node("Content/House").text = tr_text(
		"بناء منزل",
		"Build House"
	)

	build_panel.get_node("Content/Cancel").text = tr_text(
		"إلغاء الاختيار",
		"Cancel Selection"
	)

	if status_label != null:
		status_label.text = tr_text(
			"اختر عنصرًا للبناء",
			"Choose an object to build"
		)


# --------------------------------------------------
# WORLD CONFIG
# --------------------------------------------------

func load_world_config():

	var path = "res://data/world_config.json"

	if FileAccess.file_exists(path):

		var file = FileAccess.open(path, FileAccess.READ)

		if file:

			var parsed = JSON.parse_string(file.get_as_text())

			if parsed is Dictionary:
				world_config = parsed.get("world", {})

	print("Kingdoms of the Desert loaded")


func terrain_height(_x: float, _z: float) -> float:

	return 0.0


func make_material(color: Color, roughness := 0.9):

	var mat = StandardMaterial3D.new()

	mat.albedo_color = color
	mat.roughness = roughness

	return mat


# --------------------------------------------------
# ENVIRONMENT
# --------------------------------------------------

func create_environment():

	world_environment = WorldEnvironment.new()

	var env = Environment.new()

	var sky = Sky.new()
	var sky_material = ProceduralSkyMaterial.new()

	sky_material.sky_top_color = Color(0.13, 0.35, 0.62)
	sky_material.sky_horizon_color = Color(0.78, 0.78, 0.75)
	sky_material.ground_bottom_color = Color(0.78, 0.72, 0.60)
	sky_material.ground_horizon_color = Color(0.78, 0.72, 0.60)

	sky.sky_material = sky_material

	env.background_mode = Environment.BG_SKY
	env.sky = sky

	env.ambient_light_source = Environment.AMBIENT_SOURCE_SKY
	env.ambient_light_energy = ambient_strength

	env.tonemap_mode = Environment.TONE_MAPPER_FILMIC

	world_environment.environment = env

	add_child(world_environment)


# --------------------------------------------------
# TERRAIN
# --------------------------------------------------

func create_terrain():

	var ground = MeshInstance3D.new()

	ground.name = "DesertTerrain"

	var plane = PlaneMesh.new()

	plane.size = Vector2(3000.0, 3000.0)
	plane.subdivide_width = 150
	plane.subdivide_depth = 150

	ground.mesh = plane

	var mat = StandardMaterial3D.new()

	mat.albedo_color = Color.WHITE

	var diffuse = load(
		"res://assets/materials/sand_diffuse.png"
	)

	if diffuse:
		mat.albedo_texture = diffuse

	mat.texture_filter = BaseMaterial3D.TEXTURE_FILTER_LINEAR_WITH_MIPMAPS_ANISOTROPIC
	mat.texture_repeat = true
	mat.uv1_scale = Vector3(100.0, 100.0, 1.0)

	var normal_map = load(
		"res://assets/materials/sand_normal.png"
	)

	if normal_map:

		mat.normal_enabled = true
		mat.normal_texture = normal_map
		mat.normal_scale = 0.35

	var roughness_map = load(
		"res://assets/materials/sand_roughness.png"
	)

	if roughness_map:

		mat.roughness = 1.0
		mat.roughness_texture = roughness_map

	var ao_map = load(
		"res://assets/materials/sand_ao.png"
	)

	if ao_map:

		mat.ao_enabled = true
		mat.ao_texture = ao_map

	ground.material_override = mat

	add_child(ground)


# --------------------------------------------------
# MODEL HELPERS
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

		if mesh_node == null or mesh_node.mesh == null:
			continue

		var local_transform = root.global_transform.affine_inverse() * mesh_node.global_transform
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

	var bounds = get_model_bounds(root)

	var height = maxf(bounds.size.y, 0.01)

	var factor = target_height / height

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

func create_castle(pos: Vector3):

	var castle_scene: PackedScene = load(
		"res://scenes/Castle.tscn"
	)

	if castle_scene == null:

		push_error("Castle scene could not be loaded")
		return null

	var castle = castle_scene.instantiate() as Node3D

	if castle == null:
		return null

	castle.name = "PlayerCastle"

	add_child(castle)

	castle.global_position = pos

	placed_buildings.append(castle)

	return castle


# --------------------------------------------------
# HOUSE
# --------------------------------------------------

func create_real_house(pos: Vector3):

	var house_scene: PackedScene = load(
		"res://scenes/House.tscn"
	)

	if house_scene == null:

		push_error("House scene could not be loaded")
		return null

	var house = house_scene.instantiate() as Node3D

	if house == null:
		return null

	house.name = "PlayerHouse"

	add_child(house)

	house.global_position = pos

	await get_tree().process_frame

	normalize_model(house, HOUSE_TARGET_HEIGHT)

	house.global_position = pos

	placed_buildings.append(house)

	return house


# --------------------------------------------------
# BUILDING INTERFACE
# --------------------------------------------------

func create_interface():

	canvas = CanvasLayer.new()

	canvas.name = "GameInterface"

	add_child(canvas)

	create_main_menu()
	create_settings_panel()
	create_build_panel()


func make_panel(parent: Control, panel_name: String,
		position_value: Vector2, width: float):

	var panel = PanelContainer.new()

	panel.name = panel_name
	panel.position = position_value
	panel.custom_minimum_size = Vector2(width, 0)

	parent.add_child(panel)

	return panel


func make_button(parent: VBoxContainer, node_name: String,
		text_value: String, callback: Callable):

	var button = Button.new()

	button.name = node_name
	button.text = text_value
	button.custom_minimum_size = Vector2(210, 48)

	apply_font(button)

	parent.add_child(button)

	button.pressed.connect(callback)

	return button


# --------------------------------------------------
# MAIN MENU
# --------------------------------------------------

func create_main_menu():

	main_menu = PanelContainer.new()

	main_menu.name = "MainMenu"

	main_menu.set_anchors_and_offsets_preset(
		Control.PRESET_CENTER
	)

	main_menu.custom_minimum_size = Vector2(300, 300)

	canvas.add_child(main_menu)

	var content = VBoxContainer.new()

	content.name = "Content"

	content.add_theme_constant_override("separation", 12)

	main_menu.add_child(content)

	var title = Label.new()

	title.name = "Title"
	title.text = "KINGDOMS OF THE DESERT"
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER

	apply_font(title)

	content.add_child(title)

	make_button(
		content,
		"Start",
		"START GAME",
		start_game
	)

	make_button(
		content,
		"Settings",
		"SETTINGS",
		open_settings
	)

	make_button(
		content,
		"Exit",
		"CLOSE MENU",
		close_main_menu
	)


func show_main_menu():

	main_menu.visible = true
	build_panel.visible = false
	settings_panel.visible = false

	is_game_started = false


func start_game():

	main_menu.visible = false
	settings_panel.visible = false
	build_panel.visible = true

	is_game_started = true


func close_main_menu():

	main_menu.visible = false


# --------------------------------------------------
# SETTINGS
# --------------------------------------------------

func create_settings_panel():

	settings_panel = PanelContainer.new()

	settings_panel.name = "SettingsPanel"

	settings_panel.position = Vector2(340, 20)
	settings_panel.custom_minimum_size = Vector2(310, 0)

	canvas.add_child(settings_panel)

	var content = VBoxContainer.new()

	content.name = "Content"
	content.add_theme_constant_override("separation", 8)

	settings_panel.add_child(content)

	var title = Label.new()

	title.name = "SettingsTitle"
	title.text = "GAME SETTINGS"
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER

	apply_font(title)

	content.add_child(title)

	language_button = Button.new()

	language_button.text = "Language"

	apply_font(language_button)

	content.add_child(language_button)

	language_button.pressed.connect(toggle_language)

	add_slider(
		content,
		"Sunlight",
		0.0,
		2.0,
		sunlight_strength,
		set_sunlight
	)

	add_slider(
		content,
		"Ambient Light",
		0.0,
		2.0,
		ambient_strength,
		set_ambient
	)

	add_slider(
		content,
		"Master Volume",
		0.0,
		1.0,
		master_volume,
		set_master_volume
	)

	add_slider(
		content,
		"Music Volume",
		0.0,
		1.0,
		music_volume,
		set_music_volume
	)

	add_slider(
		content,
		"Effects Volume",
		0.0,
		1.0,
		effects_volume,
		set_effects_volume
	)

	make_button(
		content,
		"Back",
		"BACK",
		close_settings
	)

	settings_panel.visible = false


func add_slider(parent: VBoxContainer, title_text: String,
		minimum: float, maximum: float,
		initial: float, callback: Callable):

	var label = Label.new()

	label.text = title_text
	apply_font(label)

	parent.add_child(label)

	var slider = HSlider.new()

	slider.min_value = minimum
	slider.max_value = maximum
	slider.step = 0.05
	slider.value = initial
	slider.custom_minimum_size = Vector2(220, 28)

	parent.add_child(slider)

	slider.value_changed.connect(callback)


func toggle_language():

	if current_language == "en":
		set_language("ar")
	else:
		set_language("en")


func open_settings():

	settings_panel.visible = true
	main_menu.visible = false


func close_settings():

	settings_panel.visible = false

	if is_game_started:
		build_panel.visible = true
	else:
		main_menu.visible = true


func set_sunlight(value: float):

	sunlight_strength = value

	if sun:
		sun.light_energy = value


func set_ambient(value: float):

	ambient_strength = value

	if world_environment:

		world_environment.environment.ambient_light_energy = value


# --------------------------------------------------
# AUDIO SETTINGS
# --------------------------------------------------

func setup_audio_buses():

	var master_index = AudioServer.get_bus_index("Master")

	if master_index >= 0:
		AudioServer.set_bus_volume_linear(
			master_index,
			master_volume
		)

	if AudioServer.get_bus_index("Music") == -1:

		AudioServer.add_bus()

		music_bus = AudioServer.bus_count - 1

		AudioServer.set_bus_name(music_bus, "Music")
		AudioServer.set_bus_send(music_bus, "Master")

	else:

		music_bus = AudioServer.get_bus_index("Music")

	if AudioServer.get_bus_index("Effects") == -1:

		AudioServer.add_bus()

		effects_bus = AudioServer.bus_count - 1

		AudioServer.set_bus_name(effects_bus, "Effects")
		AudioServer.set_bus_send(effects_bus, "Master")

	else:

		effects_bus = AudioServer.get_bus_index("Effects")


func set_master_volume(value: float):

	master_volume = value

	var index = AudioServer.get_bus_index("Master")

	if index >= 0:
		AudioServer.set_bus_volume_linear(index, value)


func set_music_volume(value: float):

	music_volume = value

	if music_bus >= 0:
		AudioServer.set_bus_volume_linear(music_bus, value)


func set_effects_volume(value: float):

	effects_volume = value

	if effects_bus >= 0:
		AudioServer.set_bus_volume_linear(effects_bus, value)


# --------------------------------------------------
# BUILD PANEL
# --------------------------------------------------

func create_build_panel():

	build_panel = PanelContainer.new()

	build_panel.name = "BuildPanel"

	build_panel.position = Vector2(20, 20)
	build_panel.custom_minimum_size = Vector2(230, 0)

	canvas.add_child(build_panel)

	var content = VBoxContainer.new()

	content.name = "Content"
	content.add_theme_constant_override("separation", 7)

	build_panel.add_child(content)

	var title = Label.new()

	title.name = "BuildTitle"
	title.text = "BUILD MENU"
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER

	apply_font(title)

	content.add_child(title)

	make_button(
		content,
		"Castle",
		"Build Castle",
		func(): choose_building("castle")
	)

	make_button(
		content,
		"House",
		"Build House",
		func(): choose_building("house")
	)

	make_button(
		content,
		"Cancel",
		"Cancel Selection",
		cancel_building
	)

	status_label = Label.new()

	status_label.text = "Choose an object"

	status_label.autowrap_mode = TextServer.AUTOWRAP_WORD

	apply_font(status_label)

	content.add_child(status_label)

	make_button(
		content,
		"Settings",
		"SETTINGS",
		open_settings
	)

	build_panel.visible = false


func create_build_panel_text():

	update_interface_text()


func choose_building(kind: String):

	selected_building = kind
	selected_object = null

	if kind == "castle":

		status_label.text = tr_text(
			"اختر مكان القلعة",
			"Tap a location for the castle"
		)

	elif kind == "house":

		status_label.text = tr_text(
			"اختر مكان المنزل",
			"Tap a location for the house"
		)


func cancel_building():

	selected_building = ""
	status_label.text = tr_text(
		"تم إلغاء الاختيار",
		"Selection cancelled"
	)


# --------------------------------------------------
# PLACEMENT
# --------------------------------------------------

func screen_to_ground(screen_position: Vector2):

	var ray_origin = camera.project_ray_origin(screen_position)
	var ray_direction = camera.project_ray_normal(screen_position)

	var ground_plane = Plane(Vector3.UP, 0.0)

	return ground_plane.intersects_ray(
		ray_origin,
		ray_direction
	)


func place_selected_building(screen_position: Vector2):

	if selected_building == "":
		return

	var hit = screen_to_ground(screen_position)

	if hit == null:
		return

	var build_position: Vector3 = hit

	if selected_building == "castle":

		var result = create_castle(build_position)

		if result != null:
			status_label.text = tr_text(
				"تم وضع القلعة",
				"Castle placed"
			)

	elif selected_building == "house":

		create_real_house(build_position)

		status_label.text = tr_text(
			"تم وضع المنزل",
			"House placed"
		)

	selected_building = ""


# --------------------------------------------------
# OBJECT SELECTION AND EDITING
# --------------------------------------------------

func find_object_at_screen_position(screen_position: Vector2):

	var best_object: Node3D = null
	var best_distance := 70.0

	for object in placed_buildings:

		if not is_instance_valid(object):
			continue

		var screen_point = camera.unproject_position(
			object.global_position
		)

		var distance = screen_point.distance_to(screen_position)

		if distance < best_distance:

			best_distance = distance
			best_object = object

	return best_object


func select_object(object: Node3D):

	selected_object = object

	if object == null:

		selected_object_index = -1

		status_label.text = tr_text(
			"لم يتم تحديد مبنى",
			"No building selected"
		)

		return

	selected_object_index = placed_buildings.find(object)

	status_label.text = tr_text(
		"تم تحديد المبنى. استخدم أدوات التحكم.",
		"Object selected. Use the controls."
	)

	show_object_controls()


func show_object_controls():

	if build_panel == null:
		return

	var content = build_panel.get_node("Content")

	for child in content.get_children():

		if child.name.begins_with("Edit_"):
			child.queue_free()

	add_edit_button(content, "Edit_Left", "تحريك يسار / Left", Vector3(-2, 0, 0))
	add_edit_button(content, "Edit_Right", "تحريك يمين / Right", Vector3(2, 0, 0))
	add_edit_button(content, "Edit_Forward", "تحريك للأمام / Forward", Vector3(0, 0, -2))
	add_edit_button(content, "Edit_Back", "تحريك للخلف / Back", Vector3(0, 0, 2))

	add_edit_button(content, "Edit_RotateLeft", "تدوير يسار / Rotate Left", Vector3(0, 100, 0))
	add_edit_button(content, "Edit_RotateRight", "تدوير يمين / Rotate Right", Vector3(0, -100, 0))

	add_edit_button(content, "Edit_Bigger", "تكبير / Bigger", Vector3(1.1, 1.1, 1.1))
	add_edit_button(content, "Edit_Smaller", "تصغير / Smaller", Vector3(0.9, 0.9, 0.9))

	var delete_button = Button.new()

	delete_button.name = "Edit_Delete"
	delete_button.text = tr_text("حذف المبنى", "Delete Object")

	content.add_child(delete_button)

	delete_button.pressed.connect(delete_selected_object)


func add_edit_button(parent: VBoxContainer, node_name: String,
		button_text: String, operation: Vector3):

	var button = Button.new()

	button.name = node_name
	button.text = button_text

	parent.add_child(button)

	button.pressed.connect(
		func(): edit_selected_object(node_name, operation)
	)


func edit_selected_object(operation_name: String, operation: Vector3):

	if not is_instance_valid(selected_object):
		return

	match operation_name:

		"Edit_Left", "Edit_Right", "Edit_Forward", "Edit_Back":

			selected_object.position += operation

		"Edit_RotateLeft", "Edit_RotateRight":

			selected_object.rotate_y(deg_to_rad(operation.y))

		"Edit_Bigger", "Edit_Smaller":

			selected_object.scale *= operation


func delete_selected_object():

	if not is_instance_valid(selected_object):
		return

	placed_buildings.erase(selected_object)

	selected_object.queue_free()

	selected_object = null

	status_label.text = tr_text(
		"تم حذف المبنى",
		"Object deleted"
	)


# --------------------------------------------------
# ROCKS AND OASIS
# --------------------------------------------------

func create_rocks():

	for i in range(40):

		var x = sin(float(i) * 12.7) * 65
		var z = cos(float(i) * 8.3) * 65

		if Vector2(x, z).length() < 20:
			continue

		var rock = MeshInstance3D.new()
		var mesh = SphereMesh.new()

		mesh.radius = 1
		mesh.height = 1.5

		rock.mesh = mesh

		rock.position = Vector3(x, 0.5, z)
		rock.scale = Vector3(1.5, 0.7, 1.2)

		rock.material_override = make_material(
			Color(0.43, 0.36, 0.27)
		)

		add_child(rock)


func create_oasis():

	var water = MeshInstance3D.new()
	var mesh = CylinderMesh.new()

	mesh.top_radius = 8
	mesh.bottom_radius = 8
	mesh.height = 0.15
	mesh.radial_segments = 48

	water.mesh = mesh

	water.position = Vector3(42, 0.3, -35)

	var water_material = make_material(
		Color(0.08, 0.43, 0.58),
		0.2
	)

	water_material.metallic = 0.15

	water.material_override = water_material

	add_child(water)


# --------------------------------------------------
# LIGHTING
# --------------------------------------------------

func create_lighting():

	sun = DirectionalLight3D.new()

	sun.rotation_degrees = Vector3(-48, -35, 0)

	sun.light_energy = sunlight_strength

	sun.shadow_enabled = true
	sun.directional_shadow_max_distance = 100

	add_child(sun)


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
# INPUT
# --------------------------------------------------

func _input(event):

	if not is_game_started:
		return

	if event is InputEventScreenTouch:

		if event.pressed:

			touch_points[event.index] = event.position
			touch_start[event.index] = event.position

		else:

			if touch_points.has(event.index):

				var start_position: Vector2 = touch_start.get(
					event.index,
					event.position
				)

				var movement = start_position.distance_to(event.position)

				if movement < 15.0 and touch_points.size() == 1:

					handle_world_tap(event.position)

			touch_points.erase(event.index)
			touch_start.erase(event.index)

		return

	if event is InputEventScreenDrag:

		if not touch_points.has(event.index):
			return

		var old_positions = touch_points.duplicate()

		touch_points[event.index] = event.position

		var ids = touch_points.keys()

		if ids.size() == 1:

			var start_position: Vector2 = touch_start.get(
				event.index,
				event.position
			)

			if start_position.distance_to(event.position) > 15.0:
				touch_moved = true

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

			var old_distance = old_a.distance_to(old_b)
			var new_distance = new_a.distance_to(new_b)

			zoom_distance = clamp(
				zoom_distance
				+ (old_distance - new_distance) * TOUCH_ZOOM_SPEED,
				ZOOM_MIN,
				ZOOM_MAX
			)

			camera.position.z = zoom_distance

		return

	if event is InputEventMouseButton:

		if event.button_index == MOUSE_BUTTON_LEFT:

			if event.pressed:

				mouse_is_down = true
				mouse_press_position = event.position

			else:

				if mouse_is_down:

					var movement = mouse_press_position.distance_to(
						event.position
					)

					if movement < 8.0:
						handle_world_tap(event.position)

				mouse_is_down = false

		if event.pressed:

			if event.button_index == MOUSE_BUTTON_WHEEL_UP:
				change_zoom(-4)

			elif event.button_index == MOUSE_BUTTON_WHEEL_DOWN:
				change_zoom(4)

		if event.button_index == MOUSE_BUTTON_RIGHT:
			panning = event.pressed

	elif event is InputEventMouseMotion:

		if mouse_is_down and mouse_press_position.distance_to(event.position) > 8.0:

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


func handle_world_tap(position: Vector2):

	if selected_building != "":

		place_selected_building(position)

	else:

		var object = find_object_at_screen_position(position)

		select_object(object)


# --------------------------------------------------
# ZOOM AND MOVEMENT
# --------------------------------------------------

func change_zoom(amount: float):

	zoom_distance = clamp(
		zoom_distance + amount,
		ZOOM_MIN,
		ZOOM_MAX
	)

	camera.position.z = zoom_distance


func _process(delta):

	if not is_game_started:
		return

	var movement = Vector3.ZERO

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
