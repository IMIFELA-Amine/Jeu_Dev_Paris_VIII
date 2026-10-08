extends Node

const SAVE_FOLDER := "res://Save/"

var current_save_id: int = -1
var current_save_data: SaveData


func _ready() -> void:
	DirAccess.make_dir_recursive_absolute(
		ProjectSettings.globalize_path(SAVE_FOLDER)
	)


func select_save(save_id: int) -> void:
	current_save_id = save_id


func get_save_path(save_id: int) -> String:
	return SAVE_FOLDER + "save" + str(save_id) + ".json"


func save_game() -> void:
	if current_save_id == -1:
		push_error("Aucune sauvegarde sélectionnée !")
		return
	var file := FileAccess.open(
		get_save_path(current_save_id),
		FileAccess.WRITE)
	if file == null:
		return
	file.store_string(
		JSON.stringify(current_save_data.to_dictionary(), "\t"))
	file.close()


func load_save(save_id: int) -> bool:
	var path := get_save_path(save_id)
	if not FileAccess.file_exists(path):
		return false
	var file := FileAccess.open(path, FileAccess.READ)
	if file == null:
		return false
	var json_data = JSON.parse_string(file.get_as_text())
	file.close()
	if json_data == null:
		return false

	current_save_data = SaveData.new()
	current_save_data.from_dictionary(json_data)
	current_save_id = save_id
	return true


func create_new_save(save_id: int) -> void:
	current_save_id = save_id
	current_save_data = SaveData.new()
	current_save_data.save_name = "Sauvegarde " + str(save_id)
	## TEST
	current_save_data.inventory = [
		{
			"id": "pistolet_mk1",
			"quantity": 1,
			"stats": {
				"degats": 42,
				"precision": 78,
				"cadence": 5
			}
		}
	]

	save_game()
	
func save_exists(save_id: int) -> bool:

	return FileAccess.file_exists(
		get_save_path(save_id)
	)
