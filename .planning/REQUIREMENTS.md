# Requirements: VR Music Visualizer

**Defined:** 2026-04-13
**Core Value:** Each stem drives its own visual layer, creating a visualization experience that's dramatically more responsive and intentional than mixed-signal FFT

## v1 Requirements

### Audio Pipeline

- [ ] **AUD-01**: App plays 4 simultaneous audio streams (drums, bass, vocals, other) each on its own Godot audio bus
- [ ] **AUD-02**: Each audio bus has FFT spectrum analysis providing per-frame frequency magnitude data
- [ ] **AUD-03**: Audio data is normalized into a consistent struct (energy, peak frequency, magnitude bands) consumed by all visualizer modes

### Serato Integration

- [ ] **SER-01**: Serato DJ Pro stem outputs route to Godot via virtual audio device (BlackHole/Loopback on macOS)
- [ ] **SER-02**: Each Serato stem (drums, bass, vocals, other) maps to its own Godot audio bus in real-time
- [ ] **SER-03**: Visualization reacts to live Serato playback with acceptable latency (<50ms audio-to-visual)

### VR Foundation

- [ ] **VR-01**: Godot project runs as PCVR app with OpenXR, viewable on Quest 3 via Virtual Desktop
- [ ] **VR-02**: Stable 90fps rendering on desktop GPU
- [ ] **VR-03**: Comfortable VR experience — no forced locomotion, static viewpoint, photosensitivity-safe defaults

### Visualizer

- [ ] **VIS-01**: Spectrum bars mode — spatial arrangement of glowing bars in a void, one color per stem, bars react to FFT magnitudes
- [ ] **VIS-02**: Stem-to-visual mapping: drums→impact pulses, bass→low-frequency spatial effects, vocals→flowing shapes, melody→pattern generation

### Infrastructure

- [ ] **INF-01**: AudioManager autoload provides normalized audio data to all modes every frame
- [ ] **INF-02**: Shader uniform bridge passes audio data (energy, frequency bands) to GPU shaders per frame

## v2 Requirements

### Mode System & Additional Visualizers

- **VIS-03**: Mode system where each visualizer is a self-contained Godot scene with ModeManager autoload
- **VIS-04**: Milkdrop-style warp tunnel — SubViewport feedback loop, immersive 3D VR environment
- **VIS-05**: Geiss plasma fields — organic fluid morphing environment
- **VIS-06**: Oscilloscope waveforms — line traces per stem
- **VIS-07**: AVS-style layered effects — scope/spectrum with color maps
- **VIS-08**: Tripex geometric shapes — platonic solids reacting to beat per stem
- **VIS-09**: Circular spectrum — radial frequency display

### UX

- **UX-01**: Controller-based mode switching menu (floating panel)
- **UX-02**: Auto-cycle between modes on timer or beat drop
- **UX-03**: Crossfade transitions between modes
- **UX-04**: Stem color/mapping configuration
- **UX-05**: Song browser in VR

### Extended Audio

- **AUD-04**: Beat detection from drum stem triggers visual events
- **AUD-05**: Local file playback mode (pre-separated OGG stems from disk) as fallback when Serato isn't running

## Out of Scope

| Feature | Reason |
|---------|--------|
| Quest 3 standalone mode | PCVR-first; standalone with pre-loaded tracks is a future add |
| Tidal API integration | Research confirmed no stem API; Serato handles Tidal playback |
| Mobile GPU optimization | Desktop GPU, no mobile constraints |
| Multiplayer/shared experiences | Solo headset experience |
| Meta Quest Store publishing | Passion project unless it turns out amazing |
| Spotify/Apple Music | Tidal DJ via Serato is the audio source |
| Microphone input | Curated high-quality audio, not ambient capture |
| Live Serato DJ set features (cue points, BPM sync) | Serato handles DJing; we just visualize the output |
| Preset editor | Users don't create visualizers, they experience them |
| Controller UI in v1 | One mode, no switching needed yet |

## Traceability

| Requirement | Phase | Status |
|-------------|-------|--------|
| AUD-01 | Phase 1 | Pending |
| AUD-02 | Phase 1 | Pending |
| AUD-03 | Phase 1 | Pending |
| SER-01 | Phase 3 | Pending |
| SER-02 | Phase 3 | Pending |
| SER-03 | Phase 3 | Pending |
| VR-01 | Phase 1 | Pending |
| VR-02 | Phase 1 | Pending |
| VR-03 | Phase 1 | Pending |
| VIS-01 | Phase 2 | Pending |
| VIS-02 | Phase 2 | Pending |
| INF-01 | Phase 1 | Pending |
| INF-02 | Phase 1 | Pending |

**Coverage:**
- v1 requirements: 13 total
- Mapped to phases: 13
- Unmapped: 0

---
*Requirements defined: 2026-04-13*
*Last updated: 2026-04-13 -- Roadmap created, all v1 requirements mapped to phases*
