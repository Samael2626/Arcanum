#!/bin/bash
# Toques seguros en el movil compartido. Cada orden que toca comprueba antes
# que delante esta el paquete propio; si no, se niega (exit 3).
# Uso: adb_seguro.sh <orden> [args]   (PKG=com.arcanum.magick.sigilos por defecto)
#   foco                  paquete en primer plano
#   abrir                 lanza la app propia (solo si delante esta el escritorio o ella misma)
#   dump                  vuelca la pantalla a /tmp/ui.xml y lista textos tocables
#   tocar_texto "<txt>"   toca el nodo cuyo text o content-desc contiene <txt>
#   tocar x y             toque por coordenadas (solo nodos sin texto, p. ej. el menu)
#   escribir "<txt>"      escribe en el campo con foco
#   ocultar_teclado       atras solo si hay teclado (atras sin teclado cierra la pantalla)
#   atras                 tecla atras (cuidado: cierra la pantalla)
#   arrastrar x1 y1 x2 y2 [ms]
#   captura <nombre>      guarda qa/<nombre>.png
#   log                   ultimas lineas relevantes de logcat
export MSYS_NO_PATHCONV=1
# la consola de Windows no es UTF-8: sin esto, un ✶ en pantalla tumba el script
export PYTHONIOENCODING=utf-8
UI_LOCAL="${TMPDIR:-/tmp}/arcanum_ui.xml"
export UI_WIN="$(cygpath -w "$UI_LOCAL" 2>/dev/null || echo "$UI_LOCAL")"
PKG="${PKG:-com.arcanum.magick.sigilos}"
OUT="${QA_DIR:-qa}"

foco() { adb shell dumpsys window | grep -m1 mCurrentFocus | sed -E 's/.*u0 ([^ /}]+).*/\1/'; }

teclado() { adb shell dumpsys input_method | grep -q "mInputShown=true"; }

exige_foco() {
  local f i; f=$(foco)
  # en una transicion el foco vale null un instante: se reintenta
  for i in 1 2 3; do case "$f" in *null*|"") sleep 1; f=$(foco) ;; *) break ;; esac; done
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
    adb shell uiautomator dump /sdcard/ui.xml >/dev/null && adb pull /sdcard/ui.xml "$UI_LOCAL" >/dev/null 2>&1
    python - <<'PY'
import os,re
x=open(os.environ['UI_WIN'],encoding='utf-8').read()
for m in re.finditer(r'<node [^>]*?text="([^"]*)"[^>]*?content-desc="([^"]*)"[^>]*?clickable="(\w+)"[^>]*?bounds="([^"]*)"',x):
    t,d,c,b=m.groups()
    if t or d: print(('*' if c=='true' else ' '),(t or d)[:60].replace('&#10;',' '),b)
PY
    ;;
  tocar_texto)
    exige_foco
    adb shell uiautomator dump /sdcard/ui.xml >/dev/null && adb pull /sdcard/ui.xml "$UI_LOCAL" >/dev/null 2>&1
    xy=$(TXT="$2" python - <<'PY'
import os,re
x=open(os.environ['UI_WIN'],encoding='utf-8').read(); want=os.environ['TXT']
for m in re.finditer(r'<node [^>]*?text="([^"]*)"[^>]*?content-desc="([^"]*)"[^>]*?bounds="\[(\d+),(\d+)\]\[(\d+),(\d+)\]"',x):
    t,d,a,b,c,e=m.groups()
    if want in t or want in d:
        print((int(a)+int(c))//2,(int(b)+int(e))//2); break
PY
)
    [ -z "$xy" ] && { echo "NO ENCONTRADO: '$2'" >&2; exit 4; }
    adb shell input tap $xy; echo "tocado '$2' en $xy" ;;
  tocar) exige_foco; adb shell input tap "$2" "$3"; echo "tocado $2,$3" ;;  # solo si el nodo no tiene texto
  escribir)
    # el texto se pierde si el teclado aun no esta: se espera a que aparezca
    exige_foco
    for i in 1 2 3 4 5 6; do teclado && break; sleep .5; done
    teclado || { echo "SIN TECLADO: el campo no tomo el foco; toca el campo y repite" >&2; exit 5; }
    adb shell input text "$(printf '%s' "$2" | sed 's/ /%s/g')" ;;
  ocultar_teclado)
    # atras SOLO si el teclado esta abierto: si no, atras cierra la pantalla
    exige_foco; if teclado; then adb shell input keyevent 4; echo "teclado cerrado"; else echo "no habia teclado"; fi ;;
  atras) exige_foco; adb shell input keyevent 4 ;;
  arrastrar) exige_foco; adb shell input swipe "$2" "$3" "$4" "$5" "${6:-400}" ;;
  captura)
    # solo la app propia: nada de capturar lo que otra persona tiene delante
    exige_foco
    mkdir -p "$OUT"; adb exec-out screencap -p > "$OUT/$2.png" && echo "$OUT/$2.png" ;;
  log) adb logcat -d -t 400 | grep -E "ARCANUM|flutter|Exception|overflowed|FATAL" | tail -40 ;;
  *) sed -n 2,16p "$0"; exit 1 ;;
esac
