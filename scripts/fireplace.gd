extends Node3D

## Firewatch-inspired cabin fireplace.
## Warm dusk light, soft fog, flickering fire.

@onready var fire_light: OmniLight3D = $Fire/FireLight
@onready var flames: GPUParticles3D = $Fire/Flames
@onready var embers: GPUParticles3D = $Fire/Embers
@onready var fire_core: MeshInstance3D = $Fire/FireCore

var intensity: float = 0.85:
	set(value):
		intensity = clampf(value, 0.0, 1.0)
		_apply_intensity()

var _noise_t: float = 0.0
var _core_mat: StandardMaterial3D


func _ready() -> void:
	var base := fire_core.get_active_material(0)
	if base is StandardMaterial3D:
		_core_mat = base.duplicate() as StandardMaterial3D
		fire_core.material_override = _core_mat
	_apply_intensity()


func _process(delta: float) -> void:
	_noise_t += delta
	var flicker := _firewatch_flicker(_noise_t)
	var lit := intensity * flicker

	fire_light.light_energy = lerpf(0.4, 4.2, lit)
	fire_light.omni_range = lerpf(3.5, 7.5, lit)
	fire_light.position.x = sin(_noise_t * 3.1) * 0.04 * intensity
	fire_light.position.z = cos(_noise_t * 2.4) * 0.03 * intensity

	fire_core.scale = Vector3(
		lerpf(0.7, 1.15, lit),
		lerpf(0.85, 1.35, lit),
		lerpf(0.7, 1.1, lit)
	)
	if _core_mat:
		_core_mat.emission_energy_multiplier = lerpf(0.5, 3.5, lit)
		_core_mat.albedo_color.a = lerpf(0.2, 0.65, lit)


func _firewatch_flicker(t: float) -> float:
	# Uneven, organic pulse — not a clean sine.
	var f := 1.0
	f += sin(t * 7.3) * 0.05
	f += sin(t * 13.1) * 0.035
	f += sin(t * 23.7 + 1.7) * 0.025
	f += sin(t * 3.2) * 0.04
	return clampf(f, 0.75, 1.2)


func _apply_intensity() -> void:
	if not is_node_ready():
		return
	flames.amount_ratio = intensity
	embers.amount_ratio = intensity * 0.65
	flames.emitting = intensity > 0.02
	embers.emitting = intensity > 0.05
