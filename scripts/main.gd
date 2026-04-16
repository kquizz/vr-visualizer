extends Node3D

var xr_interface: XRInterface
var xr_active: bool = false

func _ready():
	# macOS has no real PCVR support — Meta XR Simulator intercepts OpenXR
	# but can't actually render. Skip XR entirely on macOS.
	if OS.get_name() == "macOS":
		print("macOS detected - forcing flat screen preview mode")
		_enable_flat_screen()
		return

	xr_interface = XRServer.find_interface("OpenXR")
	if xr_interface and xr_interface.initialize():
		print("OpenXR initialized - VR mode active")
		DisplayServer.window_set_vsync_mode(DisplayServer.VSYNC_DISABLED)
		get_viewport().use_xr = true
		xr_active = true
	else:
		print("No XR runtime - flat screen preview mode")
		_enable_flat_screen()

func _enable_flat_screen():
	get_viewport().use_xr = false
	$VRScene/FallbackCamera3D.current = true
	print("Flat screen camera active")
