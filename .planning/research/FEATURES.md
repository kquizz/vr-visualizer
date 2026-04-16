# Feature Research

**Domain:** PCVR Music Visualizer (FFT-driven, Milkdrop-inspired, VR immersive)
**Researched:** 2026-04-16
**Confidence:** HIGH

## Feature Landscape

### Table Stakes (Users Expect These)

Features that a music visualizer must have to feel complete. Missing any of these and the experience falls flat.

| Feature | Why Expected | Complexity | Notes |
|---------|--------------|------------|-------|
| System audio capture via BlackHole | Core promise: "play music on your computer, see it in VR." Without this, user must manually load audio files. | MEDIUM | Requires BlackHole multi-output device setup on macOS. Godot reads BlackHole as an audio input device. One-time system config, then transparent. |
| FFT frequency-band mapping (sub-bass, bass, mids, highs) | The foundation of all audio-reactive visuals. Every visualizer maps frequency bands to visual parameters. Without meaningful band separation, visuals feel random. | LOW | Already partially built -- AudioManager has 7-band FFT. Needs remapping from 4-stem architecture to single-source frequency bands. |
| Spectrum bars visualizer | The most recognizable visualizer mode. Every music visualizer since Winamp has had bars. Users immediately understand "bars = frequencies." | MEDIUM | 3D spatial bars in VR space. Each bar represents a frequency band. Height/color driven by magnitude. Needs MeshInstance3D generation or MultiMesh for performance. |
| Audio-reactive color/brightness | Visuals must visibly respond to the music in real-time. Static or barely-moving visuals are worse than no visualizer. | LOW | Already partially working via ShaderBridge global uniforms. Needs tuning for single-source FFT rather than per-stem data. |
| Beat detection (onset/transient) | Drops, kicks, and snare hits should trigger visible events. Without beat reactivity, visuals feel disconnected from rhythm. | MEDIUM | Not a full BPM tracker -- just onset detection via energy spike thresholding on sub-bass/bass bands. Compare current frame energy to rolling average. |
| Smooth visual decay/persistence | Abrupt on/off visuals are jarring. Every good visualizer uses temporal smoothing -- fast attack, slow decay. | LOW | Already implemented in AudioManager (0.3 attack, 0.05 decay smoothing). May need per-mode tuning. |
| Flat-screen preview mode | Already built, but must continue working for all new modes. Essential for development and for showing people without VR. | LOW | Existing FallbackCamera3D. New modes must render correctly in both VR and flat-screen. |

### Differentiators (Competitive Advantage)

Features that make this visualizer worth putting on a VR headset for, versus just watching a Winamp plugin on a monitor.

| Feature | Value Proposition | Complexity | Notes |
|---------|-------------------|------------|-------|
| Milkdrop-style warp/feedback shader | The "holy shit" factor. Milkdrop's signature look comes from sampling the previous frame with warped UV coordinates, creating flowing psychedelic feedback loops. This is the single most impactful visual effect. | HIGH | Requires: (1) render previous frame to texture, (2) warp shader that distorts UV sampling of that texture, (3) decay/fade, (4) audio-driven warp parameters (zoom, rot, warp amount). Godot SubViewport can capture previous frame. Core variables: zoom, rot, warp, dx, dy, decay. |
| VR immersion (you are INSIDE the visualization) | Flat-screen visualizers are passive. VR places you at the center of the visual field. 360-degree audio-reactive environment is qualitatively different. Existing VR apps (Evryway, Gravity, Visionarium) prove this is compelling. | MEDIUM | Apply warp shader to a surrounding sphere/skybox or full-screen quad in VR. Spectrum bars arranged in a ring or hemisphere around the user. The spatial arrangement IS the differentiator. |
| Mode switching via VR controller | Cycle through visualizer modes without removing headset. Existing VR visualizers (Gravity) use trigger-press to cycle modes. Simple and intuitive. | LOW | Controller input already available via OpenXR. Map trigger/button to cycle through mode scenes. Minimal UI -- just swap modes. |
| Per-band visual layering | Sub-bass drives background pulse, bass drives mid-ground geometry, mids drive particle/wave motion, highs drive sparkle/detail. Creates depth and intentionality rather than "everything reacts to everything." | MEDIUM | Assign each frequency band to a distinct visual layer. This is what makes a visualizer feel "smart" vs. "random." Requires thoughtful mapping in each mode. |
| Smooth preset/mode transitions | Milkdrop's crossfade between presets is iconic. Abrupt mode switches are jarring. Blend between modes over 1-3 seconds. | MEDIUM | For shader-based modes: lerp uniforms. For scene-based modes: fade to black or crossfade via two SubViewports. Butterchurn blends both equation sets over configurable durations. |

### Anti-Features (Commonly Requested, Often Problematic)

| Feature | Why Requested | Why Problematic | Alternative |
|---------|---------------|-----------------|-------------|
| Full Milkdrop preset compatibility | "There are thousands of presets!" | Milkdrop presets use HLSL shaders and a custom equation language. Porting the full preset engine to Godot GLSL is a massive undertaking (Butterchurn took years). The equation interpreter alone is a project. | Hand-write 3-5 Godot shaders inspired by Milkdrop's core techniques (warp, zoom, rotation, decay). Get the feel without the compatibility burden. |
| BPM detection and beat-sync | "Sync visuals to the exact beat grid" | Reliable BPM detection from FFT alone is an unsolved-hard problem. Libraries exist but are heavy and imperfect, especially with mixed genres. False positives create worse experience than no sync. | Use onset/transient detection (energy spike above threshold) instead. Catches kicks and drops without needing BPM. Feels beat-synced without being beat-synced. |
| Microphone input mode | "Use the Quest mic to capture room audio" | Quest mic quality is poor. Room audio has noise, echo, crosstalk. FFT of room-captured music is muddy. PCVR via BlackHole gives clean digital audio. | Keep BlackHole as the only audio source for v2.0. Mic mode is a future "party mode" milestone if desired. |
| User-configurable parameters UI | "Let me tweak every knob" | In VR, complex UI is painful. Text is hard to read, sliders are fiddly, it breaks immersion. Every minute in menus is a minute not in the visualization. | Curate good defaults per mode. Mode switching is the only control. If later needed, use a companion desktop app or simple radial menu. |
| Real-time stem separation (Demucs) | "Separate vocals/drums/bass from the mix" | Demucs requires significant compute, adds latency, needs a sidecar process. Over-engineering for v2.0 when FFT bands provide 80% of the value. | FFT frequency bands (sub-bass, bass, mids, highs) approximate stem behavior well enough. Demucs is a future upgrade path if FFT proves insufficient. |
| Hand tracking for interaction | "Wave your hands to control visuals" | Adds complexity for minimal gain. The visualizer is passive entertainment -- you put it on and watch. Hand tracking occlusion and reliability are still inconsistent. | Controller trigger for mode switch. That is the only interaction needed. |

## Feature Dependencies

```
[BlackHole Audio Capture]
    └──requires──> [FFT Band Remapping]
                       └──requires──> [Spectrum Bars Mode]
                       └──requires──> [Milkdrop Warp Mode]
                       └──requires──> [Beat/Onset Detection]

[FFT Band Remapping]
    └──requires──> [ShaderBridge Update]
                       └──requires──> [All Shader-Based Modes]

[Milkdrop Warp Mode]
    └──requires──> [Previous Frame Capture (SubViewport)]
    └──requires──> [Warp Shader (zoom/rot/warp/decay)]
    └──enhances──> [Per-Band Visual Layering]

[Mode Switching]
    └──requires──> [At Least 2 Working Modes]
    └──requires──> [Controller Input Handling]

[Mode Transitions]
    └──enhances──> [Mode Switching]
    └──requires──> [At Least 2 Working Modes]
```

### Dependency Notes

- **BlackHole Audio Capture requires FFT Band Remapping:** Current AudioManager is built around 4-stem buses. Switching to a single BlackHole input source means collapsing to 1 bus with FFT analysis, then mapping 7 bands to visual parameters instead of per-stem data.
- **All visual modes require ShaderBridge Update:** ShaderBridge currently exposes per-stem uniforms (drums_energy, bass_energy, etc.). Must change to frequency-band uniforms (sub_bass_energy, bass_energy, mid_energy, etc.) from a single audio source.
- **Milkdrop Warp Mode requires Previous Frame Capture:** The signature Milkdrop feedback effect samples the previous frame's rendered output with warped UVs. In Godot, this means rendering to a SubViewport, then sampling that texture in the warp shader. This is the highest-complexity dependency.
- **Mode Switching requires at least 2 modes:** No switching needed until both spectrum bars and warp mode exist.

## MVP Definition

### Launch With (v2.0)

Minimum to deliver the "play music, put on headset, you're inside it" promise.

- [ ] BlackHole system audio capture into Godot -- without this, no live music reactivity
- [ ] FFT band remapping from single source -- foundation for all visual modes
- [ ] Spectrum bars mode -- immediately recognizable, proves the pipeline works
- [ ] Milkdrop-style warp mode -- the "wow" factor, the reason to use VR
- [ ] Basic mode switching via controller trigger -- cycle between the two modes
- [ ] Beat/onset detection via energy thresholding -- makes visuals feel rhythmically connected

### Add After Validation (v2.x)

Features to add once the core pipeline is proven and both modes feel good.

- [ ] Smooth mode transitions (crossfade) -- once switching works, make it feel polished
- [ ] Per-band visual layering refinement -- tune which bands drive which visual layers per mode
- [ ] Additional warp presets (hand-authored) -- 3-5 variations of warp parameters for variety
- [ ] Color palette system -- swap color schemes per mode or per "preset"
- [ ] Audio-reactive environment (skybox pulse, ambient particles) -- shared across all modes

### Future Consideration (v3+)

Features to defer until v2.0 proves the concept.

- [ ] Demucs stem separation sidecar -- only if FFT bands prove insufficient for visual quality
- [ ] More visualizer modes (particle field, tunnel, fractal) -- only after pipeline is solid
- [ ] Preset auto-cycling with timer -- Milkdrop-style automatic mode rotation
- [ ] Companion desktop app for settings -- only if curated defaults prove insufficient
- [ ] Microphone input mode -- "party mode" for when BlackHole is not available
- [ ] Quest standalone mode -- requires solving audio capture without a desktop

## Feature Prioritization Matrix

| Feature | User Value | Implementation Cost | Priority |
|---------|------------|---------------------|----------|
| BlackHole audio capture | HIGH | MEDIUM | P1 |
| FFT band remapping (single source) | HIGH | LOW | P1 |
| ShaderBridge update (band uniforms) | HIGH | LOW | P1 |
| Spectrum bars mode | HIGH | MEDIUM | P1 |
| Milkdrop warp mode | HIGH | HIGH | P1 |
| Beat/onset detection | HIGH | LOW | P1 |
| Mode switching (controller) | MEDIUM | LOW | P1 |
| Per-band visual layering | MEDIUM | MEDIUM | P2 |
| Smooth mode transitions | MEDIUM | MEDIUM | P2 |
| Color palette system | LOW | LOW | P2 |
| Additional warp presets | MEDIUM | LOW | P2 |
| Environment reactivity | LOW | MEDIUM | P3 |

**Priority key:**
- P1: Must have for v2.0 launch
- P2: Should have, add in v2.x polish passes
- P3: Nice to have, future consideration

## Competitor Feature Analysis

| Feature | Evryway Visualiser | Gravity | Visionarium 2 | Our Approach |
|---------|-------------------|---------|---------------|--------------|
| Audio source | Quest local files/mic | Quest local files | PC audio or mic | Desktop system audio via BlackHole (cleanest signal) |
| Visualizer modes | Multiple effects | Switchable themes | Detailed scenes | Spectrum bars + Milkdrop warp (quality over quantity) |
| Mode switching | Hand tracking | Dual trigger | Menu | Controller trigger (simple) |
| Platform | Quest standalone | Quest standalone | PCVR + Quest | PCVR only (desktop GPU = full shader quality) |
| Frequency analysis | Basic | Basic | Unknown | 7-band FFT with per-band visual mapping |
| Feedback/warp effects | Some | No | Some | Full Milkdrop-style warp with decay and feedback |
| Frame rate | 90/120Hz | 72Hz | 90Hz | 90Hz target on desktop GPU |

**Our edge:** PCVR means desktop GPU with no mobile shader constraints. We can run full-resolution warp feedback shaders that Quest standalone apps cannot. Clean digital audio from BlackHole (vs. mic capture) gives sharper FFT data. Fewer modes done well beats many modes done poorly.

## How Each Feature Actually Works

### System Audio Capture (BlackHole)

BlackHole creates a virtual audio device on macOS. User creates a "Multi-Output Device" in Audio MIDI Setup that sends audio to both speakers and BlackHole. Godot opens BlackHole as an audio input device (like a microphone). Zero additional latency. Godot's AudioEffectCapture or AudioStreamMicrophone can read from this input. The captured audio feeds into the existing FFT analysis pipeline.

### FFT Band Mapping

The existing 7-band split (sub-bass 20-60Hz, bass 60-250Hz, low-mid 250-500Hz, mid 500-2kHz, upper-mid 2-4kHz, presence 4-6kHz, brilliance 6-11kHz) is already well-chosen. For visualizer purposes, these 7 bands collapse to 4 visual channels: sub-bass+bass (low), low-mid+mid (mid), upper-mid+presence (high), brilliance (sparkle). Logarithmic frequency mapping is critical -- the existing BAND_EDGES array already handles this correctly. Key improvement: gamma-corrected magnitude scaling and frame-rate-independent smoothing (s' = s^(1/R) where R is frame rate).

### Spectrum Bars

3D bars arranged in VR space. Implementation options: (a) MultiMeshInstance3D with box meshes, scale Y per band -- best performance for many bars, (b) individual MeshInstance3D nodes for 7-16 bars -- simpler, fine for low bar count. Color per bar maps to frequency band (warm reds for bass, cool blues for highs). Height driven by smoothed magnitude. Bars arranged in an arc or ring around the user for VR immersion.

### Milkdrop Warp/Feedback Effect

The core Milkdrop rendering loop each frame:
1. Render current visuals to SubViewport texture
2. Next frame: sample that texture with warped UV coordinates (the "warp shader")
3. Apply decay (multiply by 0.96-0.99 to fade over time)
4. Draw new audio-reactive elements on top (waves, shapes)
5. Repeat -- creating flowing, psychedelic feedback trails

Key warp parameters (all audio-driven):
- **zoom** (1.0 = static, 0.98 = outward zoom): drive with overall energy
- **rot** (rotation): drive with mid-frequency content
- **warp** (distortion amount): drive with bass energy
- **dx/dy** (translation): drive with stereo balance or slow oscillation
- **decay** (0.95-0.99): controls trail length, drive with high-frequency presence
- **cx/cy** (center point): can drift with audio or stay centered

In Godot: use a SubViewport rendering to a ViewportTexture. A full-screen quad (or sphere for VR) samples that texture via a warp shader. Audio parameters from ShaderBridge drive the warp uniforms.

### Beat/Onset Detection

Simple energy-threshold approach (no BPM needed):
1. Track rolling average of sub-bass + bass energy over ~0.5s window
2. When current frame energy exceeds rolling average by threshold (e.g., 1.5x), trigger "beat"
3. Set a cooldown (e.g., 100ms minimum between beats) to prevent rapid-fire triggers
4. Expose as a global uniform (beat_intensity: 0.0-1.0 with fast decay)

This catches kick drums, bass drops, and snare hits reliably. Does not need BPM or beat grid. Shaders use beat_intensity for flash effects, scale pulses, color shifts.

### Mode Switching

Minimal VR UI. Controller mapping:
- Right trigger press: next mode
- Left trigger press: previous mode (or same trigger cycles forward only)
- Haptic buzz on mode change for confirmation

Implementation: each mode is a scene or set of nodes. Switching either swaps scene trees or toggles visibility. For v2.0, just hard-cut between modes. Crossfade is a v2.x polish item.

## Sources

- [MilkDrop Preset Authoring Guide (Geisswerks)](https://www.geisswerks.com/milkdrop/milkdrop_preset_authoring.html) -- authoritative source for warp pipeline
- [Butterchurn Architecture (DeepWiki)](https://deepwiki.com/jberg/butterchurn/1.2-architecture-overview) -- WebGL Milkdrop reimplementation
- [projectM Visualizer (GitHub)](https://github.com/projectM-visualizer/projectm) -- open-source Milkdrop-compatible renderer
- [FFT Visualization Best Practices (Daniel Beer)](https://www.dlbeer.co.nz/articles/fftvis.html) -- gamma correction, smoothing, logarithmic mapping
- [BlackHole Virtual Audio (GitHub)](https://github.com/existentialaudio/blackhole) -- macOS audio loopback driver
- [Godot AudioEffectSpectrumAnalyzer Docs](https://docs.godotengine.org/en/stable/classes/class_audioeffectspectrumanalyzer.html) -- built-in FFT analysis
- [Evryway Visualiser (SideQuest)](https://sidequestvr.com/app/325/evryway-visualiser) -- competitor reference
- [Gravity VR Visualizer (SideQuest)](https://sidequestvr.com/app/6172/gravity) -- competitor reference

---
*Feature research for: PCVR Music Visualizer (FFT-first, Milkdrop-inspired)*
*Researched: 2026-04-16*
