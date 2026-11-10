extends Resource
class_name EquipmentData

enum Slot { HEATER, FILTER, LIGHT, AIR_STONE, CO2, TEST_KIT, SUBSTRATE, DECOR }

@export var id: String = ""
@export var display_name: String = ""
@export var slot: Slot = Slot.FILTER
@export var price: int = 10
@export var unlock_tier: int = 0

@export_group("Heater")
@export var heater_target_temp_c: float = 25.0
@export var heater_power: float = 1.0           ## higher = faster pull toward target, more failure-prone under strain
@export var heater_base_failure_chance_per_day: float = 0.002

@export_group("Filter")
@export var filter_flow_liters_per_hour: float = 100.0
@export var filter_bio_capacity: float = 1.0     ## scales how fast filter_maturity grows and how much ammonia/nitrite it processes

@export_group("Light")
@export var light_intensity: float = 1.0
@export var light_color: Color = Color(1.0, 0.98, 0.9)

@export_group("Air stone / CO2")
@export var oxygen_boost: float = 0.0
@export var co2_boost: float = 0.0

@export_group("Test kit")
@export var reveals_exact_readings: bool = false
