# Audio Player

Локальный музыкальный плеер для Android.

## Сборка

### Локальная сборка (требуется Flutter SDK)

```bash
flutter pub get
flutter run
```

### CI/CD сборка (GitHub Actions)

1. Пушите код в ветку `main`
2. GitHub Actions автоматически соберёт APK
3. Скачайте артефакт `app-release.apk` из GitHub Actions

## Установка APK

1. Скачайте `app-release.apk` на телефон
2. Разрешите установку из неизвестных источников
3. Установите APK

## Требования

- Android 7.0+ (API 24)
- Разрешение на доступ к аудио
