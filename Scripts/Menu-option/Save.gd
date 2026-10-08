class_name SaveData
extends Resource

var save_name: String = ""
var inventory: Array = []


func to_dictionary() -> Dictionary:
	return {
		"save_name": save_name,
		"inventory": inventory
	}


func from_dictionary(data: Dictionary) -> void:
	save_name = data.get("save_name", "")
	inventory = data.get("inventory", [])
