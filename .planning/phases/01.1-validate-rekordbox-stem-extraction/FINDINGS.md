# Phase 1.1: Rekordbox Stem Extraction - Findings

**Date:** 2026-04-16
**Status:** Cache investigation complete; BlackHole setup pending

## Cache Investigation

**Result:** CONFIRMED DEAD END

Rekordbox does not cache stem audio files to disk. Stems are processed in real-time by an on-device AI model during playback. The analysis metadata (.3EX files) contains ML embeddings, not audio data. No audio files related to stem separation were found in any Rekordbox data directory.

### Directories Searched

| Directory | Audio Files Found | Notes |
|-----------|------------------|-------|
| `~/Library/Pioneer/rekordbox/` | **None** | Contains master.db (encrypted SQLite), USBANLZ analysis files, artwork cache |
| `~/Music/rekordbox/` | Sampler presets only | WAV files found are factory Sampler/OSC/MergeFX/Groove Circuit presets -- not stem audio |
| `~/Music/rekordbox/Sampler/Capture/` | **Directory does not exist** | Expected location for captured audio is absent entirely |
| `~/Library/Caches/rekordbox/` | **None** | Contains only app lock files (`mixVibesAppLock_rekordbox`, `juceAppLock_Upmgr`) |
| `~/Library/Caches/com.pioneerdj.rekordboxdj/` | **None** | WebKit cache only (NetworkCache, AlternativeServices SQLite) |
| `~/Library/Caches/com.pioneer.Upmgr_rekordbox/` | **None** | Update manager cache (Cache.db, fsCachedData) |
| `~/Library/Pioneer/` (files >1MB) | **None** | Only large files are `master.db` and `master.backup.db` (encrypted databases) |

### .3EX File Analysis

**File:** `~/Library/Pioneer/rekordbox/share/PIONEER/USBANLZ/0e1/f127e-68da-446d-a34e-570121725fd5/ANLZ0000.3EX`

**File size:** 956 bytes (far too small for audio -- even 1 second of 44.1kHz WAV is ~176KB)

**File type (from `file` command):** `data` (no recognized audio format header)

**Binary header (xxd):**
```
00000000: 81a9 656d 6265 6464 696e 678b a264 34cb  ..embedding..d4.
00000010: 401d 5810 624d d2f2 a264 3591 dc00 40ca  @.X.bM...d5...@.
00000020: 3f02 092a ca3f 085a 66ca 3f35 51f9 cb3f  ?..*.?.Zf.?5Q..?
00000030: fca8 7220 0000 01cb 4006 a743 4000 0001  ..r ....@..C@...
00000040: ca3e b37c 48ca 0000 0000 ca3f 0fba 0eca  .>.|H......?....
00000050: 3f21 42ba ca3e 4e68 30ca 3f65 d018 cb3f  ?!B..>Nh0.?e...?
00000060: f426 2cbf ffff ffca 3ff7 dcd8 ca40 057f  .&,.....?....@..
00000070: 30ca 3f03 c1b0 ca3e a273 3dca 3ebe 94c2  0.?....>.s=.>...
00000080: ca3e ddc2 41ca 3f49 c736 cb3f f3e1 687f  .>..A.?I.6.?..h.
00000090: ca3f 59b1 6aca 3ea7 2871 ca00 00            .?Y.j.>.(q...
```

**Analysis:** The file starts with msgpack-encoded data. The first key is `"embedding"` (visible as ASCII in the hex dump: `81a9 656d 6265 6464 696e 67`). The values are IEEE 754 floating-point numbers (`ca` = 32-bit float, `cb` = 64-bit float in msgpack). This is an ML feature embedding vector, not audio data.

The `.3EX` extension follows the ANLZ naming pattern (`.DAT`, `.EXT`, `.2EX`) and appears to be a newer addition storing the AI model's embedding output for each analyzed track.

### Audio Files Found

**None** -- no stem audio cached to disk.

The only audio files found under `~/Music/rekordbox/` are factory-installed sampler presets:
- `Sampler/OSC_SAMPLER/PRESET ONESHOT/` (SINEWAVE.wav, HORN.wav, SIREN.wav, NOISE.wav)
- `Sampler/MERGE FX/` (MergeFX Sample Sound *.wav)
- `Sampler/GROOVE CIRCUIT/` (drum kit presets)

These are Rekordbox DJ performance tools, completely unrelated to stem separation.

### Conclusion

**Rekordbox does NOT cache stem audio to disk.** This is definitively confirmed by:

1. **Zero audio files** found in any Rekordbox data directory outside of factory sampler presets
2. **The .3EX files contain ML embeddings** (956 bytes of msgpack float arrays), not audio data
3. **The Sampler/Capture directory does not even exist** on this installation
4. **No files >1MB** exist in `~/Library/Pioneer/` beyond the encrypted master databases
5. **macOS Caches directories** contain only web cache and app metadata, no audio

This confirms the research finding: Rekordbox stems are computed in real-time during playback by an on-device AI model. The .3EX embeddings may speed up re-analysis but do not contain reconstructed audio. To capture individual stems, the solo-and-capture workflow via BlackHole (or equivalent virtual audio routing) is required.

**Next step:** Install BlackHole 16ch and validate the solo-and-capture workflow (Task 2).

## BlackHole Setup

(To be completed in Task 2)

## Solo-and-Capture Results

(To be completed in Plan 02)
