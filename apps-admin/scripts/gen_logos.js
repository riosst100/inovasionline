// Renders the admin variants of the Inovasi Online logo: same mark as
// apps/assets/images/logo.svg, dark gray background with a hint of brand
// green, orange "Admin" pill.
// Usage (needs `npm i @resvg/resvg-js` somewhere on NODE_PATH):
//   node scripts/gen_logos.js assets/images ../apps/assets/fonts/Montserrat-Bold.ttf
//   dart run flutter_launcher_icons && dart run flutter_native_splash:create
const fs = require('fs');
const path = require('path');
const { Resvg } = require('@resvg/resvg-js');

const [, , outDir, fontFile] = process.argv;
// Dark gray, turning faintly green towards the bottom-right corner.
// The native splash and the intro use the solid #2A3436 (kept in pubspec.yaml / intro.dart).
const BG_FROM = '#33393B';
const BG_TO = '#1E3431';
const GRADIENT = `<defs><linearGradient id="bg" x1="0" y1="0" x2="1" y2="1">
  <stop offset="0" stop-color="${BG_FROM}"/><stop offset="1" stop-color="${BG_TO}"/></linearGradient></defs>`;
const CREAM = '#FAF6EF';
const ORANGE = '#FB7A2E';

// Mark in logo.svg coordinates; bbox x 20.5..85.5, y 19.4..76.5.
const MARK = `
  <rect x="30" y="42" width="11" height="32" rx="5.5" fill="${CREAM}"/>
  <path d="M22 27 A18 18 0 0 1 49 27" fill="none" stroke="${CREAM}" stroke-width="3" stroke-linecap="round" opacity="0.55"/>
  <path d="M27 30 A11 11 0 0 1 44 30" fill="none" stroke="${CREAM}" stroke-width="3" stroke-linecap="round" opacity="0.8"/>
  <circle cx="35.5" cy="34" r="6.5" fill="${ORANGE}"/>
  <circle cx="64" cy="55" r="16" fill="none" stroke="${CREAM}" stroke-width="11"/>`;
const MARK_BOX = { x: 20.5, y: 19.4, w: 65, h: 57.1 };

/** Mark + pill below it, fitted to [width] and centred on (cx, cy). */
function content(cx, cy, width) {
  const s = width / MARK_BOX.w;
  const markH = MARK_BOX.h * s;
  const pillW = width * 0.72;
  const pillH = width * 0.25;
  const gap = width * 0.07;
  const top = cy - (markH + gap + pillH) / 2;
  const tx = cx - width / 2 - MARK_BOX.x * s;
  const ty = top - MARK_BOX.y * s;
  const pillY = top + markH + gap;
  return `
    <g transform="translate(${tx} ${ty}) scale(${s})">${MARK}</g>
    <rect x="${cx - pillW / 2}" y="${pillY}" width="${pillW}" height="${pillH}" rx="${pillH / 2}" fill="${ORANGE}"/>
    <text x="${cx}" y="${pillY + pillH / 2}" dy="0.35em" text-anchor="middle"
      font-family="Montserrat" font-weight="700" font-size="${pillH * 0.62}" fill="#FFFFFF">Admin</text>`;
}

function render(file, size, body) {
  const svg = `<svg xmlns="http://www.w3.org/2000/svg" width="${size}" height="${size}" viewBox="0 0 ${size} ${size}">${body}</svg>`;
  const png = new Resvg(svg, {
    font: { fontFiles: [fontFile], loadSystemFonts: false, defaultFontFamily: 'Montserrat' },
  }).render().asPng();
  fs.writeFileSync(path.join(outDir, file), png);
  console.log(file);
}

// Launcher icon (iOS + legacy Android): full-bleed, the OS applies the mask.
render('logo_admin_icon.png', 1024, `${GRADIENT}<rect width="1024" height="1024" fill="url(#bg)"/>${content(512, 512, 640)}`);

// Adaptive icon foreground: flutter_launcher_icons insets it a further 16%,
// which keeps this size inside the circular-mask safe zone.
render('logo_admin_foreground.png', 1024, content(512, 512, 620));

// Adaptive icon background layer.
render('logo_admin_background.png', 1024, `${GRADIENT}<rect width="1024" height="1024" fill="url(#bg)"/>`);

// In-app logo (login screen), like logo_app.png: rounded tile.
render('logo_app.png', 512,
  `${GRADIENT}<rect x="32" y="32" width="448" height="448" rx="96" fill="url(#bg)"/>${content(256, 256, 300)}`);

/** Just the mark, fitted into a [size] square centred on (cx, cy). */
function markOnly(cx, cy, size) {
  // A 74-unit square around the mark's bbox centre (53, 48).
  const s = size / 74;
  return `<g transform="translate(${cx - 53 * s} ${cy - 48 * s}) scale(${s})">${MARK}</g>`;
}

// Native splash, like the customer app: only the mark, 256px in a 1152px canvas
// (= 64dp at 4x). The Flutter intro (lib/features/shell/intro.dart) starts from
// an identical frame using logo_splash_mark.png, so both must stay in sync.
render('logo_splash.png', 1152, markOnly(576, 576, 256));
render('logo_splash_mark.png', 256, markOnly(128, 128, 256));
