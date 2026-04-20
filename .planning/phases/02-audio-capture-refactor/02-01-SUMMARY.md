---
phase: 02-audio-capture-refactor
plan: 01
subsystem: audio
tags: [godot, blackhole, fft, audio-capture, gdscript]

requires:
  - phase: 01-vr-audio-foundation
    provides: AudioData class, AudioManager autoload, bus layout pattern
provides:
  - Single Capture bus with SpectrumAnalyzer at -80dB
  - AudioData with 7 raw bands + 4 grouped channels + signal detection
  - AudioManager with BlackHole auto-detection and single-source FFT
  - Audio input enabled in project.godot
affects: [02-audio-capture-refactor plan 02, shader-bridge, debug-overlay]

tech-stack:
  added: [AudioStreamMicrophone, BlackHole virtual audio device]
  patterns: [single-source capture, grouped channel computation, signal detection]

key-files:
  created: []
  modified:
    - default_bus_layout.tres
    - scripts/audio_data.gd
    - scripts/autoloads/audio_manager.gd
    - project.godot

key-decisions:
  - "Capture bus at -80dB with runtime safety check prevents audio feedback"
  - "30-frame silence threshold (~0.5s) for signal detection avoids flicker"
  - "4 grouped channels from 7 bands: LOW (sub-bass+bass), MID_LOW (low-mid+mid), MID_HIGH (upper-mid+presence), HIGH (brilliance)"

patterns-established:
  - "BlackHole auto-detection: substring match on device list with graceful degradation"
  - "Single AudioData instance replaces per-stem array (audio_data vs stem_data[])"

requirements-completed: [AUD-04, AUD-05]

duration: 1min
completed: 2026-04-20
---

# Phase 2 Plan 01: Audio Capture Pipeline Summary

**BlackHole single-source capture with 7-band FFT, 4 grouped visual channels, and signal detection replacing 4-stem bus layout**

## Performance

- **Duration:** 1 min
- **Started:** 2026-04-20T02:25:53Z
- **Completed:** 2026-04-20T02:27:17Z
- **Tasks:** 2
- **Files modified:** 4

## Accomplishments
- Replaced 4-stem bus layout (Drums/Bass/Vocals/Other) with single Capture bus at -80dB
- Extended AudioData with 4 grouped visual channels and signal detection flag
- Rewrote AudioManager for BlackHole auto-detection with graceful degradation
- Enabled audio input in project.godot for AudioStreamMicrophone capture

## Task Commits

Each task was committed atomically:

1. **Task 1: Replace bus layout and update AudioData struct** - `c475347` (feat)
2. **Task 2: Rewrite AudioManager for BlackHole single-source capture** - `a28f09b` (feat)

## Files Created/Modified
- `default_bus_layout.tres` - Single Capture bus with SpectrumAnalyzer, -80dB volume
- `scripts/audio_data.gd` - Added grouped[4] channels and has_signal flag
- `scripts/autoloads/audio_manager.gd` - Complete rewrite: BlackHole capture, single AudioData, signal detection
- `project.godot` - Added [audio] section with driver/enable_input=true

## Decisions Made
None - followed plan as specified

## Deviations from Plan

None - plan executed exactly as written.

## Issues Encountered
- Godot CLI not available in PATH for headless parse verification -- skipped (syntax verified by inspection)

## User Setup Required
None - no external service configuration required. BlackHole must be pre-installed (detected at runtime with graceful warning if missing).

## Next Phase Readiness
- AudioManager.audio_data is ready for ShaderBridge and debug overlay consumption (Plan 02)
- ShaderBridge and debug_overlay.gd will break until updated to use audio_data instead of stem_data[] -- this is expected and addressed in Plan 02
- BlackHole installation and Multi-Output Device configuration is a prerequisite for runtime testing

---
*Phase: 02-audio-capture-refactor*
*Completed: 2026-04-20*
