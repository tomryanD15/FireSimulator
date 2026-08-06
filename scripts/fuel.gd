extends Node2D

## Adds fuel when the player presses Space.
## Boosts Fire intensity — first player action.

@onready var fire: Fire = $"../Fire"
@onready var placeholder: Polygon2D = $Placeholder
@onready var hint_label: Label = $"../UI/HintLabel"

@export_range(0.05, 1.0, 0.01) var boost_amount: float = 0.15

var _flash_time: float = 0.0


func _process(delta: float) -> void:
	if _flash_time > 0.0:
		_flash_time = maxf(_flash_time - delta, 0.0)
		placeholder.modulate = Color(1.4, 1.2, 1.0) if _flash_time > 0.0 else Color.WHITE


func _unhandled_input(event: InputEvent) -> void:
	if event is InputEventKey and event.pressed and not event.echo:
		if event.keycode == KEY_SPACE:
			_add_fuel()
			get_viewport().set_input_as_handled()


func _add_fuel() -> void:
	if fire == null:
		return
	fire.add_fuel(boost_amount)
	_flash_time = 0.12
	if hint_label:
		hint_label.text = "Space: add fuel"
