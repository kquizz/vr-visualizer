---
phase: 3
slug: spectrum-bars-mode-system
status: draft
nyquist_compliant: false
wave_0_complete: false
created: 2026-04-19
---

# Phase 3 — Validation Strategy

> Per-phase validation contract for feedback sampling during execution.

---

## Test Infrastructure

| Property | Value |
|----------|-------|
| **Framework** | Manual visual + console smoke tests (Godot 4.6) |
| **Config file** | N/A — visual output, no unit test framework |
| **Quick run command** | `godot --path .` |
| **Full suite command** | `godot --path .` + VR headset via Virtual Desktop |
| **Estimated runtime** | ~5 seconds (launch + visual check) |

---

## Sampling Rate

- **After every task commit:** Run `godot --path .` and visually verify bars render + audio reactivity
- **After every plan wave:** Full VR headset test with music playing
- **Before `/gsd:verify-work`:** Full suite must be green (flat-screen + VR)
- **Max feedback latency:** 10 seconds

---

## Per-Task Verification Map

| Task ID | Plan | Wave | Requirement | Test Type | Automated Command | File Exists | Status |
|---------|------|------|-------------|-----------|-------------------|-------------|--------|
| 03-01-01 | 01 | 1 | INF-03 | smoke | Console print: "ModeManager: switched to spectrum_bars" | ❌ W0 | ⬜ pending |
| 03-01-02 | 01 | 1 | VIS-01 | manual-visual | `godot --path .` — verify 27 bars in 360° ring with 7 colors | N/A | ⬜ pending |
| 03-01-03 | 01 | 1 | VIS-02 | manual-visual | `godot --path .` + play music — bass bars spike on bass hits | N/A | ⬜ pending |

*Status: ⬜ pending · ✅ green · ❌ red · ⚠️ flaky*

---

## Wave 0 Requirements

- [ ] `scenes/modes/` directory — needs creation
- [ ] ModeManager autoload registration in `project.godot`
- [ ] Glow environment tuning in `vr_scene.tscn` for emission-heavy scene

*Infrastructure gaps identified from research.*

---

## Manual-Only Verifications

| Behavior | Requirement | Why Manual | Test Instructions |
|----------|-------------|------------|-------------------|
| 3D bars visible in VR with per-band colors | VIS-01 | Visual output — cannot automate "bars look correct in VR" | Launch `godot --path .`, verify 27 cylindrical bars in ring, 7 distinct colors warm-to-cool |
| Bar heights react to FFT in real-time | VIS-02 | Audio-visual sync — requires human judgment | Play music, verify bass bars (front) spike on bass hits, high bars (rear) spike on hi-hats |
| Glow/bloom visible around bars | VIS-01 | Visual quality — emission glow is subjective | Verify bars have visible glow halo, intensifies with energy, primary light source in scene |

---

## Validation Sign-Off

- [ ] All tasks have `<automated>` verify or Wave 0 dependencies
- [ ] Sampling continuity: no 3 consecutive tasks without automated verify
- [ ] Wave 0 covers all MISSING references
- [ ] No watch-mode flags
- [ ] Feedback latency < 10s
- [ ] `nyquist_compliant: true` set in frontmatter

**Approval:** pending
