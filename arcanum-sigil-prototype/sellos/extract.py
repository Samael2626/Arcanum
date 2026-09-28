"""Reproduce los sellos y caracteres de Agrippa II.22 desde el escaneo de la
Wellcome Collection (Internet Archive b30335231, 1651, dominio publico).
Para cada pieza: recorte del original, tinta separada del papel, facsimil y
calco vectorial. Nada se dibuja a mano: todo sale de la pagina.

Uso: descargar las hojas del escaneo a hNNN.jpg en el directorio actual,
  curl -L https://archive.org/download/b30335231/page/nNNN_w2400.jpg -o hNNN.jpg
(NNN = 257..265) y ejecutar: python extract.py && python build_data.py"""
import json, os
import numpy as np
from PIL import Image
from skimage import measure, morphology
import vtracer

OUT = r'D:\Proyectos\Arcanum\arcanum-sigil-prototype\sellos'
os.makedirs(OUT, exist_ok=True)
# (id, hoja, pagina impresa, caja en la vista reducida x0,x1,y0,y1 (x4 = original))
ITEMS = [
  ('saturno-sello', 257, 244, (170, 325, 395, 525)), ('saturno-inteligencia', 257, 244, (410, 520, 410, 505)), ('saturno-espiritu', 257, 244, (595, 715, 400, 500)),
  ('jupiter-sello', 257, 244, (180, 345, 750, 890)), ('jupiter-inteligencia', 257, 244, (380, 525, 775, 860)), ('jupiter-espiritu', 257, 244, (575, 707, 760, 870)),
  ('marte-sello', 258, 245, (45, 255, 390, 565)), ('marte-inteligencia', 258, 245, (270, 460, 435, 540)), ('marte-espiritu', 258, 245, (480, 575, 400, 580)),
  ('sol-sello', 259, 246, (177, 345, 440, 640)), ('sol-inteligencia', 259, 246, (375, 515, 460, 600)), ('sol-espiritu', 259, 246, (545, 690, 455, 600)),
  ('venus-sello', 260, 247, (52, 235, 455, 665)), ('venus-inteligencia', 260, 247, (315, 495, 450, 620)),
  ('venus-espiritu', 261, 248, (275, 430, 425, 620)), ('venus-inteligencias', 261, 248, (565, 700, 425, 580)),
  ('mercurio-sello', 262, 249, (55, 235, 475, 655)), ('mercurio-inteligencia', 262, 249, (315, 465, 475, 625)),
  ('mercurio-espiritu', 263, 250, (415, 512, 480, 598)),
  ('luna-sello', 264, 251, (55, 305, 515, 760)), ('luna-espiritu', 264, 251, (335, 530, 515, 695)),
  ('luna-espiritu-de-los-espiritus', 265, 252, (210, 420, 485, 660)), ('luna-inteligencia-de-las-inteligencias', 265, 252, (445, 685, 490, 670)),
]
PAD = 10  # en la vista reducida
# Ajustes por pieza: umbral de tinta (mas alto = recoge trazos finos) y
# fraccion minima de mancha respecto a la mayor (quita motas y borrones)
TUNE = {
  'saturno-espiritu': {'minfrac': .02}, 'jupiter-espiritu': {'minfrac': .02},
  'venus-inteligencia': {'minfrac': .03},  # borron de imprenta bajo el caracter
  'luna-espiritu-de-los-espiritus': {'thr': .6, 'minfrac': .012}, 'luna-inteligencia-de-las-inteligencias': {'thr': .66},
  'jupiter-sello': {'minfrac': .01}, 'venus-sello': {'minfrac': .02}, 'sol-sello': {'minfrac': .006},
}

manifest = []
for iid, leaf, page, (x0, x1, y0, y1) in ITEMS:
    tune = TUNE.get(iid, {})
    im = Image.open(f'h{leaf}.jpg').convert('RGB')
    box = ((x0 - PAD) * 4, (y0 - PAD) * 4, (x1 + PAD) * 4, (y1 + PAD) * 4)
    crop = im.crop(box)
    g = np.asarray(crop.convert('L')).astype(float)
    # papel: mediana local amplia; tinta: bastante mas oscura que su papel
    paper = np.median(g)
    ink = g < paper * tune.get('thr', 0.55)
    ink = morphology.remove_small_objects(ink, 60)
    lab = measure.label(ink, connectivity=2)
    props = measure.regionprops(lab)
    if not props:
        print('SIN TINTA', iid); continue
    big = max(p.area for p in props)
    h, w = ink.shape
    keep = np.zeros_like(ink)
    for p in props:
        r0, c0, r1, c1 = p.bbox
        touches = r0 == 0 or c0 == 0 or r1 == h or c1 == w
        # fuera: motas y restos de texto cortados por el borde del recorte
        if p.area < max(80, big * tune.get('minfrac', 0.004)) or (touches and p.area < big * 0.3):
            continue
        keep[lab == p.label] = True
    rows, cols = np.where(keep)
    m = 30
    r0, r1 = max(rows.min() - m, 0), min(rows.max() + m, h)
    c0, c1 = max(cols.min() - m, 0), min(cols.max() + m, w)
    keep = keep[r0:r1, c0:c1]
    fac = crop.crop((c0, r0, c1, r1))
    # facsimil: la pagina tal cual, reducida a un tamano razonable
    fac.thumbnail((900, 900))
    fac.save(os.path.join(OUT, f'{iid}.jpg'), quality=88)
    # tinta limpia en negro para el calco
    bw = Image.fromarray(np.where(keep, 0, 255).astype(np.uint8)).convert('RGB')
    tmp = os.path.join(OUT, f'_{iid}_tinta.png')
    bw.save(tmp)
    svg_path = os.path.join(OUT, f'{iid}.svg')
    vtracer.convert_image_to_svg_py(tmp, svg_path, colormode='binary', mode='spline',
                                    filter_speckle=8, corner_threshold=60, length_threshold=4.0,
                                    splice_threshold=45, path_precision=2)
    os.remove(tmp)
    manifest.append({'id': iid, 'leaf': leaf, 'page': page,
                     'box': [int(box[0] + c0), int(box[1] + r0), int(box[0] + c1), int(box[1] + r1)],
                     'size': [int(c1 - c0), int(r1 - r0)], 'inkComponents': int(measure.label(keep).max())})
    print(f'{iid:42} p.{page} hoja {leaf}  {c1 - c0}x{r1 - r0}  trazos={manifest[-1]["inkComponents"]}')
json.dump(manifest, open(os.path.join(OUT, '_extract.json'), 'w'), indent=1)
