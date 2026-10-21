const fs = require('fs');
const path = require('path');
const base = String.raw`C:\Users\Jirka\.cursor\projects\d-Games-projekt-loop-v2\agent-transcripts`;
const outdir = String.raw`D:\Games\projekt-loop-v2\_transcript_extract`;
const ids = [
  '421a7715-3e78-454e-8406-a2ad3ee02bae',
  '9a1f922b-587c-4ca6-a00a-7e3d7e151aaa',
  '176420bc-409b-498b-a384-8ace36b421a1',
  '45cbda02-c1c0-4528-8b3e-f47a017bba67',
  '77318613-7187-439f-a508-9ed7d4a81b8b',
  '156322a8-cc68-4d12-83a1-00e53f6fa7a6',
  'b0041ab1-80c9-408a-9b69-76aa13a855b7',
  'f9749d7b-6480-483f-b2f4-56bc88ffa21c',
];

function getText(msg) {
  const content = msg.content;
  if (typeof content === 'string') return content;
  if (!Array.isArray(content)) return '';
  return content
    .map((p) => {
      if (typeof p === 'string') return p;
      if (p && p.type === 'text') return p.text || '';
      return '';
    })
    .join('\n');
}

for (const id of ids) {
  const file = path.join(base, id, `${id}.jsonl`);
  const lines = fs.readFileSync(file, 'utf8').split(/\r?\n/);
  const qs = [];
  const assists = [];
  for (const line of lines) {
    if (!line.trim()) continue;
    let obj;
    try {
      obj = JSON.parse(line);
    } catch {
      continue;
    }
    const msg = obj.message || obj;
    const role = msg.role || obj.role;
    const text = getText(msg);
    if (role === 'user') {
      const m = text.match(/<user_query>\s*([\s\S]*?)\s*<\/user_query>/);
      let q = (m ? m[1] : text).trim();
      if (q.length < 25) continue;
      if (q.startsWith('Godot Engine') || q.slice(0, 200).includes('Vulkan ')) continue;
      if (q.slice(0, 80).includes('mcp_meta_tools')) continue;
      qs.push(q);
    } else if (role === 'assistant' && text.length > 200) {
      assists.push(text);
    }
  }
  let out = '';
  qs.forEach((q, i) => {
    out += `===== Q${i + 1} len=${q.length} =====\n`;
    out += q.length > 4500 ? q.slice(0, 4500) + '\n...[TRUNC]\n' : q;
    out += '\n\n';
  });
  out += '\n\n######## LAST ASSISTANT (up to 3) ########\n\n';
  for (const a of assists.slice(-3)) {
    const clean = a.replace(/<[^>]+>/g, ' ').replace(/\s+/g, ' ').trim();
    out += '----- ASSIST -----\n' + clean.slice(-4000) + '\n\n';
  }
  const outPath = path.join(outdir, `${id}-py.txt`);
  fs.writeFileSync(outPath, out, 'utf8');
  console.log(id, 'queries', qs.length, 'assists', assists.length, 'bytes', fs.statSync(outPath).size);
}
