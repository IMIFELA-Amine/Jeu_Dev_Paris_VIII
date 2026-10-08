extends Node3D

@export var rotation_speed: float = 1
@export var distance: float = 3.5

@onready var camera: Camera3D = $Camera3D_inv

func _ready() -> void:
	pass

func _process(delta: float) -> void:
	rotate_y(rotation_speed * delta)
