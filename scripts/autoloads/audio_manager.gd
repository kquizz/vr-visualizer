extends Node

## Frequency band boundaries (Hz) - 7 musically meaningful bands
const BAND_EDGES: Array[float] = [20.0, 60.0, 250.0, 500.0, 2000.0, 4000.0, 6000.0, 11050.0]

## dB normalization floor
const MIN_DB: float = 60.0

## No-signal detection
const NO_SIGNAL_THRESHOLD: float = 0.001
const NO_SIGNAL_FRAMES: int = 30  # ~0.5s at 60fps

## Spectrum analyzer instance for capture bus
var _analyzer: AudioEffectSpectrumAnalyzerInstance

## Single-source audio data, updated every frame. Public API.
var audio_data: AudioData

## Whether audio signal is currently detected
var has_signal: bool = false

## Whether capture is active
var _is_capturing: bool = false

## Name of the detected capture device
var _capture_device: String = ""

## Silent frame counter for signal detection
var _silent_frames: int = 0

## Reference to the mic stream player for diagnostics
var _player: AudioStreamPlayer

## AudioEffectCapture instance for raw PCM extraction
var _capture_effect: AudioEffectCapture
## Buffer for PCM samples, reused each frame
var _pcm_buffer: PackedVector2Array

func _ready() -> void:
	# Defer initialization to ensure AudioServer is fully ready
	call_deferred("_initialize")

func _initialize() -> void:
	audio_data = AudioData.new()

	# Auto-detect BlackHole in input device list
	var devices := AudioServer.get_input_device_list()
	for device in devices:
		if "BlackHole" in device:
			_capture_device = device
			break

	if _capture_device.is_empty():
		push_warning("AudioManager: BlackHole not found in audio devices: %s" % str(devices))
		push_warning("AudioManager: Install BlackHole: brew install blackhole-2ch")
		push_warning("AudioManager: Then create Multi-Output Device in Audio MIDI Setup")
		return

	AudioServer.input_device = _capture_device
	print("AudioManager: Listening on %s" % _capture_device)

	# Create AudioStreamPlayer with mic input on Capture bus
	_player = AudioStreamPlayer.new()
	_player.stream = AudioStreamMicrophone.new()
	_player.bus = "Capture"
	add_child(_player)
	_player.play()

	# Get spectrum analyzer from Capture bus
	var bus_idx := AudioServer.get_bus_index("Capture")
	if bus_idx == -1:
		push_error("AudioManager: Capture bus not found in bus layout")
		return

	# Ensure capture bus is silenced to prevent feedback
	AudioServer.set_bus_volume_db(bus_idx, -80.0)

	_analyzer = AudioServer.get_bus_effect_instance(bus_idx, 0)
	if _analyzer == null:
		push_error("AudioManager: No SpectrumAnalyzer on Capture bus")
		return

	_is_capturing = true

	# Get AudioEffectCapture (effect index 1 on Capture bus)
	_capture_effect = AudioServer.get_bus_effect(bus_idx, 1) as AudioEffectCapture
	if _capture_effect == null:
		push_warning("AudioManager: No AudioEffectCapture on Capture bus (index 1)")
	else:
		print("AudioManager: PCM capture ready (buffer_length=%.1fs)" % _capture_effect.buffer_length)

func _process(_delta: float) -> void:
	if not _is_capturing or _analyzer == null:
		return
	_update_audio_data(_analyzer, audio_data)
	_update_signal_status()

func _update_audio_data(analyzer: AudioEffectSpectrumAnalyzerInstance, data: AudioData) -> void:
	var total_energy: float = 0.0
	var peak_magnitude: float = 0.0
	var peak_freq: float = 0.0

	for band_idx in range(BAND_EDGES.size() - 1):
		var mag_vec: Vector2 = analyzer.get_magnitude_for_frequency_range(
			BAND_EDGES[band_idx], BAND_EDGES[band_idx + 1]
		)
		var raw: float = mag_vec.length()
		var db_normalized: float = clampf((MIN_DB + linear_to_db(raw)) / MIN_DB, 0.0, 1.0)

		# Exponential smoothing: fast attack (0.3), slow decay (0.05)
		var smoothing: float = 0.3 if db_normalized > data.bands[band_idx] else 0.05
		data.bands[band_idx] = lerpf(data.bands[band_idx], db_normalized, smoothing)

		total_energy += data.bands[band_idx]
		if data.bands[band_idx] > peak_magnitude:
			peak_magnitude = data.bands[band_idx]
			peak_freq = (BAND_EDGES[band_idx] + BAND_EDGES[band_idx + 1]) / 2.0

	data.energy = total_energy / (BAND_EDGES.size() - 1)
	data.peak_frequency = peak_freq

	# Compute 4 grouped visual channels from 7 raw bands
	data.grouped[0] = (data.bands[0] + data.bands[1]) / 2.0   # LOW: sub-bass + bass
	data.grouped[1] = (data.bands[2] + data.bands[3]) / 2.0   # MID_LOW: low-mid + mid
	data.grouped[2] = (data.bands[4] + data.bands[5]) / 2.0   # MID_HIGH: upper-mid + presence
	data.grouped[3] = data.bands[6]                             # HIGH: brilliance

func _update_signal_status() -> void:
	if audio_data.energy < NO_SIGNAL_THRESHOLD:
		_silent_frames += 1
		if _silent_frames >= NO_SIGNAL_FRAMES:
			has_signal = false
			audio_data.has_signal = false
	else:
		_silent_frames = 0
		has_signal = true
		audio_data.has_signal = true

## Returns raw PCM samples as interleaved stereo PackedFloat32Array.
## Returns empty array if no capture or no frames available.
## Caller should request num_frames (e.g., 512 for projectM).
func get_pcm_buffer(num_frames: int = 512) -> PackedFloat32Array:
	if _capture_effect == null:
		return PackedFloat32Array()
	var available := _capture_effect.get_frames_available()
	if available < num_frames:
		if available == 0:
			return PackedFloat32Array()
		num_frames = available
	_pcm_buffer = _capture_effect.get_buffer(num_frames)
	# Convert PackedVector2Array (stereo L/R) to interleaved PackedFloat32Array
	var interleaved := PackedFloat32Array()
	interleaved.resize(num_frames * 2)
	for i in range(num_frames):
		interleaved[i * 2] = _pcm_buffer[i].x      # Left channel
		interleaved[i * 2 + 1] = _pcm_buffer[i].y  # Right channel
	return interleaved
