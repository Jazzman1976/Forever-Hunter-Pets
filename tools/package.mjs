// Baut das Addon-Paket als ZIP, wie es auf CurseForge und an Tester geht (Meilenstein M4).
// Aufruf: node tools/package.mjs [Zielordner]   (Standard: .ignore/dist, nicht im Repo)
//
// Inhalt: alle Dateien, die git verfolgt, ohne das, was .pkgmeta unter „ignore“ nennt, und ohne Punkt-Dateien
// (.pkgmeta, .gitignore …). Im ZIP liegt alles im Ordner „package-as“ (Forever-Hunter-Pets/), die
// Version kommt aus dem TOC. Das ZIP schreibt dieses Skript selbst (Deflate aus zlib): Compress-Archive der
// Windows PowerShell legt Pfade mit Backslashes an, die manche Werkzeuge falsch entpacken.
import fs from 'node:fs';
import path from 'node:path';
import zlib from 'node:zlib';
import { execFileSync } from 'node:child_process';
import { fileURLToPath } from 'node:url';

const ROOT = path.resolve(path.dirname(fileURLToPath(import.meta.url)), '..');
const OUT_DIR = path.resolve(process.argv[2] || path.join(ROOT, '.ignore', 'dist'));

// .pkgmeta: „package-as“ und die Liste unter „ignore“ (einfaches YAML, wie wir es schreiben)
const meta = fs.readFileSync(path.join(ROOT, '.pkgmeta'), 'utf8').split(/\r?\n/);
const folder = (meta.find((l) => l.startsWith('package-as:')) || '').split(':')[1]?.trim();
if (!folder) throw new Error('.pkgmeta: package-as fehlt');
const ignore = [];
let inIgnore = false;
for (const l of meta) {
  if (/^ignore:/.test(l)) { inIgnore = true; continue; }
  if (inIgnore && /^\s+-\s+/.test(l)) ignore.push(l.replace(/^\s+-\s+/, '').trim());
  else if (inIgnore && /^\S/.test(l)) inIgnore = false;
}

const toc = fs.readFileSync(path.join(ROOT, `${folder}.toc`), 'utf8');
const version = (toc.match(/^## Version:\s*(\S+)/m) || [])[1];
if (!version) throw new Error('TOC: ## Version fehlt');

const tracked = execFileSync('git', ['ls-files'], { cwd: ROOT, encoding: 'utf8' }).split('\n').filter(Boolean);
const skip = (f) => f.split('/').some((p) => p.startsWith('.'))
  || ignore.some((i) => f === i || f.startsWith(i.replace(/\/$/, '') + '/'));
const files = tracked.filter((f) => !skip(f)).sort();

// ---- ZIP schreiben ----
const CRC = new Uint32Array(256).map((_, n) => {
  let c = n;
  for (let k = 0; k < 8; k++) c = c & 1 ? 0xedb88320 ^ (c >>> 1) : c >>> 1;
  return c >>> 0;
});
const crc32 = (buf) => {
  let c = 0xffffffff;
  for (const b of buf) c = CRC[(c ^ b) & 0xff] ^ (c >>> 8);
  return (c ^ 0xffffffff) >>> 0;
};
const dosTime = (d) => ((d.getHours() << 11) | (d.getMinutes() << 5) | (d.getSeconds() >> 1)) & 0xffff;
const dosDate = (d) => (((d.getFullYear() - 1980) << 9) | ((d.getMonth() + 1) << 5) | d.getDate()) & 0xffff;

const parts = [];
const central = [];
let offset = 0;
const now = new Date();
for (const f of files) {
  const data = fs.readFileSync(path.join(ROOT, f));
  const packed = zlib.deflateRawSync(data, { level: 9 });
  const name = Buffer.from(`${folder}/${f}`, 'utf8');
  const crc = crc32(data);
  const local = Buffer.alloc(30);
  local.writeUInt32LE(0x04034b50, 0); local.writeUInt16LE(20, 4); local.writeUInt16LE(0x0800, 6);   // UTF-8-Namen
  local.writeUInt16LE(8, 8); local.writeUInt16LE(dosTime(now), 10); local.writeUInt16LE(dosDate(now), 12);
  local.writeUInt32LE(crc, 14); local.writeUInt32LE(packed.length, 18); local.writeUInt32LE(data.length, 22);
  local.writeUInt16LE(name.length, 26); local.writeUInt16LE(0, 28);
  parts.push(local, name, packed);
  const c = Buffer.alloc(46);
  c.writeUInt32LE(0x02014b50, 0); c.writeUInt16LE(20, 4); c.writeUInt16LE(20, 6); c.writeUInt16LE(0x0800, 8);
  c.writeUInt16LE(8, 10); c.writeUInt16LE(dosTime(now), 12); c.writeUInt16LE(dosDate(now), 14);
  c.writeUInt32LE(crc, 16); c.writeUInt32LE(packed.length, 20); c.writeUInt32LE(data.length, 24);
  c.writeUInt16LE(name.length, 28); c.writeUInt32LE(offset, 42);
  central.push(c, name);
  offset += local.length + name.length + packed.length;
}
const centralSize = central.reduce((s, b) => s + b.length, 0);
const end = Buffer.alloc(22);
end.writeUInt32LE(0x06054b50, 0); end.writeUInt16LE(files.length, 8); end.writeUInt16LE(files.length, 10);
end.writeUInt32LE(centralSize, 12); end.writeUInt32LE(offset, 16);

fs.mkdirSync(OUT_DIR, { recursive: true });
const out = path.join(OUT_DIR, `${folder}-${version}.zip`);
fs.writeFileSync(out, Buffer.concat([...parts, ...central, end]));
console.log(`${out}: ${files.length} Dateien, ${(fs.statSync(out).size / 1024).toFixed(0)} KB`);
for (const f of files) console.log('  ' + f);
