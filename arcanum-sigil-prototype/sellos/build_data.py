"""Une los calcos (SVG de vtracer) con su ficha y escribe sellos/sellos.js."""
import io, json, os, re
DIR = r'D:\Proyectos\Arcanum\arcanum-sigil-prototype\sellos'
man = {m['id']: m for m in json.load(open(os.path.join(DIR, '_extract.json')))}
PLANETS = {'saturno': ('saturn', 'Saturno', '♄'), 'jupiter': ('jupiter', 'Júpiter', '♃'), 'marte': ('mars', 'Marte', '♂'),
           'sol': ('sun', 'Sol', '☉'), 'venus': ('venus', 'Venus', '♀'), 'mercurio': ('mercury', 'Mercurio', '☿'), 'luna': ('moon', 'Luna', '☽')}
# Rotulo del grabado (ingles de 1651) y nombre de la tabla de nombres (p. 243)
META = {
  'sello': ('Sello de {P}', 'Of {E}.', None),
  'inteligencia': ('Carácter de la Inteligencia de {P}', 'Of the Intelligence of {E}.', 'Inteligencia'),
  'espiritu': ('Carácter del Espíritu de {P}', 'Of the Spirit of {E}.', 'Espíritu'),
  'inteligencias': ('Carácter de las Inteligencias de {P}', 'Of the Intelligences of {E}.', 'Inteligencias'),
  'espiritu-de-los-espiritus': ('Carácter del Espíritu de los espíritus de {P}', 'Of the Spirit of the spirits of the {E}.', 'Espíritu de los espíritus'),
  'inteligencia-de-las-inteligencias': ('Carácter de la Inteligencia de las inteligencias de {P}', 'Of the Intelligence of the Intelligences of the {E}.', None),
}
EN = {'saturn': 'Saturn', 'jupiter': 'Jupiter', 'mars': 'Mars', 'sun': 'the Sun', 'venus': 'Venus', 'mercury': 'Mercury', 'moon': 'the Moon'}
NOTES = {
  'venus-inteligencia': 'Bajo el carácter hay un borrón de imprenta: está en el facsímil y no en el trazo.',
  'luna-espiritu-de-los-espiritus': 'Tinta muy tenue y transparencia del reverso (el espíritu de la Luna de la p. 251): algún tramo fino se corta en el trazo. Manda el facsímil.',
  'luna-inteligencia-de-las-inteligencias': 'Su nombre llega corrupto en Agrippa; por eso no tiene trazado en la Kamea.',
  'marte-inteligencia': 'La Kamea no reproduce esta figura con ningún método conocido.',
}
out = []
for iid, m in man.items():
    pkey, kind = iid.split('-', 1)
    pid, pname, sym = PLANETS[pkey]
    title, en, role = META[kind]
    svg = io.open(os.path.join(DIR, iid + '.svg'), encoding='utf-8').read()
    w, h = re.search(r'width="(\d+)" height="(\d+)"', svg).groups()
    paths = []
    for pm in re.finditer(r'<path d="([^"]+)"[^>]*?transform="translate\(([-\d.]+),([-\d.]+)\)"', svg):
        paths.append([pm.group(1), round(float(pm.group(2)), 2), round(float(pm.group(3)), 2)])
    assert paths, iid
    en_label = en.replace('{E}', EN[pid])
    if kind.endswith('-espiritus') or kind.endswith('-inteligencias'):
        en_label = en_label.replace('the the', 'the')
    out.append({'id': iid, 'planet': pid, 'planetName': pname, 'sym': sym, 'kind': kind,
                'title': title.replace('{P}', pname if pid not in ('sun', 'moon') else ('el Sol' if pid == 'sun' else 'la Luna')).replace('de el ', 'del '),
                'engraved': en_label, 'role': role, 'page': m['page'], 'leaf': m['leaf'], 'box': m['box'],
                'w': int(w), 'h': int(h), 'paths': paths, 'note': NOTES.get(iid, '')})
order = ['saturn', 'jupiter', 'mars', 'sun', 'venus', 'mercury', 'moon']
kinds = list(META)
out.sort(key=lambda x: (order.index(x['planet']), kinds.index(x['kind'])))
js = ('// Sellos y caracteres de Agrippa, lib. II, cap. 22 (Londres, 1651).\n'
      '// Calcados del escaneo de la Wellcome Collection (Internet Archive b30335231,\n'
      '// dominio publico) por extract.py: recorte, tinta separada del papel y calco.\n'
      '// Generado: no editar a mano.\n'
      'window.SEALS = ' + json.dumps(out, ensure_ascii=False, separators=(',', ':')) + ';\n')
io.open(os.path.join(DIR, 'sellos.js'), 'w', encoding='utf-8', newline='\n').write(js)
print(len(out), 'piezas,', round(len(js) / 1024), 'KB')
for o in out: print(f"{o['id']:42} {o['title'][:55]:55} p.{o['page']} trazos={len(o['paths'])}")
