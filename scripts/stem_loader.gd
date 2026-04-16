extends Node

## Paths to test stem files (OGG format)
@export var drums_path: String = "res://audio/stems/test_drums.wav"
@export var bass_path: String = "res://audio/stems/test_bass.wav"
@export var vocals_path: String = "res://audio/stems/test_vocals.wav"
@export var other_path: String = "res://audio/stems/test_other.wav"

func _ready() -> void:
	# Wait one frame for AudioManager to initialize
	await get_tree().process_frame
	await get_tree().process_frame

	# Check if stem files exist before playing
	if not FileAccess.file_exists(drums_path):
		push_warning("StemLoader: No test stems found at %s. Place OGG stems in audio/stems/ to hear audio." % drums_path)
		print("StemLoader: To prepare test stems, run:")
		print("  demucs -n htdemucs your_track.mp3")
		print("  ffmpeg -i separated/htdemucs/your_track/drums.wav -c:a libvorbis -q:a 5 audio/stems/test_drums.wav")
		return

	AudioManager.play_stems(drums_path, bass_path, vocals_path, other_path)
	print("StemLoader: Playing test stems")
