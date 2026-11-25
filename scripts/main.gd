
extends Node3D

# KINGDOMS OF THE DESERT
# Godot 4.3 - 3D World Foundation

var camera_pivot: Node3D
var camera_pitch: Node3D
var camera: Camera3D

var zoom_distance := 48.0
var dragging := false
var panning := false
var touch_points := {}
var last_pinch_distance := 0.0

var world_config: Dictionary = {}

const ZOOM_MIN := 12.0
const ZOOM_MAX := 100.0
const CAMERA_SPEED := 30.0

const SAND := Color(0.76, 0.61, 0.39)
const STONE := Color(0.68, 0.59, 0.47)
const DARK_STONE := Color(0.36, 0.29, 0.22)
const WOOD := Color(0.28, 0.14, 0.07)
const GREEN := Color(0.13, 0.32, 0.13)


func _ready():
    load_world_config()
    create_environment()
    create_terrain()
    create_castle()
    create_village()
    create_palms()
    create_rocks()
    create_oasis()
    create_lighting()
    create_camera()


# CONFIGURATION

func load_world_config():
    var path = "res://data/world_config.json"

    if FileAccess.file_exists(path):
        var file = FileAccess.open(path, FileAccess.READ)
        var parsed = JSON.parse_string(file.get_as_text())

        if parsed is Dictionary:
            world_config = parsed.get("world", {})

    print("Kingdoms of the Desert: World configuration loaded")


# MATERIALS

func make_material(color: Color, roughness := 0.9):
    var mat = StandardMaterial3D.new()
    mat.albedo_color = color
    mat.roughness = roughness
    return mat


func add_box(pos: Vector3, dimensions: Vector3, color: Color, parent: Node = null, angle := 0.0):
    var item = MeshInstance3D.new()
    var mesh = BoxMesh.new()

    mesh.size = dimensions
    item.mesh = mesh
    item.position = pos
    item.rotation.y = angle
    item.material_override = make_material(color)

    if parent == null:
        add_child(item)
    else:
        parent.add_child(item)

    return item


func add_cylinder(pos: Vector3, radius: float, height: float, color: Color, parent: Node = null):
    var item = MeshInstance3D.new()
    var mesh = CylinderMesh.new()

    mesh.top_radius = radius
    mesh.bottom_radius = radius
    mesh.height = height
    mesh.radial_segments = 20

    item.mesh = mesh
    item.position = pos
    item.material_override = make_material(color)

    if parent == null:
        add_child(item)
    else:
        parent.add_child(item)

    return item


# SKY AND ENVIRONMENT

func create_environment():
    var world = WorldEnvironment.new()
    var env = Environment.new()

    var sky = Sky.new()
    var sky_material = ProceduralSkyMaterial.new()

    sky_material.sky_top_color = Color(0.13, 0.35, 0.62)
    sky_material.sky_horizon_color = Color(0.72, 0.78, 0.84)
    sky_material.ground_bottom_color = Color(0.38, 0.30, 0.22)
    sky_material.ground_horizon_color = Color(0.72, 0.65, 0.54)

    sky.sky_material = sky_material

    env.background_mode = Environment.BG_SKY
    env.sky = sky
    env.ambient_light_source = Environment.AMBIENT_SOURCE_SKY
    env.ambient_light_energy = 0.8
    env.tonemap_mode = Environment.TONE_MAPPER_FILMIC

    world.environment = env
    add_child(world)


# DESERT TERRAIN

func terrain_height(x: float, z: float) -> float:
    var noise = sin(x * 0.045) * 1.3
    noise += cos(z * 0.055) * 1.0
    noise += sin((x + z) * 0.025) * 1.5

    return noise


func create_terrain():
    var st = SurfaceTool.new()
    st.begin(Mesh.PRIMITIVE_TRIANGLES)

    var size := 200.0
    var divisions := 100
    var step = size / float(divisions)

    for z in range(divisions):
        for x in range(divisions):
            var x0 = -size / 2.0 + x * step
            var z0 = -size / 2.0 + z * step
            var x1 = x0 + step
            var z1 = z0 + step

            var p00 = Vector3(x0, terrain_height(x0, z0), z0)
            var p10 = Vector3(x1, terrain_height(x1, z0), z0)
            var p01 = Vector3(x0, terrain_height(x0, z1), z1)
            var p11 = Vector3(x1, terrain_height(x1, z1), z1)

            var shade = sin(x0 * 0.18) * 0.025
            var color = Color(
                SAND.r + shade,
                SAND.g + shade,
                SAND.b + shade
            )

            st.set_color(color)
            st.add_vertex(p00)

            st.set_color(color)
            st.add_vertex(p01)

            st.set_color(color)
            st.add_vertex(p10)

            st.set_color(color)
            st.add_vertex(p10)

            st.set_color(color)
            st.add_vertex(p01)

            st.set_color(color)
            st.add_vertex(p11)

    st.generate_normals()

    var ground = MeshInstance3D.new()
    ground.mesh = st.commit()

    var mat = make_material(Color.WHITE)
    mat.vertex_color_use_as_albedo = true
    ground.material_override = mat

    add_child(ground)


# CASTLE

func create_castle():
    var castle = Node3D.new()
    add_child(castle)

    add_box(Vector3(0, 0.4, 0), Vector3(25, 0.8, 25), DARK_STONE, castle)

    # Outer walls
    add_box(Vector3(-11, 2.8, 0), Vector3(2, 5, 22), STONE, castle)
    add_box(Vector3(11, 2.8, 0), Vector3(2, 5, 22), STONE, castle)
    add_box(Vector3(0, 2.8, -11), Vector3(22, 5, 2), STONE, castle)

    # Front entrance
    add_box(Vector3(-6, 2.8, 11), Vector3(10, 5, 2), STONE, castle)
    add_box(Vector3(6, 2.8, 11), Vector3(10, 5, 2), STONE, castle)

    # Gate
    add_box(Vector3(0, 2, 11.2), Vector3(2.8, 4, 0.4), WOOD, castle)
    add_box(Vector3(0, 5.5, 11), Vector3(5, 0.8, 2.5), DARK_STONE, castle)

    # Corner towers
    for x in [-11.0, 11.0]:
        for z in [-11.0, 11.0]:
            create_tower(Vector3(x, 0, z), castle)

    # Central fortress
    add_box(Vector3(0, 3.5, -2), Vector3(10, 7, 9), Color(0.70, 0.59, 0.45), castle)
    add_box(Vector3(0, 7.2, -2), Vector3(11, 0.7, 10), DARK_STONE, castle)

    # Keep towers
    for x in [-4.5, 4.5]:
        for z in [-6.0, 2.0]:
            add_cylinder(Vector3(x, 4, z), 1.2, 8, STONE, castle)


func create_tower(pos: Vector3, parent: Node):
    var tower = Node3D.new()
    tower.position = pos
    parent.add_child(tower)

    add_cylinder(Vector3(0, 4, 0), 2.1, 8, STONE, tower)
    add_cylinder(Vector3(0, 8.2, 0), 2.3, 0.5, DARK_STONE, tower)

    for i in range(8):
        var angle = TAU * float(i) / 8.0
        var x = cos(angle) * 1.7
        var z = sin(angle) * 1.7

        add_box(
            Vector3(x, 8.9, z),
            Vector3(0.8, 1.1, 0.8),
            STONE,
            tower,
            angle
        )


# VILLAGE

func create_village():
    add_box(
        Vector3(-19, 0.05, 22),
        Vector3(42, 0.1, 4),
        Color(0.59, 0.41, 0.24)
    )

    for i in range(8):
        var x = -27.0 + float(i % 4) * 10.0
        var z = 20.0 + floor(float(i) / 4.0) * 10.0
        create_house(Vector3(x, 0, z))


func create_house(pos: Vector3):
    var house = Node3D.new()
    house.position = pos
    add_child(house)

    add_box(
        Vector3(0, 1.7, 0),
        Vector3(5.5, 3.4, 5),
        Color(0.77, 0.65, 0.48),
        house
    )

    # Roof
    add_box(
        Vector3(-0.8, 3.6, 0),
        Vector3(3.2, 0.5, 6),
        Color(0.43, 0.21, 0.12),
        house,
        -0.45
    )

    add_box(
        Vector3(0.8, 3.6, 0),
        Vector3(3.2, 0.5, 6),
        Color(0.43, 0.21, 0.12),
        house,
        0.45
    )

    # Door
    add_box(
        Vector3(0, 1, 2.56),
        Vector3(1.1, 2, 0.15),
        WOOD,
        house
    )

    # Windows
    for x in [-1.7, 1.7]:
        add_box(
            Vector3(x, 2, 2.58),
            Vector3(0.8, 0.9, 0.12),
            DARK_STONE,
            house
        )


# PALM TREES

func create_palms():
    var positions = [
        Vector3(-30, 0, -20),
        Vector3(30, 0, -22),
        Vector3(-32, 0, 18),
        Vector3(32, 0, 18),
        Vector3(-25, 0, 40),
        Vector3(22, 0, 38),
        Vector3(40, 0, 0),
        Vector3(-40, 0, 0)
    ]

    for p in positions:
        create_palm(p)


func create_palm(pos: Vector3):
    var palm = Node3D.new()
    palm.position = pos
    add_child(palm)

    add_cylinder(
        Vector3(0, 2.5, 0),
        0.4,
        5,
        Color(0.35, 0.21, 0.10),
        palm
    )

    for i in range(8):
        var angle = TAU * float(i) / 8.0

        var leaf = add_box(
            Vector3(cos(angle) * 1.7, 5, sin(angle) * 1.7),
            Vector3(3.8, 0.18, 0.65),
            GREEN,
            palm,
            angle
        )

        leaf.rotation.z = -0.25


# ROCKS

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
        rock.material_override = make_material(Color(0.43, 0.36, 0.27))

        add_child(rock)


# OASIS

func create_oasis():
    var water = MeshInstance3D.new()
    var mesh = CylinderMesh.new()

    mesh.top_radius = 8
    mesh.bottom_radius = 8
    mesh.height = 0.15
    mesh.radial_segments = 48

    water.mesh = mesh
    water.position = Vector3(42, 0.3, -35)

    var water_material = make_material(Color(0.08, 0.43, 0.58), 0.2)
    water_material.metallic = 0.15
    water.material_override = water_material

    add_child(water)


# LIGHTING

func create_lighting():
    var sun = DirectionalLight3D.new()

    sun.rotation_degrees = Vector3(-48, -35, 0)
    sun.light_energy = 1.5
    sun.shadow_enabled = true
    sun.directional_shadow_max_distance = 100

    add_child(sun)


# CAMERA

func create_camera():
    camera_pivot = Node3D.new()
    add_child(camera_pivot)

    camera_pitch = Node3D.new()
    camera_pitch.rotation.x = deg_to_rad(-40)
    camera_pivot.add_child(camera_pitch)

    camera = Camera3D.new()
    camera.position = Vector3(0, 0, zoom_distance)
    camera.fov = 50
    camera.current = true

    camera_pitch.add_child(camera)


# INPUT

func _input(event):

    # Touch
    if event is InputEventScreenTouch:
        if event.pressed:
            touch_points[event.index] = event.position

            if touch_points.size() == 2:
                var points = touch_points.values()
                last_pinch_distance = points[0].distance_to(points[1])
        else:
            touch_points.erase(event.index)

            if touch_points.size() < 2:
                last_pinch_distance = 0.0

    elif event is InputEventScreenDrag:
        if touch_points.has(event.index):
            touch_points[event.index] = event.position

        if touch_points.size() == 1:
            camera_pivot.rotate_y(-event.relative.x * 0.004)

            camera_pitch.rotation.x = clamp(
                camera_pitch.rotation.x - event.relative.y * 0.004,
                deg_to_rad(-80),
                deg_to_rad(-10)
            )

        elif touch_points.size() >= 2:
            var points = touch_points.values()
            var distance = points[0].distance_to(points[1])

            if last_pinch_distance > 0:
                zoom_distance = clamp(
                    zoom_distance + (last_pinch_distance - distance) * 0.08,
                    ZOOM_MIN,
                    ZOOM_MAX
                )

                camera.position.z = zoom_distance

            last_pinch_distance = distance

            var movement = event.relative
            camera_pivot.translate(
                Vector3(-movement.x * 0.025, 0, -movement.y * 0.025)
            )

    # Mouse
    elif event is InputEventMouseButton:
        if event.button_index == MOUSE_BUTTON_LEFT:
            dragging = event.pressed

        if event.button_index == MOUSE_BUTTON_RIGHT or event.button_index == MOUSE_BUTTON_MIDDLE:
            panning = event.pressed

        if event.pressed:
            if event.button_index == MOUSE_BUTTON_WHEEL_UP:
                change_zoom(-4)

            elif event.button_index == MOUSE_BUTTON_WHEEL_DOWN:
                change_zoom(4)

    elif event is InputEventMouseMotion:
        if dragging:
            camera_pivot.rotate_y(-event.relative.x * 0.004)

            camera_pitch.rotation.x = clamp(
                camera_pitch.rotation.x - event.relative.y * 0.004,
                deg_to_rad(-80),
                deg_to_rad(-10)
            )

        elif panning:
            camera_pivot.translate(
                Vector3(-event.relative.x * 0.05, 0, -event.relative.y * 0.05)
            )


func change_zoom(amount: float):
    zoom_distance = clamp(zoom_distance + amount, ZOOM_MIN, ZOOM_MAX)
    camera.position.z = zoom_distance


func _process(delta):
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
        camera_pivot.translate(movement.normalized() * CAMERA_SPEED * delta)
