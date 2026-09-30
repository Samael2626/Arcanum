#!/bin/sh
# Copia el arte real de las cartas y construye la APK de perfil (id propio: no sustituye a ARCANUM)
set -e
cd "$(dirname "$0")"
mkdir -p assets/tarot
cp ../../arcanum_app/assets/tarot/*.webp assets/tarot/
flutter build apk --profile
echo "APK: build/app/outputs/flutter-apk/app-profile.apk"
