# VR Music Visualizer

## What This Is

A PCVR music visualizer for Quest 3 (via Virtual Desktop) that renders classic Winamp-inspired visualizer modes (Milkdrop, AVS, Geiss, spectrum bars, etc.) powered by a desktop GPU. Uses Serato DJ stem separation to drive 4 independent reactive visual channels (drums, bass, vocals, other) — each mapped to distinct visual elements. Built in Godot. Designed as a passion project and party trick.

## Core Value

When you put on the headset, the music comes alive around you — each stem (drums, bass, vocals, melody) drives its own visual layer, creating a visualization experience that's dramatically more responsive and intentional than anything based on mixed-signal FFT. DJing on Serato while someone wears the headset and is *inside* your live mix is the ultimate party trick.

## Requirements

### Validated

(None yet — ship to validate)

### Active

- [ ] PCVR app running in Godot, viewed on Quest 3 via Virtual Desktop
- [ ] Audio playback with FFT analysis per stem channel
- [ ] Serato stem separation (drums, bass, vocals, other) as 4 reactive channels
- [ ] Discrete visualizer mode system — each mode is a self-contained scene
- [ ] Mode 1: Spectrum bars — spatial bars in a void, one color per stem
- [ ] Mode 2+: Immersive environments (Milkdrop warp tunnel, Geiss plasma, etc.)
- [ ] Classic visualizer styles: Milkdrop, AVS, Geiss, Tripex, oscilloscope, circular spectrum
- [ ] Mode switching via controller menu, gesture cycling, and auto-cycle with crossfade
- [ ] Stem-to-visual mapping: drums→impacts/pulses, bass→spatial warping, vocals→particles/ribbons, melody→pattern generation

### Out of Scope

- Publishing to Meta Quest Store — unless it turns out amazing
- Spotify/Apple Music integration — Tidal DJ via Serato is the audio source
- Microphone input mode — curated high-quality audio is the goal
- Multiplayer / shared experiences — solo headset experience
- Quest 3 standalone mode — may add later for simpler scenarios with pre-loaded tracks
- Mobile GPU optimization — PCVR means desktop GPU, no mobile constraints

## Context

- Kevin has Godot experience (built small projects) but is new to VR specifically
- Kevin has Tidal DJ subscription which includes stem separation via Serato
- Kevin uses Serato DJ Pro for DJing — Serato 3.0+ has built-in stem separation
- **PCVR via Virtual Desktop** — Godot runs on Mac/PC, Quest 3 is a wireless VR display
- Desktop GPU removes mobile shader constraints — full Milkdrop-quality effects are achievable
- Serato runs alongside Godot on the same machine — real-time stem access is architecturally possible
- Research confirmed: Tidal API does NOT expose stems. Serato does the separation locally.
- Classic Winamp visualizers (especially Milkdrop) are well-documented with open-source implementations (projectM, Butterchurn)
- The "holy shit" factor: you're DJing on Serato, someone puts on the headset, and they're inside your live mix

## Constraints

- **Platform**: PCVR via Virtual Desktop — Quest 3 as wireless display, desktop GPU for rendering
- **Engine**: Godot 4.6 — Kevin's existing experience, good VR support via XR Tools
- **Audio source**: Serato DJ Pro stems — need to research how to access Serato's stem output programmatically
- **Performance**: Must maintain 90fps for VR comfort on desktop hardware
- **Wireless**: Virtual Desktop adds some latency — visual effects should be forgiving of ~20ms audio-visual offset

## Key Decisions

| Decision | Rationale | Outcome |
|----------|-----------|---------|
| PCVR over Quest standalone | Desktop GPU enables full shader quality, Serato runs alongside Godot, wireless via Virtual Desktop still feels untethered. Party trick still works — person wearing headset doesn't know there's a computer. | — Pending |
| Godot over Unity/Unreal | Kevin has Godot experience, lighter weight, good enough VR support | — Pending |
| Serato stems over Tidal API | Research confirmed Tidal API has no stem endpoint. Serato 3.0+ separates stems locally. Kevin already uses Serato. | — Pending |
| Stems over mixed FFT | 4 pre-separated channels give dramatically better visualization than band-splitting mixed audio | — Pending |
| Discrete modes over single environment | Variety of visual experiences, classic Winamp feel, easier to build incrementally | — Pending |
| Start with spectrum bars | Simplest visualizer proves the entire pipeline (VR, audio, FFT, stems, mode switching) | — Pending |
| Virtual Desktop over Quest Link/Air Link | Kevin already uses Virtual Desktop, says it's much better than Air Link | — Pending |

---
*Last updated: 2026-04-13 after PCVR pivot*
