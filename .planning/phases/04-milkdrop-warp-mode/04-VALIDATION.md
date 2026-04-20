---
phase: 4
slug: milkdrop-warp-mode
status: draft
nyquist_compliant: false
wave_0_complete: false
created: 2026-04-19
---

# Phase 4 — Validation Strategy

> Per-phase validation contract for feedback sampling during execution.

---

## Test Infrastructure

| Property | Value |
|----------|-------|
| **Framework** | Manual visual verification + Godot editor |
| **Config file** | None — visual/VR testing |
| **Quick run command** | `godot --path .` (run main scene, press key to switch modes) |
| **Full suite command** | `godot --path .` + 5-minute stability test in VR |
| **Estimated runtime** | ~10 seconds (launch) + manual observation |

---

## Sampling Rate

- **After every task commit:** Run `godot --path .`, verify no errors, observe basic visual output
- **After every plan wave:** Full 5-minute playback test with music
- **Before `/gsd:verify-work`:** VR test via Virtual Desktop + flat-screen test on macOS
- **Max feedback latency:** ~10 seconds (scene launch time)

---

## Per-Task Verification Map

| Task ID | Plan | Wave | Requirement | Test Type | Automated Command | File Exists | Status |
|---------|------|------|-------------|-----------|-------------------|-------------|--------|
| 04-01-01 | 01 | 1 | VIS-04 | manual-visual | `godot --path .` — verify SubViewport ping-pong renders feedback texture | N/A | ⬜ pending |
| 04-01-02 | 01 | 1 | VIS-03 | manual-visual | `godot --path .` — verify UV warp distortion visible in feedback loop | N/A | ⬜ pending |
| 04-01-03 | 01 | 1 | VIS-03 | manual-visual | `godot --path .` — verify audio-driven parameters (bass→zoom, mids→rotation, highs→color) | N/A | ⬜ pending |
| 04-02-01 | 02 | 2 | INF-04 | manual-visual | `godot --path .` — verify inverted sphere dome renders warp texture correctly | N/A | ⬜ pending |
| 04-02-02 | 02 | 2 | INF-04 | manual-visual | `godot --path .` — verify mode switch via keyboard without stutter | N/A | ⬜ pending |
| 04-02-03 | 02 | 2 | VIS-04 | manual-visual | 5-min stability test — verify no convergence, no precision drift | N/A | ⬜ pending |

*Status: ⬜ pending · ✅ green · ❌ red · ⚠️ flaky*

---

## Wave 0 Requirements

- [ ] Keyboard toggle for mode switching in `main.gd` (if not already present from Phase 3)
- [ ] NoiseTexture2D resource for seed injection

*Existing infrastructure covers audio pipeline and ShaderBridge — no new framework install needed.*

---

## Manual-Only Verifications

| Behavior | Requirement | Why Manual | Test Instructions |
|----------|-------------|------------|-------------------|
| Warp visuals respond to bass/mids/highs | VIS-03 | Visual/perceptual outcome — no automated metric | Play music, observe: bass → zoom pulses, mids → rotation, highs → color shift |
| Feedback loop sustains 5+ minutes | VIS-04 | Time-based stability test requires observation | Run scene with music for 5 min, verify visuals still evolving (no dead image, no static pattern) |
| Both modes render in VR + flat-screen | INF-04 | Requires VR hardware + macOS fallback test | Test flat-screen on macOS, test VR via Virtual Desktop on Windows |
| Mode switch without stutter | INF-04 | Frame timing perception | Switch modes 5x, verify no visible frame drops (fade-to-black masks compilation) |

*All phase behaviors are visual/perceptual — automated screenshot comparison is fragile and overkill for this project.*

---

## Validation Sign-Off

- [ ] All tasks have manual verification instructions
- [ ] Sampling continuity: every task has a run-and-observe step
- [ ] Wave 0 covers keyboard toggle and noise texture prerequisites
- [ ] No watch-mode flags
- [ ] Feedback latency < 10s (scene launch time)
- [ ] `nyquist_compliant: true` set in frontmatter

**Approval:** pending
