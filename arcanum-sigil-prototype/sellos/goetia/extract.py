"""Reproduce los 80 sellos de la Goetia (72 espiritus, 8 con sello doble)
desde las laminas de L. W. de Laurence, The Lesser Key of Solomon, Goetia
(Chicago, 1916), reimpresion de la ed. Mathers-Crowley (1904). Escaneo de la
Harold B. Lee Library (BYU) en Internet Archive: lesserkeyofsolom00dela.

Uso: descargar las laminas (hojas 7 a 10) a LN.jpg,
  curl -L https://archive.org/download/lesserkeyofsolom00dela/page/nN_w3000.jpg -o LN.jpg
y ejecutar este script. Nada se dibuja a mano: todo sale de la lamina."""
import json, os
import numpy as np
from PIL import Image
from scipy import ndimage as ndi
from skimage import measure, morphology
import vtracer

OUT = r'D:\Proyectos\Arcanum\arcanum-sigil-prototype\sellos\goetia'
os.makedirs(OUT, exist_ok=True)
# Orden de figuras por lamina (filas de 4, de arriba abajo). Las laminas 2 y 3
# van intercaladas: asi estan impresas.
PLATES = {7: list(range(1, 25)),
          8: [25, 26, 27, 28, 33, 34, 35, 36, 41, 42, 43, 44, 49, 50, 51, 52, 57, 58, 59, 60, 65, 66, 67, 68],
          9: [29, 30, 31, 32, 37, 38, 39, 40, 45, 46, 47, 48, 53, 54, 55, 56, 61, 62, 63, 64, 69, 70, 71, 72],
          10: list(range(73, 81))}
# Segundas figuras de un mismo espiritu (leidas en el borde de cada sello)
SECOND = {10, 15, 17, 22, 31, 48, 54, 78}

def cells(n):
    g = np.asarray(Image.open(f'L{n}.jpg').convert('L')).astype(float)
    ink = g < np.median(g) * 0.6
    if n == 10:  # solo las dos filas de sellos de arriba
        ink[int(ink.shape[0] * 0.42):] = False
    hl = ndi.binary_opening(ink, structure=np.ones((1, 220)))
    vl = ndi.binary_opening(ink, structure=np.ones((220, 1)))
    lab = measure.label(ink & ~hl & ~vl, connectivity=2)
    rings = [p.bbox for p in measure.regionprops(lab)
             if 330 < p.bbox[2] - p.bbox[0] < 560 and 330 < p.bbox[3] - p.bbox[1] < 560 and 0.8 < (p.bbox[2] - p.bbox[0]) / (p.bbox[3] - p.bbox[1]) < 1.25]
    rings.sort(key=lambda b: -(b[2] - b[0]) * (b[3] - b[1]))
    kept = []
    for b in rings:
        cy, cx = (b[0] + b[2]) / 2, (b[1] + b[3]) / 2
        if not any(k[0] <= cy <= k[2] and k[1] <= cx <= k[3] for k in kept):
            kept.append(b)
    kept.sort(key=lambda b: (round(((b[0] + b[2]) / 2) / 540), (b[1] + b[3]) / 2))
    return kept

manifest = []
spirit = 0
figs = {}
for n, order in PLATES.items():
    boxes = cells(n)
    assert len(boxes) == len(order), (n, len(boxes))
    im = Image.open(f'L{n}.jpg').convert('RGB')
    for fig, b in zip(order, boxes):
        figs[fig] = (n, b, im)
for fig in range(1, 81):
    if fig not in SECOND:
        spirit += 1
    n, b, im = figs[fig]
    cell = im.crop((b[1] - 12, b[0] - 12, b[3] + 12, b[2] + 12))
    g = np.asarray(cell.convert('L')).astype(float)
    ink = g < np.median(g) * 0.68
    # el sello es el circulo mayor: fuera de el (numero de figura, restos de la
    # rejilla) no se calca
    lab = measure.label(ink, connectivity=2)
    ring = max(measure.regionprops(lab), key=lambda p: (p.bbox[2] - p.bbox[0]) * (p.bbox[3] - p.bbox[1]))
    r0, c0, r1, c1 = ring.bbox
    cy, cx, rad = (r0 + r1) / 2, (c0 + c1) / 2, max(r1 - r0, c1 - c0) / 2 + 4
    yy, xx = np.mgrid[:ink.shape[0], :ink.shape[1]]
    dist2 = (yy - cy) ** 2 + (xx - cx) ** 2
    # restos de la rejilla: rectas largas, solo junto al borde (no las barras del sello)
    lines = ndi.binary_opening(ink, structure=np.ones((1, 140))) | ndi.binary_opening(ink, structure=np.ones((140, 1)))
    ink &= ~(lines & (dist2 > (rad * 0.9) ** 2))
    ink &= dist2 <= (rad - 3) ** 2
    # piezas pequenas pegadas al borde exterior: restos de la rejilla, no del sello
    lab2 = measure.label(ink, connectivity=2)
    for p in measure.regionprops(lab2):
        py, px = p.centroid
        r0_, c0_, r1_, c1_ = p.bbox
        thin = min(r1_ - r0_, c1_ - c0_) <= 14 and max(r1_ - r0_, c1_ - c0_) >= 40
        far = (py - cy) ** 2 + (px - cx) ** 2 > (rad * 0.93) ** 2
        if far and (p.area < 500 or thin):
            ink[lab2 == p.label] = False
    ink = morphology.remove_small_objects(ink, max_size=25)
    y0, y1, x0, x1 = int(max(cy - rad - 8, 0)), int(min(cy + rad + 8, ink.shape[0])), int(max(cx - rad - 8, 0)), int(min(cx + rad + 8, ink.shape[1]))
    ink = ink[y0:y1, x0:x1]
    fac = cell.crop((x0, y0, x1, y1))
    fid = f'g{fig:02d}'
    fac.thumbnail((520, 520)); fac.save(os.path.join(OUT, f'{fid}.jpg'), quality=85)
    tmp = os.path.join(OUT, f'_{fid}.png')
    # calco a 360 px: de sobra para pantalla completa y mucho mas ligero
    bw = Image.fromarray(np.where(ink, 0, 255).astype(np.uint8))
    k = 360 / max(bw.size)
    bw = bw.resize((round(bw.width * k), round(bw.height * k)), Image.LANCZOS).point(lambda v: 0 if v < 128 else 255)
    bw.convert('RGB').save(tmp)
    vtracer.convert_image_to_svg_py(tmp, os.path.join(OUT, f'{fid}.svg'), colormode='binary', mode='spline',
                                    filter_speckle=6, corner_threshold=60, length_threshold=4.0,
                                    splice_threshold=45, path_precision=1)
    os.remove(tmp)
    manifest.append({'fig': fig, 'spirit': spirit, 'second': fig in SECOND, 'leaf': n,
                     'box': [int(b[1]), int(b[0]), int(b[3]), int(b[2])], 'w': int(bw.width), 'h': int(bw.height)})
assert spirit == 72, spirit
json.dump(manifest, open(os.path.join(OUT, '_extract.json'), 'w'), indent=1)
print(len(manifest), 'figuras,', spirit, 'espiritus')
