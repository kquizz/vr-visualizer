---
phase: 05-milkdrop-rendering-engine-with-preset-loader
plan: 01
subsystem: rendering
tags: [gdextension, projectm, milkdrop, cpp, godot-cpp, opengl]

# Dependency graph
requires:
  - phase: 04-milkdrop-warp-mode
    provides: inverted sphere dome and mode system for displaying projectM output
provides:
  - ProjectMWrapper GDExtension class exposing init/preset/audio/render to GDScript
  - Compiled arm64 dylib at addons/projectm/bin/
  - Build system (SConstruct) for GDExtension compilation
affects: [05-02, 05-03, milkdrop-integration, audio-pipeline]

# Tech tracking
tech-stack:
  added: [projectM 3.1.12, godot-cpp 4.4, scons, OpenGL]
  patterns: [GDExtension C++ wrapper, projectM v3 C++ API, GL texture readback]

key-files:
  created:
    - addons/projectm/SConstruct
    - addons/projectm/src/projectm_wrapper.h
    - addons/projectm/src/projectm_wrapper.cpp
    - addons/projectm/src/register_types.h
    - addons/projectm/src/register_types.cpp
    - addons/projectm/projectm.gdextension
    - addons/projectm/bin/libprojectm_gdext.macos.template_debug.arm64.dylib
  modified: []

key-decisions:
  - "Used projectM v3 C++ API instead of v4 C API (Homebrew ships v3.1.12)"
  - "Build restricted to arm64 only (Homebrew projectM is arm64-only)"
  - "GL texture readback via glGetTexImage for texture transfer to Godot"
  - ".gdextension references .dylib not .framework (matches SCons output)"

patterns-established:
  - "GDExtension wrapper pattern: thin C++ class extending Node, _bind_methods for GDScript exposure"
  - "projectM v3 preset loading: addPresetURL + selectPreset (playlist-based)"
  - "Audio feeding: PCM::addPCMfloat_2ch for stereo, addPCMfloat for mono"

requirements-completed: [VIS-03]

# Metrics
duration: 6min
completed: 2026-04-20
---

# Phase 5 Plan 01: projectM GDExtension Wrapper Summary

**Thin C++ GDExtension wrapping projectM v3 for MilkDrop rendering, exposing init/preset/audio/render/texture to GDScript**

## Performance

- **Duration:** 6 min
- **Started:** 2026-04-20T15:29:30Z
- **Completed:** 2026-04-20T15:35:29Z
- **Tasks:** 2
- **Files modified:** 7

## Accomplishments
- GDExtension scaffold with godot-cpp 4.4 bindings and SCons build system
- ProjectMWrapper C++ class with 9 bound methods callable from GDScript
- Successful arm64 compilation on macOS linking projectM 3.1.12 and OpenGL

## Task Commits

Each task was committed atomically:

1. **Task 1: Scaffold GDExtension project** - `93a26a7` (feat)
2. **Task 2: Implement ProjectMWrapper C++ class** - `93a6f6d` (feat)

## Files Created/Modified
- `addons/projectm/SConstruct` - SCons build file linking projectM + OpenGL
- `addons/projectm/src/projectm_wrapper.h` - C++ wrapper class declaration
- `addons/projectm/src/projectm_wrapper.cpp` - Full implementation with projectM v3 API
- `addons/projectm/src/register_types.h` - GDExtension registration header
- `addons/projectm/src/register_types.cpp` - GDExtension entry point and class registration
- `addons/projectm/projectm.gdextension` - Godot extension descriptor
- `addons/projectm/bin/libprojectm_gdext.macos.template_debug.arm64.dylib` - Compiled binary

## Decisions Made
- Used projectM v3 C++ API instead of planned v4 C API -- Homebrew only ships v3.1.12; v4 would require building from source
- Build restricted to arm64 architecture -- Homebrew projectM is arm64-only, universal build fails at x86_64 link stage
- Texture readback via glGetTexImage -- simplest approach for getting projectM's GL texture into Godot's ImageTexture
- .gdextension references .dylib files instead of .framework -- matches actual SCons SharedLibrary output format

## Deviations from Plan

### Auto-fixed Issues

**1. [Rule 3 - Blocking] Adapted from projectM v4 C API to v3 C++ API**
- **Found during:** Task 2 (ProjectMWrapper implementation)
- **Issue:** Plan assumed projectM v4 with C API (projectm_create, projectm_pcm_add_float, etc.) but Homebrew ships v3.1.12 with C++ API only
- **Fix:** Rewrote all API calls to use v3 C++ API (projectM constructor, PCM::addPCMfloat, renderFrame, etc.)
- **Files modified:** addons/projectm/src/projectm_wrapper.cpp, addons/projectm/SConstruct
- **Verification:** Build succeeds, all planned methods exposed
- **Committed in:** 93a6f6d (Task 2 commit)

**2. [Rule 3 - Blocking] Fixed exceptions-disabled build error**
- **Found during:** Task 2 (build attempt)
- **Issue:** godot-cpp builds with -fno-exceptions, try/catch is invalid
- **Fix:** Removed try/catch block around projectM constructor, using null check instead
- **Files modified:** addons/projectm/src/projectm_wrapper.cpp
- **Verification:** Build succeeds
- **Committed in:** 93a6f6d (Task 2 commit)

**3. [Rule 3 - Blocking] Fixed OpenGL framework linking**
- **Found during:** Task 2 (build attempt)
- **Issue:** env.Append(FRAMEWORKS=["OpenGL"]) not supported by godot-cpp's SCons env
- **Fix:** Used env.Append(LINKFLAGS=["-framework", "OpenGL"]) instead
- **Files modified:** addons/projectm/SConstruct
- **Verification:** Build succeeds, GL symbols resolved
- **Committed in:** 93a6f6d (Task 2 commit)

**4. [Rule 3 - Blocking] Restricted to arm64 architecture**
- **Found during:** Task 2 (build attempt)
- **Issue:** Universal build failed linking x86_64 against arm64-only Homebrew projectM
- **Fix:** Build with arch=arm64, updated .gdextension paths to match
- **Files modified:** addons/projectm/projectm.gdextension
- **Verification:** Build succeeds on arm64
- **Committed in:** 93a6f6d (Task 2 commit)

---

**Total deviations:** 4 auto-fixed (4 blocking)
**Impact on plan:** All auto-fixes necessary for build to succeed with available projectM version. API surface identical to plan. No scope creep.

## Issues Encountered
- scons not installed -- installed via Homebrew (brew install scons)
- projectM Homebrew formula is v3.1.12, not v4 -- adapted wrapper accordingly

## User Setup Required
None - no external service configuration required.

## Next Phase Readiness
- GDExtension compiles and produces loadable dylib
- ProjectMWrapper class ready for GDScript integration
- Next: PCM audio capture from AudioManager and scene integration (05-02)
- Note: projectM requires an active OpenGL context at init time -- Godot's Mobile renderer may need consideration

## Self-Check: PASSED

All 7 created files verified on disk. Both task commits (93a26a7, 93a6f6d) verified in git log.

---
*Phase: 05-milkdrop-rendering-engine-with-preset-loader*
*Completed: 2026-04-20*
