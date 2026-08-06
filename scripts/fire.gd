extends Node2D

class_name Fire

## Fire intensity with slow natural decay.
## Space (via Fuel) can boost intensity.

@onready var placeholder: Polygon2D = $Placeholder
@onready var intensity_label: Label = $"../UI/IntensityLabel"

## intensity 0 = out, 1 = full.
@export_range(0.0, 1.0, 0.01) var intensity: float = 0.8:
	set(value):
		intensity = clampf(value, 0.0, 1.0)

## How fast the fire dies (units per second).
@export_range(0.0, 0.5, 0.001) var decay_rate: float = 0.04


func add_fuel(amount: float) -> void:
	intensity = minf(intensity + amount, 1.0)


func _process(delta: float) -> void:
	if intensity > 0.0:
		intensity = maxf(intensity - decay_rate * delta, 0.0)

	_update_visuals()
	_update_label()


func _update_visuals() -> void:
	if placeholder == null:
		return

	var flicker: float = 1.0 + sin(Time.get_ticks_msec() * 0.011) * 0.05
	flicker += sin(Time.get_ticks_msec() * 0.029) * 0.03

	var lit: float = intensity * flicker
	placeholder.modulate.a = clampf(lit, 0.0, 1.0)
	placeholder.scale = Vector2(1.0, 0.9 + lit * 0.2)
	placeholder.visible = intensity > 0.001


func _update_label() -> void:
	if intensity_label == null:
		return
	intensity_label.text = "Intensity: %.2f" % intensity
