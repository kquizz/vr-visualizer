# Requirements: VR Music Visualizer

**Defined:** 2026-04-16
**Core Value:** Whatever music is playing on your computer comes alive around you — frequency bands drive distinct visual layers

## v1.0 Requirements (Validated)

### Audio Pipeline

- [x] **AUD-01**: App plays 4 simultaneous audio streams each on its own Godot audio bus — Phase 1
- [x] **AUD-02**: Each audio bus has FFT spectrum analysis providing per-frame frequency magnitude data — Phase 1
- [x] **AUD-03**: Audio data is normalized into a consistent struct (energy, peak frequency, magnitude bands) consumed by all visualizer modes — Phase 1

### VR Foundation

- [x] **VR-01**: Godot project runs as PCVR app with OpenXR, viewable on Quest 3 via Virtual Desktop — Phase 1
- [x] **VR-02**: Stable 90fps rendering on desktop GPU — Phase 1
- [x] **VR-03**: Comfortable VR experience — no forced locomotion, static viewpoint, photosensitivity-safe defaults — Phase 1

### Infrastructure

- [x] **INF-01**: AudioManager autoload provides normalized audio data to all modes every frame — Phase 1
- [x] **INF-02**: Shader uniform bridge passes audio data (energy, frequency bands) to GPU shaders per frame — Phase 1

## v2.0 Requirements

Requirements for FFT-First Visualizer milestone. Each maps to roadmap phases.

### Audio Pipeline

- [x] **AUD-04**: System audio captured via BlackHole virtual audio device into Godot
- [x] **AUD-05**: AudioManager refactored from 4-stem buses to single capture bus with FFT analysis
- [x] **AUD-06**: ShaderBridge updated with frequency-band uniforms (sub-bass, bass, mids, highs) from single audio source
- [x] **AUD-07**: Any desktop audio source (Spotify, Tidal, Rekordbox, YouTube) visualized without app-specific integration

### Visualization

- [x] **VIS-01**: Spectrum bars mode renders spatial 3D bars in VR with one color per frequency band
- [x] **VIS-02**: Bar heights react in real-time to FFT magnitude data from corresponding frequency bands
- [ ] **VIS-03**: Milkdrop-style warp mode renders feedback shader with audio-driven parameters (zoom, rotation, warp, decay)
- [ ] **VIS-04**: Warp mode creates flowing psychedelic visuals via SubViewport ping-pong frame feedback

### Infrastructure

- [x] **INF-03**: ModeManager system loads and switches between visualizer mode scenes
- [ ] **INF-04**: Both modes render correctly in VR (Quest 3 via Virtual Desktop) and flat-screen fallback

## v2.x Requirements

Deferred to future milestone. Tracked but not in current roadmap.

### Audio Analysis

- **ANAL-01**: Beat/onset detection via energy thresholding on sub-bass/bass bands
- **ANAL-02**: Beat intensity exposed as global shader uniform with fast decay

### Interaction

- **INT-01**: Mode switching via VR controller trigger press
- **INT-02**: Haptic feedback on mode change

### Polish

- **POL-01**: Smooth crossfade transitions between modes
- **POL-02**: Per-band visual layering (sub-bass→background, bass→midground, mids→motion, highs→sparkle)
- **POL-03**: Color palette system for swapping color schemes per mode
- **POL-04**: Audio-reactive environment (skybox pulse, ambient particles)
- **POL-05**: Additional hand-authored warp presets (3-5 variations)

## Out of Scope

Explicitly excluded. Documented to prevent scope creep.

| Feature | Reason |
|---------|--------|
| Full Milkdrop preset compatibility | Milkdrop uses HLSL + custom equation language. Porting the full engine is a separate project. Hand-write Godot shaders inspired by the techniques. |
| BPM detection / beat-sync | Unreliable from FFT alone. Onset detection (v2.x) provides 90% of the value. |
| Rekordbox stem separation | Confirmed dead end — stems are real-time only, no discrete audio output. |
| Microphone input mode | Quest mic quality is poor. BlackHole gives clean digital audio. Future "party mode" milestone. |
| Quest standalone mode | Requires solving audio capture without a desktop. Future milestone. |
| User-configurable parameter UI | VR UI is painful. Curate good defaults per mode. |
| Hand tracking interaction | Adds complexity for minimal gain. Controller trigger is sufficient. |
| Real-time Demucs stem separation | Over-engineering for v2.0. FFT bands provide 80% of the value. Upgrade path if needed. |
| Multiplayer / shared experiences | Solo headset experience |
| Meta Quest Store publishing | Passion project |

## Traceability

Which phases cover which requirements. Updated during roadmap creation.

| Requirement | Phase | Status |
|-------------|-------|--------|
| AUD-04 | Phase 2 | Complete |
| AUD-05 | Phase 2 | Complete |
| AUD-06 | Phase 2 | Complete |
| AUD-07 | Phase 2 | Complete |
| VIS-01 | Phase 3 | Complete |
| VIS-02 | Phase 3 | Complete |
| INF-03 | Phase 3 | Complete |
| VIS-03 | Phase 4 | Pending |
| VIS-04 | Phase 4 | Pending |
| INF-04 | Phase 4 | Pending |

**Coverage:**
- v2.0 requirements: 10 total
- Mapped to phases: 10
- Unmapped: 0

---
*Requirements defined: 2026-04-16*
*Last updated: 2026-04-16 after v2.0 roadmap creation*
