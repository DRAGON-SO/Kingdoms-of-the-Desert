
extends Node3D

# ==========================================
# KINGDOMS OF THE DESERT
# Godot 4.3 - Mobile Balanced
# ==========================================

var camera_pivot: Node3D
var camera_pitch: Node3D
var camera: Camera3D

var dragging := false
var panning := false
var touch_points: Dictionary = {}

var zoom_distance := 48.0

const ZOOM_MIN := 12.0
const ZOOM_MAX := 85.0
const CAMERA_SPEED := 25.0

# COLORS

const SAND := Color(0.76, 0.62, 0.40)
const STONE := Color(0.68, 0.59, 0.47)
const DARK_STONE := Color(0.39, 0.32, 0.24)
const WOOD := Color(0.27, 0.13, 0.065)
const ROOF := Color(0.43, 0.19, 0.10)
const GREEN := Color(0.13, 0.30, 0.12)


func _ready():
    create_environment()
    create_terrain()
    create_castle()
    create_village()
    create_palms()
    create_rocks()
    create_lighting()
    create_camera()


# ==========================================
# MATERIALS
# ==========================================

func material(color: Color, roughness := 0.9) -> StandardMaterial3D:
    var m = StandardMaterial3D.new()
    m.albedo_color = color
    m.roughness = roughness
    return m


# ==========================================
# ENVIRONMENT
# ==========================================

func create_environment():
    var world = WorldEnvironment.new()
    var env = Environment.new()

    env.background_mode = Environment.BG_COLOR
    env.background_color = Color(0.42, 0.68, 0.88)

    env.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
    env.ambient_light_color = Color(0.82, 0.84, 0.88)
    env.ambient_light_energy = 0.8

    env.tonemap_mode = Environment.TONE_MAPPER_FILMIC
    env.tonemap_exposure = 1.15

    world.environment = env
    add_child(world)


# ==========================================
# DESERT TERRAIN
# ==========================================

func terrain_height(x: float, z: float) -> float:
    var h = sin(x * 0.055) * 0.65
    h += cos(z * 0.07) * 0.45
    h += sin((x + z) * 0.035) * 0.55

    var distance = Vector2(x, z).length()
    h *= clamp(distance / 15.0, 0.0, 1.0)

    return h


func create_terrain():
    var st = SurfaceTool.new()
    st.begin(Mesh.PRIMITIVE_TRIANGLES)

    var size = 140.0
    var divisions = 70
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

            var variation = sin(x0 * 0.3) * 0.025
            variation += cos(z0 * 0.2) * 0.02

            var c = Color(
                SAND.r + variation,
                SAND.g + variation,
                SAND.b + variation
            )

            st.set_color(c)
            st.add_vertex(p00)

            st.set_color(c)
            st.add_vertex(p01)

            st.set_color(c)
            st.add_vertex(p10)

            st.set_color(c)
            st.add_vertex(p10)

            st.set_color(c)
            st.add_vertex(p01)

            st.set_color(c)
            st.add_vertex(p11)

    st.generate_normals()

    var mesh = st.commit()

    var ground = MeshInstance3D.new()
    ground.mesh = mesh

    var sand_mat = material(Color.WHITE)
    sand_mat.vertex_color_use_as_albedo = true

    ground.material_override = sand_mat
    add_child(ground)


# ==========================================
# BUILDING HELPERS
# ==========================================

func add_box(
    pos: Vector3,
    size: Vector3,
    color: Color,
    parent: Node = null,
    rotation_y := 0.0
):
    var item = MeshInstance3D.new()
    var mesh = BoxMesh.new()

    mesh.size = size
    item.mesh = mesh
    item.position = pos
    item.rotation.y = rotation_y
    item.material_override = material(color)

    if parent == null:
        add_child(item)
    else:
        parent.add_child(item)

    return item


func add_cylinder(
    pos: Vector3,
    radius: float,
    height: float,
    color: Color,
    parent: Node = null
):
    var item = MeshInstance3D.new()
    var mesh = CylinderMesh.new()

    mesh.top_radius = radius
    mesh.bottom_radius = radius
    mesh.height = height
    mesh.radial_segments = 16

    item.mesh = mesh
    item.position = pos
    item.material_override = material(color)

    if parent == null:
        add_child(item)
    else:
        parent.add_child(item)

    return item


# ==========================================
# STONE WALL DETAILS
# ==========================================

func add_wall_blocks(
    center: Vector3,
    width: float,
    height: float,
    depth: float,
    parent: Node,
    front_axis := "z",
    face_sign := 1.0
):
    var rows = int(height / 0.8)
    var columns = int(width / 2.0)

    for row in range(rows):
        for col in range(columns):

            var offset = 0.0

            if row % 2 == 1:
                offset = 1.0

            var x = -width / 2.0 + col * 2.0 + offset
            var y = -height / 2.0 + row * 0.8

            var shade = 0.0

            if (row + col) % 3 == 0:
                shade = 0.07
            elif (row + col) % 3 == 1:
                shade = -0.05

            var stone_color = Color(
                0.68 + shade,
                0.59 + shade,
                0.47 + shade
            )

            if front_axis == "z":
                add_box(
                    center + Vector3(
                        x,
                        y,
                        face_sign * (depth / 2.0 + 0.04)
                    ),
                    Vector3(1.85, 0.72, 0.08),
                    stone_color,
                    parent
                )

            else:
                add_box(
                    center + Vector3(
                        face_sign * (depth / 2.0 + 0.04),
                        y,
                        x
                    ),
                    Vector3(0.08, 0.72, 1.85),
                    stone_color,
                    parent
                )


# ==========================================
# CASTLE
# ==========================================

func create_castle():
    var castle = Node3D.new()
    add_child(castle)

    # Castle platform

    add_box(
        Vector3(0, 0.35, 0),
        Vector3(23, 0.7, 23),
        DARK_STONE,
        castle
    )

    # Outer walls

    add_box(
        Vector3(-10, 2.5, 0),
        Vector3(1.5, 4.5, 20),
        STONE,
        castle
    )

    add_box(
        Vector3(10, 2.5, 0),
        Vector3(1.5, 4.5, 20),
        STONE,
        castle
    )

    add_box(
        Vector3(0, 2.5, -10),
        Vector3(20, 4.5, 1.5),
        STONE,
        castle
    )

    # Front wall with entrance

    add_box(
        Vector3(-5.5, 2.5, 10),
        Vector3(9, 4.5, 1.5),
        STONE,
        castle
    )

    add_box(
        Vector3(5.5, 2.5, 10),
        Vector3(9, 4.5, 1.5),
        STONE,
        castle
    )

    # Stone details

    add_wall_blocks(
        Vector3(-10, 2.5, 0),
        20, 4.5, 1.5, castle, "x", -1.0
    )

    add_wall_blocks(
        Vector3(10, 2.5, 0),
        20, 4.5, 1.5, castle, "x", 1.0
    )

    add_wall_blocks(
        Vector3(0, 2.5, -10),
        20, 4.5, 1.5, castle, "z", -1.0
    )

    add_wall_blocks(
        Vector3(-5.5, 2.5, 10),
        9, 4.5, 1.5, castle, "z", 1.0
    )

    add_wall_blocks(
        Vector3(5.5, 2.5, 10),
        9, 4.5, 1.5, castle, "z", 1.0
    )

    # Gate

    add_box(
        Vector3(0, 1.9, 10.2),
        Vector3(2.8, 3.8, 0.5),
        WOOD,
        castle
    )

    add_box(
        Vector3(0, 4.8, 10),
        Vector3(5, 0.8, 2),
        DARK_STONE,
        castle
    )

    # Corner towers

    for x in [-10.0, 10.0]:
        for z in [-10.0, 10.0]:
            create_tower(Vector3(x, 0, z), castle)

    # Battlements

    for i in range(9):
        var p = -8.0 + i * 2.0

        add_box(
            Vector3(p, 5.0, -10),
            Vector3(0.8, 1.0, 1.0),
            STONE,
            castle
        )

        add_box(
            Vector3(-10, 5.0, p),
            Vector3(1.0, 1.0, 0.8),
            STONE,
            castle
        )

        add_box(
            Vector3(10, 5.0, p),
            Vector3(1.0, 1.0, 0.8),
            STONE,
            castle
        )

    for i in range(4):
        add_box(
            Vector3(-8.0 + i * 2.0, 5.0, 10),
            Vector3(0.8, 1.0, 1.0),
            STONE,
            castle
        )

        add_box(
            Vector3(4.0 + i * 2.0, 5.0, 10),
            Vector3(0.8, 1.0, 1.0),
            STONE,
            castle
        )

    # Central keep

    add_box(
        Vector3(0, 3.5, -2),
        Vector3(9, 6, 8),
        Color(0.69, 0.58, 0.42),
        castle
    )

    add_box(
        Vector3(0, 6.7, -2),
        Vector3(10, 0.7, 9),
        DARK_STONE,
        castle
    )

    # Keep towers

    for x in [-4.5, 4.5]:
        for z in [-6.0, 2.0]:
            add_cylinder(
                Vector3(x, 4.0, z),
                1.2,
                8.0,
                STONE,
                castle
            )


# ==========================================
# TOWERS
# ==========================================

func create_tower(pos: Vector3, parent: Node):
    var tower = Node3D.new()
    tower.position = pos
    parent.add_child(tower)

    add_cylinder(
        Vector3(0, 4.0, 0),
        2.0,
        8.0,
        STONE,
        tower
    )

    add_cylinder(
        Vector3(0, 8.1, 0),
        2.15,
        0.45,
        DARK_STONE,
        tower
    )

    # Tower stone details

    for row in range(8):
        for i in range(8):

            var angle = TAU * i / 8.0
            var x = cos(angle) * 2.02
            var z = sin(angle) * 2.02

            var color = STONE

            if (row + i) % 3 == 0:
                color = Color(0.76, 0.67, 0.55)

            add_box(
                Vector3(x, 0.6 + row * 0.9, z),
                Vector3(0.75, 0.78, 0.25),
                color,
                tower,
                angle
            )

    # Tower battlements

    for i in range(8):
        var angle = TAU * i / 8.0
        var x = cos(angle) * 1.65
        var z = sin(angle) * 1.65

        add_box(
            Vector3(x, 8.9, z),
            Vector3(0.75, 1.1, 0.75),
            STONE,
            tower,
            angle
        )


# ==========================================
# VILLAGE
# ==========================================

func create_village():

    # Sandy road

    add_box(
        Vector3(-17, 0.1, 20),
        Vector3(35, 0.12, 3.5),
        Color(0.62, 0.44, 0.25)
    )

    for i in range(7):

        var x = -24.0 + float(i % 4) * 9.0
        var z = 18.0 + floor(float(i) / 4.0) * 9.0

        create_house(Vector3(x, 0, z))


func create_house(pos: Vector3):

    var house = Node3D.new()
    house.position = pos
    add_child(house)

    # Main building

    add_box(
        Vector3(0, 1.7, 0),
        Vector3(5.5, 3.4, 5),
        Color(0.78, 0.66, 0.48),
        house
    )

    # Decorative horizontal stone courses

    for row in range(4):
        var y = 0.45 + row * 0.8

        add_box(
            Vector3(0, y, 2.53),
            Vector3(5.4, 0.08, 0.08),
            Color(0.61, 0.49, 0.34),
            house
        )

    # Roof

    add_box(
        Vector3(-1.0, 3.6, 0),
        Vector3(3.0, 0.45, 6.0),
        ROOF,
        house,
        -0.48
    )

    add_box(
        Vector3(1.0, 3.6, 0),
        Vector3(3.0, 0.45, 6.0),
        ROOF,
        house,
        0.48
    )

    # Door

    add_box(
        Vector3(0, 1.0, 2.58),
        Vector3(1.1, 2.0, 0.12),
        WOOD,
        house
    )

    # Windows

    for x in [-1.7, 1.7]:

        add_box(
            Vector3(x, 2.0, 2.57),
            Vector3(0.85, 0.85, 0.14),
            DARK_STONE,
            house
        )

        add_box(
            Vector3(x, 2.0, 2.66),
            Vector3(0.55, 0.55, 0.05),
            Color(0.25, 0.40, 0.48),
            house
        )


# ==========================================
# PALM TREES
# ==========================================

func create_palms():

    var positions = [
        Vector3(-28, 0, -18),
        Vector3(25, 0, -20),
        Vector3(-30, 0, 18),
        Vector3(28, 0, 15),
        Vector3(-23, 0, 35),
        Vector3(18, 0, 36),
        Vector3(35, 0, 0),
        Vector3(-35, 0, 0)
    ]

    for p in positions:
        create_palm(p)


func create_palm(pos: Vector3):

    var palm = Node3D.new()
    palm.position = pos
    add_child(palm)

    add_cylinder(
        Vector3(0, 2.5, 0),
        0.35,
        5.0,
        Color(0.36, 0.22, 0.11),
        palm
    )

    for i in range(7):

        var angle = TAU * i / 7.0

        var leaf = add_box(
            Vector3(
                cos(angle) * 1.5,
                5.0,
                sin(angle) * 1.5
            ),
            Vector3(3.5, 0.18, 0.65),
            GREEN,
            palm,
            angle
        )

        leaf.rotation.z = -0.22


# ==========================================
# ROCKS
# ==========================================

func create_rocks():

    for i in range(35):

        var x = sin(float(i) * 12.7) * 55.0
        var z = cos(float(i) * 8.3) * 55.0

        if Vector2(x, z).length() < 16:
            continue

        var rock = MeshInstance3D.new()
        var mesh = SphereMesh.new()

        mesh.radius = 0.8
        mesh.height = 1.2

        rock.mesh = mesh
        rock.position = Vector3(x, 0.4, z)
        rock.scale = Vector3(1.5, 0.65, 1.0)

        rock.material_override = material(
            Color(0.43, 0.36, 0.27)
        )

        add_child(rock)


# ==========================================
# LIGHTING
# ==========================================

func create_lighting():

    var sun = DirectionalLight3D.new()

    sun.rotation_degrees = Vector3(-48, -35, 0)
    sun.light_energy = 1.4
    sun.shadow_enabled = true
    sun.directional_shadow_max_distance = 65.0

    add_child(sun)


# ==========================================
# CAMERA
# ==========================================

func create_camera():

    camera_pivot = Node3D.new()
    add_child(camera_pivot)

    camera_pitch = Node3D.new()
    camera_pitch.rotation.x = deg_to_rad(-35)
    camera_pivot.add_child(camera_pitch)

    camera = Camera3D.new()
    camera.position = Vector3(0, 0, zoom_distance)
    camera.fov = 50.0
    camera.current = true

    camera_pitch.add_child(camera)


# ==========================================
# INPUT - TOUCH AND MOUSE
# ==========================================

func _input(event):

    # Touch controls

    if event is InputEventScreenTouch:

        if event.pressed:
            touch_points[event.index] = event.position
        else:
            touch_points.erase(event.index)

    elif event is InputEventScreenDrag:

        var old_positions = touch_points.duplicate()
        touch_points[event.index] = event.position

        if touch_points.size() == 1:

            camera_pivot.rotate_y(
                -event.relative.x * 0.004
            )

            camera_pitch.rotation.x = clamp(
                camera_pitch.rotation.x
                - event.relative.y * 0.004,
                deg_to_rad(-80),
                deg_to_rad(-10)
            )

        elif touch_points.size() >= 2:

            var ids = touch_points.keys()

            var a = ids[0]
            var b = ids[1]

            var old_a = old_positions.get(a, touch_points[a])
            var old_b = old_positions.get(b, touch_points[b])

            var old_distance = old_a.distance_to(old_b)

            var new_distance = touch_points[a].distance_to(
                touch_points[b]
            )

            # Pinch zoom

            zoom_distance = clamp(
                zoom_distance + (
                    old_distance - new_distance
                ) * 0.08,
                ZOOM_MIN,
                ZOOM_MAX
            )

            camera.position.z = zoom_distance

            # Two finger movement

            var old_center = (old_a + old_b) / 2.0

            var new_center = (
                touch_points[a] + touch_points[b]
            ) / 2.0

            var movement = new_center - old_center

            camera_pivot.translate(
                Vector3(
                    -movement.x * 0.035,
                    0,
                    -movement.y * 0.035
                )
            )

    # Mouse controls

    elif event is InputEventMouseButton:

        if event.button_index == MOUSE_BUTTON_LEFT:
            dragging = event.pressed

        if (
            event.button_index == MOUSE_BUTTON_RIGHT
            or event.button_index == MOUSE_BUTTON_MIDDLE
        ):
            panning = event.pressed

        if event.pressed:

            if event.button_index == MOUSE_BUTTON_WHEEL_UP:

                zoom_distance = clamp(
                    zoom_distance - 4.0,
                    ZOOM_MIN,
                    ZOOM_MAX
                )

                camera.position.z = zoom_distance

            elif event.button_index == MOUSE_BUTTON_WHEEL_DOWN:

                zoom_distance = clamp(
                    zoom_distance + 4.0,
                    ZOOM_MIN,
                    ZOOM_MAX
                )

                camera.position.z = zoom_distance

    elif event is InputEventMouseMotion:

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

        elif panning:

            camera_pivot.translate(
                Vector3(
                    -event.relative.x * 0.05,
                    0,
                    -event.relative.y * 0.05
                )
            )


# ==========================================
# KEYBOARD MOVEMENT
# ==========================================

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

        movement = movement.normalized()

        camera_pivot.translate(
            movement * CAMERA_SPEED * delta
        )
