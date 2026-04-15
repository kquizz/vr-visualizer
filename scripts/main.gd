extends Node3D

var xr_interface: XRInterface
var xr_active: bool = false

func _ready():
	xr_interface = XRServer.find_interface("OpenXR")
	if xr_interface and xr_interface.is_initialized():
		print("OpenXR initialized - VR mode active")
		DisplayServer.window_set_vsync_mode(DisplayServer.VSYNC_DISABLED)
		get_viewport().use_xr = true
		xr_active = true
	else:
		print("No XR runtime - flat screen preview mode")
		$VRScene/FallbackCamera3D.current = true
