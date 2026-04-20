class_name AudioData
extends RefCounted

## Overall energy level (0.0 - 1.0), average of all bands
var energy: float = 0.0
## Frequency of the loudest band (Hz)
var peak_frequency: float = 0.0
## Per-band magnitudes (0.0 - 1.0), 7 bands:
## [sub-bass 20-60Hz, bass 60-250Hz, low-mid 250-500Hz, mid 500-2000Hz,
##  upper-mid 2000-4000Hz, presence 4000-6000Hz, brilliance 6000-11050Hz]
var bands: Array[float] = [0.0, 0.0, 0.0, 0.0, 0.0, 0.0, 0.0]
## Grouped visual channels (0.0 - 1.0), 4 groups:
## [LOW (sub-bass+bass), MID_LOW (low-mid+mid), MID_HIGH (upper-mid+presence), HIGH (brilliance)]
var grouped: Array[float] = [0.0, 0.0, 0.0, 0.0]
## Whether non-zero audio signal is being received
var has_signal: bool = false
