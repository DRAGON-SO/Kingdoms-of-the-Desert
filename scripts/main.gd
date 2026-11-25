
extends Node3D

# KINGDOMS OF THE DESERT
# Godot 4.3

var camera_pivot: Node3D
var camera_pitch: Node3D
var camera: Camera3D

var zoom_distance := 48.0
var dragging := false
var panning := false

# Touch controls
var touch_points: Dictionary = {}

var world_config: Dictionary = {}

const WORLD_SIZE := 200.0
const TERRAIN_DIVISIONS := 150

const ZOOM_MIN := 12.0
const ZOOM_MAX := 100.0
const CAMERA_SPEED := 30.0

const TOUCH_ROTATION_SPEED := 0.004
const TOUCH_ZOOM_SPEED := 0.06
const TOUCH_PAN_SPEED := 0.0015

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

        if file:
            var parsed = JSON.parse_string(file.get_as_text())

            if parsed is Dictionary:
                world_config = parsed.get("world", {})

    print("Kingdoms of the Desert loaded")


# TERRAIN HEIGHT

func terrain_height(x: float, z: float) -> float:
    var height = sin(x * 0.045) * 0.8
    height += cos(z * 0.055) * 0.65
    height += sin((x + z) * 0.025) * 0.9

    return height


# MATERIALS

func make_material(color: Color, roughness := 0.9):
    var mat = StandardMaterial3D.new()
    mat.albedo_color = color
    mat.roughness = roughness
    return mat


func add_box(pos: Vector3, dimensions: Vector3, color: Color,
        parent: Node = null, angle := 0.0):

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


func add_cylinder(pos: Vector3, radius: float, height: float,
        color: Color, parent: Node = null):

    var item = MeshInstance3D.new()
    var mesh = CylinderMesh.new()

    mesh.top_radius = radius
    mesh.bottom_radius = radius
    mesh.height = height
    mesh.radial_segments = 32

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
    sky_material.sky_horizon_color = Color(0.78, 0.78, 0.75)
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

func create_terrain():
    var st = SurfaceTool.new()
    st.begin(Mesh.PRIMITIVE_TRIANGLES)

    var step = WORLD_SIZE / float(TERRAIN_DIVISIONS)

    for z in range(TERRAIN_DIVISIONS):
        for x in range(TERRAIN_DIVISIONS):

            var x0 = -WORLD_SIZE / 2.0 + x * step
            var z0 = -WORLD_SIZE / 2.0 + z * step

            var x1 = x0 + step
            var z1 = z0 + step

            var p00 = Vector3(x0, terrain_height(x0, z0), z0)
            var p10 = Vector3(x1, terrain_height(x1, z0), z0)
            var p01 = Vector3(x0, terrain_height(x0, z1), z1)
            var p11 = Vector3(x1, terrain_height(x1, z1), z1)

            st.set_uv(Vector2(x0 / 10.0, z0 / 10.0))
            st.add_vertex(p00)

            st.set_uv(Vector2(x0 / 10.0, z1 / 10.0))
            st.add_vertex(p01)

            st.set_uv(Vector2(x1 / 10.0, z0 / 10.0))
            st.add_vertex(p10)

            st.set_uv(Vector2(x1 / 10.0, z0 / 10.0))
            st.add_vertex(p10)

            st.set_uv(Vector2(x0 / 10.0, z1 / 10.0))
            st.add_vertex(p01)

            st.set_uv(Vector2(x1 / 10.0, z1 / 10.0))
            st.add_vertex(p11)

    st.generate_normals()

    var ground = MeshInstance3D.new()
    ground.name = "DesertTerrain"
    ground.mesh = st.commit()

    # SAND MATERIAL

    var mat = StandardMaterial3D.new()

    mat.albedo_color = Color.WHITE
    mat.albedo_texture = load(
        "res://assets/materials/sand_diffuse.png"
    )

    # Improved distant texture filtering
    mat.texture_filter = BaseMaterial3D.TEXTURE_FILTER_LINEAR_WITH_MIPMAPS_ANISOTROPIC

    # Correct Godot 4.3 setting
    mat.texture_repeat = true

    mat.normal_enabled = true
    mat.normal_texture = load(
        "res://assets/materials/sand_normal.png"
    )

    mat.roughness = 1.0
    mat.roughness_texture = load(
        "res://assets/materials/sand_roughness.png"
    )

    mat.ao_enabled = true
    mat.ao_texture = load(
        "res://assets/materials/sand_ao.png"
    )

    ground.material_override = mat
    add_child(ground)


# CASTLE

func create_castle():
    var castle = Node3D.new()
    castle.name = "DesertCastle"

    castle.position.y = terrain_height(0, 0)
    add_child(castle)

    add_box(
        Vector3(0, 0.4, 0),
        Vector3(25, 0.8, 25),
        DARK_STONE,
        castle
    )

    add_box(Vector3(-11, 2.8, 0), Vector3(2, 5, 22), STONE, castle)
    add_box(Vector3(11, 2.8, 0), Vector3(2, 5, 22), STONE, castle)
    add_box(Vector3(0, 2.8, -11), Vector3(22, 5, 2), STONE, castle)

    add_box(Vector3(-6, 2.8, 11), Vector3(10, 5, 2), STONE, castle)
    add_box(Vector3(6, 2.8, 11), Vector3(10, 5, 2), STONE, castle)

    add_box(Vector3(0, 2, 11.2), Vector3(2.8, 4, 0.4), WOOD, castle)
    add_box(Vector3(0, 5.5, 11), Vector3(5, 0.8, 2.5), DARK_STONE, castle)

    for x in [-11.0, 11.0]:
        for z in [-11.0, 11.0]:
            create_tower(Vector3(x, 0, z), castle)

    add_box(
        Vector3(0, 3.5, -2),
        Vector3(10, 7, 9),
        Color(0.70, 0.59, 0.45),
        castle
    )

    add_box(
        Vector3(0, 7.2, -2),
        Vector3(11, 0.7, 10),
        DARK_STONE,
        castle
    )

    for x in [-4.5, 4.5]:
        for z in [-6.0, 2.0]:
            add_cylinder(
                Vector3(x, 4, z),
                1.2,
                8,
                STONE,
                castle
            )


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
    var road = add_box(
        Vector3(-19, 0, 22),
        Vector3(42, 0.1, 4),
        Color(0.59, 0.41, 0.24)
    )

    road.position.y = terrain_height(-19, 22) + 0.06

    for i in range(8):
        var x = -27.0 + float(i % 4) * 10.0
        var z = 20.0 + floor(float(i) / 4.0) * 10.0

        create_house(Vector3(x, terrain_height(x, z), z))


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

    add_box(
        Vector3(0, 1, 2.56),
        Vector3(1.1, 2, 0.15),
        WOOD,
        house
    )

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
        p.y = terrain_height(p.x, p.z)
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
        rock.position = Vector3(
            x,
            terrain_height(x, z) + 0.5,
            z
        )

        rock.scale = Vector3(1.5, 0.7, 1.2)
        rock.material_override = make_material(
            Color(0.43, 0.36, 0.27)
        )

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

    water.position = Vector3(
        42,
        terrain_height(42, -35) + 0.3,
        -35
    )

    var water_material = make_material(
        Color(0.08, 0.43, 0.58),
        0.2
    )

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


# TOUCH INPUT

func _input(event):

    # Finger pressed or released
    if event is InputEventScreenTouch:

        if event.pressed:
            touch_points[event.index] = event.position

        else:
            touch_points.erase(event.index)

        return

    # Finger movement
    if event is InputEventScreenDrag:

        if not touch_points.has(event.index):
            return

        var old_positions: Dictionary = touch_points.duplicate()

        touch_points[event.index] = event.position

        var ids = touch_points.keys()

        # ONE FINGER: rotate camera only
        if ids.size() == 1:

            camera_pivot.rotate_y(
                -event.relative.x * TOUCH_ROTATION_SPEED
            )

            camera_pitch.rotation.x = clamp(
                camera_pitch.rotation.x
                - event.relative.y * TOUCH_ROTATION_SPEED,
                deg_to_rad(-80),
                deg_to_rad(-10)
            )

        # TWO FINGERS: zoom and pan only
        elif ids.size() >= 2:

            var id_a = ids[0]
            var id_b = ids[1]

            var old_a: Vector2 = old_positions[id_a]
            var old_b: Vector2 = old_positions[id_b]

            var new_a: Vector2 = touch_points[id_a]
            var new_b: Vector2 = touch_points[id_b]

            var old_center = (old_a + old_b) * 0.5
            var new_center = (new_a + new_b) * 0.5

            var old_distance = old_a.distance_to(old_b)
            var new_distance = new_a.distance_to(new_b)

            # Pinch zoom
            var zoom_change = old_distance - new_distance

            zoom_distance = clamp(
                zoom_distance + zoom_change * TOUCH_ZOOM_SPEED,
                ZOOM_MIN,
                ZOOM_MAX
            )

            camera.position.z = zoom_distance

            # Two-finger pan
            var center_movement = new_center - old_center

            var pan_scale = zoom_distance * TOUCH_PAN_SPEED

            camera_pivot.translate(
                Vector3(
                    -center_movement.x * pan_scale,
                    0,
                    -center_movement.y * pan_scale
                )
            )

        return

    # MOUSE INPUT

    if event is InputEventMouseButton:

        if event.button_index == MOUSE_BUTTON_LEFT:
            dragging = event.pressed

        if event.button_index == MOUSE_BUTTON_RIGHT \
        or event.button_index == MOUSE_BUTTON_MIDDLE:
            panning = event.pressed

        if event.pressed:

            if event.button_index == MOUSE_BUTTON_WHEEL_UP:
                change_zoom(-4)

            elif event.button_index == MOUSE_BUTTON_WHEEL_DOWN:
                change_zoom(4)

    elif event is InputEventMouseMotion:

        # Left mouse button: rotate
        if dragging:

            camera_pivot.rotate_y(
                -event.relative.x * 0.004
            )

            camera_pitch.rotation.x = clamp(
                camera_pitch.rotation.x
                - event.relative.y * 0.004,
                deg_to_rad(-80),
                deg_to_rad(-10)
            )

        # Right or middle mouse button: pan
        elif panning:

            camera_pivot.translate(
                Vector3(
                    -event.relative.x * 0.05,
                    0,
                    -event.relative.y * 0.05
                )
            )


# ZOOM

func change_zoom(amount: float):

    zoom_distance = clamp(
        zoom_distance + amount,
        ZOOM_MIN,
        ZOOM_MAX
    )

    camera.position.z = zoom_distance


# KEYBOARD MOVEMENT

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

        camera_pivot.translate(
            movement.normalized() * CAMERA_SPEED * delta
        )
