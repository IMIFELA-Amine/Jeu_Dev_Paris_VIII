extends Node2D

@onready var continuer = $menu/continuer/Continuer
@onready var continuer_sel = $menu/continuer/ContinuerSelec

@onready var nv = $menu/nvpartie/NvPartie
@onready var nv_sel = $menu/nvpartie/NvPartieSel

@onready var option = $menu/option/Option
@onready var option_sel = $menu/option/OptionSelec

@onready var quit = $menu/quitter/Quitter
@onready var quit_sel = $menu/quitter/QuitterSelec

# Called when the node enters the scene tree for the first time.
func _ready() -> void:
	continuer_sel.visible = false
	nv_sel.visible = false
	option_sel.visible = false
	quit_sel.visible = false
	$Save1.visible =false
	$Save2.visible =false
	$Save3.visible =false
	


func get_last_save() -> int:
	var last_save := -1
	for i in range(1, 4):
		if SaveManager.save_exists(i):
			last_save = i
	return last_save




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
	var save_id = get_last_save()
	if save_id == -1:
		print("Aucune sauvegarde trouvée")
		return
	if SaveManager.load_save(save_id):
		get_tree().change_scene_to_file(
			"res://Scenes/Levels/bac.tscn"
		)
		
# NV
func _on_nvpartie_pressed() -> void:
	$Save1.visible =true
	$Save2.visible =true
	$Save3.visible =true
	
# Option
func _on_option_pressed() -> void:
	pass # Replace with function body.
# Quit
func _on_quitter_pressed() -> void:
	get_tree().quit()






func _on_save_1_pressed() -> void:
	SaveManager.create_new_save(1)
	get_tree().change_scene_to_file(
		"res://Scenes/Levels/bac.tscn")
		
		
func _on_save_2_pressed() -> void:
	SaveManager.create_new_save(2)
	get_tree().change_scene_to_file(
		"res://Scenes/Levels/bac.tscn")

func _on_save_3_pressed() -> void:
	SaveManager.create_new_save(3)
	get_tree().change_scene_to_file(
		"res://Scenes/Levels/bac.tscn")
		
