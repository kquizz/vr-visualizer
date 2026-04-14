# Technology Stack

**Project:** VR Music Visualizer
**Researched:** 2026-04-13

## Recommended Stack

### Engine & Runtime

| Technology | Version | Purpose | Why | Confidence |
|------------|---------|---------|-----|------------|
| Godot Engine | 4.6.x stable | Game engine, rendering, scene management | Latest stable with OpenXR 1.1 auto-enable, spatial anchors, improved XR editor. Kevin has Godot experience. Released Jan 2026. | HIGH |
| GDScript | (bundled) | Primary scripting language | Native to Godot, no FFI overhead, faster iteration than C#/GDExtension for a passion project. C# adds complexity with no benefit here. | HIGH |

### VR / XR Layer

| Technology | Version | Purpose | Why | Confidence |
|------------|---------|---------|-----|------------|
| Godot OpenXR Vendors Plugin | 4.2.1+ | Meta Quest OpenXR extensions, passthrough, foveated rendering | Official Meta/Quest support. Required for standalone Quest 3 APK export. Requires Godot 4.4+. | HIGH |
| Godot XR Tools | 4.5.1 | VR interaction framework (controllers, hand tracking, movement) | Standard toolkit for Godot VR. Provides controller input, teleportation, UI interaction out of the box. Requires Godot 4.4+. | HIGH |
| Godot Meta Toolkit | 1.0.2+ | Meta Platform SDK (entitlements, if ever shipping to Store) | Only needed if targeting Meta Quest Store. Skip initially, add if project goes beyond party trick. | MEDIUM |

### Renderer

| Technology | Purpose | Why | Confidence |
|------------|---------|-----|------------|
| Mobile Renderer (Vulkan) | Primary render pipeline | Quest 3's Snapdragon XR2 Gen 2 handles Vulkan well. Mobile renderer provides single-pass stereo, better shader features than Compatibility, and the Adreno 740 GPU drives it efficiently. Forum consensus as of Godot 4.6 is that Vulkan Mobile is stable and performant on Quest 3. Compatibility (OpenGL ES 3.0) is the fallback if Vulkan issues arise. Do NOT use Forward+ on standalone. | MEDIUM |

**Renderer decision rationale:** The Compatibility renderer (OpenGL) was previously recommended as the "safe" choice for Quest, but as of Godot 4.6, the Mobile (Vulkan) renderer has matured significantly for Quest 3. For a visualizer that will lean heavily on custom shaders, Vulkan's better shader pipeline is worth the slight risk. Keep Compatibility as fallback.

### Audio Analysis

| Technology | Version | Purpose | Why | Confidence |
|------------|---------|---------|-----|------------|
| AudioEffectSpectrumAnalyzer | (built-in) | Real-time FFT per audio bus | Built into Godot. Attach to any audio bus, get frequency magnitude data per frame via `get_magnitude_for_frequency_range()`. FFT sizes: 256-4096. No external dependency. | HIGH |
| AudioStreamPlayer | (built-in) | Audio playback per stem channel | One AudioStreamPlayer per stem (drums, bass, vocals, other), each on its own audio bus with its own SpectrumAnalyzer effect. This gives per-stem FFT for free. | HIGH |
| Custom beat detection (GDScript) | N/A | Beat/onset detection from FFT data | No production-ready beat detection plugin for Godot. Write a simple energy-based beat detector: track rolling average of bass energy, trigger on threshold crossing. ~50 lines of GDScript. The gd-audio-analyzer addon exists but targets Godot 4.5+ and is early-stage. | MEDIUM |

**Audio architecture:** 4 audio buses (Drums, Bass, Vocals, Other), each with AudioEffectSpectrumAnalyzer attached. Each bus drives one AudioStreamPlayer. Per-frame, query each bus's analyzer for frequency band magnitudes. Feed into visualizer as uniform data or vertex offsets.

### Audio Source / Tidal Integration

| Technology | Version | Purpose | Why | Confidence |
|------------|---------|---------|-----|------------|
| Local pre-separated stems (OGG/WAV files) | N/A | Audio input for v1 | **Critical finding: Tidal does NOT expose stem separation via their developer API.** Stems are only available through licensed DJ software partners (Serato, djay, etc.). The developer API provides catalog search, metadata, and limited playback via their Player SDK module. For v1, pre-separate tracks using Demucs on desktop, export 4 stems as OGG files, bundle with APK or load from device storage. | HIGH |
| Demucs / HTDemucs v4 | latest | Offline stem separation (desktop preprocessing) | State-of-the-art stem separation. Splits any track into drums/bass/vocals/other. Run on desktop (Python + PyTorch), export stems as WAV/OGG. ~81MB model (FP16). NOT viable to run on Quest 3 at runtime. | HIGH |
| tidalapi (Python) | 0.8.x | Download tracks from Tidal for processing | Unofficial Python API. Can stream/download tracks from Tidal with valid subscription. Use as desktop preprocessing pipeline: download track -> Demucs separation -> export 4 stems -> load into Quest app. | MEDIUM |

**Tidal reality check:** The dream of "browse Tidal catalog in VR, select song, get stems in real-time" is NOT achievable with current Tidal APIs. Stems are partner-locked. The viable architecture is a desktop companion pipeline that prepares stem files, which the Quest app consumes. This is the single biggest constraint on the project.

### Shader / Visual Pipeline

| Technology | Purpose | Why | Confidence |
|------------|---------|-----|------------|
| Godot Shader Language (GLSL-like) | Custom fragment/vertex shaders per visualizer mode | Godot's shader language compiles to GLSL/SPIR-V. Write custom shaders for each visualizer mode. Milkdrop-style effects are fundamentally fullscreen fragment shaders with audio-reactive uniforms -- perfect fit. | HIGH |
| ShaderMaterial + uniforms | Pass audio data to GPU | Set uniform floats/vectors per frame from GDScript. Example: `material.set_shader_parameter("bass_energy", bass_value)`. Up to ~16 float uniforms per material is plenty for audio reactivity. | HIGH |
| MeshInstance3D + MultiMesh | Geometry for spectrum bars, particles | MultiMeshInstance3D for instanced geometry (spectrum bars, particle-like effects). Vertex shader displacement driven by audio uniforms. MultiMesh handles thousands of instances efficiently on mobile. | HIGH |
| SubViewport + ViewportTexture | Feedback/warp effects (Milkdrop-style) | Render previous frame to texture, sample in next frame's shader for warp/feedback loops. This is how Milkdrop's motion vectors work. Two SubViewports ping-ponging gives you the classic warp tunnel. | HIGH |

### Reference Implementations

| Resource | Purpose | Why |
|----------|---------|-----|
| projectM (libprojectM) | Milkdrop preset reference, algorithm documentation | Open-source C++ reimplementation of Milkdrop. NOT directly usable in Godot, but invaluable for understanding warp mesh math, per-pixel equations, and preset structure. LGPL-2.1 licensed. Has thousands of community presets to study. |
| Butterchurn (milkdrop-shader-converter) | HLSL-to-GLSL shader conversion reference | JavaScript converter for Milkdrop shaders. Useful for understanding how to port specific presets to Godot's shader language. |
| Godot Audio Spectrum Visualizer Demo | Basic Godot audio visualization starter | Asset Library demo showing AudioEffectSpectrumAnalyzer usage pattern. Good starting scaffold. |

## Alternatives Considered

| Category | Recommended | Alternative | Why Not |
|----------|-------------|-------------|---------|
| Engine | Godot 4.6 | Unity | Kevin has Godot experience, not Unity. Unity's XR stack is more mature but the learning curve negates the benefit for a passion project. Godot's XR support is now production-viable on Quest 3. |
| Engine | Godot 4.6 | Unreal | Massive overkill for a visualizer. Build times alone would kill iteration speed. |
| Scripting | GDScript | C# | Adds Mono runtime overhead on Android. No performance benefit for this workload (audio analysis is lightweight, shaders do the heavy lifting). |
| Scripting | GDScript | GDExtension (C++) | Only justified if audio analysis becomes a bottleneck, which it won't with 4 FFT streams. Premature optimization. |
| Renderer | Mobile (Vulkan) | Compatibility (OpenGL ES) | Compatibility is safer but limits shader features. For a shader-heavy visualizer, Vulkan Mobile is worth the trade. Fall back to Compatibility only if Vulkan bugs appear. |
| Renderer | Mobile (Vulkan) | Forward+ | Not viable on standalone Quest 3. Too bandwidth-heavy. |
| Stem separation | Demucs (desktop) | On-device Demucs | HTDemucs requires ~81MB model + significant compute. Quest 3 could theoretically run it but inference would take minutes per track, drain battery, and compete with rendering for GPU. Not worth it. |
| Stem separation | Demucs (desktop) | Tidal API stems | Tidal does not expose stems via developer API. Only available through licensed DJ software integrations. |
| Audio source | Local files | Tidal streaming in-app | Tidal's Player SDK is the only sanctioned playback method, and it doesn't provide raw PCM access needed for per-stem FFT. Local files give full control. |
| Visualization reference | projectM (study only) | Port projectM to Godot | projectM is OpenGL C++ -- porting the renderer is a project unto itself. Instead, study the algorithms and reimplement specific effects as Godot shaders. |

## What NOT to Use

| Technology | Why Avoid |
|------------|-----------|
| Godot 4.4 or 4.5 | Use 4.6. It has OpenXR 1.1 auto-enable, spatial entities, and the best Quest 3 stability. No reason to target older versions for a new project. |
| Forward+ renderer | Will not perform on Quest 3 standalone. Period. |
| C# scripting | Adds complexity, Mono runtime overhead on Android, no benefit for this project. |
| GDExtension for audio | Premature. Godot's built-in FFT is sufficient for 4 channels. Only consider if profiling shows GDScript audio processing as a bottleneck (unlikely). |
| Runtime Tidal streaming | The API doesn't provide what you need (stems). Design around local files from day one. |
| On-device stem separation | Too slow, too power-hungry, competes with rendering GPU. Separate on desktop. |
| Compute shaders for audio | Quest 3's mobile GPU has limited compute shader support. Use fragment shaders with texture-based data passing instead. |

## Installation / Setup

```bash
# Godot Engine
# Download Godot 4.6.x stable from https://godotengine.org/download/
# Use the "Standard" build (not .NET) since we're using GDScript

# Quest 3 Export Setup
# 1. Install Android SDK via Android Studio
# 2. In Godot: Editor > Editor Settings > Export > Android
#    - Set Android SDK path
#    - Set debug keystore path
# 3. Install export templates: Editor > Manage Export Templates

# XR Plugins (install via Godot Asset Library or GitHub)
# - Godot OpenXR Vendors Plugin v4.2.1+ (required for Quest)
# - Godot XR Tools v4.5.1 (VR interaction toolkit)

# Desktop Stem Preparation Pipeline
pip install demucs
pip install tidalapi  # Optional: for downloading from Tidal

# Separate a track into stems
demucs --two-stems=vocals track.mp3          # Quick: vocals + accompaniment
demucs -n htdemucs track.mp3                  # Full: drums, bass, vocals, other

# Convert stems to OGG for Godot (smaller file size)
# Use ffmpeg:
ffmpeg -i separated/htdemucs/track/drums.wav -c:a libvorbis -q:a 5 drums.ogg
ffmpeg -i separated/htdemucs/track/bass.wav -c:a libvorbis -q:a 5 bass.ogg
ffmpeg -i separated/htdemucs/track/vocals.wav -c:a libvorbis -q:a 5 vocals.ogg
ffmpeg -i separated/htdemucs/track/other.wav -c:a libvorbis -q:a 5 other.ogg
```

## Project Configuration

```
# project.godot key settings for Quest 3 VR

[rendering]
renderer/rendering_method = "mobile"        # Vulkan Mobile
textures/vram_compression/import_etc2_astc = true  # ASTC for Quest 3

[xr]
openxr/enabled = true
shaders/shader_compilation_mode = 1         # Async compilation to avoid stutters
```

## Sources

- [Godot 4.6 Release Notes](https://godotengine.org/releases/4.6/) - HIGH confidence
- [Godot XR Update Feb 2025](https://godotengine.org/article/godot-xr-update-feb-2025/) - HIGH confidence
- [Godot OpenXR Vendors Plugin Releases](https://github.com/GodotVR/godot_openxr_vendors/releases) - HIGH confidence
- [Godot XR Tools Releases](https://github.com/GodotVR/godot-xr-tools/releases) - HIGH confidence
- [AudioEffectSpectrumAnalyzer Docs](https://docs.godotengine.org/en/stable/classes/class_audioeffectspectrumanalyzer.html) - HIGH confidence
- [Godot Deploying to Android (XR)](https://docs.godotengine.org/en/stable/tutorials/xr/deploying_to_android.html) - HIGH confidence
- [TIDAL Developer Portal](https://developer.tidal.com/documentation) - HIGH confidence (for confirming no stem API)
- [Demucs GitHub](https://github.com/facebookresearch/demucs) - HIGH confidence
- [projectM GitHub](https://github.com/projectM-visualizer/projectm) - HIGH confidence
- [Milkdrop Shader Converter](https://github.com/jberg/milkdrop-shader-converter) - MEDIUM confidence
- [Quest 3 Renderer Discussion (Godot Forum)](https://forum.godotengine.org/t/quest-3-standalone-forward-mobile-or-compatibility-for-a-3d-vr-project-in-godot-4-6/136328) - MEDIUM confidence
- [tidalapi PyPI](https://pypi.org/project/tidalapi/) - MEDIUM confidence
