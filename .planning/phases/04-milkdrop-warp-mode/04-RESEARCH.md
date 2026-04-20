# Phase 4: Milkdrop Warp Mode - Research

**Researched:** 2026-04-19
**Domain:** Godot 4.6 SubViewport feedback loops, Milkdrop-style warp shaders, VR dome rendering
**Confidence:** MEDIUM-HIGH

## Summary

This phase implements a Milkdrop-inspired warp feedback visualizer rendered on an inverted sphere surrounding the VR viewer. The core technical challenge is a SubViewport ping-pong buffer system -- two SubViewports alternating read/write roles each frame to create a feedback loop without violating Vulkan's "cannot read and write same texture" constraint. The warp shader displaces UV coordinates each frame (zoom, rotation, translation) driven by audio data, while a decay factor prevents infinite accumulation.

The architecture maps cleanly to Godot 4.6: a `canvas_item` shader on a ColorRect inside SubViewport A reads from SubViewport B's texture, applies UV warp + decay + new color injection, and renders back to A. A Sprite2D in SubViewport B copies A's output for the next frame. The final texture is applied to an inverted SphereMesh (via `PrimitiveMesh.flip_faces = true`) surrounding the viewer. The inverted sphere approach is simpler than sky shaders and integrates naturally with the existing ModeManager scene system.

**Primary recommendation:** Build the ping-pong SubViewport feedback loop as the first task (proof of concept), then layer warp math and audio reactivity on top. The ping-pong buffer is the only novel infrastructure -- everything else (shader uniforms, ModeManager integration, inverted sphere) uses established project patterns.

<user_constraints>
## User Constraints (from CONTEXT.md)

### Locked Decisions
- Flowing liquid style -- smooth distortions like ink in water or lava lamp, organic and hypnotic, never angular
- Start simple (2-3 warp layers), ramp up complexity while monitoring FPS for 90fps VR target
- Default to subtle radial/bilateral symmetry (mandala-like effects), with a setting to switch to purely organic (no symmetry)
- Audio-driven color cycling as the default palette -- colors shift based on dominant frequency band (bass=warm reds/oranges, highs=cool blues/purples)
- Shader architecture should support palette swapping for future work (POL-03 deferred to v2.x)
- Mobile renderer is required for OpenXR -- no compute shaders, spatial shaders only. Desktop GPU is powerful enough; constraint is shader language features, not performance
- Inverted sphere (dome) -- warp texture mapped to inside of a large sphere surrounding the viewer. Full 360 immersion
- Sphere radius: 5-8m (medium)
- Total blackout environment -- pure black void, the warp sphere IS the entire visual
- Mode transition: brief fade through black (~0.5s) when switching between spectrum bars and warp
- Long trails as default (~95-98% retention per frame)
- Decay mode setting with 3 options: Long trails (default), Quick dissolve (~80-90%), Audio-driven (quiet=trail longer, loud=dissolve faster)
- Stability: periodic subtle reset as default -- inject tiny seed of new noise/color every ~30-60s to prevent convergence
- Seed source: both procedural noise injection AND color fields from audio
- Bass (LOW channel) -> zoom/warp distortion with three response modes (punchy/smooth/intensity-scaled)
- Mids (MID_LOW + MID_HIGH) -> rotation speed only
- Highs (HIGH channel) -> color hue shift speed AND brightness/intensity
- Overall energy -> master intensity scaler

### Claude's Discretion
- SubViewport resolution and ping-pong implementation details
- Exact warp distortion math (UV displacement functions)
- Noise algorithm choice for seed injection
- Sphere mesh resolution and UV mapping approach
- Shader uniform names for warp-specific parameters
- Settings storage mechanism (export vars, resource file, etc.)
- Fade-to-black transition implementation
- Exact symmetry implementation (kaleidoscope UV fold vs. radial repeat)

### Deferred Ideas (OUT OF SCOPE)
- Multiple color palettes / palette switching -- tracked as POL-03 in v2.x
- Crossfade transitions between modes -- tracked as POL-01 in v2.x (fade-to-black is the v2.0 approach)
- Controller-based mode switching -- tracked as INT-01 in v2.x (keyboard toggle for testing in Phase 4)
- Additional warp presets -- tracked as POL-05 in v2.x
</user_constraints>

<phase_requirements>
## Phase Requirements

| ID | Description | Research Support |
|----|-------------|-----------------|
| VIS-03 | Milkdrop-style warp mode renders feedback shader with audio-driven parameters (zoom, rotation, warp, decay) | Ping-pong SubViewport architecture, Milkdrop per-vertex warp equations adapted to fragment shader, audio channel mapping |
| VIS-04 | Warp mode creates flowing psychedelic visuals via SubViewport ping-pong frame feedback | Two-SubViewport buffer system with Sprite2D copy, canvas_item shader for feedback loop, decay/injection system |
| INF-04 | Both modes render correctly in VR (Quest 3 via Virtual Desktop) and flat-screen fallback | Inverted SphereMesh with ViewportTexture works identically in XR and flat-screen; ModeManager handles mode lifecycle |
</phase_requirements>

## Standard Stack

### Core
| Component | Type | Purpose | Why Standard |
|-----------|------|---------|--------------|
| SubViewport (x2) | Godot node | Ping-pong frame buffer for feedback loop | Only way to do read/write texture feedback in Godot without compute shaders |
| ColorRect + canvas_item shader | Godot node + shader | Warp processing -- reads previous frame, applies UV warp, writes new frame | canvas_item shaders can sample uniform textures and render to SubViewport |
| SphereMesh (flip_faces=true) | Godot PrimitiveMesh | Inverted dome for immersive warp display | PrimitiveMesh.flip_faces reverses winding order; renders interior |
| ViewportTexture | Godot texture | Pipes SubViewport output to sphere material and between buffers | Native Godot mechanism for SubViewport-to-material binding |
| Global shader uniforms | Godot shader system | Audio data (energy, channels, bands) consumed by warp shader | Already established in project -- ShaderBridge sets these every frame |

### Supporting
| Component | Type | Purpose | When to Use |
|-----------|------|---------|-------------|
| NoiseTexture2D | Godot resource | Seed noise for periodic injection to prevent convergence | Every 30-60s or on stability reset |
| Tween | Godot node | Fade-to-black transition (0.5s) on mode switch | Mode switch via ModeManager signal |
| Timer | Godot node | Periodic noise injection timing | Stability reset cycle |

### Alternatives Considered
| Instead of | Could Use | Tradeoff |
|------------|-----------|----------|
| Two SubViewports | BackBufferCopy | BackBufferCopy is simpler but unreliable in VR stereo rendering (SCREEN_TEXTURE limitation) |
| SphereMesh | Sky shader | Sky shaders are for environment background, not mode-scene objects; harder to integrate with ModeManager |
| canvas_item shader | spatial shader in SubViewport | canvas_item is simpler for 2D texture processing; spatial adds unnecessary 3D overhead |

## Architecture Patterns

### Recommended Project Structure
```
scenes/modes/
  warp.tscn            # Main warp mode scene (registered with ModeManager)
  warp.gd              # Warp mode script (ping-pong management, audio mapping, settings)
shaders/
  warp_feedback.gdshader   # canvas_item shader for feedback loop (UV warp + decay + injection)
  warp_display.gdshader    # spatial shader for inverted sphere (samples final texture, adds bloom/glow)
```

### Pattern 1: SubViewport Ping-Pong Buffer
**What:** Two SubViewports (A and B) where A's shader reads B's texture, processes it, and renders to A. A Sprite2D in B copies A's output for the next frame. No explicit swap code needed -- the one-frame delay of ViewportTexture creates the temporal separation.
**When to use:** Any time you need a feedback loop (reading previous frame's output as current frame's input) in Godot without compute shaders.
**Scene tree structure:**
```
WarpMode (Node3D)                    # Root of mode scene
  PingPongSystem (Node2D)            # Hidden -- only SubViewports render
    SubViewportA (SubViewport)       # Renders warp effect
      ColorRect (ColorRect)          # Full-rect, warp_feedback shader
    SubViewportB (SubViewport)       # Buffer -- copies A's output
      Sprite2D (Sprite2D)            # ViewportTexture referencing SubViewportA
  WarpDome (MeshInstance3D)          # Inverted SphereMesh, spatial shader
    Material: ViewportTexture -> SubViewportA
```
**Key detail:** SubViewportA's ColorRect shader samples SubViewportB via a `uniform sampler2D` (set to SubViewportB's ViewportTexture). SubViewportB's Sprite2D displays SubViewportA's output. This creates the one-frame-behind buffer without any GDScript swap logic.

**SubViewport configuration:**
- Size: 1024x1024 (start here, can increase to 2048x2048 if quality demands and FPS allows)
- Render Target: `UPDATE_ALWAYS`
- Transparent BG: false (black background is the "void")
- Own World: true (isolate from main 3D scene)
- Disable 3D: true (canvas_item only)

### Pattern 2: Milkdrop-Style UV Warp (Adapted for Fragment Shader)
**What:** Per-pixel UV displacement that creates zoom, rotation, and translation effects. Instead of Milkdrop's per-vertex mesh approach, we compute UV warp entirely in the fragment shader (simpler, no mesh grid needed).
**Core warp math:**
```glsl
// Convert UV to centered polar coordinates
vec2 center = vec2(0.5);
vec2 delta = uv - center;
float radius = length(delta);
float angle = atan(delta.y, delta.x);

// Apply warp transforms (audio-driven)
radius /= zoom;           // zoom > 1.0 = zoom in, < 1.0 = zoom out
angle += rotation;         // rotation in radians
delta = vec2(cos(angle), sin(angle)) * radius;

// Apply translation
vec2 warped_uv = delta + center + vec2(dx, dy);

// Sample previous frame at warped position
vec4 prev = texture(prev_frame, warped_uv);
```
**When to use:** Core of the feedback shader -- this is what creates the "motion" in the feedback loop.

### Pattern 3: Inverted Sphere Display
**What:** A SphereMesh with `flip_faces = true` creates an inverted dome. The viewer sits inside at the origin. A spatial shader on the sphere samples the final SubViewport texture.
**Configuration:**
- SphereMesh: radius=6.0, height=12.0, radial_segments=64, rings=32, flip_faces=true
- Material: `render_mode unshaded;` (no lighting -- pure emission from texture)
- Cull mode: back (default is fine since flip_faces reverses winding)

### Pattern 4: Audio-to-Warp Parameter Mapping
**What:** GDScript reads AudioManager data each frame and sets shader uniforms that control warp behavior.
**Mapping (from CONTEXT.md decisions):**
```gdscript
# In warp.gd _process():
var channels = AudioManager.audio_data.grouped  # [LOW, MID_LOW, MID_HIGH, HIGH]
var energy = AudioManager.audio_data.energy

# Bass -> zoom (punchy default: direct mapping with emphasis)
var bass = channels[0]  # LOW
var zoom = 1.0 + bass * zoom_intensity  # zoom_intensity ~0.15 for punchy

# Mids -> rotation
var mids = (channels[1] + channels[2]) * 0.5  # average MID_LOW + MID_HIGH
var rotation = mids * rotation_speed  # rotation_speed ~0.03

# Highs -> color shift speed + brightness
var highs = channels[3]  # HIGH
var hue_shift_speed = highs * hue_speed_multiplier
var brightness = 1.0 + highs * brightness_boost

# Overall energy -> master scaler
var master = energy
```

### Anti-Patterns to Avoid
- **Reading and writing the same SubViewport texture:** Causes Vulkan validation error. Always use two SubViewports.
- **Using SCREEN_TEXTURE for feedback in VR:** Broken in stereo rendering. SubViewport ping-pong is the only reliable approach.
- **High-precision float accumulation in shaders:** Over many frames, floating point values drift. Use multiplicative decay (`color *= 0.97`) combined with small additive offset (`color -= 0.002`) to keep values bounded.
- **Symmetric feedback without organic variation:** Pure radial symmetry converges to static patterns quickly. Always inject noise or audio-driven color to break symmetry.
- **Large SubViewport sizes on first iteration:** Start at 1024x1024. Larger sizes are expensive because they render twice per frame (once per SubViewport). Profile before increasing.

## Don't Hand-Roll

| Problem | Don't Build | Use Instead | Why |
|---------|-------------|-------------|-----|
| Noise generation in shader | Custom hash-based noise functions | NoiseTexture2D as uniform sampler | GPU noise is expensive per-pixel; a pre-baked noise texture is free to sample |
| Frame buffer swapping | Manual texture copy with RenderingServer | SubViewport + ViewportTexture auto-buffer | Godot handles the GPU copy; manual approach is fragile and slow |
| Color palette interpolation | Manual RGB lerping | HSV conversion in shader (`rgb2hsv`/`hsv2rgb`) | HSV hue rotation produces natural-looking color cycling; RGB lerp produces muddy transitions |
| Smooth parameter transitions | Raw audio values to shader | Exponential smoothing in GDScript (already in AudioManager) | AudioManager already applies attack/decay smoothing; use `grouped[]` directly |
| Mode lifecycle management | Custom scene loading/unloading | ModeManager.register_mode / switch_to | Already handles instantiation, tree management, and cleanup |

**Key insight:** The project already has the hard infrastructure (AudioManager FFT pipeline, ShaderBridge global uniforms, ModeManager). Phase 4's novelty is exclusively in the SubViewport ping-pong system and the warp shader math. Everything else plugs into existing patterns.

## Common Pitfalls

### Pitfall 1: Feedback Loop Convergence / Dead Image
**What goes wrong:** After 2-3 minutes, the warp feedback converges to a uniform color or static pattern. All visual motion dies.
**Why it happens:** Multiplicative decay alone eventually drives all pixels to zero or to a uniform value. Without injection of new content, information is lost each frame.
**How to avoid:** Dual injection strategy: (1) Audio-driven color fields injected every frame at low opacity based on frequency data, (2) Periodic noise burst every 30-60 seconds via Timer to break convergence. Use both additive and multiplicative decay: `color = (color - 0.002) * 0.97;`
**Warning signs:** Visuals becoming monotone; reduced contrast; all areas of the sphere looking the same.

### Pitfall 2: Grid Artifacts on Mobile GPUs
**What goes wrong:** Visible grid pattern (32px or 64px blocks) appears in the feedback texture on some mobile GPUs.
**Why it happens:** Mobile GPU tile-based rendering introduces precision artifacts in feedback loops. Documented in Godot issue #81527.
**How to avoid:** This project targets desktop GPU via PCVR (Quest 3 + Virtual Desktop), NOT native Quest rendering. Desktop GPUs do not exhibit this artifact. If ever porting to standalone Quest, this would need investigation. For now, this is a non-issue.
**Warning signs:** Regular rectangular patterns that don't follow the warp flow.

### Pitfall 3: SubViewport Texture Assignment Errors
**What goes wrong:** ViewportTexture fails to bind, producing black sphere or Vulkan errors.
**Why it happens:** ViewportTexture must be assigned via the editor or carefully in code using `ViewportTexture.new()` with the correct `viewport_path`. Race conditions during scene load can cause null references.
**How to avoid:** Assign ViewportTextures in the .tscn file (editor), not in code. Use `call_deferred` for any runtime texture path changes. Ensure SubViewports are in the scene tree before any texture references are resolved.
**Warning signs:** Black dome on startup; errors mentioning "ViewportTexture" or "framebuffer" in console.

### Pitfall 4: Mode Switch Shader Compilation Stutter
**What goes wrong:** First switch to warp mode causes a visible frame drop while shaders compile.
**Why it happens:** Godot compiles shaders on first use. The warp shader is complex and the first frame triggers compilation.
**How to avoid:** Pre-warm the shader by briefly instantiating and then removing the warp scene during startup (before any mode is visible), or use Godot's shader cache. The fade-to-black transition (0.5s) also masks most compilation hitches.
**Warning signs:** Single-frame stutter on first mode switch; subsequent switches are smooth.

### Pitfall 5: Floating Point Precision Drift
**What goes wrong:** After 5+ minutes, shader values accumulate rounding errors causing visual artifacts (color banding, UV drift).
**Why it happens:** Each frame multiplies/adds to the previous frame's values. After thousands of frames, mediump precision (mobile renderer) causes visible drift.
**How to avoid:** Always use bounded operations: multiply by decay < 1.0 to prevent runaway values; clamp color output to [0,1]; use the periodic noise injection as a "soft reset" that reintroduces clean values. Avoid accumulating TIME-based values in the feedback texture.
**Warning signs:** Colors shifting to unexpected values; visual "banding" in gradients; UV sampling showing discontinuities.

## Code Examples

### Warp Feedback Shader (canvas_item)
```glsl
// warp_feedback.gdshader
shader_type canvas_item;

// Previous frame from ping-pong buffer
uniform sampler2D prev_frame : filter_linear, repeat_enable;

// Audio-driven warp parameters (set from GDScript)
uniform float warp_zoom : hint_range(0.9, 1.2) = 1.0;
uniform float warp_rotation : hint_range(-0.1, 0.1) = 0.0;
uniform float warp_dx : hint_range(-0.02, 0.02) = 0.0;
uniform float warp_dy : hint_range(-0.02, 0.02) = 0.0;
uniform float decay : hint_range(0.8, 1.0) = 0.97;
uniform float hue_shift : hint_range(0.0, 1.0) = 0.0;
uniform float brightness : hint_range(0.5, 2.0) = 1.0;
uniform float master_intensity : hint_range(0.0, 2.0) = 1.0;

// Noise injection
uniform sampler2D noise_tex : filter_linear;
uniform float noise_amount : hint_range(0.0, 0.1) = 0.0;
uniform float audio_inject_amount : hint_range(0.0, 0.5) = 0.1;

// Audio color injection
uniform vec3 audio_color = vec3(1.0, 0.3, 0.1);

// Symmetry
uniform bool symmetry_enabled = true;

vec3 rgb2hsv(vec3 c) {
    vec4 K = vec4(0.0, -1.0/3.0, 2.0/3.0, -1.0);
    vec4 p = mix(vec4(c.bg, K.wz), vec4(c.gb, K.xy), step(c.b, c.g));
    vec4 q = mix(vec4(p.xyw, c.r), vec4(c.r, p.yzx), step(p.x, c.r));
    float d = q.x - min(q.w, q.y);
    float e = 1.0e-10;
    return vec3(abs(q.z + (q.w - q.y) / (6.0 * d + e)), d / (q.x + e), q.x);
}

vec3 hsv2rgb(vec3 c) {
    vec4 K = vec4(1.0, 2.0/3.0, 1.0/3.0, 3.0);
    vec3 p = abs(fract(c.xxx + K.xyz) * 6.0 - K.www);
    return c.z * mix(K.xxx, clamp(p - K.xxx, 0.0, 1.0), c.y);
}

void fragment() {
    vec2 uv = UV;

    // Optional symmetry (kaleidoscope fold)
    if (symmetry_enabled) {
        vec2 centered = uv - 0.5;
        float angle = atan(centered.y, centered.x);
        float radius = length(centered);
        // 4-fold symmetry
        angle = mod(angle, PI / 2.0);
        uv = vec2(cos(angle), sin(angle)) * radius + 0.5;
    }

    // UV warp: polar coordinate transform
    vec2 center = vec2(0.5);
    vec2 delta = uv - center;
    float r = length(delta);
    float a = atan(delta.y, delta.x);

    // Apply warp
    r /= warp_zoom;
    a += warp_rotation;
    delta = vec2(cos(a), sin(a)) * r;
    vec2 warped_uv = delta + center + vec2(warp_dx, warp_dy);

    // Sample previous frame
    vec4 prev = texture(prev_frame, warped_uv);

    // Decay (combined multiplicative + additive for stability)
    prev.rgb = (prev.rgb - vec3(0.002)) * decay;

    // Hue shift
    vec3 hsv = rgb2hsv(prev.rgb);
    hsv.x = fract(hsv.x + hue_shift);
    hsv.z *= brightness;
    prev.rgb = hsv2rgb(hsv);

    // Audio color injection (always active, intensity varies)
    prev.rgb += audio_color * audio_inject_amount * master_intensity;

    // Noise injection (periodic, controlled by GDScript)
    vec3 noise = texture(noise_tex, uv + vec2(TIME * 0.01)).rgb;
    prev.rgb += noise * noise_amount;

    // Clamp to prevent runaway values
    COLOR = vec4(clamp(prev.rgb, 0.0, 1.0), 1.0);
}
```

### Warp Display Shader (spatial, for inverted sphere)
```glsl
// warp_display.gdshader
shader_type spatial;
render_mode unshaded, cull_back;

uniform sampler2D warp_texture : filter_linear;

void fragment() {
    vec3 color = texture(warp_texture, UV).rgb;
    ALBEDO = color;
    EMISSION = color * 2.0;  // Bloom picks this up via glow
}
```

### Warp Mode GDScript Structure
```gdscript
# warp.gd -- attached to WarpMode root Node3D
extends Node3D

# Warp parameter settings
@export_group("Bass Response")
@export_enum("Punchy", "Smooth", "Intensity-Scaled") var bass_mode: int = 0
@export var zoom_intensity: float = 0.15

@export_group("Decay")
@export_enum("Long Trails", "Quick Dissolve", "Audio-Driven") var decay_mode: int = 0

@export_group("Stability")
@export var stability_reset_enabled: bool = true
@export var reset_interval: float = 45.0  # seconds

@export_group("Symmetry")
@export var symmetry_enabled: bool = true

var _shader_material: ShaderMaterial  # Reference to ColorRect's material
var _reset_timer: float = 0.0

func _ready() -> void:
    _shader_material = $PingPongSystem/SubViewportA/ColorRect.material

func _process(delta: float) -> void:
    var data: AudioData = AudioManager.audio_data
    if data == null:
        return
    _update_warp_params(data, delta)
    _handle_stability_reset(delta)

func _update_warp_params(data: AudioData, delta: float) -> void:
    var channels = data.grouped
    var bass = channels[0]
    var mids = (channels[1] + channels[2]) * 0.5
    var highs = channels[3]
    var energy = data.energy

    # Bass -> zoom
    var zoom: float
    match bass_mode:
        0:  # Punchy
            zoom = 1.0 + bass * zoom_intensity
        1:  # Smooth
            zoom = 1.0 + bass * zoom_intensity * 0.3
        2:  # Intensity-scaled
            zoom = 1.0 + bass * zoom_intensity * bass

    # Mids -> rotation (consistent direction)
    var rotation = mids * 0.03

    # Highs -> hue shift + brightness
    var hue_shift = highs * 0.005
    var brightness = 1.0 + highs * 0.3

    # Decay mode
    var decay: float
    match decay_mode:
        0: decay = 0.975  # Long trails
        1: decay = 0.85   # Quick dissolve
        2: decay = lerpf(0.98, 0.85, energy)  # Audio-driven

    # Master intensity
    var master = 0.3 + energy * 0.7  # Never fully zero

    # Audio color: map dominant band to hue
    var audio_color = _frequency_to_color(bass, mids, highs)

    _shader_material.set_shader_parameter("warp_zoom", zoom)
    _shader_material.set_shader_parameter("warp_rotation", rotation)
    _shader_material.set_shader_parameter("decay", decay)
    _shader_material.set_shader_parameter("hue_shift", hue_shift)
    _shader_material.set_shader_parameter("brightness", brightness)
    _shader_material.set_shader_parameter("master_intensity", master)
    _shader_material.set_shader_parameter("audio_inject_amount", energy * 0.15)
    _shader_material.set_shader_parameter("audio_color", audio_color)
    _shader_material.set_shader_parameter("symmetry_enabled", symmetry_enabled)

func _frequency_to_color(bass: float, mids: float, highs: float) -> Vector3:
    # Bass = warm (red/orange), Mids = green/yellow, Highs = cool (blue/purple)
    var r = bass * 0.8 + mids * 0.2
    var g = mids * 0.5 + bass * 0.3
    var b = highs * 0.8 + mids * 0.2
    return Vector3(r, g, b).normalized() * 0.8

func _handle_stability_reset(delta: float) -> void:
    if not stability_reset_enabled:
        return
    _reset_timer += delta
    if _reset_timer >= reset_interval:
        _reset_timer = 0.0
        _shader_material.set_shader_parameter("noise_amount", 0.05)
        # Tween noise back to 0 over 2 seconds
        var tween = create_tween()
        tween.tween_method(
            func(val): _shader_material.set_shader_parameter("noise_amount", val),
            0.05, 0.0, 2.0
        )
```

## State of the Art

| Old Approach | Current Approach | When Changed | Impact |
|--------------|------------------|--------------|--------|
| SCREEN_TEXTURE feedback | SubViewport ping-pong | Godot 4.0+ (Vulkan) | SCREEN_TEXTURE cannot self-reference; ping-pong is required |
| Milkdrop HLSL per-vertex mesh | Fragment shader UV warp | N/A (adaptation) | Simpler for Godot; no warp mesh needed; equivalent visual result |
| Separate render passes via code | ViewportTexture auto-copy | Godot 4.x | No manual buffer swap needed; Godot handles GPU copy |

**Deprecated/outdated:**
- `BackBufferCopy` node: Unreliable for feedback loops; exists for screen-reading shaders, not iterative feedback
- `SCREEN_TEXTURE` for VR feedback: Broken in stereo rendering (both eyes get same texture or wrong eye)

## Open Questions

1. **Optimal SubViewport resolution for VR quality**
   - What we know: 1024x1024 is a safe starting point; 2048x2048 may look better in VR where the sphere fills the FOV
   - What's unclear: Performance impact of 2048x2048 with two SubViewports at 90fps
   - Recommendation: Start at 1024x1024, profile, then increase if headroom exists. Make resolution an export var for easy tuning.

2. **ViewportTexture assignment: editor vs code**
   - What we know: Editor-assigned ViewportTextures are more reliable; code assignment can have race conditions
   - What's unclear: Whether .tscn-based assignment works correctly when the mode scene is instantiated dynamically by ModeManager
   - Recommendation: Try editor assignment first. If ViewportTexture paths break on dynamic instantiation, fall back to code-based assignment in `_ready()` with `call_deferred`.

3. **Shader pre-warming strategy**
   - What we know: First mode switch causes shader compilation stutter. Fade-to-black masks ~0.5s of this.
   - What's unclear: Whether the warp shader is complex enough to exceed 0.5s compilation time on typical desktop GPUs
   - Recommendation: The fade-to-black transition should suffice for desktop PCVR. If stutter is visible, add a pre-warm step in `_setup_mode_manager()`.

## Validation Architecture

### Test Framework
| Property | Value |
|----------|-------|
| Framework | Manual visual verification + Godot editor |
| Config file | None -- visual/VR testing |
| Quick run command | `godot --path .` (run main scene, press key to switch modes) |
| Full suite command | `godot --path .` + 5-minute stability test in VR |

### Phase Requirements to Test Map
| Req ID | Behavior | Test Type | Automated Command | File Exists? |
|--------|----------|-----------|-------------------|-------------|
| VIS-03 | Warp mode renders audio-driven feedback visuals | manual-visual | Run scene, play music, observe warp responds to bass/mids/highs | N/A |
| VIS-04 | Feedback loop via SubViewport ping-pong | manual-visual | Run scene, verify flowing visuals persist and evolve over 5+ minutes | N/A |
| INF-04 | Both modes render in VR and flat-screen | manual-visual | Test flat-screen on macOS, test VR via Virtual Desktop on Windows | N/A |

**Justification for manual-only:** All three requirements are visual/perceptual outcomes in a real-time graphics context. Automated testing would require screenshot comparison which is fragile and overkill for a passion project with 2 modes.

### Sampling Rate
- **Per task commit:** Run scene, verify no errors, observe basic visual output
- **Per wave merge:** Full 5-minute playback test with music
- **Phase gate:** VR test via Virtual Desktop + flat-screen test on macOS

### Wave 0 Gaps
- [ ] Keyboard toggle for mode switching (for testing) -- may need to add to `main.gd`
- [ ] NoiseTexture2D resource for seed injection -- needs to be created

## Sources

### Primary (HIGH confidence)
- [Godot PrimitiveMesh docs](https://docs.godotengine.org/en/stable/classes/class_primitivemesh.html) - flip_faces property confirmed
- [Godot SphereMesh docs](https://docs.godotengine.org/en/stable/classes/class_spheremesh.html) - mesh properties
- [Godot SubViewport as texture](https://docs.godotengine.org/en/stable/tutorials/shaders/using_viewport_as_texture.html) - official tutorial
- [MilkDrop Preset Authoring Guide](https://www.geisswerks.com/milkdrop/milkdrop_preset_authoring.html) - warp variables, UV displacement, feedback mechanism

### Secondary (MEDIUM confidence)
- [godot4_shader_viewport_example](https://github.com/inkusgames/godot4_shader_viewport_example) - ping-pong implementation pattern verified
- [Godot Issue #81527](https://github.com/godotengine/godot/issues/81527) - grid artifacts on mobile GPUs (confirmed desktop is unaffected)
- [Godot Forum: SubViewport feedback](https://forum.godotengine.org/t/accessing-a-screen-texture-from-a-subviewport/132492) - community verification of ping-pong approach

### Tertiary (LOW confidence)
- Exact performance impact of 2048x2048 dual SubViewports at 90fps -- needs profiling

## Metadata

**Confidence breakdown:**
- Standard stack: HIGH - SubViewport ping-pong is the established Godot pattern for feedback loops; verified by official docs and community examples
- Architecture: HIGH - Milkdrop warp math is well-documented; Godot integration points are clear from existing codebase
- Pitfalls: MEDIUM-HIGH - Grid artifacts documented but only affect mobile GPUs (not our target); precision drift and convergence are well-understood from Milkdrop literature
- Audio mapping: HIGH - Direct mapping from existing AudioManager.grouped[] channels to shader uniforms follows established Phase 3 patterns

**Research date:** 2026-04-19
**Valid until:** 2026-05-19 (stable -- Godot 4.6 features are established)
