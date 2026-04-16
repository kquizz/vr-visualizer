# Technology Stack

**Project:** VR Music Visualizer - v2.0 FFT-First Milestone
**Researched:** 2026-04-16
**Confidence:** HIGH
**Scope:** New additions only. Existing stack (Godot 4.6, OpenXR, GDScript, Mobile renderer, AudioEffectSpectrumAnalyzer, AudioManager/ShaderBridge autoloads) is validated and carries forward unchanged.

## What's Changing from v1.0

The architecture pivots from 4 separate stem AudioStreamPlayers to a single AudioStreamMicrophone capturing system audio via BlackHole. This collapses the 4-bus stem layout into a single "Capture" bus with one SpectrumAnalyzer. FFT band extraction replaces per-stem analysis. The ShaderBridge global uniforms change from stem-named (`drums_energy`, `bass_energy`, etc.) to band-named (`sub_bass`, `bass`, `low_mid`, `mid`, `upper_mid`, `presence`, `brilliance`).

## New Stack Components

### System Audio Capture

| Technology | Version | Purpose | Why | Confidence |
|------------|---------|---------|-----|------------|
| BlackHole | 0.6.0+ (2ch) | macOS virtual audio loopback driver | Routes any desktop audio (Spotify, Tidal, Rekordbox, YouTube) into Godot as an audio input device. Zero latency. Free, open source. The 2-channel version is sufficient -- stereo capture is all we need. Install via `brew install blackhole-2ch`. | HIGH |
| AudioStreamMicrophone | (Godot built-in) | Captures audio input device into Godot audio bus | Godot treats BlackHole as a microphone input. Create an AudioStreamPlayer with AudioStreamMicrophone stream, route to a "Capture" bus with SpectrumAnalyzer attached. BlackHole shows up in `AudioServer.get_input_device_list()`. | HIGH |
| macOS Multi-Output Device | (macOS built-in) | Hear audio AND capture it simultaneously | Without this, routing output to BlackHole means you can't hear the music. Create a Multi-Output Device in Audio MIDI Setup combining Built-in Output + BlackHole 2ch. Set as system output. Audio goes to both speakers and BlackHole. | HIGH |

**How audio capture works end-to-end:**

1. User creates Multi-Output Device in macOS Audio MIDI Setup (one-time setup)
2. System audio output set to Multi-Output Device -- sound goes to speakers AND BlackHole
3. Godot project has `audio/driver/enable_input = true` in Project Settings
4. `AudioServer.input_device` set to "BlackHole 2ch" (or user selects from `AudioServer.get_input_device_list()`)
5. AudioStreamPlayer with AudioStreamMicrophone stream plays on "Capture" bus
6. Capture bus has AudioEffectSpectrumAnalyzer -- FFT data available per frame
7. Capture bus is MUTED (volume_db = -80) to prevent feedback loop of re-outputting captured audio

### Audio Analysis (Replaces Stem-Based Analysis)

| Technology | Version | Purpose | Why | Confidence |
|------------|---------|---------|-----|------------|
| AudioEffectSpectrumAnalyzer | (Godot built-in) | FFT on single capture bus | Same component as v1.0 but now on one bus instead of four. Use FFT size 2048 (enum value 3) for good frequency resolution at reasonable latency. Buffer length 0.1s is fine. | HIGH |
| Custom band mapper (GDScript) | N/A | Map FFT bins to musically meaningful frequency bands | Replace v1.0's per-stem 7-band analysis with a single-stream band mapper. Same `get_magnitude_for_frequency_range()` API, same band edges. No new dependencies needed. | HIGH |
| Custom beat detector (GDScript) | N/A | Energy-threshold beat detection from sub-bass/bass bands | Track rolling average of bass energy (60-250Hz), trigger beat flag when instantaneous energy exceeds average by threshold. ~50 lines. Provide `is_beat` bool and `beat_intensity` float to ShaderBridge. | MEDIUM |

**Band mapping (same as v1.0 AudioData, carries forward):**

| Band | Range (Hz) | Musical Role | Visual Use |
|------|-----------|--------------|------------|
| Sub-bass | 20-60 | Kick drum fundamental, rumble | Large-scale pulsing, warp intensity |
| Bass | 60-250 | Bass guitar, bass synth body | Medium-scale motion, zoom |
| Low-mid | 250-500 | Warmth, body of instruments | Color warmth shifts |
| Mid | 500-2000 | Vocals, lead instruments | Primary visual brightness |
| Upper-mid | 2000-4000 | Vocal presence, guitar attack | Edge sharpness, detail level |
| Presence | 4000-6000 | Clarity, sibilance | Sparkle effects |
| Brilliance | 6000-11050 | Air, cymbal shimmer | High-frequency particle triggers |

### Shader / Visual Pipeline (New Components)

| Technology | Purpose | Why | Confidence |
|------------|---------|-----|------------|
| SubViewport ping-pong pair | Frame feedback for Milkdrop-style warp | Two SubViewports alternate: A renders the warp shader sampling B's texture, then B renders sampling A's texture next frame. This is how Milkdrop's persistent warp motion works. Godot's ViewportTexture makes this straightforward. Community-validated pattern for feedback shaders in Godot 4.x. | HIGH |
| ColorRect + ShaderMaterial (canvas_item shader) | Fullscreen post-process for warp effect | A ColorRect filling the SubViewport with a fragment shader that samples the previous frame texture with warped UVs. The warp is driven by audio uniforms (zoom, rotation, translation from bass/sub-bass energy). This IS the Milkdrop core loop. | HIGH |
| MultiMeshInstance3D | Instanced spectrum bar geometry | Existing recommendation from v1.0. For the spectrum bars visualizer: one MultiMesh with N instances (32-64 bars), per-instance transform set from GDScript each frame based on band magnitudes. Efficient for VR. | HIGH |
| WorldEnvironment + Environment | Glow/bloom post-processing | Godot's built-in glow effect adds the "visualizer feel" to both modes. Configure glow bloom with 1-2 levels, intensity driven by overall energy. Mobile renderer supports glow. | HIGH |

### Milkdrop Algorithm Reference

| Resource | How to Use | License |
|----------|-----------|---------|
| [MilkDrop Preset Authoring Guide](https://www.geisswerks.com/milkdrop/milkdrop_preset_authoring.html) | Definitive reference for per-frame/per-vertex equations. Documents all audio variables (`bass`, `mid`, `treb`, `bass_att`) and warp parameters (`zoom`, `rot`, `warp`, `cx`, `cy`, `dx`, `dy`, `sx`, `sy`). Port these concepts to Godot shader uniforms. | Documentation (public) |
| [projectM source](https://github.com/projectM-visualizer/projectm) | C++ open-source Milkdrop implementation. Study the warp mesh renderer and preset evaluator for algorithm understanding. Do NOT try to port the renderer -- just learn the math. | LGPL-2.1 |
| [Butterchurn / milkdrop-shader-converter](https://github.com/jberg/milkdrop-shader-converter) | HLSL-to-GLSL converter for Milkdrop presets. Useful if you want to study how specific preset pixel shaders translate to GLSL (Godot's shader language is GLSL-like). | MIT |

## Changes to Existing Components

### Bus Layout (default_bus_layout.tres)

**Current:** 4 stem buses (Drums, Bass, Vocals, Other) each with SpectrumAnalyzer
**New:** 1 "Capture" bus with SpectrumAnalyzer, muted. Remove the 4 stem buses (or keep for backward compat with stem files as a stretch goal).

### AudioManager Autoload

**Current:** 4 AudioStreamPlayers on 4 buses, per-stem AudioData, sync checking
**New:** 1 AudioStreamPlayer with AudioStreamMicrophone on Capture bus, single AudioData with 7 bands. Remove sync logic. Add device selection (`AudioServer.input_device`). Add beat detection.

### ShaderBridge Autoload

**Current:** Per-stem globals (`drums_energy`, `bass_energy`, etc.)
**New:** Per-band globals (`sub_bass`, `bass`, `low_mid`, `mid`, `upper_mid`, `presence`, `brilliance`), plus aggregate values (`total_energy`, `is_beat`, `beat_intensity`). Milkdrop-style derived values (`zoom_amount`, `rot_amount`, `warp_amount`) computed from band data.

### project.godot Shader Globals

**Current:** 16 stem-based globals (4 stems x 4 values each)
**New:** Replace with band-based globals. Approximate count: 7 band energies (float) + 3 aggregates (total_energy, is_beat, beat_intensity) + 4 Milkdrop-style derived (zoom, rot, warp, brightness) = ~14 globals. Fits comfortably in the global uniform budget.

## Project Settings Changes

```
# Add to project.godot
[audio]
driver/enable_input=true    # REQUIRED for AudioStreamMicrophone to work
```

## What NOT to Add

| Technology | Why Avoid | What to Do Instead |
|------------|-----------|-------------------|
| GDExtension / C++ for audio processing | Premature optimization. Single-stream FFT in GDScript is trivial. Profile first. | Keep GDScript. One `get_magnitude_for_frequency_range()` call per band per frame is nothing. |
| Compute shaders for FFT | Godot's built-in SpectrumAnalyzer already does FFT on the audio thread. Adding a GPU FFT pass adds complexity for zero benefit. | Use built-in AudioEffectSpectrumAnalyzer. |
| AudioEffectRecord / AudioEffectCapture | You don't need to RECORD audio or access raw PCM buffers. You only need FFT magnitudes. SpectrumAnalyzer gives you that directly. | Use AudioEffectSpectrumAnalyzer on the Capture bus. |
| Third-party audio analysis plugins (gd-audio-analyzer) | Early-stage addon (targets Godot 4.5+). Adds dependency risk for features you can implement in ~100 lines of GDScript. | Custom GDScript band mapper + beat detector. |
| BlackHole 16ch or 64ch | Stereo capture is all you need. Higher channel counts waste resources and complicate device selection. | BlackHole 2ch. |
| Full Milkdrop preset parser | Parsing .milk presets is a project unto itself. You want the visual EFFECT, not preset compatibility. | Hand-write 1-2 warp shaders inspired by Milkdrop. Use the authoring guide to understand the math, then implement directly in Godot shader language. |
| Demucs / stem separation pipeline | Dead end per Phase 1.1 spike. FFT bands from mixed audio produce excellent visualizations. | Single-stream FFT band analysis. |
| Multiple SubViewport layers | One ping-pong pair is sufficient for the warp feedback effect. Adding more layers complicates the render pipeline and risks frame drops in VR. | Single ping-pong SubViewport pair for warp. |

## Alternatives Considered

| Category | Recommended | Alternative | Why Not |
|----------|-------------|-------------|---------|
| Audio loopback | BlackHole 2ch | Loopback (Rogue Amoeba) | $99 commercial app. BlackHole is free, open source, zero latency, and does exactly one thing well. |
| Audio loopback | BlackHole 2ch | Soundflower | Abandoned, doesn't support Apple Silicon natively. BlackHole is the maintained successor. |
| Audio loopback | BlackHole 2ch | Ground Control (macOS native ScreenCaptureKit) | Only available macOS 13+, designed for screen recording, not general audio routing. More complex setup. BlackHole is simpler and more universal. |
| Beat detection | Custom GDScript | Aubio / LibROSA via GDExtension | Massive overkill. Energy-threshold beat detection is ~50 lines. If you need onset detection or tempo tracking later, consider it then. |
| Warp effect | SubViewport ping-pong | BackBufferCopy + SCREEN_TEXTURE | SCREEN_TEXTURE in Godot 4 has restrictions in VR (doesn't work with multiview/stereo rendering). SubViewport approach is explicit and works correctly in stereo. |
| Spectrum bars | MultiMeshInstance3D | Individual MeshInstance3D per bar | MultiMesh is purpose-built for instanced geometry. 32-64 bars as individual nodes would work but is less efficient and harder to manage. |

## Version Compatibility

| Component | Compatible With | Notes |
|-----------|-----------------|-------|
| BlackHole 2ch | macOS 10.10+ (Intel + Apple Silicon) | Works with any macOS version Kevin might be running. Zero driver conflicts. |
| AudioStreamMicrophone | Godot 4.0+ | Stable API since Godot 4.0. `AudioServer.input_device` property confirmed in 4.3, 4.4, 4.6 docs. |
| SubViewport ping-pong | Godot 4.0+ (Mobile renderer) | ViewportTexture works in Mobile renderer. Tested by community for feedback effects. |
| MultiMeshInstance3D | Godot 4.0+ | Stable, well-documented. Works with Mobile renderer. |

## Installation / Setup

```bash
# BlackHole 2ch (one-time macOS setup)
brew install blackhole-2ch

# After install:
# 1. Open "Audio MIDI Setup" (Spotlight search)
# 2. Click "+" button -> "Create Multi-Output Device"
# 3. Check both "Built-in Output" (or your speakers) AND "BlackHole 2ch"
# 4. Ensure Built-in Output is the TOP device (clock source)
# 5. System Preferences -> Sound -> Output -> Select "Multi-Output Device"
# Now system audio goes to speakers AND BlackHole simultaneously

# Godot project changes (no external packages needed):
# 1. Project Settings: Audio > Driver > Enable Input = true
# 2. Update default_bus_layout.tres: Add "Capture" bus with SpectrumAnalyzer, muted
# 3. Update AudioManager: Replace stem players with AudioStreamMicrophone player
# 4. Update ShaderBridge: Replace stem globals with band globals
# 5. Update project.godot: Replace stem shader_globals with band shader_globals
```

## Sources

- [BlackHole GitHub](https://github.com/ExistentialAudio/BlackHole) -- latest version, install methods, channel options -- HIGH confidence
- [BlackHole Multi-Output Device Wiki](https://github.com/ExistentialAudio/BlackHole/wiki/Multi-Output-Device) -- setup guide for hearing + capturing audio -- HIGH confidence
- [AudioStreamMicrophone Docs (Godot stable)](https://docs.godotengine.org/en/stable/classes/class_audiostreammicrophone.html) -- audio input stream class -- HIGH confidence
- [AudioServer Docs (Godot stable)](https://docs.godotengine.org/en/stable/classes/class_audioserver.html) -- `input_device`, `get_input_device_list()`, `enable_input` -- HIGH confidence
- [Recording with Microphone Tutorial (Godot)](https://docs.godotengine.org/en/stable/tutorials/audio/recording_with_microphone.html) -- setup pattern for audio input -- HIGH confidence
- [AudioEffectSpectrumAnalyzer Docs](https://docs.godotengine.org/en/stable/classes/class_audioeffectspectrumanalyzer.html) -- FFT API -- HIGH confidence
- [MilkDrop Preset Authoring Guide](https://www.geisswerks.com/milkdrop/milkdrop_preset_authoring.html) -- warp mesh math, audio variables, UV warping -- HIGH confidence
- [projectM GitHub](https://github.com/projectM-visualizer/projectm) -- open-source Milkdrop implementation -- HIGH confidence
- [Butterchurn shader converter](https://github.com/jberg/milkdrop-shader-converter) -- HLSL-to-GLSL Milkdrop translation -- MEDIUM confidence
- [SubViewport feedback shader (Godot Forum)](https://forum.godotengine.org/t/reusing-a-shader-output-as-an-input-for-the-next-frame/118726/2) -- ping-pong buffer pattern validation -- MEDIUM confidence
- [Using SubViewport as Texture (Godot Docs)](https://docs.godotengine.org/en/stable/tutorials/shaders/using_viewport_as_texture.html) -- ViewportTexture usage -- HIGH confidence

---
*Stack research for: VR Music Visualizer v2.0 -- FFT-first milestone additions*
*Researched: 2026-04-16*
