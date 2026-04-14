# Phase 1: VR + Audio Foundation - Context

**Gathered:** 2026-04-13
**Status:** Ready for planning

<domain>
## Phase Boundary

PCVR app running in Godot on Quest 3 via Virtual Desktop that plays 4 stem audio streams (drums, bass, vocals, other) with per-frame FFT data available to shaders. This phase proves the audio-to-shader pipeline with test stem files — live Serato integration is Phase 3.

</domain>

<decisions>
## Implementation Decisions

### VR Scene Environment
- Deep space skybox — stars, nebulae, distant galaxies. Cosmic backdrop for visualizations.
- Skybox is static in Phase 1 — all visual reactivity comes from visualizer elements in Phase 2+
- Default viewpoint: center of the scene, surrounded by visualizations (most immersive)
- Future modes can use any viewpoint (forward-facing, orbital, etc.) — each mode is self-contained

### Development Workflow
- Primary dev machine: Mac (macOS)
- Audio routing via BlackHole/Loopback on macOS
- Flat screen preview mode for fast iteration + VR testing for verification
- Must be able to run and test without the headset on for daily development

### Test Audio
- Use pre-separated stem files (OGG/WAV) for Phase 1 development
- User wants to de-risk Serato stem routing before investing heavily in the VR pipeline (see Deferred Ideas)

### Claude's Discretion
- Debug overlay design for verifying FFT data in VR
- AudioData struct granularity (frequency bands, smoothing)
- Exact skybox asset selection
- Godot project structure and scene organization

</decisions>

<canonical_refs>
## Canonical References

**Downstream agents MUST read these before planning or implementing.**

### Project specs
- `.planning/PROJECT.md` — Vision, constraints, key decisions (PCVR via Virtual Desktop, Godot 4.6, Serato stems)
- `.planning/REQUIREMENTS.md` — Phase 1 requirements: AUD-01, AUD-02, AUD-03, VR-01, VR-02, VR-03, INF-01, INF-02
- `.planning/ROADMAP.md` — Phase goals and success criteria

No external specs, ADRs, or design docs exist yet — requirements are fully captured in the planning documents above.

</canonical_refs>

<code_context>
## Existing Code Insights

### Reusable Assets
- None — greenfield project, no Godot files exist yet

### Established Patterns
- None — patterns will be established in this phase

### Integration Points
- Godot 4.6 with OpenXR for VR
- Virtual Desktop for PCVR streaming to Quest 3
- BlackHole/Loopback for macOS audio routing (Phase 3, but architecture should accommodate)

</code_context>

<specifics>
## Specific Ideas

- "A solar system skybox would be cool" — deep space with stars and nebulae
- Modes should be able to be "very different" from each other — viewpoint, environment, everything. The mode system should not constrain visual variety.
- The "holy shit" factor is the north star: DJing on Serato while someone wears the headset and is inside the live mix

</specifics>

<deferred>
## Deferred Ideas

- **Serato spike (PRIORITY)**: User wants to de-risk Serato stem routing before Phase 1. Confirm that Serato's 4 stem outputs can route to separate audio channels via BlackHole/Loopback on macOS. This should be addressed as a roadmap insertion before Phase 1.
- Reactive skybox that pulses/shifts with music energy — decided static for Phase 1, revisit in Phase 2+
- Forward-facing "stage" viewpoint mode — future mode variant

</deferred>

---

*Phase: 01-vr-audio-foundation*
*Context gathered: 2026-04-13*
