// Baut aus den selbst erhobenen Daten in tools/eigene/ das Datenmodell tools/data.json.
// Aufruf: node tools/build-data.mjs [--neue-faehigkeiten]   (danach node tools/build-addon.mjs)
//
// Grundsatz (docs/konzept/entscheidungen.md): In die Daten kommt nur, was im Spiel selbst erhoben wurde
// – im Ausbildungsfenster, beim Anvisieren, beim Zähmen – oder ein Befund aus dem Spiel. Fremde Quellen
// gibt es hier nicht. Fehlt einer Angabe der Beleg, bricht
// das Skript ab, statt sie still zu übernehmen.
import { execFileSync } from 'node:child_process';
import fs from 'node:fs';
import path from 'node:path';
import { fileURLToPath } from 'node:url';

const HERE = path.dirname(fileURLToPath(import.meta.url));
const OWN = path.join(HERE, 'eigene');
const OUT = path.join(HERE, 'data.json');
const read = (name) => JSON.parse(fs.readFileSync(path.join(OWN, name), 'utf8'));

// Belegung eines Lehrtiers (`conf`): 1 belegt, 2 unsicher, 3 unbelegt (geschätzt; gibt es noch nicht).
// Widerlegte Paare werden nicht ausgeliefert.
const CONF_SURE = 1, CONF_UNSURE = 2;
// Fremde Beobachtungen zählen ab so vielen verschiedenen Meldern als belegt – wie im Addon (Core/Observe.lua).
// Eigene gelten sofort als bewiesen, gesehen wie nicht gesehen.
const FOREIGN_NEEDED = 3; // bis 17.10.2026: 10 (#1)

// faehigkeiten.json: von Hand, was die Erhebung nicht liefert (etwa das Angriffstempo):
//   [{ en?, de?, icon?, kind: general|family|trait, source: tame|trainer|unknown,
//   speed? (nur trait), families: [Familien-ID], ranks: [{ id, rank, level?, tp? }], beleg }]
const manualAbilities = read('faehigkeiten.json');
// erhebung.json (tools/import-observations.mjs aus Core/Survey.lua): Ränge mit Zauber-ID und die
// Wildtierausbildung je Familie – daraus die übrigen Fähigkeiten, siehe abilitiesFromSurvey
const survey = read('erhebung.json');
// familien.json: { Familien-ID: { de?, en?, icon?, beleg } }
const familiesIn = read('familien.json');
// tiere.json: { NPC-ID: { de?, en?, fam?, min?, max?, cls?, beleg } }
const beastsIn = read('tiere.json');
// sichtungen.json: [{ npc, stufe, einstufung, familie, sprache, name, zeit, melder }] (tools/import-observations.mjs)
const sightingsAll = fs.existsSync(path.join(OWN, 'sichtungen.json')) ? read('sichtungen.json') : [];
// beobachtungen.json: [{ npc, stufe, zauber: [IDs], tempo, zeit, melder }] (tools/import-observations.mjs)
const observations = read('beobachtungen.json');
// eigene-melder.json: Kürzel der eigenen Charaktere (ForeverHunterPetsDB.myReps), von import-observations.mjs
const ownReps = new Set(read('eigene-melder.json'));
// korrekturen.json: [{ npc, name, ability (englisch), rank, befund: bestätigt|widerlegt, quelle, datum }]
const corrections = read('korrekturen.json');
// fundorte.json: [{ npc, name, map (uiMapID), punkte: [[x, y], …] in Prozent, quelle, datum }]
const places = read('fundorte.json');
// zellen.json: { npc: { uiMapID: "xyxy…" } }, eigene Fundort-Zellen aus dem Spiel (tools/import-observations.mjs)
const cells = fs.existsSync(path.join(OWN, 'zellen.json')) ? read('zellen.json') : {};
// zellen-fremd.json: { npc: { uiMapID: { melder: "xyxy…" } } }, Zellen anderer Spieler (tools/import-observations.mjs)
const foreignCells = fs.existsSync(path.join(OWN, 'zellen-fremd.json')) ? read('zellen-fremd.json') : {};
// melder-wege.json: { melder: [absender, …] }, über welche Absender ein Kürzel ankam (tools/import-observations.mjs, #15)
const ways = fs.existsSync(path.join(OWN, 'melder-wege.json')) ? read('melder-wege.json') : {};
// nicht-zaehmbar.json: [{ npc, name?, karten?: [uiMapID], stufen?: { min, max }, grund, quelle, datum }], Sperrliste (#90):
// Begleiter von NPCs und andere Tiere, die sich nicht zähmen lassen. Ein Eintrag gilt, wenn alle Felder, die er hat,
// zutreffen; ohne karten überall, ohne stufen auf jeder Stufe.
const blockList = fs.existsSync(path.join(OWN, 'nicht-zaehmbar.json')) ? read('nicht-zaehmbar.json') : [];

// Fremde Melder zählen nur, wenn sie zusammen über mindestens zwei verschiedene Absender kamen – ein einzelner
// Absender genügt nie (#15, wie ns.ViaDistinct in Core/Comm.lua). Ein Melder ohne Angabe (vor diesem Stand
// empfangen) gilt als „Herkunft unbekannt“ und zählt wie bisher; ohne melder-wege.json bleibt alles wie bisher.
const enough = (reps) => {
  if (reps.size < FOREIGN_NEEDED) return false;
  let first = null;
  for (const rep of reps) {
    const l = ways[rep];
    if (!Array.isArray(l) || !l.length) return true;
    for (const from of l) {
      if (first == null) first = from; else if (from !== first) return true;
    }
  }
  return false;
};

const problems = [];
const need = (cond, msg) => { if (!cond) problems.push(msg); };
const warnings = [];

// ---- Sperrliste (#90) ----
// Wie ns.Blocked im Addon (Core/Sightings.lua): Eine Bedingung ohne Wert (etwa die Karte einer Sichtung) trifft nicht zu.
const blocks = new Map(); // NPC-ID → [Eintrag, …]
for (const e of blockList) {
  need(Number.isInteger(e.npc) && e.npc > 0, `Sperrliste: Eintrag ohne NPC-ID: ${JSON.stringify(e)}`);
  need(e.quelle && e.datum, `Sperrliste: ${e.npc} ohne Quelle oder Datum`);
  need(['besitzer', 'zähmen-scheitert', 'befund'].includes(e.grund), `Sperrliste: ${e.npc} mit unbekanntem Grund ${e.grund}`);
  need(e.karten == null || (Array.isArray(e.karten) && e.karten.length && e.karten.every(Number.isInteger)),
    `Sperrliste: ${e.npc} mit ungültigen Karten`);
  need(e.stufen == null || Number.isInteger(e.stufen.min), `Sperrliste: ${e.npc} mit ungültigen Stufen`);
  (blocks.get(e.npc) ?? blocks.set(e.npc, []).get(e.npc)).push(e);
}
const blocked = (npc, map, level) => (blocks.get(Number(npc)) || []).some((e) =>
  (e.karten == null || (map != null && e.karten.includes(Number(map))))
  && (e.stufen == null || (level != null && level >= e.stufen.min && level <= (e.stufen.max ?? e.stufen.min))));
// Sichtungen kennen keine Karte: Hier fallen nur die heraus, die überall gesperrt sind. Gesperrte Tiere, von denen nach
// den Fundorten nichts übrig bleibt, fallen unten ganz aus den Tieren (beastIds).
const sightings = sightingsAll.filter((s) => !blocked(s.npc, null, s.stufe));
let blockedOut = sightingsAll.length - sightings.length;

// ---- Fähigkeiten aus der Erhebung ----
// Regeln (Inkrement 2b, 16.10.2026):
// - Ränge mit demselben Namen bilden eine Fähigkeit (deutscher Name vor englischem).
// - Bietet der Tierausbilder in der Stadt einen Rang an, lernt man die Fähigkeit dort („trainer“) und jede
//   Familie kann sie; sonst lernt man sie von Tieren („tame“), und sie gilt nur für die Familien, in deren
//   Wildtierausbildung sie stand – was nicht gesehen wurde, wird nicht angenommen.
// - TP: Die Wildtierausbildung zeigt beim aktuellen Rang des Pets 0, bei höheren den Preis abzüglich dessen,
//   bei niedrigeren den vollen Preis (UI/Training.lua). Daraus wird der Preis zurückgerechnet; was sich noch
//   nicht rechnen lässt, bleibt leer.
// - Aktueller Rang (#4): gelernt („used“) – oder mit 0 angezeigt, und Pets dieser Familie hatten ihn im
//   Zauberbuch. Die Liste zeigt einen Rang, den das Pet mitbrachte, nicht immer als gelernt (Ducken beim
//   Weitschreiter: 0 und 2 statt 8 und 10).
// - Eine 0 als voller Preis ist nur ein Preis, wenn mindestens zwei Familien sie zeigen (verfügbar oder
//   gelernt) und keine Gleichung mehr ergibt (#4). Sonst bleibt der Preis leer: Prankenhieb und Gespinst
//   standen nur mit 0 da, ohne jeden Gegenbeleg; Knurren zeigen viele Familien mit 0.
// Tempo-Einträge heißen alle gleich; das Tempo macht sie eindeutig
const label = (a) => (a.en || a.de) + (a.kind === 'trait' ? ` ${a.speed} s` : '');
const nameOf = (n) => n.deDE ?? n.enUS ?? n.enGB ?? Object.values(n)[0];
function abilitiesFromSurvey() {
  const groups = new Map();
  for (const [id, r] of Object.entries(survey.raenge)) {
    const name = nameOf(r.name);
    if (!groups.has(name)) groups.set(name, []);
    groups.get(name).push({ id: +id, ...r });
  }
  // Zauber aus dem Zauberbuch eines Pets, die in keiner Liste stehen: Das Pet kann sie, der Jäger noch
  // nicht (etwa Tanz des Täuschers, 16.10.2026). Sie kommen dazu, ohne Pet-Stufe und TP; die Familien
  // sind die der Pets, die sie hatten.
  // Die Familien aus dem Zauberbuch gelten auch für Ränge aus den Listen: Eine Liste zählt nur vollständig, ein
  // Rang kann also in einer Wildtierausbildung gestanden haben, deren Liste fehlt (Wildes Verwunden, #30).
  const fromBook = new Map(); // Zauber-ID → Familien
  for (const [id, z] of Object.entries(survey.zauberbuch || {})) {
    if (z.rang == null) continue;
    if (survey.raenge[id]) { fromBook.set(+id, z.familien || []); continue; }
    const name = nameOf(z.name);
    if (!groups.has(name)) groups.set(name, []);
    groups.get(name).push({ id: +id, name: z.name, rang: z.rang, datum: z.datum });
    fromBook.set(+id, z.familien || []);
  }
  // TP: aus jeder Liste Gleichungen „Preis(id) = angezeigt (+ Preis(aktueller Rang))“, dann auflösen
  const rankOfId = new Map([...groups.values()].flat().map((r) => [r.id, r]));
  const inBook = (id, fam) => (survey.zauberbuch?.[id]?.familien || []).map(Number).includes(Number(fam));
  const equations = [];
  for (const [fam, l] of Object.entries(survey.listen)) {
    const current = new Map(); // Name → aktueller Rang (gelernt oder mitgebracht) mit höchstem Rang
    const rows = Object.entries(l.zeilen).map(([id, v]) => {
      const [status, shown] = v.split('/');
      return { r: rankOfId.get(+id), status, shown: Number(shown) };
    }).filter((x) => x.r && Number.isFinite(x.shown));
    for (const x of rows) {
      const name = nameOf(x.r.name);
      const known = x.status === 'used' || (x.shown === 0 && inBook(x.r.id, fam));
      if (known && x.r.rang > (current.get(name)?.rang ?? 0)) current.set(name, x.r);
    }
    for (const x of rows) {
      const cur = current.get(nameOf(x.r.name));
      if (!cur || x.r.rang < cur.rang) equations.push({ id: x.r.id, tp: x.shown, fam, status: x.status });
      else if (x.r.rang > cur.rang) equations.push({ id: x.r.id, tp: x.shown, plus: cur.id, fam });
    }
  }
  // Eine 0 als voller Preis zählt erst, wenn sie belegt ist (siehe oben); bis dahin rechnet sie nicht mit
  const zeros = new Map(); // Zauber-ID → Familien, die ihn mit 0 als vollem Preis zeigen (verfügbar oder gelernt)
  for (const q of equations) {
    if (q.plus == null && q.tp === 0 && q.status !== 'unavailable') (zeros.get(q.id) ?? zeros.set(q.id, new Set()).get(q.id)).add(q.fam);
  }
  const tp = new Map();
  const solve = () => { for (let changed = true; changed;) {
    changed = false;
    for (const q of equations) {
      if (q.plus == null && q.tp === 0) continue;
      if (q.plus != null && !tp.has(q.plus)) continue;
      const v = q.tp + (q.plus != null ? tp.get(q.plus) : 0);
      if (!tp.has(q.id)) { tp.set(q.id, v); changed = true; } else if (tp.get(q.id) !== v && !q.warned) {
        q.warned = true;
        warnings.push(`TP für Zauber ${q.id} widersprechen sich: ${tp.get(q.id)} und ${v} (Familie ${q.fam})`);
      }
    }
  } };
  solve();
  for (const [id, fams] of zeros) if (!tp.has(id) && fams.size >= 2) tp.set(id, 0);
  solve();

  const out = [];
  for (const [name, ranks] of groups) {
    ranks.sort((x, y) => x.rang - y.rang);
    const ids = new Set(ranks.map((r) => r.id));
    const trainer = ranks.some((r) => r.tierausbilder);
    const families = [...new Set([
      ...Object.entries(survey.listen)
        .filter(([, l]) => Object.keys(l.zeilen).some((id) => ids.has(+id)))
        .map(([fam]) => +fam),
      ...[...ids].flatMap((id) => fromBook.get(id) || []),
    ])].sort((a, b) => a - b);
    const first = ranks[0];
    out.push({
      de: first.name.deDE, en: first.name.enUS ?? first.name.enGB, icon: first.icon,
      kind: trainer ? 'general' : 'family', source: trainer ? 'trainer' : 'tame',
      families: trainer ? [] : families,
      ranks: ranks.map((r) => ({ id: r.id, rank: r.rang, level: r.petStufe ?? null, tp: tp.get(r.id) ?? null })),
      beleg: `Erhebung im Spiel (Wildtierausbildung, Tierausbilder, Zauberbuch), seit ${ranks.map((r) => r.datum).sort()[0]}`,
    });
    if (!name) problems.push(`Rang ohne Namen in erhebung.json: ${[...ids].join(', ')}`);
  }
  return out;
}

// Von Hand Gepflegtes geht vor: Eine erhobene Fähigkeit, die einen Rang mit ihm teilt, entfällt.
const manualIds = new Set(manualAbilities.flatMap((a) => (a.ranks || []).map((r) => r.id)));
// ---- Angriffstempo ----
// Ein abweichendes Tempo ist eine passive Fähigkeit im Zauberbuch des Pets, mit eigener Zauber-ID und dem
// Namen im Spiel („Schnellerer Angriff III“, „Langsamerer Angriff II“; im Spiel geprüft am 16.10.2026).
// Normales Tempo (2,0 s) hat keine. Welcher Zauber welches Tempo bedeutet, zeigen die Zähmungen: Ein
// passiver Zauber ohne Rang, der immer mit demselben Tempo auftritt, ist dieses Tempo. Für ein beobachtetes
// Tempo, dessen Zauber noch niemand gesehen hat, bleibt eine negative Ersatz-ID (−150 für 1,5 s).
// Die Lehrtiere kommen wie bei den Fähigkeiten aus den Beobachtungen (siehe unten).
const NORMAL_SPEED = 2.0;
function traitsFromObservations() {
  const have = new Set(manualAbilities.filter((a) => a.kind === 'trait').map((a) => Math.round(Number(a.speed) * 10)));
  const book = survey.zauberbuch || {};
  const isTempoSpell = (id) => book[id]?.passiv && book[id].rang == null && !survey.raenge[id];
  const speedsOf = new Map();   // Zauber-ID → Set(Tempo × 10)
  const observed = new Set();   // Tempo × 10
  for (const o of observations) {
    if (o.tempo == null) continue;
    const k = Math.round(o.tempo * 10);
    if (Math.abs(o.tempo - NORMAL_SPEED) >= 0.05) observed.add(k);
    for (const id of o.zauber || []) {
      if (!isTempoSpell(id)) continue;
      if (!speedsOf.has(id)) speedsOf.set(id, new Set());
      speedsOf.get(id).add(k);
    }
  }
  // auch das Tempo gesichteter wilder Tiere: es ist das, das sie gezähmt haben
  for (const s of sightings) {
    if (s.tempo != null && Math.abs(s.tempo - NORMAL_SPEED) >= 0.05) observed.add(Math.round(s.tempo * 10));
  }
  const out = [];
  const bySpeed = new Map();
  for (const [id, ks] of speedsOf) {
    if (ks.size !== 1) {
      warnings.push(`Tempo-Zauber ${id} trat mit verschiedenen Tempi auf: ${[...ks].map((k) => k / 10).join(', ')} s`);
      continue;
    }
    const k = [...ks][0];
    if (have.has(k) || bySpeed.has(k)) continue;
    const z = book[id];
    bySpeed.set(k, true);
    out.push({
      de: z.name.deDE, en: z.name.enUS ?? z.name.enGB, kind: 'trait', source: 'tame', speed: k / 10, families: [],
      ranks: [{ id: Number(id), rank: 1 }],
      beleg: `passiver Zauber im Zauberbuch, Tempo aus den Zähmungen, seit ${z.datum}`,
    });
  }
  for (const k of observed) {
    if (have.has(k) || bySpeed.has(k)) continue;
    out.push({
      de: 'Angriffstempo', en: 'Attack speed', icon: 'INV_Misc_PocketWatch_01',
      kind: 'trait', source: 'tame', speed: k / 10, families: [],
      ranks: [{ id: -k * 10, rank: 1 }],
      beleg: 'beim Zähmen beobachtetes Angriffstempo, Zauber noch nicht gesehen (tools/eigene/beobachtungen.json)',
    });
  }
  return out.sort((a, b) => a.speed - b.speed);
}

const abilitiesIn = [
  ...manualAbilities,
  ...abilitiesFromSurvey().filter((a) => !a.ranks.some((r) => manualIds.has(r.id))),
  ...traitsFromObservations(),
];

// ---- Fähigkeiten ----
const spellRank = new Map(); // Zauber-ID → { a, rank }
for (const a of abilitiesIn) {
  need(a.en || a.de, `Fähigkeit ohne Namen: ${JSON.stringify(a).slice(0, 80)}`);
  need(a.beleg, `Fähigkeit ${label(a)} ohne Beleg`);
  need(['general', 'family', 'trait'].includes(a.kind), `Fähigkeit ${label(a)}: unbekannte Art ${a.kind}`);
  need(Array.isArray(a.ranks) && a.ranks.length, `Fähigkeit ${label(a)} ohne Ränge`);
  for (const r of a.ranks || []) {
    need(Number.isInteger(r.id) && (r.id > 0 || a.kind === 'trait'), `Fähigkeit ${label(a)}: Rang ohne Zauber-ID`);
    need(!spellRank.has(r.id), `Zauber-ID ${r.id} doppelt`);
    spellRank.set(r.id, { a, rank: r.rank });
  }
}

// ---- Familien und Tiere: nur mit Beleg ----
for (const [id, f] of Object.entries(familiesIn)) need(f.beleg, `Familie ${id} ohne Beleg`);
for (const [id, b] of Object.entries(beastsIn)) need(b.beleg, `Tier ${id} ohne Beleg`);

// ---- Lehrtiere aus den Beobachtungen beim Zähmen ----
// je Fähigkeit: "npc:rang" → { own: bool, reps: Set }
const seen = new Map(abilitiesIn.map((a) => [a, new Map()]));
const note = (a, npc, rank, rep) => {
  const k = `${npc}:${rank}`;
  const e = seen.get(a).get(k) || { npc, rank, own: false, reps: new Set() };
  e.reps.add(rep);
  if (ownReps.has(rep)) e.own = true;
  seen.get(a).set(k, e);
};
const level = new Map(); // NPC-ID → [min, max] aus den Beobachtungen
let unknownSpells = 0;
for (const o of observations) {
  need(o.melder, `Beobachtung ohne Melder: ${JSON.stringify(o)}`);
  const lv = level.get(o.npc) || [o.stufe, o.stufe];
  level.set(o.npc, [Math.min(lv[0], o.stufe), Math.max(lv[1], o.stufe)]);
  for (const id of o.zauber || []) {
    const hit = spellRank.get(id);
    if (!hit) { unknownSpells++; continue; }
    if (hit.a.source === 'trainer') continue; // vom Tierausbilder, sagt nichts über das Tier
    note(hit.a, o.npc, hit.rank, o.melder);
  }
  // Angriffstempo: die Tempo-Fähigkeit mit passendem Wert
  if (o.tempo != null) {
    const t = abilitiesIn.find((a) => a.kind === 'trait' && Math.abs(Number(a.speed) - o.tempo) < 0.05);
    if (t) note(t, o.npc, t.ranks[0].rank, o.melder);
  }
}
// Angriffstempo aus den Sichtungen: Das wilde Tier hat das Tempo, das es gezähmt hat (Probe 16.10.2026).
// Belegt wie beim Zähmen: eigene sofort, fremde ab FOREIGN_NEEDED Meldern.
for (const s of sightings) {
  if (s.tempo == null || Math.abs(s.tempo - NORMAL_SPEED) < 0.05) continue;
  const t = abilitiesIn.find((a) => a.kind === 'trait' && Math.abs(Number(a.speed) - s.tempo) < 0.05);
  if (t) note(t, s.npc, t.ranks[0].rank, s.melder);
}

// ---- Befunde ----
// Ein Befund nennt die Fähigkeit über die Zauber-ID des Rangs (zauber) oder ihren Namen (ability)
const byName = new Map(abilitiesIn.flatMap((a) => [[a.en, a], [a.de, a]]).filter(([n]) => n));
const refuted = new Set();
for (const c of corrections) {
  need(c.quelle && c.datum, `Befund zu ${c.npc} ohne Quelle oder Datum`);
  const a = (c.zauber && spellRank.get(c.zauber)?.a) || byName.get(c.ability);
  if (!a) continue; // Fähigkeit noch nicht erhoben
  if (c.befund === 'bestätigt') {
    const k = `${c.npc}:${c.rank}`;
    const e = seen.get(a).get(k) || { npc: c.npc, rank: c.rank, own: false, reps: new Set() };
    e.own = true;
    seen.get(a).set(k, e);
  } else if (c.befund === 'widerlegt') refuted.add(`${label(a)}:${c.npc}:${c.rank}`);
}

// ---- Widerlegt und Widersprüche ----
// Die Fähigkeiten hängen an der NPC-ID, nur der Rang an der Stufe. Eine Zähmung widerlegt ein Paar, wenn
// die Stufe reichte und weder dieser noch ein höherer Rang da war (das Zauberbuch zeigt nur den höchsten).
// Eigene Zähmungen gelten als bewiesen: Widerlegt eine eigene ein Paar, das kein eigener Charakter gesehen
// hat, fällt es heraus. Unter Fremden geht gesehen vor. Jeder Widerspruch wird gemeldet – dann wackelt
// die Annahme, dass die NPC-ID die Fähigkeiten festlegt.
for (const [a, pairs] of seen) {
  if (a.kind === 'trait') continue;
  for (const e of pairs.values()) {
    const r = a.ranks.find((x) => x.rank === e.rank);
    const higher = a.ranks.filter((x) => x.rank > e.rank).map((x) => x.id);
    const against = observations.filter((o) => o.npc === e.npc && o.stufe >= (r.level ?? 0)
      && !(o.zauber || []).includes(r.id) && !higher.some((id) => (o.zauber || []).includes(id)));
    if (!against.length) continue;
    const ownAgainst = !e.own && against.some((o) => ownReps.has(o.melder));
    if (ownAgainst) refuted.add(`${label(a)}:${e.npc}:${e.rank}`);
    warnings.push(`Widerspruch: NPC ${e.npc} mit ${label(a)} ${e.rank} gesehen, aber ${against.length} Zähmung(en) `
      + `ohne (Stufe ${against.map((o) => o.stufe).join(', ')})`
      + (ownAgainst ? ' – eigene Zähmung entscheidet, das Paar entfällt' : ''));
  }
}

// ---- Fundorte (Promille, wie bisher im Addon) ----
const coords = {};
for (const p of places) {
  need(p.quelle && p.datum, `Fundort zu ${p.npc} ohne Quelle oder Datum`);
  need(Number.isInteger(p.map), `Fundort zu ${p.npc} ohne uiMapID`);
  if (blocked(p.npc, p.map)) { blockedOut++; continue; }
  const list = ((coords[p.npc] ??= {})[p.map] ??= []);
  for (const [x, y] of p.punkte) list.push(Math.round(x * 10), Math.round(y * 10));
}
// Zellen aus dem Spiel: Mittelpunkt jeder Zelle (Raster 50 × 50, Core/Places.lua). Eigene sofort, fremde wie
// Zähmungen und Sichtungen: ab FOREIGN_NEEDED verschiedenen Meldern, ein eigenes Kürzel gilt als eigen (#2).
const CELL_ALPHA = '0123456789ABCDEFGHIJKLMNOPQRSTUVWXYZabcdefghijklmn';
const shipCells = new Map(); // "npc:map" → Set der Zellen
for (const [npc, maps] of Object.entries(cells)) {
  for (const [map, s] of Object.entries(maps)) {
    if (blocked(npc, map)) { blockedOut++; continue; }
    const set = shipCells.get(`${npc}:${map}`) ?? new Set();
    for (const c of s.match(/../g) || []) set.add(c);
    shipCells.set(`${npc}:${map}`, set);
  }
}
let foreignShipped = 0;
for (const [npc, maps] of Object.entries(foreignCells)) {
  for (const [map, byRep] of Object.entries(maps)) {
    if (blocked(npc, map)) { blockedOut++; continue; }
    const reps = new Map(); // Zelle → Set der Melder
    for (const [rep, s] of Object.entries(byRep)) {
      for (const c of s.match(/../g) || []) (reps.get(c) ?? reps.set(c, new Set()).get(c)).add(rep);
    }
    const set = shipCells.get(`${npc}:${map}`) ?? new Set();
    for (const [c, who] of reps) {
      if (set.has(c)) continue;
      if (enough(who) || [...who].some((r) => ownReps.has(r))) { set.add(c); foreignShipped++; }
    }
    if (set.size) shipCells.set(`${npc}:${map}`, set);
  }
}
for (const [key, set] of shipCells) {
  const [npc, map] = key.split(':');
  const list = ((coords[npc] ??= {})[map] ??= []);
  for (const c of set) {
    const cx = CELL_ALPHA.indexOf(c[0]), cy = CELL_ALPHA.indexOf(c[1]);
    need(cx >= 0 && cy >= 0, `Zelle „${c}“ bei ${npc} ungültig`);
    list.push(Math.round((cx + 0.5) * 20), Math.round((cy + 0.5) * 20));
  }
}
if (foreignShipped) console.log(`${foreignShipped} fremde Fundort-Zellen belegt (ab ${FOREIGN_NEEDED} Meldern)`);

if (problems.length) {
  console.error(`Abbruch – ${problems.length} Angaben ohne Beleg oder fehlerhaft:\n  ` + problems.join('\n  '));
  process.exit(1);
}

// ---- Ausgabe ----
const abilities = abilitiesIn.map((a) => {
  const teach = [...seen.get(a).values()]
    .filter((e) => !refuted.has(`${label(a)}:${e.npc}:${e.rank}`))
    .map((e) => ({ id: e.npc, rank: e.rank, conf: e.own || enough(e.reps) ? CONF_SURE : CONF_UNSURE }))
    .sort((x, y) => x.rank - y.rank || x.conf - y.conf || x.id - y.id);
  return {
    en: a.en || null, de: a.de || null, icon: a.icon || null, kind: a.kind, source: a.source || 'unknown',
    speed: a.kind === 'trait' ? Number(a.speed) : null,
    families: a.families || [],
    ranks: a.ranks.map((r) => ({ id: r.id, rank: r.rank, level: r.level ?? null, tp: r.tp ?? null })),
    teach,
  };
});

// ---- Sichtungen: Name, Stufe, Familie, Einstufung je Tier ----
// Eigene Sichtungen zählen sofort, fremde erst, wenn FOREIGN_NEEDED verschiedene Melder das Tier gesehen haben (wie
// beim Zähmen). Familie und Einstufung: die eigene, sonst die häufigste.
// Namen (#3, #47): je Sprache aus den Sichtungen dieser Sprache. Sie kommen nur an Tiere, die ohnehin ausgeliefert
// werden (siehe beastIds unten). Der eigene Name geht vor; ein fremder nur, wenn genug verschiedene Melder ihn nennen
// (enough), unter mehreren der mit den meisten Meldern. Mehrere Namen je Tier und Sprache stehen unter „Hinweise“.
const sighted = new Map(); // NPC-ID → { de, en, fam, cls, min, max }
const sightedNames = new Map(); // NPC-ID → { de, en }
{
  const byNpc = new Map();
  for (const s of sightings) {
    need(s.melder, `Sichtung ohne Melder: ${JSON.stringify(s)}`);
    if (!byNpc.has(s.npc)) byNpc.set(s.npc, []);
    byNpc.get(s.npc).push(s);
  }
  const pick = (list, f) => {
    const own = list.find((s) => ownReps.has(s.melder) && f(s) != null);
    if (own) return f(own);
    const count = new Map();
    for (const s of list) if (f(s) != null) count.set(f(s), (count.get(f(s)) || 0) + 1);
    return [...count].sort((x, y) => y[1] - x[1])[0]?.[0] ?? null;
  };
  const pickName = (npc, lang, list) => {
    const own = list.find((s) => ownReps.has(s.melder));
    const reps = new Map(); // Name → Set der Melder
    for (const s of list) {
      if (!reps.has(s.name)) reps.set(s.name, new Set());
      reps.get(s.name).add(s.melder);
    }
    if (reps.size > 1) {
      warnings.push(`Tier ${npc} (${lang}): mehrere Namen – `
        + [...reps].map(([n, r]) => `„${n}“ (${r.size} Melder)`).join(', '));
    }
    if (own) return own.name;
    const best = [...reps].filter(([, r]) => enough(r)).sort((x, y) => y[1].size - x[1].size)[0];
    return best ? best[0] : null;
  };
  for (const [npc, list] of byNpc) {
    sightedNames.set(npc, {
      de: pickName(npc, 'deDE', list.filter((s) => s.sprache === 'deDE')),
      en: pickName(npc, 'enUS', list.filter((s) => s.sprache === 'enUS' || s.sprache === 'enGB')),
    });
    const own = list.filter((s) => ownReps.has(s.melder));
    const foreignReps = new Set(list.filter((s) => !ownReps.has(s.melder)).map((s) => s.melder));
    const use = own.length ? own : enough(foreignReps) ? list : null;
    if (!use) continue;
    const levels = use.map((s) => s.stufe);
    sighted.set(npc, {
      fam: pick(use, (s) => s.familie), cls: pick(use, (s) => s.einstufung),
      min: Math.min(...levels), max: Math.max(...levels),
    });
  }
}

// Jedes Tier, das etwas beibringt, einen Fundort hat oder gesichtet wurde. Von Hand Gepflegtes geht vor,
// dann die Sichtung; die Stufe umfasst Sichtungen und Zähmungen.
// Ein gesperrtes Tier ohne Fundort und ohne Lehre fällt ganz heraus (#90): Von ihm weiß man nur, dass es nicht
// zähmbar ist. Von Hand Gepflegtes bleibt.
const teachers = new Set(abilities.flatMap((a) => a.teach.map((t) => t.id)));
const beastIds = new Set([
  ...Object.keys(beastsIn).map(Number),
  ...Object.keys(coords).map(Number),
  ...teachers,
  ...[...sighted.keys()].filter((id) => !(blocks.has(id) && !coords[id] && !teachers.has(id))),
]);
const beasts = {};
for (const id of [...beastIds].sort((x, y) => x - y)) {
  const b = beastsIn[id] || {};
  const s = sighted.get(id) || {};
  const n = sightedNames.get(id) || {};
  const lv = [level.get(id), s.min != null ? [s.min, s.max] : null].filter(Boolean);
  const min = lv.length ? Math.min(...lv.map((x) => x[0])) : null;
  const max = lv.length ? Math.max(...lv.map((x) => x[1])) : null;
  beasts[id] = {
    de: b.de || n.de || null, en: b.en || n.en || null, fam: b.fam ?? s.fam ?? null,
    min: b.min ?? min, max: b.max ?? max, cls: b.cls ?? s.cls ?? 0,
  };
}

const families = {};
// erhobene Familien (Name, wie der Client ihn nennt), von Hand Gepflegtes geht vor
for (const [id, f] of Object.entries(survey.familien)) families[id] = { de: f.name.deDE || null, en: f.name.enUS || f.name.enGB || null, icon: f.icon ?? null };
for (const [id, f] of Object.entries(familiesIn)) families[id] = { de: f.de || null, en: f.en || null, icon: f.icon || null };

// Sperrliste fürs Addon (ns.Data.notTameable): nur NPC, Karten und Stufen
const nichtZaehmbar = blockList.map((e) => ({
  npc: e.npc, karten: e.karten ?? null, stufen: e.stufen ?? null,
})).sort((x, y) => x.npc - y.npc);
if (blockedOut) console.log(`${blockedOut} gesperrte Einträge (Sichtungen, Fundorte, Zellen je Karte) nicht übernommen (Sperrliste)`);

const data = { generatedAt: new Date().toISOString(), families, beasts, coords, abilities, nichtZaehmbar };

// ---- Vergleich mit dem Stand in Git (#37) ----
// Neue, weggefallene und umgezogene Fähigkeiten (Herkunft tame ↔ trainer) brechen ab, bis man sie geprüft hat und
// mit --neue-faehigkeiten bestätigt: So wären die Jägerzauber aus #34 nicht unbemerkt in die Stammdaten gekommen.
// Verglichen wird mit HEAD, nicht mit der Datei auf der Platte – sonst meldete ein zweiter Lauf nichts mehr.
// Eine Fähigkeit ist dieselbe, wenn sie einen Rang (Zauber-ID) mit ihr teilt.
const countPairs = (d) => d.abilities.reduce((s, a) => s + a.teach.length, 0);
const countPoints = (d) => Object.values(d.coords).reduce((s, z) => s + Object.values(z).reduce((t, l) => t + l.length / 2, 0), 0);
const countRanks = (d) => d.abilities.reduce((s, a) => s + a.ranks.length, 0);
let old = null;
try {
  old = JSON.parse(execFileSync('git', ['show', 'HEAD:tools/data.json'], {
    cwd: path.dirname(HERE), encoding: 'utf8', maxBuffer: 64 * 1024 * 1024, stdio: ['ignore', 'pipe', 'ignore'],
  }));
} catch {
  console.log('Hinweis: kein Stand von tools/data.json in Git – Fähigkeiten nicht verglichen.');
}
if (old) {
  const nameOfAbility = (a) => (a.de || a.en) + (a.kind === 'trait' ? ` ${a.speed} s` : '');
  const describe = (a) => `${nameOfAbility(a)}${a.de && a.en ? ` / ${a.en}` : ''} – ${a.kind}, ${a.source}, `
    + `Ränge ${a.ranks.map((r) => `${r.rank}:${r.id}`).join(' ')}, Familien ${a.families.length ? a.families.join(' ') : '–'}, `
    + `Lehrtiere ${a.teach.length}`;
  const oldByRank = new Map(old.abilities.flatMap((a) => a.ranks.map((r) => [r.id, a])));
  const matched = new Set();
  const added = [], moved = [], newRanks = [];
  for (const a of abilities) {
    const was = a.ranks.map((r) => oldByRank.get(r.id)).find(Boolean);
    if (!was) { added.push(a); continue; }
    matched.add(was);
    if (was.source !== a.source) moved.push(`${describe(a)} (vorher ${was.source})`);
    const had = new Set(was.ranks.map((r) => r.id));
    for (const r of a.ranks) if (!had.has(r.id)) newRanks.push(`${nameOfAbility(a)} Rang ${r.rank} (${r.id})`);
  }
  const gone = old.abilities.filter((a) => !matched.has(a));
  const change = (label, before, after) => `${label} ${before} → ${after}${after !== before ? ` (${after > before ? '+' : ''}${after - before})` : ''}`;
  console.log('Gegenüber dem Stand in Git: ' + [
    change('Fähigkeiten', old.abilities.length, abilities.length), change('Ränge', countRanks(old), countRanks(data)),
    change('Lehrtier-Paare', countPairs(old), countPairs(data)), change('Tiere', Object.keys(old.beasts).length, Object.keys(beasts).length),
    change('Fundorte', countPoints(old), countPoints(data)),
  ].join(', '));
  if (newRanks.length) console.log(`Neue Ränge (${newRanks.length}):\n  ` + newRanks.join('\n  '));
  const stop = [
    ...added.map((a) => `neu: ${describe(a)}`),
    ...gone.map((a) => `weggefallen: ${describe(a)}`),
    ...moved.map((s) => `Herkunft gewechselt: ${s}`),
  ];
  if (stop.length) {
    const confirmed = process.argv.includes('--neue-faehigkeiten');
    const text = `${stop.length} ${stop.length === 1 ? 'Änderung' : 'Änderungen'} an den Fähigkeiten:\n  ` + stop.join('\n  ');
    if (!confirmed) {
      console.error(`Abbruch – ${text}\nErst prüfen (etwa Jägerzauber, falsche Tierausbilder-Angaben), dann mit --neue-faehigkeiten bestätigen.`);
      process.exit(1);
    }
    console.log(`Bestätigt (--neue-faehigkeiten) – ${text}`);
  }
}

fs.writeFileSync(OUT, JSON.stringify(data, null, 1) + '\n');

const pairs = countPairs(data);
const points = countPoints(data);
console.log(`Fertig: ${abilities.length} Fähigkeiten, ${spellRank.size} Ränge, ${pairs} Lehrtier-Paare, `
  + `${Object.keys(beasts).length} Tiere, ${Object.keys(families).length} Familien, ${points} Fundorte → ${path.relative(path.dirname(HERE), OUT)}`);
if (unknownSpells) console.log(`${unknownSpells} beobachtete Zauber-IDs gehören zu keiner erhobenen Fähigkeit (erst die Fähigkeiten erheben).`);
if (warnings.length) console.log(`Hinweise (${warnings.length}):\n  ` + warnings.join('\n  '));
