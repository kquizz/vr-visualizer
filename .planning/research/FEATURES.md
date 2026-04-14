# Feature Landscape

**Domain:** VR Music Visualizer (Quest 3 Standalone)
**Researched:** 2026-04-13

## Table Stakes

Features users expect from a VR music visualizer. Missing = "why is this even VR?"

| Feature | Why Expected | Complexity | Notes |
|---------|--------------|------------|-------|
| Immersive 360-degree visual environment | The entire point of VR over a screen. Must surround the user. | Low | Even simple spectrum bars feel magical in VR if they surround you. |
| Audio-reactive visuals | Core value proposition. Visuals must respond to music in real time. | Medium | Per-frame FFT -> shader uniforms. Godot's AudioEffectSpectrumAnalyzer handles this. |
| Smooth 72fps+ performance | VR sickness below 72fps. Non-negotiable. | Medium | Quest 3 supports 72/90/120Hz. Target 90fps, never drop below 72. |
| Controller-based mode switching | Need a way to change visualizer modes without taking off headset. | Low | Simple menu on controller button press. Godot XR Tools has UI interaction. |
| Multiple visualizer modes | One mode gets boring fast. Variety is table stakes for any visualizer. | Medium | Each mode is a self-contained scene. Mode system manages transitions. |
| Volume/audio control | Users expect to control volume without removing headset. | Low | Map to controller thumbstick or trigger. |

## Differentiators

Features that make this special vs. existing VR visualizers.

| Feature | Value Proposition | Complexity | Notes |
|---------|-------------------|------------|-------|
| Per-stem visualization (4 channels) | Dramatically more responsive than mixed-signal FFT. Each instrument drives its own visual layer. This is THE differentiator. | Medium | Requires stem preprocessing pipeline (Demucs) but the visual payoff is enormous. Drums -> impacts, bass -> spatial warp, vocals -> particles, melody -> patterns. |
| Classic Winamp aesthetic (Milkdrop/Geiss/AVS) | Nostalgia factor + these are genuinely the best music visualizer algorithms ever made. No one has put Milkdrop in VR properly. | High | Requires porting shader algorithms from projectM/Butterchurn references. Fragment shader math is well-documented but translating to 3D VR space is novel work. |
| Stem-to-visual semantic mapping | Not just "louder = bigger" but "drums = impact flashes, bass = spatial warping, vocals = flowing ribbons." Intentional, curated mappings. | Medium | Design work more than technical work. Each mode defines its own stem-to-visual mapping. |
| Auto-cycle with crossfade | Modes change automatically on beat drops or time intervals, with smooth visual transitions. DJ-set feel without manual switching. | Medium | Crossfade via SubViewport blending. Beat-drop detection triggers transitions. |
| Gesture-based mode cycling | Wave hand or make gesture to switch modes. Party-friendly -- no controller fumbling. | Medium | Godot XR Tools supports hand tracking on Quest 3. Map swipe gesture to mode change. |

## Anti-Features

Features to explicitly NOT build.

| Anti-Feature | Why Avoid | What to Do Instead |
|--------------|-----------|-------------------|
| In-VR Tidal browsing/streaming | Tidal API does not expose stems. Building a Tidal browser creates the false expectation of real-time stem streaming. | Desktop companion pipeline: select track -> separate stems -> transfer to Quest. |
| Real-time stem separation on device | Quest 3 cannot run Demucs at usable speed. Would drain battery and stutter rendering. | Pre-separate on desktop. Include a simple Python CLI tool. |
| Microphone/ambient audio input | Mixed audio from a mic gives terrible FFT compared to clean stems. Undermines the core value prop. | Focus on curated, pre-separated audio only. |
| Preset editor in VR | Massive UI complexity for a passion project. Milkdrop presets took years of community iteration. | Hardcode modes as Godot scenes. Edit on desktop, test on Quest. |
| Multiplayer/shared experience | Networking complexity with zero payoff for v1. The magic is personal immersion. | Solo experience. Hand someone the headset. |
| PC VR (SteamVR) support | Splits development focus. Quest 3 standalone is the target. | Quest 3 only. PCVR is a future consideration if demand exists. |
| Complex particle physics | Mobile GPU cannot handle thousands of physics-driven particles. Will tank framerate. | Use MultiMesh instancing with vertex shader displacement. Looks like particles, costs like geometry. |

## Feature Dependencies

```
Audio playback system -> FFT analysis per bus -> Visualizer reactivity
                                              -> Beat detection

Stem file loading -> 4x AudioStreamPlayer -> 4x Audio buses -> 4x FFT analyzers

Mode system (scene management) -> Individual visualizer scenes
                                -> Mode transition/crossfade
                                -> Auto-cycle logic

Controller input -> Mode switching menu
Hand tracking    -> Gesture-based mode cycling (depends on Mode system)

Milkdrop-style shaders -> SubViewport feedback loop (warp effects)
                       -> Shader uniform pipeline (audio data -> GPU)
```

## MVP Recommendation

**Phase 1 -- Prove the Pipeline (minimum viable visualizer):**
1. Quest 3 VR app boots with a void environment
2. Load 4 pre-separated stem files (OGG)
3. Play all 4 stems in sync, each on its own audio bus
4. Spectrum bars visualizer: 4 groups of bars, one color per stem, surrounding the user
5. Controller button switches between 2-3 simple modes

This proves: VR rendering, audio playback, per-stem FFT, shader reactivity, mode switching, Quest 3 deployment. Every subsequent mode builds on this foundation.

**Phase 2 -- The Wow Factor:**
1. Milkdrop-style warp tunnel (SubViewport feedback)
2. Stem-to-visual semantic mapping (drums=impacts, bass=warp, etc.)
3. Beat detection driving mode transitions

**Defer:**
- Gesture-based controls: Requires hand tracking tuning. Add after core modes work.
- Auto-cycle crossfade: Nice-to-have. Manual switching is fine for v1.
- Desktop companion app (GUI): CLI pipeline is sufficient. GUI is polish.
- Additional Winamp-style modes (Geiss plasma, AVS, Tripex): Build incrementally after pipeline is proven.

## Sources

- [Godot AudioEffectSpectrumAnalyzer Docs](https://docs.godotengine.org/en/stable/classes/class_audioeffectspectrumanalyzer.html)
- [Godot XR Tools Documentation](https://godotvr.github.io/godot-xr-tools/docs/home/)
- [projectM Visualizer](https://github.com/projectM-visualizer/projectm)
- [TIDAL Developer Portal](https://developer.tidal.com/documentation)
- [Demucs GitHub](https://github.com/facebookresearch/demucs)
