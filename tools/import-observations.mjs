// Führt die Beobachtungen beim Zähmen aus den SavedVariables des Addons in tools/eigene/beobachtungen.json
// zusammen und merkt sich die Kürzel der eigenen Charaktere (myReps) in tools/eigene/eigene-melder.json.
// Dazu die Sichtungen beim Anvisieren (Core/Sightings.lua) nach tools/eigene/sichtungen.json, die
// Fundort-Zellen nach tools/eigene/zellen.json (eigene) und zellen-fremd.json (fremde, mit Melder), die Herkunft
// fremder Melder nach tools/eigene/melder-wege.json und die
// Erhebung der Fähigkeiten aus Wildtierausbildung, Tierausbilder und Zauberbuch (Core/Survey.lua)
// nach tools/eigene/erhebung.json.
// In der Datei eines Spielers steht, was er selbst gesehen hat, und alles, was andere im Spiel geteilt haben.
// Aufruf: node tools/import-observations.mjs <Pfad> [<Pfad> …]
//   Ein Pfad ist eine Forever-Hunter-Pets.lua (früher ForeverHunterPets.lua) oder ein Ordner, unter dem sie
//   gesucht wird (etwa der WoW-Ordner).
// Gespeichert werden keine Namen: fremde Beobachtungen tragen schon ein Kürzel; eigene (Melder leer) bekommen
// eines aus dem Namen des Account-Ordners, damit sie von denen anderer Dateien unterscheidbar bleiben.
import fs from 'node:fs';
import path from 'node:path';
import { fileURLToPath } from 'node:url';
import { parseSavedVariables } from './lua-table.mjs';

const HERE = path.dirname(fileURLToPath(import.meta.url));
const OUT = path.join(HERE, 'eigene', 'beobachtungen.json');
const OWN_OUT = path.join(HERE, 'eigene', 'eigene-melder.json');
const SURVEY_OUT = path.join(HERE, 'eigene', 'erhebung.json');
const SURVEY_VERSION = 5; // wie VERSION in Core/Survey.lua; Version 4 kann Jägerzauber enthalten (#16)
const SIGHT_OUT = path.join(HERE, 'eigene', 'sichtungen.json');
const CELLS_OUT = path.join(HERE, 'eigene', 'zellen.json');
const FOREIGN_CELLS_OUT = path.join(HERE, 'eigene', 'zellen-fremd.json');
const WAYS_OUT = path.join(HERE, 'eigene', 'melder-wege.json');
const MIN_TIME = 1788220800; // 01.09.2026, wie im Addon (Core/Comm.lua)

// djb2, wie ns.ReporterHash im Addon
function hash(s) {
  let h = 5381;
  for (const ch of Buffer.from(s, 'utf8')) h = (h * 33 + ch) % 4294967296;
  return h.toString(16).padStart(8, '0');
}

function findFiles(p, depth = 0, out = []) {
  let st;
  try { st = fs.statSync(p); } catch { return out; }
  if (st.isFile()) {
    if (/^Forever-?Hunter-?Pets\.lua$/.test(path.basename(p)) && /SavedVariables/i.test(p)) out.push(p);
    return out;
  }
  if (!st.isDirectory() || depth > 8) return out;
  for (const e of fs.readdirSync(p)) {
    if (/^(Interface|Cache|Logs|Data|Errors|Screenshots)$/i.test(e)) continue;
    findFiles(path.join(p, e), depth + 1, out);
  }
  return out;
}

// Konto-Datei (nicht die je Charakter): …/WTF/Account/<Konto>/SavedVariables/ForeverHunterPets.lua
function accountOf(file) {
  const parts = file.split(/[\\/]/);
  const i = parts.findIndex((x) => /^account$/i.test(x));
  return i >= 0 ? parts[i + 1] : file;
}

function parseObs(text) {
  const m = text.match(/\["obs"\]\s*=\s*\{([^}]*)\}/);
  if (!m) return [];
  return [...m[1].matchAll(/"([^"]*)"/g)].map((x) => x[1]);
}

// Kürzel der eigenen Charaktere: ["myReps"] = { ["758ea066"] = true, … }
function parseMyReps(text) {
  const m = text.match(/\["myReps"\]\s*=\s*\{([^}]*)\}/);
  return m ? [...m[1].matchAll(/\["([0-9a-f]{8})"\]/g)].map((x) => x[1]) : [];
}

function record(s, ownRep) {
  const m = s.match(/^(\d+);(\d+);([\d,]*);([\d.]*);(\d*);([0-9a-f]*)$/);
  if (!m) return null;
  const r = {
    npc: +m[1], stufe: +m[2],
    zauber: m[3] ? m[3].split(',').map(Number) : [],
    tempo: m[4] ? +m[4] : null,
    zeit: m[5] ? +m[5] : null,
    melder: m[6] || ownRep,
    // ältere eigene Einträge ohne Kürzel: Ersatz aus dem Konto, bis die Datei das echte nachliefert
    ...(m[6] ? {} : { ersatz: true }),
  };
  if (r.stufe < 1 || r.stufe > 63 || !r.zeit || r.zeit < MIN_TIME) return null;
  if (r.tempo != null && (r.tempo < 0.5 || r.tempo > 4)) return null;
  if (!/^[0-9a-f]{8}$/.test(r.melder)) return null;
  return r;
}

// --ohne-tierausbilder: aus den SavedVariables weder das Kennzeichen „Tierausbilder“ noch Jägerstufe und Goldpreis
// übernehmen; was erhebung.json schon hat, bleibt. Für Dateien, in denen das Addon die Wildtierausbildung
// als Tierausbilder erhoben hat (#30: Pet-Stufen als Jägerstufe, TP als Preis).
const NO_TRAINER = process.argv.includes('--ohne-tierausbilder');
const args = process.argv.slice(2).filter((a) => a !== '--ohne-tierausbilder');
if (!args.length) {
  console.error('Aufruf: node tools/import-observations.mjs [--ohne-tierausbilder] <SavedVariables-Datei oder WoW-Ordner> […]');
  process.exit(1);
}
const files = [...new Set(args.flatMap((a) => findFiles(path.resolve(a))))]
  .filter((f) => /[\\/]Account[\\/][^\\/]+[\\/]SavedVariables[\\/]/i.test(f));
if (!files.length) {
  console.error('Keine Forever-Hunter-Pets.lua unter WTF/Account/<Konto>/SavedVariables gefunden.');
  process.exit(1);
}

const old = fs.existsSync(OUT) ? JSON.parse(fs.readFileSync(OUT, 'utf8')) : [];
// Dieselbe Zähmung: gleiches Tier zur selben Sekunde. Das echte Kürzel ersetzt ein Ersatzkürzel.
const key = (r) => `${r.npc}:${r.zeit}`;
const all = new Map(old.map((r) => [key(r), r]));
let read = 0, bad = 0;
// Eigene Kürzel: Beobachtungen damit gelten im Generator schon mit einem Melder als belegt.
const own = new Set(fs.existsSync(OWN_OUT) ? JSON.parse(fs.readFileSync(OWN_OUT, 'utf8')) : []);
for (const f of files) {
  const ownRep = hash('konto:' + accountOf(f));
  const text = fs.readFileSync(f, 'utf8');
  own.add(ownRep);
  for (const rep of parseMyReps(text)) own.add(rep);
  for (const s of parseObs(text)) {
    read++;
    const r = record(s, ownRep);
    if (!r) { bad++; continue; }
    const had = all.get(key(r));
    if (!had || (had.ersatz && !r.ersatz)) all.set(key(r), r);
  }
}
const list = [...all.values()].sort((x, y) => x.zeit - y.zeit || x.npc - y.npc);
// eine Beobachtung je Zeile: gut lesbare Diffs
fs.writeFileSync(OUT, '[\n' + list.map((r) => '  ' + JSON.stringify(r)).join(',\n') + '\n]\n');
fs.writeFileSync(OWN_OUT, JSON.stringify([...own].sort()) + '\n');
const reps = new Set(list.map((r) => r.melder));
console.log(`${files.length} Datei(en), ${read} Beobachtungen gelesen (${bad} unbrauchbar), ` +
  `${list.length - old.length} neu → ${list.length} in tools/eigene/beobachtungen.json von ${reps.size} Meldern ` +
  `(${own.size} eigene Kürzel)`);

// ---- Sichtungen (Core/Sightings.lua) → tools/eigene/sichtungen.json ----
// „npc;stufe;einstufung;familie;sprache;name;zeit;melder[;tempo]“, je Tier, Stufe, Sprache und Melder eine
const sightKey = (r) => `${r.npc}:${r.stufe}:${r.sprache}:${r.melder}`;
const sightsOld = fs.existsSync(SIGHT_OUT) ? JSON.parse(fs.readFileSync(SIGHT_OUT, 'utf8')) : [];
const sightsAll = new Map(sightsOld.map((r) => [sightKey(r), r]));
let sightsRead = 0;
for (const f of files) {
  const m = fs.readFileSync(f, 'utf8').match(/\["sights"\]\s*=\s*\{([^}]*)\}/);
  for (const [, s] of m ? m[1].matchAll(/"((?:[^"\\]|\\.)*)"/g) : []) {
    const x = s.match(/^(\d+);(\d+);(\d);(\d+);([a-z]{2}[A-Z]{2});([^;|]+);(\d+);([0-9a-f]{8});?([\d.]*)$/);
    if (!x) continue;
    sightsRead++;
    const r = { npc: +x[1], stufe: +x[2], einstufung: +x[3], familie: +x[4], sprache: x[5], name: x[6].replace(/\\(.)/g, '$1'),
      zeit: +x[7], melder: x[8], ...(x[9] ? { tempo: +x[9] } : {}) };
    if (r.stufe < 1 || r.stufe > 63 || r.zeit < MIN_TIME) continue;
    if (r.tempo != null && (r.tempo < 0.5 || r.tempo > 5)) delete r.tempo;
    // eine Sichtung mit Tempo ersetzt dieselbe ohne
    const had = sightsAll.get(sightKey(r));
    if (!had || (r.tempo != null && had.tempo == null)) sightsAll.set(sightKey(r), r);
  }
}
const sightList = [...sightsAll.values()].sort((x, y) => x.npc - y.npc || x.stufe - y.stufe || x.zeit - y.zeit);
fs.writeFileSync(SIGHT_OUT, '[\n' + sightList.map((r) => '  ' + JSON.stringify(r)).join(',\n') + '\n]\n');
console.log(`${sightsRead} Sichtungen gelesen, ${sightList.length - sightsOld.length} neu → ${sightList.length} in tools/eigene/sichtungen.json `
  + `(${new Set(sightList.map((r) => r.npc)).size} Tiere)`);

// ---- Eigene Fundort-Zellen (Core/Places.lua) → tools/eigene/zellen.json ----
// { npc: { uiMapID: "xyxy…" } }, zwei Zeichen je Zelle (Spalte, Zeile im Raster 50 × 50), aus
// ForeverHunterPetsDB.loc. Fremde (locIn) siehe unten.
const CELL_ALPHA = '0123456789ABCDEFGHIJKLMNOPQRSTUVWXYZabcdefghijklmn';
const cellsOut = fs.existsSync(CELLS_OUT) ? JSON.parse(fs.readFileSync(CELLS_OUT, 'utf8')) : {};
let cellsNew = 0;
for (const f of files) {
  let loc;
  try {
    loc = parseSavedVariables(fs.readFileSync(f, 'utf8')).ForeverHunterPetsDB?.loc;
  } catch { continue; }
  for (const [npc, maps] of Object.entries(loc || {})) {
    for (const [map, cells] of Object.entries(maps || {})) {
      if (typeof cells !== 'string' || cells.length % 2 || [...cells].some((c) => !CELL_ALPHA.includes(c))) continue;
      const have = ((cellsOut[npc] ??= {})[map] ??= '');
      const set = new Set(have.match(/../g) || []);
      let add = '';
      for (const c of cells.match(/../g)) if (!set.has(c)) { set.add(c); add += c; }
      cellsOut[npc][map] = have + add;
      cellsNew += add.length / 2;
    }
  }
}
const sortedCells = Object.fromEntries(Object.entries(cellsOut).sort(([a], [b]) => a - b)
  .map(([npc, maps]) => [npc, Object.fromEntries(Object.entries(maps).sort(([a], [b]) => a - b))]));
fs.writeFileSync(CELLS_OUT, '{\n' + Object.entries(sortedCells).map(([npc, maps]) => `  ${JSON.stringify(npc)}: ${JSON.stringify(maps)}`).join(',\n') + '\n}\n');
console.log(`${cellsNew} neue eigene Fundort-Zellen → tools/eigene/zellen.json (${Object.keys(sortedCells).length} Tiere)`);

// ---- Fremde Fundort-Zellen (Core/Places.lua) → tools/eigene/zellen-fremd.json ----
// { npc: { uiMapID: { melder: "xyxy…" } } }, aus ForeverHunterPetsDB.locIn. Ältere Einträge ohne Melder
// (String je Karte oder Melder „-“) zählen nicht und werden übergangen. Ob eine Zelle ausgeliefert wird
// (ab 3 Meldern), entscheidet der Generator.
const foreignOut = fs.existsSync(FOREIGN_CELLS_OUT) ? JSON.parse(fs.readFileSync(FOREIGN_CELLS_OUT, 'utf8')) : {};
let foreignNew = 0;
for (const f of files) {
  let locIn;
  try {
    locIn = parseSavedVariables(fs.readFileSync(f, 'utf8')).ForeverHunterPetsDB?.locIn;
  } catch { continue; }
  for (const [npc, maps] of Object.entries(locIn || {})) {
    for (const [map, byRep] of Object.entries(maps || {})) {
      if (!byRep || typeof byRep !== 'object') continue;
      for (const [rep, cells] of Object.entries(byRep)) {
        if (!/^[0-9a-f]{8}$/.test(rep)) continue;
        if (typeof cells !== 'string' || cells.length % 2 || [...cells].some((c) => !CELL_ALPHA.includes(c))) continue;
        const have = (((foreignOut[npc] ??= {})[map] ??= {})[rep] ??= '');
        const set = new Set(have.match(/../g) || []);
        let add = '';
        for (const c of cells.match(/../g)) if (!set.has(c)) { set.add(c); add += c; }
        foreignOut[npc][map][rep] = have + add;
        foreignNew += add.length / 2;
      }
    }
  }
}
const sortedForeign = Object.fromEntries(Object.entries(foreignOut).sort(([a], [b]) => a - b)
  .map(([npc, maps]) => [npc, Object.fromEntries(Object.entries(maps).sort(([a], [b]) => a - b)
    .map(([map, byRep]) => [map, Object.fromEntries(Object.entries(byRep).sort(([a], [b]) => a.localeCompare(b)))]))]));
fs.writeFileSync(FOREIGN_CELLS_OUT, '{\n' + Object.entries(sortedForeign).map(([npc, maps]) => `  ${JSON.stringify(npc)}: ${JSON.stringify(maps)}`).join(',\n') + '\n}\n');
console.log(`${foreignNew} neue fremde Fundort-Zellen → tools/eigene/zellen-fremd.json (${Object.keys(sortedForeign).length} Tiere)`);

// ---- Herkunft fremder Kürzel (Core/Comm.lua, #15) → tools/eigene/melder-wege.json ----
// { melder: [absender, …] }, aus ForeverHunterPetsDB.via (je Melder „abs1abs2…“), nur Kürzel. Über alle Dateien
// vereinigt: Kam ein Melder bei zwei Spielern über verschiedene Absender, sind das zwei Wege. Die Datei entsteht
// erst, wenn es etwas zu vermerken gibt; ohne sie zählt der Generator wie bisher.
const wegeOld = fs.existsSync(WAYS_OUT) ? JSON.parse(fs.readFileSync(WAYS_OUT, 'utf8')) : null;
const wege = new Map(Object.entries(wegeOld || {}).map(([rep, l]) => [rep, new Set(l)]));
let wegeNew = 0;
for (const f of files) {
  let via;
  try {
    via = parseSavedVariables(fs.readFileSync(f, 'utf8')).ForeverHunterPetsDB?.via;
  } catch { continue; }
  for (const [rep, s] of Object.entries(via || {})) {
    if (!/^[0-9a-f]{8}$/.test(rep) || typeof s !== 'string' || !/^([0-9a-f]{8})+$/.test(s)) continue;
    const set = wege.get(rep) ?? wege.set(rep, new Set()).get(rep);
    for (const from of s.match(/.{8}/g)) if (!set.has(from)) { set.add(from); wegeNew++; }
  }
}
if (wegeOld || wege.size) {
  const sortedWege = [...wege].sort(([a], [b]) => a.localeCompare(b)).map(([rep, set]) => `  ${JSON.stringify(rep)}: ${JSON.stringify([...set].sort())}`);
  fs.writeFileSync(WAYS_OUT, '{\n' + sortedWege.join(',\n') + '\n}\n');
  console.log(`${wegeNew} neue Absender → tools/eigene/melder-wege.json (Herkunft bekannt für ${wege.size} Melder)`);
} else {
  console.log('Noch keine Herkunft fremder Melder vermerkt (tools/eigene/melder-wege.json bleibt aus)');
}

// ---- Erhebung (Core/Survey.lua) → tools/eigene/erhebung.json ----
// Je Rang wird zusammengeführt, was die Dateien wissen (eine fehlende Angabe überschreibt keine vorhandene),
// je Familie gilt die jüngste vollständige Liste der Wildtierausbildung. Namen stehen je Client-Sprache.
const day = (t) => new Date(t * 1000).toISOString().slice(0, 10);
const survey = fs.existsSync(SURVEY_OUT)
  ? JSON.parse(fs.readFileSync(SURVEY_OUT, 'utf8'))
  : { raenge: {}, listen: {}, familien: {}, zauberbuch: {} };
let surveyFiles = 0;
for (const f of files) {
  let s;
  try {
    s = parseSavedVariables(fs.readFileSync(f, 'utf8')).ForeverHunterPetsDB?.survey;
  } catch (e) {
    console.error(`${f}: nicht lesbar (${e.message})`);
    continue;
  }
  if (!s || s.v !== SURVEY_VERSION) continue;
  surveyFiles++;
  const lang = s.locale || 'enUS';
  for (const [id, e] of Object.entries(s.ranks || {})) {
    if (!/^\d+$/.test(id)) continue; // ohne Zauber-ID nicht verwertbar
    const r = (survey.raenge[id] ??= { name: {} });
    r.name[lang] = e.name;
    const fields = [['rang', 'rank'], ['icon', 'icon'], ['petStufe', 'petLevel']];
    if (!NO_TRAINER) fields.push(['jaegerStufe', 'hunterLevel'], ['preis', 'gold']);
    for (const [to, from] of fields) {
      if (e[from] != null) r[to] = e[from];
    }
    if (e.bw) r.wildtierausbildung = true;
    if (e.npc && !NO_TRAINER) r.tierausbilder = true;
    if (e.t) r.datum = r.datum && r.datum < day(e.t) ? r.datum : day(e.t);
  }
  for (const [fam, l] of Object.entries(s.lists || {})) {
    const had = survey.listen[fam];
    if (had && had.zeit >= l.at) continue;
    survey.listen[fam] = { zeit: l.at, datum: day(l.at), zeilen: Object.fromEntries(Object.entries(l.rows || {}).sort()) };
  }
  for (const [fam, name] of Object.entries(s.families || {})) {
    const e = (survey.familien[fam] ??= { name: {} });
    e.name[lang] = name;
  }
  for (const [fam, icon] of Object.entries(s.familyIcons || {})) {
    if (icon != null && icon !== '') (survey.familien[fam] ??= { name: {} }).icon = icon;
  }
  for (const [id, e] of Object.entries(s.spells || {})) {
    const z = (survey.zauberbuch[id] ??= { name: {}, familien: [] });
    z.name[lang] = e.name;
    if (e.rank != null) z.rang = e.rank;
    if (e.passive) z.passiv = true;
    z.familien = [...new Set([...z.familien, ...Object.keys(e.fam || {}).map(Number)])].sort((a, b) => a - b);
    if (e.t) z.datum = z.datum && z.datum < day(e.t) ? z.datum : day(e.t);
  }
}
const sortKeys = (o) => Object.fromEntries(Object.entries(o).sort(([a], [b]) => a - b));
for (const k of ['raenge', 'listen', 'familien', 'zauberbuch']) survey[k] = sortKeys(survey[k]);
// je Rang eine Zeile, wie bei den Beobachtungen
const block = (o, indent) => '{\n' + Object.entries(o).map(([k, v]) => `${indent}  ${JSON.stringify(k)}: ${JSON.stringify(v)}`).join(',\n') + `\n${indent}}`;
fs.writeFileSync(SURVEY_OUT, '{\n' + ['raenge', 'listen', 'familien', 'zauberbuch']
  .map((k) => `  ${JSON.stringify(k)}: ${Object.keys(survey[k]).length ? block(survey[k], '  ') : '{}'}`).join(',\n') + '\n}\n');
console.log(`Erhebung aus ${surveyFiles} Datei(en): ${Object.keys(survey.raenge).length} Ränge, `
  + `${Object.keys(survey.listen).length} Familien mit Liste, ${Object.keys(survey.zauberbuch).length} Zauber aus Zauberbüchern `
  + '→ tools/eigene/erhebung.json');
