# Phase 3: Spectrum Bars + Mode System - Context

**Gathered:** 2026-04-20
**Status:** Ready for planning

<domain>
## Phase Boundary

A spatial spectrum bars visualizer runs in VR, managed by a ModeManager that can load and switch between visualizer scenes. Bars react to live FFT data from BlackHole audio capture (Phase 2). ModeManager provides scene lifecycle so Phase 4 can add a second mode with stutter-free switching.

</domain>

<decisions>
## Implementation Decisions

### Bar Spatial Layout
- Full 360° ring surrounding the viewer at ~3m radius
- ~20-30 bars total, distributed across the 7 frequency bands (multiple bars per band for density)
- Bass forward: sub-bass and bass directly in front where the viewer naturally looks, highs behind
- Band ordering clockwise from front: Sub-Bass → Bass → Lo-Mid → Mid → Up-Mid → Presence → Brilliance (wrapping around behind)
- Bars grow from the floor upward
- Towering scale: bars reach ~4-5m at peak energy (above head height), ~0.1m stubs at rest

### Bar Visual Style
- Glowing cylindrical pillars with emissive material and bloom
- Solid core with glow halo that intensifies with energy
- Cross-section: cylindrical (looks good from any angle in 360° ring)
- Dual motion: height scales with band magnitude + glow intensity/radius pulses with energy
- Bars are the primary light source in the deep space environment

### Color Mapping
- Warm-to-cool gradient across frequency bands (default palette):
  - Sub-Bass: Deep Red (#FF1744)
  - Bass: Orange (#FF9100)
  - Lo-Mid: Yellow (#FFEA00)
  - Mid: Green (#00E676)
  - Up-Mid: Cyan (#00E5FF)
  - Presence: Blue (#2979FF)
  - Brilliance: Violet (#D500F9)
- Static color per band — intensity only affects glow brightness/radius, not hue
- Multiple palette support deferred to v2.x (POL-03 already tracks this)

### Claude's Discretion
- Exact bar width and spacing within the ring
- Ring radius fine-tuning for VR comfort
- Glow falloff curve and bloom parameters
- Floor reflection/ground plane treatment
- Bar mesh segment count (cylinder resolution)
- ModeManager architecture (scene loading, switching mechanism, lifecycle)
- Idle/no-signal animation for bars (Phase 2 decided "subtle ambient idle" — implementation details are flexible)
- How to distribute ~20-30 bars across 7 bands (even vs weighted toward bass)

</decisions>

<canonical_refs>
## Canonical References

**Downstream agents MUST read these before planning or implementing.**

### Audio pipeline (data source for bars)
- `scripts/autoloads/audio_manager.gd` — AudioManager with 7 bands + 4 grouped channels, energy, peak_freq
- `scripts/autoloads/shader_bridge.gd` — 5 global shader uniforms: audio_energy, audio_peak_freq, audio_bands_low (vec4), audio_bands_high (vec4), audio_channels (vec4)
- `scripts/audio_data.gd` — AudioData class: energy, peak_frequency, bands[7], grouped[4], has_signal

### Existing VR scene
- `scenes/vr_scene.tscn` — VR environment, XR camera, fallback camera, test mesh (to be replaced/extended)
- `scripts/main.gd` — XR init / flat-screen fallback detection
- `scripts/fallback_camera.gd` — macOS mouse-look camera for desktop testing

### Shader reference
- `shaders/test_reactive.gdshader` — Proof-of-concept audio-reactive shader using global uniforms
- `project.godot` [shader_globals] section — Global uniform declarations

### Project planning
- `.planning/REQUIREMENTS.md` — VIS-01, VIS-02, INF-03 requirements for this phase
- `.planning/ROADMAP.md` — Phase 3 success criteria

</canonical_refs>

<code_context>
## Existing Code Insights

### Reusable Assets
- `AudioManager.audio_data.bands[7]`: Per-frame FFT magnitudes for all 7 frequency bands — direct data source for bar heights
- `AudioManager.audio_data.grouped[4]`: Pre-computed LOW/MID_LOW/MID_HIGH/HIGH channels for broader visual effects
- `AudioManager.has_signal`: Boolean for idle vs active state
- `ShaderBridge`: Already pushes audio data to global shader uniforms each frame — bars can use these directly in shaders
- `test_reactive.gdshader`: Working example of audio-reactive shader with vertex scaling and emission

### Established Patterns
- Autoload singletons for global services (AudioManager, ShaderBridge) — ModeManager should follow the same pattern
- `call_deferred("_initialize")` for safe startup — use for ModeManager init too
- Global shader uniforms declared in project.godot, set at runtime — bar shaders consume these
- Mobile renderer — no compute shaders, stick to spatial shaders with emission + bloom

### Integration Points
- `vr_scene.tscn` currently has a test mesh — ModeManager will replace this with mode-specific scenes
- `main.gd` handles XR init — ModeManager needs to work after XR is ready
- Bars read from AudioManager each frame via `_process()` — same pattern as ShaderBridge

</code_context>

<specifics>
## Specific Ideas

- Bars should feel like "pillars of light" in deep space — the primary light source illuminating the environment
- The "holy shit" factor: bass drops make the bars in front of you tower overhead with intense warm glow
- Multiple bars per band creates density and visual spectacle vs. a sparse 7-bar equalizer

</specifics>

<deferred>
## Deferred Ideas

- Multiple color palettes / palette switching — tracked as POL-03 in v2.x requirements
- Ring rotation or orbital camera motion — potentially disorienting in VR, revisit in polish phase
- Floor reflections / ground plane effects — could enhance immersion, not critical for Phase 3

</deferred>

---

*Phase: 03-spectrum-bars-mode-system*
*Context gathered: 2026-04-20*
