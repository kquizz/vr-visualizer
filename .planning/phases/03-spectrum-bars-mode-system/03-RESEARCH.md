# Phase 3: Spectrum Bars + Mode System - Research

**Researched:** 2026-04-19
**Domain:** Godot 4.6 3D visualization, scene management, emissive materials, Mobile renderer
**Confidence:** HIGH

## Summary

Phase 3 builds a 360-degree ring of glowing cylindrical spectrum bars driven by the 7-band FFT data from AudioManager, plus a ModeManager autoload that manages visualizer scene lifecycle. The technical domain is well-understood: Godot's built-in CylinderMesh, StandardMaterial3D with emission, and the existing glow post-processing in the VR scene provide everything needed. No external libraries required.

The ModeManager is a lightweight autoload that swaps child scenes under a designated container node in the scene tree. The spectrum bars mode reads `AudioManager.audio_data.bands[7]` each frame in `_process()` and scales bar height + emission energy accordingly. The Mobile renderer supports glow/bloom but requires tuned thresholds (HDR threshold below 1.0, increased glow_strength) to compensate for its lower dynamic range (max 2.0 vs Forward+'s 8.0+).

**Primary recommendation:** Use MeshInstance3D nodes with CylinderMesh resources and StandardMaterial3D (emission_enabled) for bars, arranged procedurally in a ring. ModeManager as an autoload singleton following the established AudioManager/ShaderBridge pattern.

<user_constraints>
## User Constraints (from CONTEXT.md)

### Locked Decisions
- Full 360-degree ring at ~3m radius, ~20-30 bars total distributed across 7 frequency bands
- Bass forward: sub-bass and bass directly in front, highs behind, clockwise ordering
- Bars grow from floor upward, towering scale 0.1m (rest) to 4-5m (peak)
- Glowing cylindrical pillars with emissive material and bloom
- Solid core with glow halo that intensifies with energy
- Dual motion: height scales with band magnitude + glow intensity/radius pulses with energy
- Bars are the primary light source in the deep space environment
- Warm-to-cool color gradient: Sub-Bass Deep Red (#FF1744), Bass Orange (#FF9100), Lo-Mid Yellow (#FFEA00), Mid Green (#00E676), Up-Mid Cyan (#00E5FF), Presence Blue (#2979FF), Brilliance Violet (#D500F9)
- Static color per band -- intensity affects glow brightness/radius only, not hue

### Claude's Discretion
- Exact bar width and spacing within the ring
- Ring radius fine-tuning for VR comfort
- Glow falloff curve and bloom parameters
- Floor reflection/ground plane treatment
- Bar mesh segment count (cylinder resolution)
- ModeManager architecture (scene loading, switching mechanism, lifecycle)
- Idle/no-signal animation for bars
- How to distribute ~20-30 bars across 7 bands (even vs weighted toward bass)

### Deferred Ideas (OUT OF SCOPE)
- Multiple color palettes / palette switching (tracked as POL-03)
- Ring rotation or orbital camera motion
- Floor reflections / ground plane effects
</user_constraints>

<phase_requirements>
## Phase Requirements

| ID | Description | Research Support |
|----|-------------|-----------------|
| VIS-01 | Spectrum bars mode renders spatial 3D bars in VR with one color per frequency band | CylinderMesh + StandardMaterial3D emission, procedural ring layout, band-to-color mapping |
| VIS-02 | Bar heights react in real-time to FFT magnitude data from corresponding frequency bands | _process() reads AudioManager.audio_data.bands[7], lerp height + emission energy per frame |
| INF-03 | ModeManager system loads and switches between visualizer mode scenes | Autoload singleton with PackedScene instantiation, child scene swap under container node |
</phase_requirements>

## Standard Stack

### Core
| Library/Class | Version | Purpose | Why Standard |
|---------------|---------|---------|--------------|
| CylinderMesh | Godot 4.6 built-in | Bar geometry | Built-in PrimitiveMesh, no custom geometry needed |
| MeshInstance3D | Godot 4.6 built-in | Holds bar mesh + material | Standard 3D rendering node |
| StandardMaterial3D | Godot 4.6 built-in | Emissive glow material per bar | Emission + glow without custom shaders |
| PackedScene | Godot 4.6 built-in | Mode scene loading | Standard Godot scene management |
| Environment (glow) | Godot 4.6 built-in | Post-process bloom | Already configured in vr_scene.tscn |

### Supporting
| Class | Purpose | When to Use |
|-------|---------|-------------|
| Node3D (base for mode scenes) | Root node for each visualizer mode | Every mode scene extends Node3D |
| Tween | Smooth transitions for idle animation | Idle pulse when has_signal == false |

### Alternatives Considered
| Instead of | Could Use | Tradeoff |
|------------|-----------|----------|
| StandardMaterial3D emission | Custom spatial shader | Shader gives more control but StandardMaterial3D is sufficient for phase 3; shaders can be added in polish |
| Individual MeshInstance3D per bar | MultiMeshInstance3D | MultiMesh is better for 100+ instances; 20-30 bars don't need it, and individual nodes allow per-bar material variation |
| CylinderMesh | ImmediateMesh / ArrayMesh | Custom geometry is unnecessary; CylinderMesh properties cover all needs |

## Architecture Patterns

### Recommended Project Structure
```
scripts/
  autoloads/
    mode_manager.gd         # New autoload singleton
scenes/
  modes/
    spectrum_bars.tscn      # Spectrum bars mode scene
    spectrum_bars.gd        # Script driving bar behavior
shaders/
  bar_glow.gdshader         # Optional: custom bar shader (if StandardMaterial3D is insufficient)
```

### Pattern 1: ModeManager Autoload
**What:** Singleton autoload that manages loading/unloading visualizer mode scenes under a container node.
**When to use:** Always -- this is the INF-03 requirement.

```gdscript
# scripts/autoloads/mode_manager.gd
extends Node

signal mode_changed(mode_name: String)

## Registry of available modes: name -> scene path
var _modes: Dictionary = {}
## Currently active mode instance
var _active_mode: Node = null
## Container node where modes are placed (set after scene tree ready)
var _container: Node3D = null

func _ready() -> void:
    call_deferred("_initialize")

func _initialize() -> void:
    # Register built-in modes
    register_mode("spectrum_bars", "res://scenes/modes/spectrum_bars.tscn")

func register_mode(mode_name: String, scene_path: String) -> void:
    _modes[mode_name] = scene_path

func set_container(container: Node3D) -> void:
    _container = container

func switch_to(mode_name: String) -> void:
    if not _modes.has(mode_name):
        push_error("ModeManager: Unknown mode '%s'" % mode_name)
        return
    if _container == null:
        push_error("ModeManager: No container set")
        return

    # Remove current mode
    if _active_mode != null:
        _container.remove_child(_active_mode)
        _active_mode.queue_free()
        _active_mode = null

    # Load and instantiate new mode
    var scene: PackedScene = load(_modes[mode_name])
    _active_mode = scene.instantiate()
    _container.add_child(_active_mode)
    mode_changed.emit(mode_name)

func get_active_mode_name() -> String:
    if _active_mode == null:
        return ""
    for key in _modes:
        # Match by scene file path
        if _active_mode.scene_file_path == _modes[key]:
            return key
    return ""
```

**Key design decisions:**
- Uses `load()` not `preload()` because mode paths are registered dynamically
- `queue_free()` on old mode -- no reason to keep in memory (only one active at a time)
- Container is set by main.gd after scene tree is ready (avoids hardcoded paths)
- Signal `mode_changed` for any UI/debug that needs to know

### Pattern 2: Spectrum Bars Scene
**What:** A self-contained scene that creates bars procedurally in `_ready()` and animates them in `_process()`.
**When to use:** The VIS-01 and VIS-02 implementation.

```gdscript
# scenes/modes/spectrum_bars.gd
extends Node3D

const BAND_COUNT: int = 7
const BAND_COLORS: Array[Color] = [
    Color("#FF1744"),  # Sub-Bass: Deep Red
    Color("#FF9100"),  # Bass: Orange
    Color("#FFEA00"),  # Lo-Mid: Yellow
    Color("#00E676"),  # Mid: Green
    Color("#00E5FF"),  # Up-Mid: Cyan
    Color("#2979FF"),  # Presence: Blue
    Color("#D500F9"),  # Brilliance: Violet
]

## Bar distribution per band (weighted toward bass for visual density)
const BARS_PER_BAND: Array[int] = [4, 5, 4, 4, 4, 3, 3]  # = 27 total

const RING_RADIUS: float = 3.0
const BAR_RADIUS: float = 0.12
const MIN_HEIGHT: float = 0.1
const MAX_HEIGHT: float = 5.0
const EMISSION_BASE: float = 2.0
const EMISSION_PEAK: float = 8.0

var _bars: Array[MeshInstance3D] = []
var _bar_bands: Array[int] = []  # Which band index each bar belongs to
var _materials: Array[StandardMaterial3D] = []

func _ready() -> void:
    _create_bars()

func _create_bars() -> void:
    var total_bars: int = 0
    for count in BARS_PER_BAND:
        total_bars += count

    var bar_index: int = 0
    var angle_step: float = TAU / total_bars

    for band_idx in range(BAND_COUNT):
        for _i in range(BARS_PER_BAND[band_idx]):
            # Offset so bass is forward (negative Z in Godot)
            var angle: float = bar_index * angle_step
            # Rotate 180 degrees so index 0 is in front (-Z direction)
            angle += PI

            var mesh_instance := MeshInstance3D.new()
            var cylinder := CylinderMesh.new()
            cylinder.top_radius = BAR_RADIUS
            cylinder.bottom_radius = BAR_RADIUS
            cylinder.height = MIN_HEIGHT
            cylinder.radial_segments = 16  # Low for performance, 20-30 bars
            cylinder.rings = 1
            mesh_instance.mesh = cylinder

            var mat := StandardMaterial3D.new()
            mat.emission_enabled = true
            mat.emission = BAND_COLORS[band_idx]
            mat.emission_energy_multiplier = EMISSION_BASE
            mat.albedo_color = BAND_COLORS[band_idx] * 0.3
            mesh_instance.material_override = mat

            # Position on ring, bars grow from y=0 upward
            var x: float = cos(angle) * RING_RADIUS
            var z: float = sin(angle) * RING_RADIUS
            mesh_instance.position = Vector3(x, MIN_HEIGHT / 2.0, z)

            add_child(mesh_instance)
            _bars.append(mesh_instance)
            _bar_bands.append(band_idx)
            _materials.append(mat)
            bar_index += 1

func _process(_delta: float) -> void:
    var data: AudioData = AudioManager.audio_data
    if data == null:
        return

    for i in range(_bars.size()):
        var band_idx: int = _bar_bands[i]
        var magnitude: float = data.bands[band_idx]

        # Height: lerp between min and max
        var target_height: float = lerpf(MIN_HEIGHT, MAX_HEIGHT, magnitude)
        var cylinder: CylinderMesh = _bars[i].mesh as CylinderMesh
        cylinder.height = target_height

        # Reposition so bar grows from floor (y=0)
        _bars[i].position.y = target_height / 2.0

        # Emission energy: pulse with magnitude
        _materials[i].emission_energy_multiplier = lerpf(
            EMISSION_BASE, EMISSION_PEAK, magnitude
        )
```

### Pattern 3: main.gd Integration
**What:** main.gd sets ModeManager container and triggers initial mode load after XR init.
**When to use:** Wiring ModeManager into existing scene tree.

```gdscript
# In main.gd, after XR init or flat screen setup:
func _ready():
    # ... existing XR init code ...

    # Set up ModeManager after scene tree is ready
    call_deferred("_setup_mode_manager")

func _setup_mode_manager() -> void:
    # Container is the VRScene node (or a child of it)
    var container := $VRScene
    ModeManager.set_container(container)
    ModeManager.switch_to("spectrum_bars")
```

### Anti-Patterns to Avoid
- **Modifying CylinderMesh height every frame on shared resource:** Each bar MUST have its own CylinderMesh instance. If bars shared a mesh resource, changing height would affect all bars. The pattern above creates unique CylinderMesh per bar.
- **Using global shader uniforms for bar animation:** The bars read from `AudioManager.audio_data` directly in GDScript, not from shader uniforms. Shader uniforms are for GPU-side effects. Per-bar height is CPU-driven via mesh property changes.
- **Placing mode scenes as direct children of root:** Mode scenes go under a container node in the VR scene, not under root. This keeps them in the correct 3D coordinate space relative to XR origin.

## Don't Hand-Roll

| Problem | Don't Build | Use Instead | Why |
|---------|-------------|-------------|-----|
| Cylinder geometry | Custom ArrayMesh | CylinderMesh | Built-in, GPU-optimized, adjustable at runtime |
| Emissive glow | Custom bloom shader | StandardMaterial3D emission + Environment glow | Already working in vr_scene.tscn, tuning only |
| Scene lifecycle | Custom tree manipulation | PackedScene.instantiate() + queue_free() | Standard Godot pattern, handles cleanup |
| Smoothed audio data | Rolling average/filter | AudioManager's existing exponential smoothing | Already tuned (0.3 attack / 0.05 decay) |

**Key insight:** The existing audio pipeline (AudioManager -> AudioData -> bands[7]) and post-processing (Environment with glow) handle the hard parts. This phase is primarily about creating geometry, wiring data, and building a simple manager.

## Common Pitfalls

### Pitfall 1: Glow Invisible on Mobile Renderer
**What goes wrong:** Emission materials render but no visible glow/bloom around them.
**Why it happens:** Mobile renderer has lower HDR dynamic range (max ~2.0). Default glow_hdr_threshold of 1.0 may be too high.
**How to avoid:** Set `glow_hdr_threshold` to 0.8 or lower. Increase `glow_strength` to compensate. Increase `glow_bloom` above 0 to send more screen data to glow processor. Test with `emission_energy_multiplier` values of 2.0-8.0.
**Warning signs:** Bars appear colored but flat/non-glowing in VR.

### Pitfall 2: Shared Mesh Resource Mutation
**What goes wrong:** Changing `cylinder.height` on one bar changes ALL bars.
**Why it happens:** If CylinderMesh is created once and assigned to multiple MeshInstance3D nodes, they share the same resource.
**How to avoid:** Create a unique CylinderMesh instance per bar in the creation loop.
**Warning signs:** All bars are the same height at all times.

### Pitfall 3: Bar Position Drift When Scaling Height
**What goes wrong:** Bars appear to grow from center instead of floor.
**Why it happens:** CylinderMesh is centered at origin by default. When height changes, it grows equally up and down.
**How to avoid:** Set `position.y = height / 2.0` every frame when updating height, so the bottom stays at y=0.
**Warning signs:** Bars float above the floor or sink below it during peaks.

### Pitfall 4: ModeManager Initializing Before Scene Tree Ready
**What goes wrong:** Container node is null, mode fails to load.
**Why it happens:** Autoloads initialize before the main scene tree. If ModeManager tries to find nodes in _ready(), they don't exist yet.
**How to avoid:** Use `call_deferred("_initialize")` pattern (established in AudioManager/ShaderBridge). Have main.gd call `ModeManager.set_container()` after its own _ready().
**Warning signs:** "No container set" errors at startup.

### Pitfall 5: Performance with Per-Frame Mesh Property Changes
**What goes wrong:** Stuttering or frame drops when changing CylinderMesh.height 27 times per frame.
**Why it happens:** Mesh property changes trigger re-upload to GPU.
**How to avoid:** 27 bars is well within budget. If performance is an issue, switch to vertex shader scaling (scale the transform instead of changing mesh geometry). Transform scaling is cheaper: `_bars[i].scale.y = target_height / MIN_HEIGHT` with mesh height fixed at MIN_HEIGHT.
**Warning signs:** Frame time spikes correlating with audio peaks. Profile with Godot's built-in profiler.

### Pitfall 6: VR Scale Mismatch
**What goes wrong:** Bars look tiny or enormous in VR headset.
**Why it happens:** VR units are 1:1 with real-world meters. A 5m bar IS 5 meters -- roughly a two-story wall.
**How to avoid:** The 4-5m max height at 3m radius is intentional per user decision -- meant to feel "towering." Test in headset early to confirm the scale feels right. Adjust RING_RADIUS and MAX_HEIGHT as constants.
**Warning signs:** Bars feel uncomfortably close (radius too small) or insignificant (too far/short).

## Code Examples

### Reading Audio Bands Per-Frame
```gdscript
# Source: existing pattern from debug_overlay.gd and shader_bridge.gd
func _process(_delta: float) -> void:
    var data: AudioData = AudioManager.audio_data
    if data == null:
        return
    # data.bands[0] = sub-bass (0.0-1.0)
    # data.bands[1] = bass
    # ...
    # data.bands[6] = brilliance
    # data.energy = overall average
    # data.has_signal = whether audio is playing
```

### CylinderMesh Configuration
```gdscript
# Source: https://docs.godotengine.org/en/stable/classes/class_cylindermesh.html
var cylinder := CylinderMesh.new()
cylinder.top_radius = 0.12
cylinder.bottom_radius = 0.12
cylinder.height = 0.1  # Will be updated per frame
cylinder.radial_segments = 16  # Lower = better perf, 16 looks smooth enough
cylinder.rings = 1  # No need for subdivisions
```

### Emissive Material Setup
```gdscript
# Source: Godot StandardMaterial3D docs + existing test_reactive.gdshader pattern
var mat := StandardMaterial3D.new()
mat.emission_enabled = true
mat.emission = Color("#FF1744")  # Band color
mat.emission_energy_multiplier = 4.0  # Drives glow intensity
mat.albedo_color = Color("#FF1744") * 0.3  # Dim albedo for solid core
# Optional for better glow:
mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED  # Skip lighting calc
```

### Environment Glow Tuning for Mobile Renderer
```gdscript
# Source: Godot environment docs + mobile renderer considerations
# Existing vr_scene.tscn has glow_enabled=true, glow_intensity=0.4
# May need adjustment for emission-driven glow:
var env: Environment = world_environment.environment
env.glow_enabled = true
env.glow_intensity = 0.8  # Increase from 0.4
env.glow_strength = 1.5   # Increase for mobile renderer
env.glow_bloom = 0.3      # Add some full-screen bloom
env.glow_hdr_threshold = 0.8  # Lower for mobile HDR range
env.glow_hdr_scale = 1.0
```

### Idle Animation (No Signal)
```gdscript
# Subtle ambient pulse when AudioManager.has_signal == false
func _process(delta: float) -> void:
    if not AudioManager.has_signal:
        var t: float = Time.get_ticks_msec() / 1000.0
        for i in range(_bars.size()):
            var phase: float = float(i) / _bars.size() * TAU
            var idle_val: float = 0.05 + 0.03 * sin(t * 0.5 + phase)
            _update_bar(i, idle_val)
        return
    # ... normal audio-reactive update ...
```

## State of the Art

| Old Approach | Current Approach | When Changed | Impact |
|--------------|------------------|--------------|--------|
| ShaderMaterial for everything | StandardMaterial3D with emission | Godot 4.0+ | No custom shader needed for basic glow |
| `instance()` | `instantiate()` | Godot 4.0 | API rename, old method removed |
| SceneTree.change_scene() | Manual add_child/remove_child | Godot 4.0+ best practice | More control over lifecycle |
| 4-stem audio buses | Single capture bus with 7-band FFT | Phase 2 (v2.0) | Simpler pipeline, any audio source |

## Open Questions

1. **CylinderMesh.height changes per frame -- performance impact?**
   - What we know: 27 mesh property changes per frame is low volume. Godot re-uploads mesh data to GPU on change.
   - What's unclear: Whether Mobile renderer handles this differently than Forward+.
   - Recommendation: Start with mesh height changes. If profiling shows issues, switch to `scale.y` transform instead (zero GPU re-upload cost). This is a simple constant change.

2. **Glow tuning for VR stereo rendering**
   - What we know: Glow is a screen-space post-process. In VR stereo, it runs per-eye.
   - What's unclear: Whether glow parameters need different values for VR vs flat screen.
   - Recommendation: Tune in flat-screen first, then verify in VR headset. The existing glow in vr_scene.tscn already works in VR (Phase 1 verified).

3. **Optimal bar distribution across bands**
   - What we know: User wants 20-30 bars, weighted toward bass for visual impact.
   - Recommendation: [4, 5, 4, 4, 4, 3, 3] = 27 bars gives bass dominance up front while keeping all bands represented. This is Claude's discretion -- easy to adjust.

## Validation Architecture

### Test Framework
| Property | Value |
|----------|-------|
| Framework | Manual VR + flat-screen visual verification |
| Config file | N/A -- visual output, no unit test framework |
| Quick run command | `godot --path .` (flat-screen preview) |
| Full suite command | `godot --path .` + VR headset via Virtual Desktop |

### Phase Requirements -> Test Map
| Req ID | Behavior | Test Type | Automated Command | File Exists? |
|--------|----------|-----------|-------------------|-------------|
| VIS-01 | 3D spectrum bars visible in VR with per-band colors | manual-visual | `godot --path .` -- verify bars render in ring with 7 distinct colors | N/A |
| VIS-02 | Bar heights react to FFT magnitude in real-time | manual-visual | `godot --path .` + play music -- verify bass bars spike on bass hits | N/A |
| INF-03 | ModeManager loads spectrum bars scene | smoke | Print confirmation in console when mode loads + bars appear | N/A |

**Justification for manual-only:** This phase is entirely visual output. Automated tests cannot verify "bars look right in VR" or "glow is visible." Smoke tests (console prints confirming mode loaded, bar count correct) provide basic automated verification.

### Sampling Rate
- **Per task commit:** Run `godot --path .` and visually verify bars + audio reactivity
- **Per wave merge:** Full VR headset test with music playing
- **Phase gate:** Bars visible, reactive, and managed by ModeManager in both flat-screen and VR

### Wave 0 Gaps
- [ ] `scenes/modes/` directory -- needs creation
- [ ] ModeManager autoload registration in project.godot
- [ ] Glow environment tuning for emission-heavy scene

## Sources

### Primary (HIGH confidence)
- [CylinderMesh docs](https://docs.godotengine.org/en/stable/classes/class_cylindermesh.html) - Properties, defaults, segments
- [Change scenes manually](https://docs.godotengine.org/en/stable/tutorials/scripting/change_scenes_manually.html) - PackedScene patterns
- [Environment and post-processing](https://docs.godotengine.org/en/4.4/tutorials/3d/environment_and_post_processing.html) - Glow/bloom settings
- Existing codebase: audio_manager.gd, shader_bridge.gd, debug_overlay.gd, vr_scene.tscn -- verified patterns

### Secondary (MEDIUM confidence)
- [Godot Forum: Glow in Godot 4](https://forum.godotengine.org/t/how-to-use-glow-effect-in-godot-4/1626) - Mobile renderer glow threshold guidance
- [Godot Forum: Emission glow](https://godotforums.org/d/36272-emission-material-doesnt-have-glow-around-it) - Emission + environment glow interaction

### Tertiary (LOW confidence)
- Glow parameter values for Mobile renderer (specific numbers need in-engine testing)
- CylinderMesh per-frame height change performance (needs profiling)

## Metadata

**Confidence breakdown:**
- Standard stack: HIGH - All built-in Godot classes, verified in docs
- Architecture: HIGH - Follows established project patterns (autoload, _process, call_deferred)
- Pitfalls: HIGH - Common Godot 3D issues well-documented + Mobile renderer glow is MEDIUM (needs testing)
- ModeManager design: MEDIUM - Simple pattern but untested in this specific project context

**Research date:** 2026-04-19
**Valid until:** 2026-05-19 (stable domain, Godot 4.6 is current)
