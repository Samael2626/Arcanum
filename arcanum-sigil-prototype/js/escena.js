'use strict';
// ════════════════════════════════════════════════════════════════
//  Escena: una sola lista de dibujo para el lienzo y para el SVG
//  Antes el lienzo y la exportacion se dibujaban por caminos separados;
//  ahora ambos leen los mismos grupos y solo cambia el emisor. Lo que se
//  ve es lo que se exporta (salvo las marcas de edicion, que no son obra).
//
//  Grupo: { layer, color, w?, cap?, op?, dx?, dy?, sigil?, items }
//   items: trazos { d, fill?, op?, units?, grad? } o primitivas de capa
//   { k: circle | poly | text | glyph } (las pinta paintPrims/primsSVG).
//   grad: { id, type: linear | radial, x1..y2 | cx cy r, stops: [[off, color, op]] }
// ════════════════════════════════════════════════════════════════
const isPrimGroup = g => g.items.length > 0 && !!g.items[0].k;
const hexRGB = hex => { const h = hex.replace('#', ''); const n = parseInt(h.length === 3 ? h.replace(/./g, c => c + c) : h, 16); return [n >> 16 & 255, n >> 8 & 255, n & 255]; };
const hexA = (hex, a) => `rgba(${hexRGB(hex).join(',')},${String(+a.toFixed(3)).replace(/^0\./, '.')})`;
const luminance = hex => { const [r, g, b] = hexRGB(hex); return (0.2126 * r + 0.7152 * g + 0.0722 * b) / 255; };
const opAttr = op => op != null && op < 1 ? ` opacity="${+op.toFixed(3)}"` : '';

// ── Emisor SVG ──────────────────────────────────────────────────
function gradSVG(gr) {
  const stops = gr.stops.map(([o, c, a = 1]) => `<stop offset="${o}" stop-color="${c}"${a < 1 ? ` stop-opacity="${a}"` : ''}/>`).join('');
  return gr.type === 'radial'
    ? `<radialGradient id="${gr.id}" gradientUnits="userSpaceOnUse" cx="${gr.cx}" cy="${gr.cy}" r="${gr.r}">${stops}</radialGradient>`
    : `<linearGradient id="${gr.id}" gradientUnits="userSpaceOnUse" x1="${gr.x1}" y1="${gr.y1}" x2="${gr.x2}" y2="${gr.y2}">${stops}</linearGradient>`;
}
function groupSVG(g) {
  const tf = g.dx || g.dy ? ` transform="translate(${g.dx || 0} ${g.dy || 0})"` : '';
  const gop = g.op == null ? 1 : g.op;
  if (isPrimGroup(g)) return `<g data-layer="${g.layer}"${tf}>${primsSVG(gop < 1 ? g.items.map(p => ({ ...p, op: p.op * gop })) : g.items, g.color)}</g>`;
  const sq = g.cap === 'square', defs = [];
  const body = g.items.map(it => {
    const op = opAttr(gop * (it.op == null ? 1 : it.op));
    if (it.grad) { defs.push(gradSVG(it.grad)); return `<path d="${it.d}" fill="url(#${it.grad.id})" stroke="none"${op}/>`; }
    return it.fill ? `<path d="${it.d}" fill="${g.color}" stroke="none"${op}/>` : `<path d="${it.d}"${op}/>`;
  }).join('');
  const stroke = g.w ? ` fill="none" stroke="${g.color}" stroke-width="${+g.w.toFixed(2)}" stroke-linecap="${sq ? 'square' : 'round'}" stroke-linejoin="${sq ? 'miter' : 'round'}"` : '';
  return `<g data-layer="${g.layer}"${stroke}${tf}>${defs.length ? `<defs>${defs.join('')}</defs>` : ''}${body}</g>`;
}
const sceneSVG = groups => groups.map(groupSVG).join('');

// ── Emisor canvas ───────────────────────────────────────────────
const pathCache = new Map();
function pathOf(d) {
  let p = pathCache.get(d);
  if (!p) { if (pathCache.size > 4000) pathCache.clear(); p = new Path2D(d); pathCache.set(d, p); }
  return p;
}
function gradCanvas(ctx, gr) {
  const g = gr.type === 'radial' ? ctx.createRadialGradient(gr.cx, gr.cy, 0, gr.cx, gr.cy, gr.r) : ctx.createLinearGradient(gr.x1, gr.y1, gr.x2, gr.y2);
  for (const [o, c, a = 1] of gr.stops) g.addColorStop(o, hexA(c, a));
  return g;
}
// opt.minW: grosor minimo de los trazos del sigilo (solo miniaturas)
// opt.dim(item): factor de opacidad (resaltar la letra elegida)
function paintScene(ctx, groups, opt = {}) {
  for (const g of groups) {
    ctx.save();
    if (g.dx || g.dy) ctx.translate(g.dx || 0, g.dy || 0);
    const gop = g.op == null ? 1 : g.op;
    if (isPrimGroup(g)) { paintPrims(ctx, gop < 1 ? g.items.map(p => ({ ...p, op: p.op * gop })) : g.items, g.color); ctx.restore(); continue; }
    const sq = g.cap === 'square';
    ctx.lineCap = sq ? 'square' : 'round'; ctx.lineJoin = sq ? 'miter' : 'round';
    ctx.strokeStyle = g.color; ctx.fillStyle = g.color;
    if (g.w) ctx.lineWidth = g.sigil && opt.minW ? Math.max(g.w, opt.minW) : g.w;
    for (const it of g.items) {
      ctx.globalAlpha = gop * (it.op == null ? 1 : it.op) * (opt.dim ? opt.dim(it) : 1);
      const p = pathOf(it.d);
      if (it.grad) { ctx.fillStyle = gradCanvas(ctx, it.grad); ctx.fill(p); ctx.fillStyle = g.color; }
      else if (it.fill) ctx.fill(p);
      else ctx.stroke(p);
    }
    ctx.restore();
  }
}

// ── Lienzo de las familias que se dibujan desde su SVG ─────────
// (Rosa-Cruz, Kamea, sellos): el lienzo pinta el mismo SVG que se exporta.
// Mientras carga uno nuevo se ve el anterior: no parpadea.
const svgImg = { key: '', img: null };
function paintSVGImage(ctx, svg) {
  if (svgImg.key !== svg) {
    const img = new Image();
    img.onload = () => { if (svgImg.key === svg) { svgImg.img = img; render(); } };
    img.src = 'data:image/svg+xml;charset=utf-8,' + encodeURIComponent(svg);
    svgImg.key = svg;
  }
  if (svgImg.img && svgImg.img.complete) ctx.drawImage(svgImg.img, 0, 0, SIZE, SIZE);
}
