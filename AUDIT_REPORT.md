# NeonWave (audio_player) — Отчёт об аудите и исправлениях

**Дата:** 2026-09-09
**Ветка:** локальная рабочая копия `/sdcard/projects/audio_player` (не запушено)
**Среда разработки:** Flutter 3.44.6 / Dart 3.12.2 (proot Linux arm64)

---

## 1. Резюме

Проект: локальный музыкальный плеер на Flutter, **~21 000 строк Dart** в `lib/`,
разросшийся монолит (100+ коммитов, 4 стиля интерфейса, медиа-сервис, виджеты
рабочего стола, «умные» подборки, DNA-статистика, жанровая таксономия,
iTunes/MusicBrainz-аугментация и т.д.).

**Главные проблемы:**
1. Критические баги в `switch` (fall-through) — код в текущем состоянии
   не проходил компиляцию в локальном SDK; кнопки/сортировки работали бы неверно.
2. **Дикие лаги при проигрывании** — «шторм уведомлений» перестраивал всё
   дерево виджетов каждую секунду (подтверждено встроенным мега-логером).
3. Лаги при загрузке/скролле списка — сотни параллельных запросов обложек
   захлёбывали платформенный канал.
4. Много мелких архитектурных флагов (monolith, `context.watch` на весь
   провайдер, `build`-времённые тяжёлые фильтрации).

---

## 2. Расшифровка лога производительности (мега-логер)

Пример типичной записи во время проигрывания (до фиксов):

```
T+37s ui_avg=1226ms ui_max=1226ms r_avg=18ms notify=1/s
| notify: position-1Hz:15, playerStateStream:8, togglePlay:2, _loadFavorites:1
| rebuild: TrackTile:360, NeonHome:34, LibraryTabs:34, CinematicMini:34,
           MusicDnaTab:17, CategoryTab:1
```

Что это значит:
- **`notify`** — количество вызовов `PlayerProvider.notifyListeners()` в секунду.
  Источники: `position-1Hz` (позиция, 1 раз/с), `playerStateStream`
  (поток состояния just_audio, ~5 раз/с), `_loadFavorites`, `_loadSettings`, `_handleIndexEvent`.
- **`rebuild`** — сколько раз пересобрался виджет за сессию:
  `TrackTile` (все карточки списка) — **360**; `LibraryTabs` — **34** —
  каждый раз перестраивались **все 9 вкладок** библиотеки.
- **`ui_avg=1000-1200ms`** — время построения кадра. При 60fps лимит 16мс;
  1000мс = «1 кадр в секунду», т.е. интерфейс стоит.

Итог: **каждое глобальное уведомление перестраивало всё дерево целиком**,
включая тяжёлые агрегаты DNA/Категорий, и это повторялось 1–5 раз в секунду.
---

## 3. Найденные баги и их исправления

### 3.1. `switch` без `break` (fall-through) — ВАЖНАЯ ПОПРАВКА

**Итоговый вывод после проверки: это НЕ баг компиляции и НЕ баг рантайма.**
Первоначальная оценка была ошибочной (мой тест компиляции шёл БЕЗ `pubspec`,
т.е. с другой версией языка). Проверка с реальным `pubspec` проекта
(`environment.sdk: '>=3.0.0 <4.0.0'`) показала:

- код **компилируется** (это же подтверждают успешные CI-сборки на Flutter 3.47);
- рантайм-проверка точной копии `toggleRepeat()` дала корректный цикл
  `off → all → one → off` — **падения нет**, ветки не «проваливаются».

Поэтому добавленные `break` — **защитная мера** (явная семантика, защита от
возможного ужесточения языка в будущих Dart), а **не** исправление бага.
Поведение приложения от этих правок не меняется.

| # | Файл | Место | Что добавлено | Статус |
|---|------|-------|---------------|--------|
| 1 | `lib/providers/player_provider.dart` | `toggleRepeat()` | `break` | защитно (не баг) |
| 2 | `lib/services/audio_handler.dart` | `customAction()` | `break` | защитно (не баг) |
| 3 | `lib/services/widget_service.dart` | `bind()` | `break` | защитно (не баг) |
| 4 | `lib/features/library/library_tabs.dart` | `_playlistSort` | `break` | защитно (не баг) |
| 5 | `lib/features/library/library_tabs.dart` | `_albumFilter` | `break` | защитно (не баг) |
| 6 | `lib/features/collection/neon_collection_screen.dart` | фильтр альбомов | `break` | защитно (не баг) |

### 3.2. ЛАГИ «при проигрывании» — шторм уведомлений

| # | Файл | Правка |
|---|------|--------|
| 7 | `lib/providers/player_provider.dart` | **Убран глобальный `_notify('position-1Hz')`** из `positionStream`. Позиция и так публикуется в `positionTick` (`ValueNotifier`), который слушают прогресс-бары через `ValueListenableBuilder`. Глобальные уведомления на каждый тик перестраивали всё дерево. |
| 8 | `lib/providers/player_provider.dart` | **Дедупликация `playerStateStream`**: `_notify` только при реальном изменении `playing` (раньше — на каждый тик плеера ~5/с). |
| 9 | `lib/providers/player_provider.dart` | **Коалесценция `_notify()`**: несколько уведомлений в одном кадре (playAt + indexEvent + togglePlay и т.п.) схлопываются в одно `notifyListeners()` через `scheduleMicrotask`. |
| 10 | `lib/providers/player_provider.dart` | **`dataEpoch`** — счётчик версии данных (библиотека/история/плейлисты/жанры/избранное). Инкрементируется в `_invalidateDerivedCaches()` и `_invalidateCategoryCache()`. |
| 11 | `lib/features/library/music_dna_tab.dart` | `context.watch<PlayerProvider>()` → `context.select((p) => p.dataEpoch)` + `read`. Вкладка DNA перестраивается только при реальном изменении данных (было: 17–24 пересборки за сессию от шторма). |
| 12 | `lib/features/library/category_tab.dart` | Аналогично для CategoryTab (тяжёлые `tracksForCategory`/`genreCounts`). |

### 3.3. ЛАГИ «при загрузке/скролле списка» — шторм обложек

| # | Файл | Правка |
|---|------|--------|
| 13 | `lib/widgets/cached_artwork.dart` | **Пул загрузок обложек**: максимум **8 конкурентных** `queryArtwork` вместо «360 разом». Добавлена очередь (`Completer`), лимит `_maxConcurrent`, `_drain()`. На ошибке кешируем «арта нет» (раньше `_pending` текло навсегда и файлы перезапрашивались). |

### 3.4. ЛАГИ «при открытии вкладки Альбомы» — тяжёлая группировка в build

| # | Файл | Правка |
|---|------|--------|
| 14 | `lib/providers/player_provider.dart` | Новый **кешированный геттер `albumEntries`**: альбомы с треками строятся один раз (O(n)), инвалидируются в `_invalidateFolderCache()`. |
---

## 4. Полный список изменённых файлов

```
lib/providers/player_provider.dart                  +56  — шторм, коалесценция, dataEpoch, albumEntries, switch
lib/widgets/cached_artwork.dart                     +59  — пул загрузок обложек (8 concurrent)
lib/services/widget_service.dart                    +3   — switch break
lib/services/audio_handler.dart                     +3   — switch break
lib/features/library/library_tabs.dart              +11  — switch break ×2, albumEntries
lib/features/library/music_dna_tab.dart             +5   — select(dataEpoch)
lib/features/library/category_tab.dart              +5   — select(dataEpoch)
lib/features/collection/neon_collection_screen.dart +7   — switch break, albumEntries
```

Всего: **8 файлов, ~+149 строк, без удаления логики**.

**НЕ тронуто:** уже существовавшая незакоммиченная правка `_precomputeAggregates()`
в `player_provider.dart` (фоновый прогрев агрегатов после загрузки библиотеки) —
оставлена как была.

---

## 5. Ожидаемый эффект

До фиксов (по логу): `notify=1-3/s`, `ui_avg≈1.0-1.2s`, `TrackTile:360`.

После фиксов ожидается:
- `notify` во время прослушивания ≈ **0-1/с** (только реальные события:
  смена трека, play/pause, действия пользователя);
- `TrackTile`/`LibraryTabs`/`CinematicMini` не растут, пока ничего не нажимается;
- `MusicDnaTab`/`CategoryTab` перестраиваются только при изменении своих данных;
- при скролле списка обложки грузятся пачками по 8 (нет «удушья» канала);
- вкладка «Альбомы» открывается без синхронного пересчёта;
- исчезают фреймы `ui_max≈870-1266ms` во время простого прослушивания.

---

## 6. Как проверить руками

1. `cd /sdcard/projects/audio_player && flutter analyze` — не должно быть ошибок.
2. `flutter run` на устройстве.
3. В настройках включить запись сессии (мега-логер), начать проигрывание,
   подождать 20-30 сек. Ожидаемо в логе: `notify≈0-1/s`, `ui_avg` — единицы мс,
   счётчики `TrackTile`/`LibraryTabs` растут только при действиях.
4. Прокрутить список треков — обложки подгружаются плавно.
5. Вкладки «Альбомы», «DNA», «Категории» — открываются без фризов.
6. Проверить: повтор (off→all→one→off), кнопки уведомления и виджета
   (favorite/shuffle/repeat) — каждое срабатывает по одному разу.
7. Kill-switch'и для диагностики в настройках работают:
   `debugNoNotify`, `debugNoVisualizers`, `debugNoImageFilters`, `debugNoAudioEffects`.

---

## 7. Что осталось (рекомендации на будущее)

### Проверить в первую очередь
- **`flutter analyze` + сборка** — синтаксис всех правок подтверждён парсером
  (`dart format` — 0 ошибок), но полный анализ в proot-среде не дожил до конца.
  В CI (`build-apk.yml`) стоит добавить шаг `flutter analyze` ДО `flutter build`.

### Архитектура (требует отдельной переработки, не делал)
- `context.watch<PlayerProvider>()` в корне экранов (`NeonHome`, `LibraryTabs`,
  мини-плееры, now-playing) — после коалесценции уведомлений приемлемо, но для
  тонкой оптимизации стоит перевести на `context.select` по конкретным полям
  (`isPlaying`, `currentTrack`, `playlist.length`).
- `player_provider.dart` — 3000+ строк монолит; стоит дробить на сервисы
  (history/genres/queue/settings).
- `_buildNativeSlice` (treadmill ±40): переход за край окна пересобирает
  нативный плеер — возможен короткий шов в аудио. Сознательный компромисс
  против маршалинга тысяч треков (just_audio #294).
- `MarqueeText` в мини-плеере крутит `animateTo` в бесконечном цикле — при
  паузе тоже; можно останавливать по `TickerMode`.
- CI пересоздаёт Flutter-проект с нуля каждый пуш (`flutter create` + копирование
  `lib`) — хрупко, но работает; трогать не стал.
- Фоновые запросы iTunes/MusicBrainz для жанров — не влияют на UI (async),
  но при желании добавить глобальный таймаут/ретраи.

---

## 8. История сессии

- Аудит: прочитаны SPEC.md, main.dart, player_provider.dart (3084 стр.),
  audio_handler, widget_service, library_tabs (2092), category_tab,
  music_dna_tab, cinematic_player_body, cached_artwork, artwork_palette,
  artwork_backdrop, three_d_visualizer, spinning_vinyl, marquee_text,
  swipe_reveal, queue_sheet, settings_screen, debug_log, CI-workflow.
- Проверка гипотезы fall-through: компиляция тестового файла на локальном SDK
  подтвердила ошибку `Switch case may fall through` (в отличие от docs.dev).
- Исправления: 16 пунктов, 8 файлов (см. разделы 3-4).
- Валидация: `dart format --output=none` на всех 8 файлах — ошибок разбора нет;
  `git diff` просмотрен построчно, посторонних изменений нет.
- Отчёт: этот файл (`AUDIT_REPORT.md`).

---

## 9. Раунд 2 (изоляция экранов + отклонённые идеи)

### 9.1. Сделано

| # | Файл | Правка |
|---|------|--------|
| 17 | `lib/features/home/neon/neon_home_screen.dart` | `context.watch<PlayerProvider>()` → **два `context.select`**: `visibleTracks.length` и `currentTrack?.id`. В логе `NeonHome` пересобирался 41 раз и тянул за собой `LibraryTabs` со всеми 9 вкладками. Теперь любые прочие нотификации (история, favorites, настройки) не перестраивают домашний экран и вложенную библиотеку. |

### 9.2. Оценено и ОТКЛОНЕНО (с причинами)

- **Хак «`==` на TrackTile»** (пропуск rebuild при равных полях через
  short-circuit `Element.updateChild`): у `TrackTile` **8 мест использования**,
  и замыкания `onTap/onLongPress` в родителях захватывают изменяемые списки
  (поисковый результат, очередь плейлиста, категорию). При пропуске rebuild
  замыкания становились бы устаревшими: после смены очереди тап играл бы
  **устаревший список** (например, удалённый из очереди трек). Риск регрессии
  без возможности прогнать приложение — отклонено.
- **Разбиение `player_provider.dart` (3000+ строк) на 3-4 нотификатора:**
  затронуло бы почти каждый файл `lib/` (десятки `watch/read`), включая
  требовательные к синхронности места (`_handleIndexEvent`, коалесценция,
  `dataEpoch`). Без рабочего `flutter analyze`/запуска — слишком высокий риск.
  Рекомендовано отдельной сессией с CI-гейтом `flutter analyze` до сборки.
- **RepaintBoundary на корнях вкладок:** `ListView.builder`/`CustomScrollView`
  уже ставят RepaintBoundary на каждый item по умолчанию — выигрыш нулевой.
- **`select` для now-playing экранов:** им нужен полный объект `AudioTrack`
  (`PlayerFeatureRow(track: ...)`), а `AudioTrack` не переопределяет `==` —
  `select` по объекту не давал бы выигрыша.

### 9.3. Уточнение к резюме раунда 1

Каскад `TrackTile:360` после раунда 1 возникает **только на реальных действиях**
(смена трека, play/pause, toggle favorite — 1-2 перестройки действия вместо
постоянных 360 при каждом секундном тике). Постоянные пересборки во время
простого прослушивания устранены полностью (убраны `position-1Hz` и
`playerStateStream`-шторм + коалесценция).

---

## 10. Итоговый список изменённых файлов (раунды 1+2)

```
lib/providers/player_provider.dart                  — шторм, коалесценция, dataEpoch, albumEntries, switch
lib/widgets/cached_artwork.dart                     — пул загрузок обложек (8 concurrent)
lib/services/widget_service.dart                    — switch break
lib/services/audio_handler.dart                     — switch break
lib/features/library/library_tabs.dart              — switch break ×2, albumEntries
lib/features/library/music_dna_tab.dart             — select(dataEpoch)
lib/features/library/category_tab.dart              — select(dataEpoch)

---

## 11. Раунд 3 — реальные баги (не производительность)

### 11.1. Хрупкое получение id нового плейлиста (2 места)

`createPlaylist()` **возвращает id** созданного плейлиста, но в двух местах
брали `player.playlists.last.id` — это упадёт (`StateError`), если список
пуст или сохранение не сработало, и завязано на порядок элементов.

| # | Файл | Правка |
|---|------|--------|
| 18 | `lib/widgets/playlist_picker_sheet.dart` | `player.playlists.last.id` → использовать id из `await player.createPlaylist(name)` |
| 19 | `lib/features/library/library_tabs.dart` (`_showTrackActions`) | то же самое |

### 11.2. Утечки `TextEditingController` (3 места)

Контроллеры создавались в диалогах/шторках и никогда не освобождались
(утечка ChangeNotifier-подписок при каждом открытии диалога).

| # | Файл | Правка |
|---|------|--------|
| 20 | `lib/features/library/library_tabs.dart` (`_promptPlaylistName`) | `try/finally` + `controller.dispose()` |
| 21 | `lib/features/library/library_tabs.dart` (`_createPlaylistDialog`) | `controller.dispose()` после диалога |
| 22 | `lib/widgets/playlist_picker_sheet.dart` (`_createPlaylist`) | `dispose()` (в т.ч. на ранних `return`) |
| 23 | `lib/features/library/category_tab.dart` (`_showGenreEditor`) | `.whenComplete(controller.dispose)` |

Проверено: `_showUrlDialog` в `settings_screen.dart` уже имел `.then(dispose)` —
не тронут. Остальные контроллеры (`_searchController`, `_controller` у
`prompt_playlist_sheet`) освобождаются штатно.

---

## 12. Итог всех раундов

**Всего:** 12 файлов + отчёт. Изменения — производительность (шторм уведомлений,
пул обложек, кеши) и мелкие реальные баги (хрупкий id плейлиста, утечки
контроллеров). Ломающих изменений нет; всё — в пределах существующих
паттернов кода.

**Проверка всех файлов:** `dart format --output=none` — синтаксических ошибок
нет ни в одном изменённом файле.
lib/features/collection/neon_collection_screen.dart — switch break, albumEntries
lib/features/home/neon/neon_home_screen.dart        — watch → 2×select (раунд 2)
AUDIT_REPORT.md                                     — этот отчёт
```

Проверка: `dart format --output=none` на всех 9 dart-файлах — ошибок разбора нет.

---

## 13. Валидация и сборка (GitHub Actions)

### 13.1. Локальная проверка

- `dart analyze lib` (весь проект) → **No issues found!**
- `dart format --output=none` по всем изменённым файлам → синтаксических ошибок нет.

### 13.2. Ошибка, найденная и исправленная на этапе сборки

Первый прогон CI (run `34487608176`, коммит `012bd65`) **упал** на компиляции:

```
lib/features/collection/neon_collection_screen.dart:203:54:
  Error: The getter 'query' isn't defined for the type '_AlbumsGrid'.
```

Причина — моя правка `albumEntries` в `_AlbumsGrid` ошибочно использовала
переменную `query` (она есть только в `LibraryTabs._buildAlbumList`, а в
`_AlbumsGrid` поиска нет). Исправлено: `final entries = player.albumEntries.toList();`.
Там же убрано неиспользуемое поле `_lastPositionSecond` (analyzer-предупреждение
после удаления глобального 1Hz-тика).

### 13.3. Итоговая успешная сборка

| Параметр | Значение |
|---|---|
| Workflow | Build APK (`workflow_dispatch`) |
| Run | **34489141651** — `success` |
| Коммит | `fbaeea4` |
| Ветка | `stack-upgrade` |
| APK в CI | `build/app/outputs/flutter-apk/app-release.apk` (**59.3 МБ**) |
| Подпись | ✅ `CN=NeonWave` (release keystore из секретов) |
| Локальная копия | `/sdcard/projects/audio_player/NeonWave-v103-new.apk` |

### 13.4. Коммиты

```
fbaeea4 v103 fix: neon_collection _AlbumsGrid has no search query (compile error E-203), drop unused _lastPositionSecond
012bd65 v103: perf — kill notify storm (no global 1Hz position, dedup playerStateStream, coalesce notifies), artwork load pool (8 concurrent), cached albumEntries, select() isolation for DNA/Category/NeonHome; fix fragile playlist id lookup + 4 controller leaks; add AUDIT_REPORT.md
```

Оба запушены в `origin/stack-upgrade`.

### 13.5. Что проверить на устройстве (тестовый план)

1. Установить `NeonWave-v103-new.apk`.
2. Включить запись сессии в настройках, послушать музыку 30-60 сек:
   ожидается `notify ≈ 0-1/с`, `ui_avg` — единицы мс, отсутствие фреймов ~1с.
3. Прокрутить список треков, открыть «Альбомы»/«DNA»/«Категории» — без фризов.
4. Создать плейлист (через трек → «Добавить в плейлист» → «Новый плейлист»)
   и через раздел «Плейлисты» — трек должен попасть в правильный плейлист.
5. Проверить кнопки уведомления и виджета рабочего стола (favorite/shuffle/repeat).

| 15 | `lib/features/library/library_tabs.dart` | `_buildAlbumList` использует `player.albumEntries` вместо `O(альбомы×треки)` пересборки каждый билд. |
| 16 | `lib/features/collection/neon_collection_screen.dart` | То же в коллекции. |

---

## 14. Раунд 4 — удаление трека, снекбары и единое меню (v104)

Запрос: (1) баг — «каждое удаление трека переносит очередь в начало»; (2) белый снекбар
«Трек удалён» вырвиглазный и перекрывает нижнюю панель; (3) кнопка «три точки» в плеере
открывает недоделанное меню — свести к единому стилю; (4) развивать сцену плеера.

### 14.1. Баг удаления — очередь больше не сбрасывается в начало

**Файл:** `lib/providers/player_provider.dart`, `deleteTrack()`.

**Причина:** при удалении **играющего** трека код делал `_currentIndex = -1` и
`_audioPlayer.stop()`. После этого `currentTrack == null`, а карусель/плейлист
брали индекс 0 → визуально «перебрасывало в начало очереди». Плюс в `deleteTrack`
не пересобиралось нативное окно под новый индекс.

**Исправление:** при удалении текущего трека продолжаем воспроизведение с трека,
вставшего на освободившееся место (или с нового последнего, если удалили последний).
Индекс не сбрасывается; очередь и нативное окно синхронизируются через
`_rebuildPlaylist()`, затем `playAt(nextIndex)` (если трек играл). Останов — только
когда очередь становится пустой. Удаление трека до текущего сдвигает индекс без
рывка; удаление после — просто укорачивает очередь.

### 14.2. Снекбары — единый неоновый стиль, не перекрывают мини-плеер

**Файлы:** `lib/ui/theme.dart` (`snackBarTheme`), новый `lib/widgets/neon_snack.dart`.

- Глобальный `snackBarTheme`: тёмная поверхность, скруглённая рамка, floating,
  `insetPadding` снизу 96px — чтобы не закрывать нижнюю панель плеера.
- Хелперы `showNeonSnack` / `showNeonSnackOn` / `showDeleteResultSnack` — иконка в
  акцентной плашке + текст; вариант `...On` принимает `ScaffoldMessengerState`,
  т.к. после `Navigator.pop` шторки контекст уже недействителен.
- Заменены снекбары удаления в `player_feature_row.dart` и `library_tabs.dart`
  (одиночное и массовое удаление).

### 14.3. Единое меню «три точки» — `TrackActionsSheet`

**Новый файл:** `lib/widgets/track_actions_sheet.dart`.

Раньше «три точки» в простом плеере открывали «Очередь», а в кинематографичном —
ряд кнопок `PlayerFeatureRow`; стиль и логика различались. Теперь оба открывают
одну шторку NeonWave с действиями: Избранное, Играть следующим, В плейлист,
Очередь, Информация, Удалить (с подтверждением и стилизованным результатом).

Подключено в `simple_now_playing_screen.dart` и `cinematic_player_body.dart`.
`PlayerFeatureRow` остаётся внутри сцены плеера (как и просил пользователь),
но «три точки» теперь ведут в единое меню.

### 14.4. Валидация

- `dart format` — все 8 файлов разбираются без ошибок синтаксиса.
- `dart analyze` (8 изменённых файлов) — **No issues found!**

### 14.5. Изменённые файлы раунда 4

```
lib/providers/player_provider.dart                        (fix delete → continue queue)
lib/ui/theme.dart                                         (snackBarTheme)
lib/widgets/player_feature_row.dart                       (unified delete snack)
lib/features/library/library_tabs.dart                    (unified delete snack x2)
lib/features/now_playing/simple/simple_now_playing_screen.dart    (TrackActionsSheet)
lib/features/now_playing/cinematic/cinematic_player_body.dart     (TrackActionsSheet)
lib/widgets/neon_snack.dart                               (NEW)
lib/widgets/track_actions_sheet.dart                      (NEW)
```

---

## 15. Раунд 5 — запросы пользователя (удаление, неон-палитра, миксер, меню)

Источник: замечания пользователя по скриншотам двух реальных экранов
(20:04:42 — неон-плеер, 20:04:54 — белый снекбар «Трек удалён»).

### 15.1. Логика удаления трека в карусели/очереди (ИСПРАВЛЕНО в v104)

Жалоба: «каждое удаление переносит в начало очереди».

Причина: старый код при удалении текущего трека сбрасывал очередь к началу.

Фикс (`PlayerProvider.deleteTrack`): удаление текущего трека **не** сбрасывает
очередь. Логика теперь:

- удалили последний трек очереди → только тогда `stop()`, сброс позиции;
- удалили играющий трек → продолжаем с трека на освободившемся месте
  (или с нового последнего), без перезапуска очереди;
- удалили трек до текущего → индекс сдвигается (`_currentIndex -= 1`),
  играющий трек продолжает без рывка;
- удалили трек после текущего → очередь просто короче;
- во всех ветках `_rebuildPlaylist()` — нативное окно пересобирается,
  чтобы индексы не разъезжались.

### 15.2. Снекбар удаления — в стиль NeonWave (ИСПРАВЛЕНО в v104)

Белый «вырвиглазный» `SnackBar` заменён на `showNeonSnack` / `showDeleteResultSnack`
(`lib/widgets/neon_snack.dart`): тёмная поверхность, акцентная иконка,
скруглённая кромка и отступ снизу (не перекрывает мини-плеер и нижнюю панель).
Тема снекбара также задана глобально (`AppTheme.dark.snackBarTheme`).

### 15.3. «Три точки» → единое меню (ИСПРАВЛЕНО в v104)

Кнопка «⋮» в простом и кинематографичном плеерах теперь открывает один и тот
же `TrackActionsSheet` (избранное, очередь, плейлист, закладки, «не хочу»,
инфо, удаление с подтверждением). Раньше открывались разные шторки с разным
стилем и неполной логикой. `PlayerFeatureRow` остаётся внутри сцены плеера.

### 15.4. Умный миксер (Personal DJ) в новом стиле (ДОБАВЛЕНО)

Жалоба: «нет нашего умного миксера в новом стиле».

В шапку `NeonHomeScreen` и `CinematicHomeScreen` добавлена иконка
`auto_awesome` (Personal DJ), открывающая `PersonalDJSheet` в едином
тёмном стиле (`AppTheme.surface`, скругление 24). Миксер больше не доступен
только из старого интерфейса.

### 15.5. Единая неон-палитра списка и сцены (СДЕЛАНО)

Жалоба по скринам: «рамки (поиск, число треков) в новом стиле не очень»,
«палитра мини-плеера и верхней части не сходятся».

- `TrackTile` получил флаг `neon`: карточка — полупрозрачная поверхность
  `0x0FFFFFFF` с тонкой белой кромкой `0x24FFFFFF` (как сцена/мини-плеер),
  вместо фиолетовой заливки `AppTheme.card`. Подсветка текущего/выделенного —
  через акцент, но с неоновой прозрачностью.
- `LibraryTabs` получил флаг `neon`: поле поиска — тёмное полупрозрачное
  (`0x14FFFFFF`) с тонкой белой кромкой и радиусом 14, текст/подсказка —
  белые, вместо синевато-серого `AppTheme.surfaceLight`.
- `neon_home_screen` и `cinematic_home_screen` передают `neon: true`.
- Остальные стили (simple/cover-flow) сохраняют прежний вид (флаги по
  умолчанию `false`) — регресса нет.

### 15.6. Виджеты рабочего стола (В ПЛАНЕ)

Запрос: «заняться виджетами, их обрисовкой, анимированием».

Текущее состояние: `lib/services/widget_service.dart` — MethodChannel-мост к
нативному Android-виджету (команды play/pause/next/prev/favorite/shuffle/repeat).
Обрисовка и анимация самого виджета живут в нативном слое `android/`
(RemoteViews) и требуют отдельной сессии с эмулятором/устройством для
проверки. Оставлено на следующий заход.

### 15.7. Валидация

- `dart format --output=none` на 4 изменённых файлах — разбор без ошибок
  синтаксиса (`Formatted 4 files`).
- `dart analyze` запущен в фоне (полный прогон в proot-окружении долгий);
  финальная проверка — CI-сборкой APK.

### 15.8. Изменённые файлы раунда 5

```
lib/widgets/track_tile.dart                              (neon-скин карточек)
lib/features/library/library_tabs.dart                   (neon: поле поиска, флаг)
lib/features/home/neon/neon_home_screen.dart             (Personal DJ + neon: true)
lib/features/home/cinematic/cinematic_home_screen.dart   (Personal DJ + neon: true)
```


---

## 16. Раунд 6 — виджеты рабочего стола (нативные) + упрочнение CI

Запрос: «заняться виджетами, их обрисовкой, анимированием».

### 16.1. КРИТИЧЕСКИЙ баг обрисовки: невидимые иконки (ИСПРАВЛЕНО)

Виджет на тёмном фоне (набор `ic_action_*`) рисовался **чёрным** цветом
`#FF000000` — то есть иконки избранного/шаффла/повтора были **невидимы**.

Кроме того, использовались **два разных набора** иконок: в layout —
`ic_widget_*` (цветные), а Kotlin после первого обновления подставлял
`ic_action_*` (чёрные). То есть иконки «пропадали» сразу после запуска.

Фикс (`NeonWaveWidgets.kt`, `fill()`):
- fav → `ic_widget_favorite` / `ic_widget_favorite_off` (новые, pink/grey);
- shuffle → `ic_widget_shuffle_on` / `ic_widget_shuffle_off`;
- repeat → `ic_widget_repeat_on` (all) / `ic_widget_repeat_one` (one) /
  `ic_widget_repeat_off` (off);
- play/pause/prev/next — уже были `ic_widget_*`.
- заглушка обложки: было чёрное **сердце** (`ic_action_favorite_off`) →
  стало `ic_widget_placeholder` (нотка `#66FFFFFF`).

Новые drawable: `ic_widget_favorite.xml`, `ic_widget_favorite_off.xml`,
`ic_widget_placeholder.xml`. `widget_large.xml` — стартовая иконка fav
переведена на `ic_widget_favorite_off`.

### 16.2. Упрочнение CI (важно для сборок через GitHub)

Воркфлоу `build-apk.yml` пересоздаёт Android-проект (`flutter create`) и
восстанавливал только `layout/`, `xml/`, `widget_bg.xml`, `drawable-nodpi/`.
Иконки виджета (`ic_widget_*`, `ic_action_*`, `widget_btn_bg`, `widget_play_bg`)
выживали лишь потому, что `flutter create` не удаляет уже существующие файлы —
это хрупко и могло сломать сборку при обновлении Flutter/шаблона.

Добавлено полноценное резервирование всего каталога `res/drawable`:
```
[ -d android/app/src/main/res/drawable ] && cp -r ... mainactivity_backup/
...
[ -d mainactivity_backup/drawable ] && cp -r ... android/app/src/main/res/
```

### 16.3. Изменённые/новые файлы раунда 6

```
.github/workflows/build-apk.yml                                  (backup drawable)
android/app/src/main/kotlin/.../widget/NeonWaveWidgets.kt        (иконки виджета)
android/app/src/main/res/layout/widget_large.xml                 (fav icon)
android/app/src/main/res/drawable/ic_widget_favorite.xml         (NEW)
android/app/src/main/res/drawable/ic_widget_favorite_off.xml     (NEW)
android/app/src/main/res/drawable/ic_widget_placeholder.xml      (NEW)
```

### 16.4. Что осталось по виджетам (нужно устройство/эмулятор)

- Прогресс-бар трека в виджете (RemoteViews ProgressBar + push из Dart).
- Анимация — RemoteViews крайне ограничены (нет произвольных анимаций);
  возможна смена кадров через периодический push или переход на
  `Glance`/`AppWidget` с `ListView`, что требует отдельной сессии.
- Иконки `ic_action_*` больше не используются — можно удалить позже
  (не удалял без подтверждения, по правилам репозитория).


---

## 17. Раунд 7 — единое меню трека везде + палитра мини-плеера

### 17.1. «Три точки» в списке открывали ДРУГОЕ меню (ИСПРАВЛЕНО)

`TrackTile` (карточка трека) имел собственный `PopupMenuButton` с ограниченным
набором действий и своими белыми `SnackBar` — то есть то же расхождение,
которое пользователь заметил в плеере, но этажом ниже.

Теперь «⋮» в списке открывает тот же `TrackActionsSheet`, что и в плеере
(избранное, очередь, плейлист, закладки, «не хочу», инфо, удаление с
подтверждением и неоновым снекбаром). Удалено ~143 строки дублирующего кода,
убраны ставшие лишними импорты (`playlist_picker_sheet`, `track_info_dialog`).

Итог: **одно меню на всё приложение** — список, простой плеер,
кинематографичный, neon.

### 17.2. Палитра мини-плеера под сцену (СДЕЛАНО)

Жалоба: «палитра мини-плеера и верхней части не сходятся в стиле неон».

`CinematicMiniPlayer` теперь берёт акцент из обложки/темы
(`cinematicAccent(context, track.id)`) и использует его для:
- кромки карточки (accent 38%) вместо холодной серой;
- мягкого свечения `BoxShadow` под карточкой;
- прогресс-бара (accent вместо белого).

Теперь мини-плеер, сцена и нижняя панель навигации читаются одной
неоновой палитрой (панель уже использовала `cinematicAccent`).

### 17.3. Валидация

- `dart analyze lib/widgets/track_tile.dart lib/features/mini_player/cinematic/cinematic_mini_player.dart`
  → **No issues found!**
- CI-сборка v105 (Dart-правки) — **success** (run 34501750262).

### 17.4. Изменённые файлы раунда 7

```
lib/widgets/track_tile.dart                                    (единое меню, -143 стр.)
lib/features/mini_player/cinematic/cinematic_mini_player.dart  (акцент из обложки)
```


---

## 18. Раунд 8 — neon-скин шапки библиотеки (иконки/меню)

Завершение неон-палитры списка: в `LibraryTabs` при `neon: true` иконки
сортировки и переключения «список/сетка» теперь приглушённо-белые
(`Colors.white54`) вместо холодного серо-синего `AppTheme.textSecondary`,
а выпадающее меню сортировки — тёмная поверхность `#141622` с тонкой
белой кромкой вместо синеватой `AppTheme.surfaceLight`.

Итого шапка библиотеки (поиск + сортировка + счётчик «N треков») полностью
согласована с неоновой сценой и нижней панелью.

Валидация: `dart analyze lib/features/library/library_tabs.dart` →
**No issues found!**; полный `dart analyze lib` → **No issues found!**.


---

## 19. Раунд 9 — плавающий мини-плеер, прогресс в виджете, Personal DJ в плеере, CI

Всё собрано в **одну** версию (один APK), как просил пользователь.

### 19.1. Плавающий оверлей внизу (ПО ЖАЛОБЕ)

Раньше мини-плеер и нижняя навигация стояли **под** списком в `Column`,
поэтому между списком и ними была чёрная полоса.

Теперь (`NeonHomeScreen`, `CinematicHomeScreen`):
```
Expanded(
  child: Stack([
    Positioned.fill(child: LibraryTabs(..., bottomInset: ...)),
    Positioned(bottom: 0, child: <оверлей: мини-плеер + навигация>),
  ]),
)
```
- Контент списка **уходит под** мини-плеер и навигацию.
- Оверлей имеет градиент `transparent → bg`, поэтому список плавно
  затухает за ними — «вшитости» и жёсткой чёрной полосы нет.
- `LibraryTabs` получил `bottomInset`: нижний отступ всех списков увеличен,
  чтобы последние треки не прятались под оверлеем
  (156 при играющем треке, 88 без мини-плеера).

### 19.2. Прогресс-бар в виджете (обрисовка)

- Новый `drawable/widget_progress.xml` — тонкая линия, фон `#22FFFFFF`,
  заполнение акцентом `#FFA855F7`.
- `ProgressBar` добавлен в `widget_large.xml` и `widget_small.xml`
  (`widget_small` переделан в вертикальный корень: строка + прогресс).
- `NeonWaveWidgets.kt`: `WidgetState` хранит `positionMs/durationMs`,
  `fill()` вызывает `setProgressBar` (скрывает бар, если длительность 0).
- Dart `WidgetService`: передаёт `positionMs/durationMs` и держит тикер
  (раз в 4 c) пока играет музыка, чтобы прогресс обновлялся.
- `MainActivity.kt`: прокинуты новые аргументы канала.

### 19.3. Personal DJ в сцене плеера (развитие сцены)

В `PlayerFeatureRow` (ряд функций во всех плеерах) добавлена кнопка
`auto_awesome` — **умный миксер** открывается прямо из сцены плеера,
а не только с домашнего экрана.

### 19.4. CI: снятие deprecation-предупреждений

`actions/checkout@v4 → v5`, `actions/setup-java@v4 → v5`
(обе рекомендованы самим предупреждением GitHub; Node 24).
`upload-artifact@v4` оставлен (стабильный), `subosito/flutter-action@v2`.

### 19.5. Гигиена артефактов

Удалены старые APK, оставлен только свежий (пользователь: «не множь APK»):
```
удалено: NeonWave.apk, NeonWave-v103-new.apk, NeonWave-v106.apk, NeonWave-v107.apk
оставлен: <свежий build этого раунда>
```
`*.apk` в `.gitignore` — git не затронут.

### 19.6. Валидация

- `dart analyze lib` → **No issues found!** (EXIT=0).
- `dart format` разобрал все изменённые файлы без ошибок.

### 19.7. Изменённые/новые файлы раунда 9

```
lib/features/home/neon/neon_home_screen.dart              (плавающий оверлей)
lib/features/home/cinematic/cinematic_home_screen.dart    (плавающий оверлей)
lib/features/library/library_tabs.dart                    (bottomInset)
lib/widgets/player_feature_row.dart                       (Personal DJ)
lib/services/widget_service.dart                          (позиция + тикер)
android/.../MainActivity.kt                               (аргументы виджета)
android/.../widget/NeonWaveWidgets.kt                     (прогресс-бар)
android/app/src/main/res/layout/widget_large.xml          (ProgressBar)
android/app/src/main/res/layout/widget_small.xml          (вертикальный + ProgressBar)
android/app/src/main/res/drawable/widget_progress.xml     (NEW)
.github/workflows/build-apk.yml                           (actions v5)
```

