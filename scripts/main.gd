
extends Node3D

var camera_pivot: Node3D
var camera: Camera3D
var dragging := false
var last_touch := Vector2.ZERO

func _ready():
    create_world()
    create_camera()
    create_lighting()

func create_world():
    # Desert ground
    var ground = MeshInstance3D.new()
    var plane = PlaneMesh.new()
    plane.size = Vector2(120, 120)
    ground.mesh = plane
    ground.position.y = -0.2

    var sand = StandardMaterial3D.new()
    sand.albedo_color = Color(0.76, 0.59, 0.34)
    ground.material_override = sand
    add_child(ground)

    # Main castle
    create_box(Vector3(0, 2, 0), Vector3(12, 4, 12),
        Color(0.72, 0.65, 0.49))

    # Castle towers
    for x in [-6.0, 6.0]:
        for z in [-6.0, 6.0]:
            create_cylinder(Vector3(x, 3.2, z),
                1.5, 6.4, Color(0.58, 0.48, 0.34))

    # Castle entrance
    create_box(Vector3(0, 1.5, 6.2),
        Vector3(3, 3, 0.5), Color(0.30, 0.19, 0.10))

    # Village houses
    for i in range(6):
        var x = -18.0 + float(i % 3) * 8.0
        var z = 12.0 + float(i / 3) * 9.0
        create_box(Vector3(x, 1.2, z),
            Vector3(5, 2.4, 5), Color(0.78, 0.65, 0.45))

    # Palm trees
    for i in range(10):
        var x = -30.0 + float(i) * 6.0
        create_palm(Vector3(x, 0, -15))

func create_box(pos: Vector3, size: Vector3, color: Color):
    var item = MeshInstance3D.new()
    var mesh = BoxMesh.new()
    mesh.size = size
    item.mesh = mesh
    item.position = pos

    var material = StandardMaterial3D.new()
    material.albedo_color = color
    item.material_override = material
    add_child(item)

func create_cylinder(pos: Vector3, radius: float,
        height: float, color: Color):
    var item = MeshInstance3D.new()
    var mesh = CylinderMesh.new()
    mesh.top_radius = radius
    mesh.bottom_radius = radius
    mesh.height = height
    item.mesh = mesh
    item.position = pos

    var material = StandardMaterial3D.new()
    material.albedo_color = color
    item.material_override = material
    add_child(item)

func create_palm(pos: Vector3):
    create_cylinder(pos + Vector3(0, 2, 0),
        0.3, 4, Color(0.38, 0.22, 0.10))

    var leaves = Color(0.12, 0.35, 0.12)
    for i in range(5):
        var angle = float(i) * TAU / 5.0
        var leaf_pos = pos + Vector3(
            cos(angle) * 1.5, 4.1, sin(angle) * 1.5)
        create_box(leaf_pos, Vector3(2.5, 0.2, 0.7), leaves)

func create_lighting():
    var sun = DirectionalLight3D.new()
    sun.rotation_degrees = Vector3(-50, -30, 0)
    sun.light_energy = 1.3
    add_child(sun)

func create_camera():
    camera_pivot = Node3D.new()
    add_child(camera_pivot)

    camera = Camera3D.new()
    camera.position = Vector3(0, 17, 30)
    camera.look_at(Vector3(0, 0, 0), Vector3.UP)
    camera.current = true
    camera_pivot.add_child(camera)

func _input(event):
    if event is InputEventScreenTouch:
        dragging = event.pressed
        last_touch = event.position

    elif event is InputEventScreenDrag:
        if dragging:
            camera_pivot.rotate_y(-event.relative.x * 0.005)

    elif event is InputEventMouseButton:
        if event.button_index == MOUSE_BUTTON_LEFT:
            dragging = event.pressed

        elif event.pressed and event.button_index == MOUSE_BUTTON_WHEEL_UP:
            camera.position *= 0.9

        elif event.pressed and event.button_index == MOUSE_BUTTON_WHEEL_DOWN:
            camera.position *= 1.1

    elif event is InputEventMouseMotion and dragging:
        camera_pivot.rotate_y(-event.relative.x * 0.005)

