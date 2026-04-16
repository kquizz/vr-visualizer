# Phase 2: Audio Capture Refactor - Context

**Gathered:** 2026-04-16
**Status:** Ready for planning

<domain>
## Phase Boundary

Replace the 4-stem audio pipeline with a single BlackHole capture bus. Refactor AudioManager from 4 stem buses/players/analyzers to 1 capture bus reading system audio via AudioStreamMicrophone. Update ShaderBridge from 16 per-stem uniforms to frequency-band uniforms. Validate that any desktop audio source produces FFT data visible in the debug overlay.

</domain>

<decisions>
## Implementation Decisions

### Dev Fallback Mode
- BlackHole is the only audio input path — no local file playback fallback
- Auto-detect BlackHole on startup: check if "BlackHole 2ch" is in the audio device list, warn with setup instructions if missing
- `stem_loader.gd` kept but disabled (renamed to `_stem_loader_legacy.gd` or similar) — not wired into the scene, preserved for reference
- Old test stem WAV files can stay in `audio/stems/` but are not loaded

### Band Grouping
- Collapse 7 FFT bands into 4 visual channel groups:
  - **LOW** = sub-bass + bass (20-250Hz) — deep pulses, spatial warping
  - **MID_LOW** = low-mid + mid (250-2kHz) — body, melody, main motion
  - **MID_HIGH** = upper-mid + presence (2-6kHz) — brightness, texture, shimmer
  - **HIGH** = brilliance (6-11kHz) — sparkle, detail, transients
- Expose BOTH levels to shaders: 4 grouped channels AND 7 raw bands
- This is the data contract for Phases 3-4: modes use grouped channels for most visual mapping, raw bands for finer detail (e.g., spectrum bars showing all 7)

### No-Signal Behavior
- When no audio is playing: scene renders with subtle ambient idle animation (not frozen, not fake reactivity)
- Debug overlay shows signal status: "Listening on BlackHole 2ch" or "No signal detected" alongside FFT bars
- Zero FFT data = subtle idle state, making the contrast obvious when music starts

### Claude's Discretion
- Exact shader uniform naming convention for the new band groups
- AudioData struct internal changes (single instance vs. array)
- Bus layout architecture (single "Capture" bus with AudioStreamMicrophone)
- How to mute the capture bus to prevent feedback while keeping SpectrumAnalyzer active
- Debug overlay layout changes for single-source display
- Exact idle animation behavior (drift speed, what moves)

</decisions>

<canonical_refs>
## Canonical References

**Downstream agents MUST read these before planning or implementing.**

### Audio pipeline (existing code to refactor)
- `scripts/autoloads/audio_manager.gd` — Current 4-stem AudioManager with FFT analysis, exponential smoothing, sync guard
- `scripts/autoloads/shader_bridge.gd` — Current 16 per-stem shader uniforms (drums_*, bass_*, vocals_*, other_*)
- `scripts/audio_data.gd` — AudioData class: energy, peak_frequency, 7 bands
- `default_bus_layout.tres` — Current 4-bus layout (Drums, Bass, Vocals, Other) with SpectrumAnalyzers
- `project.godot` [shader_globals] section — 16 global shader uniforms to replace

### Debug and loading (affected files)
- `scripts/debug_overlay.gd` — Currently displays 4 stems, needs rework for single-source + signal status
- `scripts/stem_loader.gd` — To be disabled/renamed, not deleted

### Research findings
- `.planning/research/STACK.md` — BlackHole + AudioStreamMicrophone approach, no plugins needed
- `.planning/research/ARCHITECTURE.md` — 4-bus to 1-bus refactor plan, data flow changes
- `.planning/research/PITFALLS.md` — macOS audio input bugs, Multi-Output Device requirement, sample rate matching

</canonical_refs>

<code_context>
## Existing Code Insights

### Reusable Assets
- `AudioData` class: energy/peak_frequency/bands struct carries forward with minimal changes
- FFT analysis logic in `_update_stem_data()`: same `get_magnitude_for_frequency_range()` API, same smoothing constants, just from one analyzer instead of four
- `BAND_EDGES` constant: 7 musically meaningful boundaries are already well-tuned

### Established Patterns
- Autoload pattern: AudioManager and ShaderBridge are autoloads in project.godot — same pattern continues
- Deferred initialization: AudioManager uses `call_deferred("_initialize")` to avoid null analyzer instances — same caution needed for AudioStreamMicrophone
- Global shader uniforms declared in project.godot [shader_globals], set at runtime by ShaderBridge — same approach for new uniforms

### Integration Points
- `ShaderBridge._process()` reads from `AudioManager.stem_data` — needs to read from new single-source data
- `debug_overlay.gd` reads from `AudioManager.stem_data` — needs refactor for single-source + signal status
- `main.gd` — may need to trigger audio capture start (AudioStreamMicrophone may need explicit play())
- `project.godot` audio settings — needs `audio/driver/enable_input = true` for microphone access
- Test reactive shader (`shaders/test_reactive.gdshader`) — needs to reference new uniform names

</code_context>

<specifics>
## Specific Ideas

No specific visual references for this phase — it's infrastructure/plumbing. The key outcome is: play music on desktop, see FFT data moving in the debug overlay.

</specifics>

<deferred>
## Deferred Ideas

None — discussion stayed within phase scope.

</deferred>

---

*Phase: 02-audio-capture-refactor*
*Context gathered: 2026-04-16*
