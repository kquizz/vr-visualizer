# Pitfalls Research

**Domain:** PCVR Music Visualizer -- BlackHole audio capture, FFT visualization, Milkdrop shaders, mode switching
**Researched:** 2026-04-16
**Confidence:** MEDIUM-HIGH (verified against Godot issues, official docs, and community experience)

## Critical Pitfalls

### Pitfall 1: BlackHole Audio Routing Kills Speaker Output

**What goes wrong:**
Developer sets macOS system output to BlackHole 2ch to route audio into Godot. System audio now goes ONLY to BlackHole -- speakers/headphones go silent. User can no longer hear the music they are trying to visualize.

**Why it happens:**
BlackHole is an audio sink, not a tap. Setting it as the system output device redirects ALL audio to BlackHole and nowhere else. This is how virtual audio devices work on macOS -- there is no built-in "monitor" mode.

**How to avoid:**
Create a Multi-Output Device in macOS Audio MIDI Setup that includes BOTH the real speakers/headphones AND BlackHole 2ch. Set this Multi-Output as the system output. Critical setup details:
- Built-in Output MUST be the top/primary/clock device in the Multi-Output (macOS bug)
- BlackHole 2ch as secondary device
- Enable Drift Correction for BlackHole but NOT for the clock source device
- Volume cannot be adjusted on Multi-Output devices via macOS menu bar -- adjust individual device volumes in Audio MIDI Setup
- Right-click the Multi-Output and select "Use This Device For Sound Output"

Then in Godot, set the audio input device to BlackHole 2ch.

**Warning signs:**
No sound from speakers when testing. Or "it works on my setup" but no setup documentation for new installs.

**Phase to address:**
Phase 1 (BlackHole audio capture). Must be validated before any FFT work begins. Include setup documentation as a deliverable.

---

### Pitfall 2: Godot macOS Audio Input Device Selection Bug

**What goes wrong:**
AudioStreamMicrophone works with the default macOS input device but fails with AudioUnitRender error -10863 when switching to a non-default device like BlackHole. Audio capture silently fails or spams errors.

**Why it happens:**
Long-standing Godot bug (Issues #35445, #106397) -- sample rate mismatch between Godot's expected mix rate and the input device's native sample rate. When the input device changes, Godot does not properly reinitialize the audio unit. A separate macOS mic initialization bug (#110624) was fixed and merged for Godot 4.6.

**How to avoid:**
- Use Godot 4.6 which includes the macOS mic fix (PR #111691)
- Set BlackHole as the DEFAULT macOS input device in System Settings > Sound > Input BEFORE launching Godot, rather than switching devices at runtime
- Match Godot's audio mix rate (project.godot `audio/driver/mix_rate`) to BlackHole's sample rate (default 48000 for both, but verify in Audio MIDI Setup)
- If errors persist, set BlackHole as part of an Aggregate Device with Built-in Microphone as the clock source
- Enable `audio/enable_audio_input = true` in project settings

**Warning signs:**
Console spam of `input_callback: AudioUnitRender failed, code: -10863`. AudioEffectSpectrumAnalyzer returning all zeros on the capture bus. No FFT data despite music playing.

**Phase to address:**
Phase 1 (BlackHole audio capture). This is the highest-risk technical item -- must be proven working before building anything on top.

---

### Pitfall 3: Existing AudioManager Architecture Assumes 4 Stems, Not 1 Input

**What goes wrong:**
Current AudioManager is designed around 4 separate AudioStreamPlayers on 4 buses (Drums, Bass, Vocals, Other), each with their own SpectrumAnalyzer. The new FFT-first approach uses a SINGLE audio input (BlackHole) analyzed as one stream. Developers try to bolt the new approach onto the old architecture, ending up with confusing hybrid code that half-works.

**Why it happens:**
The Phase 1 codebase is stem-centric. ShaderBridge pushes `drums_energy`, `bass_energy`, etc. as separate global shader uniforms (4 stems x 4 uniforms = 16 uniforms). The reflex is to preserve this API to avoid touching shaders. But the conceptual model has fundamentally changed: instead of 4 audio sources each analyzed for 7 bands, there is 1 audio source analyzed for 7 bands.

**How to avoid:**
Clean break. Refactor AudioManager to:
- Single AudioStreamPlayer with AudioStreamMicrophone on a single "Capture" bus
- Single SpectrumAnalyzer on that bus
- Single AudioData instance (not an array of 4)
- ShaderBridge pushes simplified uniforms: `audio_energy`, `audio_bands_low`, `audio_bands_high`, `audio_peak_freq` (4 uniforms instead of 16)
- Remove stem sync logic, stem playback, stem bus references entirely
- Keep the AudioData class and 7-band FFT analysis -- that code is solid

Preserve the old AudioManager in a `_legacy/` folder if desired, but do not try to support both modes in one class.

**Warning signs:**
AudioManager still references `STEM_NAMES`. ShaderBridge still pushes `drums_*`, `bass_*` etc. New code has `if is_stem_mode:` branches.

**Phase to address:**
Phase 1 (audio capture refactor). Must happen before FFT visualization work.

---

### Pitfall 4: FFT-to-Visual Mapping That Looks Boring or Twitchy

**What goes wrong:**
Visualizer looks like a generic equalizer bar graph that flickers randomly, does not feel connected to the music, and fails to produce the "holy shit" reaction. Bass feels the same as treble. Quiet sections and loud sections look identical.

**Why it happens:**
Multiple compounding mistakes:
1. **Linear frequency mapping** -- FFT bins are linear but hearing is logarithmic. Low frequencies get 2-3 bars, high frequencies get 50. Sub-bass is invisible.
2. **No dynamic range compression** -- quiet passages produce near-zero values, loud passages clip at 1.0. Most of the time the visualizer is either dead or maxed out.
3. **Same visual weight per band** -- sub-bass (20-60Hz) and brilliance (6-11kHz) are treated equally, but sub-bass carries the groove and should dominate visually.
4. **Smoothing too aggressive or too weak** -- too much smoothing = mushy, unresponsive. Too little = twitchy noise.

**How to avoid:**
- The existing 7-band logarithmic mapping in AudioManager is already correct (bands are musically spaced, not linear). Keep it.
- Use asymmetric smoothing (already implemented: attack 0.3, decay 0.05). Tune per-mode if needed.
- Add automatic gain control: track a rolling max over ~2 seconds, normalize bands against it. This keeps visuals lively during quiet sections.
- Weight sub-bass and bass more heavily in visual mappings (2-3x multiplier on visual displacement/color intensity for bands 0-1).
- Use `log(max_power)` not `average_power` per band for peak preservation.
- Add beat detection on the sub-bass band (threshold crossing with cooldown) for punctuated visual events (flash, pulse, zoom).

**Warning signs:**
Visualizer looks the same regardless of what song is playing. Quiet acoustic track looks like heavy EDM. No visual difference between drop and breakdown.

**Phase to address:**
Phase 2 (FFT visualization). Build the gain control and beat detection into AudioManager, not into individual modes.

---

### Pitfall 5: Milkdrop Feedback Loop Artifacts in VR

**What goes wrong:**
Milkdrop-style warp effects rely on rendering the previous frame's output, warping/distorting it with a shader, then compositing new elements on top. In Godot, this requires SubViewport ping-pong buffers. On certain GPUs or configurations, this produces grid-like artifacts, incorrect UV sampling, or accumulated precision errors that turn the visual into colored noise after 30 seconds.

**Why it happens:**
- Godot Issue #81527: confirmed grid artifacts on mobile GPUs with feedback loop shaders (though this project targets desktop GPU via PCVR, the pattern is fragile)
- SubViewport texture sampling can be off-by-half-pixel, causing drift in the feedback loop
- No automatic double-buffering for viewport feedback in Godot -- developer must manually implement ping-pong
- Accumulated floating-point error in UV warping compounds over hundreds of frames

**How to avoid:**
- Use two SubViewports as explicit ping-pong buffers. Frame N reads from viewport A, writes to viewport B. Frame N+1 reads from B, writes to A. Toggle every frame.
- Use `SubViewport` directly, NOT `SubViewportContainer` (the container adds unwanted resizing behavior)
- Set `transparent_bg = false` and clear color to black on both viewports
- Apply subtle fade-to-black each frame (multiply previous frame by 0.98-0.99) to prevent infinite energy accumulation and wash out precision errors over time
- Sample textures with explicit `textureLod(tex, uv, 0.0)` to avoid mipmap artifacts
- Render feedback at half resolution (960x540 per eye equivalent) -- full resolution feedback is expensive and the blur from upscaling actually looks good for warp effects
- Test for 5+ minutes continuously -- artifacts from precision drift take time to appear

**Warning signs:**
Visual looks great for 10 seconds then degrades. Grid patterns appear. Colors saturate to white. Warping "drifts" in one direction over time.

**Phase to address:**
Phase 3 (Milkdrop shader). Requires careful SubViewport architecture from the start -- cannot be patched onto a naive implementation.

---

### Pitfall 6: VR Shader Compilation Stutter on Mode Switch

**What goes wrong:**
First time switching to a new visualizer mode, there is a 100-500ms frame hitch while the GPU compiles the mode's shader(s). In VR at 90fps, even a single dropped frame is noticeable, and 500ms causes visible judder and discomfort.

**Why it happens:**
Godot compiles GPU shaders on first use, not at load time. Each visualizer mode has unique shaders that the GPU has not seen until the mode is activated. The compilation blocks the render thread.

**How to avoid:**
- Project already has `xr/shaders/shader_compilation_mode=1` (asynchronous compilation) -- good
- Additionally, pre-warm all mode shaders at startup: instantiate every mode scene offscreen during a loading screen, render one frame, then free the scene. This forces shader compilation before the user sees anything.
- Alternatively, use Godot's `ShaderMaterial.resource_local_to_scene` and preload all shader materials at startup
- Keep mode scenes lightweight enough that instantiation itself is fast (< 50ms)
- For the ping-pong SubViewport setup, pre-warm those too -- the feedback shaders need to compile

**Warning signs:**
First mode switch hitches. Second switch to the same mode is smooth. Frame time spikes in profiler during scene transitions.

**Phase to address:**
Phase 4 (mode switching). Must be designed into the mode management system from the start. Include a loading/warm-up step at app launch.

---

## Technical Debt Patterns

| Shortcut | Immediate Benefit | Long-term Cost | When Acceptable |
|----------|-------------------|----------------|-----------------|
| Keeping stem-based shader uniforms (drums_*, bass_*, etc.) and mapping FFT bands to them | Avoid touching existing shaders | Confusing API -- "drums_energy" doesn't mean drums anymore. Every new contributor will be confused. | Never -- clean rename takes 30 minutes |
| Hardcoding BlackHole device name in AudioManager | Gets audio working fast | Breaks on any other Mac, or if BlackHole is renamed/updated. No fallback. | Only for spike/prototype. Replace with configurable device selection. |
| Single SubViewport for feedback (read+write same texture) | Simpler code, fewer nodes | Works on some GPUs, fails on others. Undefined behavior per GPU spec. | Never -- always use ping-pong |
| Skipping automatic gain control | Simpler audio pipeline | Visualizer looks dead on quiet music, clipped on loud music. Manual volume adjustment needed. | Acceptable for first mode prototype, but add AGC before second mode |
| Mode switching via scene tree replacement (queue_free + instantiate) | Simple implementation | Frame hitch from scene instantiation. Shaders recompile if materials were freed. | Never for VR -- keep modes loaded, toggle visibility |

## Integration Gotchas

| Integration | Common Mistake | Correct Approach |
|-------------|----------------|------------------|
| BlackHole + macOS | Setting BlackHole as system output directly (kills speaker audio) | Create Multi-Output Device with speakers as primary, BlackHole as secondary |
| BlackHole + Godot | Trying to select BlackHole as input device at runtime via code | Set BlackHole as default input device in macOS System Settings before launching Godot |
| AudioStreamMicrophone + AudioEffectCapture | Adding AudioEffectCapture to capture bus without enabling audio input in project settings | Enable `audio/enable_audio_input = true` in Project Settings > Audio |
| AudioStreamMicrophone + Speaker Output | Microphone input plays back through speakers, creating feedback loop | Route the capture bus to a silent/muted bus, or set the capture bus volume to -80dB. Only use the SpectrumAnalyzer effect on it, do not route to Master |
| SubViewport + XR | SubViewport renders to a 2D texture, but XR needs stereoscopic rendering | SubViewport feedback textures are applied to 3D geometry (e.g., a sphere or full-screen quad) within the XR scene -- they are NOT rendered as a HUD/overlay |
| Virtual Desktop + Audio | Assuming Virtual Desktop passes audio back to Quest -- it does, but with ~20-40ms latency | Design visuals to be forgiving of audio-visual offset. Avoid sharp frame-exact sync (e.g., flash on every beat). Use smooth reactive animations instead. |

## Performance Traps

| Trap | Symptoms | Prevention | When It Breaks |
|------|----------|------------|----------------|
| Full-resolution feedback buffer per eye | Frame time > 11ms, GPU bottleneck in profiler | Render feedback at half resolution, upscale. The inherent blur is aesthetically appropriate for warp effects. | Immediately on complex shaders |
| Too many global shader uniform updates per frame | CPU time in `_process` climbs, stutter on uniform-heavy frames | Batch uniform updates. Current 16 uniforms (4 stems x 4) should become 4 (1 source x 4). Never exceed ~20 global uniforms. | ~30+ uniform updates per frame |
| Spectrum analyzer buffer too small | FFT data lags behind audio, visualizer feels sluggish | Use `AudioEffectSpectrumAnalyzer.buffer_length` of 0.1s (default). Do not increase beyond 0.5s. | Buffer > 0.5s adds perceptible visual lag |
| Multiple additive-blend passes in warp shader | Glow/bloom looks great but fragments per second budget blown | Use Godot's built-in `WorldEnvironment` glow as a single post-process pass instead of per-object additive materials | > 2 additive fullscreen passes |
| Per-frame SubViewport.get_texture() allocation | GC pressure, micro-stutters from garbage collection | Cache the ViewportTexture reference. Assign once, not every frame. | Visible after 30+ seconds as periodic micro-hitches |

## UX Pitfalls

| Pitfall | User Impact | Better Approach |
|---------|-------------|-----------------|
| No visual feedback when audio is not detected | User puts on headset, sees nothing moving, assumes app is broken | Show a "waiting for audio" indicator or ambient animation. Pulse a "no audio detected" message in the debug overlay. |
| Mode switch with no transition | Jarring instant cut between visual styles, feels broken in VR | Cross-fade over 0.5-1s: fade old mode out (reduce opacity/energy), fade new mode in. Even a simple fade-to-black-and-back works. |
| Intense flashing visuals on beat drops | Motion sickness, photosensitive seizure risk, VR amplifies both | Cap maximum brightness change rate. Never go from black to white in a single frame. Clamp beat-reactive brightness to 0.7 max. Add a "reduced motion" toggle. |
| No way to exit/pause without removing headset | User is trapped in visualization, cannot pause or adjust | Map controller menu button to a simple radial menu: pause, switch mode, exit. Always accessible. |
| Visualization identical regardless of genre | EDM and jazz look the same, no genre-appropriate response | Weight bands differently per mode. Spectrum bars should emphasize all bands equally. Warp mode should weight sub-bass heavily. Let modes have personality. |

## "Looks Done But Isn't" Checklist

- [ ] **BlackHole capture:** Audio data flows -- verify by checking AudioData.energy > 0 in debug overlay while music plays. Zero energy = capture not working.
- [ ] **FFT responsiveness:** Visualizer responds to music -- verify by playing silence, then bass-heavy music. Sub-bass band should jump. If all bands move together uniformly, the frequency mapping is wrong.
- [ ] **Feedback loop stability:** Warp shader looks good -- verify by letting it run for 5+ minutes. If it degrades to noise or white, there is a precision/accumulation bug.
- [ ] **Mode switching:** Modes switch -- verify first switch AND return to original mode. If returning to mode 1 after mode 2 shows a stutter, shaders were freed and recompiled.
- [ ] **VR comfort:** Looks good on desktop -- verify in headset. Peripheral motion that is fine on a monitor can be nauseating in VR. Test with the headset on for at least 5 minutes per mode.
- [ ] **Multi-Output Device:** Audio routes to Godot -- verify speakers ALSO still produce sound. If you can hear it but Godot gets no data (or vice versa), the Multi-Output Device is misconfigured.
- [ ] **Gain normalization:** Works on one song -- verify on quiet acoustic track AND loud EDM. Both should produce visible, dynamic visualization without manual volume adjustment.

## Recovery Strategies

| Pitfall | Recovery Cost | Recovery Steps |
|---------|---------------|----------------|
| BlackHole routing kills speakers | LOW | Create Multi-Output Device in Audio MIDI Setup. 5-minute fix, but must be documented. |
| Audio input device bug (-10863) | MEDIUM | Set BlackHole as default input before launch. If persistent, create Aggregate Device. May need Godot 4.6 build with mic fix. |
| Stem-based architecture not refactored | MEDIUM | Rename uniforms, simplify AudioManager to single-source. ~2-4 hours of focused refactoring. Longer if shaders reference old uniform names. |
| FFT visuals look boring | LOW | Tune smoothing constants, add AGC, add beat detection. Iterative -- no architecture change needed. |
| Feedback loop artifacts | HIGH | Requires implementing proper ping-pong SubViewport architecture. If done wrong initially, substantial rework of the warp mode scene tree and shader I/O. |
| Shader compilation stutter | MEDIUM | Add pre-warming at startup. Requires keeping all mode scenes in memory (toggle visibility, not instantiate/free). May need loading screen. |

## Pitfall-to-Phase Mapping

| Pitfall | Prevention Phase | Verification |
|---------|------------------|--------------|
| BlackHole routing kills speakers | Phase 1: Audio Capture | Speakers produce sound AND debug overlay shows non-zero energy simultaneously |
| Godot macOS audio input bug | Phase 1: Audio Capture | AudioStreamMicrophone produces data from BlackHole for 10+ minutes without errors in console |
| Stem architecture not refactored | Phase 1: Audio Capture | AudioManager has zero references to STEM_NAMES. ShaderBridge uses audio_* not drums_*/bass_* uniforms |
| FFT-to-visual mapping boring | Phase 2: Spectrum Visualizer | Blind test: viewer can tell when music changes between genres. Quiet and loud tracks both produce dynamic visuals |
| Feedback loop artifacts | Phase 3: Milkdrop Shader | Warp effect runs for 10 minutes without visual degradation |
| Shader compilation stutter | Phase 4: Mode Switching | Switching between all modes produces zero frame drops in VR profiler |
| VR comfort (flashing/intensity) | Phase 2-3: Both visualizer modes | 5-minute VR session with no discomfort. Brightness never flashes from 0 to 1 in single frame |

## Sources

- [BlackHole Multi-Output Device Wiki](https://github.com/ExistentialAudio/BlackHole/wiki/Multi-Output-Device) -- official setup guide
- [BlackHole Aggregate Device Wiki](https://github.com/ExistentialAudio/BlackHole/wiki/Aggregate-Device) -- drift correction guidance
- [Godot Issue #106397: macOS AudioUnitRender -10863 on non-default input device](https://github.com/godotengine/godot/issues/106397) -- open, unresolved
- [Godot Issue #110624: Mic recording fails on macOS in 4.5](https://github.com/godotengine/godot/issues/110624) -- fixed in Godot 4.6 (PR #111691)
- [Godot Issue #81527: Grid artifacts with feedback loop shaders](https://github.com/godotengine/godot/issues/81527) -- confirmed, desktop unaffected but pattern is fragile
- [Godot AudioStreamMicrophone docs](https://docs.godotengine.org/en/stable/classes/class_audiostreammicrophone.html)
- [Godot Recording with Microphone tutorial](https://docs.godotengine.org/en/stable/tutorials/audio/recording_with_microphone.html)
- [Better FFT-based Audio Visualization (Daniel Beer)](https://www.dlbeer.co.nz/articles/fftvis.html) -- smoothing and mapping techniques
- [Audio Analysis for Music Visualization (ciphrd)](https://ciphrd.com/2019/09/01/audio-analysis-for-advanced-music-visualization-pt-1/) -- frequency band analysis patterns
- [projectM OpenGL/Shader Modernization](https://spiegelmock.com/2018/07/29/projectm-opengl-and-shader-modernization/) -- Milkdrop warp/composite pass architecture
- [Godot SubViewport as Texture docs](https://docs.godotengine.org/en/stable/tutorials/shaders/using_viewport_as_texture.html) -- ping-pong buffer pattern
- [Godot XR Tools Staging](https://godotvr.github.io/godot-xr-tools/docs/staging/) -- VR scene switching patterns

---
*Pitfalls research for: PCVR FFT-first music visualizer with BlackHole capture, Milkdrop shaders, mode switching*
*Researched: 2026-04-16*
