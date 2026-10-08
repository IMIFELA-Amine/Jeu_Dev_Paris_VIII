extends TextureButton

var item_data: Dictionary = {}


func setup_item(data: Dictionary) -> void:
	item_data = data
	var item_id: String = data.get("id", "")
	if item_id == "":
		clear_slot()
		return

	var item_info := ItemDatabase.get_item(item_id)
	if item_info.is_empty():
		clear_slot()
		return
	# Image de l'objet
	var texture := load(item_info["image"])
	if texture:
		$Icon.texture = texture
	# Quantité
	if data.get("quantity", 1) > 1:
		tooltip_text = (
			item_info["nom"]
			+ "\nQuantité : "
			+ str(data["quantity"])
		)
	else:
		tooltip_text = item_info["nom"]


func clear_slot() -> void:
	item_data = {}
	$Icon.texture = null
	tooltip_text = ""


func _pressed() -> void:
	if item_data.is_empty():
		return
	var inventory = get_tree().get_first_node_in_group("inventory")
	if inventory:
		inventory.show_item(item_data)
