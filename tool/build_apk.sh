#!/usr/bin/env bash
# Собирает release APK и кладёт в корень проекта ровно один файл NeonWave.apk.
# На ПК: tool/build_apk.sh
# VERSION_CODE=133 tool/build_apk.sh  — переопределить versionCode.
set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
cd "$ROOT"

if [[ ! -f android/app/build.gradle.kts || ! -f android/settings.gradle.kts ]]; then
  tool/setup_local_android.sh
fi

export VERSION_CODE="${VERSION_CODE:-133}"

echo "Сборка release APK (VERSION_CODE=$VERSION_CODE)..."
flutter build apk --release

APK="build/app/outputs/flutter-apk/app-release.apk"
[[ -f "$APK" ]] || { echo "APK не найден: $APK" >&2; exit 1; }

rm -f "$ROOT/NeonWave.apk" "$ROOT/app-release.apk"
cp "$APK" "$ROOT/NeonWave.apk"
echo "Готово: $ROOT/NeonWave.apk"
ls -lh "$ROOT/NeonWave.apk"
