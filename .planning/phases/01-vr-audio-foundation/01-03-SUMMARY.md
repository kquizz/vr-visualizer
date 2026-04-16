---
phase: 01-vr-audio-foundation
plan: 03
subsystem: audio, shaders, vr
tags: [godot, gdshader, fft, global-uniforms, openxr, audio-visualization]

# Dependency graph
requires:
  - phase: 01-vr-audio-foundation (plan 01)
    provides: "Godot project with VR scene, OpenXR, shader_globals declarations in project.godot"
  - phase: 01-vr-audio-foundation (plan 02)
    provides: "AudioManager autoload with FFT analysis, AudioData struct, 4-bus audio layout"
provides:
  - "ShaderBridge autoload pushing 16 global shader uniforms per frame (4 per stem: energy, peak_freq, bands_low, bands_high)"
  - "Test reactive shader proving audio-to-visual pipeline works"
  - "Debug overlay showing per-stem FFT values in-scene"
  - "StemLoader that auto-plays WAV stems from audio/stems/"
  - "End-to-end verified pipeline: stems -> FFT -> uniforms -> shader reaction"
affects: [02-stem-visualization]

# Tech tracking
tech-stack:
  added: []
  patterns:
    - "Global shader uniforms declared in project.godot [shader_globals], set at runtime via RenderingServer.global_shader_parameter_set()"
    - "Label3D with billboard mode for in-scene debug text (works in both VR and flat-screen)"
    - "macOS flat-screen fallback: skip OpenXR initialization, use FallbackCamera3D"

key-files:
  created:
    - scripts/autoloads/shader_bridge.gd
    - shaders/test_reactive.gdshader
    - scripts/debug_overlay.gd
    - scripts/stem_loader.gd
  modified:
    - scenes/vr_scene.tscn
    - scenes/main.tscn
    - scripts/main.gd

key-decisions:
  - "WAV stems instead of Opus OGG: Godot 4.6 imports WAV natively without codec issues"
  - "macOS flat-screen mode: skip OpenXR init entirely on non-VR platforms for reliable testing"
  - "ext_resource ordering in .tscn: Godot requires ascending ID order or scene fails to parse"

patterns-established:
  - "ShaderBridge pattern: autoload reads AudioManager.stem_data every _process frame and pushes to global shader uniforms"
  - "Global uniform naming: {stem_prefix}_{data_type} (e.g., drums_energy, bass_bands_low)"
  - "Debug overlay pattern: Label3D billboard nodes for in-scene telemetry"

requirements-completed: [INF-02, VR-02]

# Metrics
duration: ~15min
completed: 2026-04-15
---

# Phase 1 Plan 3: Audio-to-Shader Pipeline Summary

**ShaderBridge pushing 16 global uniforms per frame from FFT data, verified end-to-end with test reactive shader and debug overlay**

## Performance

- **Duration:** ~15 min
- **Tasks:** 3 (2 auto + 1 human-verify checkpoint)
- **Files modified:** 7

## Accomplishments
- ShaderBridge autoload pushes 16 global shader uniforms per frame (4 per stem: energy, peak_freq, bands_low, bands_high)
- Test reactive shader visibly changes color (R=drums, G=bass, B=vocals) and pulses in size with audio energy
- Debug overlay shows per-stem energy, peak frequency, and 7-band ASCII bar graphs via Label3D billboards
- StemLoader auto-plays WAV stems from audio/stems/ with graceful degradation when missing
- User verified end-to-end: heard song, saw colorful sphere reacting to audio, saw debug overlay outputs

## Task Commits

Each task was committed atomically:

1. **Task 1: Implement ShaderBridge, test shader, and debug overlay** - `a61ed3c` (feat)
2. **Task 2: Wire test mesh, debug overlay, and stem loader into VR scene** - `7ba762f` (feat)
3. **Task 3: Verify end-to-end audio-visual pipeline** - `a249e94` (fix -- verification fixes applied)

## Files Created/Modified
- `scripts/autoloads/shader_bridge.gd` - Autoload pushing AudioManager.stem_data as 16 global shader uniforms per frame
- `shaders/test_reactive.gdshader` - Spatial shader consuming global audio uniforms for color and vertex scaling
- `scripts/debug_overlay.gd` - Label3D billboard overlay showing per-stem FFT values
- `scripts/stem_loader.gd` - Auto-loads and plays WAV stems from audio/stems/ on scene ready
- `scenes/vr_scene.tscn` - Added TestReactiveMesh, DebugOverlay, and StemLoader nodes
- `scenes/main.tscn` - Updated main scene references
- `scripts/main.gd` - macOS flat-screen mode fix (skip OpenXR)

## Decisions Made
- Used WAV stems instead of Opus OGG -- Godot 4.6 imports WAV natively without codec configuration
- macOS flat-screen mode skips OpenXR initialization entirely for reliable desktop testing
- Fixed ext_resource ordering in .tscn files (Godot requires ascending ID order)
- Reduced skybox brightness for better contrast with glowing shader mesh

## Deviations from Plan

### Auto-fixed Issues

**1. [Rule 3 - Blocking] macOS flat-screen mode -- skip OpenXR**
- **Found during:** Task 3 (verification)
- **Issue:** OpenXR initialization failed on macOS, preventing scene launch
- **Fix:** Modified main.gd to skip XR initialization on non-VR platforms, use FallbackCamera3D
- **Files modified:** scripts/main.gd
- **Committed in:** a249e94

**2. [Rule 3 - Blocking] Scene file ext_resource ordering**
- **Found during:** Task 3 (verification)
- **Issue:** Godot refused to parse vr_scene.tscn due to non-ascending ext_resource IDs
- **Fix:** Reordered ext_resource declarations to ascending ID order
- **Files modified:** scenes/vr_scene.tscn
- **Committed in:** a249e94

**3. [Rule 3 - Blocking] WAV stems instead of OGG Opus**
- **Found during:** Task 3 (verification)
- **Issue:** Godot 4.6 had issues importing Opus OGG stems
- **Fix:** Changed stem_loader.gd to use WAV format; user provided WAV stems from demucs
- **Files modified:** scripts/stem_loader.gd
- **Committed in:** a249e94

**4. [Rule 1 - Bug] Skybox brightness too high**
- **Found during:** Task 3 (verification)
- **Issue:** Bright skybox washed out the glowing test shader mesh
- **Fix:** Reduced ProceduralSkyMaterial brightness for better contrast
- **Files modified:** scenes/vr_scene.tscn
- **Committed in:** a249e94

---

**Total deviations:** 4 auto-fixed (3 blocking, 1 bug)
**Impact on plan:** All fixes necessary for the verification to succeed. No scope creep.

## Issues Encountered
- All issues discovered and fixed during Task 3 verification checkpoint (see deviations above)

## User Setup Required
None - no external service configuration required.

## Next Phase Readiness
- Phase 1 complete: VR scene, audio pipeline, FFT analysis, shader uniforms, and end-to-end verification all working
- Ready for Phase 2 (Stem Visualization): ShaderBridge pattern established, global uniform naming convention set, AudioData struct stable
- Phase 1.1 (Validate Rekordbox Stem Extraction) can proceed independently

## Self-Check: PASSED

All 4 created files verified on disk. All 3 task commits verified in git log.

---
*Phase: 01-vr-audio-foundation*
*Completed: 2026-04-15*
