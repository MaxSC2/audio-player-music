# Промт для консультации с сильной моделью: UI-лаги NeonWave

You are a senior Flutter performance engineer specializing in UI-thread jank diagnosis. Help diagnose severe, sustained UI-thread lag in a production music player app.

## App facts
- Flutter (CI builds on 3.47), Dart, `provider` (ChangeNotifier) for state.
- Audio: `just_audio 0.10.6` + `audio_service 0.18.19`. Local files only.
- Library: ~6400 tracks. Player state lives in one big `PlayerProvider : ChangeNotifier` (~60 `notifyListeners()` call sites).
- just_audio `positionStream` ticks up to ~5 Hz (16–200 ms interval per docs).
- Native audio queue uses a "treadmill": only a ±40 window around the current track is loaded into just_audio; the full list lives in Dart. `setAudioSources` is called only on queue switch / window slide.
- Artwork: `Image.memory` from MediaStore bytes, in-memory LRU (200 entries, ~400px PNGs), neighbor preloading ±3 on page change.
- Screens: 4 visual styles (simple / 3D / cinematic / neon). Player screens contain: PageView 3D carousel (Matrix4 perspective, per-card ColorFiltered saturation + ImageFiltered blur on far cards, RepaintBoundary per card), CustomPaint visualizers driven by AnimationControllers, MarqueeText, sliders, feature buttons.
- One screen has an ambient background driven by a repeating 14s AnimationController (rebuilds only glow blobs; content is passed via AnimatedBuilder `child`).
- AudioService publishes playbackState to the notification on position ticks.

## Measured symptoms (in-app FPS meter, mid-range Android)
- UI thread: average ~150–600+ ms/frame sustained DURING playback, spikes 1000+ ms on track start. Raster thread: ~11 ms avg, 300+ max — i.e., Dart UI thread is pegged, GPU is mostly fine.
- Lags are ABSENT in the "3D" visual style, but appear in the other three styles as soon as playback starts. Opening any track list in 3D style also triggers lag, with raster jumping to 550+ ms.
- Screen-transition delays (route push feels sluggish).
- A `notifyListeners()` rate meter shows bursts up to ~40 notifications/sec during playback.
- A sharp, very short click/pop is audible on track start EVEN with media volume at 0.

## What we already tried (marginal or no improvement)
- All list-derived getters cached (search, folders/artists/albums, smart playlists, categories, visibleTracks) with invalidation on library/history change.
- Position-tick global notifications throttled (first to 300 ms, then to 1 Hz on second change); progress UI moved to a dedicated `ValueNotifier<Duration>` listened via ValueListenableBuilder.
- Fullscreen blur isolated in RepaintBoundary + sigma reduced; visualizer animation controllers gated on isPlaying.
- EQ gains now applied only on preset change (previously re-applied on every track).
- Treadmill window replaced full-list `setAudioSources` marshalling on taps.

## Questions
1. Given raster is fine but the UI thread averages 150–600 ms/frame during playback, what is the most likely class of cause: rebuild storms, synchronous Dart work per tick, GC pressure from image churn, platform-channel flooding (notification updates per position tick?), or something in ExoPlayer↔just_audio event flow? Rank by probability.
2. Why would one visual style (3D carousel, no fullscreen blur, no per-card ColorFiltered/ImageFiltered) be immune while others lag — is per-card saveLayer (ColorFiltered + ImageFiltered blur) a plausible sustained UI-thread peg, or would that show on raster instead?
3. What explains ~40 ChangeNotifier notifications/sec when position ticks are throttled to 1 Hz — what mechanisms could re-notify that fast (e.g., streams echoing, setState loops, controller listeners)?
4. What could cause an audible sharp click on track start at zero media volume — hardware audio-session pop, effect attach, or something an app can produce outside the media stream?
5. What is the single most informative measurement to take next on-device (we have no profiler access, only in-app logging), and what minimal code change would most likely move the needle?
