---
phase: 05-milkdrop-rendering-engine-with-preset-loader
plan: 02
subsystem: audio, rendering
tags: [projectm, milkdrop, pcm-capture, gdextension, vr-dome]

requires:
  - phase: 05-01
    provides: ProjectMWrapper GDExtension with feed_audio/render_frame/get_texture API
provides:
  - AudioManager.get_pcm_buffer() for raw PCM extraction from capture bus
  - Milkdrop mode scene with projectM rendering on inverted sphere dome
  - Milkdrop display shader for dome texture rendering
affects: [05-03, mode-manager-registration, preset-management]

tech-stack:
  added: [AudioEffectCapture]
  patterns: [PCM interleaved stereo extraction, projectM frame loop, dome texture display]

key-files:
  created:
    - scenes/modes/milkdrop.gd
    - scenes/modes/milkdrop.tscn
    - shaders/milkdrop_display.gdshader
  modified:
    - scripts/autoloads/audio_manager.gd
    - default_bus_layout.tres

key-decisions:
  - "AudioEffectCapture coexists with SpectrumAnalyzer on same Capture bus (effect index 1)"
  - "PCM buffer defaults to 512 frames (projectM typical expectation)"
  - "projectM renders at 1024x1024 (can increase to 2048 if perf allows)"

patterns-established:
  - "PCM extraction: AudioEffectCapture.get_buffer() -> PackedVector2Array -> interleaved PackedFloat32Array"
  - "Milkdrop mode: ProjectMWrapper as child Node, feed_audio/render_frame/get_texture per frame"

requirements-completed: [VIS-03, VIS-04, INF-04]

duration: 2min
completed: 2026-04-20
---

# Phase 5 Plan 02: Milkdrop Mode Scene Summary

**PCM audio capture pipeline and milkdrop mode scene rendering projectM output on VR dome via GDExtension**

## Performance

- **Duration:** 2 min
- **Started:** 2026-04-20T15:37:40Z
- **Completed:** 2026-04-20T15:39:44Z
- **Tasks:** 2
- **Files modified:** 5

## Accomplishments
- AudioManager now exposes get_pcm_buffer() for raw interleaved stereo PCM extraction alongside existing FFT pipeline
- Milkdrop mode scene integrates ProjectMWrapper GDExtension: feeds audio, renders frames, displays on dome
- Display shader and inverted sphere dome follow established Phase 4 warp mode patterns

## Task Commits

Each task was committed atomically:

1. **Task 1: Add AudioEffectCapture to Capture bus for raw PCM extraction** - `0a79f22` (feat)
2. **Task 2: Create milkdrop mode scene with ProjectMWrapper, dome display, and audio feed** - `d51d368` (feat)

## Files Created/Modified
- `scripts/autoloads/audio_manager.gd` - Added _capture_effect, _pcm_buffer vars and get_pcm_buffer() method
- `default_bus_layout.tres` - Added AudioEffectCapture as effect index 1 on Capture bus
- `scenes/modes/milkdrop.gd` - Milkdrop mode script with ProjectMWrapper lifecycle and audio feed
- `scenes/modes/milkdrop.tscn` - Scene with MilkdropDome (inverted sphere, shader material)
- `shaders/milkdrop_display.gdshader` - Unshaded dome display shader with milkdrop_texture uniform

## Decisions Made
- AudioEffectCapture added at effect index 1 on Capture bus, coexisting with SpectrumAnalyzer at index 0 -- both work simultaneously
- PCM buffer size defaults to 512 frames per call, matching projectM's typical expectation
- projectM renders at 1024x1024 resolution (configurable constant, can increase to 2048 if performance allows)
- No manual bass/mid/treb mapping needed -- projectM performs its own internal FFT from raw PCM

## Deviations from Plan

None - plan executed exactly as written.

## Issues Encountered
None

## User Setup Required
None - no external service configuration required.

## Next Phase Readiness
- Milkdrop mode scene ready for registration in ModeManager (Plan 03)
- Preset loading infrastructure in place (auto-loads first .milk from res://presets/)
- Audio pipeline complete: BlackHole capture -> AudioEffectCapture -> PCM -> projectM

## Self-Check: PASSED

All 5 files verified present. Both task commits (0a79f22, d51d368) confirmed in git log.

---
*Phase: 05-milkdrop-rendering-engine-with-preset-loader*
*Completed: 2026-04-20*
