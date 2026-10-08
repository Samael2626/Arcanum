"""Une los calcos de la Goetia con su ficha y escribe sellos/goetia/goetia.js.
Nombres: encabezado de cada espiritu en el texto (pp. 22-45), con los errores
del OCR corregidos contra el escaneo. Rangos y metales: la lista clasificada
del propio libro (pp. 47-48)."""
import io, json, os, re
DIR = r'D:\Proyectos\Arcanum\arcanum-sigil-prototype\sellos\goetia'
man = json.load(open(os.path.join(DIR, '_extract.json')))
sp = {int(k): v for k, v in json.load(open(os.path.join(DIR, '_spirits_ocr.json'), encoding='utf-8')).items() if v}
# OCR corregido contra el escaneo
sp[9] = {'name': 'Paimon', 'page': 24}
sp[44]['name'] = 'Shax'
sp[72]['name'] = 'Andromalius'
# Lista clasificada, pp. 47-48 ("Classified list of the 72 chief spirits")
RANK = {
  'Rey': ('oro', [1, 9, 13, 20, 32, 45, 51, 61, 68]),
  'Duque': ('cobre', [2, 6, 8, 11, 15, 16, 18, 19, 23, 26, 28, 29, 41, 42, 47, 49, 52, 54, 56, 60, 64, 67, 71]),
  'Príncipe o prelado': ('estaño', [3, 12, 22, 33, 36, 55, 70]),
  'Marqués': ('plata', [4, 7, 14, 24, 27, 30, 35, 37, 43, 44, 59, 63, 65, 66, 69]),
  'Presidente': ('mercurio', [5, 10, 17, 21, 25, 31, 33, 39, 48, 53, 57, 58, 61, 62]),
  'Conde': ('cobre y plata a partes iguales', [17, 21, 25, 27, 34, 38, 40, 45, 46, 72]),
  'Caballero': ('plomo', [50]),
}
count = sum(len(v[1]) for v in RANK.values())
assert count == 79 and len({n for v in RANK.values() for n in v[1]}) == 72, count
NOTES = {63: 'Las letras del borde son muy tenues en la lámina; la E sale incompleta en el trazo. Manda el facsímil.'}
out = []
for m in man:
    s = m['spirit']
    raw = re.sub(r'\s+', ' ', sp[s]['name']).strip()
    parts = [p.strip() for p in re.split(r',?\s+or\s+|,\s+', raw) if p.strip()]
    name, alt = parts[0], parts[1:]
    ranks = [(r, metal) for r, (metal, ids) in RANK.items() if s in ids]
    svg = io.open(os.path.join(DIR, f"g{m['fig']:02d}.svg"), encoding='utf-8').read()
    w, h = re.search(r'width="(\d+)" height="(\d+)"', svg).groups()
    paths = [[pm.group(1), round(float(pm.group(2)), 1), round(float(pm.group(3)), 1)]
             for pm in re.finditer(r'<path d="([^"]+)"[^>]*?transform="translate\(([-\d.]+),([-\d.]+)\)"', svg)]
    assert paths, m['fig']
    out.append({'id': f"goetia-{m['fig']:02d}", 'src': 'goetia1916', 'fig': m['fig'], 'spirit': s, 'name': name, 'alt': alt,
                'second': m['second'], 'ranks': [r for r, _ in ranks], 'metals': [mt for _, mt in ranks],
                'page': sp[s]['page'], 'leaf': m['leaf'], 'w': int(w), 'h': int(h), 'paths': paths,
                'title': f"Sello de {name}" + (' (segundo)' if m['second'] else ''), 'note': NOTES.get(m['fig'], '')})
js = ('// Los 72 espiritus de la Goetia (80 sellos: 8 tienen dos), de las laminas de\n'
      '// L. W. de Laurence, The Lesser Key of Solomon, Goetia (Chicago, 1916),\n'
      '// reimpresion de la ed. Mathers-Crowley (1904). Escaneo de la Harold B. Lee\n'
      '// Library (BYU) en Internet Archive: lesserkeyofsolom00dela.\n'
      '// Generado por build_goetia.py: no editar a mano.\n'
      'window.GOETIA = ' + json.dumps(out, ensure_ascii=False, separators=(',', ':')) + ';\n')
io.open(os.path.join(DIR, 'goetia.js'), 'w', encoding='utf-8', newline='\n').write(js)
print(len(out), 'sellos,', round(len(js) / 1024), 'KB')
for o in out[:3] + out[8:10] + out[-2:]:
    print(o['fig'], o['spirit'], o['name'], o['alt'], o['ranks'], o['metals'], 'p.', o['page'], 'hoja', o['leaf'])
