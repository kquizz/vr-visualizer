# Phase 5: Milkdrop Rendering Engine with Preset Loader - Context

**Gathered:** 2026-04-20
**Status:** Ready for planning (REVISED — pivoted from GDScript reimplementation to projectM integration)

<domain>
## Phase Boundary

Integrate the projectM library (open-source Milkdrop reimplementation in C++) as a Godot GDExtension to get full Milkdrop preset compatibility. projectM handles all rendering (NSEEL interpreter, grid warp, waveforms, blur, compositing). We write a thin GDExtension wrapper that feeds it audio data and gets a rendered texture back, displayed on the VR inverted sphere dome. Replaces Phase 4's basic warp mode.

</domain>

<decisions>
## Implementation Decisions

### Architecture: projectM as GDExtension
- Use projectM (https://github.com/projectM-visualizer/projectm) — a mature C++ library that reimplements Milkdrop with full preset compatibility
- Compile projectM as a Godot GDExtension (C++ plugin) using godot-cpp bindings
- projectM renders each frame to an OpenGL texture → we transfer that texture to Godot for display on the dome
- This replaces the previous plan to reimplement NSEEL, warp, waveforms, and blur in GDScript — 10x less work, better performance, full compatibility

### Preset Compatibility
- Full .milk preset compatibility via projectM (it already handles NSEEL, all waveform types, blur, video echo, compositing)
- Start with 5 test presets bundled in `res://presets/`
- Manual preset selection only (no auto-cycling for now)
- Unsupported features handled by projectM gracefully

### Audio Bridge
- projectM expects PCM audio samples (typically 512-2048 samples per frame)
- Need to capture raw PCM from Godot's AudioServer (AudioEffectCapture on the capture bus)
- Feed PCM data to projectM via its API each frame
- projectM handles its own FFT analysis internally — we just give it raw audio

### VR Presentation
- Replace Phase 4 warp mode entirely — remove old warp.gd/warp.tscn/warp_feedback.gdshader
- Keep inverted sphere dome (radius 6m, flip_faces) centered at camera height
- Two modes total: spectrum bars + milkdrop
- Same fade-to-black transition on TAB key switch
- projectM rendered texture mapped to dome interior via display shader

### GDExtension Build
- Use godot-cpp (official C++ bindings for Godot 4.x)
- Build system: SCons (matches Godot's build system) or CMake
- Target platforms: macOS (development), Windows (VR/PCVR deployment)
- The GDExtension exposes a simple GDScript API: init, set_preset, feed_audio, get_texture

### Claude's Discretion
- GDExtension project structure and build configuration
- projectM API surface to expose (minimal — just what we need)
- Texture transfer mechanism (OpenGL shared context, pixel readback, or Godot RenderingServer)
- PCM audio capture implementation details
- Error handling for projectM initialization failures
- Preset file discovery and listing approach

</decisions>

<canonical_refs>
## Canonical References

**Downstream agents MUST read these before planning or implementing.**

### projectM library (the core dependency)
- `https://github.com/projectM-visualizer/projectm` — projectM source code. Key areas:
  - API surface (libprojectM headers — how to initialize, feed audio, render, get texture)
  - Build system (CMake, dependencies)
  - Preset loading API
  - Rendering output (OpenGL texture handle)

### Godot GDExtension system
- `https://github.com/godotengine/godot-cpp` — Official C++ bindings for Godot GDExtensions
- Godot docs on GDExtension: initialization, registering classes, exposing methods to GDScript

### Existing audio pipeline
- `scripts/autoloads/audio_manager.gd` — AudioManager with FFT analysis, grouped channels
- `scripts/audio_data.gd` — AudioData class
- Godot AudioEffectCapture docs — for getting raw PCM samples

### Mode system (integration point)
- `scripts/autoloads/mode_manager.gd` — ModeManager with register_mode/switch_to
- `scripts/main.gd` — XR init, flat-screen fallback, TAB toggle

### Current warp mode (to be replaced)
- `scenes/modes/warp.gd` — Current basic feedback loop
- `scenes/modes/warp.tscn` — Current warp scene
- `shaders/warp_feedback.gdshader` — Current feedback shader
- `shaders/warp_display.gdshader` — Current dome display shader

### Project constraints
- `CLAUDE.md` — Mobile renderer constraint, project architecture

</canonical_refs>

<code_context>
## Existing Code Insights

### Reusable Assets
- `ModeManager`: Mode registration/switching — milkdrop registers as "warp"
- `AudioManager`: Provides FFT data; need to add AudioEffectCapture for raw PCM
- Phase 4 dome: Inverted SphereMesh + display shader reusable for projectM texture output

### Established Patterns
- Autoload singletons (AudioManager, ShaderBridge, ModeManager)
- Mode scenes in `scenes/modes/` with Node3D root
- `call_deferred("_initialize")` for safe startup

### Integration Points
- New `addons/projectm/` directory for the GDExtension
- `AudioManager` needs AudioEffectCapture added for PCM extraction
- `ModeManager._initialize()` — update warp registration to new milkdrop scene
- New `scenes/modes/milkdrop.tscn` + `milkdrop.gd` replaces old warp files

</code_context>

<specifics>
## Specific Ideas

- User wants to load real .milk preset files — "being able to use their presets would be insane"
- Pivoted from GDScript reimplementation to projectM integration after realizing it's 10x less work for better results
- projectM is a mature library used by many Linux music players and Webamp (via butterchurn JS port)
- The GDExtension wrapper should be as thin as possible — let projectM do all the heavy lifting
- Phase 4's attempts at building a feedback loop from scratch proved the complexity of the problem

</specifics>

<deferred>
## Deferred Ideas

- Auto-cycling presets with smooth crossfade — projectM supports this natively, just needs API exposure
- Curated preset packs (20-50 hand-picked presets) — after integration is proven
- Full preset archive browser (~44k presets) — future quality-of-life feature
- Preset rating/favorites system — UX feature for later
- Quest standalone (would need projectM compiled for Android/ARM)

</deferred>

---

*Phase: 05-milkdrop-rendering-engine-with-preset-loader*
*Context gathered: 2026-04-20 (revised: pivoted to projectM GDExtension approach)*
