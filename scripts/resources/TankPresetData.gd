extends Resource
class_name TankPresetData
## A purchasable tank size/type, used to configure a locked tank slot when the player buys it
## (see TankController.unlock and GameController._on_buy_tank).

@export var id: String = ""
@export var display_name: String = ""
@export var price: int = 50
@export var unlock_tier: int = 0
@export var tank_liters: float = 40.0
@export var tank_type: int = 0  ## matches TankController.TankType (FRESHWATER=0, SALTWATER=1)
@export var ambient_temp_base_c: float = 22.0
