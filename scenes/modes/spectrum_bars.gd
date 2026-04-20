extends Node3D

const BAND_COUNT: int = 7
const BAND_COLORS: Array[Color] = [
	Color("#FF1744"),  # Sub-Bass: Deep Red
	Color("#FF9100"),  # Bass: Orange
	Color("#FFEA00"),  # Lo-Mid: Yellow
	Color("#00E676"),  # Mid: Green
	Color("#00E5FF"),  # Up-Mid: Cyan
	Color("#2979FF"),  # Presence: Blue
	Color("#D500F9"),  # Brilliance: Violet
]

## Bar distribution per band (weighted toward bass for visual density in front)
const BARS_PER_BAND: Array[int] = [4, 5, 4, 4, 4, 3, 3]  # = 27 total

const RING_RADIUS: float = 3.0
const BAR_RADIUS: float = 0.12
const MIN_HEIGHT: float = 0.1
const MAX_HEIGHT: float = 5.0
const EMISSION_BASE: float = 2.0
const EMISSION_PEAK: float = 8.0

var _bars: Array[MeshInstance3D] = []
var _bar_bands: Array[int] = []  # Which band index each bar belongs to
var _materials: Array[StandardMaterial3D] = []

func _ready() -> void:
	_create_bars()

func _create_bars() -> void:
	var total_bars: int = 0
	for count in BARS_PER_BAND:
		total_bars += count

	var bar_index: int = 0
	var angle_step: float = TAU / total_bars

	for band_idx in range(BAND_COUNT):
		for _i in range(BARS_PER_BAND[band_idx]):
			# Offset so bass (first bands) is in front (-Z direction)
			var angle: float = bar_index * angle_step + PI

			var mesh_instance := MeshInstance3D.new()
			var cylinder := CylinderMesh.new()
			cylinder.top_radius = BAR_RADIUS
			cylinder.bottom_radius = BAR_RADIUS
			cylinder.height = MIN_HEIGHT
			cylinder.radial_segments = 16
			cylinder.rings = 1
			mesh_instance.mesh = cylinder

			var mat := StandardMaterial3D.new()
			mat.emission_enabled = true
			mat.emission = BAND_COLORS[band_idx]
			mat.emission_energy_multiplier = EMISSION_BASE
			mat.albedo_color = BAND_COLORS[band_idx] * 0.3
			mesh_instance.material_override = mat

			# Position on ring, bars grow from y=0 upward
			var x: float = cos(angle) * RING_RADIUS
			var z: float = sin(angle) * RING_RADIUS
			mesh_instance.position = Vector3(x, MIN_HEIGHT / 2.0, z)

			add_child(mesh_instance)
			_bars.append(mesh_instance)
			_bar_bands.append(band_idx)
			_materials.append(mat)
			bar_index += 1

func _process(_delta: float) -> void:
	var data: AudioData = AudioManager.audio_data
	if data == null:
		return

	if not AudioManager.has_signal:
		_update_idle()
		return

	for i in range(_bars.size()):
		var band_idx: int = _bar_bands[i]
		var magnitude: float = data.bands[band_idx]
		_update_bar(i, magnitude)

func _update_bar(index: int, magnitude: float) -> void:
	var target_height: float = lerpf(MIN_HEIGHT, MAX_HEIGHT, magnitude)
	var cylinder: CylinderMesh = _bars[index].mesh as CylinderMesh
	cylinder.height = target_height

	# Reposition so bar grows from floor (y=0), bottom stays grounded
	_bars[index].position.y = target_height / 2.0

	# Emission energy: pulse glow with magnitude
	_materials[index].emission_energy_multiplier = lerpf(
		EMISSION_BASE, EMISSION_PEAK, magnitude
	)

func _update_idle() -> void:
	var t: float = Time.get_ticks_msec() / 1000.0
	for i in range(_bars.size()):
		var phase: float = float(i) / _bars.size() * TAU
		var idle_val: float = 0.05 + 0.03 * sin(t * 0.5 + phase)
		_update_bar(i, idle_val)
