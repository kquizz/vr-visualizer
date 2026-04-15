extends Camera3D

var mouse_sensitivity := 0.002
var pitch := 0.0
var yaw := 0.0

func _ready():
	if current:
		Input.mouse_mode = Input.MOUSE_MODE_CAPTURED

func _unhandled_input(event: InputEvent):
	if not current:
		return
	if event is InputEventMouseMotion:
		yaw -= event.relative.x * mouse_sensitivity
		pitch -= event.relative.y * mouse_sensitivity
		pitch = clamp(pitch, -PI/2, PI/2)
		transform.basis = Basis()
		rotate_y(yaw)
		rotate_object_local(Vector3.RIGHT, pitch)
	if event is InputEventKey and event.pressed and event.keycode == KEY_ESCAPE:
		Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
