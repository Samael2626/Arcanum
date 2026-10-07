"""Auditoria de depuracion de ARCANUM: codigo muerto, obsoleto, con fallos
conocidos o innecesario. Solo LEE: no borra ni cambia nada.

Uso (desde la raiz del repo):
    python .claude/skills/arcanum-depuracion/scripts/auditar.py [--salida informe.md]

Cada hallazgo lleva su EVIDENCIA (por que se cree que sobra) y una CONFIANZA:
  alta  = comprobado mecanicamente (nadie lo importa, patron de fallo exacto)
  media = muy probable, pero hay que mirar (uso dinamico, reflexion, rutas)
  baja  = pista para revisar a mano
"""
from __future__ import annotations

import argparse
import datetime as dt
import json
import re
import subprocess
import sys
from collections import defaultdict
from pathlib import Path

ROOT = Path(subprocess.run(["git", "rev-parse", "--show-toplevel"], capture_output=True, text=True).stdout.strip())
APP = ROOT / "arcanum_app"
API = ROOT / "arcanum-api"
HOY = dt.date.today()

hallazgos: list[dict] = []


def anota(modulo: str, tipo: str, ruta: str, que: str, evidencia: str, confianza: str) -> None:
    hallazgos.append(dict(modulo=modulo, tipo=tipo, ruta=ruta, que=que, evidencia=evidencia, confianza=confianza))


def git(*args: str) -> str:
    return subprocess.run(["git", "-C", str(ROOT), *args], capture_output=True, text=True, encoding="utf-8", errors="replace").stdout


def rel(p: Path) -> str:
    return p.relative_to(ROOT).as_posix()


def modulo_de(path: str) -> str:
    m = re.search(r"lib/features/([^/]+)/", path)
    if m:
        return m.group(1)
    m = re.search(r"packages/([^/]+)/", path)
    if m:
        return m.group(1)
    m = re.search(r"arcanum-api/app/([^/]+)/", path)
    if m:
        return "api/" + m.group(1)
    return path.split("/")[0]


# ── Dart: ficheros que nadie importa ─────────────────────────────────
IMPORT = re.compile(r"""^\s*(?:import|export|part)\s+['"]([^'"]+)['"]""", re.M)


def dart_imports(f: Path, pkg_roots: dict[str, Path]) -> list[Path]:
    out = []
    for spec in IMPORT.findall(f.read_text(encoding="utf-8", errors="replace")):
        if spec.startswith("dart:"):
            continue
        if spec.startswith("package:"):
            name, _, rest = spec[len("package:"):].partition("/")
            base = pkg_roots.get(name)
            if base:
                out.append((base / rest).resolve())
        else:
            out.append((f.parent / spec).resolve())
    return out


def audita_dart() -> None:
    if not APP.exists():
        return
    pkg_roots = {"arcanum_app": APP / "lib"}
    for pub in (APP / "packages").glob("*/pubspec.yaml"):
        name = re.search(r"^name:\s*(\S+)", pub.read_text(encoding="utf-8"), re.M).group(1)
        pkg_roots[name] = pub.parent / "lib"
    libs = [p for base in pkg_roots.values() for p in base.rglob("*.dart")]
    generados = {p.resolve() for p in libs if p.name.endswith((".g.dart", ".freezed.dart"))}
    # alcanzables desde main.dart (y desde la API publica de cada paquete)
    entradas = [APP / "lib" / "main.dart"] + [b / f"{n}.dart" for n, b in pkg_roots.items() if n != "arcanum_app"]
    vivos, pila = set(), [e.resolve() for e in entradas if e.exists()]
    while pila:
        f = pila.pop()
        if f in vivos or not f.exists():
            continue
        vivos.add(f)
        pila.extend(dart_imports(f, pkg_roots))
    # lo que solo usan los tests
    en_tests = set()
    for t in (APP / "test").rglob("*.dart"):
        en_tests.update(dart_imports(t, pkg_roots))
    for p in libs:
        r = p.resolve()
        if r in vivos or r in generados:
            continue
        if r in en_tests:
            anota(modulo_de(rel(p)), "muerto", rel(p), "Solo lo usan los tests", "Ningun fichero alcanzable desde lib/main.dart lo importa; algun test si.", "media")
        else:
            anota(modulo_de(rel(p)), "muerto", rel(p), "Fichero que nadie importa", "Ni lib/main.dart (transitivamente) ni ningun test lo importan.", "alta")

    # dependencias del pubspec que ningun fichero importa
    for pub in [APP / "pubspec.yaml", *(APP / "packages").glob("*/pubspec.yaml")]:
        txt = pub.read_text(encoding="utf-8")
        deps = re.search(r"^dependencies:\n((?:[ \t]+.*\n|\n)+)", txt, re.M)
        if not deps:
            continue
        nombres = re.findall(r"^  ([a-z_][a-z0-9_]*):", deps.group(1), re.M)
        codigo = "\n".join(p.read_text(encoding="utf-8", errors="replace") for p in pub.parent.rglob("*.dart") if "/build/" not in p.as_posix())
        for n in nombres:
            if n in ("flutter", "flutter_localizations", "cupertino_icons"):
                continue
            if f"package:{n}/" not in codigo:
                anota(modulo_de(rel(pub)), "innecesario", rel(pub), f"Dependencia sin uso: {n}", "Ningun .dart del paquete importa package:%s/. Puede ser un plugin nativo que se usa solo por registro: comprobar." % n, "media")

    # assets declarados que ningun fichero nombra
    # se buscan en el codigo y en los manifiestos JSON (los grabados se cargan por manifest.json)
    fuentes = [*(APP / "lib").rglob("*.dart"), *(APP / "assets").rglob("*.json"), APP / "pubspec.yaml"]
    codigo_app = "\n".join(p.read_text(encoding="utf-8", errors="replace") for p in fuentes)
    for a in (APP / "assets").rglob("*"):
        if a.is_dir() or a.suffix in (".txt", ".md", ".json") or "fonts" in a.parts:
            continue
        nombre = a.name
        # carpeta cargada por nombre compuesto ('assets/tarot/$slug.webp'): no se juzga fichero a fichero
        carpeta = a.parent.relative_to(APP).as_posix() + "/"
        if carpeta in codigo_app and a.suffix not in (".py", ".sh", ".ps1"):
            continue
        if a.suffix in (".py", ".sh", ".ps1"):
            anota("assets", "innecesario", rel(a), "Script dentro de assets/", "Un script no es un asset: si la carpeta esta declarada en pubspec, viaja dentro de la app.", "alta")
            continue
        if nombre not in codigo_app and a.stem not in codigo_app:
            anota("assets", "innecesario", rel(a), "Asset que ningun .dart nombra", "Ni el nombre ni la raiz del fichero aparecen en lib/. Puede cargarse por manifiesto o nombre compuesto: comprobar.", "baja")


# ── Patrones de fallo conocidos (aprendidos en ARCANUM) ──────────────
PATRONES = [
    (r"setState\(\(\)\s*=>\s*_\w+\s*=\s*_?\w*load\w*\(", "dart", "fallo", "setState devuelve un Future",
     "Flecha que asigna un Future dentro de setState: lanza en depuracion (visto en grimorio_detail el 5-oct).", "alta"),
    (r"^\s*print\(", "dart", "innecesario", "print() en codigo de la app", "En lib/ se usa debugPrint o el logger; print sale en release.", "media"),
    (r"HapticFeedback\.selectionClick\(", "dart", "fallo", "selectionClick no vibra en varios Android",
     "CLOCK_TICK no vibra en OnePlus (comprobado en el GN2200 el 6-oct). Usar lightImpact.", "media"),
    (r"llama-3\.3-70b", "any", "obsoleto", "Modelo de Groq retirado de la cuenta", "llama-3.3-70b-versatile da 404 con nuestra clave (AGENTS.md).", "alta"),
    (r"google_mobile_ads|AdMob|admob", "any", "obsoleto", "Rastro de AdMob", "AdMob salio en la 1.0.5 (build.gradle).", "media"),
    (r"except\s*:\s*$", "py", "fallo", "except desnudo", "Atrapa hasta KeyboardInterrupt; falla en silencio (regla: fallar ruidoso).", "media"),
    (r"except Exception:\s*\n\s*pass", "py", "fallo", "Excepcion tragada", "except Exception: pass oculta fallos (regla: fallar ruidoso).", "alta"),
]


def audita_patrones() -> None:
    files = [p for p in (APP / "lib").rglob("*.dart")] + [p for p in (APP / "packages").rglob("lib/**/*.dart")]
    files += [p for p in (API / "app").rglob("*.py")] if API.exists() else []
    for f in files:
        if f.name.endswith(".g.dart"):
            continue
        txt = f.read_text(encoding="utf-8", errors="replace")
        lang = "py" if f.suffix == ".py" else "dart"
        for pat, donde, tipo, que, ev, conf in PATRONES:
            if donde not in ("any", lang):
                continue
            for m in re.finditer(pat, txt, re.M):
                linea = txt.count("\n", 0, m.start()) + 1
                if tipo == "obsoleto":
                    # una mencion en un comentario o docstring suele ser historia, no uso
                    ini = txt.rfind("\n", 0, m.start()) + 1
                    pre = txt[ini:m.start()].lstrip()
                    if pre.startswith(("#", "//", "*", "///")) or (lang == "py" and txt.count('"""', 0, m.start()) % 2 == 1):
                        continue
                anota(modulo_de(rel(f)), tipo, f"{rel(f)}:{linea}", que, ev, conf)


# ── TODO/FIXME viejos ────────────────────────────────────────────────
def audita_todos() -> None:
    out = git("grep", "-n", "-E", r"\b(TODO|FIXME|HACK|XXX)\b", "--", "arcanum_app/lib", "arcanum_app/packages", "arcanum-api/app")
    for linea in out.splitlines()[:400]:
        ruta, num, texto = linea.split(":", 2)
        blame = git("blame", "-L", f"{num},{num}", "--porcelain", ruta)
        t = re.search(r"^author-time (\d+)", blame, re.M)
        if not t:
            continue
        fecha = dt.date.fromtimestamp(int(t.group(1)))
        dias = (HOY - fecha).days
        if dias >= 30:
            anota(modulo_de(ruta), "obsoleto", f"{ruta}:{num}", f"{texto.strip()[:90]}", f"Pendiente desde {fecha} ({dias} dias).", "baja")


# ── Tests que no prueban nada / saltados ─────────────────────────────
def audita_tests() -> None:
    for t in (APP / "test").rglob("*_test.dart"):
        if "capturas" in t.parts:
            continue  # generan imagenes a proposito: no comprueban nada
        txt = t.read_text(encoding="utf-8", errors="replace")
        for m in re.finditer(r"(?:testWidgets|test)\(\s*['\"]([^'\"]+)['\"]", txt):
            # cuerpo aproximado: hasta el siguiente test( o el final
            sig = re.search(r"\n\s*(?:testWidgets|test|group)\(", txt[m.end():])
            cuerpo = txt[m.end(): m.end() + (sig.start() if sig else len(txt))]
            if not re.search(r"\bexpect(Later)?\(|\bfail\(|throwsA|\bverify\w*\(", cuerpo):
                if re.search(r"paint|pump|render|toImage", cuerpo):
                    ev, conf = "Sin expect: solo comprueba que no lanza al pintar o montar. Puede bastar; mirar si deberia afirmar algo.", "baja"
                else:
                    ev, conf = "No hay expect ni fail en su cuerpo: pasa siempre.", "media"
                anota(modulo_de(rel(t)), "fallo", f"{rel(t)}:{txt.count(chr(10), 0, m.start()) + 1}", f"Test sin comprobaciones: «{m.group(1)[:60]}»", ev, conf)
        for m in re.finditer(r"skip:\s*(true|['\"])", txt):
            anota(modulo_de(rel(t)), "obsoleto", f"{rel(t)}:{txt.count(chr(10), 0, m.start()) + 1}", "Test saltado", "skip: un test que no corre no protege nada.", "baja")


# ── Python: vulture y ruff (via uvx) ─────────────────────────────────
def audita_python() -> None:
    if not API.exists():
        return
    r = subprocess.run(["uvx", "vulture", "app", "--min-confidence", "80"], cwd=API, capture_output=True, text=True, encoding="utf-8", errors="replace")
    for linea in r.stdout.splitlines():
        m = re.match(r"(.+?):(\d+): (.+) \((\d+)% confidence", linea)
        if m:
            ruta = "arcanum-api/" + m.group(1).replace("\\", "/")
            anota(modulo_de(ruta), "muerto", f"{ruta}:{m.group(2)}", m.group(3), f"vulture: {m.group(4)} % de confianza.", "alta" if int(m.group(4)) >= 90 else "media")
    r = subprocess.run(["uvx", "ruff", "check", "app", "--select", "F401,F811,F841,ERA001,B006,B904", "--output-format", "json", "--no-cache"], cwd=API, capture_output=True, text=True, encoding="utf-8", errors="replace")
    try:
        items = json.loads(r.stdout or "[]")
    except json.JSONDecodeError:
        items = []
    nombres = {"F401": ("muerto", "Import sin uso"), "F811": ("fallo", "Redefinicion sin uso"), "F841": ("muerto", "Variable asignada y no usada"),
               "ERA001": ("innecesario", "Codigo comentado"), "B006": ("fallo", "Argumento por defecto mutable"), "B904": ("fallo", "raise sin from dentro de except")}
    for it in items:
        ruta = "arcanum-api/" + Path(it["filename"]).resolve().relative_to(API.resolve()).as_posix()
        tipo, que = nombres.get(it["code"], ("fallo", it["code"]))
        if it["code"] == "F401" and ruta.endswith("__init__.py"):
            continue  # en __init__ el import suele registrar (modelos de SQLAlchemy, API publica)
        anota(modulo_de(ruta), tipo, f"{ruta}:{it['location']['row']}", f"{que}: {it['message'][:80]}", f"ruff {it['code']}.", "alta" if it["code"] in ("F401", "F841", "F811") else "media")


# ── Carpetas sueltas del repo ─────────────────────────────────────────
def audita_carpetas() -> None:
    for d in sorted(p for p in ROOT.iterdir() if p.is_dir() and not p.name.startswith(".")):
        if d.name in ("arcanum_app", "arcanum-api", "docs", "scripts", "tools"):
            continue
        ultimo = git("log", "-1", "--format=%cs", "--", d.name).strip()
        if not ultimo:
            continue
        dias = (HOY - dt.date.fromisoformat(ultimo)).days
        if dias >= 45:
            anota(d.name, "obsoleto", d.name + "/", "Carpeta sin cambios desde hace tiempo", f"Ultimo commit que la toca: {ultimo} ({dias} dias). ¿Sigue en uso?", "baja")


def informe(salida: Path | None) -> str:
    orden = {"alta": 0, "media": 1, "baja": 2}
    por_mod = defaultdict(list)
    for h in hallazgos:
        por_mod[h["modulo"]].append(h)
    cab = git("log", "-1", "--format=%h %cs %s").strip()
    lineas = [f"# Auditoria de depuracion de ARCANUM", "", f"Commit auditado: `{cab}` · {HOY}", ""]
    tot = defaultdict(int)
    for h in hallazgos:
        tot[(h["tipo"], h["confianza"])] += 1
    lineas += ["| Tipo | Alta | Media | Baja |", "|---|---|---|---|"]
    for tipo in ("muerto", "fallo", "obsoleto", "innecesario"):
        lineas.append(f"| {tipo} | {tot[(tipo, 'alta')]} | {tot[(tipo, 'media')]} | {tot[(tipo, 'baja')]} |")
    for mod in sorted(por_mod, key=lambda m: (-len(por_mod[m]), m)):
        lineas += ["", f"## {mod} ({len(por_mod[mod])})", ""]
        for h in sorted(por_mod[mod], key=lambda h: (orden[h["confianza"]], h["tipo"], h["ruta"])):
            lineas.append(f"- **[{h['confianza']}] {h['tipo']}** `{h['ruta']}`: {h['que']}. _{h['evidencia']}_")
    texto = "\n".join(lineas) + "\n"
    if salida:
        salida.write_text(texto, encoding="utf-8")
        salida.with_suffix(".json").write_text(json.dumps(hallazgos, ensure_ascii=False, indent=1), encoding="utf-8")
    return texto


def main() -> None:
    ap = argparse.ArgumentParser()
    ap.add_argument("--salida", type=Path)
    args = ap.parse_args()
    for paso in (audita_dart, audita_patrones, audita_todos, audita_tests, audita_python, audita_carpetas):
        try:
            paso()
        except Exception as e:  # una parte que falla no tumba el resto, pero se dice
            print(f"AVISO: {paso.__name__} fallo: {e}", file=sys.stderr)
    texto = informe(args.salida)
    if not args.salida:
        sys.stdout.reconfigure(encoding="utf-8")
        print(texto)
    print(f"{len(hallazgos)} hallazgos", file=sys.stderr)


if __name__ == "__main__":
    main()
