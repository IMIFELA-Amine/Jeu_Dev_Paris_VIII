extends Node

var items: Dictionary = {
	
	"pistolet_mk1": {
		"nom": "Pistolet MK-I",
		"image": "res://Assets/Item/test.webp",
		"description": "Un pistolet militaire standard."
	},
	
	"fusil_assaut": {
		"nom": "Fusil d'assaut",
		"image": "res://assets/items/fusil_assaut.png",
		"description": "Un fusil d'assaut puissant."
	},
	
	"medikit": {
		"nom": "Kit médical",
		"image": "res://assets/items/medikit.png",
		"description": "Permet de récupérer des points de vie."
	}
}


func get_item(item_id: String) -> Dictionary:
	if items.has(item_id):
		return items[item_id]
	return {}
