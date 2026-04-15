extends Node3D

var _labels: Array[Label3D] = []
const STEM_NAMES: PackedStringArray = ["Drums", "Bass", "Vocals", "Other"]
const STEM_COLORS: Array[Color] = [
	Color(1.0, 0.3, 0.3),  # Drums: red
	Color(0.3, 0.3, 1.0),  # Bass: blue
	Color(0.3, 1.0, 0.3),  # Vocals: green
	Color(1.0, 1.0, 0.3),  # Other: yellow
]

func _ready() -> void:
	for i in range(4):
		var label := Label3D.new()
		label.position = Vector3(-1.5 + i * 1.0, 2.5, -3.0)
		label.font_size = 24
		label.modulate = STEM_COLORS[i]
		label.billboard = BaseMaterial3D.BILLBOARD_ENABLED
		label.no_depth_test = true
		label.outline_size = 8
		add_child(label)
		_labels.append(label)

func _process(_delta: float) -> void:
	var data: Array[AudioData] = AudioManager.stem_data
	for i in range(min(data.size(), _labels.size())):
		_labels[i].text = "%s\nE: %.2f\nPk: %.0f Hz\n%s" % [
			STEM_NAMES[i],
			data[i].energy,
			data[i].peak_frequency,
			_format_bands(data[i].bands)
		]

func _format_bands(bands: Array[float]) -> String:
	var result: String = ""
	for b in bands:
		var filled: int = int(b * 5)
		result += "|" + "#".repeat(filled) + ".".repeat(5 - filled) + "|\n"
	return result
