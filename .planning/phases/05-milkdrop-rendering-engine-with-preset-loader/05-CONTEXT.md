# Phase 5: Milkdrop Rendering Engine with Preset Loader - Context

**Gathered:** 2026-04-20
**Status:** Ready for planning

<domain>
## Phase Boundary

A proper Milkdrop rendering engine that replaces Phase 4's basic warp mode. Implements Milkdrop's actual rendering architecture (grid mesh warp, NSEEL equation interpreter, waveform overlays, blur pipeline) and can load real .milk preset files. Displayed on the VR inverted sphere dome. Registered as the "warp" mode in ModeManager, replacing the Phase 4 implementation.

</domain>

<decisions>
## Implementation Decisions

### Preset Compatibility
- Build a full NSEEL (Nullsoft Expression Evaluator Library) interpreter in GDScript to evaluate .milk preset equations at runtime
- Can load any standard .milk preset file directly — no conversion step needed
- Start with 5 test presets to prove the engine works; curated preset packs come later
- Manual preset selection only (no auto-cycling for now)
- Unsupported features are skipped gracefully — preset still renders, just missing some effects
- Presets loaded from a `res://presets/` directory (or user-accessible folder)

### Rendering Pipeline
- **Grid mesh warp (core):** 128x96 vertex grid with dynamic UV coordinates computed per-frame from preset per-pixel equations. This is the heart of the Milkdrop look
- **GPU ping-pong feedback:** Two SubViewports at 2048x2048, swap each frame using get_texture(). Phase 4's CPU copy was a workaround for a shader bug, not a GPU limitation
- **Waveform overlay drawing:** All four types — circular waveform, spectrum/frequency bars, oscilloscope lines, and custom preset-defined shapes. Drawn as mesh geometry on top of the feedback each frame
- **Multi-level Gaussian blur:** Separable blur passes for glow/soft look. Up to 3-4 levels initially
- **Video echo deferred:** Not in MVP. Can add in a follow-up phase if needed
- **Composite shaders deferred:** Not in MVP. Core warp + waveforms + blur is the target

### Waveform Drawing
- Match Milkdrop's blending modes: additive blend for bright glowing lines, alpha blend for softer shapes — follow preset's blend mode flags
- Waveforms are generated as mesh geometry each frame from audio data, rendered on top of the feedback SubViewport
- Custom shapes support per-frame equations from presets (for full preset compatibility)

### VR Presentation
- Replace Phase 4 warp mode entirely — remove old warp.gd/warp.tscn/warp_feedback.gdshader
- Keep inverted sphere dome (radius 6m, flip_faces) centered at camera height
- Two modes total: spectrum bars + milkdrop
- Same fade-to-black transition on TAB key switch
- Milkdrop output texture mapped to dome interior

### Audio Integration
- Milkdrop presets expect specific audio variables: bass, bass_att, mid, mid_att, treb, treb_att, plus raw waveform data (512 samples)
- Map our AudioManager grouped channels and FFT bands to Milkdrop's expected audio variables
- bass = grouped[0] (LOW), mid = (grouped[1] + grouped[2]) * 0.5, treb = grouped[3] (HIGH)
- _att variants use exponential smoothing (slower decay) — need to add these to the audio pipeline

### Claude's Discretion
- NSEEL interpreter implementation details (tokenizer, parser, AST, evaluator)
- Mesh generation approach for waveforms (ImmediateMesh, ArrayMesh, etc.)
- Blur shader implementation (number of taps, kernel weights)
- Preset file parsing approach (.milk files are INI-like format)
- Grid mesh implementation (MeshInstance3D, ArrayMesh, or custom rendering)
- Error handling for malformed presets
- Memory management for preset resources

</decisions>

<canonical_refs>
## Canonical References

**Downstream agents MUST read these before planning or implementing.**

### Milkdrop3 source code (rendering architecture reference)
- `https://github.com/milkdrop2077/MilkDrop3` — Full Milkdrop3 source. Key files to study:
  - Rendering pipeline and per-vertex warp computation
  - NSEEL equation language (per-frame and per-pixel code)
  - Waveform/shape drawing and blending
  - Preset file format (.milk INI-like structure)
  - Blur pipeline implementation

### Existing audio pipeline (data source for Milkdrop)
- `scripts/autoloads/audio_manager.gd` — AudioManager with 7 bands + 4 grouped channels, energy, has_signal
- `scripts/autoloads/shader_bridge.gd` — Global shader uniforms bridge
- `scripts/audio_data.gd` — AudioData class: energy, peak_frequency, bands[7], grouped[4], has_signal

### Mode system (integration point)
- `scripts/autoloads/mode_manager.gd` — ModeManager with register_mode/switch_to
- `scripts/main.gd` — XR init, flat-screen fallback, TAB key toggle, ModeManager setup

### Current warp mode (to be replaced)
- `scenes/modes/warp.gd` — Current basic feedback loop implementation
- `scenes/modes/warp.tscn` — Current warp scene (SubViewport + dome)
- `shaders/warp_feedback.gdshader` — Current feedback shader
- `shaders/warp_display.gdshader` — Current dome display shader

### Project constraints
- `.planning/REQUIREMENTS.md` — VIS-03, VIS-04, INF-04 requirements
- `CLAUDE.md` — Mobile renderer constraint, project architecture

</canonical_refs>

<code_context>
## Existing Code Insights

### Reusable Assets
- `ModeManager`: Handles mode registration and switching — milkdrop registers as "warp" replacing the old implementation
- `AudioManager.audio_data`: Provides grouped channels, FFT bands, energy, has_signal — maps to Milkdrop audio vars
- `ShaderBridge`: Global shader uniforms — may need extension for Milkdrop-specific uniforms
- Phase 4 dome setup: Inverted SphereMesh with display shader can be reused for the Milkdrop output

### Established Patterns
- Autoload singletons for managers (AudioManager, ShaderBridge, ModeManager)
- Mode scenes in `scenes/modes/` with Node3D root
- `call_deferred("_initialize")` for safe startup
- Mobile renderer — spatial shaders, no compute

### Integration Points
- `ModeManager._initialize()` — update warp registration to point to new milkdrop scene
- `scenes/modes/` — new milkdrop scene files replace old warp files
- `scripts/` — new NSEEL interpreter, preset loader, milkdrop renderer scripts
- `shaders/` — new grid warp shader, blur shaders, waveform shader

</code_context>

<specifics>
## Specific Ideas

- User specifically wants to load real .milk preset files from the MilkDrop community — "being able to use their presets would be insane"
- Reference implementation: https://github.com/milkdrop2077/MilkDrop3
- Previous REQUIREMENTS.md listed this as "out of scope" but user has explicitly upgraded it to in-scope
- The Milkdrop3 codebase research (completed 2026-04-20) revealed the full rendering architecture — grid mesh warp with 4 oscillating sine waves, per-pixel NSEEL equations, waveform geometry overlays, multi-level blur, video echo, preset system
- Phase 4's basic feedback loop attempt proved that simple center-injection + zoom/rotate cannot produce Milkdrop-quality visuals — the sharp geometric patterns come from waveform drawing, and the organic flow comes from per-pixel warp equations

</specifics>

<deferred>
## Deferred Ideas

- Auto-cycling presets with smooth crossfade — future enhancement after engine is stable
- Curated preset packs (20-50 hand-picked presets) — after engine proves compatibility
- Full preset archive browser (~44k presets) — future quality-of-life feature
- Video echo effect — after core pipeline is solid
- Composite shaders from presets — after core pipeline is solid
- Per-pixel custom shaders (bUseWarpShader, bUseCompShader) — advanced preset feature for later
- Preset rating/favorites system — UX feature for later

</deferred>

---

*Phase: 05-milkdrop-rendering-engine-with-preset-loader*
*Context gathered: 2026-04-20*
