extends Node3D

const LEVEL_COUNT = 30
const SEGMENTS = 12
const LEVEL_HEIGHT = 1.0
const FALL_SPEED = 5.0

var tower: Node3D
var ball: Node3D
var camera: Camera3D
var score_label: Label
var message_label: Label
var restart_button: Button

var layers: Array = []
var black_segments: Array = []

var score = 0
var current_level = 0
var holding = false
var game_over = false
var won = false
var last_touch = Vector2.ZERO


func _ready():
    randomize()
    create_world()
    create_tower()
    create_ball()
    create_ui()


func create_world():
    var env = WorldEnvironment.new()
    var environment = Environment.new()
    environment.background_mode = Environment.BG_COLOR
    environment.background_color = Color(0.035, 0.025, 0.09)
    environment.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
    environment.ambient_light_color = Color(0.65, 0.65, 0.8)
    environment.ambient_light_energy = 1.0
    env.environment = environment
    add_child(env)

    var light = DirectionalLight3D.new()
    light.rotation_degrees = Vector3(-45, -30, 0)
    light.light_energy = 2.0
    add_child(light)

    camera = Camera3D.new()
    camera.position = Vector3(0, 5, 13)
    camera.fov = 50
    add_child(camera)
    camera.current = true
    camera.look_at(Vector3.ZERO)


func create_tower():
    tower = Node3D.new()
    add_child(tower)

    var pillar = MeshInstance3D.new()
    var cylinder = CylinderMesh.new()
    cylinder.top_radius = 0.3
    cylinder.bottom_radius = 0.3
    cylinder.height = 34.0
    pillar.mesh = cylinder
    pillar.position.y = -14.0

    var pillar_mat = StandardMaterial3D.new()
    pillar_mat.albedo_color = Color(0.16, 0.16, 0.23)
    pillar.material_override = pillar_mat
    tower.add_child(pillar)

    for i in range(LEVEL_COUNT):
        create_layer(i)


func create_layer(index: int):
    var layer = Node3D.new()
    layer.position.y = -float(index) * LEVEL_HEIGHT
    tower.add_child(layer)
    layers.append(layer)

    var black_index = randi_range(0, SEGMENTS - 1)
    black_segments.append(black_index)

    for j in range(SEGMENTS):
        var angle = TAU * float(j) / float(SEGMENTS)

        var piece = MeshInstance3D.new()
        var mesh = BoxMesh.new()
        mesh.size = Vector3(0.92, 0.22, 0.62)
        piece.mesh = mesh

        piece.position = Vector3(
            sin(angle) * 1.15,
            0,
            cos(angle) * 1.15
        )
        piece.rotation.y = angle

        var mat = StandardMaterial3D.new()

        if j == black_index:
            mat.albedo_color = Color(0.025, 0.025, 0.035)
        else:
            var colors = [
                Color(1.0, 0.12, 0.18),
                Color(1.0, 0.48, 0.05),
                Color(0.95, 0.12, 0.55),
                Color(0.15, 0.55, 1.0),
                Color(0.35, 0.95, 0.35)
            ]
            mat.albedo_color = colors[index % colors.size()]

        mat.metallic = 0.25
        mat.roughness = 0.3
        piece.material_override = mat
        layer.add_child(piece)


func create_ball():
    ball = Node3D.new()
    ball.position = Vector3(0, 1.45, 0)
    add_child(ball)

    var mesh = MeshInstance3D.new()
    var sphere = SphereMesh.new()
    sphere.radius = 0.43
    sphere.height = 0.86
    mesh.mesh = sphere

    var mat = StandardMaterial3D.new()
    mat.albedo_color = Color(1.0, 0.9, 0.08)
    mat.metallic = 0.35
    mat.roughness = 0.18
    mesh.material_override = mat

    ball.add_child(mesh)


func create_ui():
    var canvas = CanvasLayer.new()
    add_child(canvas)

    score_label = Label.new()
    score_label.position = Vector2(25, 35)
    score_label.add_theme_font_size_override("font_size", 32)
    score_label.add_theme_color_override("font_color", Color.WHITE)
    canvas.add_child(score_label)

    message_label = Label.new()
    message_label.position = Vector2(25, 100)
    message_label.add_theme_font_size_override("font_size", 23)
    message_label.add_theme_color_override("font_color", Color.YELLOW)
    canvas.add_child(message_label)

    restart_button = Button.new()
    restart_button.text = "شروع دوباره"
    restart_button.position = Vector2(220, 500)
    restart_button.size = Vector2(280, 75)
    restart_button.add_theme_font_size_override("font_size", 26)
    restart_button.visible = false
    restart_button.pressed.connect(restart_game)
    canvas.add_child(restart_button)

    update_ui()


func update_ui():
    score_label.text = "YASER STACK BALL   |   امتیاز: " + str(score)

    if game_over:
        if won:
            message_label.text = "آفرین! برنده شدی!"
        else:
            message_label.text = "باختی! به قسمت سیاه برخورد کردی."
        restart_button.visible = true
    else:
        message_label.text = "برای شکستن طبقات صفحه را نگه دار"


func _input(event):
    if event is InputEventScreenTouch:
        if event.pressed:
            holding = true
            last_touch = event.position
        else:
            holding = false

    elif event is InputEventScreenDrag:
        var difference = event.position.x - last_touch.x
        tower.rotation.y += difference * 0.008
        last_touch = event.position

    elif event is InputEventMouseButton:
        if event.button_index == MOUSE_BUTTON_LEFT:
            holding = event.pressed
            last_touch = event.position

    elif event is InputEventMouseMotion:
        if holding:
            var difference = event.position.x - last_touch.x
            tower.rotation.y += difference * 0.008
            last_touch = event.position


func _process(delta):
    if game_over:
        return

    tower.rotation.y += delta * 0.35

    if holding:
        ball.position.y -= FALL_SPEED * delta

        while current_level < LEVEL_COUNT:
            var target_y = 0.45 - float(current_level) * LEVEL_HEIGHT

            if ball.position.y > target_y:
                break

            check_current_layer()

            if game_over:
                return

        camera.position.y = ball.position.y + 5.0
        camera.look_at(Vector3(0, ball.position.y - 2.0, 0))

        if current_level >= LEVEL_COUNT:
            win_game()

    else:
        ball.position.y = max(
            ball.position.y,
            1.45 - float(current_level) * LEVEL_HEIGHT
        )

    update_ui()


func check_current_layer():
    var angle = fposmod(tower.rotation.y, TAU)
    var segment = int(round(angle / TAU * SEGMENTS)) % SEGMENTS

    if segment == black_segments[current_level]:
        end_game()
        return

    layers[current_level].visible = false
    current_level += 1
    score += 10


func end_game():
    game_over = true
    won = false
    holding = false
    update_ui()


func win_game():
    game_over = true
    won = true
    holding = false
    update_ui()


func restart_game():
    for layer in layers:
        layer.queue_free()

    layers.clear()
    black_segments.clear()

    score = 0
    current_level = 0
    game_over = false
    won = false
    holding = false

    ball.position = Vector3(0, 1.45, 0)
    camera.position = Vector3(0, 5, 13)
    tower.rotation = Vector3.ZERO

    for i in range(LEVEL_COUNT):
        create_layer(i)

    restart_button.visible = false
    update_ui()
