extends Node3D

const BAND_NAMES: PackedStringArray = [
	"Sub-Bass", "Bass", "Lo-Mid", "Mid", "Up-Mid", "Presence", "Brilliance"
]
const GROUP_NAMES: PackedStringArray = ["LOW", "MID_LOW", "MID_HIGH", "HIGH"]

var _label: Label3D

func _ready() -> void:
	_label = Label3D.new()
	_label.position = Vector3(0.0, 2.5, -3.0)
	_label.font_size = 22
	_label.modulate = Color(0.9, 0.9, 1.0)
	_label.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	_label.no_depth_test = true
	_label.outline_size = 8
	add_child(_label)

func _process(_delta: float) -> void:
	var data: AudioData = AudioManager.audio_data
	if data == null:
		_label.text = "AudioManager: initializing..."
		return

	var status: String
	if not AudioManager._is_capturing:
		status = "BlackHole not detected"
	elif AudioManager.has_signal:
		status = "Listening on %s" % AudioManager._capture_device
	else:
		status = "No signal detected"

	var text: String = "=== Audio Capture ===\n"
	text += "Status: %s\n" % status
	text += "Energy: %.3f\n" % data.energy

	text += "\n"

	# 7 raw bands
	text += "--- Raw Bands ---\n"
	for i in range(data.bands.size()):
		var filled: int = int(data.bands[i] * 10)
		var bar: String = "#".repeat(filled) + ".".repeat(10 - filled)
		text += "%s %s|%s| %.2f\n" % [BAND_NAMES[i].substr(0, 6).rpad(6), "", bar, data.bands[i]]

	# 4 grouped channels
	text += "\n--- Channels ---\n"
	for i in range(data.grouped.size()):
		var filled: int = int(data.grouped[i] * 10)
		var bar: String = "#".repeat(filled) + ".".repeat(10 - filled)
		text += "%s %s|%s| %.2f\n" % [GROUP_NAMES[i].rpad(8), "", bar, data.grouped[i]]

	text += "\nPeak: %.0f Hz" % data.peak_frequency

	_label.text = text
