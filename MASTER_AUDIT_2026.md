# NeonWave — Master Audit 2026

Date: 2026-09-20 · Updated: 2026-10-22
Branch: `stack-upgrade` (merged) → `master`
Base at audit time: `master` (v94)
Current app version: **v141**

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

## v141 — P0 navigation and settings cleanup

- replaced the horizontally scrolling nine-tab library bar with five stable destinations: Tracks, Playlists, Albums, Artists and More;
- Folders, Favorites, History, DNA and Categories now live in a compact “More” sheet with a clear selected state and no clipped labels;
- the UI style picker is a 2×2 grid with short descriptions instead of a cramped segmented control;
- palette presets use a four-column grid, so every swatch is visible without horizontal scrolling;
- the About section reads the real app version through `package_info_plus` instead of the stale 1.0.0 string;
- Neon and Cinematic now use the shared mini-player wrapper, making the documented long-press style switch work everywhere.

Validation: `flutter analyze` clean; 70 tests pass, including compact navigation at 360 px width.

## v140 — neon mini player with swipe navigation

- added a dedicated neon mini player with a single play/pause control;
- swipe left selects the next track, swipe right selects the previous one, with an interactive card offset, velocity threshold, light haptic feedback and a smooth content transition;
- tapping the card still expands the full player; gesture cancellation resets the offset;
- swipe direction logic is covered by unit tests.

Validation: `flutter analyze` clean; 68 tests pass.

## v139 — simpler full-screen splash

- fixed splash collapsing into the left half: `AnimatedSwitcher` now uses `StackFit.expand` and the splash is wrapped in `SizedBox.expand`;
- replaced the heavy per-style backdrop painters and wave with a restrained centered layout: logo, wordmark, tagline, progress and style label;
- the breathing animation now rebuilds only the logo instead of the whole `Scaffold`;
- added a widget test that asserts a full-screen, horizontally centered splash.

Validation: `flutter analyze` clean; 65 tests pass.

## v138 — rescue copy, diagnostic log and style-specific splash

Implemented:
- critical settings are mirrored to `Android/media/com.example.audio_player/neonwave_rescue.json` via the `neonwave/rescue` native channel;
- the newest copy wins on startup (file newer than prefs, or prefs have no critical keys);
- native diagnostics log at `neonwave_diagnostics.log` includes legacy prefs, file timestamp, `rescue_saved_at` and launch count;
- `BootGate` now renders a distinct animated splash for Simple, Cover Flow 3D, Cinematic and Neon, using the selected style before HomeScreen opens;
- rescue flush is triggered on app pause/detach.

Validation: `flutter analyze` clean; 4 rescue tests added; full suite and device reinstall pending.

## v137 — preferences before audio initialization

Root cause of the v242+ reset regression: v135 moved `_attachPlayerStreams()` and an early `setSpeed()` ahead of `SharedPreferences.getInstance()`. On affected devices audio/ExoPlayer initialization blocked the platform channel long enough for prefs to time out, so every style/favorite/sort write was dropped.

Changes:
- `SharedPreferences.getInstance()` starts in `main()` before `PlayerProvider`, equalizer and AudioPlayer are constructed;
- the same future is shared by provider, UiStyleController and PaletteController;
- audio streams and audio_session start only after the prefs request;
- early `setSpeed()` removed from stream attachment; speed is applied in `_loadSettings()`.

Validation: `flutter analyze` clean; prefs race tests added; full suite required before release.

## v136 — persistent state and startup races

Implemented:
- late SharedPreferences adoption no longer overwrites user choices made in the first seconds;
- sorting is re-applied to an already loaded library, with caches invalidated;
- favorites are merged, caches/flags refreshed, pending toggles replayed;
- playlists/history gain dirty flags and deferred writes; clearing history cannot resurrect it;
- repeat/shuffle/X-Boost persistence;
- UI style and palette controllers respect choices made before init completes;
- late resume, delete-track persistence, safe prefs reads.

Validation: `flutter analyze` clean, 58 tests pass. Device check still needed for restart persistence.

## v135 — startup stream attachment, data loading, neon visualizer

Implemented:
- player stream subscriptions attach before any awaited preferences/audio-session setup;
- SharedPreferences init bounded to 3 s with late adoption and merge of history/playlists/favorites;
- audio-session setup runs in background with a 5 s timeout;
- per-item playlist parsing and tolerant history parsing;
- duration fallback from track metadata on every track start (fixes `0:00/0:00` and disabled seek);
- neon visualizer redrawn as a smooth mirrored wave with gradient, glow, spectrum backdrop and full-spectrum resampling.

Validation: `flutter analyze` clean, 58 tests pass. Device check still needed for the reported history loss and visualizer feel.

## Merge status

The audit branch was merged into `stack-upgrade` (commit `fcc1716`) on 2026-10-21
together with the v113–v130 work that had landed while the audit was in progress.
`flutter analyze` is clean and all 53 tests pass. Android Auto still requires a
real device/emulator validation.

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


## v131 follow-up UX package

- `CachedArtwork`: crossfade между обложками (260 мс) с сохранением
  stale-while-revalidate поведения и LRU-кеша.
- `QueueSheet`: открывается у текущего трека (оценка offset 64 px, клампится
  по реальному maxScrollExtent); drag&drop сохранён.
- Sleep timer: новый режим «после N дослушанных треков» (1/3/5/10) с fade-out;
  минуты и треки взаимоисключающие; иконка в плеере реагирует на любой режим.
- Локальная сборка на ПК: `tool/setup_local_android.sh` + `tool/build_apk.sh`.
- README переписан под текущее состояние; CI docs синхронизированы.

## v134 boot splash

- `BootGate` показывает NeonWave-splash с анимированным логотипом и
  эквалайзером, пока грузятся палитра, стиль и `PlayerProvider`.
- HomeScreen открывается после прогрева (не более 4 с ожидания провайдера и
  3 с на библиотеку при выданном доступе), `AudioService.init` продолжается
  в фоне и не блокирует первый экран.
- Нативный launch background: тёмный `#0B0C16` + иконка приложения вместо
  чёрного прямоугольника.
- Открытый вопрос: история/ДНК после обновления опустели. Данные в prefs не
  удаляются кодом обновления; нужна информация о способе установки APK.

## v133 startup hotfix

- `lib/main.dart`: тема/стиль инициализируются с таймаутом 2 с, затем сразу
  вызывается `runApp`; `PlayerProvider.ready` ограничен 4 с, `AudioService.init`
  стартует после первого кадра. Зависший platform channel больше не оставляет
  приложение на чёрном экране.
- Таймауты пишутся в `DebugLog`; ошибка провайдера отображается в диагностике.
- Требует проверки на устройстве, где версия 242 открывалась чёрным экраном.

## v132 follow-up

- Плейлист: добавление треков прямо из экрана плейлиста, уже добавленные
  треки disabled и подписаны; пакетная запись в prefs одним notify.
- Мультивыбор: long-press + drag выделяет диапазон в «Треках» и «Избранном»;
  добавлена видимая кнопка входа в режим выбора; действия применяются к набору.
- Авторелиз: push в `master` публикует `NeonWave.apk` в GitHub Releases
  (`--latest`), CI-артефакт остаётся.
