// Prüfung ohne Spiel: Syntax aller Lua-Dateien (luaparse), dann jedes Szenario aus tools/test/szenarien/ in einem
// frischen Lua (fengari) mit nachgebildeter API (mock.lua) und den Dateien aus der TOC (Core, Locales, Data; UI nur
// Syntax). fengari findet dabei auch ungültige Escapes wie "Interface\Icons", die luaparse übersieht.
// Einmal vorher: im Ordner tools/test „npm install“
//   node tools/test/run.mjs                 alles
//   node tools/test/run.mjs t114 t105      nur Szenarien, deren Dateiname so beginnt (Syntax immer)
import fs from 'fs';
import path from 'path';
import { createRequire } from 'module';
import { fileURLToPath } from 'url';

const require = createRequire(import.meta.url);
const HERE = path.dirname(fileURLToPath(import.meta.url));
const ROOT = path.resolve(HERE, '..', '..');
let luaparse, fengari;
try {
  luaparse = require('luaparse');
  fengari = require('fengari');
} catch {
  console.error('fengari oder luaparse fehlt: einmal im Ordner tools/test „npm install“');
  process.exit(2);
}
const { lua, lauxlib, lualib, to_luastring, to_jsstring } = fengari;

// ---- Syntax ----
const luaFiles = [];
for (const dir of ['Core', 'UI', 'Locales', 'Data']) {
  for (const f of fs.readdirSync(path.join(ROOT, dir))) if (f.endsWith('.lua')) luaFiles.push(path.join(dir, f));
}
let syntaxBad = 0;
for (const f of luaFiles) {
  try {
    luaparse.parse(fs.readFileSync(path.join(ROOT, f), 'utf8'), { luaVersion: '5.1' });
  } catch (e) {
    syntaxBad++;
    console.log(`Syntaxfehler in ${f}: ${e.message}`);
  }
}
console.log(`Syntax: ${luaFiles.length} Dateien, ${syntaxBad ? syntaxBad + ' mit Fehlern' : 'ok'}`);

// ---- Szenarien ----
const toc = fs.readFileSync(path.join(ROOT, 'Forever-Hunter-Pets.toc'), 'utf8').split(/\r?\n/)
  .filter((l) => /^(Core|Locales|Data)\\.*\.lua$/.test(l)).map((l) => l.split('\\').join('/'));

function scenario(file) {
  const L = lauxlib.luaL_newstate();
  lualib.luaL_openlibs(L);
  const run = (code, name, addon) => {
    if (lauxlib.luaL_loadbuffer(L, to_luastring(code), null, to_luastring('@' + name)) !== 0) {
      throw new Error(to_jsstring(lua.lua_tostring(L, -1)));
    }
    if (addon) {
      lua.lua_pushstring(L, to_luastring('Forever-Hunter-Pets'));
      lua.lua_getglobal(L, to_luastring('NS'));
    }
    if (lua.lua_pcall(L, addon ? 2 : 0, 0, 0) !== 0) throw new Error(to_jsstring(lua.lua_tostring(L, -1)));
  };
  const global = (name) => {
    lua.lua_getglobal(L, to_luastring(name));
    const v = lua.lua_tonumber(L, -1);
    lua.lua_pop(L, 1);
    return v;
  };
  run(fs.readFileSync(path.join(HERE, 'mock.lua'), 'utf8'), 'mock.lua');
  for (const f of toc) run(fs.readFileSync(path.join(ROOT, f), 'utf8'), f, true);
  run('NS.ReportError = function(where, err) ERRORS[#ERRORS + 1] = where .. ": " .. tostring(err) end', 'run.mjs');
  run(fs.readFileSync(file, 'utf8'), path.basename(file));
  run('if #ERRORS > 0 then error("Fehler im Addon: " .. table.concat(ERRORS, " | ")) end', 'run.mjs');
  return global('CHECKS');
}

const filter = process.argv.slice(2);
const dir = path.join(HERE, 'szenarien');
const files = fs.readdirSync(dir).filter((f) => f.endsWith('.lua'))
  .filter((f) => !filter.length || filter.some((p) => f.startsWith(p))).sort();
let failed = 0, checks = 0;
for (const f of files) {
  console.log(f);
  try {
    checks += scenario(path.join(dir, f));
  } catch (e) {
    failed++;
    console.log(`  ${e.message}`);
  }
}
console.log(`${files.length} Szenarien, ${checks} Prüfungen, ${failed ? failed + ' fehlgeschlagen' : 'alles ok'}`);
process.exit(syntaxBad || failed ? 1 : 0);
