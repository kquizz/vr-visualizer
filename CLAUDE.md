# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## Project Overview

VR Music Visualizer built in **Godot 4.6** targeting Quest 3 (via Virtual Desktop/PCVR). Renders audio-reactive visuals in VR using FFT frequency analysis. On macOS, runs in flat-screen preview mode with mouse-look camera since OpenXR isn't available.

## Running the Project

```bash
# Open in Godot editor (requires Godot 4.6)
godot -e --path .

# Run main scene directly
godot --path .
```

Main scene: `res://scenes/main.tscn`. No external build system — Godot handles compilation.

## Architecture

**Data flow:** Audio → FFT analysis → global shader uniforms → visual output

1. **AudioManager** (autoload singleton) captures audio via stem buses (v1.0) or BlackHole capture (v2.0 planned), runs 7-band FFT analysis per frame with exponential smoothing
2. **ShaderBridge** (autoload singleton) reads `AudioManager.stem_data[]` each frame and sets 16 global shader uniforms via `RenderingServer.global_shader_parameter_set()`
3. **Shaders** consume those uniforms (`drums_energy`, `bass_bands_low`, etc.) for audio-reactive vertex/fragment effects
4. **main.gd** handles XR initialization on Windows/Linux, falls back to FallbackCamera3D with mouse-look on macOS

**Key patterns:**
- Both autoloads use `call_deferred("_initialize")` to avoid AudioServer/RenderingServer null traps at startup
- FFT smoothing: fast attack (0.3), slow decay (0.05) — tuned for music visualization responsiveness
- 7 frequency bands: sub-bass (20-60Hz), bass (60-250Hz), low-mid (250-500Hz), mid (500-2kHz), upper-mid (2-4kHz), presence (4-6kHz), brilliance (6-11kHz)
- Global shader uniforms are declared in `project.godot` under `[shader_globals]` — 4 stems × 4 properties (energy, peak_freq, bands_low vec4, bands_high vec4)

## Key Files

| File | Role |
|------|------|
| `scripts/autoloads/audio_manager.gd` | FFT analysis pipeline, stem bus management |
| `scripts/autoloads/shader_bridge.gd` | Pushes audio data to global shader uniforms |
| `scripts/audio_data.gd` | RefCounted data struct (energy, peak_freq, bands[7]) |
| `scripts/main.gd` | XR init / flat-screen fallback detection |
| `scripts/debug_overlay.gd` | 3D FFT debug labels with per-band bar charts |
| `shaders/test_reactive.gdshader` | Proof-of-concept audio-reactive shader |
| `default_bus_layout.tres` | 4 audio buses with SpectrumAnalyzer effects (FFT 2048) |
| `scenes/vr_scene.tscn` | VR environment, XR camera, fallback camera, test mesh |

## Rendering & Platform Constraints

- **Renderer:** Mobile (required for XR + ETC2/ASTC compression)
- **Target FPS:** 90 (VSYNC disabled, explicit control)
- **VR:** OpenXR enabled in project.godot; skipped entirely on macOS
- **Deployment:** Quest 3 via Virtual Desktop (PCVR over WiFi)
- Shaders must work within Mobile renderer limits (no compute shaders, limited texture formats)

## Project Status

- **v1.0 (Phase 1) COMPLETE:** VR foundation, 4-stem audio pipeline, FFT analysis, debug overlay
- **v2.0 in progress:** Pivoting from Rekordbox stems to FFT-only with BlackHole audio capture (any desktop audio source)
- Planning docs live in `.planning/` — see `ROADMAP.md` for phase breakdown, `REQUIREMENTS.md` for traceability
