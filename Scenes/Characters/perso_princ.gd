extends CharacterBody3D

@export var speed: float = 5.0
@export var back_speed: float = 3.5   # Vitesse de déplacement en marche arrière
@export var sprint_speed: float = 8.5

# Physique réactive (virages fluides et arrêt net sans glissement)
@export var acceleration: float = 28.0
@export var deceleration: float = 35.0

@export var jump_velocity: float = 5.0
@export var mouse_sensitivity: float = 0.003
@export var rotation_speed: float = 12.0

# Limites de pitch de la caméra (haut / bas)
@export var min_pitch_deg: float = -45.0
@export var max_pitch_deg: float = 15.0

# Références aux nœuds
@onready var camera_pivot: Node3D = $CameraPivot
@onready var model: Node3D = $skin

@export var anim_player: AnimationPlayer

# Noms des animations
@export var anim_idle: String = "mixamo_com"
@export var anim_walk: String = "animation/walk"
@export var anim_back: String = "animation/back"
@export var anim_run: String = "animation/run"
@export var anim_jump: String = "animation/jump"

# Vitesse de déplacement pour laquelle les pieds collent au sol (animation à vitesse 1.0)
# Si ça patine : l'animation est trop lente pour le déplacement -> BAISSE la valeur
# Si les pieds "courent sur place" plus vite que le sol : -> AUGMENTE la valeur
@export var walk_ref_speed: float = 5.0
@export var back_ref_speed: float = 3.5
@export var run_ref_speed: float = 8.5

var gravity: float = ProjectSettings.get_setting("physics/3d/default_gravity")
var pitch: float = 0.0
var jump_cooldown: float = 0.0  # Empêche la détection parasite à haute vitesse
var was_on_floor: bool = true   # Sert à ne jouer l'anim de saut qu'une seule fois

func _ready() -> void:
	Input.mouse_mode = Input.MOUSE_MODE_CAPTURED
	
	if not anim_player:
		if $skin.has_node("AnimationPlayer"):
			anim_player = $skin/AnimationPlayer
		elif has_node("AnimationPlayer"):
			anim_player = $AnimationPlayer

	_setup_inputs()

func _setup_inputs() -> void:
	# Clavier WASD + Saut + Sprint
	var bindings = {
		"move_up": KEY_W,
		"move_down": KEY_S,
		"move_left": KEY_A,
		"move_right": KEY_D,
		"jump": KEY_SPACE,
		"sprint": KEY_SHIFT
	}
	
	for action in bindings:
		if not InputMap.has_action(action):
			InputMap.add_action(action)
			var event = InputEventKey.new()
			event.physical_keycode = bindings[action]
			InputMap.action_add_event(action, event)

func _unhandled_input(event: InputEvent) -> void:
	if event.is_action_pressed("ui_cancel"):
		if Input.mouse_mode == Input.MOUSE_MODE_CAPTURED:
			Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
		else:
			Input.mouse_mode = Input.MOUSE_MODE_CAPTURED

	if event is InputEventMouseMotion and Input.mouse_mode == Input.MOUSE_MODE_CAPTURED:
		camera_pivot.rotate_y(-event.relative.x * mouse_sensitivity)
		
		pitch -= event.relative.y * mouse_sensitivity
		pitch = clamp(pitch, deg_to_rad(min_pitch_deg), deg_to_rad(max_pitch_deg))
		camera_pivot.rotation.x = pitch

func _physics_process(delta: float) -> void:
	# Si inventaire ouvert
	var inventaire = get_tree().get_first_node_in_group("inventory")
	if inventaire and inventaire.visible:
		velocity = Vector3.ZERO
		return
		
		
	# Décompte du cooldown de saut
	if jump_cooldown > 0.0:
		jump_cooldown -= delta

	# 1. Gravité
	if not is_on_floor():
		velocity.y -= gravity * delta

	# 2. Saut (bloqué pendant le cooldown pour ignorer les micro-contacts à grande vitesse)
	if Input.is_action_just_pressed("jump") and is_on_floor() and jump_cooldown <= 0.0:
		velocity.y = jump_velocity
		jump_cooldown = 0.15

	# 3. Entrées de déplacement (WASD)
	var input_dir := Input.get_vector("move_left", "move_right", "move_up", "move_down")
	var is_moving_back := input_dir.y > 0.1
	var is_sprinting := Input.is_action_pressed("sprint") and not is_moving_back
	
	# Vitesse cible : recul, sprint ou marche normale
	var current_target_speed := speed
	if is_moving_back:
		current_target_speed = back_speed
	elif is_sprinting:
		current_target_speed = sprint_speed

	var cam_basis := camera_pivot.global_transform.basis
	var direction := (cam_basis * Vector3(input_dir.x, 0, input_dir.y)).normalized()
	direction.y = 0

	if direction != Vector3.ZERO:
		var target_vel := direction * current_target_speed
		velocity.x = move_toward(velocity.x, target_vel.x, acceleration * delta)
		velocity.z = move_toward(velocity.z, target_vel.z, acceleration * delta)
		
		var face_dir := -cam_basis.z if is_moving_back else direction
		face_dir.y = 0

		if face_dir != Vector3.ZERO:
			var target_angle := atan2(face_dir.x, face_dir.z)
			model.rotation.y = lerp_angle(model.rotation.y, target_angle, rotation_speed * delta)
	else:
		velocity.x = move_toward(velocity.x, 0.0, deceleration * delta)
		velocity.z = move_toward(velocity.z, 0.0, deceleration * delta)

	move_and_slide()
	
	# 4. Animations
	var horizontal_speed := Vector2(velocity.x, velocity.z).length()
	_update_animations(horizontal_speed, is_sprinting, is_moving_back)

func _update_animations(horizontal_speed: float, is_sprinting: bool, is_moving_back: bool) -> void:
	if not anim_player:
		return

	# En l'air : l'anim de saut ne se lance qu'une fois, au moment où on quitte le sol
	if not is_on_floor():
		if was_on_floor and anim_player.has_animation(anim_jump):
			anim_player.play(anim_jump, 0.1)
			# Cale la durée de l'anim sur le temps réel passé en l'air
			var air_time := 2.0 * jump_velocity / gravity
			anim_player.speed_scale = anim_player.get_animation(anim_jump).length / air_time
		was_on_floor = false
		return

	was_on_floor = true

	if horizontal_speed > 0.1:
		if is_moving_back:
			_play_anim(anim_back, 0.15, horizontal_speed / back_ref_speed)
		elif is_sprinting:
			_play_anim(anim_run, 0.15, horizontal_speed / run_ref_speed)
		else:
			_play_anim(anim_walk, 0.15, horizontal_speed / walk_ref_speed)
	else:
		if anim_player.has_animation(anim_idle):
			_play_anim(anim_idle, 0.2, 1.0)
		else:
			anim_player.stop()

func _play_anim(anim_name: String, blend_time: float = 0.15, anim_speed: float = 1.0) -> void:
	if anim_player.has_animation(anim_name):
		if anim_player.current_animation != anim_name:
			anim_player.play(anim_name, blend_time)
		
		anim_player.speed_scale = anim_speed
		

func _input(event):
	if event.is_action_pressed("ouvrir_inventaire"):
		toggle_inventory()

func toggle_inventory():
	var inventaire = get_tree().get_first_node_in_group("inventory")
	if not inventaire:
		print("Rien trouvee")
		return
	inventaire.visible = !inventaire.visible
	if inventaire.visible:
		Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
	else:
		Input.mouse_mode = Input.MOUSE_MODE_CAPTURED
