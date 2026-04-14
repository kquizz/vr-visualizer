# Research Summary: VR Music Visualizer

**Domain:** PCVR music visualizer with Serato stem-separated audio reactivity
**Researched:** 2026-04-13
**Overall confidence:** MEDIUM-HIGH

## Executive Summary

The Godot 4.6 + PCVR stack is well-suited for a VR music visualizer. The PCVR approach (Godot on desktop, Quest 3 as wireless display via Virtual Desktop) removes the mobile GPU constraint entirely — full desktop shader power means Milkdrop-quality effects are achievable without compromise. Godot's built-in AudioEffectSpectrumAnalyzer provides per-bus FFT data that can drive shader uniforms at 90fps.

**The biggest architectural pivot from research:** Tidal's developer API does NOT expose stem separation. Stems are exclusively available through licensed DJ software partners. Since Kevin uses Serato DJ Pro 3.0+ (which has built-in stem separation), the architecture centers on tapping Serato's stem output. Since both Serato and Godot run on the same desktop machine in PCVR mode, this becomes an inter-process audio routing problem rather than an API problem.

**Stem access strategy:** Serato separates stems in real-time. Options for getting stem audio into Godot:
1. **Virtual audio routing** (BlackHole/Loopback on macOS, VB-Cable on Windows) — route each Serato stem output to a virtual audio device, capture in Godot
2. **Serato stem file cache** — find where Serato caches separated stems on disk, read those files
3. **Demucs fallback** — pre-separate tracks with Demucs if Serato routing proves too complex

The visualizer rendering approach is well-understood. Classic Winamp/Milkdrop-style effects are fundamentally fragment shaders with audio-reactive uniforms. With desktop GPU, there's no need to compromise on resolution or shader complexity. projectM and Butterchurn provide open-source reference implementations.

Each visualizer mode should be a self-contained Godot scene, managed by an autoload ModeManager. The audio system (also autoload) provides a normalized AudioData struct every frame.

## Key Findings

**Stack:** Godot 4.6 + Forward+ Renderer (desktop GPU) + OpenXR + GDScript + built-in AudioEffectSpectrumAnalyzer + Serato DJ Pro stems

**Architecture:** Autoload singletons (AudioManager, ModeManager, InputManager) persist across mode scene swaps. Each visualizer mode is a PackedScene with its own shaders. Audio data flows as uniform floats from GDScript to GPU per frame.

**Critical finding:** Tidal API does NOT provide stems. Serato does — and since both apps run on the same machine in PCVR, inter-process audio routing is the solution.

**Competitive landscape:** Surprisingly thin. Effex has 9 effects and limited tracks, Evryway is generic FFT, Harmonix Music VR is discontinued. Stem-separated visualization is genuinely novel — no existing VR visualizer does 4-channel stem-driven visuals.

## Implications for Roadmap

Based on research and PCVR pivot, suggested phase structure:

1. **Foundation: PCVR + Audio Pipeline** — Get a VR scene running in Godot on desktop with Virtual Desktop, set up 4-bus audio with FFT, prove stem playback with test files.
   - Addresses: PCVR deployment, audio playback, FFT analysis per stem
   - Critical: Validates the entire technical foundation

2. **First Visualizer + Mode System** — Spectrum bars (simplest geometry) + mode switching infrastructure. Proves the full pipeline from stems to shaders.
   - Addresses: Shader uniform bridge, per-stem visualization, mode system
   - Also builds: Milkdrop warp tunnel as second mode to validate immersive environments

3. **Serato Stem Integration** — Virtual audio routing from Serato to Godot. Real-time stem capture.
   - Addresses: The core differentiator — live Serato stems driving visualization
   - Research needed: Serato's audio routing, BlackHole/Loopback setup

4. **Classic Visualizer Modes** — Milkdrop presets, Geiss plasma, AVS-style, oscilloscope, Tripex geometrics.
   - Addresses: The "wow factor" library of visual experiences
   - Each mode is independent — can be built in parallel

5. **Polish + Party Mode** — Auto-cycle between modes, crossfade transitions, beat detection for mode changes, song browser UX.
   - Addresses: Party-ready experience, controller UX

## Confidence Assessment

| Area | Confidence | Notes |
|------|------------|-------|
| Stack (Godot + XR) | HIGH | Official docs, release notes, active community |
| Audio pipeline | HIGH | Built-in FFT, per-bus analysis is standard pattern |
| PCVR rendering | HIGH | Desktop GPU removes all mobile constraints |
| Serato stem access | MEDIUM | Known that Serato separates locally, but exact method to route stems to Godot needs investigation |
| Milkdrop porting | MEDIUM | Algorithms documented, but translating 2D to 3D VR is novel |
| Competitive landscape | HIGH | Thin — stem separation is genuinely novel |

## Gaps to Address

- **Serato stem audio routing:** Exact mechanism to capture individual stem outputs from Serato into Godot's audio buses. Virtual audio routing (BlackHole) is likely approach but needs validation.
- **Milkdrop warp mesh in 3D VR:** projectM renders to 2D screen. Translating to 3D VR environment is unexplored territory.
- **Virtual Desktop latency:** How much audio-visual latency does Virtual Desktop add? Effects should be forgiving of ~20ms offset.
- **Godot + SteamVR/OpenXR on desktop:** PCVR setup with Virtual Desktop — verify the VR runtime chain works smoothly.
