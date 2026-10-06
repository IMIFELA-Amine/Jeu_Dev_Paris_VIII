extends CharacterBody3D

@export var speed: float = 5.0
@export var jump_velocity: float = 4.5
@export var mouse_sensitivity: float = 0.003
@export var rotation_speed: float = 12.0 # Vitesse de rotation du visuel

@onready var camera_pivot: Node3D = $CameraPivot
@onready var model: Node3D = $skin # Vérifie le nom de ton nœud viszdz

var gravity: float = ProjectSettings.get_setting("physics/3d/default_gravity")
var pitch: float = 0.0

func _ready() -> void:
	# Capturer la souris au démarrage
	Input.mouse_mode = Input.MOUSE_MODE_CAPTURED
	_setup_inputs()

func _setup_inputs() -> void:
	var bindings = {
		"move_up": KEY_W,
		"move_down": KEY_S,
		"move_left": KEY_A,
		"move_right": KEY_D,
		"jump": KEY_SPACE
	}
	
	for action in bindings:
		if not InputMap.has_action(action):
			InputMap.add_action(action)
			var event = InputEventKey.new()
			event.physical_keycode = bindings[action]
			InputMap.action_add_event(action, event)

func _unhandled_input(event: InputEvent) -> void:
	# Appuyer sur Échap pour basculer entre souris visible et capturée
	if event.is_action_pressed("ui_cancel"):
		if Input.mouse_mode == Input.MOUSE_MODE_CAPTURED:
			Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
		else:
			Input.mouse_mode = Input.MOUSE_MODE_CAPTURED

	# Gestion de la caméra à la souris quand le curseur est capturé
	if event is InputEventMouseMotion and Input.mouse_mode == Input.MOUSE_MODE_CAPTURED:
		# Rotation horizontale de la caméra
		camera_pivot.rotate_y(-event.relative.x * mouse_sensitivity)
		
		# Rotation verticale (limités entre -60° et 40°)
		pitch -= event.relative.y * mouse_sensitivity
		pitch = clamp(pitch, deg_to_rad(-60.0), deg_to_rad(40.0))
		camera_pivot.rotation.x = pitch

func _physics_process(delta: float) -> void:
	# Gravité
	if not is_on_floor():
		velocity.y -= gravity * delta

	# Saut
	if Input.is_action_just_pressed("jump") and is_on_floor():
		velocity.y = jump_velocity

	# Entrées ZQSD
	var input_dir := Input.get_vector("move_left", "move_right", "move_up", "move_down")
	
	# Direction relative au pivot de la caméra
	var cam_basis := camera_pivot.global_transform.basis
	var direction := (cam_basis * Vector3(input_dir.x, 0, input_dir.y)).normalized()
	direction.y = 0 # Garder le déplacement horizontal

	if direction != Vector3.ZERO:
		velocity.x = direction.x * speed
		velocity.z = direction.z * speed
		
		# Oriente le modèle visuel vers la direction de marche
		var target_angle := atan2(direction.x, direction.z)
		model.rotation.y = lerp_angle(model.rotation.y, target_angle, rotation_speed * delta)
	else:
		velocity.x = move_toward(velocity.x, 0, speed)
		velocity.z = move_toward(velocity.z, 0, speed)

	move_and_slide()
