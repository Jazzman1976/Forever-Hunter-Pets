// Sammelt die Hunter-Pet-Fähigkeiten für WoW Forever und schreibt ../data.js.
// Quellen: Wowhead Forever (deutsch, inkl. Kommentare) und Petopia Classic für Lücken.
// Aufruf: node tools/fetch-data.mjs   (Cache in tools/cache/, zum Neuladen den Ordner löschen)
import fs from 'node:fs';
import path from 'node:path';
import vm from 'node:vm';
import { fileURLToPath } from 'node:url';
import {
  parsePetopiaAbilities, parsePetopiaAttackSpeeds, extractComments, parseCommentLists, parseTrainerComment,
} from './sources.mjs';

const HERE = path.dirname(fileURLToPath(import.meta.url));
const ROOT = path.resolve(HERE, '..');
const CACHE = path.join(HERE, 'cache');
const BASE = 'https://www.wowhead.com/forever/de';
const LIST_URL = `${BASE}/spells/pet-abilities/`;
const LIST_URL_EN = 'https://www.wowhead.com/forever/spells/pet-abilities/';
const PETOPIA = 'https://www.wow-petopia.com/classic/';
const DELAY_MS = 2000;
const SKIP_IDS = new Set([415429, 409365, 1278934, 416189]); // interne Einträge (Scaling, DND, Summoning)
// Schnellerer/Langsamerer Angriff: versteckte Auren für das Angriffstempo des gezähmten Tiers.
// Basis 2,0 s; aus den Prozentwerten ergeben sich genau die Tempi, die Petopia Classic auflistet.
const TRAIT_SPEED = {
  1263110: '1.0', 1263109: '1.2', 1263107: '1.3', 1263104: '1.4', 1263102: '1.5',
  1263100: '1.6', 1263099: '1.7', 1263113: '2.4', 1263114: '2.5',
};
const PETOPIA_ALIAS = { 'Demoralizing Screech': 'Screech' };
// Petopia-Familiennamen (Singular/Plural) → Wowhead-Familien-ID
const FAMILY_EN = {
  Wolf: 1, Wolves: 1, Cat: 2, Cats: 2, Spider: 3, Spiders: 3, Bear: 4, Bears: 4, Boar: 5, Boars: 5,
  Crocolisk: 6, Crocolisks: 6, 'Carrion Bird': 7, 'Carrion Birds': 7, Crab: 8, Crabs: 8, Gorilla: 9, Gorillas: 9,
  Raptor: 11, Raptors: 11, Tallstrider: 12, Tallstriders: 12, Scorpid: 20, Scorpids: 20, Turtle: 21, Turtles: 21,
  Bat: 24, Bats: 24, Hyena: 25, Hyenas: 25, Owl: 26, Owls: 26, 'Wind Serpent': 27, 'Wind Serpents': 27,
};

fs.mkdirSync(CACHE, { recursive: true });
const sleep = (ms) => new Promise((r) => setTimeout(r, ms));

async function get(url, cacheName) {
  const file = path.join(CACHE, cacheName);
  if (fs.existsSync(file)) return fs.readFileSync(file, 'utf8');
  // Bei 403/429 (Wowhead drosselt) mit wachsender Pause erneut versuchen.
  for (let attempt = 0; ; attempt++) {
    try {
      const html = await download(url);
      fs.writeFileSync(file, html);
      return html;
    } catch (e) {
      if (e.status === 404) { fs.writeFileSync(file, ''); return ''; } // „gibt es nicht“ merken, nicht jedes Mal neu fragen
      if (!e.retry || attempt >= 4) throw e;
      const wait = 15000 * (attempt + 1);
      process.stdout.write(`\n  gedrosselt (${e.message}), warte ${wait / 1000}s …\n`);
      await sleep(wait);
    }
  }
}

async function download(url) {
  await sleep(DELAY_MS);
  // Weiterleitungen selbst folgen: Wowhead leitet auf URLs mit Umlauten um, die fetch sonst im Kreis schickt.
  let res;
  for (let hop = 0; hop < 5; hop++) {
    res = await fetch(url, { redirect: 'manual', headers: { 'User-Agent': 'Mozilla/5.0 (pet-ability-lookup)' } });
    if (res.status < 300 || res.status >= 400) break;
    const loc = Buffer.from(res.headers.get('location'), 'latin1').toString('utf8');
    url = new URL(encodeURI(decodeURI(loc)), url).href;
  }
  if (!res.ok) {
    const err = new Error(`${res.status} bei ${url}`);
    err.status = res.status;
    err.retry = res.status === 403 || res.status === 429 || res.status >= 500;
    throw err;
  }
  return res.text();
}

// Liest das Array-/Objekt-Literal ab `start` mit Klammerzählung aus (Strings werden beachtet).
function sliceLiteral(src, start) {
  const open = src[start];
  const close = open === '[' ? ']' : '}';
  let depth = 0, inStr = null;
  for (let i = start; i < src.length; i++) {
    const c = src[i];
    if (inStr) {
      if (c === '\\') i++;
      else if (c === inStr) inStr = null;
      continue;
    }
    if (c === '"' || c === "'") inStr = c;
    else if (c === open) depth++;
    else if (c === close && --depth === 0) return src.slice(start, i + 1);
  }
  throw new Error('Literal nicht abgeschlossen');
}

// Wowhead nutzt teils unquotierte Schlüssel – daher in einem leeren VM-Kontext auswerten.
const evalLiteral = (txt) => vm.runInNewContext(`(${txt})`, Object.create(null), { timeout: 1000 });

function listviewData(html, id) {
  const at = html.indexOf(`id: '${id}'`);
  if (at < 0) return [];
  const d = html.indexOf('data: [', at);
  if (d < 0) return [];
  return evalLiteral(sliceLiteral(html, d + 6));
}

function descriptions(html) {
  const out = {};
  const re = /WH\.Gatherer\.addData\(6, \d+, /g;
  let m;
  while ((m = re.exec(html))) {
    const obj = evalLiteral(sliceLiteral(html, m.index + m[0].length));
    for (const [id, v] of Object.entries(obj)) {
      const desc = (v.description_dede || v.description_enus || '')
        .replace(/<!--.*?-->/g, '').replace(/<[^>]*>/g, '').replace(/\s+/g, ' ').trim(); // Wowhead-Markup entfernen
      out[id] = { desc, icon: v.icon || '' };
    }
  }
  return out;
}

function spellList(html) {
  const i = html.indexOf('listviewspells = ');
  return evalLiteral(sliceLiteral(html, i + 'listviewspells = '.length))
    .filter((s) => s.chrclass === 4 && !SKIP_IDS.has(s.id));
}

// NPC-Seite (deutsch) → Name, Titel, Stufen, Zonen, Familie
async function npcInfo(id) {
  const html = await get(`${BASE}/npc=${id}`, `npc-${id}.html`);
  const m = html.match(new RegExp(`\\$\\.extend\\(g_npcs\\[${id}\\], `));
  const o = m ? evalLiteral(sliceLiteral(html, m.index + m[0].length)) : {};
  const title = (html.match(/<h1 class="heading-size-1">[^<]*?&lt;([^&]*)&gt;<\/h1>/) || [])[1] || '';
  return {
    id, name: o.name || o.displayName || `NPC ${id}`, title,
    min: o.minlevel, max: o.maxlevel, zones: (o.location || []).filter((z) => z > 0),
    cls: o.classification ?? 0, family: o.family || 0,
  };
}

// Fundorte aus Wowhead Classic (Forever hat noch keine Kartendaten): { [zoneId]: [[x, y], …] } in Prozent
async function classicCoords(id) {
  const html = await get(`https://www.wowhead.com/classic/npc=${id}`, `classic-npc-${id}.html`);
  const m = html.match(/var g_mapperData = /);
  if (!m) return null;
  const data = evalLiteral(sliceLiteral(html, m.index + m[0].length));
  const out = {};
  for (const [zone, entries] of Object.entries(data)) {
    const pts = (Array.isArray(entries) ? entries : [entries]).flatMap((e) => e?.coords || []);
    const uniq = [...new Map(pts.map(([x, y]) => [`${x},${y}`, [x, y]])).values()];
    if (uniq.length) out[zone] = uniq;
  }
  return Object.keys(out).length ? out : null;
}

const rankNum = (r) => parseInt(String(r || '').replace(/\D+/g, ''), 10) || 0;

async function main() {
  const spells = spellList(await get(LIST_URL, 'list.html'));
  const enName = Object.fromEntries(spellList(await get(LIST_URL_EN, 'list-en.html')).map((s) => [s.id, s.name]));
  console.log(`${spells.length} Hunter-Pet-Einträge gefunden`);

  const zonesHtml = await get(`${BASE}/zones`, 'zones.html');
  const zones = {};
  const instanceOf = {}; // 2 Dungeon, 3 Raid, 4 Schlachtfeld
  // Gruppeninhalte erkennt man an "nplayers" > 0 (die Blackrockspitze hat z. B. "instance":0, aber 10 Spieler),
  // die Art an "category": 2 Dungeon, 3 Raid, 6 Schlachtfeld.
  for (const m of zonesHtml.matchAll(/"category":(\d+),[^{}]*?"id":(\d+),"instance":\d+,[^{}]*?"name":"((?:[^"\\]|\\.)*)","nplayers":(\d+)/g)) {
    const [, cat, id, name, nplayers] = m;
    zones[id] = JSON.parse(`"${name}"`);
    if (+nplayers > 0) instanceOf[id] = cat === '3' ? 3 : cat === '6' ? 4 : 2;
  }
  // Englische Zonennamen (Petopia) → Zonen-ID, um sie deutsch anzeigen zu können
  const zoneIdEn = {};
  for (const m of (await get('https://www.wowhead.com/forever/zones', 'zones-en.html'))
    .matchAll(/"id":(\d+),"instance":\d+,[^{}]*?"name":"((?:[^"\\]|\\.)*)"/g)) {
    zoneIdEn[JSON.parse(`"${m[2]}"`)] = +m[1];
  }
  console.log(`${Object.keys(zones).length} Zonen geladen`);

  const petopia = parsePetopiaAbilities(await get(`${PETOPIA}abilities.php`, 'petopia-abilities.html'));
  const speeds = parsePetopiaAttackSpeeds(await get(`${PETOPIA}attackspeed.php`, 'petopia-attackspeed.html'));
  console.log(`Petopia Classic: ${Object.keys(petopia).length} Fähigkeiten, ${Object.keys(speeds).length} Angriffstempi`);

  const families = {};
  const abilities = {};
  const spellToAbility = {};
  const commentLists = []; // { ability, spellId, rank, tp, npcIds, ref }
  const trainerRefs = [];
  const npcs = new Map(); // bekannte Tiere aus Wowhead Forever (deutsche Daten)
  let n = 0;
  for (const s of spells) {
    n++;
    const html = await get(`${BASE}/spell=${s.id}`, `spell-${s.id}.html`);
    process.stdout.write(`\r[${n}/${spells.length}] ${s.name} ${s.rank || ''}          `);

    const info = descriptions(html)[s.id] || { desc: '', icon: '' };
    const pets = listviewData(html, 'used-by-pet');
    const users = listviewData(html, 'used-by-npc').filter((c) => c.family > 0);

    for (const p of pets) {
      families[p.id] ??= { id: p.id, name: p.name, icon: p.icon, diet: p.diet, type: p.type };
    }
    for (const c of users) {
      npcs.set(c.id, {
        id: c.id, name: c.name, family: c.family, min: c.minlevel, max: c.maxlevel,
        zones: (c.location || []).filter((z) => z > 0),
        cls: c.classification, // 0 normal, 1 Elite, 2 Rar-Elite, 3 Boss, 4 Rar
      });
    }

    const a = (abilities[s.name] ??= {
      name: s.name, nameEn: enName[s.id] || '', icon: info.icon, schools: s.schools, general: s.skill.includes(270),
      families: new Set(), ranks: [], foreverNpcs: new Set(),
    });
    if (!a.icon) a.icon = info.icon;
    pets.forEach((p) => a.families.add(p.id));
    users.forEach((c) => a.foreverNpcs.add(c.id));
    a.ranks.push({ id: s.id, rank: rankNum(s.rank), level: s.level, desc: info.desc });
    spellToAbility[s.id] = a;

    for (const c of extractComments(html, evalLiteral, sliceLiteral)) {
      const ref = { url: `${BASE}/spell=${s.id}#comments:id=${c.id}`, user: c.user, date: String(c.date || '').slice(0, 10) };
      for (const [sid, e] of Object.entries(parseCommentLists(c, s.id))) {
        commentLists.push({ ability: a, spellId: +sid, ...e, ref });
      }
      for (const t of parseTrainerComment(c)) trainerRefs.push({ ...t, ref });
    }
  }
  process.stdout.write('\n');

  // Rang eines Kommentar-Eintrags bestimmen: über die Spell-ID, sonst über „Rank N“ aus der Tabelle.
  for (const e of commentLists) {
    const own = e.ability.ranks.find((r) => r.id === e.spellId);
    e.rankNo = own ? own.rank : e.rank;
  }

  // Alle Tiere aus Petopia/Kommentaren/Tempo-Liste, die Wowhead Forever nicht schon mitliefert, nachladen.
  const wanted = new Set();
  for (const p of Object.values(petopia)) for (const r of Object.values(p.ranks)) r.npcs.forEach((x) => wanted.add(x.id));
  for (const e of commentLists) e.npcIds.forEach((id) => wanted.add(id));
  for (const [sp, list] of Object.entries(speeds)) if (sp !== '2.0') list.forEach((x) => wanted.add(x.id));
  const missing = [...wanted].filter((id) => !npcs.has(id));
  const trainerIds = [...new Map(trainerRefs.map((t) => [t.id, t])).keys()];
  let k = 0;
  for (const id of [...missing, ...trainerIds]) {
    process.stdout.write(`\rNPC-Seiten: ${++k}/${missing.length + trainerIds.length}   `);
    const info = await npcInfo(id);
    if (!trainerIds.includes(id)) npcs.set(id, info);
    else npcs.set(`t${id}`, info);
  }
  process.stdout.write('\n');

  // Petopia-Tierdaten als Rückfall, falls Wowhead eine Angabe nicht hat.
  const petopiaNpc = new Map();
  for (const p of Object.values(petopia)) for (const r of Object.values(p.ranks)) r.npcs.forEach((x) => petopiaNpc.set(x.id, x));
  for (const list of Object.values(speeds)) list.forEach((x) => petopiaNpc.set(x.id, x));
  const beastBase = (id) => {
    const w = npcs.get(id);
    const p = petopiaNpc.get(id) || {};
    const petopiaZone = zoneIdEn[String(p.zoneEn || '').replace(/\s*\([^)]*\)$/, '')];
    return {
      id, name: w?.name || p.nameEn || `NPC ${id}`,
      family: w?.family || FAMILY_EN[p.familyEn] || 0,
      min: w?.min ?? p.min, max: w?.max ?? p.max,
      zones: w?.zones?.length ? w.zones : petopiaZone ? [petopiaZone] : [],
      zoneText: w?.zones?.length || petopiaZone ? '' : (p.zoneEn || ''),
      cls: w?.cls ?? 0,
    };
  };

  const abilityList = Object.values(abilities).map((a) => {
    a.ranks.sort((x, y) => x.rank - y.rank || x.level - y.level);
    const traitSpeed = a.ranks.length === 1 ? TRAIT_SPEED[a.ranks[0].id] : undefined;
    const pt = petopia[PETOPIA_ALIAS[a.nameEn] || a.nameEn];
    const beasts = new Map(); // npcId → Eintrag
    const add = (id, rank, src, est = false) => {
      const b = beasts.get(id) || { ...beastBase(id), rank, est, src: [] };
      if (!est && b.est) { b.rank = rank; b.est = false; }
      if (!b.src.includes(src)) b.src.push(src);
      beasts.set(id, b);
    };
    const refs = [];

    if (traitSpeed) {
      for (const x of speeds[traitSpeed] || []) add(x.id, 0, 'petopia');
      refs.push({ label: `Petopia Classic: Angriffstempo ${traitSpeed}`, url: `${PETOPIA}attackspeed.php#attackspeed_${traitSpeed}` });
    }
    // 1) Classic-Listen je Rang: Petopia und Wowhead-Kommentare
    if (pt) {
      for (const [rank, r] of Object.entries(pt.ranks)) r.npcs.forEach((x) => add(x.id, +rank, 'petopia'));
      refs.push({ label: 'Petopia Classic', url: `${PETOPIA}abilities.php#${(PETOPIA_ALIAS[a.nameEn] || a.nameEn).toLowerCase().replace(/[^a-z]/g, '')}` });
    }
    const seenRefs = new Set();
    for (const e of commentLists.filter((x) => x.ability === a && x.rankNo)) {
      e.npcIds.forEach((id) => add(id, e.rankNo, 'kommentar'));
      if (!seenRefs.has(e.ref.user + e.ref.date)) {
        seenRefs.add(e.ref.user + e.ref.date);
        refs.push({ label: `Wowhead-Kommentar von ${e.ref.user}${e.ref.date ? ` (${e.ref.date})` : ''}`, url: e.ref.url });
      }
    }
    // 2) Wowhead-Forever-Tiere: bestätigen vorhandene Einträge, sonst Rang nach Stufe schätzen.
    //    (Die Forever-Liste ist nicht rangspezifisch; bei allgemeinen Fähigkeiten wäre sie nur Rauschen.)
    if (!a.general) {
      for (const id of a.foreverNpcs) {
        if (beasts.has(id)) { beasts.get(id).src.push('forever'); continue; }
        const t = npcs.get(id);
        const lvl = t.max ?? t.min ?? 0;
        const fit = a.ranks.filter((r) => r.level <= lvl).pop() || a.ranks[0];
        add(id, fit.rank, 'forever', true);
      }
    }

    // Trainingspunkte und zusätzliche Classic-Ränge
    const ranks = a.ranks.map((r) => {
      const c = pt?.ranks[r.rank];
      const ce = commentLists.find((e) => e.ability === a && e.rankNo === r.rank && e.tp != null);
      return { ...r, tp: c?.tp ?? ce?.tp ?? null };
    });
    const classicExtra = pt
      ? Object.entries(pt.ranks).filter(([rk]) => !a.ranks.some((r) => r.rank === +rk))
        .map(([rk, r]) => ({ rank: +rk, level: r.level, tp: r.tp }))
      : [];

    const beastList = [...beasts.values()]
      .sort((x, y) => (x.min ?? 0) - (y.min ?? 0) || x.name.localeCompare(y.name, 'de'));
    const classicTrainer = pt && Object.values(pt.ranks).some((r) => r.trainer);
    const kind = traitSpeed ? 'trait' : a.general ? 'general' : 'family';
    let source = 'unknown';
    if (beastList.length) source = 'tame';
    else if (classicTrainer || a.general) source = 'trainer';
    return {
      name: a.name, nameEn: a.nameEn, icon: a.icon, schools: a.schools,
      families: [...a.families].sort((x, y) => x - y),
      classicFamilies: pt && !pt.families.includes('All Families')
        ? [...new Set(pt.families.map((f) => FAMILY_EN[f]).filter(Boolean))] : [],
      kind, source, speed: traitSpeed || null,
      classic: !!pt, classicTrainer: !!classicTrainer, classicExtra,
      ranks, beasts: beastList, refs,
    };
  }).sort((x, y) => x.name.localeCompare(y.name, 'de'));

  const trainers = trainerIds.map((id) => {
    const t = npcs.get(`t${id}`);
    return { id, name: t.name, title: t.title, zones: t.zones };
  });
  const trainerRef = trainerRefs[0]?.ref;

  // Koordinaten je Tier (einmal pro NPC abrufen, auch wenn es bei mehreren Fähigkeiten vorkommt)
  const coords = {};
  const beastIds = [...new Set(abilityList.flatMap((a) => a.beasts.map((b) => b.id)))];
  let c = 0;
  for (const id of beastIds) {
    process.stdout.write(`\rKoordinaten (Wowhead Classic): ${++c}/${beastIds.length}   `);
    try {
      const co = await classicCoords(id);
      // kompakt speichern: flache Liste ganzer Zahlen (×10), z. B. [258, 486, 282, 468, …]
      if (co) coords[id] = Object.fromEntries(Object.entries(co).map(([z, pts]) => [z, pts.flatMap(([x, y]) => [Math.round(x * 10), Math.round(y * 10)])]));
    } catch (e) {
      if (!/404/.test(e.message)) throw e; // NPC gibt es in Classic nicht
    }
  }
  process.stdout.write('\n');

  // Nur die tatsächlich genutzten Zonen übernehmen, damit data.js klein bleibt.
  const usedZones = {};
  for (const co of Object.values(coords)) for (const z of Object.keys(co)) usedZones[z] = zones[z] || `Zone ${z}`;
  for (const a of abilityList) for (const t of a.beasts) for (const z of t.zones) usedZones[z] = zones[z] || `Zone ${z}`;
  for (const t of trainers) for (const z of t.zones) usedZones[z] = zones[z] || `Zone ${z}`;

  const data = {
    generatedAt: new Date().toISOString(),
    sources: [
      { label: 'Wowhead Forever', url: LIST_URL },
      { label: 'Wowhead-Kommentare', url: LIST_URL },
      { label: 'Petopia Classic', url: `${PETOPIA}abilities.php` },
      { label: 'Wowhead Classic (Koordinaten)', url: 'https://www.wowhead.com/classic/' },
    ],
    coords,
    instances: Object.fromEntries(Object.keys(usedZones).filter((z) => instanceOf[z]).map((z) => [z, instanceOf[z]])),
    families: Object.values(families).sort((x, y) => x.name.localeCompare(y.name, 'de')),
    zones: usedZones,
    trainers, trainerRef: trainerRef ? { url: trainerRef.url, user: trainerRef.user } : null,
    abilities: abilityList,
  };
  fs.writeFileSync(path.join(ROOT, 'data.js'),
    `// Automatisch erzeugt von tools/fetch-data.mjs – nicht von Hand bearbeiten.\nwindow.PET_DATA = ${JSON.stringify(data)};\n`);

  const rankCount = abilityList.reduce((s, a) => s + a.ranks.length, 0);
  const all = abilityList.flatMap((a) => a.beasts);
  console.log(`Fertig: ${abilityList.length} Fähigkeiten, ${rankCount} Ränge, ${all.length} Tier-Einträge ` +
    `(${all.filter((b) => !b.est).length} rangbestätigt), ${trainers.length} Tierausbilder, ` +
    `Koordinaten für ${Object.keys(coords).length}/${beastIds.length} Tiere → data.js`);
}

main().catch((e) => { console.error(e); process.exit(1); });
