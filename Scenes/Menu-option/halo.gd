extends PointLight2D

@export_group("Scintillement permanent")
@export var base_energy: float = 1.2
@export var flicker_amount: float = 0.15
@export var flicker_speed: float = 3.0

@export_group("Gros clignotement (rapide)")
@export var blink_min_delay: float = 4.0
@export var blink_max_delay: float = 10.0
@export var blink_depth: float = 0.8       # 1 = s'éteint complètement

@export_group("Baisse lente (forte baisse puis retour)")
@export var dim_min_delay: float = 8.0
@export var dim_max_delay: float = 20.0
@export var dim_level_min: float = 0.25    # niveau le plus bas atteint (0.25 = tombe à 25 %)
@export var dim_level_max: float = 0.45    # niveau le moins bas (tirage aléatoire entre les deux)
@export var dim_fall_time_min: float = 1.5 # durée de la descente (s)
@export var dim_fall_time_max: float = 3.0
@export var dim_hold_time_min: float = 0.3 # temps passé au plus bas (s)
@export var dim_hold_time_max: float = 1.0
@export var relight_time_min: float = 1.5  # durée de la remontée (s)
@export var relight_time_max: float = 3.0

@export_group("Teinte")
@export var shift_color_when_dim: bool = true
@export var dim_tint: Color = Color(1.0, 0.55, 0.35)  # la flamme rougit quand elle faiblit

enum DimState { IDLE, FALLING, HOLD, RISING }

var noise := FastNoiseLite.new()
var t: float = 0.0

var blink_factor: float = 1.0
var dim_factor: float = 1.0

var blink_timer: float = 0.0
var dim_timer: float = 0.0
var is_blinking: bool = false

var dim_state: DimState = DimState.IDLE
var dim_elapsed: float = 0.0
var dim_duration: float = 1.0
var dim_level: float = 0.3
var dim_hold: float = 0.5
var dim_relight: float = 2.0

var base_color: Color
var halo_base_modulate: Color
var halo: Node2D

func _ready() -> void:
	noise.seed = randi()
	t = randf() * 100.0
	base_color = color
	
	if has_node("Halo"):
		halo = $Halo
		halo_base_modulate = halo.modulate
	
	blink_timer = randf_range(blink_min_delay, blink_max_delay)
	dim_timer = randf_range(dim_min_delay, dim_max_delay)

func _process(delta: float) -> void:
	# Scintillement continu
	t += delta * flicker_speed
	var f := 1.0 + noise.get_noise_1d(t) * flicker_amount

	# Un seul événement à la fois
	var busy := is_blinking or dim_state != DimState.IDLE
	if not busy:
		blink_timer -= delta
		dim_timer -= delta
		if blink_timer <= 0.0:
			_start_blink()
		elif dim_timer <= 0.0:
			_start_dim()

	_update_dim(delta)

	# Intensité finale : tout est corrélé sur cette seule valeur
	var level := f * blink_factor * dim_factor
	energy = base_energy * level
	
	var warmth := clampf(level, 0.0, 1.0)
	var tint := dim_tint.lerp(Color.WHITE, warmth) if shift_color_when_dim else Color.WHITE
	
	color = Color(base_color.r * tint.r, base_color.g * tint.g, base_color.b * tint.b, base_color.a)
	
	if halo:
		halo.scale = Vector2.ONE * maxf(level, 0.0)
		halo.modulate = Color(
			halo_base_modulate.r * tint.r,
			halo_base_modulate.g * tint.g,
			halo_base_modulate.b * tint.b,
			halo_base_modulate.a * warmth
		)

# --- Gros clignotement : rapide, brutal ---
func _start_blink() -> void:
	is_blinking = true
	var low := 1.0 - blink_depth
	
	var tween := create_tween()
	tween.tween_property(self, "blink_factor", low, 0.05)
	tween.tween_property(self, "blink_factor", 0.8, 0.06)
	tween.tween_property(self, "blink_factor", low, 0.05)
	tween.tween_property(self, "blink_factor", 1.0, 0.18)
	tween.finished.connect(func():
		blink_factor = 1.0
		blink_timer = randf_range(blink_min_delay, blink_max_delay)
		is_blinking = false
	)

# --- Baisse lente : descente, palier, remontée, calculées à chaque image ---
func _start_dim() -> void:
	dim_level = randf_range(dim_level_min, dim_level_max)
	dim_hold = randf_range(dim_hold_time_min, dim_hold_time_max)
	dim_relight = randf_range(relight_time_min, relight_time_max)
	_set_dim_state(DimState.FALLING, randf_range(dim_fall_time_min, dim_fall_time_max))

func _set_dim_state(new_state: DimState, duration: float) -> void:
	dim_state = new_state
	dim_elapsed = 0.0
	dim_duration = maxf(duration, 0.01)

func _update_dim(delta: float) -> void:
	if dim_state == DimState.IDLE:
		return
	
	dim_elapsed += delta
	var k := clampf(dim_elapsed / dim_duration, 0.0, 1.0)
	var smooth := smoothstep(0.0, 1.0, k)
	
	match dim_state:
		DimState.FALLING:
			dim_factor = lerpf(1.0, dim_level, smooth)
			if k >= 1.0:
				_set_dim_state(DimState.HOLD, dim_hold)
		DimState.HOLD:
			dim_factor = dim_level
			if k >= 1.0:
				_set_dim_state(DimState.RISING, dim_relight)
		DimState.RISING:
			dim_factor = lerpf(dim_level, 1.0, smooth)
			if k >= 1.0:
				dim_factor = 1.0
				dim_state = DimState.IDLE
				dim_timer = randf_range(dim_min_delay, dim_max_delay)
