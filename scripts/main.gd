extends Node3D

var ball: CharacterBody3D
var score := 0
var speed := 5.0
var direction := 0.0
var camera: Camera3D
var score_label: Label
var touch_start := Vector2.ZERO

func _ready():
    create_world()
    create_tower()
    create_ball()
    create_ui()

func create_world():
    camera = Camera3D.new()
    camera.position = Vector3(0, 9, 17)
    camera.rotation_degrees = Vector3(-20, 0, 0)
    camera.fov = 55
    add_child(camera)
    camera.current = true

    var light = DirectionalLight3D.new()
    light.rotation_degrees = Vector3(-45, -30, 0)
    light.light_energy = 2.0
    add_child(light)

    var env = WorldEnvironment.new()
    var environment = Environment.new()
    environment.background_mode = Environment.BG_SKY
    environment.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
    environment.ambient_light_color = Color(0.5, 0.35, 0.5)
    env.environment = environment
    add_child(env)

func create_tower():
    for i in range(35):
        var angle = float(i) * 0.22
        var y = 0.3 + float(i) * 0.42
        var platform = StaticBody3D.new()
        platform.position = Vector3(
            sin(angle) * 2.2,
            y,
            cos(angle) * 2.2
        )
        platform.rotation.y = angle

        var mesh = MeshInstance3D.new()
        var shape = BoxMesh.new()
        shape.size = Vector3(3.5, 0.35, 1.5)
        mesh.mesh = shape

        var material = StandardMaterial3D.new()
        material.albedo_color = Color(0.12, 0.28, 1.0)
        material.metallic = 0.3
        mesh.material_override = material
        platform.add_child(mesh)

        var collision = CollisionShape3D.new()
        var box = BoxShape3D.new()
        box.size = shape.size
        collision.shape = box
        platform.add_child(collision)
        add_child(platform)

func create_ball():
    ball = CharacterBody3D.new()
    ball.position = Vector3(0, 3, 0)

    var mesh = MeshInstance3D.new()
    var sphere = SphereMesh.new()
    sphere.radius = 0.45
    sphere.height = 0.9
    mesh.mesh = sphere

    var material = StandardMaterial3D.new()
    material.albedo_color = Color(1.0, 0.22, 0.04)
    material.roughness = 0.25
    mesh.material_override = material
    ball.add_child(mesh)

    var collision = CollisionShape3D.new()
    var shape = SphereShape3D.new()
    shape.radius = 0.45
    collision.shape = shape
    ball.add_child(collision)

    add_child(ball)

func create_ui():
    var canvas = CanvasLayer.new()
    add_child(canvas)

    score_label = Label.new()
    score_label.text = "YASER GAME   |   0"
    score_label.position = Vector2(25, 30)
    score_label.add_theme_font_size_override("font_size", 32)
    canvas.add_child(score_label)

func _input(event):
    if event is InputEventScreenTouch:
        if event.pressed:
            touch_start = event.position
        else:
            direction = 0

    if event is InputEventScreenDrag:
        direction = clamp((event.position.x - touch_start.x) / 150.0, -1.0, 1.0)

func _physics_process(delta):
    if not is_instance_valid(ball):
        return

    ball.velocity.y -= 18.0 * delta
    ball.velocity.x = direction * speed
    ball.velocity.z = -1.5

    ball.move_and_slide()

    camera.position.y = max(camera.position.y, ball.position.y + 7)
    camera.position.x = lerp(camera.position.x, ball.position.x, delta * 2)

    if ball.position.y < -5:
        ball.position = Vector3(0, 3, 0)
        ball.velocity = Vector3.ZERO
        score = 0

    score = max(score, int(ball.position.y * 10))
    score_label.text = "YASER GAME   |   " + str(score)
