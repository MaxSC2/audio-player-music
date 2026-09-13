# NeonWave (audio_player) — аудит и план исправлений

**Дата:** 2026-09-13
**Целевая платформа:** **Android 13+ (API 33+)** — зафиксированная цель проекта.
**Рабочая копия:** `/storage/emulated/0/projects/audio_player` (она же `/sdcard/projects/audio_player`)
**Git:** локальная ветка `gitlab-main` (squash-импорт, 1 коммит) **новее** GitHub `origin/master`
(`MaxSC2/audio-player-music`, последний коммит `v93`, 2026-09-08).
**Проверка:** `flutter analyze --no-pub` — чисто; разбор `app-release.apk` через `aapt2`;
чтение исходников `just_audio 0.10.6`, `audio_service 0.18.19`, `permission_handler_android 12.1.0`.

> Корректировка относительно первой редакции: так как поддержка ограничена **Android 13+**,
> проблема с `Permission.audio` на Android ≤12 (пункт H1) **выведена из скоупа** и переведена
> в раздел «не дефект для целевой платформы». Всё остальное в силе.

---

## 1. Матрица находок

| # | Приоритет | Файл(ы) | Суть | Статус |
|---|---|---|---|---|
| C1 | Critical | `lib/providers/player_provider.dart` | `currentIndex`/`currentTrack` игнорировали `_nativeOffset` (окно treadmill) | исправлено |
| C2 | Critical | `android/app/src/main/AndroidManifest.xml`, `.github/workflows/build-apk.yml` | Манифест перезаписывался только в CI → локальные сборки без foreground-сервиса | исправлено |
| H2 | High | `MainActivity.kt` | Удаление трека считалось успешным до подтверждения системного диалога | исправлено |
| H3 | High | `lib/providers/player_provider.dart` | `_switchingSource` без `try/finally` → «залипание» плеера | исправлено |
| M1 | Medium | `lib/services/audio_handler.dart` | `playbackState.add` на каждом тике позиции (~5 Гц) | исправлено |
| M2 | Medium | `lib/providers/player_provider.dart` | Полный список id очереди писался в SharedPreferences каждые 5 с | исправлено |
| M3 | Medium | `lib/providers/player_provider.dart` | `isFavorite` — линейный поиск по `List<int>` (O(n·m)) | исправлено |
| M4 | Medium | `lib/providers/player_provider.dart` | `_allTracks.indexWhere` внутри циклов по истории | исправлено |
| M7 | Medium | `widget_service.dart`, `audio_handler.dart` | Неограниченные кэши обложек (байты + temp-файлы) | исправлено |
| M5 | Medium | `player_provider.dart` (`loadTracks`) | MediaStore-запрос + 6k объектов на UI-isolate | исправлено (batch 2) |
| M6 | Medium | ~32 × `context.watch<PlayerProvider>()` | Широкие перестройки экранов | частично (batch 2: queue_sheet) |
| L1–L8 | Low | разные | Гигиена/lifecycle | частично |
| H1 | — | `player_provider.dart` | `Permission.audio` = denied на Android ≤12 | вне скоупа (Android 13+) |

---

## 2. Что именно исправлено

### C1. Индекс и текущий трек при очереди > 81 трека — `player_provider.dart`

`just_audio` отдаёт индекс **внутри загруженной последовательности** (`sequence`), а не в полном
`_playlist`; «treadmill» держит окно ±40 треков вокруг текущего. Offset применялся только в
`_handleIndexEvent`, а геттеры — нет:

```dart
// БЫЛО
int get currentIndex {
  final idx = _audioPlayer.currentIndex;
  if (idx != null && idx >= 0 && idx < _playlist.length) return idx;  // без _nativeOffset
  return _currentIndex;
}
```

Сценарий: 6400 треков, тап по треку №500 → окно `[460..540]`, `_nativeOffset = 460`, нативный
индекс = 40 → UI показывал `_playlist[40]` (трек №41) вместо №500. Ломались мини-плеер,
Now Playing, медиа-уведомление, виджет рабочего стола, подсветка в очереди и запись
skip-статистики. При очереди ≤81 трека offset = 0, поэтому баг «не замечали».

**Стало:** оба геттера переводят индекс `native + _nativeOffset`.
Дополнительно подтверждено, что **тот же баг есть в GitHub `origin/master` (v93)** — строки
456–460, то есть дефект уходил в публичную историю.

### C2. Расхождение манифестов dev/CI — `AndroidManifest.xml` + `build-apk.yml`

CI-шаг `Update AndroidManifest` целиком перезаписывал манифест heredoc'ом, добавляя то, чего нет
в репозитории: `WAKE_LOCK`, `FOREGROUND_SERVICE`, `FOREGROUND_SERVICE_MEDIA_PLAYBACK`,
`POST_NOTIFICATIONS` и `<service com.ryanheise.audioservice.AudioService>`. У плагина
`audio_service 0.18.19` собственный манифест **пустой** — объявлять обязан манифест приложения.
Итог: `flutter run` / локальный `flutter build apk` давали сборку без foreground-сервиса —
не работали фоновое воспроизведение, медиа-уведомление и запрос `POST_NOTIFICATIONS`.
Подтверждено сравнением: в `app-release.apk` (CI) всё это есть, в закоммиченном манифесте — нет.

**Стало:**
* в манифест добавлены 4 разрешения и `<service ... android:foregroundServiceType="mediaPlayback">`;
* добавлен `WRITE_EXTERNAL_STORAGE maxSdkVersion=29` для паритета с уже выпущенным APK;
* `flutter create` в CI перезаписывает манифест → добавлены backup/restore в шаге
  «Create Flutter project»;
* шаг `Update AndroidManifest` заменён на `Verify AndroidManifest` (grep-проверки), чтобы
  расхождение не вернулось и ловилось уже на CI.

### H2. Удаление трека — `MainActivity.kt`

```kotlin
// БЫЛО: ответ success(true) сразу после запуска диалога
startIntentSenderForResult(pendingIntent.intentSender, DELETE_REQUEST_CODE, null, 0, 0, 0)
true
```

`onActivityResult` не был переопределён, поэтому Dart удалял трек из `_allTracks`, избранного,
плейлистов и очереди **даже если пользователь нажимал «Отмена»** — файл оставался, состояние
расходилось с файловой системой.

**Стало:** `pendingDeleteResult` завершается из `onActivityResult` по `RESULT_OK`; добавлен
`deleteImmediately()` для Android < 11; повторный запрос при уже открытом диалоге отклоняется.

### H3. `_switchingSource` без `try/finally` — `player_provider.dart`

Исключение из `_buildNativeSlice` (`setAudioSources` бросает на битом файле) оставляло флаг
включённым, а `_handleIndexEvent` начинается с `if (_switchingSource) return;` — плеер переставал
реагировать на смену трека до перезапуска. `playFromPlaylist` был единственным методом без
`try/finally` (в `_maybeResume`, `_prepareInitialPlaylist`, `_rebuildPlaylist` он есть).

**Стало:** тело `playFromPlaylist` обёрнуто в `try { ... } finally { _switchingSource = false; }`.

### M1. Троттлинг позиции в медиа-сессии — `audio_handler.dart`

`player.positionStream` публиковался в `playbackState` на каждом тике (~5 Гц) → до 5 маршалингов
в платформенный канал в секунду ради MediaSession/уведомления. `audio_service` экстраполирует
позицию между апдейтами (`updatePosition` + `speed`).
**Стало:** публикация не чаще 1 раза в секунду.

### M2. Персист позиции — `player_provider.dart`

`_maybePersistPosition` каждые 5 секунд сериализовал **весь** список id очереди (на 6k+ треков)
и писал в SharedPreferences.
**Стало:** список пишется только при реальной смене очереди (`_persistQueueSnapshot` вызывается
из `playFromPlaylist` и `_rebuildPlaylist`), а тикер пишет три скалярных значения
(`last_index`, `last_position_ms`). При включении «Продолжить слушать» снимок делается сразу.

### M3. Избранное — `Set<int>` вместо `List<int>`

`isFavorite()` вызывается для каждого трека в каждом списке (`_refreshTrackFavoriteFlags`,
`visibleTracks`, `favoriteTracks`) — линейный поиск давал O(треки × избранное) на каждый тап
«сердечка». Плюс `_loadFavorites` превращал битые записи в `id = 0`.
**Стало:** `final Set<int> _favoriteIds`, `contains()`, непарсящиеся id пропускаются.

### M4. `id → track` вместо `indexWhere` в циклах

`_allTracks.indexWhere` внутри циклов по истории (до 300 записей × 6k треков) в
`totalListeningTime`, `allBookmarks`, `tracksForDay`, `applyQueueSnapshot`, `_maybeResume`,
`trackScoreBreakdown`.
**Стало:** кэш `Map<int, AudioTrack> _tracksById`, инвалидируется в `_invalidateFolderCache`
(вызывается при загрузке/сортировке/удалении/изменении избранного).

### M7. Ограничение кэшей обложек

`WidgetService._artCache` (байты PNG) и `PlayerAudioHandler._artPaths` (пути к temp-файлам)
росли без границ.
**Стало:** LRU на 24 обложки в виджете; кэш путей ограничен 40 записями с удалением старых
temp-файлов.

### Прочие правки

* `debug_log.dart`: `DebugLog.rebuild()` — no-op вне `kDebugMode` (18 вызовов в hot-path build).
* `cycleSpeed()`: поиск ближайшей скорости вместо `indexOf(double)` (ненадёжен из-за точности).
* `toggleFavoriteCurrent()`: убран лишний push в виджет **до** переключения избранного.

---

## 3. Вне скоупа / отложено

### H1 (было High) — `Permission.audio` на Android ≤12

`Permission.audio` = `Permission._(33)`; в `permission_handler_android 12.1.0`
(`PermissionUtils.java:347-350`) на `SDK_INT < TIRAMISU` список имён пуст, а
`PermissionManager.determinePermissionStatus` для пустого списка возвращает `DENIED`. Значит,
`requestPermission()` (проверяет `Permission.audio`) на Android ≤12 не загрузил бы библиотеку.

**Для целевой платформы Android 13+ это не дефект** — там `READ_MEDIA_AUDIO` запрашивается
корректно. Если когда-нибудь понадобится поддерживать Android ≤12, фикс:
```dart
granted = (await Permission.audio.request()).isGranted;      // Android 13+
if (!granted) granted = (await Permission.storage.request()).isGranted;  // Android ≤12
```

### M5. `loadTracks()` на UI-isolate — отложено

MediaStore-запрос + построение ~6k объектов `AudioTrack` синхронно на главном изоляте
(фриз на старте и на «Обновить библиотеку»). Требует аккуратного `compute()`-разбиения:
`OnAudioQuery.querySongs` использует platform channel, поэтому в изолят нужно выносить
только маппинг, либо перейти на нативный batch-запрос. Делать отдельным этапом с замером.

### M6. `context.watch` → `context.select` — отложено

32 широких `context.watch<PlayerProvider>()` против 5 `select`. Правка затрагивает много
экранов и легко даёт тонкие регрессии реактивности; делать по одному экрану с проверкой
на устройстве. Приоритетные кандидаты: `cover_flow_now_playing_screen.dart`,
`queue_sheet.dart`, `library_tabs.dart`.

### L (низкий приоритет)

* `dispose()` не отменяет подписки из `_init()` и не диспозит `positionTick` (провайдер живёт
  весь процесс, поэтому риск низкий).
* `AudioTrack.copyWith` не умеет сбрасывать nullable-поля в `null`.
* `_prepareInitialPlaylist` / `albumEntries` используют `_allTracks` вместо `visibleTracks`
  (игнорируют «скрыть Unknown Artist»).
* `getImageUri` при удалении ищет по `MediaColumns.DATA` (deprecated) — надёжнее передавать
  MediaStore-`Uri` из `on_audio_query`.

---

## 4. Выполненные проверки

| Проверка | Результат |
|---|---|
| `flutter analyze --no-pub` (после всех правок) | **No issues found!** (EXIT=0) |
| `AndroidManifest.xml` — XML-валидность + состав | OK: 10 `uses-permission` (включая `FOREGROUND_SERVICE`, `FOREGROUND_SERVICE_MEDIA_PLAYBACK`, `POST_NOTIFICATIONS`, `WAKE_LOCK`) + `<service com.ryanheise.audioservice.AudioService foregroundServiceType="mediaPlayback">` |
| Паритет с выпущенным APK (`aapt2 dump badging app-release.apk`) | состав разрешений и сервиса совпадает 1:1 |
| `.github/workflows/build-apk.yml` — структура шагов и отсутствие heredoc | OK: шаги `Checkout → Setup Java → Setup Flutter → Create Flutter project → Setup signing → Verify AndroidManifest → Install dependencies → Build APK → Upload APK`; `EOFMANIFEST`/`Update AndroidManifest` отсутствуют |
| Kotlin `MainActivity.kt` | визуальная проверка: `pendingDeleteResult`, `onActivityResult`, `deleteImmediately`, обработка второго диалога |

**Не проверено (нужно устройство/эмулятор):**
* компиляция Kotlin (`flutter build apk` требует gradle-скелета, которого в репозитории нет
  по замыслу — его создаёт `flutter create` в CI);
* сборка CI (нужен push, чтобы увидеть зелёный workflow);
* поведение на устройстве по сценариям из раздела 5.

---

## 5. Сценарии приёмки на устройстве (Android 13+)

1. **C1.** Очередь из ≥300 треков (папка с большим числом файлов или «Треки» целиком):
   запустить трек №150 → заголовок мини-плеера, экран Now Playing, медиа-уведомление и
   виджет рабочего стола должны показывать **именно** запущенный трек;
   подсветка в «Очереди» — на нём же.
2. **C1.** Автопереход на следующий трек на границе окна (например, трек №499 → №500) —
   информация не должна «съезжать».
3. **C2.** `flutter build apk --release` (или CI) и `aapt2 dump xmltree --file AndroidManifest.xml`
   по собранному APK: наличие `AudioService` и 4 разрешений; воспроизведение в фоне при
   погашенном экране, медиа-уведомление, запрос уведомлений на Android 13+.
4. **H2.** Удалить трек и **нажать «Отмена»** в системном диалоге → трек должен остаться
   в библиотеке/очереди (раньше исчезал). Повторить с подтверждением → трек исчезает.
5. **H3.** Запустить битый/недоступный файл в очереди → плеер после ошибки должен продолжать
   реагировать на переключение треков (раньше «замирал»).
6. **M1/M2.** Во время воспроизведения: в мега-логере `notify/s` и нагрузка не должны расти;
   «продолжить слушать» после перезапуска — на том же треке и позиции.
7. **M3/M4.** Тап «сердечка» при 6k библиотеке не должен давать заметного фриза;
   вкладки DNA/История/закладки открываются без пауз.

---

## 6. Изменённые файлы

```
lib/providers/player_provider.dart                    — C1, H3, M2, M3, M4, L (cycleSpeed,
                                                        toggleFavoriteCurrent, _loadFavorites)
lib/services/audio_handler.dart                       — M1, M7
lib/services/widget_service.dart                      — M7
lib/core/debug_log.dart                               — гигиена (kDebugMode, импорты)
android/app/src/main/AndroidManifest.xml              — C2
android/app/src/main/kotlin/.../MainActivity.kt       — H2
.github/workflows/build-apk.yml                       — C2
AUDIT_REPORT_2026-09-13.md                            — этот отчёт
```

---

## 7. Рекомендации на будущее (не входят в текущие правки)

1. **Единый индекс.** Три параллельных источника текущего трека (`_currentIndex`,
   `_lastEventIndex`, `player.currentIndex`) — корневая причина C1. Надёжнее хранить
   `currentTrackId` и вычислять индексы; в отладочных сборках держать
   `assert(_toProviderIndex(native) == _currentIndex)`.
2. **Слой доступа к медиа.** `loadTracks`, `AudioHandler._attachArt`, `ArtworkCache`,
   `WidgetService` — четыре независимых потребителя MediaStore с разными стратегиями кэша.
3. **Тесты.** `flutter_test` объявлен, но каталога `test/` нет. Чистые функции
   (`GenreTaxonomy`, `sortTracks`, offset-математика окна, `_inferCategories`, модели)
   легко покрываются без плагинов — это защитило бы от регрессий вроде C1.
4. **Разбиение `player_provider.dart`** (3000+ строк, ~60 call-site'ов `_notify`) на
   контроллеры (`QueueController`, `LibraryRepository`, `FavoritesStore`, `GenreService`).
5. **Аудио-сессия.** Настроить `AudioSessionConfiguration.music()` и обрабатывать
   `becomingNoisy` (пауза при отключении наушников) — закрывает открытый вопрос из
   `ANDROID_AUDIO_AUDIT.md` о «возобновлении через динамик».
6. **Версионирование схемы настроек** в SharedPreferences (`schema_version`), иначе
   ad-hoc миграции (как `dateAdded → dateAddedNew`) будут накапливаться.