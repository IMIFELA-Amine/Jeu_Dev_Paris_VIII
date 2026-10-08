extends Node2D

@onready var continuer = $menu/continuer/Continuer
@onready var continuer_sel = $menu/continuer/ContinuerSelec

@onready var nv = $menu/nvpartie/NvPartie
@onready var nv_sel = $menu/nvpartie/NvPartieSel

@onready var option = $menu/option/Option
@onready var option_sel = $menu/option/OptionSelec

@onready var quit = $menu/quitter/Quitter
@onready var quit_sel = $menu/quitter/QuitterSelec
@onready var clic1 =$"736851XkerilOneHitSonarInspired"
@onready var clic2 =$"736852XkerilTransitionHitAndWhoosh"
# Called when the node enters the scene tree for the first time.
func _ready() -> void:
	continuer_sel.visible = false
	nv_sel.visible = false
	option_sel.visible = false
	quit_sel.visible = false

# CONTINUER: Select/pas select quand on passe la sourit
func _on_continuer_mouse_entered() -> void:
	continuer.visible = false
	continuer_sel.visible = true
func _on_continuer_mouse_exited() -> void:
	continuer.visible = true
	continuer_sel.visible = false

# NV: Select/pas select quand on passe la sourit
func _on_nvpartie_mouse_entered() -> void:
	nv.visible = false
	nv_sel.visible = true
func _on_nvpartie_mouse_exited() -> void:
	nv.visible = true
	nv_sel.visible = false

# Option: Select/pas select quand on passe la sourit
func _on_option_mouse_entered() -> void:
	option.visible = false
	option_sel.visible = true
func _on_option_mouse_exited() -> void:
	option.visible = true
	option_sel.visible = false

# Quit: Select/pas select quand on passe la sourit
func _on_quitter_mouse_entered() -> void:
	quit.visible = false
	quit_sel.visible = true
func _on_quitter_mouse_exited() -> void:
	quit.visible = true
	quit_sel.visible = false


########### bouton Appuie ###########
# Continuer
func _on_continuer_pressed() -> void:
	clic1.play()
	pass # Replace with function body.
# NV
func _on_nvpartie_pressed() -> void:
	clic1.play()
	pass # Replace with function body.
# Option
func _on_option_pressed() -> void:
	clic1.play()
	pass # Replace with function body.
# Quit
func _on_quitter_pressed() -> void:
	clic1.play()
	get_tree().quit()
