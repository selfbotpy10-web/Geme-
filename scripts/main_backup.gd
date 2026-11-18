extends Node3D

const LEVEL_COUNT = 30
const SEGMENTS = 12
const LEVEL_HEIGHT = 1.0
const FALL_SPEED = 5.5
const PLATFORM_RADIUS = 1.55
const PLATFORM_THICKNESS = 0.20

var tower: Node3D
var ball: Node3D
var camera: Camera3D
var score_label: Label
var message_label: Label
var restart_button: Button

var layers: Array = []
var black_segments: Array = []
var flying_parts: Array = []

var score = 0
var current_level = 0
var holding = false
var game_over = false
var won = false
var last_touch = Vector2.ZERO
var bounce_time = 0.0


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
    environment.background_color = Color(0.018, 0.012, 0.055)
    environment.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
    environment.ambient_light_color = Color(0.75, 0.78, 1.0)
    environment.ambient_light_energy = 1.1
    environment.tonemap_mode = Environment.TONE_MAPPER_FILMIC

    env.environment = environment
    add_child(env)

    var light = DirectionalLight3D.new()
    light.rotation_degrees = Vector3(-48, -30, 0)
    light.light_energy = 2.0
    light.shadow_enabled = true
    add_child(light)

    var fill = OmniLight3D.new()
    fill.position = Vector3(0, 3, 4)
    fill.light_color = Color(0.25, 0.45, 1.0)
    fill.light_energy = 1.8
    fill.omni_range = 12
    add_child(fill)

    camera = Camera3D.new()
    camera.position = Vector3(7.5, 5.5, 11.5)
    camera.fov = 42
    add_child(camera)
    camera.current = true
    camera.look_at(Vector3.ZERO)


func create_tower():
    tower = Node3D.new()
    add_child(tower)

    for i in range(LEVEL_COUNT):
        create_layer(i)


func create_layer(index: int):
    var layer = Node3D.new()
    layer.position.y = -float(index) * LEVEL_HEIGHT
    tower.add_child(layer)
    layers.append(layer)

    var black_index = randi_range(0, SEGMENTS - 1)
    black_segments.append(black_index)

    var colors = [
        Color(1.0, 0.035, 0.12),
        Color(1.0, 0.30, 0.025),
        Color(0.95, 0.025, 0.48),
        Color(0.025, 0.35, 1.0),
        Color(0.025, 0.9, 0.42),
        Color(0.55, 0.08, 1.0)
    ]

    for j in range(SEGMENTS):
        var piece = MeshInstance3D.new()
        piece.mesh = make_wedge_mesh(j)

        var mat = StandardMaterial3D.new()

        if j == black_index:
            mat.albedo_color = Color(0.012, 0.012, 0.02)
            mat.metallic = 0.15
            mat.roughness = 0.22
        else:
            mat.albedo_color = colors[index % colors.size()]
            mat.metallic = 0.35
            mat.roughness = 0.2
            mat.emission_enabled = true
            mat.emission = colors[index % colors.size()] * 0.12

        piece.material_override = mat
        layer.add_child(piece)


func make_wedge_mesh(index: int) -> ArrayMesh:
    var st = SurfaceTool.new()
    st.begin(Mesh.PRIMITIVE_TRIANGLES)

    var start_angle = TAU * float(index) / SEGMENTS + 0.012
    var end_angle = TAU * float(index + 1) / SEGMENTS - 0.012

    var steps = 5
    var top_y = 0.0
    var bottom_y = -PLATFORM_THICKNESS

    var center_top = Vector3(0, top_y, 0)
    var center_bottom = Vector3(0, bottom_y, 0)

    for k in range(steps):
        var a1 = lerp(start_angle, end_angle, float(k) / steps)
        var a2 = lerp(start_angle, end_angle, float(k + 1) / steps)

        var p1 = Vector3(sin(a1) * PLATFORM_RADIUS, top_y, cos(a1) * PLATFORM_RADIUS)
        var p2 = Vector3(sin(a2) * PLATFORM_RADIUS, top_y, cos(a2) * PLATFORM_RADIUS)

        var b1 = Vector3(p1.x, bottom_y, p1.z)
        var b2 = Vector3(p2.x, bottom_y, p2.z)

        add_triangle(st, center_top, p1, p2)
        add_triangle(st, center_bottom, b2, b1)
        add_quad(st, p1, b1, b2, p2)

    var first_top = Vector3(sin(start_angle) * PLATFORM_RADIUS, top_y, cos(start_angle) * PLATFORM_RADIUS)
    var first_bottom = Vector3(first_top.x, bottom_y, first_top.z)

    var last_top = Vector3(sin(end_angle) * PLATFORM_RADIUS, top_y, cos(end_angle) * PLATFORM_RADIUS)
    var last_bottom = Vector3(last_top.x, bottom_y, last_top.z)

    add_quad(st, center_top, center_bottom, first_bottom, first_top)
    add_quad(st, center_top, last_top, last_bottom, center_bottom)

    st.generate_normals()
    return st.commit()


func add_triangle(st: SurfaceTool, a: Vector3, b: Vector3, c: Vector3):
    st.add_vertex(a)
    st.add_vertex(b)
    st.add_vertex(c)


func add_quad(st: SurfaceTool, a: Vector3, b: Vector3, c: Vector3, d: Vector3):
    add_triangle(st, a, b, c)
    add_triangle(st, a, c, d)


func create_ball():
    ball = Node3D.new()
    ball.position = Vector3(0, 1.25, 0)
    add_child(ball)

    var mesh = MeshInstance3D.new()
    var sphere = SphereMesh.new()
    sphere.radius = 0.42
    sphere.height = 0.84
    sphere.radial_segments = 48
    sphere.rings = 24
    mesh.mesh = sphere

    var mat = StandardMaterial3D.new()
    mat.albedo_color = Color(1.0, 0.82, 0.015)
    mat.metallic = 0.65
    mat.roughness = 0.12
    mat.emission_enabled = true
    mat.emission = Color(1.0, 0.55, 0.01) * 0.18
    mesh.material_override = mat

    ball.add_child(mesh)

    var glow = OmniLight3D.new()
    glow.light_color = Color(1.0, 0.65, 0.05)
    glow.light_energy = 0.8
    glow.omni_range = 3.0
    ball.add_child(glow)


func create_ui():
    var canvas = CanvasLayer.new()
    add_child(canvas)

    score_label = Label.new()
    score_label.position = Vector2(20, 28)
    score_label.add_theme_font_size_override("font_size", 25)
    score_label.add_theme_color_override("font_color", Color.WHITE)
    score_label.add_theme_color_override("font_shadow_color", Color.BLACK)
    score_label.add_theme_constant_override("shadow_offset_x", 2)
    score_label.add_theme_constant_override("shadow_offset_y", 2)
    canvas.add_child(score_label)

    message_label = Label.new()
    message_label.position = Vector2(20, 85)
    message_label.add_theme_font_size_override("font_size", 19)
    message_label.add_theme_color_override("font_color", Color(1.0, 0.85, 0.2))
    canvas.add_child(message_label)

    restart_button = Button.new()
    restart_button.text = "شروع دوباره"
    restart_button.position = Vector2(170, 560)
    restart_button.size = Vector2(250, 68)
    restart_button.add_theme_font_size_override("font_size", 24)
    restart_button.visible = false
    restart_button.pressed.connect(restart_game)
    canvas.add_child(restart_button)

    update_ui()


func update_ui():
    score_label.text = "YASER GAME   |   امتیاز: " + str(score)

    if game_over:
        if won:
            message_label.text = "آفرین! برنده شدی!"
        else:
            message_label.text = "به قسمت سیاه برخورد کردی!"
        restart_button.visible = true
    else:
        message_label.text = "برای سقوط توپ، صفحه را نگه دار"


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

    elif event is InputEventMouseMotion and holding:
        var difference = event.position.x - last_touch.x
        tower.rotation.y += difference * 0.008
        last_touch = event.position


func _process(delta):
    if game_over:
        update_flying_parts(delta)
        return

    bounce_time += delta

    if holding:
        ball.position.y -= FALL_SPEED * delta

        while current_level < LEVEL_COUNT:
            var target_y = 0.35 - float(current_level) * LEVEL_HEIGHT

            if ball.position.y > target_y:
                break

            check_current_layer()

            if game_over:
                return

        if current_level >= LEVEL_COUNT:
            win_game()
            return
    else:
        var rest_y = 1.25 - float(current_level) * LEVEL_HEIGHT
        ball.position.y = lerp(
            ball.position.y,
            rest_y + sin(bounce_time * 5.0) * 0.09,
            delta * 9.0
        )

    ball.rotation.z += delta * 1.2
    tower.rotation.y += delta * 0.12

    camera.position.y = lerp(
        camera.position.y,
        ball.position.y + 4.5,
        delta * 2.5
    )
    camera.look_at(Vector3(0, ball.position.y - 2.0, 0))

    update_flying_parts(delta)
    update_ui()


func check_current_layer():
    var angle = fposmod(tower.rotation.y, TAU)
    var segment = int(round(angle / TAU * SEGMENTS)) % SEGMENTS

    if segment == black_segments[current_level]:
        end_game()
        return

    break_layer(current_level)
    current_level += 1
    score += 10


func break_layer(index: int):
    if index >= layers.size():
        return

    var layer = layers[index]
    if not is_instance_valid(layer):
        return

    layer.visible = false

    for i in range(10):
        var shard = MeshInstance3D.new()
        var cube = BoxMesh.new()
        cube.size = Vector3(0.22, 0.16, 0.22)
        shard.mesh = cube

        var material = StandardMaterial3D.new()
        material.albedo_color = Color.from_hsv(
            float(index % 6) / 6.0,
            0.9,
            1.0
        )
        material.metallic = 0.3
        material.roughness = 0.2
        shard.material_override = material

        add_child(shard)

        var angle = randf() * TAU
        shard.global_position = Vector3(
            sin(angle) * randf_range(0.3, 1.2),
            layer.position.y,
            cos(angle) * randf_range(0.3, 1.2)
        )

        flying_parts.append({
            "node": shard,
            "velocity": Vector3(
                randf_range(-3.0, 3.0),
                randf_range(1.5, 4.5),
                randf_range(-3.0, 3.0)
            ),
            "life": 1.2
        })


func update_flying_parts(delta: float):
    for i in range(flying_parts.size() - 1, -1, -1):
        var part = flying_parts[i]
        var node = part["node"]

        if not is_instance_valid(node):
            flying_parts.remove_at(i)
            continue

        var velocity: Vector3 = part["velocity"]
        velocity.y -= 9.8 * delta
        node.position += velocity * delta
        node.rotate_x(delta * 5.0)
        node.rotate_z(delta * 4.0)

        part["velocity"] = velocity
        part["life"] -= delta

        if part["life"] <= 0:
            node.queue_free()
            flying_parts.remove_at(i)
        else:
            flying_parts[i] = part


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
        if is_instance_valid(layer):
            layer.queue_free()

    for part in flying_parts:
        if is_instance_valid(part["node"]):
            part["node"].queue_free()

    layers.clear()
    black_segments.clear()
    flying_parts.clear()

    score = 0
    current_level = 0
    game_over = false
    won = false
    holding = false
    bounce_time = 0.0

    ball.position = Vector3(0, 1.25, 0)
    camera.position = Vector3(7.5, 5.5, 11.5)
    tower.rotation = Vector3.ZERO

    for i in range(LEVEL_COUNT):
        create_layer(i)

    restart_button.visible = false
    update_ui()
