# Project Research Summary

**Project:** VR Music Visualizer — v2.0 FFT-First Milestone
**Domain:** PCVR audio-reactive visualization (Milkdrop-inspired, BlackHole system audio capture)
**Researched:** 2026-04-16
**Confidence:** HIGH

## Executive Summary

This is a PCVR music visualizer built in Godot 4.6, targeting a desktop GPU via Link/Air Link with the headset running in PCVR mode. The v2.0 milestone is a clean architectural pivot away from the stem-based approach (confirmed dead end in Phase 1.1) toward single-stream FFT analysis of system audio captured via BlackHole. The two core visual modes are: (1) spatial spectrum bars — the recognizable equalizer-bar metaphor rendered in 3D VR space, and (2) a Milkdrop-style warp feedback shader — the "holy shit" effect that justifies using a VR headset over a flat screen. The entire stack is built on Godot built-ins with no new external dependencies beyond the BlackHole virtual audio driver.

The recommended implementation order is dictated by hard dependencies: BlackHole audio capture must be proven working first, because every visual mode depends on it. The AudioManager and ShaderBridge autoloads must be refactored to a single-source FFT model before any shader or visual work begins — attempting to layer new visuals onto the old 4-stem architecture will produce confusing hybrid code. Once the audio pipeline is clean, the two visual modes can be built in sequence on a stable foundation, with mode switching added last.

The top risk is the macOS audio input device selection bug in Godot. A specific bug (AudioUnitRender error -10863 when selecting a non-default input device) was present through Godot 4.x and was fixed in 4.6 via PR #111691. Since the project already runs Godot 4.6, this should be resolved, but it must be validated as the first milestone of the audio capture phase. If it surfaces, the workaround is setting BlackHole as the default macOS input device before launching Godot rather than selecting it programmatically at runtime. The second major risk is the Milkdrop feedback loop: a naive single-SubViewport implementation produces GPU artifacts; a ping-pong dual-SubViewport architecture is required from the start and cannot be patched in later.

## Key Findings

### Recommended Stack

The existing Godot 4.6 + OpenXR + GDScript + Mobile renderer stack carries forward unchanged. The only new external dependency is BlackHole 2ch (free, open source, `brew install blackhole-2ch`), which macOS treats as a virtual audio device. Godot reads it via the built-in `AudioStreamMicrophone` class, treating it identically to a microphone. No GDExtension, no C++ audio processing, no third-party Godot plugins — the entire audio analysis pipeline runs in GDScript using `AudioEffectSpectrumAnalyzer`, which Godot already runs on the audio thread.

For the Milkdrop warp effect, the approach is hand-authored Godot shaders inspired by Milkdrop math — not preset compatibility. The SubViewport ping-pong pattern (two `SubViewport` nodes alternating as read/write targets each frame) is the community-validated mechanism for frame-feedback effects in Godot 4.x. The `SCREEN_TEXTURE` approach was explicitly ruled out because it does not work correctly with VR stereo/multiview rendering.

**Core technologies:**
- BlackHole 2ch: macOS virtual audio loopback — routes any desktop audio into Godot as a mic input, zero latency, free
- AudioStreamMicrophone (Godot built-in): system audio capture into the analysis bus
- AudioEffectSpectrumAnalyzer (Godot built-in): FFT on the single Capture bus, 7 frequency bands
- SubViewport ping-pong pair: frame feedback for Milkdrop-style warp effect — the only correct approach for stereo VR
- MultiMeshInstance3D: instanced spectrum bar geometry — efficient for 32-64 bars in VR
- WorldEnvironment glow: single post-process bloom pass, supported by the Mobile renderer

### Expected Features

The feature dependency chain is linear: BlackHole capture enables FFT band remapping, which enables everything else. The Milkdrop warp mode is the highest-complexity deliverable and the clearest differentiator — PCVR's desktop GPU can run full-resolution feedback shaders that Quest standalone apps cannot.

**Must have (v2.0 table stakes):**
- BlackHole system audio capture — without this, no live music reactivity; the entire premise fails
- FFT band remapping (single source, 7 bands) — foundation of all visual modes
- AudioManager + ShaderBridge refactor — clean break from 4-stem to single-source uniforms
- Spectrum bars mode — immediately recognizable, proves the pipeline works end-to-end
- Milkdrop-style warp/feedback mode — the VR "wow" factor; the reason to own a headset
- Beat/onset detection via energy thresholding — makes visuals feel rhythmically connected
- Controller-based mode switching — the only interaction needed

**Should have (v2.x polish):**
- Smooth mode transitions (crossfade over 0.5-1s) — hard cuts are jarring in VR
- Per-band visual layering refinement — sub-bass drives different layers than brilliance
- Additional hand-authored warp presets (3-5 variations)
- Color palette system per mode

**Defer (v3+):**
- Demucs stem separation sidecar — only if FFT bands prove insufficient
- Quest standalone mode — requires solving audio capture without a desktop host
- Companion desktop app for settings — curated defaults should be sufficient
- Microphone input "party mode"
- More visualizer modes (particle field, tunnel, fractal) — add only after pipeline is solid

### Architecture Approach

The architecture is a clean layered pipeline: macOS audio system → BlackHole → Godot audio capture bus → AudioManager (FFT analysis + beat detection) → ShaderBridge (global uniforms) → ModeManager (scene lifecycle) → active mode's shaders. The key architectural decision is that shaders never directly query AudioManager — they read global uniforms set by ShaderBridge. This decouples every visual mode from the audio pipeline completely: modes are "dumb" PackedScenes that react to globals, with ModeManager owning their lifecycle.

The global uniform count drops from 16 (4 stems x 4 values) to 6: `audio_energy`, `audio_peak_freq`, `audio_bands_low` (vec4 of bands 0-3), `audio_bands_high` (vec4 of bands 4-6 + beat flag), `audio_beat`, `audio_time`. This fits comfortably in Godot's global uniform budget. The new autoload is ModeManager, which loads mode PackedScenes by path and manages the active child in a container node in main.tscn.

**Major components:**
1. **AudioManager** (modified autoload) — single mic player on Capture bus, single AudioData with 7 bands + beat bool, beat detection via rolling energy average
2. **ShaderBridge** (modified autoload) — pushes 6 global uniforms from AudioData each `_process` frame
3. **ModeManager** (new autoload) — mode registry, scene switching via `queue_free` + `instantiate`, VR controller input handling
4. **VisualizerMode** (new base class) — `activate()` / `deactivate()` / `_process()` lifecycle interface
5. **SpectrumBarsMode** (new scene) — MultiMeshInstance3D bars, arc arrangement around player in VR space
6. **WarpTunnelMode** (new scene) — dual SubViewport ping-pong with warp + composite shaders, display mesh surrounding player

### Critical Pitfalls

1. **BlackHole routing kills speaker output** — setting BlackHole as the system output silences speakers entirely. Create a Multi-Output Device in Audio MIDI Setup combining Built-in Output (as primary clock source) + BlackHole 2ch. Set the Multi-Output as system output. Verify speakers still work while Godot receives audio simultaneously.

2. **Godot macOS audio input bug (-10863)** — AudioUnitRender fails when switching to a non-default input device. Fixed in Godot 4.6 (PR #111691). If it surfaces anyway, set BlackHole as the default macOS input device in System Settings before launching Godot, rather than switching programmatically at runtime.

3. **Bolting new architecture onto stem-based code** — trying to reuse the 4-stem AudioManager/ShaderBridge structure produces confusing hybrid code. Make a clean break: single AudioStreamPlayer, single Capture bus, 6 global uniforms. The old stem code is dead; delete it.

4. **Milkdrop feedback loop artifacts** — a single SubViewport reading its own texture is undefined behavior per GPU spec and produces grid artifacts or precision drift over 30+ seconds. Always use two SubViewports in explicit ping-pong. Apply per-frame decay (multiply by 0.98-0.99). Test for 5+ minutes continuously before considering it stable.

5. **Shader compilation stutter on first mode switch** — Godot compiles GPU shaders on first use; in VR at 90fps a 100-500ms hitch is very noticeable. Pre-warm all mode shaders at startup by instantiating each mode scene offscreen, rendering one frame, and freeing it. The project already has `xr/shaders/shader_compilation_mode=1` which helps but does not eliminate the issue.

## Implications for Roadmap

The research is unusually opinionated about build order. The architecture file explicitly defines an 8-step dependency-driven build order, and all four research files agree on the same sequence: fix the audio foundation first, then build visuals on top of it. The phase structure maps directly from that ordering.

### Phase 1: Audio Foundation Refactor

**Rationale:** Every visual mode depends on clean FFT data from a single audio source. Nothing else can be tested until BlackHole capture is working and the AudioManager/ShaderBridge have been refactored to the new single-source model. This is also the highest-risk phase (macOS audio input bug), so it must be validated before any visual investment is made.

**Delivers:** Working system audio capture via BlackHole, refactored AudioManager with single-source FFT + beat detection, updated ShaderBridge with 6 global uniforms, debug overlay confirming non-zero FFT data from live music playback.

**Addresses:** BlackHole capture, FFT band remapping, ShaderBridge update (all P1 must-haves).

**Avoids:** Pitfall 2 (validate Godot 4.6 macOS fix), Pitfall 3 (clean break from stem architecture), Pitfall 1 (Multi-Output Device setup documented as a deliverable of the phase).

**Research flag:** NEEDS VALIDATION. The macOS audio input device selection bug fix (PR #111691) must be confirmed working on this specific machine. If it does not work, the fallback strategy (set default input before launch, or use an Aggregate Device) is documented in PITFALLS.md.

### Phase 2: Spectrum Bars Mode

**Rationale:** Spectrum bars are the lowest-complexity visual deliverable and immediately prove the full audio-to-VR pipeline works end-to-end. Building this before the Milkdrop warp mode validates the ModeManager scene lifecycle, VR rendering, and ShaderBridge global uniforms before committing to the more complex SubViewport feedback architecture.

**Delivers:** 3D spectrum bars arranged in an arc in VR space, colored and scaled by frequency band energy, automatic gain control to keep visuals dynamic across genres, and beat accent on sub-bass/bass bands.

**Uses:** MultiMeshInstance3D, `audio_bands_low` / `audio_bands_high` global uniforms, WorldEnvironment glow.

**Implements:** VisualizerMode base class, ModeManager scene container, SpectrumBarsMode scene.

**Avoids:** Pitfall 4 (boring FFT mapping — add automatic gain control here, in AudioManager, not per-mode), UX pitfall (VR comfort — cap beat flash brightness to 0.7 max, never black-to-white in one frame).

**Research flag:** STANDARD PATTERNS. MultiMeshInstance3D is well-documented. Automatic gain control is ~30 lines of GDScript. No deep research needed; tuning visual parameters is iterative work.

### Phase 3: Milkdrop Warp Mode

**Rationale:** The SubViewport ping-pong feedback architecture is the highest-complexity component and must be built on the stable foundation from Phases 1-2. The warp mode is the primary VR differentiator — PCVR's desktop GPU can run full-resolution feedback shaders that Quest standalone apps cannot. The Milkdrop math is well-documented, but the Godot-specific SubViewport implementation requires careful architecture from the start.

**Delivers:** Milkdrop-style warp/feedback shader running on a surrounding mesh in VR space, audio-driven warp parameters (zoom, rotation, distortion amount, decay) mapped to frequency bands, beat-triggered visual accents.

**Uses:** SubViewport ping-pong pair, warp.gdshader + composite.gdshader, WarpTunnelMode scene.

**Implements:** Architecture Pattern 4 (SubViewport feedback loop) from ARCHITECTURE.md.

**Avoids:** Pitfall 5 (feedback artifacts — dual SubViewport ping-pong, decay per frame, half-resolution feedback buffer, `textureLod` instead of `texture` to avoid mipmap artifacts).

**Research flag:** NEEDS ATTENTION. Ping-pong SubViewport with VR stereo rendering is a niche pattern. The architecture is documented in ARCHITECTURE.md with a concrete scene structure, but the exact node configuration (SubViewport vs SubViewportContainer, render_target_update_mode toggling) should be validated with a minimal proof-of-concept before building the full mode. Test for 5+ minutes before declaring it stable.

### Phase 4: Mode Switching and Polish

**Rationale:** Mode switching requires both modes to exist. Once both visual modes work, controller input for switching and shader pre-warming for stutter-free transitions can be added cleanly. This is the integration and comfort-testing phase.

**Delivers:** Controller-triggered mode switching (right trigger = next mode), haptic feedback on switch, shader pre-warming at startup to eliminate first-switch stutter, menu button accessible for exit/pause.

**Uses:** OpenXR controller input (already available), ModeManager.switch_to(), shader preloading pattern from PITFALLS.md.

**Avoids:** Pitfall 6 (shader compilation stutter — pre-warm all mode shaders at app launch), UX pitfall (no exit without removing headset — map menu button to pause/exit).

**Research flag:** STANDARD PATTERNS. XR controller input in Godot is well-documented. Pre-warming is straightforward. No deep research needed.

### Phase Ordering Rationale

- Phase 1 before everything: BlackHole capture is a hard dependency for all visual modes. The macOS audio bug is the highest-risk item; validating it first de-risks the entire project.
- Phase 2 before Phase 3: Spectrum bars validate the ModeManager and ShaderBridge patterns before introducing the more complex SubViewport feedback architecture. A working simpler mode makes debugging the warp mode much easier.
- Phase 4 last: Mode switching requires both modes to exist. Shader pre-warming requires knowing which shaders exist. Polish only makes sense once there is something to polish.
- This order matches the explicit 8-step build order in ARCHITECTURE.md and the pitfall-to-phase mapping in PITFALLS.md.

### Research Flags

Phases likely needing deeper research during planning:
- **Phase 1:** Validate macOS audio input device bug fix in Godot 4.6 on this machine before committing. The fix is documented (PR #111691) but not locally verified. Budget time for the fallback (Aggregate Device setup) if needed.
- **Phase 3:** SubViewport ping-pong in VR stereo mode is under-documented. Verify the exact node structure before building the full scene. Start with a minimal proof-of-concept (two SubViewports, one shader, no audio) to confirm the feedback loop works in stereo.

Phases with standard patterns (skip research-phase):
- **Phase 2:** MultiMeshInstance3D spectrum bars are well-documented in official Godot docs. Automatic gain control is a known algorithm. Parameter tuning is iterative, not research.
- **Phase 4:** XR controller input, scene management, and shader preloading are all standard Godot patterns with complete documentation.

## Confidence Assessment

| Area | Confidence | Notes |
|------|------------|-------|
| Stack | HIGH | All components are Godot built-ins or a single well-maintained open-source driver (BlackHole). APIs verified against Godot 4.6 stable docs. Alternatives explicitly evaluated and ruled out. |
| Features | HIGH | Feature set is well-scoped. Competitor analysis (Evryway, Gravity, Visionarium) confirms differentiators. Feature dependency chain is clear and matches architecture. |
| Architecture | HIGH | Existing codebase verified. All APIs confirmed in Godot docs. Milkdrop pipeline is well-documented across multiple sources. Build order is dependency-driven and cross-validated against PITFALLS.md. |
| Pitfalls | MEDIUM-HIGH | Critical pitfalls are verified against open Godot issues with issue numbers. The macOS audio input bug has a known fix (PR #111691 in Godot 4.6) but is not locally confirmed. Feedback loop artifact severity on desktop GPU is documented but empirically unverified. |

**Overall confidence:** HIGH

### Gaps to Address

- **BlackHole + Godot 4.6 audio input:** The macOS mic fix (PR #111691) is confirmed merged into Godot 4.6, but must be validated on this specific machine as the first deliverable of Phase 1. PITFALLS.md documents the workaround if the fix does not resolve the issue.

- **Warp shader VR stereo behavior:** The SubViewport ping-pong feedback shader is validated in flat-screen mode. Behavior in Godot's VR stereo/multiview rendering mode has less community documentation. The explicit note in STACK.md that `SCREEN_TEXTURE` does not work in VR stereo is why SubViewport was chosen, but the SubViewport approach itself needs a proof-of-concept at the start of Phase 3.

- **Automatic gain control tuning:** The algorithm is documented (rolling max over ~2 seconds, normalize bands against it), but specific constants (window size, max clamp) will require iterative tuning per genre. This is expected calibration work, not a blocker.

- **VR comfort thresholds:** Brightness cap, maximum warp rotation speed, and sub-bass zoom intensity need empirical tuning in-headset. PITFALLS.md notes that peripheral motion that looks fine on a monitor can be nauseating in VR. Plan for an explicit comfort-testing session after each visual mode is built.

## Sources

### Primary (HIGH confidence)
- [BlackHole GitHub](https://github.com/ExistentialAudio/BlackHole) — device, install, Multi-Output Device setup
- [BlackHole Multi-Output Device Wiki](https://github.com/ExistentialAudio/BlackHole/wiki/Multi-Output-Device) — speaker + capture simultaneous routing
- [Godot AudioStreamMicrophone Docs](https://docs.godotengine.org/en/stable/classes/class_audiostreammicrophone.html) — audio input stream API
- [Godot AudioServer Docs](https://docs.godotengine.org/en/stable/classes/class_audioserver.html) — `input_device`, `get_input_device_list()`
- [Godot AudioEffectSpectrumAnalyzer Docs](https://docs.godotengine.org/en/stable/classes/class_audioeffectspectrumanalyzer.html) — FFT API
- [Godot SubViewport as Texture Docs](https://docs.godotengine.org/en/stable/tutorials/shaders/using_viewport_as_texture.html) — ping-pong buffer pattern
- [MilkDrop Preset Authoring Guide (Geisswerks)](https://www.geisswerks.com/milkdrop/milkdrop_preset_authoring.html) — warp pipeline math, audio variable definitions
- [projectM GitHub](https://github.com/projectM-visualizer/projectm) — open-source Milkdrop implementation, warp mesh architecture

### Secondary (MEDIUM confidence)
- [Godot Issue #110624 / PR #111691](https://github.com/godotengine/godot/issues/110624) — macOS mic fix, confirmed merged to Godot 4.6
- [Godot Issue #106397](https://github.com/godotengine/godot/issues/106397) — macOS AudioUnitRender -10863 bug on non-default input device
- [Butterchurn (milkdrop-shader-converter)](https://github.com/jberg/milkdrop-shader-converter) — HLSL-to-GLSL reference for Milkdrop math
- [SubViewport feedback shader (Godot Forum)](https://forum.godotengine.org/t/reusing-a-shader-output-as-an-input-for-the-next-frame/118726/2) — ping-pong community validation
- [FFT Visualization Best Practices (Daniel Beer)](https://www.dlbeer.co.nz/articles/fftvis.html) — gamma correction, smoothing, logarithmic mapping

### Tertiary (LOW confidence / needs local validation)
- [Godot Issue #81527](https://github.com/godotengine/godot/issues/81527) — feedback loop grid artifacts (mobile GPU; may not affect desktop GPU)
- VR comfort thresholds — no authoritative source; empirical testing required in-headset

---
*Research completed: 2026-04-16*
*Ready for roadmap: yes*
