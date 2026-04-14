---
phase: 1
slug: vr-audio-foundation
status: draft
nyquist_compliant: false
wave_0_complete: false
created: 2026-04-13
---

# Phase 1 — Validation Strategy

> Per-phase validation contract for feedback sampling during execution.

---

## Test Infrastructure

| Property | Value |
|----------|-------|
| **Framework** | Godot built-in (editor run) + manual verification |
| **Config file** | project.godot (no separate test config) |
| **Quick run command** | `Run scene in Godot editor (F5)` |
| **Full suite command** | `Manual checklist: flat-screen + VR on Quest 3` |
| **Estimated runtime** | ~30 seconds (editor launch + scene play) |

---

## Sampling Rate

- **After every task commit:** Run scene in editor (F5), verify audio plays and debug overlay shows data
- **After every plan wave:** Full checklist: flat-screen mode works, VR mode works (if Windows available), all 4 stems audible, FFT data visible, test shader reacts
- **Before `/gsd:verify-work`:** Full suite must be green — VR verification on Quest 3 via Virtual Desktop, all 5 success criteria confirmed
- **Max feedback latency:** 30 seconds

---

## Per-Task Verification Map

| Task ID | Plan | Wave | Requirement | Test Type | Automated Command | File Exists | Status |
|---------|------|------|-------------|-----------|-------------------|-------------|--------|
| 01-01-01 | 01 | 1 | AUD-01 | manual + audio | Play scene, verify 4 AudioStreamPlayers active | ❌ W0 | ⬜ pending |
| 01-01-02 | 01 | 1 | AUD-02 | manual | Debug overlay shows non-zero, varying FFT values | ❌ W0 | ⬜ pending |
| 01-01-03 | 01 | 1 | AUD-03 | unit | GDScript test: create AudioData, verify properties | ❌ W0 | ⬜ pending |
| 01-02-01 | 02 | 1 | VR-01 | manual | Deploy to Windows + Virtual Desktop, verify stereo rendering | ❌ W0 | ⬜ pending |
| 01-02-02 | 02 | 1 | VR-02 | manual | Godot profiler, frame time < 11ms | ❌ W0 | ⬜ pending |
| 01-02-03 | 02 | 1 | VR-03 | manual | Verify no forced movement, static origin | ❌ W0 | ⬜ pending |
| 01-01-04 | 01 | 1 | INF-01 | integration | Run scene, verify debug overlay updates each frame | ❌ W0 | ⬜ pending |
| 01-01-05 | 01 | 1 | INF-02 | visual | Test reactive mesh visibly changes with music | ❌ W0 | ⬜ pending |

*Status: ⬜ pending · ✅ green · ❌ red · ⚠️ flaky*

---

## Wave 0 Requirements

- [ ] Godot project created from scratch with project.godot
- [ ] `default_bus_layout.tres` — 5 buses (Master + 4 stems) with AudioEffectSpectrumAnalyzer on each stem bus
- [ ] Test stem files (4x OGG) — prepared with Demucs or sourced as test assets
- [ ] Global shader uniforms pre-defined in Project Settings (16 uniforms: 4 per stem)
- [ ] Deep space skybox asset (static panorama texture)

*No automated test framework — Godot lacks built-in unit testing for GDScript; manual verification is standard for this domain.*

---

## Manual-Only Verifications

| Behavior | Requirement | Why Manual | Test Instructions |
|----------|-------------|------------|-------------------|
| VR scene renders on Quest 3 | VR-01 | Requires physical headset + Virtual Desktop + Windows | Deploy to Windows machine, launch with Virtual Desktop, confirm stereo rendering |
| Stable 90fps | VR-02 | Requires VR runtime profiler | Check Godot profiler frame time < 11ms during VR playback |
| Comfortable VR, static viewpoint | VR-03 | Subjective comfort assessment | Verify no forced movement, camera at static origin, no discomfort triggers |
| 4 stems audible simultaneously | AUD-01 | Audio output verification | Play scene, listen for all 4 stem tracks playing together |
| FFT data varies per frame | AUD-02 | Visual inspection of debug overlay | Run scene, verify debug overlay numbers change frame-to-frame |
| Test shader reacts to audio | INF-02 | Visual inspection | Play music, verify test mesh visually changes with beat/frequency |

---

## Validation Sign-Off

- [ ] All tasks have `<automated>` verify or Wave 0 dependencies
- [ ] Sampling continuity: no 3 consecutive tasks without automated verify
- [ ] Wave 0 covers all MISSING references
- [ ] No watch-mode flags
- [ ] Feedback latency < 30s
- [ ] `nyquist_compliant: true` set in frontmatter

**Approval:** pending
