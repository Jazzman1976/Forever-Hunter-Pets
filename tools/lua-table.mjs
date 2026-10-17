// Liest eine SavedVariables-Datei des Clients: Zuweisungen „Name = Wert“ mit Tabellen, Texten, Zahlen,
// true/false/nil. Mehr Lua braucht es dafür nicht. Gibt { Name: Wert } zurück; Tabellen werden zu Objekten
// mit Text-Schlüsseln („[5] = …“ wird zu "5"), Listenelemente ohne Schlüssel bekommen 1, 2, 3 …
export function parseSavedVariables(text) {
  let i = 0;
  const fail = (msg) => { throw new Error(`${msg} bei Zeichen ${i}: ${JSON.stringify(text.slice(i, i + 30))}`); };
  const skip = () => {
    for (;;) {
      while (i < text.length && /\s/.test(text[i])) i++;
      if (text.startsWith('--', i)) {
        const nl = text.indexOf('\n', i);
        i = nl < 0 ? text.length : nl + 1;
      } else return;
    }
  };
  const string = () => {
    const quote = text[i++];
    let out = '';
    while (i < text.length && text[i] !== quote) {
      if (text[i] === '\\') {
        const c = text[++i];
        if (/\d/.test(c)) {
          const m = text.slice(i).match(/^\d{1,3}/)[0];
          out += String.fromCharCode(+m);
          i += m.length;
          continue;
        }
        out += { n: '\n', t: '\t', r: '\r', '\n': '\n' }[c] ?? c;
        i++;
      } else out += text[i++];
    }
    if (text[i] !== quote) fail('Text ohne Ende');
    i++;
    return out;
  };
  const value = () => {
    skip();
    const c = text[i];
    if (c === '{') return table();
    if (c === '"' || c === "'") return string();
    const m = text.slice(i).match(/^(-?(?:0x[0-9a-f]+|\d+(?:\.\d*)?(?:e[+-]?\d+)?|\.\d+|inf|nan)|true|false|nil)/i);
    if (!m) fail('Wert erwartet');
    i += m[0].length;
    if (m[0] === 'true') return true;
    if (m[0] === 'false') return false;
    if (m[0] === 'nil') return null;
    return Number(m[0]);
  };
  const table = () => {
    i++; // {
    const out = {};
    let n = 0;
    for (;;) {
      skip();
      if (text[i] === '}') { i++; return out; }
      let key;
      if (text[i] === '[') {
        i++;
        key = String(value());
        skip();
        if (text[i++] !== ']') fail('] erwartet');
        skip();
        if (text[i++] !== '=') fail('= erwartet');
      } else {
        const m = text.slice(i).match(/^([A-Za-z_]\w*)\s*=(?!=)/);
        if (m) { key = m[1]; i += m[0].length; } else key = String(++n);
      }
      out[key] = value();
      skip();
      if (text[i] === ',' || text[i] === ';') i++;
    }
  };
  const vars = {};
  for (;;) {
    skip();
    if (i >= text.length) return vars;
    const m = text.slice(i).match(/^([A-Za-z_]\w*)\s*=/);
    if (!m) fail('Zuweisung erwartet');
    i += m[0].length;
    vars[m[1]] = value();
  }
}
