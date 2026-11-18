extends Node3D

const MAX_STAGE := 500
const SEGMENTS := 12
const LEVEL_HEIGHT := 1.0
const PLATFORM_RADIUS := 1.55
const INNER_RADIUS := 0.48

var stage := 1
var unlocked_stage := 1
var stage_layer_count := 10
var current_layer := 0
var score := 0

var tower: Node3D
var ball: Node3D
var camera: Camera3D

var score_label: Label
var message_label: Label
var progress_bar: ProgressBar
var restart_button: Button
var next_button: Button

var layers: Array = []
var black_segments: Array = []
var flying_parts: Array = []

var holding := false
var game_over := false
var stage_completed := false
var last_touch := Vector2.ZERO
var bounce_time := 0.0

var fall_speed := 5.5
var rotation_speed := 0.12

func _ready():
    randomize()
    load_progress()
    create_world()
    create_tower()
    create_ball()
    create_ui()
    start_stage(stage)

func load_progress():
    var config := ConfigFile.new()
    if config.load("user://progress.cfg") == OK:
        unlocked_stage = int(config.get_value("progress", "unlocked_stage", 1))
    unlocked_stage = clampi(unlocked_stage, 1, MAX_STAGE)

func save_progress():
    var config := ConfigFile.new()
    config.set_value("progress", "unlocked_stage", unlocked_stage)
    config.save("user://progress.cfg")

func create_world():
    var env := WorldEnvironment.new()
    var environment := Environment.new()
    environment.background_mode = Environment.BG_COLOR
    environment.background_color = Color(0.018, 0.012, 0.055)
    environment.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
    environment.ambient_light_color = Color(0.75, 0.78, 1.0)
    environment.ambient_light_energy = 1.1
    environment.tonemap_mode = Environment.TONE_MAPPER_FILMIC
    env.environment = environment
    add_child(env)

    var light := DirectionalLight3D.new()
    light.rotation_degrees = Vector3(-48, -30, 0)
    light.light_energy = 2.0
    light.shadow_enabled = true
    add_child(light)

    var fill := OmniLight3D.new()
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

func create_ball():
    ball = Node3D.new()
    ball.position = Vector3(0, 1.25, 0)
    add_child(ball)

    var mesh := MeshInstance3D.new()
    var sphere := SphereMesh.new()
    sphere.radius = 0.42
    sphere.height = 0.84
    sphere.radial_segments = 48
    sphere.rings = 24
    mesh.mesh = sphere

    var mat := StandardMaterial3D.new()
    mat.albedo_color = Color(1.0, 0.82, 0.015)
    mat.metallic = 0.65
    mat.roughness = 0.12
    mat.emission_enabled = true
    mat.emission = Color(1.0, 0.55, 0.01) * 0.18
    mesh.material_override = mat
    ball.add_child(mesh)

    var glow := OmniLight3D.new()
    glow.light_color = Color(1.0, 0.65, 0.05)
    glow.light_energy = 0.8
    glow.omni_range = 3.0
    ball.add_child(glow)

func create_ui():
    var canvas := CanvasLayer.new()
    add_child(canvas)

    score_label = Label.new()
    score_label.position = Vector2(20, 25)
    score_label.add_theme_font_size_override("font_size", 25)
    score_label.add_theme_color_override("font_color", Color.WHITE)
    canvas.add_child(score_label)

    progress_bar = ProgressBar.new()
    progress_bar.position = Vector2(20, 75)
    progress_bar.size = Vector2(680, 22)
    progress_bar.show_percentage = false
    canvas.add_child(progress_bar)

    message_label = Label.new()
    message_label.position = Vector2(20, 115)
    message_label.add_theme_font_size_override("font_size", 21)
    message_label.add_theme_color_override("font_color", Color(1.0, 0.85, 0.2))
    canvas.add_child(message_label)

    restart_button = Button.new()
    restart_button.text = "تلاش دوباره"
    restart_button.position = Vector2(170, 1050)
    restart_button.size = Vector2(380, 75)
    restart_button.add_theme_font_size_override("font_size", 25)
    restart_button.visible = false
    restart_button.pressed.connect(restart_stage)
    canvas.add_child(restart_button)

    next_button = Button.new()
    next_button.text = "مرحله بعد"
    next_button.position = Vector2(170, 1050)
    next_button.size = Vector2(380, 75)
    next_button.add_theme_font_size_override("font_size", 25)
    next_button.visible = false
    next_button.pressed.connect(go_next_stage)
    canvas.add_child(next_button)

    update_ui()

func start_stage(number: int):
    stage = clampi(number, 1, MAX_STAGE)
    stage_layer_count = 10 + (stage - 1) * 5
    current_layer = 0
    score = 0
    holding = false
    game_over = false
    stage_completed = false
    bounce_time = 0.0

    fall_speed = minf(5.5 + float(stage - 1) * 0.012, 11.5)
    rotation_speed = minf(0.12 + float(stage - 1) * 0.001, 0.65)

    for child in tower.get_children():
        child.queue_free()

    for part in flying_parts:
        if is_instance_valid(part["node"]):
            part["node"].queue_free()

    layers.clear()
    black_segments.clear()
    flying_parts.clear()

    for i in range(stage_layer_count):
        create_layer(i)

    ball.position = Vector3(0, 1.25, 0)
    camera.position = Vector3(7.5, 5.5, 11.5)
    tower.rotation = Vector3.ZERO

    restart_button.visible = false
    next_button.visible = false
    update_ui()

func create_layer(index: int):
    var layer := MeshInstance3D.new()
    layer.position.y = -float(index) * LEVEL_HEIGHT
    layer.mesh = make_ring_mesh(index)
    tower.add_child(layer)
    layers.append(layer)

    black_segments.append(randi_range(0, SEGMENTS - 1))

func make_ring_mesh(index: int) -> ArrayMesh:
    var st := SurfaceTool.new()
    st.begin(Mesh.PRIMITIVE_TRIANGLES)

    var colors = [
        Color(1.0, 0.035, 0.12),
        Color(1.0, 0.30, 0.025),
        Color(0.95, 0.025, 0.48),
        Color(0.025, 0.35, 1.0),
        Color(0.025, 0.9, 0.42),
        Color(0.55, 0.08, 1.0)
    ]

    var main_color: Color = colors[index % colors.size()]
    var black_index: int = -1

    # The black segment is assigned separately in create_layer.
    # Its index is generated here and returned through the array.
    black_index = randi_range(0, SEGMENTS - 1)

    for j in range(SEGMENTS):
        var color := main_color
        if j == black_index:
            color = Color(0.008, 0.008, 0.016)

        for k in range(3):
            var a1 := TAU * (float(j) / SEGMENTS + float(k) / (SEGMENTS * 3.0))
            var a2 := TAU * (float(j) / SEGMENTS + float(k + 1) / (SEGMENTS * 3.0))

            var inner1 := Vector3(sin(a1) * INNER_RADIUS, 0, cos(a1) * INNER_RADIUS)
            var outer1 := Vector3(sin(a1) * PLATFORM_RADIUS, 0, cos(a1) * PLATFORM_RADIUS)
            var outer2 := Vector3(sin(a2) * PLATFORM_RADIUS, 0, cos(a2) * PLATFORM_RADIUS)
            var inner2 := Vector3(sin(a2) * INNER_RADIUS, 0, cos(a2) * INNER_RADIUS)

            add_colored_triangle(st, inner1, outer1, outer2, color)
            add_colored_triangle(st, inner1, outer2, inner2, color)

    st.generate_normals()

    var material := StandardMaterial3D.new()
    material.vertex_color_use_as_albedo = true
    material.metallic = 0.35
    material.roughness = 0.2
    st.set_material(material)

    var result := st.commit()

    # Store the exact dangerous segment for this layer.
    black_segments.append(black_index)
    return result

func add_colored_triangle(st: SurfaceTool, a: Vector3, b: Vector3, c: Vector3, color: Color):
    st.set_color(color)
    st.add_vertex(a)
    st.set_color(color)
    st.add_vertex(b)
    st.set_color(color)
    st.add_vertex(c)

func _unhandled_input(event):
    if game_over or stage_completed:
        return

    if event is InputEventScreenTouch:
        holding = event.pressed
        last_touch = event.position

    elif event is InputEventScreenDrag:
        var difference := event.position.x - last_touch.x
        tower.rotation.y += difference * 0.008
        last_touch = event.position

    elif event is InputEventMouseButton:
        if event.button_index == MOUSE_BUTTON_LEFT:
            holding = event.pressed
            last_touch = event.position

    elif event is InputEventMouseMotion and holding:
        var difference := event.position.x - last_touch.x
        tower.rotation.y += difference * 0.008
        last_touch = event.position

func _process(delta):
    update_flying_parts(delta)

    if game_over or stage_completed:
        return

    bounce_time += delta

    if holding:
        ball.position.y -= fall_speed * delta

        while current_layer < stage_layer_count:
            var target_y := 0.35 - float(current_layer) * LEVEL_HEIGHT
            if ball.position.y > target_y:
                break

            check_current_layer()

            if game_over or stage_completed:
                return
    else:
        var rest_y := 1.25 - float(current_layer) * LEVEL_HEIGHT
        ball.position.y = lerpf(
            ball.position.y,
            rest_y + sin(bounce_time * 5.0) * 0.07,
            delta * 9.0
        )

    ball.rotation.z += delta * 1.2
    tower.rotation.y += delta * rotation_speed

    camera.position.y = lerpf(
        camera.position.y,
        ball.position.y + 4.5,
        delta * 2.5
    )
    camera.look_at(Vector3(0, ball.position.y - 2.0, 0))

    update_ui()

func check_current_layer():
    var angle := fposmod(-tower.rotation.y, TAU)
    var segment := int(floor(angle / TAU * SEGMENTS)) % SEGMENTS

    if segment == black_segments[current_layer]:
        end_game()
        return

    break_layer(current_layer)
    current_layer += 1
    score += 10

    if current_layer >= stage_layer_count:
        complete_stage()

func break_layer(index: int):
    if index >= layers.size():
        return

    var layer: MeshInstance3D = layers[index]
    if not is_instance_valid(layer):
        return

    layer.visible = false

    for i in range(6):
        var shard := MeshInstance3D.new()
        var cube := BoxMesh.new()
        cube.size = Vector3(0.25, 0.15, 0.25)
        shard.mesh = cube

        var material := StandardMaterial3D.new()
        material.albedo_color = Color.from_hsv(float(stage % 12) / 12.0, 0.9, 1.0)
        material.metallic = 0.3
        shard.material_override = material

        add_child(shard)

        var angle := randf() * TAU
        shard.global_position = Vector3(
            sin(angle) * randf_range(0.4, 1.2),
            layer.global_position.y,
            cos(angle) * randf_range(0.4, 1.2)
        )

        flying_parts.append({
            "node": shard,
            "velocity": Vector3(
                randf_range(-3.0, 3.0),
                randf_range(1.5, 4.5),
                randf_range(-3.0, 3.0)
            ),
            "life": 1.0
        })

func update_flying_parts(delta: float):
    for i in range(flying_parts.size() - 1, -1, -1):
        var part: Dictionary = flying_parts[i]
        var node: Node3D = part["node"]

        if not is_instance_valid(node):
            flying_parts.remove_at(i)
            continue

        var velocity: Vector3 = part["velocity"]
        velocity.y -= 9.8 * delta
        node.position += velocity * delta
        node.rotate_x(delta * 5.0)
        node.rotate_z(delta * 4.0)

        part["velocity"] = velocity
        part["life"] = float(part["life"]) - delta

        if float(part["life"]) <= 0:
            node.queue_free()
            flying_parts.remove_at(i)
        else:
            flying_parts[i] = part

func complete_stage():
    stage_completed = true
    holding = false

    if stage < MAX_STAGE:
        unlocked_stage = maxi(unlocked_stage, stage + 1)
        save_progress()
        message_label.text = "مرحله %d کامل شد! مرحله بعد باز شد." % stage
        next_button.visible = true
    else:
        message_label.text = "قهرمان YASER GAME شدی! هر ۵۰۰ مرحله را بردی."
        restart_button.text = "بازی دوباره"
        restart_button.visible = true

    update_ui()

func end_game():
    game_over = true
    holding = false
    message_label.text = "به قسمت سیاه برخورد کردی! دوباره تلاش کن."
    restart_button.text = "تلاش دوباره"
    restart_button.visible = true
    next_button.visible = false
    update_ui()

func restart_stage():
    if stage >= MAX_STAGE and stage_completed:
        start_stage(1)
    else:
        start_stage(stage)

func go_next_stage():
    if stage < MAX_STAGE and unlocked_stage > stage:
        start_stage(stage + 1)

func update_ui():
    if not is_instance_valid(score_label):
        return

    score_label.text = "YASER GAME  |  مرحله: %d / %d  |  امتیاز: %d" % [
        stage, MAX_STAGE, score
    ]

    progress_bar.max_value = stage_layer_count
    progress_bar.value = current_layer
