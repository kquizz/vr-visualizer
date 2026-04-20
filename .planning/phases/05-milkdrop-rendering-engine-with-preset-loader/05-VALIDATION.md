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
| 05-01-T1 | 05-01 | 1 | VIS-03 | automated | `cd addons/projectm && ls src/register_types.h src/register_types.cpp SConstruct projectm.gdextension` | N/A (scaffold) | pending |
| 05-01-T2 | 05-01 | 1 | VIS-03 | automated | `cd addons/projectm && scons platform=macos 2>&1 \| tail -5 && ls bin/libprojectm_gdext*` | N/A (build) | pending |
| 05-02-T1 | 05-02 | 2 | VIS-03 | automated | `grep -n "AudioEffectCapture\|get_pcm_buffer\|_capture_effect" scripts/autoloads/audio_manager.gd` | N/A (code mod) | pending |
| 05-02-T2 | 05-02 | 2 | VIS-03, VIS-04, INF-04 | automated | `grep "ProjectMWrapper" scenes/modes/milkdrop.gd && grep "milkdrop_texture" shaders/milkdrop_display.gdshader` | N/A (new files) | pending |
| 05-03-T1 | 05-03 | 3 | VIS-04 | automated | `ls presets/*.milk \| wc -l && grep "milkdrop.tscn" scripts/autoloads/mode_manager.gd && ! test -f scenes/modes/warp.gd` | N/A (wiring) | pending |
| 05-03-T2 | 05-03 | 3 | VIS-03, VIS-04, INF-04 | visual | Human verification: flat-screen + VR (Quest 3 via Virtual Desktop) | N/A (manual) | pending |

*Status: pending / green / red / flaky*

---

## Wave 0 Requirements

- [ ] projectM installed via Homebrew (`brew install projectm`)
- [ ] godot-cpp cloned and compiled for macOS
- [ ] 5 test .milk preset files in `presets/` directory

*Visual rendering tests require manual verification -- automated screenshot comparison is out of scope for Phase 5.*

---

## Manual-Only Verifications

| Behavior | Requirement | Why Manual | Test Instructions |
|----------|-------------|------------|-------------------|
| Audio drives warp parameters | VIS-03 | Requires live audio + visual inspection | Play music, verify zoom/warp on bass hits, rotation on mids, color on treble |
| Flowing psychedelic visuals | VIS-04 | Visual quality is subjective | Load preset, verify feedback loop produces trails and flowing motion |
| VR dome presentation | INF-04 | Requires VR hardware | Run on Quest 3 via Virtual Desktop, verify dome wraps correctly at 90fps |
| Flat-screen fallback | INF-04 | Integration test | Run on macOS, verify milkdrop renders in flat-screen preview mode |
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
