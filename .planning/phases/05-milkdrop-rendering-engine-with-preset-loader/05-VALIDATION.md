---
phase: 5
slug: milkdrop-rendering-engine-with-preset-loader
status: draft
nyquist_compliant: false
wave_0_complete: false
created: 2026-04-20
---

# Phase 5 — Validation Strategy

> Per-phase validation contract for feedback sampling during execution.

---

## Test Infrastructure

| Property | Value |
|----------|-------|
| **Framework** | GDScript unit tests (GdUnit4 or built-in) + manual VR visual verification |
| **Config file** | none — Wave 0 installs |
| **Quick run command** | `godot --headless --script tests/run_tests.gd` |
| **Full suite command** | `godot --headless --script tests/run_all.gd` |
| **Estimated runtime** | ~5 seconds (unit), manual for visual |

---

## Sampling Rate

- **After every task commit:** Run quick unit tests
- **After every plan wave:** Run full suite + visual spot check
- **Before `/gsd:verify-work`:** Full suite must be green + visual verification
- **Max feedback latency:** 10 seconds

---

## Per-Task Verification Map

| Task ID | Plan | Wave | Requirement | Test Type | Automated Command | File Exists | Status |
|---------|------|------|-------------|-----------|-------------------|-------------|--------|
| TBD | TBD | TBD | VIS-03 | visual+unit | TBD | ❌ W0 | ⬜ pending |
| TBD | TBD | TBD | VIS-04 | visual+unit | TBD | ❌ W0 | ⬜ pending |
| TBD | TBD | TBD | INF-04 | visual | TBD | ❌ W0 | ⬜ pending |

*Status: ⬜ pending · ✅ green · ❌ red · ⚠️ flaky*

---

## Wave 0 Requirements

- [ ] Test framework setup (GdUnit4 or equivalent)
- [ ] NSEEL parser unit test stubs
- [ ] .milk file parser test stubs with sample preset data
- [ ] Grid mesh generation verification tests

*Visual rendering tests require manual verification — automated screenshot comparison is out of scope for Phase 5.*

---

## Manual-Only Verifications

| Behavior | Requirement | Why Manual | Test Instructions |
|----------|-------------|------------|-------------------|
| Warp visuals match Milkdrop look | VIS-03 | Visual quality is subjective | Load reference preset, compare side-by-side with MilkDrop3 output |
| Waveform overlays render correctly | VIS-03 | Visual correctness check | Load preset with waveforms, verify circles/lines appear and pulse with audio |
| VR dome presentation | INF-04 | Requires VR hardware | Run on Quest 3 via Virtual Desktop, verify dome wraps correctly at 90fps |
| Mode switching works | INF-04 | Integration test | TAB between spectrum bars and milkdrop, verify fade transition |

---

## Validation Sign-Off

- [ ] All tasks have `<automated>` verify or Wave 0 dependencies
- [ ] Sampling continuity: no 3 consecutive tasks without automated verify
- [ ] Wave 0 covers all MISSING references
- [ ] No watch-mode flags
- [ ] Feedback latency < 10s
- [ ] `nyquist_compliant: true` set in frontmatter

**Approval:** pending
