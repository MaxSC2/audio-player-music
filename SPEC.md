# Audio Player MVP — Спецификация

## 1. Контекст среды

- **Платформа**: Android (физическое устройство Redmi Note 13 Pro)
- **Среда разработки**: Termux + proot Ubuntu + OpenCode
- **Отладка**: Hot Reload на устройстве, релиз через GitHub Actions

---

## 2. Цель (MVP)

Локальный музыкальный плеер с минимальным функционалом:
- Сканирование памяти на аудиофайлы
- Список треков (название, исполнитель, длительность)
- Воспроизведение, пауза, переключение, перемотка
- Тёмная тема, крупные кнопки, чистый UI

---

## 3. UI/UX

### Цветовая палитра
| Элемент | Цвет |
|---------|------|
| Фон | `#121212` |
| Карточки | `#1E1E1E` |
| Акцент | `#BB86FC` |
| Текст основной | `#E0E0E0` |
| Текст вторичный | `#A0A0A0` |

### Типографика
- Заголовки: 16sp
- Подзаголовки: 14sp
- Время: 12sp
- Шрифт: Roboto (Flutter default)

### Макет экранов

#### Библиотека (LibraryScreen)
```
┌─────────────────────────────┐
│  AppBar: "Библиотека" [🔍]  │
├─────────────────────────────┤
│  ListView.builder           │
│  ┌─────────────────────────┐│
│  │ [48x48] Название        ││
│  │        Артист     3:45 ││
│  └─────────────────────────┘│
│  ┌─────────────────────────┐│
│  │ [48x48] Название        ││
│  │        Артист     4:12 ││
│  └─────────────────────────┘│
│           ...              │
├─────────────────────────────┤
│  PlayerBar (мини-плеер)    │
│  Название трека     [▶/❚❚] │
└─────────────────────────────┘
```

#### Полный плеер (BottomSheet)
```
┌─────────────────────────────┐
│         Обложка             │
│      (200x200, градиент)    │
├─────────────────────────────┤
│        Название трека       │
│          Артист             │
├─────────────────────────────┤
│  0:00 ════════════════ 3:45 │
├─────────────────────────────┤
│   [🔀]  [⏮]  [▶]  [⏭]  [🔁] │
└─────────────────────────────┘
```

### Интеракции
- Ripple-эффект на нажатиях
- BottomSheet: 300ms анимация
- Slider.adaptive для перемотки

---

## 4. Технологический стек

| Компонент | Выбор |
|-----------|-------|
| Flutter | 3.x |
| State Management | Provider (ChangeNotifierProvider) |
| Аудио-движок | just_audio |
| Запрос медиа | on_audio_query |
| Разрешения | permission_handler |
| Архитектура | 1 файл состояния, без BLoC/Riverpod |

### Пакеты (pubspec.yaml)
```yaml
dependencies:
  flutter:
    sdk: flutter
  just_audio: ^0.9.x
  on_audio_query: ^2.9.x
  permission_handler: ^11.x
  provider: ^6.x
```

---

## 5. Структура проекта

```
lib/
├── main.dart                    # Точка входа, ProviderScope, ThemeData.dark()
├── models/
│   └── audio_track.dart         # Модель трека
├── providers/
│   └── player_provider.dart     # ChangeNotifier: состояние плеера, команды
├── screens/
│   └── library_screen.dart      # Основной экран со списком
├── widgets/
│   ├── track_tile.dart          # Карточка трека в списке
│   └── player_bar.dart          # Мини-плеер внизу
└── ui/
    └── theme.dart               # Цвета, текстовые стили

android/app/src/main/AndroidManifest.xml  # READ_MEDIA_AUDIO
.github/workflows/
└── build-apk.yml                # CI/CD для релизного APK
```

---

## 6. Функционал по шагам

### Шаг 1: Инициализация
- Flutter create
- pubspec.yaml с зависимостями
- AndroidManifest: READ_MEDIA_AUDIO
- main.dart: ThemeData.dark(), ProviderScope
- Hello World на экране

### Шаг 2: Сканирование
- Запрос разрешений (Android 13+)
- on_audio_query: isMusic==true, duration>5000ms
- ListView.builder с TrackTile
- Состояние "пусто" (иконка + текст)

### Шаг 3: Аудио-движок
- just_audio в PlayerProvider
- play(), pause(), next(), prev()
- Обработка состояний (loading, playing, stopped)
- try/catch на setUrl, пропуск битых треков

### Шаг 4: Перемотка
- Slider.adaptive
- positionStream / durationStream
- seek() по слайдеру
- Формат времени mm:ss

### Шаг 5: UI/полировка
- PlayerBar (мини-плеер)
- BottomSheet с полным плеером
- Стилизация под макет
- SnackBar для ошибок

### Шаг 6: CI/CD
- .github/workflows/build-apk.yml
- Flutter setup, pub get, build apk --release
- upload-artifact с app-release.apk

---

## 7. Фильтры данных

- **on_audio_query**: `isMusic == true`
- **Длительность**: `duration > 5000ms` (исключить короткие звуки)
- **Пропуск ошибок**: try/catch на `setUrl()`, показать SnackBar

---

## 8. Что НЕ делаем на MVP

- ❌ READ_EXTERNAL_STORAGE (устарело)
- ❌ Фоновые сервисы / уведомления
- ❌ Эквалайзер
- ❌ Плейлисты
- ❌ Загрузка обложек из сети
- ❌ Hot Reload для разрешений (flutter clean)
- ❌ Сложные анимации / жесты

---

## 9. Git workflow

1. После каждого шага: `git add -A && git commit -m "step N: description"`
2. Пуш: `git push origin main`
3. GitHub Actions собирает APK → artifact
4. APK скачивается и устанавливается на телефон

---

## 10. Проверка

- `flutter doctor` — окружение
- `flutter analyze` — линтер
- Hot Reload после изменений
- Установка APK с GitHub Actions
