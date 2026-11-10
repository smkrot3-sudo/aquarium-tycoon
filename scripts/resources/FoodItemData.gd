extends Resource
class_name FoodItemData

@export var id: String = ""
@export var display_name: String = ""
@export var price_per_feeding: int = 1
@export var compatible_diets: Array[int] = []   ## values from FishSpeciesData.Diet
@export var hunger_restored: float = 40.0
@export var waste_factor: float = 1.0           ## higher = messier food, raises ammonia more per feeding
