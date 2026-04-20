---
gsd_state_version: 1.0
milestone: v2.0
milestone_name: FFT-First Visualizer
status: completed
stopped_at: Phase 5 context gathered
last_updated: "2026-04-20T06:32:06.772Z"
last_activity: 2026-04-20 -- Completed 04-01 warp feedback loop + inverted sphere
progress:
  total_phases: 4
  completed_phases: 2
  total_plans: 6
  completed_plans: 5
  percent: 83
---

# Project State

## Project Reference

See: .planning/PROJECT.md (updated 2026-04-16)

**Core value:** Whatever music is playing on your computer comes alive around you -- frequency bands drive distinct visual layers
**Current focus:** Phase 4 in progress -- Milkdrop Warp Mode

## Current Position

Phase: 4 of 4 (Milkdrop Warp Mode) -- IN PROGRESS
Plan: 1 of 1 in current phase (done)
Status: Phase 4 Plan 01 complete
Last activity: 2026-04-20 -- Completed 04-01 warp feedback loop + inverted sphere

Progress: [████████░░] 83%

## Performance Metrics

**Velocity:**
- Total plans completed: 3 (v1.0)
- Average duration: --
- Total execution time: --

**By Phase:**

| Phase | Plans | Total | Avg/Plan |
|-------|-------|-------|----------|
| 1. VR + Audio Foundation | 3/3 | -- | -- |

*Updated after each plan completion*
| Phase 02 P01 | 1min | 2 tasks | 4 files |
| Phase 02 P02 | multi-session | 3 tasks | 6 files |
| Phase 03 P01 | 5min | 2 tasks | 4 files |
| Phase 03 P02 | 8min | 2 tasks | 2 files |
| Phase 04 P01 | 2min | 2 tasks | 4 files |

## Accumulated Context

### Decisions

Decisions are logged in PROJECT.md Key Decisions table.
Recent decisions affecting current work:

- [v2.0]: FFT frequency bands over Rekordbox stems (stems confirmed dead end)
- [v2.0]: BlackHole virtual audio device for system audio capture
- [v2.0]: 1-2 visualizer modes for v2.0 (prove pipeline before stacking modes)
- [v2.0]: SubViewport ping-pong for Milkdrop warp (SCREEN_TEXTURE broken in VR stereo)
- [Phase 01]: Mobile renderer for XR per official Godot docs
- [Phase 01]: macOS flat-screen mode skips OpenXR init entirely for desktop testing
- [Phase 02-01]: Capture bus at -80dB with runtime safety prevents audio feedback
- [Phase 02-02]: 5 band-named shader uniforms replace 16 stem-based uniforms
- [Phase 02-02]: Sample rate alignment required -- BlackHole must match Multi-Output Device (44.1kHz)
- [Phase 02]: 5 band-named shader uniforms replace 16 stem-based uniforms
- [Phase 03-01]: ModeManager follows established call_deferred autoload pattern
- [Phase 03-01]: Each bar gets its own CylinderMesh and StandardMaterial3D (no shared resources)
- [Phase 03-01]: 27 bars weighted toward bass bands for visual density in front
- [Phase 03]: Glow tuned to intensity=0.8, strength=1.5, bloom=0.3, hdr_threshold=0.8 for Mobile renderer
- [Phase 03]: ModeManager wired via call_deferred to ensure scene tree readiness after XR init
- [Phase 04-01]: ViewportTextures assigned via code in call_deferred to handle ModeManager dynamic instantiation
- [Phase 04-01]: PlaceholderTexture2D for CopySprite initial texture, replaced at runtime
- [Phase 04-01]: Idle animation with slowly cycling colors when no audio signal

### Roadmap Evolution

- v1.0 Phase 1 completed. Phases 1.1, 2, 3 abandoned (Rekordbox dead end)
- v2.0 milestone: 3 new phases (2-4) for FFT-first visualizer
- Phase 5 added: Milkdrop rendering engine with preset loader (real .milk file compatibility)

### Pending Todos

None yet.

### Blockers/Concerns

- ~~[Phase 2]: BlackHole + Godot 4.6 macOS audio input bug (PR #111691)~~ RESOLVED: works with sample rate alignment
- [Phase 4]: SubViewport ping-pong in VR stereo is under-documented -- needs proof-of-concept

## Session Continuity

Last session: 2026-04-20T06:32:06.769Z
Stopped at: Phase 5 context gathered
Resume file: .planning/phases/05-milkdrop-rendering-engine-with-preset-loader/05-CONTEXT.md
