# Roadmap: VR Music Visualizer

## Overview

Three phases take this from empty Godot project to the "holy shit" moment: first, prove the PCVR + audio pipeline works with test stems; second, build the spectrum bars visualizer with per-stem visual mapping; third, wire up live Rekordbox stems so someone wearing the headset is inside your live DJ mix.

## Phases

**Phase Numbering:**
- Integer phases (1, 2, 3): Planned milestone work
- Decimal phases (2.1, 2.2): Urgent insertions (marked with INSERTED)

Decimal phases appear between their surrounding integers in numeric order.

- [ ] **Phase 1: VR + Audio Foundation** - PCVR app with 4-bus stem audio, FFT analysis, and normalized audio data pipeline
- [ ] **Phase 2: Stem Visualization** - Spectrum bars mode with per-stem visual mapping proving the full audio-to-shader pipeline
- [ ] **Phase 3: Live Rekordbox Integration** - Real-time Rekordbox stem routing into Godot for live DJ visualization

## Phase Details

### Phase 1: VR + Audio Foundation
**Goal**: A VR scene running on Quest 3 via Virtual Desktop that plays 4 stem audio streams with per-frame FFT data available to shaders
**Depends on**: Nothing (first phase)
**Requirements**: AUD-01, AUD-02, AUD-03, VR-01, VR-02, VR-03, INF-01, INF-02
**Success Criteria** (what must be TRUE):
  1. Godot project launches as PCVR app and displays a VR scene on Quest 3 via Virtual Desktop
  2. Four audio streams (test OGG files for drums, bass, vocals, other) play simultaneously on separate Godot audio buses
  3. FFT spectrum data updates every frame for each audio bus, visible via debug overlay in VR
  4. AudioManager autoload exposes a normalized AudioData struct (energy, peak frequency, magnitude bands) consumed by a test shader that visibly reacts to audio
  5. Scene renders at stable 90fps on desktop GPU with no VR discomfort (no forced movement, static viewpoint)
**Plans**: 3 plans

Plans:
- [ ] 01-01-PLAN.md -- Godot project scaffold with Mobile renderer, OpenXR, VR scene, deep space skybox, flat-screen fallback
- [ ] 01-02-PLAN.md -- Audio bus layout, AudioData struct, AudioManager autoload with FFT analysis and sync guard
- [ ] 01-03-PLAN.md -- ShaderBridge global uniforms, test reactive shader, debug overlay, end-to-end verification

### Phase 1.1: Validate Rekordbox Stem Extraction (INSERTED)

**Goal:** [Urgent work - to be planned]
**Requirements**: TBD
**Depends on:** Phase 1
**Plans:** 2/3 plans executed

Plans:
- [ ] TBD (run /gsd:plan-phase 01.1 to break down)

### Phase 2: Stem Visualization
**Goal**: A spectrum bars visualizer where each stem drives distinct visual elements, proving the creative vision of stem-separated VR visualization
**Depends on**: Phase 1
**Requirements**: VIS-01, VIS-02
**Success Criteria** (what must be TRUE):
  1. Spectrum bars render spatially in the VR void with one distinct color per stem (4 stem groups visible)
  2. Bar heights react in real-time to FFT magnitude data from their corresponding stem
  3. Stem-to-visual mapping is observable: drums produce impact/pulse effects, bass drives spatial warping, vocals generate flowing shapes, melody drives pattern generation
**Plans**: TBD

Plans:
- [ ] 02-01: TBD

### Phase 3: Live Rekordbox Integration
**Goal**: Rekordbox's live stem separation feeds directly into the visualizer -- the party trick works
**Depends on**: Phase 2
**Requirements**: SER-01, SER-02, SER-03
**Success Criteria** (what must be TRUE):
  1. Rekordbox stem outputs route to Godot via virtual audio device (BlackHole or Loopback on macOS)
  2. Each Rekordbox stem (drums, bass, vocals, other) maps to its corresponding Godot audio bus in real-time
  3. Visualization reacts to live Rekordbox playback with latency under 50ms (audio change to visual response)
  4. The end-to-end experience works: DJ plays on Rekordbox, person in headset sees stem-reactive visualization of the live mix
**Plans**: TBD

Plans:
- [ ] 03-01: TBD

## Progress

**Execution Order:**
Phases execute in numeric order: 1 -> 2 -> 3

| Phase | Plans Complete | Status | Completed |
|-------|----------------|--------|-----------|
| 1. VR + Audio Foundation | 2/3 | In Progress|  |
| 2. Stem Visualization | 0/? | Not started | - |
| 3. Live Rekordbox Integration | 0/? | Not started | - |
