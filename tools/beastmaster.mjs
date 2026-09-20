// beastmaster.io als dritte Quelle für fetch-data.mjs.
//
// https://beastmaster.io/forever/abilities ist eine React-App ohne API: die Forever-Daten
// stecken als Literale im JS-Bundle. Wir schneiden das Bundle hinter den Datendefinitionen
// ab und werten nur diesen Teil in einem vm-Kontext mit Browser-Attrappe aus – dort kommt
// fremder Code weder an fs noch an process.
//
// Die Namen im Bundle sind minifiziert und ändern sich bei jedem Deploy. Deshalb suchen
// wir die vier Datentabellen nicht über ihren Namen, sondern über ihre *Form*; ändert
// beastmaster.io die Struktur, schlägt das hier mit einer klaren Meldung fehl.

import vm from 'node:vm';

export const BEASTMASTER = 'https://beastmaster.io/forever/abilities';
/** Einzelne Fähigkeit bzw. die gefilterte Tierliste – die Routen der Seite. */
export const bmAbilityUrl = (slug) => `https://beastmaster.io/forever/ability/${slug}`;
export const bmSpeedUrl = (speed) => `https://beastmaster.io/forever/all?speed=${speed}`;

/** `<script src="/assets/index-XYZ.js">` aus der Seite ziehen. */
export function bundleUrl(html, base = BEASTMASTER) {
  const m = html.match(/<script[^>]+src="([^"]*\/assets\/index-[^"]+\.js)"/);
  if (!m) throw new Error('beastmaster.io: kein /assets/index-*.js im HTML gefunden');
  return new URL(m[1], base).href;
}

// Die vier Tabellen, jeweils an einem Stück Literal erkannt, das ohne Umbau nicht wegfällt.
const MARKS = {
  // { era: […], tbc: […], …, forever: […] } – kommt zweimal vor: Tiere und Rang-Stufen
  tables: /([A-Za-z_$][\w$]*)=\{era:\w+,tbc:\w+,wotlk:\w+,cata:\w+,mop:\w+,midnight:\w+,forever:\w+\}/g,
  families: /([A-Za-z_$][\w$]*)=\[\{slug:"bat",name:"Bat"/,
  meta: /([A-Za-z_$][\w$]*)=\[\{slug:"acid-spit"/,
  tp: /([A-Za-z_$][\w$]*)=\{"Arcane Resistance":\[5,15,45,90,105\],Bite:\[/,
};

/**
 * Ende des Literals, das ab `from` beginnt (erste `[`/`{` und dazu die passende Klammer).
 * Wir zählen nur innerhalb reiner Datenliterale, deshalb reichen Klammern, Zeichenketten
 * und Template-Einschübe – Regex-Literale kommen darin nicht vor.
 */
function endOfLiteral(src, from) {
  const start = src.slice(from).search(/[[{]/);
  if (start < 0) throw new Error('beastmaster.io: Datentabelle ohne Literal');
  const stack = [];   // offene Klammern; '`' steht für eine laufende Template-Zeichenkette
  let inStr = null;
  for (let i = from + start; i < src.length; i++) {
    const c = src[i];
    if (inStr) {
      if (c === '\\') i++;
      else if (c === inStr) inStr = null;
      else if (inStr === '`' && c === '$' && src[i + 1] === '{') { stack.push('`'); inStr = null; i++; }
      continue;
    }
    if (c === '"' || c === "'" || c === '`') inStr = c;
    else if (c === '(' || c === '[' || c === '{') stack.push(c);
    else if (c === ')' || c === ']' || c === '}') {
      const open = stack.pop();
      if (open === '`') inStr = '`';                 // Template-Einschub zu Ende
      else if (!stack.length) return i + 1;
    }
  }
  throw new Error('beastmaster.io: Ende der Datentabellen nicht gefunden');
}

/** Browser-Attrappe: gerade genug, damit die Bibliotheken im Bundle beim Laden nicht stolpern. */
function browserStub() {
  const noop = () => {};
  const node = () => ({
    style: {}, dataset: {}, classList: { add: noop, remove: noop, toggle: noop, contains: () => false },
    setAttribute: noop, removeAttribute: noop, getAttribute: () => null, appendChild: (x) => x, removeChild: noop,
    insertBefore: (x) => x, addEventListener: noop, removeEventListener: noop, dispatchEvent: () => true,
    querySelector: () => null, querySelectorAll: () => [], getBoundingClientRect: () => ({ top: 0, left: 0, width: 0, height: 0 }),
    children: [], childNodes: [], firstChild: null, parentNode: null, textContent: '', innerHTML: '',
  });
  const doc = {
    createElement: node, createElementNS: node, createTextNode: node, createDocumentFragment: node,
    documentElement: node(), head: node(), body: node(), getElementById: () => null,
    getElementsByTagName: () => [], querySelector: () => null, querySelectorAll: () => [],
    addEventListener: noop, removeEventListener: noop, cookie: '', readyState: 'complete', visibilityState: 'visible',
  };
  const media = () => ({ matches: false, addEventListener: noop, removeEventListener: noop, addListener: noop, removeListener: noop });
  const store = { getItem: () => null, setItem: noop, removeItem: noop, clear: noop, key: () => null, length: 0 };
  const win = {
    document: doc, navigator: { userAgent: 'node', language: 'en', languages: ['en'] },
    location: new URL(BEASTMASTER), history: { pushState: noop, replaceState: noop, state: null },
    localStorage: store, sessionStorage: store, matchMedia: media,
    addEventListener: noop, removeEventListener: noop, scrollTo: noop,
    getComputedStyle: () => ({ getPropertyValue: () => '' }),
    requestAnimationFrame: (f) => setTimeout(f, 0), cancelAnimationFrame: noop,
    innerWidth: 1280, innerHeight: 800, devicePixelRatio: 1,
    HTMLElement: class {}, Element: class {}, Node: class {}, Image: class {},
    MutationObserver: class { observe() {} disconnect() {} takeRecords() { return []; } },
    IntersectionObserver: class { observe() {} unobserve() {} disconnect() {} },
    ResizeObserver: class { observe() {} unobserve() {} disconnect() {} },
    fetch: () => Promise.reject(new Error('offline')),
    setTimeout, clearTimeout, setInterval, clearInterval, console, URL, URLSearchParams, TextEncoder, TextDecoder,
  };
  win.window = win; win.self = win; win.top = win; win.parent = win; win.globalThis = win;
  doc.defaultView = win;
  return win;
}

/**
 * JS-Bundle → Forever-Daten.
 * @returns {{ beasts: object[], levels: Record<string, number[]>, tp: Record<string, number[]>,
 *             families: object[], meta: object[] }}
 */
export function parseBeastmaster(js) {
  const found = {};
  for (const [key, re] of Object.entries(MARKS)) {
    if (key === 'tables') continue;
    const m = js.match(re);
    if (!m) throw new Error(`beastmaster.io: Tabelle „${key}“ nicht im Bundle gefunden`);
    found[key] = { name: m[1], at: m.index };
  }
  // „{ era: …, forever: … }“ steht im Bundle mehrfach (Tiere, Rang-Stufen, Metadaten).
  // Welche welche ist, entscheiden wir unten an der Form der Werte.
  const tables = [...js.matchAll(MARKS.tables)].map((m) => ({ name: m[1], at: m.index }));
  if (!tables.length) throw new Error('beastmaster.io: keine Expansion-Tabelle im Bundle gefunden');

  const marks = [...tables, ...Object.values(found)];
  const cut = Math.max(...marks.map((m) => endOfLiteral(js, m.at)));

  const capture = ';globalThis.__bm = { tables: {'
    + tables.map((t) => `${JSON.stringify(t.name)}: ${t.name}`).join(', ')
    + `}, families: ${found.families.name}, meta: ${found.meta.name}, tp: ${found.tp.name} };`;

  const ctx = vm.createContext(browserStub());
  new vm.Script(js.slice(0, cut) + capture, { filename: 'beastmaster-bundle.js' }).runInContext(ctx, { timeout: 60000 });

  const raw = ctx.__bm;
  const meta = raw.meta ?? [];
  const all = Object.values(raw.tables ?? {}).map((t) => t?.forever);
  // Tiere: Liste von Objekten mit `slug`.
  const beasts = all.find((f) => Array.isArray(f) && typeof f[0]?.slug === 'string');
  // Rang-Stufen: „Fähigkeit → Stufe je Rang“. Das Bundle enthält mehrere so gebaute Tabellen
  // (eine davon mit Unterstrichen statt Leerzeichen in den Schlüsseln); wir nehmen die, deren
  // Schlüssel am besten zu den Fähigkeitsnamen aus den Metadaten passen.
  const names = new Set(meta.map((m) => m.name));
  const score = (f) => (f && !Array.isArray(f) && typeof f === 'object'
    ? Object.entries(f).filter(([k, v]) => names.has(k) && Array.isArray(v) && typeof v[0] === 'number').length
    : 0);
  const levels = all.reduce((best, f) => (score(f) > score(best) ? f : best), null);
  if (!beasts?.length) throw new Error('beastmaster.io: keine Forever-Tierliste in den Expansion-Tabellen');
  if (!score(levels)) throw new Error('beastmaster.io: keine Forever-Rangstufen gefunden');

  return {
    beasts, levels, meta,
    tp: raw.tp ?? {},
    families: (raw.families ?? []).filter((f) => f.expansions?.includes('forever')),
  };
}

/**
 * `ragged-young-wolf-705` → 705. Nur die Zahl *am Ende* ist die NPC-ID: Slugs mit
 * angehängter Farbvariante („prideclaw-251245-blue-and-white“) sind Dubletten des
 * Grundeintrags, und bei manchen steht dort eine Darstellungs- statt einer NPC-ID.
 */
export function slugNpcId(slug) {
  const m = String(slug).match(/-(\d+)$/);
  return m ? +m[1] : null;
}
