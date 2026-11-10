// Hero drawings for the store art (egg, Meteor Drake, pedestal). Each is drawn in its own local space
// with the origin at its centre and returns an SVG string; callers place it with translate/scale.
const S = require('./shapes.cjs');
const { gloss, path, ellipse, rect, poly, blob, vgrad, rad, lin, f, INK, uid } = S;

// ---------- the Meteor Egg ----------
function eggPathD(w, h) {
  return `M0 ${-h / 2}C${w * .42} ${-h / 2} ${w * .5} ${-h * .12} ${w * .5} ${h * .12}C${w * .5} ${h * .38} ${w * .28} ${h / 2} 0 ${h / 2}C${-w * .28} ${h / 2} ${-w * .5} ${h * .38} ${-w * .5} ${h * .12}C${-w * .5} ${-h * .12} ${-w * .42} ${-h / 2} 0 ${-h / 2}Z`;
}
function egg(w, h, { crack = true } = {}) {
  const d = eggPathD(w, h);
  const bb = [-w / 2, -h / 2, w, h];
  const body = gloss(path(d, bb), { top: '#FFC25A', bottom: '#E8661A', lip: '#9A3E10', sw: w * .026, shine: .3 });
  const c = S.uid('eggc');
  const zig = [];
  const zy = -h * .1, n = 9;
  for (let i = 0; i <= n; i++) zig.push([-w * .55 + i * (w * 1.1 / n), zy + (i % 2 ? -h * .045 : h * .045)]);
  const zigD = 'M' + zig.map(p => `${f(p[0])} ${f(p[1])}`).join('L');
  const capD = `M${-w} ${-h}H${w}V${f(zy)}` + zig.slice().reverse().map(p => `L${f(p[0])} ${f(p[1])}`).join('') + 'Z';
  const spots = [[-.2, .18, .13, .1, 12], [.2, .3, .15, .1, -10], [-.08, .43, .1, .07, 4], [.28, .02, .08, .06, 0]];
  const dots = [[-.38, .05], [.36, .16], [.04, .26], [-.3, .36]];
  const cap = `<g clip-path="url(#${c})"><path d="${capD}" fill="#FFE9B8"/><path d="${capD}" fill="#FFF8DE" opacity=".5" transform="translate(${f(-w * .06)} ${f(-h * .04)}) scale(.9)"/>
    <path d="${zigD}" fill="none" stroke="#FFF078" stroke-width="${f(w * .035)}" stroke-linejoin="round"/><path d="${zigD}" fill="none" stroke="#B06806" stroke-width="${f(w * .012)}" transform="translate(0 ${f(w * .03)})" stroke-linejoin="round"/>
    ${spots.map(([x, y, rx, ry, rot]) => `<ellipse cx="${f(x * w)}" cy="${f(y * h)}" rx="${f(rx * w)}" ry="${f(ry * h)}" transform="rotate(${rot} ${f(x * w)} ${f(y * h)})" fill="#8A3A1E" stroke="#5A200F" stroke-width="${f(w * .012)}"/>`).join('')}
    ${dots.map(([x, y]) => `<circle cx="${f(x * w)}" cy="${f(y * h)}" r="${f(w * .02)}" fill="#E21A38"/>`).join('')}</g>`;
  const crackD = `M${f(-w * .08)} ${f(-h * .34)}L${f(w * .02)} ${f(-h * .22)}L${f(-w * .06)} ${f(-h * .13)}L${f(w * .06)} ${f(-h * .02)}L${f(-w * .02)} ${f(h * .08)}L${f(w * .08)} ${f(h * .17)}`;
  const crackSvg = crack ? `<path d="${crackD}" fill="none" stroke="${INK}" stroke-width="${f(w * .05)}" stroke-linejoin="round" stroke-linecap="round"/><path d="${crackD}" fill="none" stroke="#FFFBD0" stroke-width="${f(w * .026)}" stroke-linejoin="round" stroke-linecap="round"/>` : '';
  return `<defs><clipPath id="${c}"><path d="${d}"/></clipPath></defs>${body}${cap}${crackSvg}
    <path d="M${f(-w * .34)} ${f(-h * .18)}Q${f(-w * .4)} ${f(h * .05)} ${f(-w * .3)} ${f(h * .22)}" fill="none" stroke="white" stroke-opacity=".5" stroke-width="${f(w * .035)}" stroke-linecap="round"/>`;
}

// a round gold stepped pedestal, origin at the centre of the top face
function pedestal(w) {
  const steps = [[w * 1.0, w * .2, 0, ['#FFF078', '#FFB21E'], '#B06806'], [w * .84, w * .17, -w * .035, ['#FFE070', '#F0A010'], '#A05C06']];
  const out = [];
  steps.forEach(([sw, sh, dy, [a, b], lip], i) => {
    out.push(gloss(ellipse(0, w * .1 + i * -w * .0 + dy + (i ? -w * .02 : 0), sw / 2, sh / 2), { top: a, bottom: b, lip, sw: w * .02, lipDy: w * .05, shine: .25 }));
  });
  return `<g transform="translate(0 ${f(w * .06)})">${out.join('')}</g>`;
}

// ---------- the Meteor Drake (legendary): navy body, orange belly and spikes, red wings, blue snout ----------
// Faces left. Local box roughly x 0..800, y 0..720. Returns { halo, body } where halo is a white silhouette for rim light.
function drake() {
  const navyTop = '#4C5CA8', navyBot = '#222B66', navyLip = '#121842';
  const sil = [];
  const parts = [];
  const add = (desc, o, silhouette = true) => { parts.push(gloss(desc, o)); if (silhouette) sil.push(desc); };

  // a bat wing from a shoulder at (ox, oy), sweeping up and back (to the right, the drake faces left)
  const wingAt = (ox, oy, k, c, bones) => {
    const P = (x, y) => `${f(ox + x * k)} ${f(oy + y * k)}`;
    const d = `M${P(0, 0)}C${P(20, -100)} ${P(90, -210)} ${P(190, -280)}C${P(200, -214)} ${P(188, -168)} ${P(164, -146)}C${P(190, -110)} ${P(166, -78)} ${P(132, -70)}C${P(140, -30)} ${P(104, -8)} ${P(74, -4)}Z`;
    const w = path(d, [ox, oy - 280 * k, 200 * k, 290 * k]);
    return { w, svg: gloss(w, { top: c[0], bottom: c[1], lip: c[2], sw: 9, shine: .18 }) + `<path d="M${P(0, 0)}L${P(190, -280)}M${P(0, 0)}L${P(164, -146)}M${P(0, 0)}L${P(132, -70)}" stroke="${INK}" stroke-width="9" stroke-linecap="round" fill="none"/><path d="M${P(0, 0)}L${P(190, -280)}" stroke="${bones}" stroke-width="4" stroke-linecap="round" fill="none"/>` };
  };
  const far = wingAt(540, 340, 1.18, ['#C8203E', '#6E0E28', '#45081A'], '#34407E');
  parts.push(far.svg); sil.push(far.w);

  // tail with a spade tip
  const tail = path('M610 500C690 520 750 500 790 430C800 400 780 380 762 394C740 450 700 462 640 450Z', [610, 380, 190, 140]);
  add(tail, { top: navyTop, bottom: navyBot, lip: navyLip, sw: 9, shine: .18 });
  add(poly([[760, 392], [812, 362], [800, 420], [782, 448]]), { top: '#FFB24A', bottom: '#FF801A', lip: '#B04A10', sw: 8, shine: 0 }, false);
  [[650, 442], [700, 452], [738, 430]].forEach(([x, y]) => add(poly([[x - 16, y + 6], [x + 4, y - 36], [x + 20, y + 2]]), { top: '#FFC25A', bottom: '#FF801A', lip: '#B04A10', sw: 7, shine: 0, noLip: true }, false));

  // far legs
  const farLeg = (x, y) => add(rect(x, y, 66, 130, 30), { top: '#34407E', bottom: '#1A2152', lip: navyLip, sw: 9, shine: .1 });
  farLeg(330, 560); farLeg(520, 575);
  // body
  const body = ellipse(440, 470, 215, 150);
  add(body, { top: navyTop, bottom: navyBot, lip: navyLip, sw: 10, shine: .22 });
  // belly
  const belly = path('M300 520C340 590 540 600 590 520C560 560 330 570 300 520Z', [300, 520, 290, 80]);
  parts.push(gloss(path('M290 505C310 590 560 610 595 505C560 535 330 540 290 505Z', [290, 505, 305, 105]), { top: '#FFC25A', bottom: '#FF801A', lip: '#B04A10', sw: 7, shine: .3, noLip: true }));
  // back spikes
  [[400, 330], [460, 322], [520, 340], [572, 372]].forEach(([x, y], i) => add(poly([[x - 26, y + 22], [x + 2, y - 46 + i * 4], [x + 30, y + 24]]), { top: '#FFC25A', bottom: '#FF801A', lip: '#B04A10', sw: 8, shine: 0, noLip: true }, false));
  // near legs
  const nearLeg = (x, y) => {
    add(rect(x, y, 84, 150, 38), { top: '#4C5CA8', bottom: '#222B66', lip: navyLip, sw: 10, shine: .22 });
    parts.push(gloss(rect(x - 6, y + 118, 96, 38, 19), { top: '#FFC25A', bottom: '#FF801A', lip: '#B04A10', sw: 8, shine: .3, noLip: true }));
    sil.push(rect(x - 6, y + 118, 96, 38, 19));
  };
  nearLeg(352, 540); nearLeg(470, 552);
  // near wing (in front of the body)
  const near = wingAt(456, 360, 1.0, ['#FF5068', '#A8183A', '#5A0A1E'], '#4C5CA8');
  parts.push(near.svg); sil.push(near.w);
  // frill and horns behind the head
  [[330, 300, 420, 220], [290, 280, 360, 170]].forEach(([x, y, tx, ty]) => add(poly([[x - 20, y + 30], [tx, ty], [x + 52, y + 36]]), { top: '#FFC25A', bottom: '#FF801A', lip: '#B04A10', sw: 8, shine: 0, noLip: true }, false));
  // horns sweep back over the neck
  add(path('M200 300C176 222 224 150 332 100C300 160 296 220 274 282Z', [176, 100, 156, 200]), { top: '#D4DCF6', bottom: '#8494CC', lip: '#4A5894', sw: 8, shine: .3 });
  add(path('M286 276C300 212 360 160 446 146C404 186 390 232 362 288Z', [286, 146, 160, 142]), { top: '#D4DCF6', bottom: '#8494CC', lip: '#4A5894', sw: 8, shine: .3 });
  // head: a rounded box of a head with a heavy brow, a long snout and a toothy grin
  add(ellipse(262, 372, 128, 112), { top: '#5666B8', bottom: '#2A357A', lip: navyLip, sw: 10, shine: .26 });
  add(path('M62 392C62 350 130 332 214 350C260 360 262 440 214 470C150 500 62 460 62 392Z', [62, 332, 200, 168]), { top: '#7B94E0', bottom: '#4560B8', lip: '#2A3C84', sw: 9, shine: .3 });
  parts.push(`<ellipse cx="96" cy="392" rx="9" ry="12" fill="${INK}"/><ellipse cx="136" cy="378" rx="8" ry="11" fill="${INK}"/>`);
  parts.push(`<path d="M80 438Q140 480 218 446" fill="none" stroke="${INK}" stroke-width="8" stroke-linecap="round"/><path d="M168 462L182 488L198 456Z" fill="white" stroke="${INK}" stroke-width="5" stroke-linejoin="round"/><path d="M112 456L124 476L136 458Z" fill="white" stroke="${INK}" stroke-width="5" stroke-linejoin="round"/>`);
  // eyes (big, shiny) with orange brows
  [[250, 340, 33, 36], [328, 338, 29, 33]].forEach(([x, y, rx, ry]) => {
    parts.push(`<ellipse cx="${x}" cy="${y}" rx="${rx}" ry="${ry}" fill="white" stroke="${INK}" stroke-width="8"/><ellipse cx="${x - 7}" cy="${y + 4}" rx="${rx * .56}" ry="${ry * .66}" fill="${INK}"/><circle cx="${x - 14}" cy="${y - 8}" r="${rx * .24}" fill="white"/><circle cx="${x + 2}" cy="${y + 14}" r="${rx * .12}" fill="white"/>`);
  });
  parts.push(`<path d="M206 306Q250 282 286 306M302 300Q338 286 362 308" fill="none" stroke="#FF801A" stroke-width="13" stroke-linecap="round"/>`);
  parts.push(`<circle cx="214" cy="410" r="16" fill="#FF6876" opacity=".45"/>`);
  const halo = sil.map(d => d.shape(`fill="#FFFFFF" stroke="#FFFFFF" stroke-width="40" stroke-linejoin="round"`)).join('');
  return { halo, body: parts.join('') };
}

module.exports = { egg, pedestal, drake, eggPathD };
