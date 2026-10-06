extends Node
const Save_1 := "user://Data1.tres"
const Save_2 := "user://Data2.tres"
const Save_3 := "user://Data3.tres"

# --- DÉFINITION DATA ---
class SaveData extends Resource:
	@export var test:int = 10


# --- FONCTIONS DU SYSTÈME DE SAUVEGARDE ---
## Sauvegarder dans le slot choisi (1, 2 ou 3)
func save_slot(slot_index: int, data: SaveData) -> bool:
	var path := _get_slot_path(slot_index)
	if path.is_empty():
		push_error("Slot invalide : %d. Choisis 1, 2 ou 3." % slot_index)
		return false
		
	var error := ResourceSaver.save(data, path)
	if error != OK:
		push_error("Échec de la sauvegarde sur le slot %d (Code: %d)" % [slot_index, error])
		return false
		
	print("Sauvegarde réussie : ", path)
	return true

## Charger depuis le slot choisi (1, 2 ou 3)
func load_slot(slot_index: int) -> SaveData:
	var path := _get_slot_path(slot_index)
	if path.is_empty():
		push_error("Slot invalide : %d. Choisis 1, 2 ou 3." % slot_index)
		return null
		
	if not FileAccess.file_exists(path):
		print("Aucune sauvegarde trouvée à l'emplacement : ", path)
		return null
		
	var data := ResourceLoader.load(path) as SaveData
	if data:
		print("Chargement réussi : ", path)
	return data

## Vérifier si une sauvegarde existe
func has_save(slot_index: int) -> bool:
	var path := _get_slot_path(slot_index)
	if path.is_empty():
		return false
	return FileAccess.file_exists(path)


# --- 3. HELPER INTERNE ---

func _get_slot_path(slot_index: int) -> String:
	match slot_index:
		1: return Save_1
		2: return Save_2
		3: return Save_3
		_: return ""
