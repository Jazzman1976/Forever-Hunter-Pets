// Baut aus tools/data.json die Datendatei des Addons: Data/Data.lua
// Aufruf: node tools/build-addon.mjs   (vorher node tools/build-data.mjs, wenn sich Daten geändert haben)
import fs from 'node:fs';
import path from 'node:path';
import { fileURLToPath } from 'node:url';

const ROOT = path.resolve(path.dirname(fileURLToPath(import.meta.url)), '..');
const OUT = path.join(ROOT, 'Data', 'Data.lua');
const D = JSON.parse(fs.readFileSync(path.join(ROOT, 'tools', 'data.json'), 'utf8'));

// ---- Lua schreiben ----
const str = (s) => `"${String(s).replace(/\\/g, '\\\\').replace(/"/g, '\\"').replace(/\r?\n/g, '\\n')}"`;
const val = (v) => (typeof v === 'string' ? str(v) : Array.isArray(v) ? `{ ${v.map(val).join(', ')} }` : String(v));
// Felder mit null, undefined oder leerem Text fallen weg – in Lua ist ein fehlendes Feld ohnehin nil
const rec = (o) => `{ ${Object.entries(o).filter(([, v]) => v != null && v !== '').map(([k, v]) => `${k} = ${val(v)}`).join(', ')} }`;
const byNum = (o) => Object.keys(o).map(Number).sort((a, b) => a - b);

const lines = [
  '-- Automatisch erzeugt von tools/build-addon.mjs aus tools/data.json – nicht von Hand bearbeiten.',
  '-- Selbst im Spiel erhobene Daten (tools/eigene/). Namen, Texte und Icons liefert der Client;',
  '-- sie gehören Blizzard Entertainment – siehe NOTICE.md.',
  'local _, ns = ...',
  'ns.Data = {',
  `  generatedAt = ${str(D.generatedAt)},`,
];

lines.push('  families = {');
for (const id of byNum(D.families)) lines.push(`    [${id}] = ${rec(D.families[id])},`);
lines.push('  },');

// Zonen sind uiMapIDs: die Karte, auf der ein Fundort erfasst wurde. Ihren Namen nennt der Client.
const zones = new Set();
for (const id of Object.keys(D.coords)) for (const z of Object.keys(D.coords[id])) zones.add(+z);
lines.push('  zones = {');
for (const z of [...zones].sort((a, b) => a - b)) lines.push(`    [${z}] = { map = ${z} },`);
lines.push('  },');

lines.push('  beasts = {');
for (const id of byNum(D.beasts)) {
  const b = D.beasts[id];
  const zs = byNum(D.coords[id] || {});
  lines.push(`    [${id}] = ${rec({ de: b.de, en: b.en, fam: b.fam, min: b.min, max: b.max, cls: b.cls, zones: zs })},`);
}
lines.push('  },');

// Fundorte: je Punkt sechs Ziffern (x und y in Promille der Karte). Das Addon packt sie erst aus,
// wenn eine Karte aufgeht.
const pad = (n) => String(Math.max(0, Math.min(999, n))).padStart(3, '0');
let points = 0;
lines.push('  coords = {');
for (const id of byNum(D.coords)) {
  const zs = byNum(D.coords[id]).map((z) => {
    points += D.coords[id][z].length / 2;
    return `[${z}] = "${D.coords[id][z].map(pad).join('')}"`;
  });
  lines.push(`    [${id}] = { ${zs.join(', ')} },`);
}
lines.push('  },');

lines.push('  abilities = {');
for (const a of D.abilities) {
  lines.push('    {');
  lines.push(`      ${rec({ de: a.de, en: a.en, icon: a.icon, kind: a.kind, source: a.source, speed: a.speed })
    .slice(2, -2)},`);
  lines.push(`      families = ${val(a.families)},`);
  lines.push('      ranks = {');
  for (const r of a.ranks) lines.push(`        ${rec({ id: r.id, rank: r.rank, level: r.level, tp: r.tp })},`);
  lines.push('      },');
  // { NPC-ID, Rang } für belegt, { NPC-ID, Rang, 2 } unsicher
  lines.push(`      teach = { ${a.teach.map((t) => `{ ${t.id}, ${t.rank}${t.conf > 1 ? `, ${t.conf}` : ''} }`).join(', ')} },`);
  lines.push('    },');
}
lines.push('  },', '}', '');

fs.mkdirSync(path.dirname(OUT), { recursive: true });
fs.writeFileSync(OUT, lines.join('\n'));

const ranks = D.abilities.reduce((s, a) => s + a.ranks.length, 0);
console.log(`Fertig: ${D.abilities.length} Fähigkeiten, ${ranks} Ränge, ${Object.keys(D.families).length} Familien, `
  + `${Object.keys(D.beasts).length} Tiere, ${points} Fundorte auf ${zones.size} Karten → ${path.relative(ROOT, OUT)} `
  + `(${Math.round(fs.statSync(OUT).size / 1024)} KB)`);
