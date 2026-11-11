extends Node
## Scans res://data/ for all content .tres files at boot and builds in-memory catalogs.
## This is the piece that makes "add species #40" a pure content task (plan Section 1):
## dropping a new .tres into data/species/ is all that's needed, no code changes.

var species_catalog: Dictionary = {}     ## id -> FishSpeciesData
var equipment_catalog: Dictionary = {}   ## id -> EquipmentData
var food_catalog: Dictionary = {}        ## id -> FoodItemData
var medication_catalog: Dictionary = {}  ## id -> MedicationData
var tank_preset_catalog: Dictionary = {} ## id -> TankPresetData


func _ready() -> void:
	_load_catalog("res://data/species/", species_catalog)
	_load_catalog("res://data/equipment/", equipment_catalog)
	_load_catalog("res://data/food/", food_catalog)
	_load_catalog("res://data/medication/", medication_catalog)
	_load_catalog("res://data/tanks/", tank_preset_catalog)


func _load_catalog(dir_path: String, into: Dictionary) -> void:
	var dir := DirAccess.open(dir_path)
	if dir == null:
		push_warning("ShopManager: could not open %s" % dir_path)
		return
	dir.list_dir_begin()
	var file_name := dir.get_next()
	while file_name != "":
		## In an exported build the directory lists "guppy.tres.remap", not "guppy.tres" —
		## without this trim every catalog loads empty on a real device (and only there).
		file_name = file_name.trim_suffix(".remap")
		if file_name.ends_with(".tres"):
			var res := load(dir_path + file_name)
			if res != null and "id" in res and res.id != "":
				into[res.id] = res
			else:
				push_warning("ShopManager: %s%s has no id, skipping" % [dir_path, file_name])
		file_name = dir.get_next()


func species_available_for_tier(unlock_tier: int) -> Array[FishSpeciesData]:
	var result: Array[FishSpeciesData] = []
	for s in species_catalog.values():
		if s.unlock_tier <= unlock_tier:
			result.append(s)
	return result


func equipment_available_for_tier(unlock_tier: int) -> Array[EquipmentData]:
	var result: Array[EquipmentData] = []
	for e in equipment_catalog.values():
		if e.unlock_tier <= unlock_tier:
			result.append(e)
	return result


func get_species(id: String) -> FishSpeciesData:
	return species_catalog.get(id)


func get_equipment(id: String) -> EquipmentData:
	return equipment_catalog.get(id)


func get_food(id: String) -> FoodItemData:
	return food_catalog.get(id)


func get_medication(id: String) -> MedicationData:
	return medication_catalog.get(id)


func get_tank_preset(id: String) -> TankPresetData:
	return tank_preset_catalog.get(id)
