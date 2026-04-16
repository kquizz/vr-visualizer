# Architecture Research

**Domain:** PCVR Music Visualizer — BlackHole system audio, FFT frequency bands, Milkdrop-style shaders
**Researched:** 2026-04-16
**Confidence:** HIGH (existing codebase verified, Godot APIs confirmed via docs, Milkdrop pipeline well-documented)

## System Overview

```
┌──────────────────────────────────────────────────────────────────┐
│  macOS System Audio                                              │
│  (Spotify, Tidal, Rekordbox, YouTube, anything)                  │
│       │                                                          │
│       ▼                                                          │
│  BlackHole 2ch ─────► macOS Multi-Output Device                  │
│  (virtual audio)       (speakers + BlackHole combined)           │
└───────┬──────────────────────────────────────────────────────────┘
        │ AudioStreamMicrophone sees BlackHole as input device
        ▼
┌──────────────────────────────────────────────────────────────────┐
│  Godot Audio Layer                                               │
│                                                                  │
│  ┌─────────────────┐    ┌──────────────┐                         │
│  │ AudioStreamPlayer│───►│ "Capture" Bus│                         │
│  │ (Microphone)     │    │   ┌────────────────────────────┐      │
│  └─────────────────┘    │   │ AudioEffectSpectrumAnalyzer │      │
│                          │   └────────────────────────────┘      │
│                          │   send ──► Master (muted)             │
│                          └──────────────┘                         │
│                                  │                                │
│                          ┌───────▼───────┐                       │
│                          │ AudioManager  │ (MODIFIED autoload)   │
│                          │ FFT per frame │                       │
│                          │ 7 bands       │                       │
│                          └───────┬───────┘                       │
│                                  │ AudioData                     │
│                          ┌───────▼───────┐                       │
│                          │ ShaderBridge  │ (MODIFIED autoload)   │
│                          │ global uniforms│                      │
│                          └───────┬───────┘                       │
└──────────────────────────┼───────────────────────────────────────┘
                           │
┌──────────────────────────▼───────────────────────────────────────┐
│  Visualization Layer                                             │
│                                                                  │
│  ┌─────────────┐    ┌───────────────────────────────────┐        │
│  │ ModeManager │───►│ Active Mode (PackedScene)          │        │
│  │ (NEW auto)  │    │                                    │        │
│  └──────┬──────┘    │  ┌──────────┐  ┌───────────────┐  │        │
│         │           │  │ Geometry │  │ Shader(s)     │  │        │
│    VR controller    │  │ (mesh/   │  │ (reads global │  │        │
│    input            │  │  multi-  │  │  uniforms)    │  │        │
│                     │  │  mesh)   │  │               │  │        │
│                     │  └──────────┘  └───────────────┘  │        │
│                     └───────────────────────────────────┘        │
│                                                                  │
│  ┌────────────────┐                                              │
│  │ XROrigin3D     │  Main scene (unchanged from Phase 1)        │
│  │  + XRCamera3D  │                                              │
│  │  + Controllers │                                              │
│  └────────────────┘                                              │
└──────────────────────────────────────────────────────────────────┘
```

## What Changes vs. Phase 1

### Components Modified

| Component | Current State | What Changes | Why |
|-----------|--------------|--------------|-----|
| **AudioManager** | 4 stem buses, 4 AudioStreamPlayers, stem-centric | Single "Capture" bus with mic input, single FFT source, no stem sync logic | BlackHole feeds one stereo stream, not 4 stems |
| **ShaderBridge** | Pushes 4x stem uniforms (drums_, bass_, vocals_, other_) | Pushes 1x unified set of band uniforms (audio_) | Single audio source, not 4 stems |
| **AudioData** | Already has 7 bands, energy, peak_frequency | Add `beat` bool for simple beat detection, keep bands as-is | Beat detection useful for mode transitions and pulse effects |
| **project.godot** | 16 shader globals (4 stems x 4 each) | ~6 shader globals (1 source x bands + energy + beat) | Simpler, matches single-source FFT |
| **default_bus_layout.tres** | 4 stem buses (Drums/Bass/Vocals/Other) | 1 "Capture" bus with SpectrumAnalyzer | Single source replaces 4 stems |

### Components Added (NEW)

| Component | Purpose | Type |
|-----------|---------|------|
| **ModeManager** | Registers modes, switches between them, manages transitions | Autoload singleton |
| **VisualizerMode** | Base class all modes extend, defines lifecycle interface | GDScript class |
| **SpectrumBarsMode** | First mode: spatial bars in VR, colored by frequency band | PackedScene |
| **WarpTunnelMode** | Second mode: Milkdrop-style warp with SubViewport feedback | PackedScene |

### Components Unchanged

| Component | Why No Changes |
|-----------|---------------|
| **main.gd** | XR init logic stays the same, just hosts ModeManager's active mode |
| **debug_overlay.gd** | Update to read new uniform names, otherwise same pattern |
| **fallback_camera.gd** | Flat-screen preview still needed for macOS dev |

## Component Responsibilities

| Component | Responsibility | Communicates With |
|-----------|----------------|-------------------|
| **AudioManager** (autoload) | Configure BlackHole input, run FFT on capture bus, update AudioData each frame, provide beat detection | ShaderBridge (data consumer), ModeManager (beat events) |
| **ShaderBridge** (autoload) | Push AudioData into global shader uniforms each _process | AudioManager (reads AudioData), All shaders (via global uniforms) |
| **ModeManager** (autoload) | Mode registry, scene switching, transition effects, VR input handling for mode changes | AudioManager (beat sync for transitions), Active mode scene (lifecycle), XR controllers (input) |
| **VisualizerMode** (base class) | Define `activate()` / `deactivate()` / `_process()` interface | AudioManager (reads data via global uniforms or direct access) |
| **SpectrumBarsMode** (scene) | MultiMeshInstance3D bars, one per frequency band, height/color driven by band energy | Global shader uniforms (audio_bands_low, audio_bands_high) |
| **WarpTunnelMode** (scene) | Dual SubViewport feedback loop, warp shader + composite shader, Milkdrop-style | Global shader uniforms, SubViewport textures (feedback) |

## Recommended Project Structure

```
vr-visualizer/
  project.godot                    # Autoloads, shader globals, XR config
  default_bus_layout.tres          # MODIFIED: single Capture bus
  scenes/
    main.tscn                      # XROrigin3D, mode container, debug overlay
  scripts/
    audio_data.gd                  # MODIFIED: add beat, keep 7 bands
    main.gd                        # UNCHANGED: XR init
    debug_overlay.gd               # MODIFIED: read new uniform names
    fallback_camera.gd             # UNCHANGED
    autoloads/
      audio_manager.gd             # MODIFIED: mic input, single FFT source
      shader_bridge.gd             # MODIFIED: unified uniform names
      mode_manager.gd              # NEW: mode switching
  modes/
    visualizer_mode.gd             # NEW: base class
    spectrum_bars/
      spectrum_bars.tscn           # NEW: bars scene
      spectrum_bars.gd             # NEW: bars logic
      spectrum_bars.gdshader       # NEW: bars shader
    warp_tunnel/
      warp_tunnel.tscn             # NEW: warp scene with SubViewports
      warp_tunnel.gd               # NEW: warp logic
      warp.gdshader                # NEW: UV distortion shader
      composite.gdshader           # NEW: final output shader
  shaders/
    test_reactive.gdshader         # KEEP for testing, update uniform names
  audio/                           # REMOVE stems dir, no longer needed
```

### Structure Rationale

- **modes/**: Each mode is self-contained (scene + script + shaders) so modes can be developed and tested independently. ModeManager loads by path.
- **scripts/autoloads/**: Core systems that persist across mode switches. AudioManager, ShaderBridge, ModeManager.
- **Flat directory under modes/**: No nested categories yet. With only 2 modes, categorization is premature.

## Architectural Patterns

### Pattern 1: BlackHole as AudioStreamMicrophone

**What:** Godot's AudioStreamMicrophone captures whatever macOS routes through BlackHole. From Godot's perspective, BlackHole is just a microphone.
**When to use:** Always. This is the system audio capture mechanism.
**Trade-offs:** Requires one-time macOS audio setup (Multi-Output Device in Audio MIDI Setup). User must select BlackHole as Godot's input device. Not automatic, but only done once.

**Setup flow:**
1. Install BlackHole 2ch
2. Create Multi-Output Device in Audio MIDI Setup (speakers + BlackHole)
3. Set Multi-Output as system output
4. In Godot project settings: `audio/driver/enable_input = true`
5. AudioManager calls `AudioServer.input_device = "BlackHole 2ch"` at startup

**Implementation:**
```gdscript
# AudioManager._initialize() - NEW version
func _initialize() -> void:
    # Set BlackHole as input device
    var devices = AudioServer.get_input_device_list()
    for device in devices:
        if "BlackHole" in device:
            AudioServer.input_device = device
            break

    # Create mic player on Capture bus
    var player := AudioStreamPlayer.new()
    player.stream = AudioStreamMicrophone.new()
    player.bus = "Capture"
    add_child(player)
    player.play()

    # Get spectrum analyzer from Capture bus
    var bus_idx := AudioServer.get_bus_index("Capture")
    _analyzer = AudioServer.get_bus_effect_instance(bus_idx, 0)
    _audio_data = AudioData.new()
```

**Critical note:** The Capture bus must send to Master but Master should NOT output to speakers (to avoid feedback). Instead, the Multi-Output Device at the OS level handles speakers. In Godot, mute the Master bus or set its volume to -INF dB.

### Pattern 2: Unified FFT Band Mapping

**What:** Single AudioData struct with 7 frequency bands from one stereo source, replacing 4 separate stem AudioData instances.
**When to use:** Always. This is simpler and more powerful than the stem approach.
**Trade-offs:** Lose per-instrument isolation (drums vs bass), but gain: works with any audio source, no prep step, lower latency.

**AudioData stays nearly identical:**
```gdscript
class_name AudioData
extends RefCounted

var energy: float = 0.0
var peak_frequency: float = 0.0
var bands: Array[float] = [0.0, 0.0, 0.0, 0.0, 0.0, 0.0, 0.0]
var beat: bool = false  # NEW: simple beat detection
```

**Shader globals simplify from 16 to 6:**
```
audio_energy      (float)  - overall energy 0-1
audio_peak_freq   (float)  - dominant frequency Hz
audio_bands_low   (vec4)   - sub_bass, bass, low_mid, mid
audio_bands_high  (vec4)   - upper_mid, presence, brilliance, beat(0/1)
audio_beat        (float)  - 1.0 on beat, 0.0 otherwise
audio_time        (float)  - elapsed time for animation
```

**Rationale for packing beat into bands_high.w:** Saves a uniform slot. Shaders that need beat can read `audio_bands_high.w`. ShaderBridge also sets `audio_beat` separately for readability in simpler shaders.

### Pattern 3: ModeManager with Scene Swapping

**What:** Autoload that manages a container node in the main scene. Modes are PackedScenes loaded and instantiated on demand.
**When to use:** For switching between visualizer modes.
**Trade-offs:** Simple, no loading screen needed for small scenes. May want preloading later if modes get heavy.

```gdscript
# mode_manager.gd
extends Node

signal mode_changed(mode_name: String)

var _mode_container: Node3D  # Set from main scene
var _active_mode: Node = null
var _modes: Dictionary = {}  # name -> PackedScene path

func register_mode(name: String, scene_path: String) -> void:
    _modes[name] = scene_path

func switch_to(name: String) -> void:
    if _active_mode:
        _active_mode.queue_free()
        _active_mode = null
    var scene: PackedScene = load(_modes[name])
    _active_mode = scene.instantiate()
    _mode_container.add_child(_active_mode)
    mode_changed.emit(name)
```

### Pattern 4: SubViewport Feedback Loop (Milkdrop Warp)

**What:** Two SubViewports ping-pong: frame N renders into VP-A reading VP-B's texture, frame N+1 renders into VP-B reading VP-A's texture. This creates the Milkdrop motion/persistence effect.
**When to use:** WarpTunnelMode and any future modes needing frame accumulation.
**Trade-offs:** Requires 2 SubViewport textures in VRAM. At 1080x1080 per eye that is ~16MB. Negligible on desktop GPU. The 1-frame delay in SubViewport texture reads is actually beneficial here (it IS the previous frame).

**Scene structure for WarpTunnelMode:**
```
WarpTunnel (Node3D)
├── SubViewportA (SubViewport)
│   └── WarpQuadA (ColorRect with warp.gdshader)
│       reads texture from SubViewportB
├── SubViewportB (SubViewport)
│   └── WarpQuadB (ColorRect with warp.gdshader)
│       reads texture from SubViewportA
├── DisplayMesh (MeshInstance3D - sphere or cylinder surrounding player)
│   material reads from whichever SubViewport was last written
└── WarpTunnelScript.gd
    flips which SubViewport is active each frame
```

**Warp shader concept:**
```glsl
shader_type canvas_item;

uniform sampler2D previous_frame;  // SubViewport texture
global uniform vec4 audio_bands_low;
global uniform float audio_beat;
global uniform float audio_time;

void fragment() {
    vec2 uv = UV;
    // Milkdrop-style UV warp driven by audio
    float bass = audio_bands_low.y;  // bass band
    float sub = audio_bands_low.x;   // sub-bass

    // Radial zoom driven by bass
    vec2 center = vec2(0.5);
    vec2 dir = uv - center;
    float zoom = 1.0 - bass * 0.02;
    uv = center + dir * zoom;

    // Rotation driven by sub-bass
    float angle = sub * 0.01;
    float c = cos(angle), s = sin(angle);
    uv -= center;
    uv = vec2(uv.x * c - uv.y * s, uv.x * s + uv.y * c);
    uv += center;

    // Sample previous frame at warped coordinates
    vec3 col = texture(previous_frame, uv).rgb;

    // Decay (prevents washout)
    col *= 0.97;

    // Add new content on beat
    if (audio_beat > 0.5) {
        float ring = smoothstep(0.3, 0.31, length(UV - center));
        col += vec3(ring * 0.5, ring * 0.3, ring * 0.8);
    }

    COLOR = vec4(col, 1.0);
}
```

### Pattern 5: Simple Beat Detection

**What:** Detect beats by watching energy spikes in the sub-bass/bass bands, using a running average and threshold.
**When to use:** For pulse effects, mode transition sync, visual accents.
**Trade-offs:** Not a real onset detector. Works well for electronic music with clear kicks. May false-trigger on complex acoustic music. Good enough for v2.0.

```gdscript
# In AudioManager
var _energy_history: Array[float] = []
const HISTORY_SIZE: int = 30  # ~0.5 seconds at 60fps
const BEAT_THRESHOLD: float = 1.4  # 40% above average

func _detect_beat(data: AudioData) -> void:
    var bass_energy: float = data.bands[0] + data.bands[1]  # sub-bass + bass
    _energy_history.append(bass_energy)
    if _energy_history.size() > HISTORY_SIZE:
        _energy_history.pop_front()

    var avg: float = 0.0
    for e in _energy_history:
        avg += e
    avg /= _energy_history.size()

    data.beat = bass_energy > avg * BEAT_THRESHOLD and _energy_history.size() >= HISTORY_SIZE
```

## Data Flow

### Per-Frame Audio Pipeline (v2.0)

```
Frame start
    │
    ▼
AudioManager._process()
    │
    ├── 1. AudioEffectSpectrumAnalyzerInstance.get_magnitude_for_frequency_range()
    │      Called 7x (one per band) on single Capture bus = 7 float values
    │
    ├── 2. Normalize to 0-1, apply attack/decay smoothing (existing logic)
    │
    ├── 3. Beat detection: compare bass energy to running average
    │
    ├── 4. Update AudioData: { bands[7], energy, peak_frequency, beat }
    │
    ▼
ShaderBridge._process()
    │
    ├── 5. Set global shader uniforms:
    │      audio_energy = data.energy
    │      audio_peak_freq = data.peak_frequency
    │      audio_bands_low = Vector4(bands[0..3])
    │      audio_bands_high = Vector4(bands[4..6], beat)
    │      audio_beat = 1.0 if beat else 0.0
    │      audio_time = elapsed seconds
    │
    ▼
Active mode's shaders read global uniforms automatically
    │
    ▼
GPU renders frame
```

### Mode Switching Flow

```
User presses controller button (e.g., B / Y)
    │
    ▼
main.gd or InputManager detects XR action
    │
    ▼
ModeManager.switch_to(next_mode_name)
    │
    ├── queue_free() current mode scene
    ├── load() + instantiate() new mode scene
    ├── add_child() to mode container
    └── emit mode_changed signal
    │
    ▼
New mode's shaders immediately read global uniforms
(no handoff needed — uniforms are global)
```

### BlackHole Audio Path

```
System audio (Spotify, etc.)
    │
    ▼
macOS Multi-Output Device
    ├──► Speakers/headphones (user hears audio)
    └──► BlackHole 2ch (virtual loopback)
            │
            ▼
         Godot AudioStreamMicrophone (input_device = "BlackHole 2ch")
            │
            ▼
         "Capture" bus ──► SpectrumAnalyzer ──► AudioManager reads FFT
            │
            ▼
         Master bus (MUTED — no Godot audio output to avoid feedback)
```

**Key insight:** Godot does NOT play audio. It only listens. The user hears audio through the Multi-Output Device's speakers/headphones path. Godot's Master bus must be muted to prevent the captured audio from playing back through Godot's output (which would cause echo/feedback if both hit the same speakers).

## Integration Points

### External: macOS Audio System

| Integration | Mechanism | Setup Required |
|-------------|-----------|----------------|
| BlackHole 2ch | Virtual audio driver, appears as input device | Install BlackHole, create Multi-Output Device in Audio MIDI Setup |
| AudioServer.input_device | Godot API to select BlackHole by name | `audio/driver/enable_input = true` in project settings |
| Multi-Output Device | macOS aggregate device combining speakers + BlackHole | One-time config in Audio MIDI Setup |

**macOS audio input fix:** Godot had a macOS audio recording bug (AudioUnitRender error -50) through all 4.x versions. [Fixed by PR #111691](https://github.com/godotengine/godot/issues/106904), merged before Godot 4.6. Should work in Godot 4.6+.

### Internal: Component Boundaries

| Boundary | Communication | Notes |
|----------|---------------|-------|
| AudioManager --> ShaderBridge | ShaderBridge reads `AudioManager.audio_data` (single AudioData) | Was `stem_data` array, now single instance |
| ShaderBridge --> All shaders | Global shader uniforms | Shaders never import AudioManager. They read `global uniform` values. Fully decoupled. |
| ModeManager --> Mode scenes | `add_child()` / `queue_free()` | Modes are dumb scenes. ModeManager owns lifecycle. |
| ModeManager --> AudioManager | Optional: listen for beat events to sync transitions | Nice-to-have, not required for v2.0 |
| XR Input --> ModeManager | Direct call: `ModeManager.switch_to(name)` | Simple. No event bus needed for 2 modes. |

## Anti-Patterns

### Anti-Pattern 1: Routing BlackHole Audio Through Godot's Output

**What people do:** Let the captured mic audio play through Godot's Master bus so users hear it.
**Why it's wrong:** Creates feedback loop or echo. The user already hears audio through the Multi-Output Device. Godot re-playing it doubles the audio.
**Do this instead:** Mute the Master bus (or the Capture bus's send). Godot is listen-only.

### Anti-Pattern 2: Per-Mode Shader Uniform Setting

**What people do:** Each mode script manually calls `set_shader_parameter()` on its materials every frame.
**Why it's wrong:** Duplicates audio-to-shader bridging logic across every mode. Global uniforms already exist.
**Do this instead:** ShaderBridge sets global uniforms once. Mode shaders declare `global uniform` and read them directly. Zero per-mode uniform code needed.

### Anti-Pattern 3: Complex Mode Transition System

**What people do:** Build an elaborate state machine with enter/exit animations, preloading queues, transition shaders.
**Why it's wrong:** Premature for 2 modes. Adds complexity with no user-visible benefit.
**Do this instead:** `queue_free()` old mode, `instantiate()` new mode. If there's a visible pop, add a 0.1s fade-to-black later. Revisit when there are 5+ modes.

### Anti-Pattern 4: Dual SubViewport Without Clear Ownership

**What people do:** Let both SubViewports render simultaneously, unclear which is "current."
**Why it's wrong:** GPU renders both every frame. Wastes half the work. Can cause visual artifacts.
**Do this instead:** Use `SubViewport.render_target_update_mode = UPDATE_DISABLED` on the inactive one. Flip each frame. Only one renders per frame.

### Anti-Pattern 5: Keeping Stem Architecture "Just in Case"

**What people do:** Keep 4 buses, 4 players, stem sync logic alongside the new BlackHole path.
**Why it's wrong:** Dead code. Confuses the uniform namespace. Stems are confirmed dead end.
**Do this instead:** Remove stem buses, stem players, stem sync. Clean break. If stems come back (via Demucs), add them as a new input source behind the same AudioData interface.

## Build Order (Dependency-Driven)

This order ensures each piece can be tested in isolation before composing.

| Order | Component | Depends On | Testable When |
|-------|-----------|-----------|---------------|
| 1 | **BlackHole audio capture** | macOS setup, project settings | Can see FFT data in debug overlay from Spotify audio |
| 2 | **AudioManager refactor** | BlackHole capture working | Single AudioData updates from system audio, debug overlay shows bands |
| 3 | **ShaderBridge refactor** | AudioManager refactor | test_reactive.gdshader responds to system audio |
| 4 | **Shader globals cleanup** | ShaderBridge refactor | project.godot has clean unified uniform names |
| 5 | **ModeManager** | Needs mode container in main scene | Can register and switch between placeholder scenes |
| 6 | **SpectrumBarsMode** | ModeManager, ShaderBridge | Spatial bars react to music in VR |
| 7 | **WarpTunnelMode** | ModeManager, ShaderBridge | Milkdrop-style warp reacts to music in VR |
| 8 | **Controller mode switching** | ModeManager, XR input | Press button, mode changes |

**Phases 1-4 are the foundation refactor.** They modify existing code and can be built/tested with the existing debug overlay. No new visual modes needed.

**Phases 5-8 are additive.** Each adds new capability on the working foundation.

## Sources

- [Godot AudioStreamMicrophone Docs](https://docs.godotengine.org/en/stable/classes/class_audiostreammicrophone.html)
- [Godot AudioEffectSpectrumAnalyzer Docs](https://docs.godotengine.org/en/stable/classes/class_audioeffectspectrumanalyzer.html)
- [Godot Recording with Microphone Tutorial](https://docs.godotengine.org/en/stable/tutorials/audio/recording_with_microphone.html)
- [Godot SubViewport as Texture](https://docs.godotengine.org/en/stable/tutorials/shaders/using_viewport_as_texture.html)
- [Milkdrop Preset Authoring Guide](https://www.geisswerks.com/milkdrop/milkdrop_preset_authoring.html)
- [projectM Architecture](https://github.com/projectM-visualizer/projectm)
- [Godot macOS Audio Input Fix (Issue #106904)](https://github.com/godotengine/godot/issues/106904)
- [BlackHole Virtual Audio](https://github.com/ExistentialAudio/BlackHole)
- [Frame Accumulation in Godot (Forum)](https://forum.godotengine.org/t/frame-accumulation-effect/131100/4)

---
*Architecture research for: PCVR Music Visualizer v2.0 — FFT-first with BlackHole*
*Researched: 2026-04-16*
