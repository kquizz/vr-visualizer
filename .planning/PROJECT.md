# VR Music Visualizer

## What This Is

A standalone Quest 3 VR app that visualizes music using classic Winamp-inspired visualizer modes (Milkdrop, AVS, Geiss, spectrum bars, etc.). Uses Tidal DJ stems to drive 4 independent reactive visual channels (drums, bass, vocals, other) — each mapped to distinct visual elements. Built in Godot. Designed as a passion project and party trick.

## Core Value

When you put on the headset, the music comes alive around you — each stem (drums, bass, vocals, melody) drives its own visual layer, creating a visualization experience that's dramatically more responsive and intentional than anything based on mixed-signal FFT.

## Requirements

### Validated

(None yet — ship to validate)

### Active

- [ ] Quest 3 standalone VR app running in Godot
- [ ] Audio playback with FFT analysis per stem channel
- [ ] Tidal API integration for browsing/selecting songs
- [ ] Tidal DJ stem separation (drums, bass, vocals, other) as 4 reactive channels
- [ ] Discrete visualizer mode system — each mode is a self-contained scene
- [ ] Mode 1: Spectrum bars — spatial bars in a void, one color per stem
- [ ] Mode 2+: Immersive environments (Milkdrop warp tunnel, Geiss plasma, etc.)
- [ ] Classic visualizer styles: Milkdrop, AVS, Geiss, Tripex, oscilloscope, circular spectrum
- [ ] Mode switching via controller menu, gesture cycling, and auto-cycle with crossfade
- [ ] Stem-to-visual mapping: drums→impacts/pulses, bass→spatial warping, vocals→particles/ribbons, melody→pattern generation

### Out of Scope

- Publishing to Meta Quest Store — unless it turns out amazing
- Spotify/Apple Music integration — Tidal DJ is the audio source
- Microphone input mode — curated high-quality audio is the goal
- Live Serato DJ input — Phase 100 dream, not v1
- Multiplayer / shared experiences — solo headset experience
- PC VR (SteamVR) — Quest 3 standalone only for now

## Context

- Kevin has Godot experience (built small projects) but is new to VR specifically
- Kevin has Tidal DJ subscription which includes stem separation
- Kevin uses Serato for DJing — future integration path exists
- Quest 3 has Adreno 740 mobile GPU — shader complexity needs to be smart, but classic Winamp visualizers are mostly geometry + color math, not texture-heavy
- Classic Winamp visualizers (especially Milkdrop) are well-documented and have open-source implementations to reference
- The "holy shit" factor is handing someone the headset at a party and they're *inside* the music

## Constraints

- **Platform**: Quest 3 standalone — mobile GPU limits shader complexity
- **Engine**: Godot — Kevin's existing experience, good VR support via XR Tools
- **Audio source**: Tidal DJ API — need to research exact API capabilities for stem access
- **Performance**: Must maintain 72fps+ for VR comfort on mobile hardware

## Key Decisions

| Decision | Rationale | Outcome |
|----------|-----------|---------|
| Godot over Unity/Unreal | Kevin has Godot experience, lighter weight for mobile VR | — Pending |
| Tidal stems over mixed FFT | 4 pre-separated channels give dramatically better visualization than trying to band-split mixed audio | — Pending |
| Discrete modes over single environment | Variety of visual experiences, classic Winamp feel, easier to build incrementally | — Pending |
| Quest 3 standalone over PCVR | Lowest friction — no PC tether, hand it to anyone at a party | — Pending |
| Start with spectrum bars | Simplest visualizer proves the entire pipeline (VR, audio, FFT, stems, mode switching) | — Pending |

---
*Last updated: 2026-04-13 after initialization*
