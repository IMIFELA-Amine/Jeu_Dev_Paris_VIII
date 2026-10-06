extends Node2D

## Chemin vers la Camera_UI située dans Perso.tscn.
## Dans Perso.tscn, on peut laisser : ../Camera_UI
@export_node_path("Camera3D") var camera_ui_path: NodePath = NodePath("../Camera_UI")

## Taille de la petite fenêtre.
@export var viewport_size: Vector2i = Vector2i(260, 180)

## Position de la caméra par rapport au personnage.
@export var camera_distance: float = 4.5
@export var camera_height: float = 0.9

## Marge par rapport au bas de l'écran.
@export var bottom_margin: float = 25.0

var camera_ui: Camera3D
var camera_preview: SubViewportContainer
var sub_viewport: SubViewport

func _ready() -> void:
	var perso := get_parent() as Node3D
	if perso == null:
		push_error("UI : le parent doit être un Node3D.")
		return

	# Récupère Camera_UI depuis Perso.tscn.
	camera_ui = get_node_or_null(camera_ui_path) as Camera3D
	if camera_ui == null:
		push_error("UI : impossible de trouver Camera_UI avec le chemin : " + str(camera_ui_path))
		return

	camera_preview = $CameraPreview
	sub_viewport = $CameraPreview/SubViewport

	# Le SubViewport utilise exactement le même monde 3D que Perso.
	sub_viewport.world_3d = get_viewport().world_3d
	sub_viewport.size = viewport_size
	sub_viewport.render_target_update_mode = SubViewport.UPDATE_ALWAYS

	# Une Camera3D ne peut rendre que dans le Viewport auquel elle appartient.
	# On déplace donc Camera_UI dans le SubViewport, tout en gardant sa position globale.
	camera_ui.reparent(sub_viewport, true)

	# Place la caméra devant le personnage.
	camera_ui.global_position = perso.global_position + Vector3(0.0, camera_height, -camera_distance)

	# Regarde le personnage.
	camera_ui.look_at(
		perso.global_position + Vector3(0.0, camera_height, 0.0),
		Vector3.UP
	)

	# Active cette caméra dans le SubViewport.
	camera_ui.make_current()

	# Petite fenêtre en bas au centre.
	camera_preview.custom_minimum_size = Vector2(viewport_size)
	camera_preview.size = Vector2(viewport_size)
	camera_preview.z_index = 100
	_update_camera_position()

func _process(_delta: float) -> void:
	if camera_preview != null:
		_update_camera_position()

func _update_camera_position() -> void:
	var screen_size := get_viewport_rect().size
	camera_preview.position = Vector2(
		(screen_size.x - viewport_size.x) / 2.0,
		screen_size.y - viewport_size.y - bottom_margin
	)
