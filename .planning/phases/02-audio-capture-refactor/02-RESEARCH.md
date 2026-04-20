# Phase 2: Audio Capture Refactor - Research

**Researched:** 2026-04-19
**Domain:** Godot 4.6 audio input via BlackHole, single-bus FFT analysis, shader uniform refactor
**Confidence:** HIGH

## Summary

Phase 2 replaces the 4-stem audio pipeline (Drums/Bass/Vocals/Other buses with separate AudioStreamPlayers) with a single BlackHole capture bus using AudioStreamMicrophone. The core FFT analysis logic (`get_magnitude_for_frequency_range()` with 7 bands, exponential smoothing) carries forward nearly unchanged -- it just reads from one analyzer instead of four. ShaderBridge collapses from 16 stem-named uniforms to a smaller set of band-named uniforms, and the debug overlay is reworked for single-source display with signal status.

The existing research in `.planning/research/` (STACK.md, ARCHITECTURE.md, PITFALLS.md) already covers this domain thoroughly. This phase-specific research validates those findings against the actual codebase, confirms API details, and adds implementation-specific guidance for the planner.

**Primary recommendation:** Refactor in strict dependency order: bus layout first, then AudioManager, then ShaderBridge + project.godot globals, then debug overlay + test shader. Each step is independently testable.

<user_constraints>
## User Constraints (from CONTEXT.md)

### Locked Decisions
- BlackHole is the only audio input path -- no local file playback fallback
- Auto-detect BlackHole on startup: check if "BlackHole 2ch" is in the audio device list, warn with setup instructions if missing
- `stem_loader.gd` kept but disabled (renamed to `_stem_loader_legacy.gd` or similar) -- not wired into the scene, preserved for reference
- Old test stem WAV files can stay in `audio/stems/` but are not loaded
- Collapse 7 FFT bands into 4 visual channel groups:
  - **LOW** = sub-bass + bass (20-250Hz)
  - **MID_LOW** = low-mid + mid (250-2kHz)
  - **MID_HIGH** = upper-mid + presence (2-6kHz)
  - **HIGH** = brilliance (6-11kHz)
- Expose BOTH levels to shaders: 4 grouped channels AND 7 raw bands
- This is the data contract for Phases 3-4
- When no audio is playing: scene renders with subtle ambient idle animation (not frozen, not fake reactivity)
- Debug overlay shows signal status: "Listening on BlackHole 2ch" or "No signal detected" alongside FFT bars
- Zero FFT data = subtle idle state

### Claude's Discretion
- Exact shader uniform naming convention for the new band groups
- AudioData struct internal changes (single instance vs. array)
- Bus layout architecture (single "Capture" bus with AudioStreamMicrophone)
- How to mute the capture bus to prevent feedback while keeping SpectrumAnalyzer active
- Debug overlay layout changes for single-source display
- Exact idle animation behavior (drift speed, what moves)

### Deferred Ideas (OUT OF SCOPE)
None -- discussion stayed within phase scope.
</user_constraints>

<phase_requirements>
## Phase Requirements

| ID | Description | Research Support |
|----|-------------|-----------------|
| AUD-04 | System audio captured via BlackHole virtual audio device into Godot | BlackHole + AudioStreamMicrophone pattern verified; macOS mic fix confirmed merged for 4.6; bus layout and muting strategy documented |
| AUD-05 | AudioManager refactored from 4-stem buses to single capture bus with FFT analysis | Existing `_update_stem_data()` FFT logic reusable; single AudioData instance replaces array; sync logic removed; BlackHole auto-detection pattern provided |
| AUD-06 | ShaderBridge updated with frequency-band uniforms from single audio source | New uniform naming convention designed (7 raw bands + 4 grouped channels); project.godot shader_globals replacement mapped |
| AUD-07 | Any desktop audio source visualized without app-specific integration | BlackHole captures ALL system audio by design; Multi-Output Device setup ensures user hears audio simultaneously; zero app-specific code needed |
</phase_requirements>

## Standard Stack

### Core (All Godot Built-in -- No External Dependencies)

| Component | Version | Purpose | Why Standard |
|-----------|---------|---------|--------------|
| BlackHole 2ch | 0.6.0+ | macOS virtual audio loopback | Routes any desktop audio into Godot as input device. Free, zero-latency, maintained. Install via `brew install blackhole-2ch` |
| AudioStreamMicrophone | Godot 4.6 built-in | Captures audio input into Godot bus | Treats BlackHole as mic input. Stable API since Godot 4.0. macOS fix merged for 4.6 (PR #111691) |
| AudioEffectSpectrumAnalyzer | Godot 4.6 built-in | FFT on capture bus | Same component as v1.0. FFT size 2048 (enum 3), buffer 0.1s |
| AudioServer | Godot 4.6 built-in | Input device selection | `input_device` property, `get_input_device_list()` method |

### Supporting

| Component | Purpose | When to Use |
|-----------|---------|-------------|
| macOS Multi-Output Device | Hear audio AND capture simultaneously | One-time OS-level setup. Required for user to hear music while Godot captures it |
| RenderingServer.global_shader_parameter_set() | Push audio data to GPU | Same pattern as v1.0, fewer uniforms |

### What NOT to Add

| Technology | Why Avoid |
|------------|-----------|
| AudioEffectCapture | Not needed -- we want FFT magnitudes, not raw PCM. SpectrumAnalyzer provides that directly |
| GDExtension/C++ for audio | Premature optimization. Single-stream FFT in GDScript is trivial |
| Third-party audio plugins | Adds dependency risk for ~100 lines of GDScript work |

**Installation:**
```bash
# One-time macOS setup (not a Godot dependency)
brew install blackhole-2ch
# Then: Audio MIDI Setup > Create Multi-Output Device > check speakers + BlackHole 2ch
```

## Architecture Patterns

### Recommended Refactor Structure

Files modified (not new files created):
```
scripts/
  audio_data.gd              # MODIFY: add grouped channels, no-signal flag
  autoloads/
    audio_manager.gd          # REWRITE: single mic input, single FFT, BlackHole detection
    shader_bridge.gd          # REWRITE: band-named uniforms instead of stem-named
  debug_overlay.gd            # REWRITE: single-source display, signal status
  stem_loader.gd              # RENAME to _stem_loader_legacy.gd

shaders/
  test_reactive.gdshader      # MODIFY: new uniform names

default_bus_layout.tres        # REWRITE: single Capture bus replaces 4 stem buses
project.godot                  # MODIFY: new shader_globals, enable audio input
```

### Pattern 1: BlackHole Auto-Detection with Graceful Degradation

**What:** On startup, scan input devices for BlackHole. If found, set as input device and start capture. If not found, print setup instructions and enter idle state.
**When to use:** Always -- this is the startup flow.

```gdscript
# AudioManager._initialize()
func _initialize() -> void:
    var devices := AudioServer.get_input_device_list()
    var blackhole_device := ""
    for device in devices:
        if "BlackHole" in device:
            blackhole_device = device
            break

    if blackhole_device.is_empty():
        push_warning("BlackHole 2ch not found. Install: brew install blackhole-2ch")
        push_warning("Then create Multi-Output Device in Audio MIDI Setup")
        _has_signal = false
        return

    AudioServer.input_device = blackhole_device

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
    _is_capturing = true
```

**Source:** [Godot AudioServer docs](https://docs.godotengine.org/en/stable/classes/class_audioserver.html), [Recording with Microphone tutorial](https://docs.godotengine.org/en/stable/tutorials/audio/recording_with_microphone.html)

### Pattern 2: Muting Capture Bus to Prevent Feedback

**What:** The Capture bus must NOT route audio to speakers. Godot would re-output the captured audio, causing echo/feedback.
**Recommended approach:** Set Capture bus volume to -80 dB (effectively silent) while keeping SpectrumAnalyzer active. The SpectrumAnalyzer processes audio BEFORE the bus volume is applied, so FFT data is unaffected by muting.

```gdscript
# In _initialize(), after setting up capture:
var capture_bus_idx := AudioServer.get_bus_index("Capture")
AudioServer.set_bus_volume_db(capture_bus_idx, -80.0)
```

**Alternative:** Set Capture bus mute = true. However, muting a bus may also disable effects on some platforms. Testing needed -- volume at -80dB is the safer approach.

**Key insight:** The user hears music through the macOS Multi-Output Device (speakers path). Godot is listen-only. The Master bus does NOT need to be muted -- only the Capture bus.

### Pattern 3: Dual-Level Band Exposure (7 Raw + 4 Grouped)

**What:** AudioData stores 7 raw FFT bands (existing). AudioManager also computes 4 grouped channels by averaging raw bands. Both are exposed to shaders.
**Why:** Raw bands for detailed visualizations (spectrum bars). Grouped channels for broad visual mapping (warp effects, color zones).

```gdscript
# AudioData additions
var bands: Array[float] = [0.0, 0.0, 0.0, 0.0, 0.0, 0.0, 0.0]  # existing 7 raw
var grouped: Array[float] = [0.0, 0.0, 0.0, 0.0]  # NEW: LOW, MID_LOW, MID_HIGH, HIGH

# In AudioManager._process() after updating bands:
_audio_data.grouped[0] = (_audio_data.bands[0] + _audio_data.bands[1]) / 2.0   # LOW
_audio_data.grouped[1] = (_audio_data.bands[2] + _audio_data.bands[3]) / 2.0   # MID_LOW
_audio_data.grouped[2] = (_audio_data.bands[4] + _audio_data.bands[5]) / 2.0   # MID_HIGH
_audio_data.grouped[3] = _audio_data.bands[6]                                   # HIGH
```

### Pattern 4: No-Signal Detection

**What:** Track whether FFT is producing non-zero data. After N frames of near-zero energy, flag as no-signal.
**When to use:** Always. Drives the idle animation vs. reactive animation distinction.

```gdscript
const NO_SIGNAL_THRESHOLD: float = 0.001
const NO_SIGNAL_FRAMES: int = 30  # ~0.5s at 60fps

var _silent_frames: int = 0
var has_signal: bool = false

# In _process():
if _audio_data.energy < NO_SIGNAL_THRESHOLD:
    _silent_frames += 1
    if _silent_frames >= NO_SIGNAL_FRAMES:
        has_signal = false
else:
    _silent_frames = 0
    has_signal = true
```

### Anti-Patterns to Avoid
- **Keeping stem architecture alongside new code:** No `if is_stem_mode:` branches. Clean break. Old code goes to `_stem_loader_legacy.gd`.
- **Routing captured audio through Godot speakers:** Causes feedback. Mute the Capture bus.
- **Setting BlackHole as system output directly:** Kills speaker audio. Must use Multi-Output Device.
- **Hardcoding "BlackHole 2ch" exactly:** Use substring match (`"BlackHole" in device`) to handle minor naming variations.

## Shader Uniform Design

### Recommended Naming Convention

**Raw bands (7 floats packed into 2 vec4s):**
```
audio_bands_low   (vec4) = sub_bass, bass, low_mid, mid
audio_bands_high  (vec4) = upper_mid, presence, brilliance, 0.0
```

**Grouped channels (4 floats packed into 1 vec4):**
```
audio_channels    (vec4) = LOW, MID_LOW, MID_HIGH, HIGH
```

**Aggregate values:**
```
audio_energy      (float) = overall energy 0-1
audio_peak_freq   (float) = dominant frequency Hz
```

**Total: 5 global uniforms** (down from 16 stem-based). Well within Godot's global uniform budget.

### project.godot Shader Globals (Replacement)

Remove all 16 `drums_*`, `bass_*`, `vocals_*`, `other_*` entries. Replace with:

```ini
[shader_globals]

audio_energy={"type": "float", "value": 0.0}
audio_peak_freq={"type": "float", "value": 0.0}
audio_bands_low={"type": "vec4", "value": Vector4(0, 0, 0, 0)}
audio_bands_high={"type": "vec4", "value": Vector4(0, 0, 0, 0)}
audio_channels={"type": "vec4", "value": Vector4(0, 0, 0, 0)}
```

### Test Reactive Shader Update

```glsl
shader_type spatial;
render_mode unshaded;

global uniform float audio_energy;
global uniform vec4 audio_bands_low;
global uniform vec4 audio_channels;

void fragment() {
    // Color driven by grouped channels
    vec3 color = vec3(audio_channels.x, audio_channels.y, audio_channels.w);
    float pulse = audio_bands_low.x * 0.5;  // sub-bass pulse
    ALBEDO = color + vec3(pulse);
    EMISSION = color * 2.0 + vec3(pulse) * 3.0;
}

void vertex() {
    float scale_factor = 1.0 + audio_energy * 0.3;
    VERTEX *= scale_factor;
}
```

## Don't Hand-Roll

| Problem | Don't Build | Use Instead | Why |
|---------|-------------|-------------|-----|
| FFT analysis | Custom FFT | AudioEffectSpectrumAnalyzer (built-in) | Already on the audio thread, zero overhead to use |
| Audio loopback | Custom audio routing | BlackHole 2ch + Multi-Output Device | OS-level solution, zero latency, battle-tested |
| dB normalization | Custom dB math | Existing `linear_to_db()` + clamping (already in AudioManager) | Already working, well-tuned |
| Smoothing | Custom filter | Existing exponential smoothing (attack 0.3 / decay 0.05) | Already tuned for music visualization |

## Common Pitfalls

### Pitfall 1: macOS Audio Input Device Bug
**What goes wrong:** AudioStreamMicrophone fails with AudioUnitRender errors when using non-default input device.
**Why it happens:** Long-standing Godot macOS bug. PR #111691 merged for 4.6 fixes mic initialization.
**How to avoid:** Use Godot 4.6 (confirmed fix merged). Set BlackHole as default macOS input device in System Settings before launching Godot as additional safety. Match Godot mix rate (48000) to BlackHole sample rate (48000).
**Warning signs:** Console spam of `AudioUnitRender failed`. SpectrumAnalyzer returning all zeros.

### Pitfall 2: Capture Bus Feedback Loop
**What goes wrong:** Captured audio plays back through Godot speakers, creating echo or feedback.
**Why it happens:** Capture bus sends to Master, Master outputs to speakers. Captured BlackHole audio gets re-output.
**How to avoid:** Set Capture bus volume to -80 dB. SpectrumAnalyzer still processes audio before volume is applied.
**Warning signs:** Echo of music playing, doubling of audio.

### Pitfall 3: SpectrumAnalyzer Returns Null on Startup
**What goes wrong:** `AudioServer.get_bus_effect_instance()` returns null, causing errors in `_process()`.
**Why it happens:** AudioServer not fully initialized when `_ready()` runs. Known Godot timing issue.
**How to avoid:** Use `call_deferred("_initialize")` pattern (already in existing code). Add null check on `_analyzer` in `_process()`.
**Warning signs:** Null reference errors on first few frames.

### Pitfall 4: BlackHole Not Detected After Install
**What goes wrong:** `get_input_device_list()` doesn't include BlackHole even though it's installed.
**Why it happens:** BlackHole requires system restart or at minimum re-login after install. Also requires `audio/driver/enable_input = true` in project settings.
**How to avoid:** Document post-install restart requirement. Check `enable_input` is set. Auto-detect with graceful fallback and clear error message.
**Warning signs:** Empty device list or list without BlackHole entry.

### Pitfall 5: Bus Mute vs Volume for Silencing
**What goes wrong:** Using `AudioServer.set_bus_mute(idx, true)` may disable SpectrumAnalyzer processing on some platforms.
**Why it happens:** Mute behavior varies by audio driver implementation. Some drivers skip effect processing on muted buses.
**How to avoid:** Use volume -80 dB instead of mute. This is inaudible but keeps effects active.
**Warning signs:** FFT data goes to zero when bus is muted, returns when unmuted.

## Bus Layout Design

### New default_bus_layout.tres

Replace all 4 stem buses with a single Capture bus:

```
Master (bus 0)
  - Default output bus (unchanged)

Capture (bus 1)
  - AudioEffectSpectrumAnalyzer (FFT 2048, buffer 0.1s)
  - volume_db = -80.0 (silent, prevents feedback)
  - send = "Master"
```

The `.tres` file format:
```
[gd_resource type="AudioBusLayout" format=3]

[sub_resource type="AudioEffectSpectrumAnalyzer" id="1"]
buffer_length = 0.1
fft_size = 3

[resource]
bus/1/name = &"Capture"
bus/1/solo = false
bus/1/mute = false
bus/1/bypass_fx = false
bus/1/volume_db = -80.0
bus/1/send = &"Master"
bus/1/effect/0/effect = SubResource("1")
bus/1/effect/0/enabled = true
```

## Debug Overlay Redesign

### Current State
- 4 Label3D nodes showing per-stem data (Drums/Bass/Vocals/Other)
- Each shows energy, peak freq, 7-band bar chart

### New Design
- 1 Label3D node showing single-source FFT data
- Signal status line: "Listening on BlackHole 2ch" / "No signal detected"
- 7-band bar chart with band names
- 4 grouped channel indicators (LOW/MID_LOW/MID_HIGH/HIGH)
- Overall energy display

## project.godot Changes

### Add Audio Input Setting
```ini
[audio]
driver/enable_input=true
```

### Replace Shader Globals
Remove all 16 stem-based globals. Add 5 band-based globals (see Shader Uniform Design section above).

## Code Examples

### Complete AudioManager Refactor (Key Methods)

```gdscript
extends Node

const BAND_EDGES: Array[float] = [20.0, 60.0, 250.0, 500.0, 2000.0, 4000.0, 6000.0, 11050.0]
const MIN_DB: float = 60.0
const NO_SIGNAL_THRESHOLD: float = 0.001
const NO_SIGNAL_FRAMES: int = 30

var _analyzer: AudioEffectSpectrumAnalyzerInstance
var audio_data: AudioData  # Public API (was stem_data array)
var has_signal: bool = false
var _is_capturing: bool = false
var _silent_frames: int = 0
var _capture_device: String = ""

func _ready() -> void:
    call_deferred("_initialize")

func _initialize() -> void:
    audio_data = AudioData.new()

    var devices := AudioServer.get_input_device_list()
    for device in devices:
        if "BlackHole" in device:
            _capture_device = device
            break

    if _capture_device.is_empty():
        push_warning("BlackHole not found in audio devices: %s" % str(devices))
        return

    AudioServer.input_device = _capture_device

    var player := AudioStreamPlayer.new()
    player.stream = AudioStreamMicrophone.new()
    player.bus = "Capture"
    add_child(player)
    player.play()

    var bus_idx := AudioServer.get_bus_index("Capture")
    if bus_idx == -1:
        push_error("Capture bus not found in bus layout")
        return

    # Mute capture bus to prevent feedback (volume, not mute flag)
    AudioServer.set_bus_volume_db(bus_idx, -80.0)

    _analyzer = AudioServer.get_bus_effect_instance(bus_idx, 0)
    if _analyzer == null:
        push_error("No SpectrumAnalyzer on Capture bus")
        return

    _is_capturing = true

func _process(_delta: float) -> void:
    if not _is_capturing or _analyzer == null:
        return
    _update_audio_data(_analyzer, audio_data)
    _update_signal_status()

func _update_audio_data(analyzer: AudioEffectSpectrumAnalyzerInstance, data: AudioData) -> void:
    # Same proven FFT logic from v1.0, just on single analyzer
    var total_energy: float = 0.0
    var peak_magnitude: float = 0.0
    var peak_freq: float = 0.0

    for band_idx in range(BAND_EDGES.size() - 1):
        var mag_vec: Vector2 = analyzer.get_magnitude_for_frequency_range(
            BAND_EDGES[band_idx], BAND_EDGES[band_idx + 1]
        )
        var raw: float = mag_vec.length()
        var db_normalized: float = clampf((MIN_DB + linear_to_db(raw)) / MIN_DB, 0.0, 1.0)
        var smoothing: float = 0.3 if db_normalized > data.bands[band_idx] else 0.05
        data.bands[band_idx] = lerpf(data.bands[band_idx], db_normalized, smoothing)
        total_energy += data.bands[band_idx]
        if data.bands[band_idx] > peak_magnitude:
            peak_magnitude = data.bands[band_idx]
            peak_freq = (BAND_EDGES[band_idx] + BAND_EDGES[band_idx + 1]) / 2.0

    data.energy = total_energy / (BAND_EDGES.size() - 1)
    data.peak_frequency = peak_freq

    # Compute grouped channels
    data.grouped[0] = (data.bands[0] + data.bands[1]) / 2.0   # LOW
    data.grouped[1] = (data.bands[2] + data.bands[3]) / 2.0   # MID_LOW
    data.grouped[2] = (data.bands[4] + data.bands[5]) / 2.0   # MID_HIGH
    data.grouped[3] = data.bands[6]                             # HIGH

func _update_signal_status() -> void:
    if audio_data.energy < NO_SIGNAL_THRESHOLD:
        _silent_frames += 1
        if _silent_frames >= NO_SIGNAL_FRAMES:
            has_signal = false
    else:
        _silent_frames = 0
        has_signal = true
```

**Source:** Existing `audio_manager.gd` FFT logic + [Godot AudioServer docs](https://docs.godotengine.org/en/stable/classes/class_audioserver.html)

### Complete ShaderBridge Refactor

```gdscript
extends Node

func _process(_delta: float) -> void:
    var data: AudioData = AudioManager.audio_data
    if data == null:
        return

    RenderingServer.global_shader_parameter_set("audio_energy", data.energy)
    RenderingServer.global_shader_parameter_set("audio_peak_freq", data.peak_frequency)
    RenderingServer.global_shader_parameter_set("audio_bands_low",
        Vector4(data.bands[0], data.bands[1], data.bands[2], data.bands[3]))
    RenderingServer.global_shader_parameter_set("audio_bands_high",
        Vector4(data.bands[4], data.bands[5], data.bands[6], 0.0))
    RenderingServer.global_shader_parameter_set("audio_channels",
        Vector4(data.grouped[0], data.grouped[1], data.grouped[2], data.grouped[3]))
```

## State of the Art

| Old Approach (v1.0) | New Approach (v2.0 Phase 2) | Impact |
|----------------------|-----------------------------|--------|
| 4 stem buses, 4 AudioStreamPlayers | 1 Capture bus, 1 AudioStreamMicrophone | Simpler architecture, works with any audio source |
| Per-stem AudioData array (4 instances) | Single AudioData instance | Simpler API surface |
| 16 shader globals (drums_*, bass_*, vocals_*, other_*) | 5 shader globals (audio_*) | Cleaner namespace, smaller uniform budget |
| Stem sync logic (drift detection, re-seeking) | Removed entirely | No sync needed for single source |
| stem_loader.gd loads WAV files | Disabled/renamed to _legacy | BlackHole handles all audio input |

## Validation Architecture

### Test Framework

| Property | Value |
|----------|-------|
| Framework | Manual validation (Godot project, no unit test framework) |
| Config file | None |
| Quick run command | `godot --path . 2>&1` (run project, observe debug overlay) |
| Full suite command | Manual checklist below |

### Phase Requirements to Test Map

| Req ID | Behavior | Test Type | Verification | File Exists? |
|--------|----------|-----------|-------------|-------------|
| AUD-04 | BlackHole audio captured into Godot | manual | Play Spotify, observe non-zero FFT in debug overlay | N/A |
| AUD-05 | Single capture bus replaces 4 stem buses | manual + code review | AudioManager has no STEM_NAMES, single _analyzer, single audio_data | N/A |
| AUD-06 | Band-named shader uniforms drive test shader | manual | test_reactive.gdshader visibly reacts to system audio | N/A |
| AUD-07 | Any desktop audio source works | manual | Test with Spotify, YouTube in browser, Tidal -- all produce FFT data | N/A |

### Manual Validation Checklist

1. **BlackHole detection:** Launch project with BlackHole installed -- console shows "Listening on BlackHole 2ch". Launch without BlackHole as default -- console shows warning with setup instructions.
2. **FFT data flows:** Play music in Spotify. Debug overlay shows non-zero energy and moving band bars.
3. **No feedback:** No echo or doubled audio from Godot speakers while capturing.
4. **Signal status:** Stop music. After ~0.5s, debug overlay shows "No signal detected". Resume music -- overlay returns to active display.
5. **Source agnostic:** Switch from Spotify to YouTube to Tidal. FFT data flows from all sources without any Godot changes.
6. **Grouped channels:** Debug overlay shows both 7 raw bands and 4 grouped channels. Grouped values correspond to expected band groupings.
7. **Shader reactivity:** Test reactive mesh visibly pulses/colors in response to music.
8. **Clean break:** No references to STEM_NAMES, drums_*, bass_*, vocals_*, other_* in active code.

### Sampling Rate
- **Per task:** Run project, play music, verify debug overlay shows FFT data
- **Per wave:** Full manual checklist above
- **Phase gate:** All 8 checklist items pass

### Wave 0 Gaps
- [ ] `audio/driver/enable_input=true` must be added to project.godot `[audio]` section
- [ ] Capture bus must be created in default_bus_layout.tres
- [ ] Old stem buses must be removed from default_bus_layout.tres

## Open Questions

1. **Bus mute vs. volume for SpectrumAnalyzer**
   - What we know: Volume at -80dB should keep effects active. Mute flag behavior varies by driver.
   - What's unclear: Whether macOS CoreAudio driver processes effects on muted buses.
   - Recommendation: Use volume -80dB (safer). Test mute behavior separately if desired.

2. **BlackHole sample rate matching**
   - What we know: Both Godot and BlackHole default to 48000Hz. Mismatch causes errors.
   - What's unclear: Whether Godot 4.6 handles sample rate mismatch gracefully.
   - Recommendation: Verify both are 48000Hz in Audio MIDI Setup. Document as setup requirement.

## Sources

### Primary (HIGH confidence)
- [Godot AudioServer docs](https://docs.godotengine.org/en/stable/classes/class_audioserver.html) -- `input_device`, `get_input_device_list()`, `enable_input`
- [Godot AudioStreamMicrophone docs](https://docs.godotengine.org/en/stable/classes/class_audiostreammicrophone.html) -- audio input stream class
- [Godot Recording with Microphone tutorial](https://docs.godotengine.org/en/stable/tutorials/audio/recording_with_microphone.html) -- setup pattern
- [Godot macOS mic fix (Issue #110624)](https://github.com/godotengine/godot/issues/110624) -- confirmed fixed in 4.6 via PR #111691
- Existing codebase: `audio_manager.gd`, `shader_bridge.gd`, `audio_data.gd`, `debug_overlay.gd`, `project.godot`

### Secondary (MEDIUM confidence)
- [Godot input device switching issue #75603](https://github.com/godotengine/godot/issues/75603) -- Windows WASAPI specific, macOS unaffected
- [BlackHole GitHub](https://github.com/ExistentialAudio/BlackHole) -- installation, Multi-Output Device setup
- `.planning/research/STACK.md`, `ARCHITECTURE.md`, `PITFALLS.md` -- prior project research

### Tertiary (LOW confidence)
- Bus mute vs. volume effect on SpectrumAnalyzer -- not officially documented, needs empirical testing

## Metadata

**Confidence breakdown:**
- Standard stack: HIGH -- all Godot built-in APIs, well-documented, macOS fix confirmed
- Architecture: HIGH -- straightforward refactor of existing working code, patterns validated in prior research
- Pitfalls: HIGH -- macOS audio bugs well-documented in Godot issue tracker, all with known fixes/workarounds
- Uniform design: HIGH -- follows existing pattern, just fewer uniforms with clearer names

**Research date:** 2026-04-19
**Valid until:** 2026-05-19 (stable domain, Godot 4.6 APIs unlikely to change)
