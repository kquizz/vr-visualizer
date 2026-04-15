extends Node

## Stem names for lookup
const STEM_NAMES: PackedStringArray = ["Drums", "Bass", "Vocals", "Other"]

## Frequency band boundaries (Hz) - 7 musically meaningful bands
const BAND_EDGES: Array[float] = [20.0, 60.0, 250.0, 500.0, 2000.0, 4000.0, 6000.0, 11050.0]

## dB normalization floor
const MIN_DB: float = 60.0

## Sync drift threshold in milliseconds
const MAX_DRIFT_MS: float = 10.0
## How often to check sync (seconds)
const SYNC_CHECK_INTERVAL: float = 1.0

## Spectrum analyzer instances (one per stem bus)
var _analyzers: Array[AudioEffectSpectrumAnalyzerInstance] = []

## AudioStreamPlayer nodes (one per stem)
var _players: Array[AudioStreamPlayer] = []

## Per-stem audio data, updated every frame. Public API.
var stem_data: Array[AudioData] = []

## Internal sync timer
var _sync_timer: float = 0.0

## Whether stems are currently playing
var is_playing: bool = false

func _ready() -> void:
	# Defer initialization to ensure AudioServer is fully ready
	# (Pitfall 5: get_bus_effect_instance can return null if called too early)
	call_deferred("_initialize")

func _initialize() -> void:
	for i in range(STEM_NAMES.size()):
		# Create AudioStreamPlayer for each stem
		var player := AudioStreamPlayer.new()
		player.bus = STEM_NAMES[i]
		add_child(player)
		_players.append(player)

		# Get spectrum analyzer instance from bus
		# Effect index 0 = SpectrumAnalyzer on each stem bus
		var bus_idx := AudioServer.get_bus_index(STEM_NAMES[i])
		if bus_idx == -1:
			push_error("AudioManager: Bus '%s' not found! Check default_bus_layout.tres" % STEM_NAMES[i])
			continue
		var analyzer = AudioServer.get_bus_effect_instance(bus_idx, 0)
		if analyzer == null:
			push_error("AudioManager: No spectrum analyzer on bus '%s'! Check default_bus_layout.tres" % STEM_NAMES[i])
		_analyzers.append(analyzer)

		# Create AudioData for each stem
		stem_data.append(AudioData.new())

func _process(delta: float) -> void:
	# Update FFT data for all stems
	for i in range(_analyzers.size()):
		if _analyzers[i] != null:
			_update_stem_data(_analyzers[i], stem_data[i])

	# Check stem synchronization
	if is_playing:
		_sync_timer += delta
		if _sync_timer >= SYNC_CHECK_INTERVAL:
			_sync_timer = 0.0
			_check_sync()

func _update_stem_data(analyzer: AudioEffectSpectrumAnalyzerInstance, data: AudioData) -> void:
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
		# This prevents FFT jitter (Pitfall 5) while keeping responsiveness
		var smoothing: float = 0.3 if db_normalized > data.bands[band_idx] else 0.05
		data.bands[band_idx] = lerpf(data.bands[band_idx], db_normalized, smoothing)

		total_energy += data.bands[band_idx]
		if data.bands[band_idx] > peak_magnitude:
			peak_magnitude = data.bands[band_idx]
			peak_freq = (BAND_EDGES[band_idx] + BAND_EDGES[band_idx + 1]) / 2.0

	data.energy = total_energy / (BAND_EDGES.size() - 1)
	data.peak_frequency = peak_freq

## Play 4 stem audio files simultaneously.
## Pass resource paths like "res://audio/stems/test_drums.ogg"
func play_stems(drums_path: String, bass_path: String, vocals_path: String, other_path: String) -> void:
	var paths: Array[String] = [drums_path, bass_path, vocals_path, other_path]
	for i in range(4):
		_players[i].stream = load(paths[i])

	# Start all on same frame for tight sync
	for player in _players:
		player.play()
	is_playing = true
	_sync_timer = 0.0

## Stop all stem playback.
func stop_stems() -> void:
	for player in _players:
		player.stop()
	is_playing = false

func _check_sync() -> void:
	if _players.size() < 2:
		return
	var ref_pos: float = _players[0].get_playback_position()
	for i in range(1, _players.size()):
		if not _players[i].playing:
			continue
		var drift_ms: float = absf(_players[i].get_playback_position() - ref_pos) * 1000.0
		if drift_ms > MAX_DRIFT_MS:
			_players[i].seek(ref_pos)
			print("AudioManager: Resynced %s (drift: %.1fms)" % [STEM_NAMES[i], drift_ms])
