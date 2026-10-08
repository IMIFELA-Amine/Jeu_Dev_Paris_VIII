extends Control

@onready var grille: GridContainer = $GrilleInventaire

@onready var grande_image: TextureRect = $Visualiseur_objet/iconVisual
@onready var nom_objet: Label = $Visualiseur_objet/NomObjet
@onready var description: Label = $Visualiseur_objet/Description
@onready var stats: VBoxContainer = $Visualiseur_objet/Stats
@onready var prev_perso = $CameraPreview

const LOOKING_AROUND = preload("res://Animation/Animation/Inventaire/Looking Around.fbx")
# ==============================
# CONFIGURATION DE LA GRILLE
# ==============================
@export var nombre_colonnes: int = 5
@export var taille_case: Vector2 = Vector2(74, 62)
@export var espacement_horizontal: int = 0
@export var espacement_vertical: int = 0

func _ready() -> void:
	configurer_grille()
	add_to_group("inventory")
	visible = false
	appliquer_animation_looking_around()
	load_inventory()


func configurer_grille() -> void:
	# Nombre de colonnes
	grille.columns = nombre_colonnes
	# Espacement entre les cases
	grille.add_theme_constant_override(
		"h_separation",
		espacement_horizontal)
	grille.add_theme_constant_override(
		"v_separation",
		espacement_vertical)
	# Taille de chaque Slot
	for slot in grille.get_children():
		slot.custom_minimum_size = taille_case

# ============================================================
# CHARGER L'INVENTAIRE
# ============================================================
func load_inventory() -> void:
	var save_data: SaveData = SaveManager.current_save_data
	if save_data == null:
		return
	var slots = grille.get_children()
	# Vider toutes les cases
	for slot in slots:
		slot.clear_slot()
	# Mettre les objets dans les cases
	for i in range(save_data.inventory.size()):
		if i >= slots.size():
			break
		slots[i].setup_item(save_data.inventory[i])
# ============================================================
# AFFICHER UN OBJET
# ============================================================

func show_item(item_data: Dictionary) -> void:
	var item_id: String = item_data.get("id", "")
	if item_id == "":
		return
	var item_info := ItemDatabase.get_item(item_id)
	if item_info.is_empty():
		return
	# IMAGE
	var texture := load(item_info["image"])
	if texture:
		grande_image.texture = texture
	# NOM
	nom_objet.text = item_info["nom"]
	# DESCRIPTION
	description.text = item_info.get(
		"description",
		"")
	# STATS
	display_stats(item_data)


# ============================================================
# AFFICHER LES STATS
# ============================================================

func display_stats(item_data: Dictionary) -> void:
	# Nettoyer les anciennes stats
	for child in stats.get_children():
		child.queue_free()
	
	var item_stats: Dictionary = item_data.get(
		"stats",
		{})
	
	# Aucune stat
	if item_stats.is_empty():
		var label := Label.new()
		label.text = "Aucune statistique"
		stats.add_child(label)
		return
	
	# Créer les labels
	for stat_name in item_stats:
		var label := Label.new()
		var value = item_stats[stat_name]
		label.text = (
			stat_name.capitalize()
			+ " : "
			+ str(value))
		stats.add_child(label)




func appliquer_animation_looking_around() -> void:
	var personnage = $"Visualiseur_inv/SubViewport/Looking Around"
	if personnage == null:
		push_error("CharacterPreview introuvable !")
		return

	var anim_player: AnimationPlayer = trouver_animation_player(personnage)
	if anim_player == null:
		push_error("Aucun AnimationPlayer trouvé sur le personnage !")
		return

	var animation_scene = LOOKING_AROUND.instantiate()
	add_child(animation_scene)

	var source_anim_player: AnimationPlayer = trouver_animation_player(animation_scene)
	if source_anim_player == null:
		push_error("Aucun AnimationPlayer dans Looking Around.fbx")
		animation_scene.queue_free()
		return

	for animation_name in source_anim_player.get_animation_list():
		if animation_name.begins_with("RESET"):
			continue

		var animation_copy: Animation = source_anim_player.get_animation(animation_name).duplicate()
		animation_copy.loop_mode = Animation.LOOP_LINEAR  # boucle

		# DEBUG : affiche les chemins des pistes
		for i in animation_copy.get_track_count():
			print("Piste : ", animation_copy.track_get_path(i))

		# Bibliothèque : utiliser has_animation_library, pas get_animation_library
		var library: AnimationLibrary
		if anim_player.has_animation_library(""):
			library = anim_player.get_animation_library("")
		else:
			library = AnimationLibrary.new()
			anim_player.add_animation_library("", library)

		if library.has_animation("looking_around"):
			library.remove_animation("looking_around")
		library.add_animation("looking_around", animation_copy)
		break

	animation_scene.queue_free()

	print("Racine de l'AnimationPlayer : ", anim_player.get_node(anim_player.root_node).name)
	anim_player.play("looking_around")
func trouver_animation_player(node: Node) -> AnimationPlayer:
	if node is AnimationPlayer:
		return node	
	for child in node.get_children():
		var result := trouver_animation_player(child)
		if result != null:
			return result
	return null
