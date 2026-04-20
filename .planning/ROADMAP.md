# Roadmap: VR Music Visualizer

## Milestones

- [x] **v1.0 VR + Audio Foundation** - Phase 1 (completed 2026-04-16)
- [ ] **v2.0 FFT-First Visualizer** - Phases 2-4 (in progress)

## Phases

**Phase Numbering:**
- Integer phases (1, 2, 3): Planned milestone work
- Decimal phases (2.1, 2.2): Urgent insertions (marked with INSERTED)
- Phase 1 and 1.1 belonged to v1.0 milestone (Phase 1 completed, Phase 1.1 abandoned -- Rekordbox stems confirmed dead end)

Decimal phases appear between their surrounding integers in numeric order.

<details>
<summary>v1.0 VR + Audio Foundation (Phase 1) - COMPLETED 2026-04-16</summary>

- [x] **Phase 1: VR + Audio Foundation** - PCVR app with 4-bus stem audio, FFT analysis, and normalized audio data pipeline
- ~~Phase 1.1: Validate Rekordbox Stem Extraction~~ (ABANDONED -- Rekordbox stems are real-time only, no discrete audio output)

</details>

### v2.0 FFT-First Visualizer

- [x] **Phase 2: Audio Capture Refactor** - BlackHole system audio capture with single-source FFT pipeline replacing stem buses (completed 2026-04-20)
- [ ] **Phase 3: Spectrum Bars + Mode System** - Spatial frequency bars in VR with ModeManager scene lifecycle
- [ ] **Phase 4: Milkdrop Warp Mode** - Feedback shader visualizer with audio-driven warp, completing the two-mode experience

## Phase Details

### Phase 2: Audio Capture Refactor
**Goal**: Any desktop audio playing on the computer is captured into Godot and analyzed into frequency bands available to shaders
**Depends on**: Phase 1 (VR foundation, existing AudioManager/ShaderBridge)
**Requirements**: AUD-04, AUD-05, AUD-06, AUD-07
**Success Criteria** (what must be TRUE):
  1. Playing music in Spotify (or any audio app) produces non-zero FFT data in Godot, visible in the debug overlay
  2. AudioManager reads from a single BlackHole capture bus (not 4 stem buses) and exposes frequency-band data (sub-bass, bass, mids, highs)
  3. ShaderBridge pushes frequency-band uniforms that a test shader visibly reacts to from live system audio
  4. Switching between audio sources (Spotify, YouTube, Tidal) requires zero changes in Godot -- it just works
**Plans**: 2 plans

Plans:
- [ ] 02-01-PLAN.md — Bus layout, AudioData, AudioManager rewrite for BlackHole capture
- [ ] 02-02-PLAN.md — ShaderBridge, shader globals, test shader, debug overlay, legacy cleanup + verification

### Phase 3: Spectrum Bars + Mode System
**Goal**: A spatial spectrum bars visualizer runs in VR, managed by a mode system that can load and switch between visualizer scenes
**Depends on**: Phase 2 (clean FFT data from live audio)
**Requirements**: VIS-01, VIS-02, INF-03
**Success Criteria** (what must be TRUE):
  1. 3D spectrum bars are visible in VR space, arranged spatially around the viewer, with distinct colors per frequency band
  2. Bar heights move in real-time tracking the music -- bass hits make bass bars jump, high-hats make high-frequency bars spike
  3. ModeManager can load the spectrum bars scene and will be able to switch to a second mode once it exists
**Plans**: 2 plans

Plans:
- [ ] 03-01-PLAN.md — ModeManager autoload + spectrum bars scene (ring layout, colors, FFT reactivity)
- [ ] 03-02-PLAN.md — Wire into main.gd, glow tuning, remove test mesh, visual verification checkpoint

### Phase 4: Milkdrop Warp Mode
**Goal**: A Milkdrop-style warp feedback visualizer surrounds the viewer in VR, completing the two-mode experience with stutter-free switching
**Depends on**: Phase 3 (ModeManager, validated ShaderBridge pipeline)
**Requirements**: VIS-03, VIS-04, INF-04
**Success Criteria** (what must be TRUE):
  1. Warp mode renders flowing psychedelic visuals that respond to music -- bass drives zoom/warp, mids drive rotation, highs drive color intensity
  2. The feedback loop runs stable for 5+ minutes without visual artifacts (no grid patterns, no precision drift)
  3. Switching between spectrum bars and warp mode via controller works without frame drops or shader compilation stutter
  4. Both modes render correctly in VR (Quest 3 via Virtual Desktop) and in flat-screen fallback
**Plans**: 2 plans

Plans:
- [x] 04-01-PLAN.md — SubViewport ping-pong feedback loop, warp shaders, inverted sphere dome, audio mapping
- [ ] 04-02-PLAN.md — ModeManager warp registration, fade-to-black transition, keyboard toggle, visual verification

### Phase 5: Milkdrop Rendering Engine with Preset Loader
**Goal**: projectM (open-source MilkDrop C++ reimplementation) integrated as a Godot GDExtension replaces Phase 4's basic warp mode, enabling full .milk preset file compatibility with real MilkDrop rendering (NSEEL, grid warp, waveforms, blur, compositing)
**Depends on**: Phase 4 (basic warp mode, ModeManager, dome infrastructure)
**Requirements**: VIS-03, VIS-04, INF-04
**Success Criteria** (what must be TRUE):
  1. projectM GDExtension compiles and loads in Godot without errors
  2. .milk preset files load and produce visible, animated MilkDrop-style visuals on the dome
  3. Desktop audio drives preset parameters via PCM feed to projectM
  4. Mode switching via TAB between spectrum bars and milkdrop works with fade transition
  5. Renders correctly in flat-screen fallback (macOS) and VR (Quest 3 via Virtual Desktop)
**Plans**: 3 plans

Plans:
- [ ] 05-01-PLAN.md — GDExtension project scaffold + projectM C++ wrapper (init, preset, audio, render, texture)
- [ ] 05-02-PLAN.md — PCM audio capture in AudioManager + milkdrop mode scene with dome display
- [ ] 05-03-PLAN.md — ModeManager integration, test presets, Phase 4 removal, visual verification

## Progress

**Execution Order:**
Phases execute in numeric order: 2 -> 3 -> 4 -> 5

| Phase | Plans Complete | Status | Completed |
|-------|----------------|--------|-----------|
| 2. Audio Capture Refactor | 2/2 | Complete   | 2026-04-20 |
| 3. Spectrum Bars + Mode System | 2/2 | Complete | 2026-04-20 |
| 4. Milkdrop Warp Mode | 1/2 | In progress | - |
| 5. Milkdrop Rendering Engine | 0/3 | Planned | - |
