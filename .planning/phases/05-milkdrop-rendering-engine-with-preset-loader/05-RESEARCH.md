# Phase 5: Milkdrop Rendering Engine with Preset Loader - Research

**Researched:** 2026-04-20
**Domain:** MilkDrop visualization engine (grid mesh warp, NSEEL interpreter, waveform rendering, blur pipeline, preset file loading) in Godot 4.6 Mobile renderer
**Confidence:** HIGH

## Summary

MilkDrop's rendering architecture is well-documented through the original MilkDrop3 C++ source, the projectM C++ reimplementation, and the butterchurn WebGL port. The core rendering pipeline has 7 distinct stages executed each frame: per-frame equation evaluation, per-vertex grid mesh UV computation, warped texture blit (feedback), blur passes, custom shape drawing, custom waveform drawing, and built-in waveform drawing. The "magic" comes from two mechanisms: (1) a 128x96 vertex grid where each vertex's UV is computed through a 7-step transform chain (zoom, stretch, warp, rotate, translate, aspect, texel offset), and (2) an NSEEL expression interpreter that evaluates preset equations each frame to drive those transforms.

The NSEEL interpreter is the largest engineering challenge. It requires a tokenizer, parser, AST evaluator, variable scoping (per-frame pool, per-vertex pool, per-point pool), Q-variable passing between pools, and ~25 built-in math functions. The .milk preset file format is straightforward INI-like text with numbered equation lines (`per_frame_1=...`, `per_pixel_1=...`). The rendering pipeline itself maps cleanly to Godot's SubViewport + canvas_item shader pattern already proven in Phase 4, but needs significant expansion for the grid mesh, blur passes, and overlay drawing.

**Primary recommendation:** Build the NSEEL interpreter first (it's the foundation everything depends on), then the preset parser, then the rendering pipeline in stages (grid warp -> feedback -> blur -> waveforms -> shapes). Use ImmediateMesh for waveforms/shapes (rebuilt each frame), ArrayMesh for the grid (UV-only updates each frame).

<user_constraints>
## User Constraints (from CONTEXT.md)


> **NOTE: SUPERSEDED APPROACH.** The locked decisions below reflect the original GDScript reimplementation plan (custom NSEEL interpreter, 128x96 grid mesh, SubViewport ping-pong). This approach was superseded by the projectM GDExtension integration. See `05-CONTEXT.md` for the current approach: projectM (mature C++ library) handles all rendering, NSEEL evaluation, grid warp, waveforms, blur, and compositing. We write a thin GDExtension wrapper that feeds it audio and gets a texture back.

### Locked Decisions
- Build a full NSEEL (Nullsoft Expression Evaluator Library) interpreter in GDScript to evaluate .milk preset equations at runtime
- Can load any standard .milk preset file directly -- no conversion step needed
- Start with 5 test presets to prove the engine works; curated preset packs come later
- Manual preset selection only (no auto-cycling for now)
- Unsupported features are skipped gracefully -- preset still renders, just missing some effects
- Presets loaded from a `res://presets/` directory (or user-accessible folder)
- Grid mesh warp: 128x96 vertex grid with dynamic UV coordinates computed per-frame from preset per-pixel equations
- GPU ping-pong feedback: Two SubViewports at 2048x2048, swap each frame using get_texture()
- Waveform overlay drawing: All four types -- circular waveform, spectrum/frequency bars, oscilloscope lines, and custom preset-defined shapes
- Multi-level Gaussian blur: Separable blur passes for glow/soft look. Up to 3-4 levels initially
- Video echo deferred -- Not in MVP
- Composite shaders deferred -- Not in MVP
- Replace Phase 4 warp mode entirely -- remove old warp.gd/warp.tscn/warp_feedback.gdshader
- Keep inverted sphere dome (radius 6m, flip_faces) centered at camera height
- Two modes total: spectrum bars + milkdrop
- Same fade-to-black transition on TAB key switch
- Milkdrop output texture mapped to dome interior
- Map AudioManager grouped channels and FFT bands to Milkdrop's expected audio variables
- bass = grouped[0] (LOW), mid = (grouped[1] + grouped[2]) * 0.5, treb = grouped[3] (HIGH)
- _att variants use exponential smoothing (slower decay) -- need to add these to the audio pipeline

### Claude's Discretion
- NSEEL interpreter implementation details (tokenizer, parser, AST, evaluator)
- Mesh generation approach for waveforms (ImmediateMesh, ArrayMesh, etc.)
- Blur shader implementation (number of taps, kernel weights)
- Preset file parsing approach (.milk files are INI-like format)
- Grid mesh implementation (MeshInstance3D, ArrayMesh, or custom rendering)
- Error handling for malformed presets
- Memory management for preset resources

### Deferred Ideas (OUT OF SCOPE)
- Auto-cycling presets with smooth crossfade -- future enhancement after engine is stable
- Curated preset packs (20-50 hand-picked presets) -- after engine proves compatibility
- Full preset archive browser (~44k presets) -- future quality-of-life feature
- Video echo effect -- after core pipeline is solid
- Composite shaders from presets -- after core pipeline is solid
- Per-pixel custom shaders (bUseWarpShader, bUseCompShader) -- advanced preset feature for later
- Preset rating/favorites system -- UX feature for later
</user_constraints>

<phase_requirements>
## Phase Requirements

| ID | Description | Research Support |
|----|-------------|-----------------|
| VIS-03 | Milkdrop-style warp mode renders feedback shader with audio-driven parameters (zoom, rotation, warp, decay) | Full MilkDrop rendering pipeline researched: grid mesh warp with per-vertex UV computation, NSEEL equation evaluation driving zoom/rot/warp/decay per frame, SubViewport ping-pong feedback |
| VIS-04 | Warp mode creates flowing psychedelic visuals via SubViewport ping-pong frame feedback | Phase 4 proved SubViewport ping-pong with get_texture(). Phase 5 upgrades to 2048x2048 with proper grid mesh warp instead of simple center-zoom |
| INF-04 | Both modes render correctly in VR (Quest 3 via Virtual Desktop) and flat-screen fallback | Milkdrop renders to SubViewport texture mapped to inverted sphere dome -- same pattern as Phase 4, works in both VR and flat-screen |
</phase_requirements>

## Standard Stack

### Core
| Library/Component | Version | Purpose | Why Standard |
|---------|---------|---------|--------------|
| Godot SubViewport | 4.6 | Ping-pong feedback rendering at 2048x2048 | Proven in Phase 4, only way to do feedback in Mobile renderer without compute shaders |
| Godot ImmediateMesh | 4.6 | Per-frame waveform and shape geometry | Designed for geometry rebuilt every frame; OpenGL immediate-mode style API |
| Godot ArrayMesh | 4.6 | Static grid mesh with dynamic UV updates | Efficient for large vertex count (12,417 vertices) where only UVs change per frame |
| canvas_item shaders | 4.6 | Feedback warp shader, blur passes | 2D shader pipeline for SubViewport rendering |
| spatial shaders | 4.6 | Dome display shader, waveform overlay material | 3D rendering on the inverted sphere and overlay geometry |

### Supporting
| Component | Purpose | When to Use |
|-----------|---------|-------------|
| AudioManager (existing) | Source of FFT data mapped to MilkDrop audio vars | Every frame -- bass/mid/treb/bass_att/mid_att/treb_att |
| ModeManager (existing) | Mode registration and switching | Register "warp" mode pointing to new milkdrop scene |
| ShaderBridge (existing) | May need extension for milkdrop-specific uniforms | If global shader uniforms needed beyond per-material params |
| ConfigFile (built-in) | .milk file parsing (INI-like format) | Preset loading -- ConfigFile handles key=value parsing |

### Alternatives Considered
| Instead of | Could Use | Tradeoff |
|------------|-----------|----------|
| Custom NSEEL interpreter | Godot Expression class | Expression class cannot do multi-statement code, variable assignment, or semicolon-delimited blocks. NSEEL requires custom interpreter. |
| ImmediateMesh (waveforms) | ArrayMesh | ImmediateMesh is simpler for variable-vertex-count geometry rebuilt each frame; ArrayMesh would need resize/realloc |
| ArrayMesh (grid) | ImmediateMesh | Grid has fixed 12,417 vertices -- ArrayMesh with surface_get_arrays/surface_set_arrays avoids recreating topology each frame |
| ConfigFile (.milk parsing) | Custom INI parser | ConfigFile handles `[section]` and `key=value` natively; only issue is multi-line equation concatenation (per_frame_1, per_frame_2...) which needs custom post-processing |

## Architecture Patterns

### Recommended Project Structure
```
scripts/
  milkdrop/
    nseel_interpreter.gd    # Tokenizer + Parser + Evaluator (core NSEEL engine)
    preset_loader.gd        # .milk file parser -> MilkdropPreset resource
    milkdrop_preset.gd      # Data class: all preset params, equations, shapes, waves
    milkdrop_renderer.gd    # Main rendering orchestrator (attached to scene root)
    grid_mesh.gd            # 128x96 vertex grid with UV computation
    waveform_drawer.gd      # Built-in waveform modes 0-7
    custom_wave.gd          # Custom wave per-frame/per-point evaluation
    custom_shape.gd         # Custom shape per-frame evaluation
    audio_bridge.gd         # Maps AudioManager data -> MilkDrop variables
scenes/
  modes/
    milkdrop.tscn           # Scene: 2x SubViewport + grid mesh + dome + waveform overlay
    milkdrop.gd             # Mode entry point (replaces warp.gd)
shaders/
  milkdrop_warp.gdshader    # Grid mesh warp: samples prev_frame at computed UVs with decay
  milkdrop_blur.gdshader    # Separable Gaussian blur (horizontal + vertical)
  milkdrop_display.gdshader # Dome display shader (same as current warp_display)
  milkdrop_waveform.gdshader # Unshaded additive/alpha material for waveform overlays
presets/
  *.milk                    # Preset files loaded at runtime
```

### Pattern 1: MilkDrop Rendering Pipeline (per frame)
**What:** The exact rendering order from MilkDrop3 source, adapted to Godot
**When to use:** Every frame in milkdrop_renderer.gd._process()
```
Frame N Pipeline:
  1. audio_bridge.update()          # Map AudioManager -> MilkDrop vars (bass, mid, treb, etc.)
  2. Run per-frame init equations    # One-time per preset load (sets q1-q32 defaults)
  3. Run per-frame equations          # Modify zoom, rot, warp, decay, wave colors, etc.
  4. Compute grid UVs                 # For each of 128x96 vertices: per-vertex equations -> 7-step UV transform
  5. Update grid mesh UVs             # Push computed UVs to ArrayMesh
  6. Render warp pass to SubViewport  # Grid mesh samples prev_frame texture at warped UVs, with decay
  7. Blur passes (3 levels)           # Separable Gaussian on progressively smaller SubViewports
  8. Draw custom shapes               # Polygon geometry overlaid on feedback texture
  9. Draw custom waveforms            # Per-point equation waveforms overlaid
  10. Draw built-in waveform          # Mode 0-7 waveform overlaid
  11. Swap ping-pong buffers          # Current output becomes next frame's prev_frame
  12. Display on dome                 # Map final texture to inverted sphere
```

### Pattern 2: NSEEL Interpreter Architecture
**What:** Three-stage interpreter: Tokenize -> Parse to AST -> Evaluate
**When to use:** Preset loading (parse+compile) and every frame (evaluate)

```gdscript
# Tokenizer: string -> tokens
# Handles: numbers, identifiers, operators (+,-,*,/,%,=,+=,-=,*=,/=),
#           comparisons (==,<,<=,>,>=), parens, semicolons, commas
# Built-in functions recognized as identifiers

# Parser: tokens -> AST nodes
# AST node types: NumberLiteral, Variable, BinaryOp, UnaryOp,
#                 FunctionCall, Assignment, CompoundAssignment, Block (semicolons)

# Evaluator: AST + variable_pool -> result
# Variable pool is a Dictionary[String, float]
# Per-frame pool and per-vertex pool share q1-q32 (copied in, not referenced)
# Custom variables persist within a pool across frames

# Built-in functions (25):
# sin, cos, tan, asin, acos, atan, atan2
# sqrt, pow, exp, log, log10
# abs, sign, floor, ceil, int
# min, max, sqr (x*x), invsqrt (1/sqrt(x))
# rand(n) -> random 0..n
# if(cond, then, else)
# sigmoid(x, y) -> 1/(1+exp(-x*y))
# above(x,y) -> 1 if x>y else 0
# below(x,y) -> 1 if x<y else 0
# equal(x,y) -> 1 if |x-y|<0.00001 else 0
# bor(x,y), band(x,y), bnot(x) -> bitwise on int-converted values
```

### Pattern 3: Grid Mesh UV Computation (Per-Vertex)
**What:** The 7-step UV transform chain from MilkDrop source
**When to use:** For each vertex in the 128x96 grid, each frame

```gdscript
# For each vertex at normalized grid position (gx, gy) in 0..1:
# 1. Set per-vertex input variables
var x = gx  # 0..1 horizontal
var y = gy  # 0..1 vertical
var rad = sqrt((x - 0.5) * (x - 0.5) + (y - 0.5) * (y - 0.5)) * 2.0  # 0..~1.414
var ang = atan2(y - 0.5, x - 0.5)  # -PI..PI

# 2. Run per-vertex equations (can modify zoom, zoomexp, rot, warp, cx, cy, dx, dy, sx, sy)
# nseel_interpreter.evaluate(per_vertex_code, vertex_pool)

# 3. Compute UV through 7-step transform chain:
# Step 1: Zoom (radius-dependent via zoomexp)
var zoom2 = pow(zoom, pow(zoomexp, rad * 2.0 - 1.0))
var zoom2_inv = 1.0 / zoom2
var u = (x - 0.5) * zoom2_inv + 0.5
var v = (y - 0.5) * zoom2_inv + 0.5

# Step 2: Stretch
u = (u - cx) / sx + cx
v = (v - cy) / sy + cy

# Step 3: Warp (4 oscillating sine waves -- the signature MilkDrop organic flow)
var warp_time = time * warp_anim_speed
var warp_scale_inv = 1.0 / warp_scale
var f0 = 11.68 + 4.0 * cos(warp_time * 1.413 + 10)
var f1 = 8.77 + 3.0 * cos(warp_time * 1.113 + 7)
var f2 = 10.54 + 3.0 * cos(warp_time * 1.233 + 3)
var f3 = 11.49 + 4.0 * cos(warp_time * 0.933 + 5)
u += warp * 0.0035 * sin(warp_time * 0.333 + warp_scale_inv * (x * f0 - y * f3))
v += warp * 0.0035 * cos(warp_time * 0.375 - warp_scale_inv * (x * f2 + y * f1))
u += warp * 0.0035 * cos(warp_time * 0.753 - warp_scale_inv * (x * f1 - y * f2))
v += warp * 0.0035 * sin(warp_time * 0.825 + warp_scale_inv * (x * f0 + y * f3))

# Step 4: Rotation (around cx, cy)
var u2 = u - cx
var v2 = v - cy
u = u2 * cos(rot) - v2 * sin(rot) + cx
v = u2 * sin(rot) + v2 * cos(rot) + cy

# Step 5: Translation
u -= dx
v -= dy

# Step 6: Aspect ratio correction (if non-square viewport)
# Step 7: Texel offset (half-pixel for texture alignment)
```

### Pattern 4: .milk Preset File Format
**What:** INI-like format with numbered equation lines
**Structure:**
```ini
MILKDROP_PRESET_VERSION=201
PSVERSION=2
PSVERSION_WARP=0
PSVERSION_COMP=2
[preset00]
fRating=4.000000
fGammaAdj=1.900000
fDecay=0.980000
fVideoEchoZoom=1.169360
fVideoEchoAlpha=0.000000
nVideoEchoOrientation=0
nWaveMode=5
bAdditiveWaves=1
bWaveDots=1
...
zoom=1.053000
rot=0.000000
cx=0.500000
cy=0.500000
dx=0.000000
dy=0.000000
warp=0.263000
sx=1.000000
sy=1.000000
wave_r=0.500000
wave_g=0.500000
wave_b=0.800000
...
wavecode_0_enabled=0
wavecode_0_samples=512
...
shapecode_0_enabled=0
shapecode_0_sides=4
...
per_frame_1=wave_r = wave_r + 0.650*(0.60*sin(1.437*time) + 0.40*sin(0.970*time));
per_frame_2=wave_g = wave_g + 0.650*(0.60*sin(1.344*time) + 0.40*sin(0.841*time));
...
per_pixel_1=zoom = zoom + 0.01*sin(10*ang);
per_pixel_2=rot = rot + 0.08*abs(0.746-rad);
...
wave_0_init=t1 = 0;
wave_0_per_frame=t1 = t1 + 0.1;
wave_0_per_point=x = 0.5 + 0.3*cos(sample*6.28 + t1);
...
shape_0_init=t1 = rand(100);
shape_0_per_frame=ang = time * 0.5;
```

**Parsing approach:**
1. Read file as text, split into lines
2. Handle version header lines before `[preset00]`
3. For `[preset00]` section: parse `key=value` pairs
4. Concatenate numbered equation lines: `per_frame_1`, `per_frame_2`... -> single string joined by `;\n`
5. Similarly for `per_pixel_N`, `wave_N_init`, `wave_N_per_frame`, `wave_N_per_point`, `shape_N_init`, `shape_N_per_frame`
6. Parse NSEEL code strings into AST at load time (not every frame)

### Anti-Patterns to Avoid
- **Running NSEEL parser every frame:** Parse equations at preset load time, store AST, evaluate AST each frame. Parsing is expensive, evaluation is cheap.
- **Recreating grid mesh topology each frame:** The grid has fixed connectivity (128x96 quads = 24,192 triangles). Only UVs change. Create ArrayMesh once, update UV array in-place.
- **Using SCREEN_TEXTURE for feedback:** Broken in VR stereo rendering. Must use explicit SubViewport ping-pong with get_texture().
- **Evaluating per-vertex equations on GPU:** MilkDrop's per-vertex equations are NSEEL code (arbitrary math with branching). Cannot run in shader. Must evaluate on CPU and upload UV results.
- **Ignoring variable scoping between equation pools:** Per-frame and per-vertex pools share read-only variables + q1-q32, but custom variables in per-frame don't exist in per-vertex and vice versa. Getting this wrong breaks presets.

## Don't Hand-Roll

| Problem | Don't Build | Use Instead | Why |
|---------|-------------|-------------|-----|
| INI file parsing | Custom line parser | Godot ConfigFile + post-processing for numbered lines | ConfigFile handles sections/keys; only need to concatenate `per_frame_1..N` lines |
| Gaussian blur kernel | Custom kernel math | Standard 8-tap separable Gaussian with fixed weights | MilkDrop uses weights [4.0, 3.8, 3.5, 2.9, 1.9, 1.2, 0.7, 0.3] -- copy these exactly |
| Waveform smoothing | Custom filter | IIR filter from MilkDrop: `s[i] = scale*(1-smooth)*p[i] + smooth*s[i-1]` | Exact formula from source; don't invent a different smoothing |
| Grid mesh topology | Custom triangle builder | Standard grid quad strip with indices | Well-known pattern: (nGridX+1)*(nGridY+1) vertices, nGridX*nGridY*2 triangles |

**Key insight:** MilkDrop's visual quality comes from specific magic numbers (warp frequencies 11.68/8.77/10.54/11.49, blur weights, smoothing constants). Copy these exactly from the source -- don't approximate.

## Common Pitfalls

### Pitfall 1: Per-Vertex Performance at 128x96
**What goes wrong:** 12,417 NSEEL evaluations per frame at 90fps = 1.1M evaluations/second. If each takes >0.5ms total, frame budget is blown.
**Why it happens:** GDScript is interpreted, not JIT-compiled. Complex AST walking for 12K vertices is expensive.
**How to avoid:** Profile early. If per-vertex NSEEL is too slow:
  - Reduce grid to 64x48 (3,185 vertices) -- MilkDrop's default was 32x24 anyway
  - Cache per-vertex results when equations don't reference x/y/rad/ang (many presets only use per-frame vars)
  - Pre-compute common subexpressions
  - Consider making per-vertex equation evaluation optional (skip if no per_pixel code in preset)
**Warning signs:** Frame time >11ms in _process(), visible hitching when switching presets

### Pitfall 2: Variable Scoping Between Equation Pools
**What goes wrong:** Preset equations silently produce wrong results because variables leak or don't transfer between pools.
**Why it happens:** MilkDrop has complex scoping: per-frame vars are seeded from preset defaults each frame, per-vertex vars inherit read-only copies + q1-q32 from per-frame, custom vars persist within a pool but not across pools, t1-t8 are local to custom wave/shape init->per_frame->per_point chains.
**How to avoid:** Implement variable pools as separate Dictionaries. Before each evaluation:
  1. Per-frame pool: reset writable vars to preset defaults, set read-only vars (time, audio, etc.), run init code once
  2. Per-vertex pool: copy zoom/rot/warp/cx/cy/dx/dy/sx/sy + q1-q32 from per-frame result, set x/y/rad/ang per vertex
  3. Custom wave/shape: copy q1-q32 from per-frame, set read-only vars, t1-t8 are local
**Warning signs:** Presets that work in MilkDrop produce different results in our engine

### Pitfall 3: Ping-Pong Buffer Initialization
**What goes wrong:** First frame renders garbage or black, feedback loop never "warms up."
**Why it happens:** Both SubViewports start empty. If the feedback shader reads from an uninitialized buffer, the decay multiplication produces nothing.
**How to avoid:** Initialize both SubViewport textures with black. The waveform and shape overlays inject color each frame, which the feedback loop then warps and decays. Seed with a visible pattern for the first ~10 frames if no audio signal.
**Warning signs:** Black screen on mode switch, preset takes seconds to "warm up"

### Pitfall 4: Equation Parsing Edge Cases in .milk Files
**What goes wrong:** Presets fail to load or produce parse errors.
**Why it happens:** .milk files have quirks:
  - Comments can appear as `//` within equation lines
  - Empty lines (`per_frame_4=`) are valid (no-op)
  - Backtick prefix on comp/warp shader lines (`` `shader_body ``)
  - Some presets use `\n` within a single line value
  - Custom variable names can collide with built-in names
  - Integer operators `%`, `|`, `&` convert operands to int first
**How to avoid:** Test with diverse preset corpus. Handle empty equations, strip comments, handle backtick shader syntax (but defer shader parsing for MVP).
**Warning signs:** Parse errors on popular presets

### Pitfall 5: Waveform Blending Modes
**What goes wrong:** Waveforms look wrong -- too bright, too dim, or invisible.
**Why it happens:** MilkDrop uses specific D3D blend states per waveform: additive (src+dst) for bright glowing lines, alpha blend (srcA*src + (1-srcA)*dst) for softer shapes. Getting the blend mode wrong dramatically changes the visual.
**How to avoid:** Use Godot's `blend_add` and `blend_mix` render modes in the waveform material. Set per the preset's `bAdditiveWaves` flag and per-wave `bAdditive` flag.
**Warning signs:** Waveforms either wash out the entire screen or are invisible

## Code Examples

### NSEEL Tokenizer (core pattern)
```gdscript
# Source: Based on MilkDrop3 ns-eel2/nseel-yylex.c lexer structure
enum TokenType {
    NUMBER, IDENTIFIER,
    PLUS, MINUS, STAR, SLASH, PERCENT,
    ASSIGN, PLUS_ASSIGN, MINUS_ASSIGN, STAR_ASSIGN, SLASH_ASSIGN,
    EQUAL, LESS, LESS_EQUAL, GREATER, GREATER_EQUAL,
    LPAREN, RPAREN, COMMA, SEMICOLON,
    PIPE, AMPERSAND,  # bitwise or/and (convert to int)
    EOF
}

class Token:
    var type: TokenType
    var value: String  # raw text
    var number_value: float  # for NUMBER tokens

func tokenize(code: String) -> Array[Token]:
    var tokens: Array[Token] = []
    var pos := 0
    while pos < code.length():
        var c := code[pos]
        # Skip whitespace and comments
        if c == ' ' or c == '\t' or c == '\n' or c == '\r':
            pos += 1; continue
        if c == '/' and pos + 1 < code.length() and code[pos + 1] == '/':
            while pos < code.length() and code[pos] != '\n': pos += 1
            continue
        # Number: digits, optional decimal
        if c.is_valid_float() or (c == '.' and pos + 1 < code.length()):
            # ... parse number
        # Identifier: letter or underscore start
        elif c == '_' or c.unicode_at(0) >= 65:  # a-z, A-Z, _
            # ... parse identifier
        # Operators: check two-char first (+=, ==, <=, etc.)
        # ...
    tokens.append(Token.new(TokenType.EOF, ""))
    return tokens
```

### Grid Mesh Creation (one-time setup)
```gdscript
# Source: Based on MilkDrop3 milkdropfs.cpp ComputeGridAlphaValues structure
const GRID_X := 128
const GRID_Y := 96

func _create_grid_mesh() -> ArrayMesh:
    var mesh := ArrayMesh.new()
    var verts := PackedVector3Array()
    var uvs := PackedVector2Array()
    var indices := PackedInt32Array()

    # Create vertices in normalized 0..1 grid
    for gy in range(GRID_Y + 1):
        for gx in range(GRID_X + 1):
            var x := float(gx) / GRID_X
            var y := float(gy) / GRID_Y
            # Position: map to -1..1 for rendering on a quad
            verts.append(Vector3(x * 2.0 - 1.0, y * 2.0 - 1.0, 0.0))
            # UVs: initially identity, updated each frame
            uvs.append(Vector2(x, y))

    # Create triangle indices (2 triangles per quad)
    for gy in range(GRID_Y):
        for gx in range(GRID_X):
            var tl := gy * (GRID_X + 1) + gx
            var tr := tl + 1
            var bl := tl + (GRID_X + 1)
            var br := bl + 1
            indices.append_array([tl, bl, tr, tr, bl, br])

    var arrays := []
    arrays.resize(Mesh.ARRAY_MAX)
    arrays[Mesh.ARRAY_VERTEX] = verts
    arrays[Mesh.ARRAY_TEX_UV] = uvs
    arrays[Mesh.ARRAY_INDEX] = indices
    mesh.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, arrays)
    return mesh
```

### Waveform Drawing with ImmediateMesh
```gdscript
# Source: Based on MilkDrop3 milkdropfs.cpp DrawWave + projectM Waveforms
func _draw_circle_waveform(im: ImmediateMesh, audio_samples: PackedFloat32Array,
                            wave_x: float, wave_y: float, mystery: float,
                            r: float, g: float, b: float, a: float) -> void:
    var num_samples := audio_samples.size() / 2
    im.surface_begin(Mesh.PRIMITIVE_LINE_STRIP)
    for i in range(num_samples + 1):  # +1 to close the loop
        var idx := i % num_samples
        var angle := float(idx) / num_samples * TAU + time * 0.2
        var radius := 0.5 + 0.4 * audio_samples[idx] + mystery
        var x := wave_x + radius * cos(angle)
        var y := wave_y + radius * sin(angle)
        im.surface_set_color(Color(r, g, b, a))
        im.surface_add_vertex(Vector3(x * 2.0 - 1.0, y * 2.0 - 1.0, 0.0))
    im.surface_end()
```

### Separable Blur Shader
```glsl
// Source: Based on MilkDrop3 milkdropfs.cpp BlurPasses
shader_type canvas_item;

uniform sampler2D source_texture : filter_linear;
uniform vec2 texel_size;  // 1.0/texture_size
uniform int direction;     // 0=horizontal, 1=vertical

// MilkDrop's exact 8-tap weights
const float w[8] = float[8](4.0, 3.8, 3.5, 2.9, 1.9, 1.2, 0.7, 0.3);

void fragment() {
    // Pair adjacent taps for efficiency (4 texture fetches instead of 8)
    float w1 = w[0] + w[1];
    float w2 = w[2] + w[3];
    float w3 = w[4] + w[5];
    float w4 = w[6] + w[7];
    float w_total = w1 + w2 + w3 + w4;

    // Offset within paired tap (weighted center)
    float d1 = 0.0 + 2.0 * w[1] / w1;
    float d2 = 2.0 + 2.0 * w[3] / w2;
    float d3 = 4.0 + 2.0 * w[5] / w3;
    float d4 = 6.0 + 2.0 * w[7] / w4;

    vec2 step_dir = (direction == 0) ? vec2(texel_size.x, 0.0) : vec2(0.0, texel_size.y);

    vec4 color = vec4(0.0);
    color += texture(source_texture, UV + step_dir * d1) * w1;
    color += texture(source_texture, UV - step_dir * d1) * w1;
    color += texture(source_texture, UV + step_dir * d2) * w2;
    color += texture(source_texture, UV - step_dir * d2) * w2;
    color += texture(source_texture, UV + step_dir * d3) * w3;
    color += texture(source_texture, UV - step_dir * d3) * w3;
    color += texture(source_texture, UV + step_dir * d4) * w4;
    color += texture(source_texture, UV - step_dir * d4) * w4;
    color /= (w_total * 2.0);

    COLOR = color;
}
```

### Audio Bridge (MilkDrop variable mapping)
```gdscript
# Source: Based on MilkDrop3 milkdropfs.cpp RunPerFrameEquations audio variable setup
# + CONTEXT.md audio mapping decisions

var bass: float = 0.0
var mid: float = 0.0
var treb: float = 0.0
var bass_att: float = 0.0  # Attenuated (slower decay) version
var mid_att: float = 0.0
var treb_att: float = 0.0

const ATT_DECAY := 0.92  # Smoothing factor for _att variants

func update() -> void:
    var data := AudioManager.audio_data
    if data == null or not AudioManager.has_signal:
        return

    # Immediate values (fast response)
    bass = data.grouped[0]  # LOW: sub-bass + bass
    mid = (data.grouped[1] + data.grouped[2]) * 0.5  # MID_LOW + MID_HIGH averaged
    treb = data.grouped[3]  # HIGH: brilliance

    # Attenuated values (slower decay for smooth envelope)
    bass_att = maxf(bass, bass_att * ATT_DECAY)
    mid_att = maxf(mid, mid_att * ATT_DECAY)
    treb_att = maxf(treb, treb_att * ATT_DECAY)
```

## MilkDrop Built-In Waveform Modes Reference

| Mode | Name | Description | Audio Source |
|------|------|-------------|-------------|
| 0 | Circle | Circular waveform pulsing with audio. `wave_mystery` adjusts base radius | PCM waveform (right channel) |
| 1 | XY Oscillation Spiral | X/Y oscillating spiral pattern | PCM waveform (both channels) |
| 2 | Centered Spirograph | Spirograph centered on screen | PCM waveform |
| 3 | Centered Spiro (Volume) | Same as 2 but alpha modulated by volume | PCM waveform |
| 4 | Derivative Line | Horizontal line showing derivative of waveform | PCM waveform (derivative) |
| 5 | Explosive Hash | Burst pattern radiating from center | PCM waveform |
| 6 | Line | Simple horizontal oscilloscope line | PCM waveform (left channel) |
| 7 | Double Line | Two parallel horizontal lines (L/R channels) | PCM waveform (both channels) |

**MVP implementation priority:** Modes 0 (Circle), 6 (Line), 7 (Double Line) are the most commonly used. Mode 5 (Explosive Hash) is popular in classic presets. Start with these 4.

## State of the Art

| Old Approach | Current Approach | When Changed | Impact |
|--------------|------------------|--------------|--------|
| HLSL pixel shaders for warp/comp | CPU per-vertex equations (skip HLSL) | MilkDrop 2.0 added shaders, but original per-vertex still works | For MVP, skip warp/comp shaders entirely. Per-vertex equations produce the classic MilkDrop look. Shader presets are deferred. |
| DirectX 9 fixed-function pipeline | OpenGL/WebGL/Godot shader pipeline | All modern ports | Use canvas_item shaders for 2D passes, spatial shaders for 3D display |
| Native C NSEEL (JIT compiled) | Interpreted evaluation (JS/WASM/GDScript) | butterchurn (JS), projectM (compiled) | GDScript interpretation will be slower than C. Profile early, optimize hot paths |
| Single-threaded rendering | Could use Godot WorkerThreadPool for per-vertex eval | N/A | Future optimization if needed |

**Deprecated/outdated:**
- MilkDrop 1.x fixed-function pipeline: replaced by shader pipeline in 2.0
- `PSVERSION=0` (no shaders): still supported as fallback, and actually what we implement for MVP
- Comp/warp HLSL shaders from presets: deferred, many great presets don't use them

## Open Questions

1. **Per-vertex NSEEL performance in GDScript**
   - What we know: 128x96 = 12,417 evaluations per frame. GDScript is interpreted.
   - What's unclear: Actual ms cost per evaluation with typical preset complexity. Could be 0.01ms (fine) or 0.1ms (too slow).
   - Recommendation: Build with 128x96, profile immediately. Have 64x48 and 32x24 as fallback grid sizes. Many presets don't have per_pixel code at all -- skip per-vertex eval entirely for those.

2. **ConfigFile compatibility with .milk format**
   - What we know: .milk files have `[preset00]` section header and `key=value` pairs. ConfigFile should handle this.
   - What's unclear: Whether ConfigFile handles lines with `=` in the value (equation lines like `per_frame_1=zoom = zoom + 0.1`). May need to split on first `=` only.
   - Recommendation: Test ConfigFile first. If it fails on equation values, use custom line parser (simple: split each line on first `=`).

3. **Waveform audio data source**
   - What we know: MilkDrop uses 512 raw PCM samples for waveforms (mysound.fWave[0]/[1]). Our AudioManager only provides FFT band magnitudes, not raw waveform data.
   - What's unclear: Whether Godot's AudioEffectSpectrumAnalyzer can provide raw waveform samples, or if we need AudioEffectCapture.
   - Recommendation: Check if AudioEffectCapture can provide raw PCM buffer. If not, synthesize approximate waveform from FFT bands. Custom waves with per-point equations can work without raw samples (they use `value1`/`value2` which come from audio).

4. **2048x2048 SubViewport performance on Quest 3 via Virtual Desktop**
   - What we know: Phase 4 used 768x768. 2048x2048 is 7x more pixels.
   - What's unclear: Whether two 2048x2048 SubViewports + blur passes stay within 11ms frame budget.
   - Recommendation: Start at 2048x2048. If too slow, drop to 1024x1024 (still higher quality than Phase 4).

## Validation Architecture

### Test Framework
| Property | Value |
|----------|-------|
| Framework | GUT (Godot Unit Testing) or manual verification |
| Config file | None -- see Wave 0 |
| Quick run command | Manual: run project, load preset, verify visually |
| Full suite command | Manual: load each of 5 test presets, verify rendering |

### Phase Requirements -> Test Map
| Req ID | Behavior | Test Type | Automated Command | File Exists? |
|--------|----------|-----------|-------------------|-------------|
| VIS-03 | Milkdrop warp mode renders with audio-driven zoom/rot/warp/decay | manual | Load preset, play audio, verify visual response | N/A Wave 0 |
| VIS-04 | Flowing psychedelic visuals via SubViewport ping-pong | manual | Load preset, verify feedback loop produces trails | N/A Wave 0 |
| INF-04 | Renders correctly in VR and flat-screen | manual | Test in flat-screen (macOS) and VR (Quest 3) | N/A Wave 0 |

### NSEEL Interpreter Unit Tests (automatable)
| Test | Description | Automated |
|------|-------------|-----------|
| Tokenizer | Verify tokenization of number, identifier, operator, function tokens | Yes - script test |
| Parser | Verify AST generation for `zoom = zoom + 0.1*sin(time);` | Yes - script test |
| Evaluator | Verify `sin(3.14159)` ~= 0, `if(1,2,3)` == 2, `above(1,0)` == 1 | Yes - script test |
| Variable scoping | Verify q1-q32 transfer between pools, custom vars don't leak | Yes - script test |
| Preset parsing | Load 5 test .milk files, verify all parameters extracted | Yes - script test |

### Sampling Rate
- **Per task commit:** Load a test preset, verify it renders without errors
- **Per wave merge:** Load all 5 test presets sequentially, verify each renders
- **Phase gate:** All 5 presets render with correct warp behavior and waveforms in flat-screen mode

### Wave 0 Gaps
- [ ] `scripts/milkdrop/test_nseel.gd` -- NSEEL interpreter unit tests
- [ ] `scripts/milkdrop/test_preset_loader.gd` -- Preset file parsing tests
- [ ] 5 test .milk preset files in `presets/` directory (select from milkdrop-original pack: mix of simple per-frame-only presets and complex per-pixel+wave presets)
- [ ] Consider GUT framework installation if automated testing desired: `git clone https://github.com/bitwes/Gut.git addons/gut`

## Sources

### Primary (HIGH confidence)
- MilkDrop3 source: `milkdropfs.cpp` -- Complete rendering pipeline (RenderFrame, ComputeGridAlphaValues, WarpedBlit, BlurPasses, DrawCustomShapes)
- MilkDrop3 source: `state.h` / `state.cpp` -- Preset state structure, Import/Export, variable definitions, defaults
- MilkDrop3 source: `plugin.h` -- CPlugin class with shader/texture/audio management
- MilkDrop3 source: `ns-eel2/` -- NSEEL interpreter (tokenizer, compiler, evaluator)
- projectM source: `Waveforms/Factory.cpp` -- Wave mode 0-15 mapping to implementations
- projectM source: `Waveforms/*.cpp` -- Individual waveform vertex generation
- Geiss preset authoring guide: https://www.geisswerks.com/milkdrop/milkdrop_preset_authoring.html -- Variable reference, NSEEL function list, preset structure
- Real .milk preset files from `projectM-visualizer/presets-milkdrop-original` -- File format verification

### Secondary (MEDIUM confidence)
- butterchurn DeepWiki: https://deepwiki.com/jberg/butterchurn -- WebGL port architecture, rendering pipeline order, equation evaluation approach
- projectM DeepWiki: https://deepwiki.com/projectM-visualizer/projectm -- C++ reimplementation architecture, rendering order
- Godot ImmediateMesh docs: https://docs.godotengine.org/en/stable/tutorials/3d/procedural_geometry/immediatemesh.html -- Per-frame geometry generation

### Tertiary (LOW confidence)
- Performance estimates for GDScript NSEEL evaluation -- needs profiling to validate
- 2048x2048 SubViewport performance on Quest 3 -- needs testing

## Metadata

**Confidence breakdown:**
- Standard stack: HIGH -- Godot SubViewport/ArrayMesh/ImmediateMesh are well-documented and proven in Phase 4
- Architecture: HIGH -- MilkDrop rendering pipeline is thoroughly documented in MilkDrop3, projectM, and butterchurn source code
- Pitfalls: MEDIUM -- Performance concerns for GDScript NSEEL are theoretical, need profiling
- NSEEL language spec: HIGH -- Complete function list and variable reference from official authoring guide + source code
- .milk file format: HIGH -- Verified against real preset files from official preset pack

**Research date:** 2026-04-20
**Valid until:** 2026-05-20 (stable domain -- MilkDrop spec hasn't changed in years)
