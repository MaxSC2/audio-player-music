#!/usr/bin/env bash
# Готовит отсутствующие Gradle-файлы для локальной сборки на ПК.
# CI генерирует их через `flutter create`; локально — этот скрипт.
set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
cd "$ROOT"

command -v flutter >/dev/null 2>&1 || {
  echo "flutter не найден в PATH" >&2
  exit 1
}

if [[ -f android/settings.gradle.kts && -f android/app/build.gradle.kts ]]; then
  echo "Gradle-файлы уже на месте — ничего не меняю."
  flutter pub get
  exit 0
fi

SEED="$(mktemp -d)"
cleanup() { rm -rf "$SEED"; }
trap cleanup EXIT

echo "Генерирую Android Gradle-обвязку через flutter create..."
flutter create --org com.example --project-name audio_player \
  --platforms=android "$SEED" >/dev/null

mkdir -p android/gradle/wrapper android/app
cp "$SEED/android/settings.gradle.kts" android/settings.gradle.kts
cp "$SEED/android/build.gradle.kts" android/build.gradle.kts
cp "$SEED/android/gradlew" android/gradlew
cp "$SEED/android/gradlew.bat" android/gradlew.bat
chmod +x android/gradlew
cp "$SEED/android/gradle/wrapper/gradle-wrapper.jar" \
  android/gradle/wrapper/gradle-wrapper.jar
cp "$SEED/android/gradle/wrapper/gradle-wrapper.properties" \
  android/gradle/wrapper/gradle-wrapper.properties

# app/build.gradle.kts берём из репозитория: там versionName/versionCode,
# signingConfig из key.properties и release-fallback на debug-подпись.
cp android/app/build.gradle.kts.tmpl android/app/build.gradle.kts

flutter pub get
echo "Готово: android/settings.gradle.kts и android/app/build.gradle.kts созданы."
echo "Release-подпись: положите keystore и android/app/key.properties (см. README)."
