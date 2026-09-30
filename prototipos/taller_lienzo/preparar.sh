#!/bin/sh
# Copia las fuentes de la app y construye el APK en modo profile (medidas reales).
# Id propio (com.arcanum.taller_lienzo): se instala junto a ARCANUM sin sustituirla.
set -e
cd "$(dirname "$0")"
mkdir -p assets/fonts
for f in CrimsonPro-400.ttf CrimsonPro-400italic.ttf ArcanumGlifos-Regular.ttf NotoSerifHebrew-Regular.ttf; do
  cp ../../arcanum_app/assets/fonts/$f assets/fonts/
done
flutter build apk --profile
