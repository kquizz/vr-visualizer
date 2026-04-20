---
phase: 02
slug: audio-capture-refactor
status: draft
nyquist_compliant: false
wave_0_complete: false
created: 2026-04-19
---

# Phase 02 — Validation Strategy

> Per-phase validation contract for feedback sampling during execution.

---

## Test Infrastructure

| Property | Value |
|----------|-------|
| **Framework** | Godot editor + manual runtime verification (no unit test framework) |
| **Config file** | none — Godot projects use editor-based testing |
| **Quick run command** | `godot --path . --headless --quit` (validates parse/load) |
| **Full suite command** | `godot --path .` (run scene, verify debug overlay output) |
| **Estimated runtime** | ~5 seconds (headless parse), ~30 seconds (visual verification) |

---

## Sampling Rate

- **After every task commit:** Run `godot --path . --headless --quit` (parse validation)
- **After every plan wave:** Run full scene, verify debug overlay shows expected state
- **Before `/gsd:verify-work`:** Full scene run with BlackHole audio playing must show non-zero FFT
- **Max feedback latency:** 30 seconds

---

## Per-Task Verification Map

| Task ID | Plan | Wave | Requirement | Test Type | Automated Command | File Exists | Status |
|---------|------|------|-------------|-----------|-------------------|-------------|--------|
| 02-01-XX | 01 | 1 | AUD-04 | manual | Run scene with BlackHole audio | N/A | ⬜ pending |
| 02-01-XX | 01 | 1 | AUD-05 | manual | Check debug overlay for single-bus FFT | N/A | ⬜ pending |
| 02-02-XX | 02 | 2 | AUD-06 | manual | Verify shader uniforms react to audio | N/A | ⬜ pending |
| 02-02-XX | 02 | 2 | AUD-07 | manual | Switch audio sources, verify no Godot changes needed | N/A | ⬜ pending |

*Status: ⬜ pending · ✅ green · ❌ red · ⚠️ flaky*

---

## Wave 0 Requirements

Existing infrastructure covers all phase requirements. No test framework install needed — Godot's built-in AudioServer + SpectrumAnalyzer provide runtime verification through the debug overlay.

---

## Manual-Only Verifications

| Behavior | Requirement | Why Manual | Test Instructions |
|----------|-------------|------------|-------------------|
| BlackHole audio captured into Godot | AUD-04 | Requires macOS audio routing + running audio source | 1. Ensure BlackHole installed, 2. Set macOS multi-output, 3. Play Spotify, 4. Run scene, 5. Check debug overlay for non-zero energy |
| Single capture bus FFT analysis | AUD-05 | Runtime audio pipeline behavior | Run scene, verify debug overlay shows 1 source with 4 channel groups + 7 raw bands |
| Shader uniform reactivity | AUD-06 | Visual verification required | Run scene with audio, observe test_reactive mesh pulsing/coloring with music |
| Source-agnostic capture | AUD-07 | Requires switching actual audio apps | Play from Spotify, then YouTube, then Tidal — verify all produce FFT data without restarting Godot |
| Idle animation when silent | User decision | Visual behavior | Stop all audio, verify scene shows subtle ambient animation (not frozen) |

---

## Validation Sign-Off

- [ ] All tasks have manual verification instructions or headless parse check
- [ ] Sampling continuity: parse check after every commit, visual after every wave
- [ ] No watch-mode flags
- [ ] Feedback latency < 30s
- [ ] `nyquist_compliant: true` set in frontmatter

**Approval:** pending
