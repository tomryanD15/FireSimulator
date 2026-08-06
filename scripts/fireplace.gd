extends Node2D

## Simple fireplace. Intensity drives the glow for now.

@onready var glow: Polygon2D = $Fire/Glow
@onready var flame: Polygon2D = $Fire/Flame

var intensity: float = 0.8:
	set(value):
		intensity = clampf(value, 0.0, 1.0)


func _process(_delta: float) -> void:
	var flicker := 1.0 + sin(Time.get_ticks_msec() * 0.012) * 0.06
	flicker += sin(Time.get_ticks_msec() * 0.031) * 0.04
	var alpha := intensity * flicker
	glow.modulate.a = clampf(alpha * 0.7, 0.0, 1.0)
	flame.modulate.a = clampf(alpha, 0.0, 1.0)
	flame.scale = Vector2(1.0, 0.92 + intensity * 0.18 * flicker)
