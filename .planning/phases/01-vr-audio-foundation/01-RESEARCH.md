# Phase 1: VR + Audio Foundation - Research

**Researched:** 2026-04-13
**Domain:** Godot 4.6 PCVR + OpenXR + Multi-bus Audio FFT Pipeline
**Confidence:** MEDIUM-HIGH

## Summary

Phase 1 establishes the PCVR + audio foundation: a Godot 4.6 project with OpenXR that renders a VR scene on Quest 3 via Virtual Desktop, plays 4 stem audio streams on separate audio buses with per-frame FFT analysis, and bridges normalized audio data to shaders via uniforms.

The core technical stack is well-understood and uses Godot built-in features almost exclusively. AudioEffectSpectrumAnalyzer provides per-bus FFT data, global shader uniforms broadcast audio data to all shaders, and the Mobile renderer is Godot's official recommendation for XR (even desktop PCVR). The biggest architectural risk is the **macOS development constraint**: OpenXR PCVR does not work on macOS, and Virtual Desktop does not support PCVR streaming from Mac. The user develops on Mac, so the dev workflow must be designed around flat-screen preview on Mac with periodic VR testing on a Windows/Linux machine or direct Quest deployment.

**Primary recommendation:** Build with a dual-mode architecture from day one -- flat-screen mode (no XR) as the primary development target on macOS, with XR mode activated only when running on a Windows machine with Virtual Desktop or when deployed to Quest. All audio and shader work is XR-independent and testable on Mac.

<user_constraints>
## User Constraints (from CONTEXT.md)

### Locked Decisions
- Deep space skybox -- stars, nebulae, distant galaxies. Cosmic backdrop for visualizations.
- Skybox is static in Phase 1 -- all visual reactivity comes from visualizer elements in Phase 2+
- Default viewpoint: center of the scene, surrounded by visualizations (most immersive)
- Primary dev machine: Mac (macOS)
- Audio routing via BlackHole/Loopback on macOS (Phase 3, not Phase 1)
- Flat screen preview mode for fast iteration + VR testing for verification
- Must be able to run and test without the headset on for daily development
- Use pre-separated stem files (OGG/WAV) for Phase 1 development

### Claude's Discretion
- Debug overlay design for verifying FFT data in VR
- AudioData struct granularity (frequency bands, smoothing)
- Exact skybox asset selection
- Godot project structure and scene organization

### Deferred Ideas (OUT OF SCOPE)
- Rekordbox spike (PRIORITY): Validate Rekordbox stem routing -- deferred to Phase 1.1
- Reactive skybox that pulses/shifts with music energy -- Phase 2+
- Forward-facing "stage" viewpoint mode -- future mode variant
</user_constraints>

<phase_requirements>
## Phase Requirements

| ID | Description | Research Support |
|----|-------------|-----------------|
| AUD-01 | 4 simultaneous audio streams on separate Godot audio buses | AudioServer buses with AudioStreamPlayer per stem; default_bus_layout.tres configuration |
| AUD-02 | Per-bus FFT spectrum analysis providing per-frame frequency magnitude data | AudioEffectSpectrumAnalyzer on each bus; AudioEffectSpectrumAnalyzerInstance.get_magnitude_for_frequency_range() |
| AUD-03 | Normalized AudioData struct (energy, peak frequency, magnitude bands) | Custom GDScript Resource class; exponential smoothing for stable values |
| VR-01 | PCVR app with OpenXR, viewable on Quest 3 via Virtual Desktop | XROrigin3D + XRCamera3D scene; Mobile renderer; OpenXR enabled in project settings |
| VR-02 | Stable 90fps rendering on desktop GPU | Mobile renderer (official XR recommendation); minimal scene in Phase 1; profiler monitoring |
| VR-03 | Comfortable VR -- no forced locomotion, static viewpoint, photosensitivity-safe | Static XROrigin3D at scene center; no movement code; controlled color ranges |
| INF-01 | AudioManager autoload provides normalized audio data every frame | GDScript autoload singleton; _process() queries all 4 spectrum analyzers; exposes AudioData |
| INF-02 | Shader uniform bridge passes audio data to GPU shaders per frame | Global shader uniforms via RenderingServer.global_shader_parameter_set() for broadcast; per-material set_shader_parameter() as fallback |
</phase_requirements>

## Standard Stack

### Core
| Library | Version | Purpose | Why Standard |
|---------|---------|---------|--------------|
| Godot Engine | 4.6 stable (Jan 2026) | Game engine, rendering, scene management | Latest stable with OpenXR 1.1, Jolt physics default, improved XR editor. User has Godot experience. |
| GDScript | (bundled) | Primary scripting language | Native to Godot, no FFI overhead, fast iteration. C# adds Mono complexity with no benefit here. |
| Mobile Renderer (Vulkan) | (bundled) | Render pipeline for XR | **Official Godot recommendation for ALL XR projects including desktop VR.** Forward+ "isn't well optimized for XR right now." |
| OpenXR | (bundled in Godot 4.6) | VR runtime interface | Built into Godot core since 4.0. No plugin needed for PCVR. |

### Supporting
| Library | Version | Purpose | When to Use |
|---------|---------|---------|-------------|
| Godot XR Tools | 4.5.1+ | VR interaction framework | Only if controller input needed. Phase 1 is static viewpoint, so likely not needed yet. |
| AllSky Free (Godot Edition) | latest | Space skybox panorama textures | For the deep space environment. 10 free skyboxes including space themes. |

### Alternatives Considered
| Instead of | Could Use | Tradeoff |
|------------|-----------|----------|
| Mobile renderer | Forward+ | Forward+ works but is officially "not well optimized for XR." Mobile is the recommended path. |
| Global shader uniforms | Per-material set_shader_parameter() | Per-material requires references to each material. Global uniforms broadcast to all shaders automatically -- better for audio data that every visualizer needs. |
| OGG stems | WAV stems | WAV has no decode overhead (eliminates sync drift risk from decode timing) but 8x file size. Start with OGG, switch to WAV only if sync issues arise. |

**Installation:**
```
# Godot 4.6 stable (Standard build, NOT .NET)
# Download from https://godotengine.org/download/
# Use universal macOS build for editing on Mac

# Stem preparation (one-time, on desktop)
pip install demucs
demucs -n htdemucs track.mp3  # produces drums.wav, bass.wav, vocals.wav, other.wav
ffmpeg -i drums.wav -c:a libvorbis -q:a 5 drums.ogg  # repeat for each stem

# Skybox asset: install from Godot Asset Library (AllSky Free) or download space panorama from itch.io
```

## Architecture Patterns

### Recommended Project Structure
```
project.godot
default_bus_layout.tres          # 5 buses: Master, Drums, Bass, Vocals, Other
audio/
  stems/
    test_drums.ogg
    test_bass.ogg
    test_vocals.ogg
    test_other.ogg
scenes/
  main.tscn                      # Entry point, XR setup
  vr_scene.tscn                  # XROrigin3D + XRCamera3D + environment
  debug_overlay.tscn             # FFT visualization in VR (Label3D panels)
scripts/
  autoloads/
    audio_manager.gd             # AudioManager autoload (INF-01)
    shader_bridge.gd             # Shader uniform bridge (INF-02)
  main.gd                        # XR initialization + flat-screen fallback
  audio_data.gd                  # AudioData resource class (AUD-03)
shaders/
  test_reactive.gdshader         # Test shader that reacts to audio uniforms
assets/
  skybox/
    space_panorama.exr           # Deep space skybox texture
```

### Pattern 1: Dual-Mode Startup (XR + Flat Screen)
**What:** Detect OpenXR availability at startup. If XR is available, enable it. If not (macOS, no headset), fall back to standard 3D camera with mouse look.
**When to use:** Every run. This is the primary dev workflow pattern.
**Example:**
```gdscript
# main.gd - Source: Godot XR setup docs
extends Node3D

var xr_interface: XRInterface
var xr_active: bool = false

func _ready():
    xr_interface = XRServer.find_interface("OpenXR")
    if xr_interface and xr_interface.is_initialized():
        print("OpenXR initialized - VR mode active")
        DisplayServer.window_set_vsync_mode(DisplayServer.VSYNC_DISABLED)
        get_viewport().use_xr = true
        xr_active = true
    else:
        print("No XR runtime - flat screen preview mode")
        # Activate fallback camera with mouse look
        $FallbackCamera3D.current = true
```

### Pattern 2: AudioManager Autoload with Per-Bus FFT
**What:** Singleton that owns 4 AudioStreamPlayers, queries 4 spectrum analyzers per frame, and exposes normalized AudioData.
**When to use:** Core audio pipeline -- always running.
**Example:**
```gdscript
# audio_manager.gd - Source: Godot AudioEffectSpectrumAnalyzer docs
extends Node

# Bus indices (must match default_bus_layout.tres)
const BUS_DRUMS := 1
const BUS_BASS := 2
const BUS_VOCALS := 3
const BUS_OTHER := 4

# Spectrum analyzer instances (one per bus)
var analyzers: Array[AudioEffectSpectrumAnalyzerInstance] = []

# Per-stem audio data, updated every frame
var stem_data: Array[AudioData] = []

# Frequency band boundaries (Hz) for magnitude extraction
const BAND_EDGES := [20.0, 60.0, 250.0, 500.0, 2000.0, 4000.0, 6000.0, 11050.0]
const MIN_DB := 60.0

func _ready():
    for bus_idx in [BUS_DRUMS, BUS_BASS, BUS_VOCALS, BUS_OTHER]:
        # Effect index 0 = SpectrumAnalyzer on each bus
        var analyzer = AudioServer.get_bus_effect_instance(bus_idx, 0)
        analyzers.append(analyzer)
        stem_data.append(AudioData.new())

func _process(_delta: float):
    for i in range(analyzers.size()):
        _update_stem_data(analyzers[i], stem_data[i])
    _push_to_shader_bridge()

func _update_stem_data(analyzer: AudioEffectSpectrumAnalyzerInstance, data: AudioData):
    var total_energy := 0.0
    var peak_magnitude := 0.0
    var peak_freq := 0.0

    for band_idx in range(BAND_EDGES.size() - 1):
        var mag_vec = analyzer.get_magnitude_for_frequency_range(
            BAND_EDGES[band_idx], BAND_EDGES[band_idx + 1]
        )
        var raw = mag_vec.length()
        var db_normalized = clamp((MIN_DB + linear_to_db(raw)) / MIN_DB, 0.0, 1.0)

        # Exponential smoothing: fast attack, slow decay
        var smoothing = 0.3 if db_normalized > data.bands[band_idx] else 0.05
        data.bands[band_idx] = lerp(data.bands[band_idx], db_normalized, smoothing)

        total_energy += data.bands[band_idx]
        if data.bands[band_idx] > peak_magnitude:
            peak_magnitude = data.bands[band_idx]
            peak_freq = (BAND_EDGES[band_idx] + BAND_EDGES[band_idx + 1]) / 2.0

    data.energy = total_energy / (BAND_EDGES.size() - 1)
    data.peak_frequency = peak_freq
```

### Pattern 3: Global Shader Uniform Bridge
**What:** Push audio data as global shader uniforms every frame so ALL shaders can read it without material references.
**When to use:** INF-02 implementation. Every visualizer shader reads these uniforms.
**Example:**
```gdscript
# shader_bridge.gd - Source: Godot global shader uniforms docs
extends Node

# Call from AudioManager._process() after updating stem_data
func push_audio_data(stem_data: Array[AudioData]):
    for i in range(stem_data.size()):
        var prefix = ["drums", "bass", "vocals", "other"][i]
        RenderingServer.global_shader_parameter_set(
            prefix + "_energy", stem_data[i].energy
        )
        RenderingServer.global_shader_parameter_set(
            prefix + "_peak_freq", stem_data[i].peak_frequency
        )
        # Pack bands into a vector for compact transfer
        # 7 bands -> pack into 2 vec4s (with one unused slot)
        RenderingServer.global_shader_parameter_set(
            prefix + "_bands_low",
            Vector4(
                stem_data[i].bands[0], stem_data[i].bands[1],
                stem_data[i].bands[2], stem_data[i].bands[3]
            )
        )
        RenderingServer.global_shader_parameter_set(
            prefix + "_bands_high",
            Vector4(
                stem_data[i].bands[4], stem_data[i].bands[5],
                stem_data[i].bands[6], 0.0
            )
        )
```

```gdshader
// test_reactive.gdshader - consuming global uniforms
shader_type spatial;

global uniform float drums_energy;
global uniform float bass_energy;
global uniform vec4 drums_bands_low;

void fragment() {
    ALBEDO = vec3(drums_energy, bass_energy, 0.0);
    EMISSION = ALBEDO * 2.0;
}
```

### Pattern 4: AudioData Resource Class
**What:** Normalized struct holding per-stem audio analysis results.
**When to use:** Data contract between AudioManager and all consumers.
**Example:**
```gdscript
# audio_data.gd
class_name AudioData
extends RefCounted

## Overall energy level (0.0 - 1.0), average of all bands
var energy: float = 0.0
## Frequency of the loudest band (Hz)
var peak_frequency: float = 0.0
## Per-band magnitudes (0.0 - 1.0), 7 bands:
## [sub-bass, bass, low-mid, mid, upper-mid, presence, brilliance]
var bands: Array[float] = [0.0, 0.0, 0.0, 0.0, 0.0, 0.0, 0.0]
```

### Pattern 5: Stem Synchronization Guard
**What:** Start all 4 players simultaneously; periodically check for drift and resync.
**When to use:** Whenever stems are playing.
**Example:**
```gdscript
# In AudioManager
var players: Array[AudioStreamPlayer] = []
const SYNC_CHECK_INTERVAL := 1.0  # seconds
const MAX_DRIFT_MS := 10.0
var sync_timer := 0.0

func play_stems(drum_stream, bass_stream, vocal_stream, other_stream):
    var streams = [drum_stream, bass_stream, vocal_stream, other_stream]
    for i in range(4):
        players[i].stream = streams[i]
    # Start all on same frame
    for player in players:
        player.play()

func _process(delta):
    sync_timer += delta
    if sync_timer >= SYNC_CHECK_INTERVAL:
        sync_timer = 0.0
        _check_sync()

func _check_sync():
    var ref_pos = players[0].get_playback_position()
    for i in range(1, players.size()):
        var drift_ms = abs(players[i].get_playback_position() - ref_pos) * 1000.0
        if drift_ms > MAX_DRIFT_MS:
            players[i].seek(ref_pos)
            print("Resynced stem %d (drift: %.1fms)" % [i, drift_ms])
```

### Anti-Patterns to Avoid
- **Using Forward+ renderer for XR:** Official docs say "not well optimized for XR." Use Mobile renderer even for PCVR.
- **Raw FFT values as shader uniforms:** Causes twitchy/flickering visuals. Always smooth with exponential moving average.
- **Hardcoding bus indices:** Use AudioServer.get_bus_index("Drums") for safety; bus order can change.
- **Trying to run OpenXR on macOS for PCVR:** It does not work. Design for flat-screen preview on Mac.
- **Global uniform arrays:** Godot does not support arrays as global shader uniforms. Pack into vec4s instead.

## Don't Hand-Roll

| Problem | Don't Build | Use Instead | Why |
|---------|-------------|-------------|-----|
| FFT spectrum analysis | Custom FFT implementation | AudioEffectSpectrumAnalyzer (built-in) | Built into Godot's audio server. Runs on audio thread. Zero overhead to add per bus. |
| Audio bus routing | Manual audio routing code | default_bus_layout.tres + AudioServer | Godot's audio bus system handles routing, effects chains, and mixing natively. |
| VR camera/tracking | Custom head tracking | XROrigin3D + XRCamera3D (built-in) | OpenXR handles all tracking. Just add the nodes. |
| Skybox rendering | Custom skybox shader | PanoramaSkyMaterial + WorldEnvironment | Built-in panoramic sky with HDR support. Just assign a texture. |
| XR runtime detection | Custom platform detection | XRServer.find_interface("OpenXR") | Built-in API. Returns null if no XR runtime available. |

**Key insight:** Phase 1 uses almost exclusively Godot built-in features. The only custom code is AudioManager (FFT query + smoothing + normalization), the shader bridge (uniform pushing), and the AudioData struct.

## Common Pitfalls

### Pitfall 1: macOS Cannot Run PCVR
**What goes wrong:** Developer tries to run VR mode on Mac and gets black screen or "OpenXR not initialized" errors.
**Why it happens:** OpenXR PCVR requires SteamVR or Oculus runtime, neither available on macOS. Virtual Desktop PCVR streaming also requires Windows.
**How to avoid:** Build dual-mode from day one. Mac = flat-screen preview (no XR). Windows = VR testing with Virtual Desktop. All audio/shader work is XR-independent.
**Warning signs:** If you are trying to install SteamVR on Mac, stop.

### Pitfall 2: Forward+ Renderer for XR
**What goes wrong:** Default Godot project uses Forward+ renderer. XR runs but with poor performance or visual glitches.
**Why it happens:** Godot defaults to Forward+. The official XR docs explicitly say to use Mobile renderer instead.
**How to avoid:** Set `renderer/rendering_method = "mobile"` in project.godot BEFORE any other work.
**Warning signs:** Project settings show Forward+ while XR is enabled.

### Pitfall 3: FFT Jitter Making Visuals Twitchy
**What goes wrong:** Visualizer elements twitch and flicker because raw FFT magnitudes jump wildly frame-to-frame.
**Why it happens:** FFT is inherently noisy. Frame-to-frame variation is large.
**How to avoid:** Exponential moving average on ALL FFT values: fast attack (~0.3), slow decay (~0.05). Never pass raw FFT to shaders.
**Warning signs:** Visual elements look like they are vibrating rather than pulsing.

### Pitfall 4: Stem Synchronization Drift
**What goes wrong:** 4 AudioStreamPlayers gradually desync, causing audible phasing artifacts.
**Why it happens:** Independent OGG decoding, audio server chunk processing, tiny timing differences accumulate.
**How to avoid:** Start all players on same frame. Check sync every 1-2 seconds. Resync any player drifting >10ms from reference (drums).
**Warning signs:** Music sounds "thick" or "flangy" after 1-2 minutes of playback.

### Pitfall 5: AudioServer.get_bus_effect_instance Returns Null
**What goes wrong:** Spectrum analyzer instance is null, causing crash in _process.
**Why it happens:** Bus or effect index is wrong, or called before audio server is ready. Known Godot issue when called too early in _ready().
**How to avoid:** Use call_deferred() for initial setup, or check for null. Verify bus names match default_bus_layout.tres exactly.
**Warning signs:** Null reference error on first frame.

### Pitfall 6: Global Shader Parameters Not Visible in Editor
**What goes wrong:** Global uniforms added via RenderingServer.global_shader_parameter_add() at runtime don't appear in Project Settings.
**Why it happens:** Known Godot behavior -- runtime-added globals aren't synced to the editor.
**How to avoid:** Pre-define all global shader uniforms in Project Settings > Shader Globals BEFORE writing shaders. Then update values at runtime with RenderingServer.global_shader_parameter_set().
**Warning signs:** Shader shows "uniform not found" errors in editor.

## Code Examples

### Audio Bus Layout (default_bus_layout.tres)
Configure in Godot editor's Audio tab at bottom of screen:
```
Master (bus 0)
  |- Drums (bus 1)  -> AudioEffectSpectrumAnalyzer (FFT 2048)
  |- Bass (bus 2)   -> AudioEffectSpectrumAnalyzer (FFT 2048)
  |- Vocals (bus 3) -> AudioEffectSpectrumAnalyzer (FFT 2048)
  |- Other (bus 4)  -> AudioEffectSpectrumAnalyzer (FFT 2048)
```
Each stem bus routes to Master. FFT size 2048 balances frequency resolution and latency.

### VR Scene Setup
```
vr_scene.tscn:
  Node3D (root)
    WorldEnvironment
      - Environment with PanoramaSkyMaterial (space panorama)
      - Ambient light: low intensity, slight blue tint
    XROrigin3D
      XRCamera3D (y: 1.7)
      XRController3D (left, tracker: left_hand)
      XRController3D (right, tracker: right_hand)
    FallbackCamera3D (for flat-screen mode, y: 1.7)
    TestReactiveMesh
      - MeshInstance3D with ShaderMaterial using test_reactive.gdshader
    DebugOverlay (Node3D)
      - Label3D nodes showing FFT values per stem
```

### Debug Overlay for FFT Verification (VR)
```gdscript
# debug_overlay.gd
extends Node3D

@export var audio_manager: AudioManager
var labels: Array[Label3D] = []
const STEM_NAMES = ["Drums", "Bass", "Vocals", "Other"]

func _ready():
    for i in range(4):
        var label = Label3D.new()
        label.position = Vector3(-1.5 + i * 1.0, 2.0, -2.0)
        label.font_size = 32
        label.modulate = Color.WHITE
        label.billboard = BaseMaterial3D.BILLBOARD_ENABLED
        add_child(label)
        labels.append(label)

func _process(_delta):
    for i in range(4):
        var data = audio_manager.stem_data[i]
        labels[i].text = "%s\nE: %.2f\nPk: %.0f Hz\nB: %s" % [
            STEM_NAMES[i],
            data.energy,
            data.peak_frequency,
            _format_bands(data.bands)
        ]

func _format_bands(bands: Array[float]) -> String:
    var bars = ""
    for b in bands:
        var filled = int(b * 5)
        bars += "|" + "#".repeat(filled) + ".".repeat(5 - filled) + "| "
    return bars
```

### Global Shader Uniform Setup (Project Settings)
Define these in Project Settings > Shader Globals before implementation:
```
drums_energy:     float = 0.0
drums_peak_freq:  float = 0.0
drums_bands_low:  vec4 = (0, 0, 0, 0)
drums_bands_high: vec4 = (0, 0, 0, 0)
bass_energy:      float = 0.0
bass_peak_freq:   float = 0.0
bass_bands_low:   vec4 = (0, 0, 0, 0)
bass_bands_high:  vec4 = (0, 0, 0, 0)
vocals_energy:    float = 0.0
vocals_peak_freq: float = 0.0
vocals_bands_low: vec4 = (0, 0, 0, 0)
vocals_bands_high:vec4 = (0, 0, 0, 0)
other_energy:     float = 0.0
other_peak_freq:  float = 0.0
other_bands_low:  vec4 = (0, 0, 0, 0)
other_bands_high: vec4 = (0, 0, 0, 0)
```
That is 16 global uniforms total (4 per stem x 4 stems). Well within limits.

## State of the Art

| Old Approach | Current Approach | When Changed | Impact |
|--------------|------------------|--------------|--------|
| Forward+ for everything | Mobile renderer for XR | Godot 4.x XR docs (ongoing) | Mobile is the official XR recommendation, even for desktop VR |
| OpenXR as plugin | OpenXR in Godot core | Godot 4.0 (2023) | No plugin installation needed for PCVR |
| Godot 3.x XR | Godot 4.6 XR | Jan 2026 | OpenXR 1.1 auto-enable, spatial anchors, improved stability |
| Per-material uniforms for shared data | Global shader uniforms | Godot 4.0 (2023) | Broadcast data to all shaders without material references |

**Deprecated/outdated:**
- Forward+ for XR: Still works but officially not recommended
- Godot XR Tools for basic setup: XR is now in core; XR Tools only needed for interaction features (teleport, grab, etc.)

## Open Questions

1. **macOS + PCVR Workflow**
   - What we know: OpenXR does not work on macOS. Virtual Desktop PCVR requires Windows. SteamVR dropped macOS in 2020.
   - What's unclear: Does the user have access to a Windows machine for VR testing? Or will they deploy directly to Quest as standalone for VR verification?
   - Recommendation: Design flat-screen preview mode as the primary dev workflow. Flag this to the user -- VR testing requires a Windows machine or Quest standalone deployment.

2. **Renderer Correction from Prior Research**
   - What we know: The SUMMARY.md and STACK.md from prior research recommend Forward+ renderer for PCVR. The official Godot XR documentation explicitly recommends Mobile renderer for desktop VR.
   - Recommendation: Use Mobile renderer. The official docs are authoritative. Forward+ "isn't well optimized for XR right now."

3. **AudioEffectSpectrumAnalyzer FFT Jitter (Known Godot Issue)**
   - What we know: GitHub issue #67650 documents jitter in get_magnitude_for_frequency_range values. Still open.
   - Recommendation: Aggressive smoothing (exponential moving average) is mandatory. This is not optional polish -- raw values are unusable for visualization.

4. **Global Shader Uniform Texture Bug**
   - What we know: GitHub issue #80558 documents sampler2D global uniforms not updating correctly (Godot 4.1.1). May be fixed in 4.6.
   - Recommendation: Use float/vec4 global uniforms only (not textures) for audio data. This is sufficient -- 16 uniforms covers all 4 stems.

## Validation Architecture

### Test Framework
| Property | Value |
|----------|-------|
| Framework | Godot built-in + manual verification |
| Config file | project.godot (no separate test config) |
| Quick run command | Run scene in Godot editor (F5) |
| Full suite command | Manual checklist (VR scene on headset) |

### Phase Requirements to Test Map
| Req ID | Behavior | Test Type | Automated Command | File Exists? |
|--------|----------|-----------|-------------------|-------------|
| AUD-01 | 4 audio streams play simultaneously on separate buses | manual + audio | Play scene, verify 4 AudioStreamPlayers active | Wave 0 |
| AUD-02 | Per-bus FFT data updates every frame | manual | Debug overlay shows non-zero, varying FFT values | Wave 0 |
| AUD-03 | AudioData struct exposes energy, peak freq, bands | unit | GDScript test: create AudioData, verify properties | Wave 0 |
| VR-01 | PCVR app displays VR scene on Quest 3 | manual | Deploy to Windows + Virtual Desktop, verify stereo rendering | Wave 0 |
| VR-02 | Stable 90fps | manual | Godot profiler, frame time < 11ms | Wave 0 |
| VR-03 | Comfortable VR, static viewpoint | manual | Verify no forced movement, static origin | Wave 0 |
| INF-01 | AudioManager autoload provides data every frame | integration | Run scene, verify debug overlay updates each frame | Wave 0 |
| INF-02 | Shader uniforms update per frame, test shader reacts | visual | Test reactive mesh visibly changes with music | Wave 0 |

### Sampling Rate
- **Per task commit:** Run scene in editor (F5), verify audio plays and debug overlay shows data
- **Per wave merge:** Full checklist: flat-screen mode works, VR mode works (if Windows available), all 4 stems audible, FFT data visible, test shader reacts
- **Phase gate:** VR verification on Quest 3 via Virtual Desktop -- all 5 success criteria confirmed

### Wave 0 Gaps
- [ ] Godot project does not exist yet -- must be created from scratch
- [ ] default_bus_layout.tres -- 5 buses with spectrum analyzers
- [ ] Test stem files (4x OGG) -- must be prepared with Demucs
- [ ] Global shader uniforms -- must be defined in Project Settings
- [ ] No automated test framework -- Godot lacks built-in unit testing for GDScript; manual verification is standard

## Sources

### Primary (HIGH confidence)
- [Godot XR Setup Docs](https://docs.godotengine.org/en/stable/tutorials/xr/setting_up_xr.html) - Renderer recommendation (Mobile for XR), XR scene setup, startup script
- [AudioEffectSpectrumAnalyzerInstance Docs](https://docs.godotengine.org/en/stable/classes/class_audioeffectspectrumanalyzerinstance.html) - get_magnitude_for_frequency_range API, MAGNITUDE_MAX/AVERAGE modes
- [AudioEffectSpectrumAnalyzer Docs](https://docs.godotengine.org/en/stable/classes/class_audioeffectspectrumanalyzer.html) - FFT size options, buffer_length config
- [Godot Audio Buses Docs](https://docs.godotengine.org/en/stable/tutorials/audio/audio_buses.html) - Bus layout, effect chains, AudioServer API
- [Godot Global Shader Uniforms Article](https://godotengine.org/article/godot-40-gets-global-and-instance-shader-uniforms/) - Global uniform API, RenderingServer methods
- [Godot 4.6 Release](https://gamefromscratch.com/godot-4-6-released/) - Release confirmation, Jan 2026

### Secondary (MEDIUM confidence)
- [Virtual Desktop macOS Limitation](https://www.uploadvr.com/virtual-desktop-macos-streamer-update/) - PCVR streaming not available on macOS
- [AudioEffectSpectrumAnalyzer Jitter Issue #67650](https://github.com/godotengine/godot/issues/67650) - Known FFT jitter, smoothing required
- [Global Shader Uniform Runtime Addition Issue #77988](https://github.com/godotengine/godot/issues/77988) - Must pre-define in Project Settings
- [AllSky Free Godot Asset](https://godotengine.org/asset-library/asset/579) - Free skybox pack with panorama textures
- [XR Debug Konsole Plugin](https://godotengine.org/asset-library/asset/3205) - VR debug text overlay

### Tertiary (LOW confidence)
- [SteamVR macOS Dropped](https://9to5mac.com/2020/05/01/valves-steamvr-ends-support-for-macos-after-being-introduced-at-wwdc-2017/) - 2020 announcement, confirms no Mac PCVR path
- [Godot Global Uniform Array Proposal #9553](https://github.com/godotengine/godot-proposals/discussions/9553) - No array support, must use vec4 packing

## Metadata

**Confidence breakdown:**
- Standard stack: HIGH - Official Godot docs, confirmed versions, built-in features
- Architecture: HIGH - Standard Godot patterns (autoloads, audio buses, shader uniforms)
- Audio pipeline: HIGH - Built-in AudioEffectSpectrumAnalyzer, well-documented API
- macOS limitation: HIGH - Multiple sources confirm no OpenXR/PCVR on Mac
- Pitfalls: MEDIUM-HIGH - Mix of official docs and community reports; FFT jitter is a known Godot issue
- Shader bridge: MEDIUM - Global uniforms work but have known edge cases with textures/runtime addition

**Research date:** 2026-04-13
**Valid until:** 2026-05-13 (Godot 4.6 is stable; no major changes expected in 30 days)
