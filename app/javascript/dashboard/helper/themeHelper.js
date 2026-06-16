import { LocalStorage } from 'shared/helpers/localStorage';
import { LOCAL_STORAGE_KEYS } from 'dashboard/constants/localStorage';

// ── Brand color theming ────────────────────────────────────────────────────────

function hexToRgb(hex) {
  const clean = hex.replace('#', '');
  const full = clean.length === 3
    ? clean.split('').map(c => c + c).join('')
    : clean;
  const num = parseInt(full, 16);
  return { r: (num >> 16) & 255, g: (num >> 8) & 255, b: num & 255 };
}

function rgbToHsl(r, g, b) {
  const rn = r / 255, gn = g / 255, bn = b / 255;
  const max = Math.max(rn, gn, bn), min = Math.min(rn, gn, bn);
  let h, s;
  const l = (max + min) / 2;
  if (max === min) {
    h = s = 0;
  } else {
    const d = max - min;
    s = l > 0.5 ? d / (2 - max - min) : d / (max + min);
    switch (max) {
      case rn: h = ((gn - bn) / d + (gn < bn ? 6 : 0)) / 6; break;
      case gn: h = ((bn - rn) / d + 2) / 6; break;
      default: h = ((rn - gn) / d + 4) / 6;
    }
  }
  return { h: h * 360, s, l };
}

function hslToRgb(h, s, l) {
  const hn = h / 360;
  if (s === 0) {
    const v = Math.round(l * 255);
    return { r: v, g: v, b: v };
  }
  const q = l < 0.5 ? l * (1 + s) : l + s - l * s;
  const p = 2 * l - q;
  const hue2rgb = (a, b2, t) => {
    let tt = t < 0 ? t + 1 : t > 1 ? t - 1 : t;
    if (tt < 1 / 6) return a + (b2 - a) * 6 * tt;
    if (tt < 1 / 2) return b2;
    if (tt < 2 / 3) return a + (b2 - a) * (2 / 3 - tt) * 6;
    return a;
  };
  return {
    r: Math.round(hue2rgb(p, q, hn + 1 / 3) * 255),
    g: Math.round(hue2rgb(p, q, hn) * 255),
    b: Math.round(hue2rgb(p, q, hn - 1 / 3) * 255),
  };
}

function generateColorScale(hex) {
  const { r, g, b } = hexToRgb(hex);
  const { h, s } = rgbToHsl(r, g, b);
  const cs = v => Math.min(1, Math.max(0, v));

  const lightSteps = [
    [0.985, cs(s * 0.15)], [0.965, cs(s * 0.22)], [0.935, cs(s * 0.35)],
    [0.895, cs(s * 0.48)], [0.845, cs(s * 0.58)], [0.780, cs(s * 0.70)],
    [0.690, cs(s * 0.78)], [0.590, cs(s * 0.82)], [0.490, cs(s * 0.95)],
    [0.440, cs(s * 0.93)], [0.390, cs(s * 0.88)], [0.130, cs(s * 0.65)],
  ];
  const darkSteps = [
    [0.060, cs(s * 0.25)], [0.090, cs(s * 0.32)], [0.135, cs(s * 0.48)],
    [0.180, cs(s * 0.58)], [0.225, cs(s * 0.65)], [0.275, cs(s * 0.72)],
    [0.325, cs(s * 0.75)], [0.385, cs(s * 0.75)], [0.490, cs(s * 0.95)],
    [0.540, cs(s * 0.88)], [0.640, cs(s * 0.82)], [0.850, cs(s * 0.72)],
  ];

  const toVars = steps => steps.map(([l, sv]) => {
    const rgb = hslToRgb(h, sv, l);
    return `${rgb.r} ${rgb.g} ${rgb.b}`;
  });

  return { light: toVars(lightSteps), dark: toVars(darkSteps) };
}

const BRAND_STYLE_ID = 'cw-account-brand';

export const applyAccountTheme = (settings = {}) => {
  const { custom_color } = settings;
  let styleEl = document.getElementById(BRAND_STYLE_ID);
  if (!styleEl) {
    styleEl = document.createElement('style');
    styleEl.id = BRAND_STYLE_ID;
    document.head.appendChild(styleEl);
  }

  if (!custom_color || !/^#[0-9a-fA-F]{3,6}$/.test(custom_color)) {
    styleEl.textContent = '';
    return;
  }

  const { r, g, b } = hexToRgb(custom_color);
  const scale = generateColorScale(custom_color);
  const brandVar = `${r} ${g} ${b}`;

  const violetLight = scale.light.map((v, i) => `  --violet-${i + 1}: ${v};`).join('\n');
  const violetDark  = scale.dark.map((v, i) => `  --violet-${i + 1}: ${v};`).join('\n');
  const blueLight   = scale.light.map((v, i) => `  --blue-${i + 1}: ${v};`).join('\n');
  const blueDark    = scale.dark.map((v, i) => `  --blue-${i + 1}: ${v};`).join('\n');

  styleEl.textContent = `
:root {
  --n-brand: ${brandVar};
${violetLight}
${blueLight}
  --solid-iris: ${scale.light[2]};
  --solid-blue: ${scale.light[1]};
  --solid-blue-2: ${scale.light[0]};
}
.dark {
  --n-brand: ${brandVar};
${violetDark}
${blueDark}
  --solid-iris: ${scale.dark[2]};
  --solid-blue: ${scale.dark[1]};
  --solid-blue-2: ${scale.dark[0]};
}`;
};

// ── Dark/light mode ────────────────────────────────────────────────────────────

export const setColorTheme = isOSOnDarkMode => {
  const selectedColorScheme =
    LocalStorage.get(LOCAL_STORAGE_KEYS.COLOR_SCHEME) || 'auto';
  if (
    (selectedColorScheme === 'auto' && isOSOnDarkMode) ||
    selectedColorScheme === 'dark'
  ) {
    document.body.classList.add('dark');
    document.documentElement.style.setProperty('color-scheme', 'dark');
  } else {
    document.body.classList.remove('dark');
    document.documentElement.style.setProperty('color-scheme', 'light');
  }
};
