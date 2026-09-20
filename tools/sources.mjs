// Zusätzliche Quellen für fetch-data.mjs:
//  - Wowhead-Kommentare auf den Zauberseiten (rangweise Zähmlisten, Tierausbilder)
//  - Petopia Classic (https://www.wow-petopia.com/classic/) als Classic-Referenz für alle Lücken

const decode = (s) => String(s)
  .replace(/<[^>]*>/g, '')
  .replace(/&nbsp;/g, ' ').replace(/&amp;/g, '&').replace(/&#39;|&apos;/g, "'").replace(/&quot;/g, '"')
  .replace(/&lt;/g, '<').replace(/&gt;/g, '>')
  .replace(/\s+/g, ' ').trim();

// „Wolf, 2-3, Tirisfal Glades“ → { family, min, max, zone }
function parseNpcInfo(txt) {
  const m = decode(txt).match(/^\((.+?),\s*(\d+)(?:\s*-\s*(\d+))?,\s*(.+)\)$/);
  if (!m) return {};
  return { familyEn: m[1], min: +m[2], max: +(m[3] || m[2]), zoneEn: m[4] };
}

// Zusatzangabe in Klammern, darf selbst eine Klammer enthalten: „(Bat, 60, Zul'Gurub (Raid))“
const npcRe = /<a class='npclink classic' href='[^']*npc=(\d+)'>([^<]*)<\/a>\s*(\((?:[^()]|\([^()]*\))*\))?/g;

/** Petopia-Fähigkeitenseite → { [englischer Name]: { families[], ranks: { [n]: { level, tp, desc, trainer, npcs[] } } } } */
export function parsePetopiaAbilities(html) {
  const out = {};
  const sections = html.split(/<h3 class='guide_heading classic' id='/).slice(1);
  for (const sec of sections) {
    const name = decode(sec.slice(sec.indexOf('>') + 1, sec.indexOf('</h3>')));
    const famM = sec.match(/<span class='ability_family_list classic'>([\s\S]*?)<\/span>/);
    const families = famM ? decode(famM[1]).split(/\s*,\s*/).filter(Boolean) : [];
    const ranks = {};
    for (const li of sec.split(/<li id='[a-z]+\d+' class='abilityrank classic'>/).slice(1)) {
      const head = li.match(/<span class='abilityrankname classic'>[^<]*?(\d+)<\/span>:\s*Pet Level (\d+), Cost (\d+) TP/);
      if (!head) continue;
      const descM = li.match(/<span class='abilityrankdesc classic'>([\s\S]*?)<\/span>\s*<span class='abilitysourceheading/);
      const npcs = [...li.matchAll(npcRe)].map((m) => ({ id: +m[1], nameEn: decode(m[2]), ...parseNpcInfo(m[3] || '') }));
      ranks[+head[1]] = {
        level: +head[2], tp: +head[3],
        desc: descM ? decode(descM[1]) : '',
        trainer: /learned from trainers/i.test(li),
        npcs,
      };
    }
    out[name] = { families, ranks };
  }
  return out;
}

/** Petopia-Angriffstempo-Seite → { '1.0': [npc…], … } */
export function parsePetopiaAttackSpeeds(html) {
  const out = {};
  const parts = html.split(/<h4 class='guideheading attackspeed classic' id='attackspeed_/).slice(1);
  for (const p of parts) {
    const speed = p.slice(0, p.indexOf("'"));
    const list = p.slice(0, p.indexOf('</ul>'));
    out[speed] = [...list.matchAll(npcRe)].map((m) => ({ id: +m[1], nameEn: decode(m[2]), ...parseNpcInfo(m[3] || '') }));
  }
  return out;
}

/** Kommentar-Rohdaten (lv_comments) einer Zauberseite. */
export function extractComments(html, evalLiteral, sliceLiteral) {
  const out = [];
  for (const m of html.matchAll(/var lv_comments\d+ = /g)) {
    let arr;
    try { arr = evalLiteral(sliceLiteral(html, m.index + m[0].length)); } catch { continue; }
    const walk = (cs) => { for (const c of cs) { out.push(c); if (c.replies) walk(c.replies); } };
    walk(arr);
  }
  return out;
}

/**
 * Liest aus Kommentaren rangweise Zähmlisten.
 * Tabellen (Spalte = Rang) → { [spellId]: { tp, npcIds[] } }. Einfache Listen („Can be learned by taming: [npc=…]“)
 * werden dem Rang der Seite zugeordnet, auf der der Kommentar steht.
 */
export function parseCommentLists(comment, pageSpellId) {
  const body = String(comment.body || '');
  const result = {};
  const table = body.match(/\[table[\s\S]*?\[\/table\]/);
  if (table) {
    const rows = table[0].split(/\[tr\]/).slice(1).map((r) => r.split(/\[td\]/).slice(1));
    const header = rows.find((r) => r.some((c) => /\[spell=\d+\]/.test(c)));
    if (header) {
      const ids = header.map((c) => +(c.match(/\[spell=(\d+)\]/) || [])[1]);
      const ranks = header.map((c) => +(c.match(/Rank (\d+)/i) || [])[1] || null);
      for (const r of rows) {
        r.forEach((cell, i) => {
          const id = ids[i];
          if (!id) return;
          const e = (result[id] ??= { rank: ranks[i], tp: null, npcIds: [] });
          const tp = cell.match(/Cost:\s*\[b\](\d+)\s*TP/i);
          if (tp) e.tp = +tp[1];
          for (const n of cell.matchAll(/npc=(\d+)/g)) e.npcIds.push(+n[1]);
        });
      }
    }
    return result;
  }
  // Freitext-Liste: nur übernehmen, wenn ausdrücklich vom Zähmen die Rede ist.
  if (/tam(e|ed|ing)\b/i.test(body)) {
    const ids = [...body.matchAll(/npc=(\d+)/g)].map((m) => +m[1]);
    if (ids.length >= 2) result[pageSpellId] = { rank: null, tp: null, npcIds: [...new Set(ids)] };
  }
  return result;
}

/** Tierausbilder aus dem Kommentar zu „Große Ausdauer“ (Links mit npc=ID/slug und „in <Stadt>“). */
export function parseTrainerComment(comment) {
  const body = String(comment.body || '');
  if (!/Pet Trainer/i.test(body)) return [];
  return [...body.matchAll(/npc=(\d+)[^\]]*\]([^[]+)\[\/url\]\s*in\s+([A-Za-z' ]+)/g)]
    .map((m) => ({ id: +m[1], nameEn: m[2].trim(), cityEn: m[3].trim() }));
}
