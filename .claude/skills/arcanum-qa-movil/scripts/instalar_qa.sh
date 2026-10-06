#!/bin/bash
# Build profile de ARCANUM con id propio (com.arcanum.magick.<modulo>) que se
# instala AL LADO de la app de Play, nunca encima. Restaura siempre los
# ficheros que toca, aunque la compilacion falle.
# Uso: instalar_qa.sh <modulo> [ruta_arcanum_app] [--local]
#   --local: la app habla con el back en 127.0.0.1:8000 (adb reverse)
set -u
MOD="${1:?falta el modulo (sigilos, mesaqa...)}"
APP="${2:-$(git rev-parse --show-toplevel)/arcanum_app}"
LOCAL="${3:-}"
ID="com.arcanum.magick.$MOD"
GS_SRC="/d/Proyectos/Arcanum/arcanum_app/android/app/google-services.json"

cd "$APP" || exit 1
# QA_SOLO_COMPILAR=1: compila sin movil (se instala despues con adb install -r)
[ "${QA_SOLO_COMPILAR:-}" = 1 ] || adb get-state >/dev/null 2>&1 || { echo "SIN MOVIL: adb no ve ningun dispositivo (cable, depuracion USB, autorizar el PC)"; exit 1; }
[ -f "$GS_SRC" ] || { echo "FALTA $GS_SRC (no se versiona)"; exit 1; }
had_gs=0; [ -f android/app/google-services.json ] && had_gs=1 && cp android/app/google-services.json /tmp/gs.bak
restore() {
  git checkout -- android/app/build.gradle
  if [ $had_gs = 1 ]; then cp /tmp/gs.bak android/app/google-services.json; else rm -f android/app/google-services.json; fi
  echo "RESTAURADO build.gradle y google-services.json"
}
trap restore EXIT

sed -i "s#applicationId = \"com.arcanum.magick\"#applicationId = \"$ID\"#" android/app/build.gradle
grep -q "applicationId = \"$ID\"" android/app/build.gradle || { echo "no se pudo cambiar el applicationId"; exit 1; }
sed "s#\"package_name\": \"com.arcanum.magick\"#\"package_name\": \"$ID\"#" "$GS_SRC" > android/app/google-services.json

DEFINES=()
if [ "$LOCAL" = "--local" ]; then
  DEFINES=(--dart-define=API_BASE_URL=http://127.0.0.1:8000)
  adb reverse tcp:8000 tcp:8000
fi

export GRADLE_USER_HOME='D:\Softwares\gradle-taller'
APK=build/app/outputs/flutter-apk/app-profile.apk
# fuera el APK viejo: si la compilacion falla no se instala el de antes
rm -f "$APK"
flutter build apk --profile "${DEFINES[@]}" > /tmp/qa_build.log 2>&1
rc=$?
if [ $rc -ne 0 ] || [ ! -f "$APK" ]; then
  echo "COMPILACION FALLIDA (rc=$rc). Lo relevante:"
  grep -E "What went wrong|error|Error|FAILURE|Could not|> " /tmp/qa_build.log | head -25
  exit 1
fi
tail -2 /tmp/qa_build.log

[ "${QA_SOLO_COMPILAR:-}" = 1 ] && { cp "$APK" "/d/tmp/arcanum-$MOD-qa.apk"; echo "COMPILADO: /d/tmp/arcanum-$MOD-qa.apk"; exit 0; }

# nunca sobre la de Play
[ "$ID" = "com.arcanum.magick" ] && { echo "PROHIBIDO instalar sobre com.arcanum.magick"; exit 1; }
adb install -r "$APK" 2>&1 | tail -1
adb shell dumpsys package "$ID" | grep -E "versionName|lastUpdateTime" | head -2
