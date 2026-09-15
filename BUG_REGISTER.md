# NeonWave — Единый реестр находок и работ

Дата: 2026-09-14 · Ветки: `stack-upgrade` = `master` · Последняя версия кода: **v119**

Это **единственный** список багов/задач. Всё, что уже проверено и найдено — здесь,
чтобы не искать заново по коду. Рядом — `FUNCTIONAL_AUDIT.md` (инвентарь функций и стратегия).

Обозначения: `✅` сделано · `⬜` открыто · `⏳` требует проверки на устройстве.
Приоритеты: **C** критично · **H** высоко · **M** средне · **L** низко.

---

## 1. Уже исправлено (не искать повторно)

| ID | Версия | Что было | Файл |
|---|---|---|---|
| **C1** | v94 | `currentIndex`/`currentTrack` возвращали индекс внутри нативного окна без `_nativeOffset` → на очередях >81 играл «не тот» трек (мини-плеер, шторка, виджет, подсветка) | `player_provider.dart` (геттеры) |
| **C2** | v94 | `AndroidManifest.xml` в репо был не тот, что собирал CI: не было `WAKE_LOCK`, `FOREGROUND_SERVICE(_MEDIA_PLAYBACK)`, `POST_NOTIFICATIONS`, `<service AudioService foregroundServiceType="mediaPlayback">` → локальные сборки без фонового воспроизведения | `AndroidManifest.xml`, `build-apk.yml` |
| **H1** | v94 | `Permission.audio` на Android ≤12 всегда denied (вне скоупа: целевая платформа 13+) | `player_provider.dart` |
| **H2** | v94 | Удаление трека «успешно» до подтверждения системного диалога → UI врал при «Отмене» | `MainActivity.kt` (`onActivityResult`) |
| **H3** | v94 | `_switchingSource` без `try/finally` → «залипал», плеер переставал реагировать до перезапуска | `player_provider.dart` |
| **M1** | v94 | `playbackState.add` на каждый тик (~5 Гц) → маршалинг + перерисовка шторки | `audio_handler.dart` (троттл 1 Гц) |
| **M2** | v94 | Полный список id очереди писался в SharedPreferences каждые 5 с | `player_provider.dart` |
| **M3** | v94 | `isFavorite` — линейный поиск по списку избранного (O(n·m) на тап ♥) | `player_provider.dart` (`Set<int>`) |
| **M4** | v94 | `_allTracks.indexWhere` внутри циклов по истории (до ~2 млн сравнений) | `player_provider.dart` (`_tracksById`) |
| **M7** | v94 | Неограниченные кэши обложек (байты + temp-файлы) | `widget_service.dart`, `audio_handler.dart` (LRU 24/40) |
| **P1** | v115 | Свайп-кнопки не подходили под стиль плеера | `swipe_reveal.dart` (стили simple/3D/neon/cinematic) |
| **R1** | v116 | Гонка пересборки окна: два быстрых `next()` → `setAudioSources` завершались не в том порядке → `seek` по чужому offset | `_sliceBuildSeq`, `_playReqSeq` |
| **R2** | v116 | `_extendRadio` без guard → дубли треков при двойном next на конце | `_radioExtending` |
| **L5** | v116 | Skip-счётчик срабатывал на `previous()` (навигация ≠ «не понравилось») | `player_provider.dart` |
| **D1** | v116 | Resume по индексу, а не по track id → «продолжить» могло стартовать чужой трек | `last_track_id` + фолбэк |
| **D2** | v116 | Рост `_skipCount`/букмарок без лимита | caps 800→500, 30/трек, 400 треков |
| **S1** | v117 | **ANR при перемотке**: `Slider.onChanged` → `seek()` на каждый пиксель → `positionStream` → `positionTick` → ребилд → `onChanged` → бесконечная петля, переполнение платформенного канала | все 4 экрана → `SeekSlider` (`lib/widgets/seek_slider.dart`) |
| **N0** | v118 | «В очередь» перезапускала играющий трек (`_rebuildPlaylist` → `setAudioSources`) | `insertAudioSource(s)` вместо пересборки |
| **N1** | v118 | `_nativeLength` не обновлялся после вставки → на коротких очередях лишний `setAudioSources` (рестарт текущего трека) | `_nativeLength += tracks.length` |
| **N2** | v118 | Шторка/локскрин/виджет не узнавали о вставке в очередь | `_audioHandler?.setQueue(_playlist)` |
| **N3** | v118 | Пакетное «в очередь» **разворачивало порядок** альбома (цикл `insert(cur+1, …)`) | `addManyToQueueNext(List)` |
| **S2** | v119 | **Кнопки свайпа не нажимались** («В очередь»/«Избранное»/«Скрыть»): полоса лежала ПОД тайлом, а у тайла `GestureDetector(behavior: opaque)` на всю ширину; `Transform.translate` двигает только отрисовку → тап доставался `_toggleClose` | `swipe_reveal.dart` (полоса перенесена ПОВЕРХ, выезжает через `Transform.translate`) |

Дополнительно (v117): умные автоплейлисты («Топ недели», «Свежее», «Часто пропускаемые», «Неизведанное»), импорт M3U/M3U8, `schema_version=2`.

### v122 — пакет «аудио»

| ID | Что сделано | Файл |
|---|---|---|
| **B1** | Настоящий shuffle: порядок — перестановка Фишера–Йетса (`_shuffleOrder`/`_shufflePos`), раунд проигрывается целиком, повторов нет; `previous()` идёт по порядку раунда. Было: случайный индекс по модулю времени | `player_provider.dart` |
| **B2** | Repeat-one нативно: `setLoopMode(LoopMode.one)` (раньше — ручной `seek` уже ПОСЛЕ старта следующего трека, слышен хвост). Ручной путь оставлен фолбэком (`_nativeLoopOne`) | `player_provider.dart` |
| **B4** | Визуализатор глушится при уходе с экрана: `AudioVisualizer.acquire()/release()` (счётчик потребителей), `stop()` сбрасывает `_requested` и уровни; отказ в разрешении больше не «защёлкивает» поток | `audio_visualizer.dart`, `live_equalizer.dart` |
| **F6** | EQ/X-Boost пере-применяются после звонка (конец interruption) и смены устройства вывода; гейт `_lastEqApplied` сбрасывается | `player_provider.dart` |

### v123 — перф/логика

| ID | Что сделано | Файл |
|---|---|---|
| **B10** | Поиск с debounce 200 мс (`Timer` + отмена в `dispose` и на «очистить») — раньше каждый символ прогонял всю библиотеку ×3 `toLowerCase()` | `library_tabs.dart` |
| **B23** | Ложный «skip» убран: автопереход доигравшего трека (`_onTrackComplete`) вызывает `next(userInitiated: false)`; статистика пропусков теперь отражает только действия пользователя | `player_provider.dart` |

### v124 — фичи

| ID | Что сделано | Файл |
|---|---|---|
| **F4** | Таймер сна: **плавное затухание** (~8 c, 20 шагов, громкость восстанавливается после паузы) + опция **«дослушать текущий трек»**. Переключатели в диалоге, выбор сохраняется в prefs (`sleep_fade`, `sleep_until_end`) | `player_provider.dart`, `sleep_timer_dialog.dart` |
| **F1** | **Экспорт M3U** (симметрично импорту): `exportM3U()` / `queueAsM3U` / `playlistTracks()`, диалог в настройках — очередь или любой плейлист → в буфер обмена | `player_provider.dart`, `settings_screen.dart` |
| **F3-задел** | Появилось управление громкостью: `_volume` + `setVolume()` (сохраняется в prefs) — база для регулятора в плеере и ReplayGain | `player_provider.dart` |

---

## 2. Открытые баги

###  Критичные / блокирующие
Пока не найдено открытых. Все критичные (C1, C2, S1, S2) закрыты.

### 🟠 Высокие

| ID | Симптом | Причина / где | Как фиксить |
|---|---|---|---|
| **B1** | **Shuffle — не shuffle.** Трек может сыграть дважды, пока не сыграют все; модульное смещение | `_playRandom()`: `index = microsecondsSinceEpoch % _playlist.length`, защита только от немедленного повтора | При включении shuffle — копия пула + Knuth shuffle, идти по ней; при исчерпании новый раунд |
| **B2** | **Repeat-one: слышен хвост следующего трека** (~200–800 мс) | `_handleIndexEvent` ловит автопереход и делает `seek(0, index: back)` уже после старта следующего | Нативный `setLoopMode(LoopMode.one)`; ручной путь — фолбэк |
| **B3** | **Удаление трека из очереди пересобирает окно** (`setAudioSources` + `seek`) → возможен разрыв/перезапуск | `removeFromQueue()` → `_rebuildPlaylist()` | Для не-текущего индекса: `removeAudioSourceAt(index - _nativeOffset)` + `_nativeLength -= 1` + `setQueue` (симметрично N0/N1) |
| **B4** | **Визуализатор не останавливается**: после ухода с экрана `EventChannel` + нативный `Visualizer` живут (микрофон/батарея). Плюс `_requested` — односторонняя защёлка | `AudioVisualizer.stop()` есть, но **не вызывается нигде** | Звать `stop()` в `dispose()` потребителей (`live_equalizer`, cinematic body); сбрасывать `_requested` при отказе в разрешении |
| **B5** | **Оптимистичный индекс при сбое `playAt`**: `_currentIndex`/`_lastHistoryTrackId` пишутся до старта; если запрос прерван — UI показывает трек, который не играет | `playAt()` — запись вне `try` | Применять оптимистичный индекс только под `if (req == _playReqSeq)` |

**✅ Пакет v122 закрыл B1, B2, B4 (переведены в раздел 1).**

### 🟡 Средние

| ID | Симптом | Причина / где | Как фиксить |
|---|---|---|---|
| **B6** | Свайп «В очередь» — fire-and-forget: ошибка вставки не видна | `library_tabs.dart:459` без `await` | `await` + `try/catch` → snackbar |
| **B7** | Ползунок после отпускания на миг отскакивает к старой позиции | `SeekSlider._displayPos` обновляется только следующим тиком | В `onChangeEnd` сразу выставить `_displayPos = target` |
| **B8** | ✅ v125: дубли drag-логики перемотки устранены — cinematic/cover-flow NP + cover-flow home переведены на единый `SeekSlider` (−270 строк дублей) | `cinematic_player_body.dart:1171`, `cover_flow_now_playing_screen.dart:230`, `cover_flow_home_screen.dart:313` | — |
| **B9** / ⬜ | `setQueue` отправляет **все** MediaItem очереди (при 6k — тысячи объектов на каждую смену/вставку) | `audio_handler.setQueue()` | Дизайн фикса: окно ±N вокруг текущего + `_queueWindowStart`; `queueIndex` считать относительно окна; `skipToQueueItem(i)` → `onPlayAt(i + windowStart)`. Требует переработки `audio_handler` — риск для шторки/локскрина, делать отдельным пакетом |
| **B10** | ✅ v123: поиск с debounce 200 мс (`Timer` + cancel в `dispose`/clear) | `library_tabs.dart` | — |
| **B11** | `NumpadSheet`: проверить UX ввода (0/ведущие нули, закрытие при успехе) | `lib/widgets/numpad_sheet.dart` | Ручной прогон ⏳ |
| **B12** | Мёртвый код: `_close()`/`_toggleClose()` дублируются; `SwipeAction.tooltip` не используется | `swipe_reveal.dart` | Убрать дубль, обернуть в `Tooltip` |

### 🟢 Низкие

| ID | Симптом | Где |
|---|---|---|
| **B13** | `AudioTrack.copyWith` не умеет сбрасывать nullable-поля в `null` | `lib/models/audio_track.dart` |
| **B14** | `_loadFavorites`: битые записи → id=0 (мусор в избранном) | `player_provider.dart` |
| **B15** | `QueueSnapshot` идентифицируется по имени: сохранение с тем же именем перезаписывает, rename нет | `saveQueueSnapshot` |
| **B16** | Контроллеры в диалогах `settings_screen` — проверить `dispose()` | `settings_screen.dart:958–1053` ⏳ |
| **B17** | Диагностический каркас в прод-коде: 4 kill-switch + `DebugLog.rebuild` в 18 `build()` | `debug_log.dart` + экраны |
| **B18** | `playlist!` в колбэке меню (теоретический NPE) | `playlist_detail_screen.dart:100` |
| **B19** | ✅ v125: `didUpdateWidget` — пере-подписка на positionTick при смене `player` | `lib/widgets/seek_slider.dart:77-86` |
| **B20** | `DateTime.now()` в «сегодня/эта неделя»-вычислениях, вызываемых из `build` → пересчёт на каждый rebuild | `library_tabs.dart:1404,1549,1639`, `music_dna_tab.dart:425` |
| **B21** | `settings_screen.dart` — 1936 строк в одном файле (то же, что F13 для провайдера) | `lib/features/settings/settings_screen.dart` |
| **B22** | История/избранное читаются единым `String` из prefs; при росте истории вынести тяжёлый стейт в отдельный файл | `player_provider.dart` |
| **B23** | Автопереход внутри окна идёт мимо `next()`; ложный skip для треков <25 c из `_onTrackComplete` | ✅ v123 (`next(userInitiated: false)`) |
| **P-10** | `context.watch` осталось 31: почти все — по одному в диалогах/шитах (транзиентные, ок), 4 в `cinematic_player_body`, экраны уже на `select` |  |
| **P-6** | Ленивые списки: 6 `ListView.builder`; единственный неленивый `ListView(` — маленький список плейлистов в bottom-sheet | ✅ |

## 3. Производительность

| ID | Что | Статус |
|---|---|---|
| **P-1** | `loadTracks` в изоляте (`compute`) — MediaStore-запрос + маппинг не на UI-потоке | ✅ сделано |
| **P-2** | Персист позиции — только 3 скаляра каждые 5 с (не весь список id) | ✅ сделано |
| **P-3** | Список id очереди пишется только при реальной смене состава | ✅ сделано |
| **P-4** | `_tracksById` вместо `indexWhere` в циклах по истории | ✅ сделано |
| **P-5** | LRU-кэш обложек + пул из 8 одновременных запросов | ✅ сделано |
| **P-6** | Ленивые списки (`ListView.builder`) — проверено на «Истории»; **проверить остальные табы** | ⏳ |
| **P-7** | Троттл `playbackState` (шторка) до 1 Гц | ✅ сделано |
| **P-8** | `setQueue` на все MediaItem (B9) | ⬜ |
| **P-9** | Поиск без debounce (B10) | ✅ v123 |
| **P-10** | `context.watch<PlayerProvider>()` в экранах: большая часть переведена на `select` (мини-плееры, queue_sheet); **проверить остальные** | ⏳ |

---

## 4. Функциональные пробелы (что можно добавить)

| ID | Фича | Зачем | Оценка |
|---|---|---|---|
| **F1** | Экспорт плейлистов/очередей в M3U (импорт уже есть) | симметрия, перенос между устройствами | ✅ v124 |
| **F2** | Crossfade / gapless | «дорогое» звучание, без паузы между треками | 1–2 дня (нужен пакет/ветка) |
| **F3** | Громкость в плеере + автобаланс (ReplayGain) | разная громкость треков — частая жалоба | ⏳ задел сделан (v124: `setVolume`), нужен UI-регулятор в 4 стилях |
| **F4** | Sleep Timer: fade-out + «до конца трека» / «через N треков» | сейчас резкая пауза | ✅ v124 (fade + до конца трека); «через N треков» — осталось |
| **F5** | Статистика с графиками (часы пика, дни недели, жанры) | данные уже есть в агрегатах | 1 день |
| **F6** | EQ/X-Boost: пере-применение при потере аудио-сессии/смене гарнитуры (E1/E2) | пресет молча слетает на Flat | ✅ v122 |
| **F7** | Очередь: drag&drop + «сохранить как плейлист» + rename снимков | UX | 1 день |
| **F8** | Редактирование тегов/обложек (MediaStore.update) | «взрослый» плеер | 2–3 дня |
| **F9** | Last.fm / ListenBrainz скробблинг | автостатистика + рекомендации | 1 день |
| **F10** | Android Auto (AAOS) | отдельная причина держать приложение | 3–5 дней |
| **F11** | Подкасты/аудиокниги (RSS) | новый класс контента | 4–6 дней |
| **F12** | Интерактивный seek на виджете рабочего стола | виджет уже есть | 1 день |
| **F13** | Refactor `PlayerProvider` (~3200 строк) на контроллеры | главный антидот к регрессиям | 2–3 дня |

**Пакет v120 (сделано):** B3 (удаление из очереди без пересборки окна), B6 (await + ошибка в свайпе), B7 (ползунок без отскока), B12 (мёртвый код свайпа убран).

---

## 5. Визуал

| ID | Что | Зачем |
|---|---|---|
| **V1** | Единый токен-слой (`ThemeExtension<NeonWaveColors>`) — сейчас ~100+ захардкоженных `Color(0x..)` по виджетам (`0xFFA855F7` ×15, `0xFF06B6D4` ×9 и т.д.) | одно место правки, консистентность «список ↔ сцена» |
| **V2** | Полная light-тема во всех 4 стилях (сейчас в основном simple) | |
| **V3** | Crossfade обложек на now-playing (`AnimatedSwitcher` + blur/scale) | |
| **V4** | Аудио-реактивные акценты в неоне (пульс свечения от `AudioVisualizer.energy`) | |
| **V5** | 3D-parallax обложки в Cover Flow | |
| **V6** | Cinematic letterbox-переходы | |
| **V7** | Ночной режим now-playing (затемнение) | |
| **V8** | Прогресс-бар со стилевым свечением в каждом стиле | |

---

## 6. Проверено — ОК (не перепроверять)

| Что | Вывод |
|---|---|
| `PlayerProvider.dispose()` | подписки `_subs` отменяются, `positionTick`/`_audioPlayer` диспозятся ✅ |
| `jsonDecode` (12 мест) | все вызовы внутри `try/catch`; HTTP-ответы проверяют `statusCode` ✅ |
| `firstWhere` (5 мест) | везде есть `orElse` ✅ |
| `palette_controller` (`_custom!`) | защищено `_custom ??= active` ✅ |
| `ArtworkCache` | LRU 200 записей + пул 8 запросов + дедуп pending ✅ |
| `WidgetService._syncTicker` | таймер корректно отменяется при паузе ✅ |
| Инвалидация кэшей при сортировке | `sortOrder` → `_invalidateFolderCache()` чистит album/artist/search/visible кэши ДО ре-сорта ✅ |
| `_queueSnapshots` | cap 20 ✅ |
| **D4** (старый аудит) | Ручная смена жанра: `setManualGenre`/`clearManualGenre` → `_invalidateCategoryCache()` → чистит `_primaryGenreCache` (стр. 1329) ✅ **не баг** |
| Тяжёлые вкладки (DNA/Категории) | используют `context.select((p) => p.dataEpoch)` — пересчёт только при смене данных ✅ |
| `setQueue`/`sortOrder`/`_maybeResume` | инварианты и инвалидации проверены ✅ |
| Манифест APK vs репо | паритет подтверждён `aapt2` (разрешения + `AudioService foregroundServiceType=mediaPlayback`) ✅ |
| `flutter analyze` / `flutter test` | чисто / 12 из 12 ✅ |

---

## 7. Рекомендуемый порядок работ

1. **Пакет «очередь/плеер» (0.5–1 день):** B3 (удаление без пересборки) → B5 (индекс) → B6 (await) → B7 (ползунок) → B12 (мёртвый код).
2. **Пакет «аудио» (1 день):** B2 (нативный repeat-one) → B1 (настоящий shuffle) → B4 (stop визуализатора) → F6 (пере-применение EQ).
3. **Пакет «перф» (1 день):** B9 (окно в `setQueue`) → B10 (debounce поиска) → P-6 (ленивые списки) → P-10 (`select`).
4. **Пакет «фичи» (2–3 дня):** F4 (sleep fade) → F3 (громкость/ReplayGain) → F1 (экспорт M3U) → F5 (графики).
5. **Стратегия:** V1 (токены) → F7 (drag&drop очереди) → F13 (рефактор провайдера) → F8/F9.

---

*Обновлять: при каждом фиксе менять `⬜` → `✅` и переносить строку в раздел 1.*
