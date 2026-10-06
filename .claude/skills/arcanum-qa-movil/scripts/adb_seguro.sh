#!/bin/bash
# Toques seguros en el movil compartido. Cada orden que toca comprueba antes
# que delante esta el paquete propio; si no, se niega (exit 3).
# Uso: adb_seguro.sh <orden> [args]   (PKG=com.arcanum.magick.sigilos por defecto)
#   foco                  paquete en primer plano
#   abrir                 lanza la app propia (solo si delante esta el escritorio o ella misma)
#   dump                  vuelca la pantalla a /tmp/ui.xml y lista textos tocables
#   tocar_texto "<txt>"   toca el nodo cuyo text o content-desc contiene <txt>
#   escribir "<txt>"      escribe en el campo con foco
#   atras                 tecla atras
#   arrastrar x1 y1 x2 y2 [ms]
#   captura <nombre>      guarda qa/<nombre>.png
#   log                   ultimas lineas relevantes de logcat
export MSYS_NO_PATHCONV=1
PKG="${PKG:-com.arcanum.magick.sigilos}"
OUT="${QA_DIR:-qa}"

foco() { adb shell dumpsys window | grep -m1 mCurrentFocus | sed -E 's/.* ([^ /]+)\/.*/\1/'; }

exige_foco() {
  local f; f=$(foco)
  if [ "$f" != "$PKG" ]; then
    echo "PARADO: delante esta '$f', no $PKG. Otra sesion o persona puede estar usandolo: avisar, no tocar." >&2
    exit 3
  fi
}

case "${1:-}" in
  foco) foco ;;
  abrir)
    f=$(foco)
    case "$f" in
      "$PKG"|*launcher*|*Launcher*) adb shell monkey -p "$PKG" -c android.intent.category.LAUNCHER 1 >/dev/null 2>&1; sleep 2; foco ;;
      *) echo "PARADO: delante esta '$f'. No se trae la app por encima." >&2; exit 3 ;;
    esac ;;
  dump)
    exige_foco
    adb shell uiautomator dump /sdcard/ui.xml >/dev/null && adb pull /sdcard/ui.xml /tmp/ui.xml >/dev/null
    python - <<'PY'
import re
x=open('/tmp/ui.xml',encoding='utf-8').read()
for m in re.finditer(r'<node [^>]*?text="([^"]*)"[^>]*?content-desc="([^"]*)"[^>]*?clickable="(\w+)"[^>]*?bounds="([^"]*)"',x):
    t,d,c,b=m.groups()
    if t or d: print(('*' if c=='true' else ' '),(t or d)[:60].replace('&#10;',' '),b)
PY
    ;;
  tocar_texto)
    exige_foco
    adb shell uiautomator dump /sdcard/ui.xml >/dev/null && adb pull /sdcard/ui.xml /tmp/ui.xml >/dev/null
    xy=$(TXT="$2" python - <<'PY'
import os,re
x=open('/tmp/ui.xml',encoding='utf-8').read(); want=os.environ['TXT']
for m in re.finditer(r'<node [^>]*?text="([^"]*)"[^>]*?content-desc="([^"]*)"[^>]*?bounds="\[(\d+),(\d+)\]\[(\d+),(\d+)\]"',x):
    t,d,a,b,c,e=m.groups()
    if want in t or want in d:
        print((int(a)+int(c))//2,(int(b)+int(e))//2); break
PY
)
    [ -z "$xy" ] && { echo "NO ENCONTRADO: '$2'" >&2; exit 4; }
    adb shell input tap $xy; echo "tocado '$2' en $xy" ;;
  escribir) exige_foco; adb shell input text "$(printf '%s' "$2" | sed 's/ /%s/g')" ;;
  atras) exige_foco; adb shell input keyevent 4 ;;
  arrastrar) exige_foco; adb shell input swipe "$2" "$3" "$4" "$5" "${6:-400}" ;;
  captura)
    mkdir -p "$OUT"; adb exec-out screencap -p > "$OUT/$2.png" && echo "$OUT/$2.png" ;;
  log) adb logcat -d -t 400 | grep -E "ARCANUM|flutter|Exception|overflowed|FATAL" | tail -40 ;;
  *) sed -n 2,16p "$0"; exit 1 ;;
esac
