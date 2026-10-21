# NeonWave — Master Audit 2026

Date: 2026-09-20
Branch: `refactor/media-session-window-audit`
Base: `master`

## Scope

This audit is based on the current source tree, not on older backlog claims. Existing features were verified before deciding whether they need changes.

## Verified existing functionality

- Local playback via just_audio/audio_service.
- Treadmill native playback window around the current provider index.
- Shuffle with Fisher-Yates order and current-track preservation.
- Repeat off/all/one with native LoopMode.one.
- EQ presets using AndroidEqualizer.
- Per-track adaptive volume correction and X-Boost.
- Personal DJ / local recommendation engine.
- Local AI Radio / queue extension.
- Listening contexts: Balanced, Energy, Calm, Party, Focus.
- Natural-language playlist parser.
- Genre taxonomy, manual override, online lookup and keyword inference.
- iTunes + MusicBrainz genre fallback.
- History, skip learning, favorites, bookmarks and statistics.
- Smart playlists and queue snapshots.
- M3U import/export with path-aware deterministic matching.
- Four UI styles: Simple, Cover Flow 3D, Cinematic, Neon.
- Preset/custom palettes and light/dark modes.
- Visualizers with lifecycle handling.
- Widgets and Android MediaSession controls.
- Android Auto browse tree (library, favorites, recent, playlists) with paged track browsing.
- URL playback.
- Sleep timer and fade.
- Resume playback.
- Permission and media-service diagnostics.

## Changes implemented in this branch

### P1 — MediaSession queue size

The provider already keeps a bounded native treadmill window, but audio_service was still receiving the complete provider queue.

Implemented:
- bounded MediaSession queue;
- provider queue remains the source of truth;
- local MediaSession index -> provider index mapping;
- queue synchronization after native-window rebuilds and attachment;
- bounded trimming after queue insertion;
- tests for index mapping and trim planning.

Device validation still required for Android Auto/queue browsing.

### P1 — Audio gain composition

The old implementation could apply learned per-track gain through LoudnessEnhancer and also through setVolume, while X-Boost added another gain path.

Implemented:
- learned track correction is applied through setVolume;
- X-Boost is applied independently through LoudnessEnhancer;
- effective-volume math is isolated and tested;
- learned correction is disabled when Auto Balance is off, but stored corrections remain available for re-enabling.

### P1 — Recommendation recency

History is stored newest-first.

Fixed:
- latest occurrence is kept instead of the oldest occurrence;
- recency distance uses the newest-first index directly;
- recommendation explanation follows the same recency semantics.

### P2 — Playback error observability

Added errorStream-backed playback diagnostics and debug UI visibility for the last playback error, timestamp and count.

### P2 — Recommendation explanation consistency

Fixed drift between recommendation scoring and the explanation sheet:
- genre affinity;
- context/category boost;
- current-track penalty;
- favorite bonus;
- authoritative favorite ID source.

Removed a dead `queue.contains()` scoring condition that could never trigger because selected IDs are already excluded.

### P1 — Auto Balance / gain semantics

Separated learned per-track correction from X-Boost and made the Auto Balance toggle actually disable stored correction application without discarding learned data.

### P2 — Not-now performance/cache

Implemented:
- cached set of not-now IDs;
- invalidation on expiry/toggle;
- expiry runs before returning cached not-now tracks.

### P2 — UI rebuild narrowing

SimpleHome now subscribes only to library count.

CinematicHome now subscribes only to:
- queue-present state;
- current track ID.

### P2 — Preference resilience

Custom palette decoding now validates payload shape/value range and gracefully clears only a corrupt custom palette preference instead of failing startup.

### P2 — Playback error observability

Added:
- last playback error;
- timestamp;
- error count;
- errorStream listener;
- debug diagnostics display.

No automatic skip behavior was introduced; playback failures still require explicit product behavior decisions.

### CI

Pull requests now have a quality job for:
- flutter pub get;
- flutter analyze;
- flutter test.

Release APK/signing remains disabled for pull_request events.

## Known validation limitation

The current execution environment does not contain Flutter/Dart, so local `flutter analyze` and `flutter test` were not executed and are not claimed as passing.

The GitHub repository currently exposes no workflow run for this draft branch, so CI status is also unverified.

## Required device validation

- 100 / 1000 / 3000 / 6400+ track libraries.
- Cross-window next/previous.
- Queue insert/remove/reorder.
- MediaSession notification.
- Lockscreen controls.
- Android widget.
- Android Auto browse tree and track playback.
- App restart/resume.
- EQ after interruption.
- X-Boost + Auto Balance combinations.
- URL playback errors.
- Corrupted custom palette recovery.
- Recommendation explanation versus generated queue.

## Deferred architecture work

- Gradual decomposition of `PlayerProvider`.
- Gradual decomposition of `SettingsScreen`.
- Design-token cleanup for hardcoded theme colors.
- Full backup/restore of user state.
- More accurate loudness normalization research.
- Android Auto-specific browsing UX.
- Optional Last.fm/ListenBrainz integration.
- Optional tag editing.
- Optional widget seek.

These are intentionally deferred until correctness and current-device validation are complete.
