# Domain Pitfalls

**Domain:** VR Music Visualizer (Quest 3 Standalone)
**Researched:** 2026-04-13

## Critical Pitfalls

Mistakes that cause rewrites or major issues.

### Pitfall 1: Assuming Tidal API Provides Stems

**What goes wrong:** You design the architecture around real-time Tidal streaming with stem separation, then discover stems are only available through licensed DJ software partners (Serato, djay, etc.), not the developer API.
**Why it happens:** Tidal markets "stem separation" prominently. The DJ Extension add-on provides stems in partner apps. It is natural to assume the developer API exposes this.
**Consequences:** Architecture rework. Months of wasted effort building a Tidal streaming integration that can never deliver the core feature.
**Prevention:** Design around local pre-separated files from day one. The desktop Demucs pipeline is the audio source, not Tidal's API. Tidal subscription is only useful for sourcing the original tracks to feed into Demucs.
**Detection:** If you find yourself writing HTTP calls to Tidal endpoints for audio data, stop.

### Pitfall 2: Shader Complexity Exceeding Mobile GPU Budget

**What goes wrong:** Beautiful visualizer on desktop preview crashes to 20fps on Quest 3, causing VR sickness.
**Why it happens:** Milkdrop-style effects use fullscreen fragment shaders with texture sampling, feedback loops, and complex math. Desktop GPUs handle this trivially. The Adreno 740 has 3.6 TFLOPS but thermal throttling and mobile memory bandwidth limit real-world performance significantly.
**Consequences:** Must rewrite shaders to be simpler, losing visual quality. Or accept stuttering, which is unacceptable in VR.
**Prevention:**
- Target fragment shader cost of <50 ALU instructions per pixel for fullscreen effects
- Use mediump/lowp precision everywhere possible (FP16 is free performance on Adreno)
- Limit SubViewport feedback to half resolution (render at 50% of eye resolution, upscale)
- Profile on device early and often -- never trust desktop performance
- One fullscreen shader pass max per mode, not stacked passes
**Detection:** Frame time > 11ms on Quest 3 (for 90fps target). Use Godot's built-in profiler or Meta's RenderDoc for Quest.

### Pitfall 3: Stem Synchronization Drift

**What goes wrong:** The 4 stem AudioStreamPlayers gradually drift out of sync, creating audible phasing/flanging artifacts that make the music sound broken.
**Why it happens:** Each AudioStreamPlayer runs independently. OGG decoding is non-deterministic in timing. Godot's audio server processes in chunks. Over a 4-minute song, even tiny per-frame timing differences accumulate.
**Consequences:** The music sounds wrong. The entire value proposition (clean per-stem audio) is undermined.
**Prevention:**
- Start all 4 players on the exact same frame in `_ready()` or a deferred call
- Every 1-2 seconds, check `get_playback_position()` on all 4 players
- If any player drifts > 10ms from the drums track (reference), `seek()` to drums position
- Consider WAV instead of OGG if decoding latency is inconsistent (WAV = no decode overhead, but larger files)
**Detection:** Record audio output and check waveform alignment. Or listen for phasing artifacts on familiar tracks.

### Pitfall 4: Using Forward+ Renderer on Quest 3

**What goes wrong:** Project works on desktop, exports to Quest 3, gets black screen or single-digit fps.
**Why it happens:** Forward+ is Godot's default renderer. New project defaults to it. Developer doesn't change it before building out the project.
**Consequences:** Must switch renderer mid-project, which can break materials, shaders, and visual settings. Some Forward+ features have no equivalent in Mobile renderer.
**Prevention:** Set `renderer/rendering_method = "mobile"` in project.godot BEFORE writing any shaders or materials. This is a first-5-minutes decision.
**Detection:** If your export preset targets Android and your renderer is Forward+, you have already made this mistake.

## Moderate Pitfalls

### Pitfall 5: FFT Jitter Making Visuals Twitchy

**What goes wrong:** Visualizer elements twitch and flicker because raw FFT magnitudes jump wildly frame-to-frame.
**Prevention:** Smooth all FFT values with exponential moving average: `smoothed = lerp(smoothed, raw, 0.15)`. Different smoothing factors for attack (fast, ~0.3) vs decay (slow, ~0.05) gives punchy-but-smooth response. Never use raw FFT values directly as shader uniforms.

### Pitfall 6: APK Size Explosion from Bundled Stems

**What goes wrong:** Bundling even a few songs as stems in the APK makes it 500MB+, slow to install, eats Quest storage.
**Prevention:** Ship APK with 1 demo song (4 stems, ~20MB). Load additional stems from device storage (`user://stems/`). Provide instructions for transferring via USB or WiFi file manager. Quest 3 has 128/512GB storage -- let users fill it.

### Pitfall 7: Shader Compilation Stutters on Mode Switch

**What goes wrong:** First time switching to a new mode, there is a 200-500ms stutter while the GPU compiles the mode's shader(s). In VR, this is jarring.
**Prevention:** Godot 4.5+ has shader baking support. Pre-compile all mode shaders at app startup (loading screen). Alternatively, instantiate every mode scene once during startup (offscreen) to force shader compilation, then free them.

### Pitfall 8: Overdraw from Transparent/Additive Materials

**What goes wrong:** Visualizer uses lots of additive blending (glow, light trails) which causes massive overdraw. Mobile GPU fragments per second budget exhausted.
**Prevention:** Limit additive surfaces to small screen area. Use glow as a post-process (Godot's WorldEnvironment glow) rather than per-object additive materials. Keep opaque geometry in front to enable early-Z culling.

### Pitfall 9: Hand Tracking Unreliability for Mode Switching

**What goes wrong:** Gesture-based mode switching triggers accidentally (user moves hands while dancing) or fails to trigger (dark room, hands at sides).
**Prevention:** Defer gesture controls to a later phase. Start with controller buttons which are 100% reliable. If implementing gestures, use deliberate gestures (pinch + swipe) not ambient motion, and add a confirmation step or cooldown.

## Minor Pitfalls

### Pitfall 10: OGG vs WAV Stem Format

**What goes wrong:** Using WAV stems for quality, but 4x WAV for a 4-minute song = ~160MB per song. Or using low-bitrate OGG and getting audible compression artifacts.
**Prevention:** OGG Vorbis at quality 5 (~160kbps) is sufficient. Compression artifacts are inaudible in a party setting. 4 stems at quality 5 = ~20MB per song. Use WAV only if sync drift issues point to OGG decoding as the cause.

### Pitfall 11: Forgetting ASTC Texture Compression

**What goes wrong:** Textures default to ETC2 compression, which is fine but ASTC is better on Quest 3's Adreno 740.
**Prevention:** Enable `textures/vram_compression/import_etc2_astc = true` in project settings. ASTC gives better quality at same memory cost.

### Pitfall 12: Not Testing with Quest 3 Developer Mode Early

**What goes wrong:** Build entire project on desktop, try to deploy to Quest 3 for the first time weeks in, and discover a chain of setup issues (developer mode, USB debugging, export templates, signing).
**Prevention:** First session: get a blank XR scene running on Quest 3. Solve all the toolchain problems with a trivial project. Then build features.

## Phase-Specific Warnings

| Phase Topic | Likely Pitfall | Mitigation |
|-------------|---------------|------------|
| Initial VR setup | Forward+ renderer selected by default (Pitfall 4) | Set Mobile renderer before any other work |
| Audio pipeline | Stem sync drift (Pitfall 3) | Implement sync checking from day one, not as a fix later |
| First visualizer mode | FFT jitter (Pitfall 5) | Implement smoothing in AudioManager, not per-mode |
| Milkdrop-style effects | Shader too complex for mobile (Pitfall 2) | Start with half-resolution feedback, profile immediately |
| Multiple modes | Shader compilation stutter (Pitfall 7) | Pre-compile shaders at startup |
| Song library | APK bloat (Pitfall 6) | External storage from the start |
| Gesture controls | Accidental triggers (Pitfall 9) | Defer to late phase, require deliberate gestures |

## Sources

- [Quest 3 XR Performance Considerations (Godot Forum)](https://forum.godotengine.org/t/performance-considerations-for-stand-alone-xr/52324)
- [Quest 3 Renderer Discussion (Godot Forum)](https://forum.godotengine.org/t/quest-3-standalone-forward-mobile-or-compatibility-for-a-3d-vr-project-in-godot-4-6/136328)
- [Godot AudioEffectSpectrumAnalyzer Jitter Issue](https://github.com/godotengine/godot/issues/67650)
- [Shader Performance Optimization in Godot](https://peerdh.com/blogs/programming-insights/shader-performance-optimization-techniques-in-godot)
- [Optimizing 3D Scenes in Godot on ARM GPUs](https://developer.arm.com/community/arm-community-blogs/b/mobile-graphics-and-gaming-blog/posts/optimizing-3d-scenes-in-godot-on-arm-gpus-part-2)
- [Meta RenderDoc Optimization Guide](https://developers.meta.com/horizon/blog/how-to-optimize-your-oculus-quest-app-w-renderdoc-walkthroughs-of-key-usage-scenarios-and-optimization-tips-part-1/)
- [TIDAL DJ Extension Support](https://support.tidal.com/hc/en-us/articles/27563493690129-DJ-Extension-Add-On)
