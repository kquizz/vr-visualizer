# VR Music Visualizer

## What This Is

A PCVR music visualizer for Quest 3 (via Virtual Desktop) that renders classic Winamp-inspired visualizer modes powered by a desktop GPU. Uses FFT frequency-band analysis on any desktop audio source (Spotify, Tidal, Rekordbox, anything) captured via BlackHole virtual audio device. Built in Godot. Designed as a passion project and party trick.

## Core Value

When you put on the headset, whatever music is playing on your computer comes alive around you — frequency bands (sub-bass, bass, mids, highs) each drive distinct visual layers, creating visualization that feels intentional and responsive. Play music however you want, put on the headset, and you're inside it.

## Current Milestone: v2.0 FFT-First Visualizer

**Goal:** Drop stem separation, capture any desktop audio via BlackHole, build 1-2 real visualizer modes with FFT frequency bands on the existing PCVR foundation.

**Target features:**
- System audio capture via BlackHole virtual audio device
- FFT frequency-band analysis (sub-bass, bass, mids, highs) replacing per-stem channels
- Spectrum bars visualizer (spatial bars in VR, one color per frequency band)
- One immersive mode (Milkdrop-style warp or similar)
- Basic mode switching via controller

## Requirements

### Validated

- ✓ PCVR app running in Godot, viewed on Quest 3 via Virtual Desktop — Phase 1
- ✓ Audio playback with FFT analysis on audio buses — Phase 1
- ✓ AudioManager autoload with normalized AudioData struct — Phase 1
- ✓ ShaderBridge global uniforms for audio-reactive shaders — Phase 1
- ✓ Debug overlay for FFT data verification — Phase 1
- ✓ 90fps stable rendering on desktop GPU — Phase 1

### Active

- [ ] System audio capture via BlackHole virtual audio device into Godot
- [ ] FFT frequency-band analysis on live system audio (sub-bass, bass, mids, highs)
- [ ] Spectrum bars visualizer — spatial bars in VR, one color per frequency band
- [ ] One immersive visualizer mode (Milkdrop-style warp tunnel or similar)
- [ ] Mode switching via VR controller menu
- [ ] Works with any desktop audio source (Spotify, Tidal, Rekordbox, YouTube, etc.)

### Out of Scope

- Rekordbox stem separation — confirmed dead end (stems are real-time only, no discrete audio output)
- Quest 3 standalone mode — PCVR is the target; standalone is a future milestone if desired
- Multiple visualizer modes beyond 2 — prove the pipeline first, stack modes in next milestone
- Microphone input mode — stretch goal for future "party mode" milestone
- Mobile GPU optimization — PCVR means desktop GPU, no mobile constraints
- Publishing to Meta Quest Store — passion project
- Multiplayer / shared experiences — solo headset experience

## Context

- Kevin has Godot experience and built Phase 1 (VR + audio foundation) successfully
- Kevin uses Rekordbox for DJing — but stem separation proved to be a dead end (Phase 1.1 spike confirmed)
- **PCVR via Virtual Desktop** — Godot runs on Mac/PC, Quest 3 is a wireless VR display
- Desktop GPU removes mobile shader constraints — full Milkdrop-quality effects are achievable
- Phase 1 foundation carries forward: VR scene, AudioManager with FFT, ShaderBridge, debug overlay
- BlackHole virtual audio device on macOS routes system audio to Godot — well-documented approach
- Classic Winamp visualizers (especially Milkdrop) are well-documented with open-source implementations (projectM, Butterchurn)
- The "holy shit" factor: put on headset, play music on your computer, you're inside the visualization

## Constraints

- **Platform**: PCVR via Virtual Desktop — Quest 3 as wireless display, desktop GPU for rendering
- **Engine**: Godot 4.6 — existing Phase 1 codebase
- **Audio source**: Any desktop audio via BlackHole virtual audio device on macOS
- **Performance**: Must maintain 90fps for VR comfort on desktop hardware
- **Wireless**: Virtual Desktop adds some latency — visual effects should be forgiving of ~20ms audio-visual offset

## Key Decisions

| Decision | Rationale | Outcome |
|----------|-----------|---------|
| PCVR over Quest standalone | Desktop GPU enables full shader quality, easy audio capture via BlackHole, reuses Phase 1 foundation | ✓ Good |
| Godot over Unity/Unreal | Kevin has Godot experience, lighter weight, good enough VR support | ✓ Good |
| FFT bands over Rekordbox stems | Rekordbox only outputs single stereo master — can't get separate stem audio. FFT works with any audio source. | ✓ Good |
| BlackHole for audio capture | Well-documented macOS virtual audio device, routes any system audio to Godot | — Pending |
| 1-2 modes for v2.0 | Prove the FFT→visual pipeline before investing in mode variety | — Pending |
| Discrete modes over single environment | Variety of visual experiences, classic Winamp feel, easier to build incrementally | — Pending |
| Virtual Desktop over Quest Link/Air Link | Kevin already uses Virtual Desktop, says it's much better than Air Link | ✓ Good |

---
*Last updated: 2026-04-16 after v2.0 milestone start — FFT-first pivot*
