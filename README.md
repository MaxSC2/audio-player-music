# NeonWave — локальный музыкальный плеер

Flutter-приложение для Android: играет локальную музыку из MediaStore без стриминга,
с четырьмя визуальными стилями, умной очередью, статистикой и Android Auto.

## Возможности

- Библиотека: треки, альбомы, исполнители, папки, плейлисты, избранное, история,
  поиск, сортировки, мультивыбор, свайп-действия, «Коллекция» с чисткой названий.
- Воспроизведение: play/pause, next/prev, seek без ANR, shuffle Фишера–Йетса,
  repeat off/all/one (нативный `LoopMode.one`), скорость 0.5–2.0x, Repeat A-B.
- Очередь: до 6000+ треков через bounded-окно нативного плеера, drag&drop,
  вставка следующим, удаление без перезагрузки, снимки и сохранение в плейлист.
- Умное: Personal DJ, AI Radio, NL-плейлист по промпту, умные автоплейлисты,
  контексты прослушивания, жанровая таксономия, «Не хочу сейчас».
- Аудио: 10-полосный эквалайзер с пресетами, X-Boost, автобаланс громкости,
  визуализаторы, sleep timer (минуты / после N треков / fade-out / до конца трека).
- Система: MediaSession-уведомление и локскрин, виджеты рабочего стола,
  Android Auto (browse: все треки, избранное, недавние, плейлисты), 4 UI-стиля,
  палитры, light/dark, resume, диагностика воспроизведения.
- Импорт/экспорт M3U/M3U8, удаление трека через системный диалог.

## Стили интерфейса

`Simple`, `Cover Flow 3D`, `Cinematic`, `Neon` — переключаются в настройках;
общая логика плеера и функций не зависит от стиля.

## Структура

```
lib/
  core/          — UI-стиль, debug-лог, навигационный observer
  features/      — home (4 стиля), now_playing, mini_player, library, settings
  models/        — AudioTrack, плейлисты, жанры, display names, снимки очереди
  providers/     — PlayerProvider (состояние и воспроизведение)
  services/      — audio_service handler, виджеты, визуализатор, мост Mini-UNA
  state/         — палитра
  ui/            — тема
  widgets/       — переиспользуемые компоненты
tool/            — локальная сборка на ПК
test/            — unit + widget тесты
```

## Сборка

### GitHub Actions (основной путь)

Push в `master` запускает `.github/workflows/build-apk.yml`:
`quality` (analyze + tests) и release-сборку с подписью из secrets.
APK публикуется артефактом `app-release`.

Workflow сам создаёт отсутствующие Gradle-файлы через `flutter create`,
поэтому в репозитории лежит только `android/app/build.gradle.kts.tmpl`.

### Локально на ПК

Нужны Flutter (stable), JDK 17 и Android SDK.

```bash
git clone https://github.com/MaxSC2/audio-player-music.git
cd audio-player-music
bash tool/setup_local_android.sh   # создаст Gradle-обвязку
bash tool/build_apk.sh             # соберёт NeonWave.apk в корне
```

Для release-подписи положите keystore в `android/app/release.keystore` и создайте
`android/app/key.properties`:

```properties
storePassword=...
keyPassword=...
keyAlias=...
storeFile=release.keystore
```

Без `key.properties` шаблон собирает APK с debug-подписью — годится для проверки,
но не для обновления поверх release-сборки.

В корне проекта всегда должен лежать **один** актуальный APK — `NeonWave.apk`
(другие `*.apk` не коммитятся, они в `.gitignore`).

## Разработка

```bash
flutter pub get
flutter analyze
flutter test
flutter run
```

## Документация

- `BUG_REGISTER.md` — реестр находок и исправлений.
- `FUNCTIONAL_AUDIT.md` — инвентарь функций и план развития.
- `MASTER_AUDIT_2026.md` — итоги verify-first аудита и merged-пакета.
- `SPEC.md` — исходная спецификация MVP.
