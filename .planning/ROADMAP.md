# Roadmap: VR Music Visualizer

## Overview

Three phases take this from empty Godot project to the "holy shit" moment: first, prove the PCVR + audio pipeline works with test stems; second, build the spectrum bars visualizer with per-stem visual mapping; third, wire up live Rekordbox stems so someone wearing the headset is inside your live DJ mix.

## Phases

**Phase Numbering:**
- Integer phases (1, 2, 3): Planned milestone work
- Decimal phases (2.1, 2.2): Urgent insertions (marked with INSERTED)

Decimal phases appear between their surrounding integers in numeric order.

- [x] **Phase 1: VR + Audio Foundation** - PCVR app with 4-bus stem audio, FFT analysis, and normalized audio data pipeline (completed 2026-04-16)
- [ ] **Phase 1.1: Validate Rekordbox Stem Extraction** (INSERTED) - De-risk spike confirming Rekordbox stems can be individually captured on macOS
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
- [x] 01-01-PLAN.md -- Godot project scaffold with Mobile renderer, OpenXR, VR scene, deep space skybox, flat-screen fallback
- [x] 01-02-PLAN.md -- Audio bus layout, AudioData struct, AudioManager autoload with FFT analysis and sync guard
- [x] 01-03-PLAN.md -- ShaderBridge global uniforms, test reactive shader, debug overlay, end-to-end verification

### Phase 1.1: Validate Rekordbox Stem Extraction (INSERTED)

**Goal:** Confirm whether Rekordbox DJ Pro's real-time stem separation can provide 4 discrete audio channels (drums, bass, vocals, other) capturable on macOS, de-risking the core Phase 3 architecture
**Requirements**: SPIKE-01, SPIKE-02, SPIKE-03, SPIKE-04
**Depends on:** Phase 1
**Success Criteria** (what must be TRUE):
  1. Rekordbox stem cache investigation is conclusively resolved with evidence
  2. BlackHole virtual audio routing captures Rekordbox output to WAV files
  3. 4 stem WAV files captured via solo-and-capture are audibly isolated
  4. FINDINGS.md contains definitive Phase 3 architecture recommendation
**Plans**: 2 plans

Plans:
- [ ] 01.1-01-PLAN.md -- Cache investigation + BlackHole setup and routing verification
- [ ] 01.1-02-PLAN.md -- Solo-and-capture all 4 stems + quality assessment + Phase 3 recommendation

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
Phases execute in numeric order: 1 -> 1.1 -> 2 -> 3

| Phase | Plans Complete | Status | Completed |
|-------|----------------|--------|-----------|
| 1. VR + Audio Foundation | 3/3 | Complete   | 2026-04-16 |
| 1.1. Validate Rekordbox Stem Extraction | 0/2 | Planning complete | - |
| 2. Stem Visualization | 0/? | Not started | - |
| 3. Live Rekordbox Integration | 0/? | Not started | - |
