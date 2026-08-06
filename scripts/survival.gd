extends Node2D

## Tracks how long the fire has been burning.
## Counts only while intensity > 0.

@onready var fire: Fire = $Fire
@onready var survival_label: Label = $UI/SurvivalLabel

var time_alive: float = 0.0
var _was_lit: bool = true


func _process(delta: float) -> void:
	if fire == null:
		return

	var lit: bool = fire.intensity > 0.001
	if lit:
		time_alive += delta
		_was_lit = true
		survival_label.text = "Time: %.1fs" % time_alive
	elif _was_lit:
		_was_lit = false
		survival_label.text = "Fire out — %.1fs" % time_alive
