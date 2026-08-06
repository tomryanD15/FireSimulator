extends Node2D

## The single fireplace for the MVP.
## Observe → act → watch it respond.

@onready var fire: Node2D = $Fire
@onready var glow: Polygon2D = $Fire/Glow
@onready var flames: GPUParticles2D = $Fire/Flames
@onready var embers: GPUParticles2D = $Fire/Embers

## 0.0 = out, 1.0 = roaring. Placeholder for the sim.
var intensity: float = 0.75:
	set(value):
		intensity = clampf(value, 0.0, 1.0)
		_apply_intensity()


func _ready() -> void:
	_apply_intensity()


func _apply_intensity() -> void:
	if not is_node_ready():
		return

	glow.modulate.a = lerpf(0.15, 0.85, intensity)
	flames.amount_ratio = intensity
	embers.amount_ratio = intensity * 0.6
	flames.emitting = intensity > 0.01
	embers.emitting = intensity > 0.05
