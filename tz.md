NeonWave — Master Audit / Verify-First Engineering Task

Репозиторий:
"MaxSC2/audio-player-music"

Целевая платформа:
Android 13+

Главный принцип этой задачи:

НЕ считать старую документацию, README, backlog или прежние аудиты источником истины.

Источник истины:

1. текущий код ветки "master";
2. текущая структура проекта;
3. текущие тесты;
4. реальные call-site;
5. текущее поведение на устройстве;
6. только после этого старые AUDIT/BUG_REGISTER/FUNCTIONAL_AUDIT использовать как исторический контекст.

КЛЮЧЕВОЕ ПРАВИЛО:

Не реализовывать фичу только потому, что она есть в старом backlog.

Для КАЖДОГО пункта сначала определить его статус:

- "EXISTS_AND_OK" — уже реализовано и работает;
- "EXISTS_BUT_WEAK" — реализовано, но есть конкретный технический/UX-дефект;
- "PARTIAL" — есть часть функциональности;
- "MISSING" — действительно отсутствует;
- "STALE_DOC" — в документации отмечено как отсутствующее, но в текущем коде уже реализовано;
- "NOT_WORTH_DOING" — технически можно сделать, но сейчас нет достаточной пользы;
- "NEEDS_DEVICE_TEST" — по коду нельзя надёжно определить, требуется реальное устройство;
- "NEEDS_RESEARCH" — сначала исследовать API/платформу/совместимость.

Не менять код до фиксации такого статуса.

---

0. BASELINE

Сначала зафиксировать состояние проекта.

Проверить:

- текущий branch;
- "git status";
- текущий commit;
- Dart/Flutter version;
- "pubspec.yaml";
- Android target/min SDK;
- зависимости;
- структуру "lib/";
- структуру "android/";
- "test/";
- CI;
- debug/release конфигурацию.

Запустить:

- "flutter analyze";
- "flutter test";
- если окружение позволяет, release build;
- не менять код только ради того, чтобы «пофиксить» несвязанные предупреждения.

Зафиксировать baseline:

- какие тесты проходят;
- какие не проходят;
- какие warnings есть;
- размер проекта;
- фактическое количество тестов;
- фактическую версию приложения;
- есть ли незакоммиченные изменения.

Создать внутреннюю таблицу:

Область| Статус| Подтверждение| Риск| Нужна работа

Не приступать к крупному рефакторингу до создания этой карты.

---

1. ИНВЕНТАРИЗАЦИЯ ФУНКЦИЙ

Перед любыми изменениями проверить текущую реализацию следующих областей.

1.1 Playback

Проверить:

- play;
- pause;
- next;
- previous;
- seek;
- repeat off;
- repeat all;
- repeat one;
- shuffle;
- queue;
- queue reorder;
- insert next;
- remove from queue;
- save queue;
- restore queue;
- resume playback;
- playback after process restart;
- playback after screen lock;
- playback after app backgrounding;
- playback after audio focus interruption;
- playback after output-device change;
- becoming noisy;
- broken/unavailable media source;
- long queue;
- queue around treadmill window boundaries.

Особенно проверить связь:

"provider index"
↔
"native just_audio index"
↔
"_nativeOffset"
↔
"audio_service queueIndex"
↔
"currentTrack"
↔
"WidgetService"
↔
"MediaItem".

Не вводить новую систему индексов, пока не доказано, что существующая неверна.

---

2. КРИТИЧЕСКАЯ ПРОВЕРКА B9: MEDIA SESSION QUEUE

Это сейчас один из главных технических кандидатов на работу.

Проверить фактическую реализацию:

"PlayerAudioHandler.setQueue()"

и все call-site:

"_audioHandler?.setQueue(...)"

Сейчас код формирует:

"List<MediaItem>" для всего "_queueTracks".

Для очереди 6000+ объектов проверить:

- сколько объектов создаётся;
- сколько памяти используется;
- сколько времени занимает "setQueue";
- что происходит при вставке одного трека;
- что происходит при drag&drop;
- что происходит при remove;
- что происходит при переходе через treadmill window;
- как ведут себя notification/lockscreen;
- как "skipToQueueItem(index)" должен работать при оконной очереди;
- не ломается ли Android MediaSession при неполной очереди.

Сначала сделать измерение.

Только если проблема реально подтверждается, спроектировать одно из решений:

A. bounded media-session window;
B. delta updates;
C. отдельное понятие provider queue и media-session queue;
D. другой безопасный механизм.

Не выбирать архитектуру заранее.

Обязательные acceptance tests:

- 81 трек;
- 300;
- 1000;
- 3000;
- 6400+.

Проверить:

- текущий трек;
- next;
- previous;
- skipToQueueItem;
- notification;
- lockscreen;
- widget;
- переход через границу окна;
- reorder;
- remove;
- insert.

Если оптимизация не даёт измеримого выигрыша либо резко усложняет media-session, зафиксировать это и не внедрять.

---

3. PROVIDER ARCHITECTURE

"PlayerProvider" сейчас очень большой.

Не начинать механический рефакторинг.

Сначала составить карту ответственности:

- playback;
- queue;
- library;
- history;
- favorites;
- playlists;
- smart playlists;
- recommendations;
- genres;
- categories;
- persistence;
- audio effects;
- bookmarks;
- statistics;
- sleep timer;
- radio;
- URL playback;
- diagnostics.

Определить связи между ними.

Для каждого блока определить:

- какие поля он читает;
- какие поля меняет;
- какие методы вызывает;
- какие UI напрямую от него зависят;
- какие caches завязаны на него;
- какие "_notify()" вызываются;
- какие persistence keys используются.

Только после этого решить, действительно ли выгодно извлекать:

- "PlaybackController";
- "QueueController";
- "LibraryRepository";
- "RecommendationEngine";
- "GenreService";
- "StatisticsService";
- "PersistenceStore".

Не дробить класс на десяток файлов только ради красоты.

Главная цель рефакторинга:

Уменьшить вероятность регрессий и количество связанных состояний.

Если после рефакторинга становится сложнее понять поток:

UI → Provider → Controller → Service → just_audio

отменить такой вариант.

---

4. AUDIO ENGINE AUDIT

4.1 Equalizer

Функция EQ уже существует.

Проверить текущую реализацию, не создавать новый EQ.

Проверить:

- фактическое количество полос;
- фактическое количество пресетов;
- реальные диапазоны native bands;
- resampling preset gains;
- min/max dB;
- сохранение пресета;
- восстановление после restart;
- восстановление после audio interruption;
- восстановление после смены output device;
- поведение при отсутствии эффекта;
- behavior на разных Android devices;
- behavior при unsupported effect;
- щелчки при применении;
- повторное применение;
- Flat preset;
- reset.

Проверить, есть ли именно пользовательское ручное редактирование каждой полосы, а не только presets.

Если manual EQ отсутствует, не считать это автоматически дефектом.

Сначала оценить:

- действительно ли это полезнее текущих пресетов;
- насколько native API стабилен;
- нужна ли отдельная persistence model;
- насколько это совместимо с четырьмя UI-стилями.

---

5. VOLUME / LOUDNESS

Громкость уже реализована.

Проверить:

- "VolumeControl";
- "previewVolume";
- "setVolume";
- persistence;
- "effectiveVolumeFor";
- X-Boost;
- adaptive balance;
- track fix;
- learning;
- caps;
- interaction с EQ;
- interaction с sleep fade;
- interaction с X-Boost;
- interaction после смены устройства.

Особенно проверить, что preview во время drag не ломает adaptive balance.

Проверить формулу:

user volume
×
track correction
×
X-Boost factor
→ final output

и одновременно используемый "LoudnessEnhancer".

Не называть текущий механизм ReplayGain, пока не доказано, что это действительно ReplayGain.

Текущий механизм нужно описать как adaptive learned per-track volume correction, если именно это подтверждается кодом.

Отдельно исследовать возможность настоящей loudness normalization.

Но сначала выяснить:

- есть ли loudness metadata;
- можно ли надёжно получить её;
- можно ли вычислять LUFS;
- где это можно делать;
- какая цена по CPU;
- нужен ли фоновый анализ;
- сколько займёт обработка 6000 файлов;
- нужен ли native DSP.

Если стоимость/сложность слишком высока, текущий adaptive balance не заменять.

---

6. X-BOOST

Проверить текущую реализацию.

Особенно:

- клиппинг;
- distortion;
- maximum output;
- interaction с volume;
- interaction с adaptive balance;
- behavior on cheap Android devices;
- behavior after interruption;
- behavior after device change.

Если "+6 dB" визуально выглядит хорошо, но фактически приводит к clipping на части устройств, проверить корректность стратегии.

Не удалять функцию только из-за теоретического риска.

Нужен device test.

---

7. GAPLESS / CROSSFADE

Не считать старое TODO автоматически актуальным.

Сначала разделить понятия:

1. gapless;
2. crossfade;
3. fade-out/fade-in;
4. manual transition;
5. album-style continuous playback.

Проверить, что текущая версия "just_audio" реально делает для локальных файлов в существующей архитектуре.

Отдельно проверить:

- MP3;
- M4A/AAC;
- OGG;
- FLAC, если поддерживается проектом;
- разные sample rates;
- разные encodings;
- speed ≠ 1.0;
- EQ enabled;
- X-Boost enabled;
- long queue.

Если gapless уже соответствует ожиданию, закрыть этот пункт.

Если нужен именно crossfade:

сначала research existing architecture/package compatibility.

Не подключать новый audio engine без доказанной необходимости.

Acceptance:

- transition 1→2;
- transition 2→3;
- repeat one;
- shuffle;
- radio extension;
- queue rebuild;
- seek near track end.

---

8. SHUFFLE / REPEAT / QUEUE

Эти функции уже были исправлены.

Не переписывать.

Проверить только regression.

Особенно:

- Fisher-Yates round;
- отсутствие повторов до окончания раунда;
- previous по shuffle order;
- repeat one;
- repeat all;
- radio mode;
- adding track to shuffled queue;
- removing track;
- moving track;
- queue snapshot;
- resume.

Добавлять tests только там, где покрытие действительно отсутствует.

---

9. SMART MUSIC ENGINE

Это уже существующая система.

Найти и описать текущую цепочку:

history
→ artist affinity
→ genre affinity
→ category affinity
→ favorites
→ skips
→ recency
→ discovery level
→ deep cuts
→ current artist/album
→ queue scoring.

Проверить фактическую реализацию "buildSmartQueue()".

Особенно проверить:

- range of scores;
- whether one factor dominates all others;
- too frequent favorite repetition;
- artist repetition;
- album repetition;
- skip punishment;
- recency punishment;
- discovery balance;
- deep cuts;
- randomness;
- deterministic/non-deterministic behavior;
- duplicate prevention;
- current-track exclusion.

Обратить внимание на потенциально избыточный "queue.contains(t)" внутри scoring loop.

Сначала измерить.

Не оптимизировать микрозацикливание, если оно не влияет на реальные 6k-library сценарии.

Нужен recommendation benchmark на искусственном наборе:

- 100 tracks;
- 1000;
- 6000. 

Проверить качество результатов.

---

10. MOOD / CONTEXT CATEGORIES

Категории уже существуют:

- Balanced;
- Energy;
- Calm;
- Party;
- Focus.

Проверить:

- keyword rules;
- duration heuristics;
- genre influence;
- manual overrides;
- multiple category membership;
- weights;
- persistence;
- cache invalidation;
- UI;
- Personal DJ interaction.

Особенно проверить, насколько странно ведут себя duration heuristics.

Например:

короткий трек автоматически становится Energy.

длинный трек автоматически становится Calm.

Проверить на реальных тестовых данных, не на одном-двух треках.

Если false positives высокие, предложить улучшенную scoring model.

Не заменять rule engine машинным обучением без доказанной пользы.

---

11. PROMPT / NATURAL LANGUAGE PARSER

Парсер уже существует.

Проверить "buildPlaylistFromPrompt()" и PromptPlaylistSheet.

Не создавать новый LLM parser.

Сначала измерить возможности текущего parser.

Проверить запросы вида:

- спокойная музыка;
- что-нибудь энергичное;
- для работы;
- для учёбы;
- для вечеринки;
- новые исполнители;
- малоизвестные;
- что-то новое и спокойное;
- спокойный рок;
- энергичная электроника;
- больше знакомого;
- наоборот, что-нибудь необычное.

Определить текущую семантику.

Потом оценить расширения:

- synonyms;
- stemming;
- RU/EN normalization;
- genre terms;
- combined intents;
- exclusions;
- artist hints;
- negative instructions.

Не подключать LLM, если regex/rule-based parser уже удовлетворяет задаче.

Если расширять parser, сделать его отдельным чистым модулем и покрыть тестами.

---

12. AI RADIO / PERSONAL DJ

Проверить:

"PersonalDJSheet"

"launchPersonalDJ"

"launchRadio"

"_extendRadio"

"_radioExtending"

и scoring.

Проверить, действительно ли пользователь ощущает Radio как непрерывную подборку, а не как случайный список.

Нужно проверить:

- queue extension;
- duplicate prevention;
- exclusion memory;
- skip learning;
- discovery;
- current context;
- behavior after 30–60 tracks;
- repeated sessions.

Отдельно решить вопрос терминологии:

Если никакой внешней AI-модели нет, в интерфейсе можно оставить marketing name "AI Radio", но техническая документация должна корректно описывать его как локальный recommendation engine.

---

13. GENRE ENGINE

Жанровая система уже серьёзная.

Проверить текущую цепочку:

manual

«»

online normalized

«»

keyword inference

и online sources:

iTunes
→
MusicBrainz fallback.

Проверить:

- 32 canonical genres;
- normalizeOnline;
- keyword taxonomy;
- longest-match logic;
- artist aliases;
- RU;
- EN;
- collisions;
- ambiguous artists;
- false positives;
- manual override;
- cache;
- cache invalidation;
- network fallback;
- errors;
- timeouts;
- retry behavior;
- request frequency.

Особенно проверить спорные случаи:

- Arctic Monkeys;
- BTS;
- Japanese/Korean;
- pop/rock;
- alternative/indie;
- electronic/dance;
- soundtrack/anime;
- chanson/shanson;
- estrada/pop.

Не менять taxonomy без тестового набора.

Создать classification test fixture хотя бы на 100–300 вручную подобранных примерах.

Для каждого примера желательно фиксировать:

input
expected genre
actual genre
source
confidence/ambiguity.

---

14. ONLINE METADATA / PRIVACY

Это отдельная важная область.

В текущем приложении есть реальные HTTP-запросы к внешним сервисам для жанров.

Проверить:

- когда именно они выполняются;
- запускаются ли автоматически;
- какие данные уходят наружу;
- artist/title;
- network timing;
- retries;
- rate limiting;
- caching;
- behavior offline;
- behavior on VPN;
- behavior with no internet.

Особенно проверить соответствие с текущим текстом:

«Работает офлайн, вся музыка — только на вашем устройстве»

Потому что приложение одновременно умеет:

- обращаться к iTunes;
- обращаться к MusicBrainz;
- проигрывать URL.

Нужно не обязательно менять код.

Нужно сделать одно из:

- корректно переписать UI-text;
- или добавить явный online metadata toggle;
- или изменить поведение по умолчанию.

Решение принять после аудита.

Нельзя создавать ложное впечатление полного offline режима.

---

15. GENRE BACKGROUND LOADING

Проверить "fetchGenresForVisible()".

Сейчас есть batch loading и delay между запросами.

Проверить:

- скорость;
- количество запросов;
- duplicate suppression;
- cache hits;
- cancellation;
- app backgrounding;
- category tab open/close;
- repeated visits;
- 6000-track library.

Важно проверить, не происходит ли слишком много network activity только из-за открытия вкладки.

---

16. MUSIC DNA / STATISTICS

Уже существуют:

- top tracks;
- top artists;
- weekday activity;
- top genres;
- listening profile;
- unique tracks;
- history;
- bookmarks;
- skip data;
- smart playlists.

Проверить:

- correctness;
- cache invalidation;
- performance;
- date handling;
- timezone;
- “today”;
- “week”;
- month/year boundaries;
- empty history;
- deleted tracks;
- changed library.

Особенно проверить использование "DateTime.now()" в build-path.

Если из-за этого только дешёвый пересчёт, не трогать.

Если есть measurable rebuild cost, оптимизировать.

---

17. HISTORY / PERSISTENCE

Проверить:

- history cap;
- skip cap;
- bookmark cap;
- queue snapshot cap;
- playlist persistence;
- genre cache;
- manual genre;
- manual categories;
- balance fix;
- volume;
- EQ;
- UI style;
- palette;
- sleep settings;
- discovery level.

Проверить migration strategy.

Есть "prefsSchemaVersion", проверить, действительно ли все будущие изменения смогут нормально мигрировать.

Не превращать всё в SQLite без причины.

Но отдельно оценить:

JSON inside SharedPreferences

для:

- history;
- bookmarks;
- genre cache;
- skip data;
- queue snapshots.

Если реальный объём остаётся небольшим, оставить.

Если объём начинает серьёзно расти, представить migration plan.

---

18. PORTABLE BACKUP

Это новая область для аудита.

Проверить, можно ли сейчас полностью восстановить пользовательские данные.

Нужно определить, что теряется при:

- uninstall;
- clear data;
- migration;
- new phone.

Особенно:

- playlists;
- favorites;
- history;
- genre overrides;
- category overrides;
- balance corrections;
- bookmarks;
- queue snapshots;
- settings;
- theme/palette.

Если полноценного backup нет, оценить создание:

"NeonWave Backup JSON"

с:

- schema version;
- app version;
- createdAt;
- playlists;
- preferences;
- user metadata;
- validation.

Restore должен проверять version/schema перед импортом.

Это потенциально более ценная фича, чем очередной визуальный эффект.

---

19. BOOKMARKS

Проверить:

- add;
- remove;
- duplicate;
- sorting;
- display;
- opening at bookmark;
- deleted track;
- multiple bookmarks per track;
- cap;
- persistence.

Убедиться, что bookmarks не просто хранятся, а реально удобно используются.

---

20. SLEEP TIMER

Уже есть:

- timer;
- fade;
- until track end.

Проверить:

- pause;
- resume;
- app background;
- screen lock;
- track changes;
- repeat;
- radio;
- manually changed volume during fade;
- X-Boost;
- auto balance.

Отдельно оценить необходимость:

“after N tracks”.

Не добавлять без понимания UX.

---

21. M3U

Уже есть import/export.

Проверить:

- relative paths;
- absolute paths;
- file basename matching;
- duplicate filename;
- case sensitivity;
- URLs;
- missing files;
- UTF-8;
- M3U8;
- "#EXTINF";
- Unicode paths;
- Windows paths;
- Android content URIs;
- duplicate tracks with identical filename.

Текущий basename-only matcher потенциально может ошибиться при одинаковых именах файлов.

Сначала создать test cases.

Если нужен более точный matcher, рассмотреть:

1. full path;
2. normalized filename;
3. title;
4. artist;
5. album;
6. duration.

Не ломать совместимость.

Отдельно проверить UX:

сейчас import принимает содержимое M3U.

Нужно решить, нужен ли настоящий File Picker.

---

22. PLAYLISTS

Проверить:

- create;
- rename;
- delete;
- duplicate name;
- add track;
- remove track;
- queue → playlist;
- snapshots;
- smart playlists;
- deleted tracks;
- stale IDs.

Проверить, что удалённые из MediaStore tracks корректно исчезают из custom playlists.

---

23. QUEUE SNAPSHOTS

Проверить:

- save;
- rename;
- delete;
- duplicate name;
- cap;
- restore;
- deleted tracks;
- current position;
- current track;
- order.

Особенно убедиться, что документация уже не утверждает, что rename отсутствует, если текущий UI его уже содержит.

---

24. SWIPE ACTIONS

Уже были исправлены.

Не переписывать.

Regression test:

- add to queue;
- favorite;
- hide/not now;
- different UI styles;
- tap;
- swipe;
- scroll;
- animation;
- rapid gesture.

---

25. LIBRARY

Проверить реальные текущие tabs:

- tracks;
- playlists;
- albums;
- artists;
- folders;
- favorites;
- history;
- DNA;
- categories.

Проверить:

- lazy lists;
- search debounce;
- sorting;
- grid;
- multi-select;
- swipe;
- selection state;
- large lists;
- empty state;
- permission denied;
- unknown artist filtering.

Особое внимание:

"context.watch<PlayerProvider>()"

и "context.select".

Но не превращать каждый watch в select автоматически.

Для каждого кандидата сначала определить:

какое изменение действительно должно обновлять widget.

---

26. ARTIST / PLAYLIST DETAIL

Проверить:

- "ArtistDetailScreen";
- "PlaylistDetailScreen".

Обратить внимание на широкие "context.watch".

Проверить, вызывает ли любой unrelated playback tick дорогой rebuild.

Проверить O(n) filtering по "_allTracks".

Оптимизировать только при измеренном эффекте.

---

27. ARTWORK SYSTEM

Есть:

- cached artwork;
- artwork palette;
- artwork backdrop;
- artwork temp files;
- widget artwork;
- media notification artwork.

Проверить, сколько существует независимых кэшей.

Найти:

- duplication;
- stale temp files;
- disk growth;
- memory growth;
- LRU behavior;
- failed artwork requests;
- giant artwork;
- corrupted artwork;
- repeated artwork loads.

Сейчас есть LRU механизмы.

Не заменять их новым cache layer без доказанного преимущества.

Отдельно проверить:

WidgetService artwork cache
vs
AudioHandler artwork paths
vs
ArtworkPalette cache
vs
CachedArtwork.

Нужно понять, возможно ли безопасно уменьшить дублирование.

---

28. VISUALIZER

Visualizers уже существуют.

Проверить:

- Android Visualizer;
- EventChannel;
- microphone permission;
- synthetic fallback;
- acquire/release;
- stop;
- consumer count;
- background;
- screen navigation;
- battery impact;
- CPU;
- multiple visualizers одновременно.

Критично проверить permission UX.

Пользователь должен понимать, зачем приложению "RECORD_AUDIO".

Если visualizer работает без real capture, должен корректно использовать synthetic fallback.

Не удалять permission blindly.

---

29. UI STYLES

Уже существуют четыре:

- Simple;
- Cover Flow 3D;
- Cinematic;
- Neon.

Проверить:

- navigation;
- home;
- now playing;
- mini player;
- seek slider;
- queue;
- artwork;
- buttons;
- states;
- empty state;
- loading;
- dialogs;
- settings.

Главное:

каждая функция, добавленная в один style, должна быть проверена во всех четырёх.

Не считать feature готовой только потому, что она работает в Simple.

---

30. PALETTE SYSTEM

Уже есть:

- preset palettes;
- custom palette;
- color picker;
- light/dark;
- persistence.

Проверить:

- persistence;
- reset;
- contrast;
- text readability;
- slider visibility;
- icons;
- dialogs;
- cards;
- gradients;
- notification;
- all four UI styles.

Особенно проверить архитектурное разделение:

"AppTheme"
vs
"PaletteController"
vs
"UiStyleController"
vs
"CinematicTheme"
vs
"ArtworkPalette".

Нужно определить, где сознательно существуют независимые цветовые системы.

Например Cinematic может сознательно использовать:

- artwork-derived colors;
- фиксированные cinematic themes;

вместо глобальной palette.

Это не считать багом автоматически.

Но UX должен быть понятен:

если пользователь меняет palette, какие экраны должны меняться, а какие намеренно нет.

---

31. THEME TOKEN LAYER

Старый аудит предлагает "ThemeExtension".

Проверить фактическое число захардкоженных цветов.

Но не выполнять механический поиск/replace.

Сначала определить:

- какие цвета являются глобальными;
- какие являются style-specific;
- какие являются semantic;
- какие являются data-driven;
- какие приходят из artwork.

Оптимальная архитектура должна позволять:

- palette;
- light/dark;
- style-specific accents;
- cinematic artwork accents.

Если "ThemeExtension" действительно упрощает систему, предложить migration plan.

---

32. LIGHT MODE

Это реально важный UI audit.

Проверить ВСЕ 4 UI styles в light mode.

Не только главный экран.

Проверить:

- now playing;
- queue;
- library;
- dialogs;
- sheets;
- player controls;
- selection;
- sliders;
- cards;
- text;
- icons;
- gradients;
- visualizers;
- empty states;
- snackbars;
- settings.

Найти места с:

- hardcoded white;
- hardcoded dark;
- white opacity;
- fixed cinematic colors;
- fixed neon surfaces.

После карты проблем принять решение, что действительно надо унифицировать.

---

33. HARD-CODED COLORS

Найти реальные повторяющиеся значения.

Сгруппировать:

- duplicate exact colors;
- semantic colors;
- decorative colors;
- effect colors;
- style colors.

Не заменять декоративные цвета на глобальные токены только для уменьшения количества строк.

Главная цель:

maintainability + consistency.

---

34. CINEMATIC MODE

Проверить отдельно.

Это отдельная система со:

- auto artwork colors;
- crimson;
- ocean;
- emerald;
- violet;
- mono.

Проверить:

- color extraction;
- transitions;
- state changes;
- palette interaction;
- image changes;
- performance;
- blur;
- animations;
- dark/light.

Не заставлять Cinematic использовать AppTheme, если это разрушает его визуальную концепцию.

---

35. COVER FLOW / 3D

Проверить:

- parallax;
- page transformations;
- scrolling;
- image filters;
- blur;
- frame rate;
- memory;
- 6k library;
- rotation;
- current track changes.

Особенно проверить expensive:

- saveLayer;
- ImageFilter.blur;
- frequent repaints;
- large image decoding.

Уже существуют kill-switches.

Использовать их для сравнительного measurement.

---

36. PERFORMANCE

Нужен не «рефакторинг ради FPS», а measurement.

Тестовые библиотеки:

1. 100 tracks
2. 1000
3. 3000
4. 6400+

Измерить:

- cold startup;
- first library render;
- switching tabs;
- search;
- sort;
- favorite;
- category;
- DNA;
- Personal DJ;
- opening queue;
- inserting item;
- deleting item;
- reorder;
- changing volume;
- seek;
- now-playing animation;
- visualizer;
- scrolling.

Найти:

- UI isolate blocking;
- rebuild storms;
- platform channel storms;
- excessive allocations;
- image decoding;
- cache misses;
- full queue serialization.

Использовать DevTools/profile mode, если доступно.

---

37. NOTIFY ARCHITECTURE

Есть "_notify()" с coalescing.

Проверить:

- call frequency;
- most frequent sources;
- whether "dataEpoch" really isolates heavy screens;
- remaining broad watchers;
- whether any notifier is called too frequently.

Не заменять Provider целиком.

Сначала построить notify source report.

---

38. SEARCH

Проверить текущий search engine.

Нужно определить, что именно ищется:

- title;
- artist;
- album;
- genre;
- folder;
- playlist.

Проверить:

- lowercase;
- Unicode;
- RU;
- EN;
- symbols;
- punctuation;
- numbers;
- spaces;
- partial words;
- multi-word query;
- empty query;
- debounce.

Опционально исследовать fuzzy search.

Но не добавлять fuzzy matching, пока обычный search не является реальным bottleneck.

---

39. SETTINGS MONOLITH

"SettingsScreen" большой.

Сначала определить секции:

- appearance;
- playback;
- audio;
- library;
- import/export;
- debug;
- diagnostics;
- app info.

Проверить lifecycle всех:

- TextEditingController;
- ScrollController;
- AnimationController;
- temporary listeners;
- dialog resources.

Особенно проверить URL playback dialog и все локальные controllers.

Не обязательно немедленно разбивать SettingsScreen.

Сначала зафиксировать наиболее опасные lifecycle cases.

---

40. URL PLAYBACK

Уже есть playback by URL.

Проверить:

- invalid URL;
- unsupported format;
- timeout;
- HTTP;
- HTTPS;
- stream;
- dead host;
- redirects;
- user experience;
- error messages;
- background playback;
- notification metadata;
- history behavior.

Определить, считается ли URL track частью library или временной media item.

Проверить cleanup.

---

41. MEDIASTORE / LIBRARY LOADING

Текущий код уже использует isolate/fallback.

Не возвращать старую проблему обратно.

Проверить:

- "RootIsolateToken";
- "BackgroundIsolateBinaryMessenger";
- fallback to main isolate;
- behavior on unsupported environment;
- 6k tracks;
- duplicate IDs;
- stale files;
- deleted files;
- changed metadata.

---

42. DELETE TRACK

Уже был серьёзный bugfix.

Regression:

- confirm delete;
- cancel delete;
- current track;
- queued track;
- favorite;
- playlist;
- history;
- artwork;
- widget;
- current index.

После deletion библиотека и derived caches должны остаться консистентными.

---

43. ANDROID AUDIO SESSION

Проверить:

- music configuration;
- audio focus;
- becoming noisy;
- headset disconnect;
- Bluetooth;
- wired headset;
- call interruption;
- notification;
- output switch;
- effects restoration.

Особенно:

EQ/X-Boost после interruption/device change.

Уже есть соответствующая логика, не переписывать без device evidence.

---

44. WIDGETS

Уже есть:

- small widget;
- large widget;
- play/pause;
- next;
- previous;
- favorite;
- repeat;
- shuffle;
- progress;
- artwork.

Проверить:

- state synchronization;
- stale artwork;
- stale track;
- queue changes;
- app killed;
- app restarted;
- current track;
- theme;
- rapid playback changes.

Отдельно исследовать interactive seek.

Если Android widget limitations делают его бессмысленным, не внедрять.

---

45. NOTIFICATION / LOCKSCREEN

Проверить:

- correct MediaItem;
- correct artist;
- correct artwork;
- favorite;
- repeat;
- shuffle;
- previous;
- next;
- seek;
- background playback;
- queue index;
- long queue;
- treadmill window.

Особенно проверить compact action order.

---

46. ANDROID AUTO

Сейчас не считать feature отсутствующей только по отсутствию отдельного файла Android Auto.

Сначала проверить:

- текущий AudioService;
- MediaBrowserService;
- media browsing tree;
- MediaItem metadata;
- queue;
- transport controls;
- Android Auto discovery.

Если базовая совместимость уже частично есть, определить minimum delta.

Только после этого решать, нужен ли отдельный Android Auto package/implementation.

---

47. LAST.FM / LISTENBRAINZ

Если функции действительно отсутствуют:

сначала исследовать product value и privacy.

Не включать автоматически.

Если внедрение оправдано:

- explicit opt-in;
- login/token flow;
- secure storage;
- scrobble threshold;
- pause/skip handling;
- offline queue;
- retry;
- duplicate prevention;
- logout;
- revoke;
- privacy copy.

Никогда не хранить secret tokens без понимания security model.

---

48. TAG / ARTWORK EDITING

Проверить реальное состояние.

Если отсутствует, изучить:

- MediaStore APIs;
- title;
- artist;
- album;
- genre;
- artwork;
- file permissions;
- Android versions;
- file type compatibility.

Не внедрять полноценный tag editor только потому, что «у взрослого плеера он должен быть».

Оценить реальную пользу относительно риска повреждения файлов.

Особенно:
не изменять исходный audio file destructive способом без явного пользовательского подтверждения.

---

49. PODCASTS / AUDIOBOOKS

Не внедрять автоматически.

Сначала оценить, не разрушит ли это позиционирование локального music player.

Если исследовать:

- content model;
- progress per episode;
- resume;
- chapters;
- speed;
- bookmarks;
- RSS;
- cache;
- storage;
- offline download.

Сравнить с текущей архитектурой.

---

50. EXPORT / IMPORT USER DATA

Помимо M3U проверить полноценный перенос пользовательского состояния.

Нужно определить:

M3U = перенос списка музыки.

Backup = перенос настроек + metadata + playlists + user state.

Не смешивать эти два понятия.

---

51. TEST ARCHITECTURE

Текущие tests уже существуют.

Сначала inventory:

- unit;
- widget;
- integration.

Определить, какие критические зоны не покрыты.

Приоритет:

1. queue index;
2. treadmill offset;
3. shuffle;
4. repeat;
5. recommendation;
6. genre classification;
7. category inference;
8. persistence;
9. balance math;
10. M3U matching;
11. queue reorder;
12. delete synchronization.

Не писать бессмысленные тесты ради количества.

---

52. TEST FIXTURES

Создать synthetic library generators.

Нужны fixtures:

- 100 tracks;
- 1000;
- 6400. 

С параметрами:

- different artists;
- different albums;
- duplicate filenames;
- missing metadata;
- duplicate genres;
- multilingual metadata;
- missing artwork;
- long duration;
- short duration;
- favorites;
- skips;
- history.

Это позволит проверять recommendation, library, genre engine и queue отдельно.

---

53. DOCUMENTATION CONSISTENCY

После технического аудита проверить:

- README;
- SPEC;
- AUDIT_REPORT;
- AUDIT_REPORT_2026-09-13;
- BUG_REGISTER;
- FUNCTIONAL_AUDIT.

Особенно убрать устаревшие claims типа:

- «MVP»;
- «feature missing», если она уже сделана;
- старые версии;
- старые file sizes;
- старые test counts;
- старые bug statuses.

README должен отражать реальный проект.

Но не превращать README в маркетинговый роман.

---

54. RELEASE READINESS

Проверить:

- application version;
- icon;
- manifest;
- permissions;
- foreground service;
- notifications;
- release build;
- debug-only controls;
- logging;
- network permissions;
- microphone permission;
- temp files;
- crash handling;
- stale test/debug UI.

Особенно проверить, не попадают ли diagnostics/kill-switches в release build.

---

55. DATA / PRIVACY UX

Сформировать фактическую карту данных:

LOCAL:

- music;
- playlists;
- history;
- favorites;
- categories;
- genres;
- volume corrections;
- preferences.

NETWORK:

- iTunes;
- MusicBrainz;
- URL playback;
- любые будущие integrations.

PERMISSION:

- music/media;
- notifications;
- microphone;
- foreground service.

Проверить, соответствует ли UI этому поведению.

---

56. ARCHITECTURE IMPROVEMENT PRIORITY

После полного аудита ранжировать результаты только по техническим критериям:

P0:

- data corruption;
- wrong current track;
- playback failure;
- queue inconsistency;
- permission/security issue;
- crash.

P1:

- measurable long-queue performance;
- excessive media-session queue;
- serious recommendation correctness;
- broken light theme;
- major lifecycle leak.

P2:

- maintainability;
- duplication;
- moderate performance;
- UX polish.

P3:

- optional new features.

Не делать P3 до устранения P0/P1.

---

57. КРИТИЧЕСКИЙ ТРЕБОВАНИЕ К РЕФАКТОРИНГУ

Любой архитектурный рефакторинг должен иметь:

BEFORE:

- complexity;
- file size;
- dependencies;
- rebuild paths;
- tests.

AFTER:

- complexity;
- dependencies;
- rebuild paths;
- tests;
- regression risk.

Если результат хуже по одному из ключевых параметров без компенсирующей пользы, остановить рефакторинг.

---

58. НЕ ТРОГАТЬ ТО, ЧТО УЖЕ РАБОТАЕТ

В частности, сначала проверить, затем не переписывать без причины:

- EQ;
- volume;
- adaptive volume balance;
- X-Boost;
- shuffle;
- repeat;
- treadmill queue;
- smart playlists;
- Personal DJ;
- AI/local Radio;
- prompt parser;
- genre classifier;
- iTunes genre lookup;
- MusicBrainz fallback;
- manual genre;
- mood/category system;
- statistics;
- bookmarks;
- sleep timer;
- M3U;
- multiple UI styles;
- palette system;
- cinematic themes;
- visualizer lifecycle;
- widgets;
- media session;
- queue drag&drop.

---

59. FINAL OUTPUT OF THE AUDIT

Перед изменениями кодер должен подготовить файл:

"MASTER_AUDIT_2026.md"

С таблицами:

A. Already implemented

B. Implemented but weak

C. Partial

D. Missing

E. Stale documentation

F. Device-only verification

G. Recommended work

H. Not worth doing now

Для каждого пункта:

- evidence;
- exact files;
- exact classes/methods;
- current behavior;
- risk;
- proposed change;
- test required;
- whether user-visible.

---

60. IMPLEMENTATION PHASES

После аудита работу вести пакетами.

Package A — correctness

Только подтверждённые:

- P0 bugs;
- queue consistency;
- media session correctness;
- delete;
- resume;
- playback.

Package B — performance

Только измеренные:

- B9;
- rebuilds;
- image memory;
- recommendation complexity;
- search;
- long queue.

Package C — audio

Только подтверждённые:

- EQ correctness;
- volume;
- adaptive balance;
- crossfade research;
- session robustness.

Package D — recommendation/data

- genre correctness;
- category scoring;
- DJ;
- parser;
- history;
- backup.

Package E — UI system

- palette;
- light mode;
- theme tokens;
- cinematic integration;
- 4-style consistency.

Package F — product extensions

Только после предыдущих пакетов:

- Android Auto;
- Last.fm/ListenBrainz;
- tag editing;
- widget seek;
- podcasts/audiobooks.

---

61. ACCEPTANCE RULE

После каждого пакета:

1. "flutter analyze";
2. "flutter test";
3. relevant integration/widget tests;
4. device smoke tests;
5. compare before/after;
6. update "MASTER_AUDIT";
7. update "BUG_REGISTER";
8. update "FUNCTIONAL_AUDIT";
9. update README only when functionality genuinely changed.

Никаких массовых изменений без промежуточного состояния.

---

62. DEVICE TEST MATRIX

Минимальная матрица:

Library:

- 100;
- 1000;
- 3000;
- 6400+ tracks.

Playback:

- local MP3;
- another supported local format;
- URL stream.

States:

- foreground;
- background;
- locked screen;
- notification;
- widget.

Queue:

- short;
- long;
- insertion;
- deletion;
- reorder;
- treadmill boundary.

Audio:

- EQ;
- volume;
- balance;
- X-Boost;
- speed;
- sleep fade;
- repeat;
- shuffle.

Metadata:

- missing genre;
- wrong genre;
- duplicate filename;
- deleted track.

UI:

- Simple;
- Cover Flow;
- Cinematic;
- Neon;
- dark;
- light;
- custom palette.

---

63. IMPORTANT: DO NOT CONFUSE “FEATURE EXISTS” WITH “FEATURE IS GOOD”

For every existing feature ask two separate questions:

1. Does it exist technically?
2. Does it behave well enough for a real user?

Examples:

EQ exists
≠
EQ implementation is necessarily correct.

Genre classifier exists
≠
genre classification is necessarily accurate.

Personal DJ exists
≠
recommendations are necessarily good.

Palette exists
≠
palette correctly propagates across all screens.

Volume balance exists
≠
it is true ReplayGain.

Widget exists
≠
widget is synchronized under every queue state.

This distinction is mandatory throughout the audit.

---

64. MOST IMPORTANT CURRENT INVESTIGATION TARGETS

Without assuming they are bugs, prioritize investigation of:

1. "PlayerAudioHandler.setQueue()" sending the full queue to MediaSession.
2. Interaction between treadmill queue and MediaSession queue.
3. "PlayerProvider" size and responsibility boundaries.
4. "SettingsScreen" size and controller lifecycle.
5. hardcoded colors + multiple theme systems.
6. actual light-mode completeness.
7. recommendation scoring quality at 6000 tracks.
8. genre classifier false positives.
9. online metadata behavior/privacy.
10. artwork cache duplication.
11. remaining broad Provider rebuilds.
12. true gapless vs desired crossfade.
13. full portable backup/restore.
14. Android Auto compatibility already obtainable from existing AudioService.
15. accuracy of documentation versus actual product.

---

65. FINAL PRINCIPLE

The goal is NOT:

“add more features”.

The goal is:

Make NeonWave internally coherent, technically reliable, fast on 6000+ local tracks, predictable across four interfaces, honest about its online/offline behavior, and maintainable enough that adding the next feature does not create another 500-line special case in "PlayerProvider".

For every change ask:

“Какую конкретную существующую проблему это решает?”

If there is no concrete answer, do not change the code.