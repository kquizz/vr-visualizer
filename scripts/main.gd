extends Node3D

var xr_interface: XRInterface
var xr_active: bool = false

func _ready():
	# macOS has no real PCVR support — Meta XR Simulator intercepts OpenXR
	# but can't actually render. Skip XR entirely on macOS.
	if OS.get_name() == "macOS":
		print("macOS detected - forcing flat screen preview mode")
		_enable_flat_screen()
	else:
		xr_interface = XRServer.find_interface("OpenXR")
		if xr_interface and xr_interface.initialize():
			print("OpenXR initialized - VR mode active")
			DisplayServer.window_set_vsync_mode(DisplayServer.VSYNC_DISABLED)
			get_viewport().use_xr = true
			xr_active = true
		else:
			print("No XR runtime - flat screen preview mode")
			_enable_flat_screen()

	# Set up ModeManager after XR/flat-screen init, deferred so scene tree is ready
	call_deferred("_setup_mode_manager")

func _enable_flat_screen():
	get_viewport().use_xr = false
	$VRScene/FallbackCamera3D.current = true
	print("Flat screen camera active")

func _input(event: InputEvent) -> void:
	if event is InputEventKey and event.pressed and not event.echo:
		if event.keycode == KEY_TAB:
			_toggle_mode()

func _toggle_mode() -> void:
	var current = ModeManager.get_active_mode_name()
	var modes = ModeManager.get_mode_names()
	if modes.size() < 2:
		return
	var idx = modes.find(current)
	var next_idx = (idx + 1) % modes.size()
	ModeManager.switch_to(modes[next_idx])
	print("Toggled to mode: %s" % modes[next_idx])

func _setup_mode_manager() -> void:
	var container := $VRScene/ModeContainer
	ModeManager.set_container(container)
	ModeManager.switch_to("spectrum_bars")
	print("Press TAB to toggle between modes")
