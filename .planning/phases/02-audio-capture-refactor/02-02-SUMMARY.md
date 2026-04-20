---
phase: 02-audio-capture-refactor
plan: 02
subsystem: audio, shaders
tags: [godot, shader-uniforms, fft, blackhole, debug-overlay]

# Dependency graph
requires:
  - phase: 02-audio-capture-refactor plan 01
    provides: Single-source AudioManager with BlackHole capture, AudioData struct with grouped bands
provides:
  - Band-named shader uniforms (5 uniforms replacing 16 stem-based)
  - Test reactive shader consuming new uniform API
  - Single-source debug overlay with signal status and 7-band + 4-channel display
  - Legacy stem loader preserved but disabled
  - Verified end-to-end pipeline: system audio -> FFT -> shader uniforms -> visual output
affects: [phase-03-spectrum-bars, phase-04-milkdrop-warp]

# Tech tracking
tech-stack:
  added: []
  patterns:
    - "Band-named shader uniforms: audio_energy, audio_peak_freq, audio_bands_low (vec4), audio_bands_high (vec4), audio_channels (vec4)"
    - "Single AudioData source pattern: AudioManager.audio_data (not stem_data array)"
    - "Signal status detection: AudioManager.has_signal + _is_capturing for UI feedback"

key-files:
  created: []
  modified:
    - scripts/autoloads/shader_bridge.gd
    - project.godot
    - shaders/test_reactive.gdshader
    - scripts/debug_overlay.gd
    - scripts/_stem_loader_legacy.gd
    - scenes/vr_scene.tscn

key-decisions:
  - "5 band-named uniforms (energy, peak_freq, bands_low vec4, bands_high vec4, channels vec4) replace 16 stem-based uniforms"
  - "Sample rate alignment required: BlackHole must match Multi-Output Device sample rate (44.1kHz) for capture to work"

patterns-established:
  - "Shader uniform naming: audio_ prefix for all global uniforms"
  - "Debug overlay: single Label3D with signal status, raw bands, and grouped channels"

requirements-completed: [AUD-06, AUD-07]

# Metrics
duration: multi-session (checkpoint-gated)
completed: 2026-04-19
---

# Phase 2 Plan 02: Consumer Refactor + End-to-End Verification Summary

**Band-named shader uniforms (5 replacing 16), single-source debug overlay with signal status, and human-verified end-to-end BlackHole audio capture pipeline**

## Performance

- **Duration:** Multi-session (checkpoint-gated verification)
- **Tasks:** 3 (2 auto + 1 human-verify checkpoint)
- **Files modified:** 6

## Accomplishments
- Replaced 16 stem-based shader uniforms with 5 band-named uniforms (audio_energy, audio_peak_freq, audio_bands_low, audio_bands_high, audio_channels)
- Rewrote debug overlay from 4-label stem display to single-source display with signal status, 7 raw bands, and 4 grouped channels
- Retired stem_loader.gd to _stem_loader_legacy.gd (preserved but disconnected from scene)
- Human-verified end-to-end pipeline: desktop audio (any source) -> BlackHole -> Godot capture -> FFT -> shader uniforms -> visible mesh reaction

## Task Commits

Each task was committed atomically:

1. **Task 1: Rewrite ShaderBridge + project.godot shader globals + test shader** - `a50b833` (feat)
2. **Task 2: Rewrite debug overlay and retire stem loader** - `e40c891` (feat)
3. **Task 3: Verify end-to-end audio capture pipeline** - `368bf2b` (fix: cleanup from verification)

## Files Created/Modified
- `scripts/autoloads/shader_bridge.gd` - Rewritten: reads single AudioManager.audio_data, sets 5 band-named uniforms
- `project.godot` - [shader_globals] replaced: 16 stem entries -> 5 band entries
- `shaders/test_reactive.gdshader` - Rewritten: uses audio_energy, audio_bands_low, audio_channels
- `scripts/debug_overlay.gd` - Rewritten: single Label3D, signal status, 7 bands + 4 channels
- `scripts/_stem_loader_legacy.gd` - Renamed from stem_loader.gd (preserved, not wired)
- `scenes/vr_scene.tscn` - Removed StemLoader node reference

## Decisions Made
- 5 band-named uniforms chosen over alternatives: provides complete frequency data (7 bands via two vec4s + 4 grouped channels) while being simple for shader authors
- Sample rate alignment is a user-side requirement: BlackHole must be set to 44.1kHz in Audio MIDI Setup to match Multi-Output Device (discovered during verification)

## Deviations from Plan

### Auto-fixed Issues

**1. [Rule 1 - Bug] AudioStreamPlayer reference stored for diagnostics**
- **Found during:** Task 3 (verification session)
- **Issue:** AudioStreamPlayer was a local variable, making diagnostics difficult during debugging
- **Fix:** Stored as `_player` class variable on AudioManager
- **Files modified:** scripts/autoloads/audio_manager.gd
- **Committed in:** 368bf2b

**2. [Rule 1 - Bug] Debug overlay text spacing**
- **Found during:** Task 3 (verification session)
- **Issue:** Extra blank line in energy display made overlay less readable
- **Fix:** Adjusted newline placement
- **Files modified:** scripts/debug_overlay.gd
- **Committed in:** 368bf2b

---

**Total deviations:** 2 auto-fixed (2 bugs)
**Impact on plan:** Minor fixes discovered during live verification. No scope creep.

## Issues Encountered
- BlackHole sample rate mismatch: BlackHole defaulted to 48kHz while Multi-Output Device was at 44.1kHz, causing silence. Resolved by user changing BlackHole to 44.1kHz in Audio MIDI Setup. This is a one-time setup requirement, not a code issue.

## User Setup Required
None beyond initial BlackHole configuration (already documented in Phase 2 context).

## Next Phase Readiness
- Full audio pipeline verified: any desktop audio -> shader uniforms in one frame
- 5 band-named uniforms ready for Phase 3 spectrum bars (audio_bands_low, audio_bands_high for per-bar heights; audio_channels for color grouping)
- ModeManager (Phase 3) can build on this foundation without audio changes
- No blockers for Phase 3

---
*Phase: 02-audio-capture-refactor*
*Completed: 2026-04-19*
