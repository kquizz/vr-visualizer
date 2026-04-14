# Architecture Patterns

**Domain:** VR Music Visualizer (Quest 3 Standalone)
**Researched:** 2026-04-13

## Recommended Architecture

### High-Level System

```
[Desktop Pipeline]                    [Quest 3 App]

Tidal/Local Audio                     Main Scene (XROrigin3D)
      |                                     |
   Demucs                             Audio Manager
(stem separation)                    /    |    |    \
      |                           Drums  Bass Vocal Other
  4x OGG files                   (bus)  (bus) (bus) (bus)
      |                             |     |     |     |
  Transfer to Quest              FFT    FFT   FFT   FFT
  (USB/WiFi/storage)               \     |     |     /
                                   Audio Data Struct
                                   (4x frequency bands)
                                         |
                                   Mode Manager
                                   /     |      \
                                Mode1  Mode2  Mode3...
                              (scene) (scene) (scene)
                                 |       |       |
                              Shaders  Shaders  Shaders
                              (uniforms from audio data)
```

### Component Boundaries

| Component | Responsibility | Communicates With |
|-----------|---------------|-------------------|
| **AudioManager** (autoload) | Load stem files, manage 4 AudioStreamPlayers, 4 audio buses, 4 SpectrumAnalyzers. Expose per-frame audio data as a struct. | ModeManager (provides audio data), XR UI (volume control) |
| **ModeManager** (autoload) | Scene switching, transition effects, mode registry. Loads/unloads visualizer scenes. | AudioManager (reads audio data), InputManager (mode switch triggers), Individual modes (lifecycle) |
| **InputManager** (autoload) | Controller button mapping, hand gesture detection. Translates raw XR input into semantic actions. | ModeManager (switch mode), AudioManager (volume), XR UI (menu toggle) |
| **Visualizer Mode** (scene) | Self-contained visualizer. Receives audio data struct, drives its own shaders/geometry. Each mode is a PackedScene. | AudioManager (reads audio data via autoload), owns its own ShaderMaterials |
| **Stem Prep Pipeline** (desktop Python) | Download audio, run Demucs, export OGG stems. Completely separate from Godot project. | File system only (outputs OGG files) |

### Data Flow

**Per-Frame Audio Pipeline (runs every `_process`):**

```
1. AudioEffectSpectrumAnalyzerInstance.get_magnitude_for_frequency_range()
   Called 4x (one per bus) with ~8 frequency bands each = 32 float values

2. AudioData resource updated:
   {
     drums:  { sub_bass: 0.8, bass: 0.6, low_mid: 0.3, mid: 0.1, ... , energy: 0.7, beat: true },
     bass:   { sub_bass: 0.9, bass: 0.7, low_mid: 0.2, mid: 0.05, ... , energy: 0.6, beat: false },
     vocals: { sub_bass: 0.0, bass: 0.1, low_mid: 0.4, mid: 0.8, ... , energy: 0.5, beat: false },
     other:  { sub_bass: 0.1, bass: 0.2, low_mid: 0.5, mid: 0.6, ... , energy: 0.4, beat: false }
   }

3. Active visualizer mode reads AudioData, sets shader uniforms:
   material.set_shader_parameter("drums_energy", audio_data.drums.energy)
   material.set_shader_parameter("bass_energy", audio_data.bass.energy)
   material.set_shader_parameter("vocal_energy", audio_data.vocals.energy)
   material.set_shader_parameter("beat_drums", 1.0 if audio_data.drums.beat else 0.0)

4. GPU renders frame with audio-reactive shader parameters
```

**Stem File Loading:**

```
1. App starts -> scan user://stems/ directory for song folders
2. Each song folder contains: drums.ogg, bass.ogg, vocals.ogg, other.ogg
3. AudioManager loads all 4 into AudioStreamPlayers
4. Playback starts synchronized (all 4 play() called same frame)
5. Periodic sync check: if drift > 10ms, resync to drums track position
```

## Patterns to Follow

### Pattern 1: Autoload Singletons for Core Systems

**What:** AudioManager, ModeManager, and InputManager are Godot autoloads (singletons).
**When:** Always. These persist across scene changes.
**Why:** Visualizer modes are swapped as scenes. Audio must keep playing across transitions. Autoloads survive scene changes.

```gdscript
# project.godot
[autoload]
AudioManager = "*res://core/audio_manager.gd"
ModeManager = "*res://core/mode_manager.gd"
InputManager = "*res://core/input_manager.gd"
```

### Pattern 2: Each Mode = One PackedScene

**What:** Every visualizer mode is a self-contained scene with its own nodes, shaders, and script.
**When:** For every new visualizer mode.
**Why:** Clean separation. Modes can be developed/tested independently. Mode switching = scene swap under a parent node.

```gdscript
# Structure:
# res://modes/spectrum_bars/spectrum_bars.tscn  (scene)
# res://modes/spectrum_bars/spectrum_bars.gd    (script)
# res://modes/spectrum_bars/spectrum_bars.gdshader (shader)
#
# res://modes/milkdrop_warp/milkdrop_warp.tscn
# res://modes/milkdrop_warp/milkdrop_warp.gd
# res://modes/milkdrop_warp/warp.gdshader
# res://modes/milkdrop_warp/composite.gdshader
```

### Pattern 3: Shader Uniform Bridge

**What:** GDScript reads FFT data and passes to shaders as uniforms every frame.
**When:** Every visualizer mode that uses custom shaders (all of them).
**Why:** Keeps audio analysis in GDScript (simple, debuggable) and visual rendering in shaders (fast, GPU-parallel).

```gdscript
# In a visualizer mode's _process():
func _process(_delta: float) -> void:
    var audio := AudioManager.get_audio_data()
    mesh_material.set_shader_parameter("drums_energy", audio.drums.energy)
    mesh_material.set_shader_parameter("bass_warp", audio.bass.sub_bass * 2.0)
    mesh_material.set_shader_parameter("vocal_brightness", audio.vocals.mid)
    mesh_material.set_shader_parameter("time", Time.get_ticks_msec() / 1000.0)
```

### Pattern 4: SubViewport Feedback Loop (Milkdrop-style)

**What:** Render current frame to a SubViewport, use its texture as input for next frame's shader.
**When:** Warp tunnel effects, motion blur, trailing effects, Milkdrop-style motion vectors.
**Why:** This is THE technique behind Milkdrop's iconic look. Previous frame warped by audio-reactive displacement + new frame composited on top.

```
SubViewportA (reads from SubViewportB's texture)
     |
  Renders warp shader (displaces previous frame based on audio)
     |
SubViewportB (reads from SubViewportA's texture)
     |
  Next frame...
```

### Pattern 5: Frequency Band Extraction

**What:** Extract meaningful frequency bands from raw FFT, not raw bin data.
**When:** In AudioManager, every frame.
**Why:** Raw FFT bins are meaningless to visualizer modes. Convert to musical ranges: sub-bass (20-60Hz), bass (60-250Hz), low-mid (250-500Hz), mid (500-2kHz), high-mid (2-4kHz), presence (4-6kHz), brilliance (6-20kHz). Normalize to 0.0-1.0.

```gdscript
const BANDS := {
    "sub_bass": Vector2(20.0, 60.0),
    "bass": Vector2(60.0, 250.0),
    "low_mid": Vector2(250.0, 500.0),
    "mid": Vector2(500.0, 2000.0),
    "high_mid": Vector2(2000.0, 4000.0),
    "presence": Vector2(4000.0, 6000.0),
    "brilliance": Vector2(6000.0, 20000.0),
}

func _get_band_magnitude(analyzer: AudioEffectSpectrumAnalyzerInstance, band: Vector2) -> float:
    var mag := analyzer.get_magnitude_for_frequency_range(band.x, band.y)
    return clampf((mag.x + mag.y) / 2.0, 0.0, 1.0)
```

## Anti-Patterns to Avoid

### Anti-Pattern 1: Processing Audio in Shaders

**What:** Trying to do FFT or audio analysis in fragment/compute shaders.
**Why bad:** Quest 3 has limited compute shader support. Audio data needs to be extracted as scalar values anyway. Shaders should receive pre-processed floats, not raw audio buffers.
**Instead:** Do all audio analysis in GDScript via AudioEffectSpectrumAnalyzer. Pass results as uniform floats.

### Anti-Pattern 2: One Giant Scene

**What:** Putting all visualizer modes in a single scene with visibility toggles.
**Why bad:** Memory waste (all modes loaded), complexity explosion, can't develop modes independently.
**Instead:** Each mode is a PackedScene. ModeManager instantiates/frees them.

### Anti-Pattern 3: Physics-Based Particles

**What:** Using Godot's GPUParticles3D or CPUParticles3D for audio-reactive effects.
**Why bad:** Particle systems are designed for fire/smoke/sparks -- they fight you when you want deterministic audio reactivity. On mobile GPU, particle overdraw destroys framerate.
**Instead:** MultiMeshInstance3D with vertex shader displacement. You control every instance's position/scale/color directly. More performant, more controllable.

### Anti-Pattern 4: Unthrottled FFT Queries

**What:** Querying get_magnitude_for_frequency_range() for dozens of narrow bands every frame.
**Why bad:** Each query has overhead. 4 stems x 20 bands = 80 queries per frame adds up.
**Instead:** 4 stems x 7-8 bands = ~32 queries per frame. Group into musically meaningful ranges. Cache and smooth values.

### Anti-Pattern 5: Synchronizing Stems via Signals

**What:** Using Godot signals to keep 4 AudioStreamPlayers in sync.
**Why bad:** Signal delivery has frame-boundary latency. Stems will drift.
**Instead:** Start all 4 players on the same frame. Periodically check `get_playback_position()` on all 4 and resync if drift exceeds threshold (~10ms).

## Directory Structure

```
vr-visualizer/
  project.godot
  core/
    audio_manager.gd          # Autoload: audio playback, FFT, beat detection
    audio_data.gd             # Resource: per-frame audio analysis results
    mode_manager.gd           # Autoload: mode switching, transitions
    input_manager.gd          # Autoload: controller/gesture input mapping
  modes/
    base_mode.gd              # Base class all modes extend
    spectrum_bars/
      spectrum_bars.tscn
      spectrum_bars.gd
      spectrum_bars.gdshader
    milkdrop_warp/
      milkdrop_warp.tscn
      milkdrop_warp.gd
      warp.gdshader
      composite.gdshader
    geiss_plasma/
      ...
  ui/
    mode_menu.tscn             # In-VR mode selection panel
    mode_menu.gd
  stems/                       # Git-ignored, user adds their own
    song_name/
      drums.ogg
      bass.ogg
      vocals.ogg
      other.ogg
  tools/
    prepare_stems.py           # Desktop CLI: Demucs wrapper
    requirements.txt           # demucs, tidalapi (optional)
  export_presets.cfg           # Android/Quest export config
```

## Scalability Considerations

| Concern | At 1 mode | At 5 modes | At 20+ modes |
|---------|-----------|------------|--------------|
| Memory | Trivial (~50MB) | Fine. Only active mode loaded. | Fine if modes free properly. Watch for shader compilation stalls on first load. |
| Shader compilation | Instant | May stutter on first switch to a mode. | Use Godot 4.5+'s shader baking to pre-compile all mode shaders at startup. |
| Audio overhead | 4 FFT queries, negligible | Same (audio system is mode-independent) | Same |
| Mode transition | Instant swap | Should add crossfade | Consider lazy-loading or background loading of next mode's scene. |
| Song library | 1 song, ~20MB stems | 10 songs, ~200MB | Store on device storage, not in APK. Load from user:// or a configurable path. |

## Sources

- [Godot AudioEffectSpectrumAnalyzer Docs](https://docs.godotengine.org/en/stable/classes/class_audioeffectspectrumanalyzer.html)
- [Godot Setting up XR](https://docs.godotengine.org/en/stable/tutorials/xr/setting_up_xr.html)
- [Godot Sync with Audio](https://docs.godotengine.org/en/stable/tutorials/audio/sync_with_audio.html)
- [projectM Architecture](https://github.com/projectM-visualizer/projectm)
- [Milkdrop Shader Converter](https://github.com/jberg/milkdrop-shader-converter)
- [Quest 3 XR Performance Considerations (Godot Forum)](https://forum.godotengine.org/t/performance-considerations-for-stand-alone-xr/52324)
