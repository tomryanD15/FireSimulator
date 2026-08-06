extends Node2D

class_name Fireplace

## The heart of Fire Simulator.
##
## This node owns the hidden fire simulation state.
## Future systems (fuel, tools, weather, visuals, audio)
## should read from and write to these values — they should
## not invent parallel "health" meters.
##
## THIS INCREMENT: airflow API + debug Up/Down to change draft.
## Still no visuals, player UI, or Main wiring.

# ---------------------------------------------------------------------------
# Burn state
# ---------------------------------------------------------------------------

## Coarse lifecycle of the fire. Derived systems may key off this,
## but finer behaviour should come from the float values below.
enum BurnState {
	OUT, ## No combustion. Intensity and heat should trend toward zero.
	SMOLDERING, ## Weak, low-flame or ember-led burn.
	BURNING, ## Healthy, sustained fire.
	ROARING, ## Hot, vigorous burn — high intensity and airflow.
}

# ---------------------------------------------------------------------------
# Simulation values (hidden from the player)
#
# Convention: most quantities are normalized 0.0–1.0 so future systems
# can compose them without unit conversion.
# ---------------------------------------------------------------------------

@export_group("Simulation")

## How strongly the fire is currently expressing itself (flame presence).
## Range: 0.0 (none) … 1.0 (maximum expression).
@export_range(0.0, 1.0, 0.01) var fire_intensity: float = 0.55

## Thermal energy held by the firebed / surround.
## Range: 0.0 (cold) … 1.0 (very hot).
@export_range(0.0, 1.0, 0.01) var heat: float = 0.45

## Combustible energy still available in the firebox.
## Range: 0.0 (empty) … 1.0 (fully stocked).
@export_range(0.0, 1.0, 0.01) var fuel_energy: float = 0.7

## How well air is feeding the fire.
## Range: 0.0 (choked) … 1.0 (strong draft).
@export_range(0.0, 1.0, 0.01) var airflow: float = 0.5

## Accumulated ash and incombustible residue.
## Range: 0.0 (clean) … 1.0 (heavily choked).
@export_range(0.0, 1.0, 0.01) var ash_level: float = 0.05

## Water content in / on the fuel bed.
## Range: 0.0 (bone dry) … 1.0 (soaked).
@export_range(0.0, 1.0, 0.01) var moisture: float = 0.15

## Visible / atmospheric smoke currently being produced.
## Range: 0.0 (clear) … 1.0 (thick).
@export_range(0.0, 1.0, 0.01) var smoke_density: float = 0.2

## Discrete burn lifecycle label.
@export var burn_state: BurnState = BurnState.BURNING

# ---------------------------------------------------------------------------
# Simulation rates (tunable; still not player-facing)
# ---------------------------------------------------------------------------

@export_group("Rates")

## How fast fuel is consumed at full intensity + airflow.
@export_range(0.0, 0.5, 0.001) var fuel_burn_rate: float = 0.035

## How quickly intensity moves toward its target.
@export_range(0.1, 5.0, 0.05) var intensity_responsiveness: float = 1.25

## How quickly heat chases intensity (lower = more lag / ember bed).
@export_range(0.05, 2.0, 0.05) var heat_responsiveness: float = 0.35

## How quickly smoke density eases toward its target.
@export_range(0.1, 5.0, 0.05) var smoke_responsiveness: float = 1.0

## Fraction of burned fuel that becomes ash.
@export_range(0.0, 1.0, 0.01) var ash_production: float = 0.08

# ---------------------------------------------------------------------------
# Debug controls (for testing this scene with F6)
# Turn off once real fuel items / tools / Main wiring exist.
# ---------------------------------------------------------------------------

@export_group("Debug")

## When true, keyboard debug controls are active.
## Space = add fuel · Up/Down = adjust airflow
@export var debug_input_enabled: bool = true

## Energy added per debug Space press.
@export_range(0.05, 0.5, 0.01) var debug_fuel_amount: float = 0.2

## Moisture of the debug fuel (0 = dry, 1 = soaked).
@export_range(0.0, 1.0, 0.01) var debug_fuel_moisture: float = 0.1

## Airflow change per Up/Down press.
@export_range(0.01, 0.25, 0.01) var debug_airflow_step: float = 0.1


func _process(delta: float) -> void:
	_simulate(delta)


func _unhandled_input(event: InputEvent) -> void:
	if not debug_input_enabled:
		return
	if event is InputEventKey and event.pressed and not event.echo:
		match event.keycode:
			KEY_SPACE:
				add_fuel(debug_fuel_amount, debug_fuel_moisture)
				get_viewport().set_input_as_handled()
			KEY_UP:
				adjust_airflow(debug_airflow_step)
				get_viewport().set_input_as_handled()
			KEY_DOWN:
				adjust_airflow(-debug_airflow_step)
				get_viewport().set_input_as_handled()


# ---------------------------------------------------------------------------
# Public API — future fuel items / tools should call these
# ---------------------------------------------------------------------------

## Add combustible energy to the firebox.
## energy:          how much fuel to add (0–1 scale contribution)
## fuel_moisture:   wetness of the incoming fuel (blended into moisture)
func add_fuel(energy: float, fuel_moisture: float = 0.1) -> void:
	energy = maxf(energy, 0.0)
	if energy <= 0.0:
		return

	var before: float = fuel_energy
	fuel_energy = clampf(fuel_energy + energy, 0.0, 1.0)
	var added: float = fuel_energy - before
	if added <= 0.0:
		return

	# Blend bed moisture toward the new fuel by how much actually landed.
	var weight: float = added / maxf(fuel_energy, 0.001)
	moisture = clampf(lerpf(moisture, fuel_moisture, weight), 0.0, 1.0)


## Set draft directly (vents, wind, damper…).
func set_airflow(value: float) -> void:
	airflow = clampf(value, 0.0, 1.0)


## Nudge draft up or down (bellows, briefly opening a vent…).
func adjust_airflow(amount: float) -> void:
	set_airflow(airflow + amount)


# ---------------------------------------------------------------------------
# Simulation
# ---------------------------------------------------------------------------

## One step of the core fire simulation.
## Keep this function boring and readable — new mechanics should
## adjust inputs (fuel, air, moisture…) rather than fork this logic.
func _simulate(delta: float) -> void:
	var target_intensity: float = _compute_target_intensity()
	fire_intensity = move_toward(
		fire_intensity,
		target_intensity,
		intensity_responsiveness * delta
	)

	_consume_fuel(delta)
	_update_heat(delta)
	_update_smoke(delta)
	_update_burn_state()


## Ideal intensity from current conditions.
## This is the "what the fire wants to be" value — not a health bar.
func _compute_target_intensity() -> float:
	if fuel_energy <= 0.001:
		return 0.0

	# Dry, clear, well-aired fuel burns hotter; ash and moisture suppress.
	var dryness: float = 1.0 - moisture
	var clearance: float = 1.0 - ash_level
	var target: float = fuel_energy * airflow * dryness * clearance
	return clampf(target, 0.0, 1.0)


func _consume_fuel(delta: float) -> void:
	if fire_intensity <= 0.001 or fuel_energy <= 0.0:
		return

	# Stronger fires + more air eat fuel faster.
	var burn: float = fuel_burn_rate * fire_intensity * (0.35 + airflow * 0.65)
	var used: float = minf(burn * delta, fuel_energy)
	fuel_energy = maxf(fuel_energy - used, 0.0)
	ash_level = clampf(ash_level + used * ash_production, 0.0, 1.0)


func _update_heat(delta: float) -> void:
	# Heat lags intensity so the bed stays warm after flames die down.
	heat = move_toward(heat, fire_intensity, heat_responsiveness * delta)


func _update_smoke(delta: float) -> void:
	# Wet fuel and poor airflow make smoke; a clean burn stays clearer.
	var poor_air: float = 1.0 - airflow
	var smoke_target: float = fire_intensity * clampf(moisture * 0.7 + poor_air * 0.5, 0.0, 1.0)
	smoke_density = move_toward(
		smoke_density,
		smoke_target,
		smoke_responsiveness * delta
	)


func _update_burn_state() -> void:
	if fire_intensity <= 0.001:
		burn_state = BurnState.OUT
	elif fire_intensity < 0.25:
		burn_state = BurnState.SMOLDERING
	elif fire_intensity < 0.75:
		burn_state = BurnState.BURNING
	else:
		burn_state = BurnState.ROARING
