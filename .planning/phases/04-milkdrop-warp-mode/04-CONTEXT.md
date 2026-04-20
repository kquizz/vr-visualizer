# Phase 4: Milkdrop Warp Mode - Context

**Gathered:** 2026-04-19
**Status:** Ready for planning

<domain>
## Phase Boundary

A Milkdrop-style warp feedback visualizer that surrounds the viewer in VR as a second mode alongside spectrum bars. Uses SubViewport ping-pong for frame feedback (SCREEN_TEXTURE broken in VR stereo). Audio-driven psychedelic visuals with flowing liquid character. ModeManager integration for stutter-free switching between modes.

</domain>

<decisions>
## Implementation Decisions

### Warp Visual Character
- Flowing liquid style — smooth distortions like ink in water or lava lamp, organic and hypnotic, never angular
- Start simple (2-3 warp layers), ramp up complexity while monitoring FPS for 90fps VR target
- Default to subtle radial/bilateral symmetry (mandala-like effects), with a setting to switch to purely organic (no symmetry)
- Audio-driven color cycling as the default palette — colors shift based on dominant frequency band (bass=warm reds/oranges, highs=cool blues/purples)
- Shader architecture should support palette swapping for future work (POL-03 deferred to v2.x)
- Mobile renderer is required for OpenXR — no compute shaders, spatial shaders only. Desktop GPU is powerful enough; constraint is shader language features, not performance

### VR Spatial Presentation
- Inverted sphere (dome) — warp texture mapped to inside of a large sphere surrounding the viewer. Full 360° immersion
- Sphere radius: 5-8m (medium) — comfortable distance, good immersion without claustrophobia
- Total blackout environment — pure black void, the warp sphere IS the entire visual. No ground plane, no ambient lighting
- Mode transition: brief fade through black (~0.5s) when switching between spectrum bars and warp. Masks loading hitches, feels intentional

### Feedback Loop Behavior
- Long trails as default (~95-98% retention per frame). Visuals smear and trail. Classic Milkdrop look
- Decay mode setting with 3 options: Long trails (default), Quick dissolve (~80-90%), Audio-driven (quiet=trail longer, loud=dissolve faster)
- Stability: periodic subtle reset as default — inject tiny seed of new noise/color every ~30-60s to prevent convergence. Option to disable for natural evolution
- Seed source: both procedural noise injection AND color fields from audio. Noise provides texture/detail, color fields from audio provide broad strokes
- Must run stable for 5+ minutes without grid artifacts or precision drift

### Audio-to-Visual Mapping
- **Bass (LOW channel)** → zoom/warp distortion. Three response modes as settings: Punchy/dramatic (default — visible zoom bursts on kicks), Smooth/flowing (slow undulations), Intensity-scaled (light bass=smooth, heavy bass=dramatic)
- **Mids (MID_LOW + MID_HIGH)** → rotation speed only. More mid energy = faster swirl. Direction stays consistent (no reversals)
- **Highs (HIGH channel)** → color hue shift speed AND brightness/intensity. Cymbals/hats make colors dance and glow. Quiet = slow muted drift, bright highs = rapid vivid cycling
- **Overall energy** → master intensity scaler. Quiet passages = gentle drift, loud sections = everything amplified. Acts as visual "master volume"

### Claude's Discretion
- SubViewport resolution and ping-pong implementation details
- Exact warp distortion math (UV displacement functions)
- Noise algorithm choice for seed injection
- Sphere mesh resolution and UV mapping approach
- Shader uniform names for warp-specific parameters
- Settings storage mechanism (export vars, resource file, etc.)
- Fade-to-black transition implementation
- Exact symmetry implementation (kaleidoscope UV fold vs. radial repeat)

</decisions>

<canonical_refs>
## Canonical References

**Downstream agents MUST read these before planning or implementing.**

### Audio pipeline (data source for warp)
- `scripts/autoloads/audio_manager.gd` — AudioManager with 7 bands + 4 grouped channels (LOW/MID_LOW/MID_HIGH/HIGH), energy, has_signal
- `scripts/autoloads/shader_bridge.gd` — 5 global shader uniforms: audio_energy, audio_peak_freq, audio_bands_low (vec4), audio_bands_high (vec4), audio_channels (vec4)
- `scripts/audio_data.gd` — AudioData class: energy, peak_frequency, bands[7], grouped[4], has_signal

### Mode system (integration point)
- `scripts/autoloads/mode_manager.gd` — ModeManager with register_mode/switch_to/set_container. Warp mode registers here
- `scripts/main.gd` — XR init, flat-screen fallback, ModeManager setup via call_deferred
- `scenes/modes/spectrum_bars.tscn` — Existing mode scene as reference for structure

### VR scene
- `scenes/vr_scene.tscn` — VR environment, XR camera, fallback camera, ModeContainer node
- `scripts/fallback_camera.gd` — macOS mouse-look camera for desktop testing

### Shader reference
- `shaders/test_reactive.gdshader` — Proof-of-concept audio-reactive shader using global uniforms
- `project.godot` [shader_globals] section — Global uniform declarations

### Project planning
- `.planning/REQUIREMENTS.md` — VIS-03, VIS-04, INF-04 requirements for this phase
- `.planning/ROADMAP.md` — Phase 4 success criteria

</canonical_refs>

<code_context>
## Existing Code Insights

### Reusable Assets
- `ModeManager`: Already handles register/switch_to/container lifecycle — warp mode just needs to register like spectrum_bars did
- `AudioManager.audio_data.grouped[4]`: Pre-computed LOW/MID_LOW/MID_HIGH/HIGH channels map directly to warp parameters
- `AudioManager.audio_data.energy`: Overall energy for master intensity scaling
- `AudioManager.has_signal`: Boolean for idle vs active state — warp can show gentle drift when no signal
- `ShaderBridge` global uniforms: Warp shader can consume the same `audio_bands_low`, `audio_bands_high`, `audio_channels`, `audio_energy` uniforms

### Established Patterns
- Autoload singletons (AudioManager, ShaderBridge, ModeManager) — warp mode is a scene, not an autoload
- `call_deferred("_initialize")` for safe startup
- Mode scenes live in `scenes/modes/` directory
- Global shader uniforms declared in project.godot, set at runtime by ShaderBridge
- Mobile renderer — spatial shaders with emission + bloom, no compute shaders

### Integration Points
- `ModeManager._initialize()` — needs `register_mode("warp", "res://scenes/modes/warp.tscn")` added
- `main.gd._setup_mode_manager()` — may need mode switching trigger (controller input deferred to INT-01 v2.x, but keyboard toggle for testing)
- SubViewport ping-pong is new infrastructure — no existing SubViewport usage in the project

</code_context>

<specifics>
## Specific Ideas

- User wants multiple settings/presets: bass response mode (punchy/smooth/intensity-scaled), decay mode (long trails/quick dissolve/audio-driven), symmetry toggle (on/off), stability reset toggle (on/off)
- These settings hint at a future preset system but for Phase 4 just need to be configurable shader uniforms or export vars
- The "holy shit" factor from Phase 3 carries over: bass drops should be viscerally visible in the warp
- Color palette should feel complementary to spectrum bars — when you switch modes, it should feel like a different experience, not the same thing on a different surface

</specifics>

<deferred>
## Deferred Ideas

- Multiple color palettes / palette switching — tracked as POL-03 in v2.x requirements
- Crossfade transitions between modes — tracked as POL-01 in v2.x (fade-to-black is the v2.0 approach)
- Controller-based mode switching — tracked as INT-01 in v2.x (keyboard toggle for testing in Phase 4)
- Additional warp presets — tracked as POL-05 in v2.x

</deferred>

---

*Phase: 04-milkdrop-warp-mode*
*Context gathered: 2026-04-19*
