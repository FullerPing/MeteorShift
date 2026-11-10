// Thumbnail 4: REBIRTH x5. A diagonal before/after split. x5 = Config.Rebirth.CashMult (bar sales multiplier per listed rank).
const path = require('node:path');
const S = require('../lib/shapes.cjs');
const Hh = require('../lib/hero.cjs');
const { letters } = require('../lib/type.cjs');
const { render } = require('../lib/raster.cjs');
const W = 1920, H = 1080;
const OUT = path.resolve(__dirname, '../../../assets/marketing/v2/thumb-4-rebirth.png');

const IRON = { top: '#EEF2FA', front: ['#C8D0E0', '#8E9AB4'], side: '#5C6884' };
const GOLD = { top: '#FFF2A0', front: ['#FFD850', '#F0A010'], side: '#B86E08' };

module.exports = async function build() {
  const r = S.rng(44);
  // the slash: from (1190, 0) down to (730, 1080)
  const slash = (y) => 1190 - (460 * y / H);
  const beforeClip = `0,0 1190,0 730,${H} 0,${H}`;
  const afterClip = `1190,0 ${W},0 ${W},${H} 730,${H}`;

  const bgB = S.vgrad('#B6C6E2', '#6C80AA');
  const bgA = S.rad([[0, '#FFE6FF'], [.35, '#E58CFF'], [.75, '#9A32EA'], [1, '#5A14B4']], { cx: .62, cy: .45, r: .8 });
  let body = `<defs>${bgB.defs}${bgA.defs}<clipPath id="cb"><polygon points="${beforeClip}"/></clipPath><clipPath id="ca"><polygon points="${afterClip}"/></clipPath></defs>`;
  body += `<g clip-path="url(#cb)"><rect width="${W}" height="${H}" fill="${bgB.ref}"/>`;
  for (let i = 0; i < 6; i++) body += `<circle cx="${S.f(r(0, 1000))}" cy="${S.f(r(0, H))}" r="${S.f(r(20, 70))}" fill="#FFFFFF" opacity=".12"/>`;
  body += `<ellipse cx="380" cy="900" rx="440" ry="60" fill="#0E1834" opacity=".16"/></g>`;
  body += `<g clip-path="url(#ca)"><rect width="${W}" height="${H}" fill="${bgA.ref}"/>`;
  body += S.rays(1390, 520, 20, 1700, { color: '#FFFFFF', alpha: .2, rot: .1, spread: .5 });
  for (let i = 0; i < 10; i++) body += `<circle cx="${S.f(r(800, W))}" cy="${S.f(r(0, H))}" r="${S.f(r(20, 80))}" fill="#FFFFFF" opacity="${S.f(r(.06, .14))}"/>`;
  body += `</g>`;

  // BEFORE: three plain iron bars on a plinth and a tiny basic miner
  const plinth = S.gloss(S.ellipse(330, 905, 330, 70), { top: '#DCE4F4', bottom: '#98A8C8', lip: '#5C6C90', sw: 7, shine: .2 });
  let stack = S.bar(110, 730, 210, 86, 72, IRON) + S.bar(335, 730, 210, 86, 72, IRON) + S.bar(222, 644, 210, 86, 72, IRON);
  const tiny = `<g transform="translate(640 940) scale(.95)">${Hh.miner({ pose: 'idle', armour: 'blue' })}</g>`;
  const x1 = letters('x1', 175, { faceTop: '#FFFFFF', faceBottom: '#D8E4F8', lipColor: '#5C6C90' });
  const before = `${plinth}${stack}${tiny}<g transform="translate(140 340) rotate(-4)">${x1.body}</g>`;

  // AFTER: portal shrine
  const cx = 1400;
  const ground = S.gloss(S.ellipse(cx, 770, 330, 74), { top: '#FFF078', bottom: '#FFB21E', lip: '#B06806', sw: 8, shine: .25 });
  const step2 = S.gloss(S.ellipse(cx, 745, 270, 56), { top: '#FFE070', bottom: '#F0A010', lip: '#A05C06', sw: 7, shine: .25 });
  const ringG = S.lin([[0, '#FFFFFF'], [.5, '#FF9AE0'], [1, '#C42AA8']]);
  const swirl = S.rad([[0, '#FFFFFF'], [.3, '#FFC0F0'], [.7, '#C84AE8'], [1, '#6A1AB4']]);
  let portal = `<defs>${ringG.defs}${swirl.defs}</defs>`;
  portal += `<ellipse cx="${cx}" cy="500" rx="226" ry="268" fill="${S.INK}" stroke="${S.INK}" stroke-width="12"/>`;
  portal += `<ellipse cx="${cx}" cy="500" rx="214" ry="256" fill="${swirl.ref}"/>`;
  for (let k = 0; k < 4; k++) portal += `<path d="M${cx} 500m-${30 + k * 38} 0a${30 + k * 38} ${40 + k * 48} 0 1 1 ${60 + k * 76} 0" fill="none" stroke="#FFFFFF" stroke-width="${12 - k * 2}" stroke-linecap="round" opacity="${(.9 - k * .15).toFixed(2)}" transform="rotate(${k * 70 - 30} ${cx} 500)"/>`;
  portal += `<ellipse cx="${cx}" cy="500" rx="214" ry="256" fill="none" stroke="${ringG.ref}" stroke-width="30"/><ellipse cx="${cx}" cy="500" rx="214" ry="256" fill="none" stroke="${S.INK}" stroke-width="5"/>`;
  // columns
  const column = x => S.gloss(S.rect(x - 34, 420, 68, 340, 22), { top: '#FFFFFF', bottom: '#C8D8F4', lip: '#7C94C8', sw: 7, shine: .25 }) + S.gloss(S.rect(x - 46, 394, 92, 40, 14), { top: '#FFF078', bottom: '#FFB21E', lip: '#B06806', sw: 7, shine: .3 });
  portal += column(cx - 330) + column(cx + 330);
  portal += `<g transform="translate(${cx} 190)">${S.starburst(0, 0, 70, { points: 5, inner: .45, top: '#FFFBD0', bottom: '#FFC030', sw: 8 })}</g>`;

  // gold pile: rows of bars along the bottom right
  let pile = '';
  const rows = [[9, 1040], [8, 985], [7, 930]];
  rows.forEach(([n, y], ri) => {
    const bw = 150, gap = 10, total = n * (bw + gap);
    const x0 = 1330 - total / 2 + 340;
    for (let i = 0; i < n; i++) {
      const jitter = r(-6, 6);
      pile += S.bar(x0 + i * (bw + gap) + (ri % 2) * 30, y - 60 + jitter, bw, 54, 50, GOLD);
    }
  });
  let coins = '';
  for (let i = 0; i < 10; i++) coins += S.coin(r(900, 1860), r(740, 1000), r(24, 36), r(-40, 40));
  for (let i = 0; i < 8; i++) coins += S.coin(r(1000, 1850), r(80, 420), r(22, 34), r(-40, 40));
  const hero = `<g transform="translate(1000 1005) scale(1.3)">${Hh.miner({ pose: 'cheer', armour: 'orange' })}</g>`;
  const ribbon = `<g transform="translate(1230 735)">${S.banner('REBIRTH', 480, 112, { top: '#FF9AE0', bottom: '#E02A9C', lip: '#8C1070', tilt: -4 })}</g>`;

  const t = letters('x5', 270, { faceTop: '#FFF078', faceBottom: '#FFB21E', lipColor: '#AA4608' });
  const x5 = `<g transform="translate(1300 330) rotate(-4)">${t.body}</g>`;
  const up = S.arrow(1790, 380, 230, { angle: -90, thick: 1.25, face: ['#B2FF4A', '#32C41E'], lip: '#166E12' });

  // slash with ink edge
  const line = `<line x1="1190" y1="-20" x2="722" y2="${H + 20}" stroke="${S.INK}" stroke-width="42"/><line x1="1190" y1="-20" x2="722" y2="${H + 20}" stroke="#FFFFFF" stroke-width="18"/>`;
  const sparks = [];
  for (let i = 0; i < 30; i++) sparks.push([r(840, 1890), r(40, 1000), r(10, 34), { fill: r() > .5 ? '#FFFFFF' : '#FFE9FF', ink: r() > .5, rot: r(0, 30) }]);

  const all = `${body}${before}${line}${ground}${step2}${portal}${pile}${hero}${coins}${ribbon}${x5}${up}${S.sparkles(sparks)}`;
  const fx = `<ellipse cx="${cx}" cy="500" rx="360" ry="400" fill="#FF8AE8" opacity=".5"/><ellipse cx="1500" cy="300" rx="420" ry="220" fill="#FFF078" opacity=".28"/>${S.sparkles(sparks.slice(0, 16).map(s => [s[0], s[1], s[2] * 1.2, { fill: '#FFFFFF', ink: false }]))}`;
  await render(OUT, W, H, all, { fxBody: fx });
};
