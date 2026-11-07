// 말뭉치 -> data.json(PARTS, DISHES, TEMPLATES, SOURCES, GOOD 감사) + docs/recipe-audit.md
//   node tools/recipes/build.mjs
import fs from 'node:fs';
import path from 'node:path';
import crypto from 'node:crypto';
import { fileURLToPath } from 'node:url';
import { loadCorpus, idsIn, ALIAS, IDS } from './lib.mjs';
import { PARTS, DISHES, TEMPLATES, REVIEW_KEEP, PAIR_REJECT } from './parts.mjs';

const here = path.dirname(fileURLToPath(import.meta.url));
const root = path.join(here, '..', '..');
const rawDir = path.join(here, 'raw');
const dataPath = path.join(root, 'game', 'data', 'data.json');
const manifest = JSON.parse(fs.readFileSync(path.join(here, 'manifest.json'), 'utf8'));
for (const m of manifest) {
  const h = crypto.createHash('sha256').update(fs.readFileSync(path.join(rawDir, m.file))).digest('hex');
  if (h !== m.sha256) throw new Error(`원본 해시 불일치: ${m.file}`);
}

const D = JSON.parse(fs.readFileSync(dataPath, 'utf8'));
const docs = loadCorpus(rawDir);
const sets = docs.map(idsIn);
const n = docs.length;
const seaIds = new Set(Object.keys(D.SEA));

// ---------- 동시 출현과 PMI ----------
const count = {}, co = {};
const pk = (a, b) => (a < b ? `${a}+${b}` : `${b}+${a}`);
for (const s of sets) {
  const a = [...s];
  for (const x of a) count[x] = (count[x] || 0) + 1;
  for (let i = 0; i < a.length; i++) for (let j = i + 1; j < a.length; j++) { const k = pk(a[i], a[j]); co[k] = (co[k] || 0) + 1; }
}
const expected = (a, b) => ((count[a] || 0) * (count[b] || 0)) / n;
const pmi = (k) => { const [a, b] = k.split('+'); return co[k] ? Math.log2(co[k] / expected(a, b)) : -Infinity; };

// 표본이 적으면 판단을 보류한다. 기대 출현이 3 미만이면 0회여도 반박이 아니다.
function verdict(k) {
  const [a, b] = k.split('+');
  const c = co[k] || 0;
  const e = expected(a, b);
  if (c >= 3 && pmi(k) > 0) return 'supported';
  if (e >= 3 && (c === 0 || pmi(k) < -0.5)) return 'refuted';
  return 'noevidence';
}

// 같은 재료의 다른 형태나 원문 표기 겹침은 궁합 후보에서 뺀다.
const NOT_PAIR = new Set(['lemon+lemonj', 'breast+chicken', 'pumpkin+zucchini', 'ham+sausage', 'beef+ribs', 'pork+ribs', 'beef+mince', 'mince+pork', 'chicken+rice'].map((k) => pk(...k.split('+'))));
const audit = { supported: [], refuted: [], noevidence: [] };
// 기준 목록은 손으로 쓴 원래 340쌍이다. 빌드를 반복해도 결과가 같도록 base_good.json에서 읽는다.
const baseGood = JSON.parse(fs.readFileSync(path.join(here, 'base_good.json'), 'utf8'));
for (const k of baseGood) audit[verdict(k)].push(k);
// 반박 후보는 자동으로 지우지 않는다. 한식 위주 말뭉치라 서양식 조합이 적게 잡히므로 사람이 검수한다 (REVIEW_KEEP).
const dropped = audit.refuted.filter((k) => !REVIEW_KEEP.has(k));
const keepGood = new Set(baseGood.filter((k) => !dropped.includes(k)));
const added = Object.keys(co).filter((k) => {
  const [a, b] = k.split('+');
  if (keepGood.has(k) || D.BADX.includes(k) || NOT_PAIR.has(k)) return false;
  if (seaIds.has(a) && seaIds.has(b)) return false;
  return co[k] >= 8 && pmi(k) >= 1 && !PAIR_REJECT.has(k);
}).sort((x, y) => pmi(y) - pmi(x));
const newGood = [...keepGood, ...added];
const badChallenged = D.BADX.filter((k) => (co[k] || 0) >= 3 && pmi(k) > 0);

// ---------- 근거 문서에서 뽑는 값 ----------
const CUTW = [['J', /채\s*(?:썰|친|쳐)|채를/], ['M', /다지|다진|곱게\s*썰/], ['B', /한입|먹기\s*좋[은게]|토막|큼직|적당한\s*크기/], ['C', /깍둑/], ['S', /얇게|어슷|슬라이스|저며|편\s*썰|납작/], ['H', /반으로|이등분/]];
const docsByKw = (kw) => { const re = new RegExp(kw); return docs.map((d, i) => [d, i]).filter(([d]) => re.test(d.title)); };
const needAlts = (nd) => nd.flatMap((x) => x.split('|'));

function cutOf(evd, id) {
  const tally = {};
  for (const [d] of evd) {
    for (const sen of d.steps.split(/[.!?]\s|\d\s*\.\s/)) {
      if (!ALIAS[id].test(sen)) continue;
      for (const [c, re] of CUTW) if (re.test(sen)) tally[c] = (tally[c] || 0) + 1;
    }
  }
  const best = Object.entries(tally).sort((a, b) => b[1] - a[1])[0];
  if (!best || best[1] < 2 || !String(D.ING[id]?.cuts || '').includes(best[0])) return null;
  return best[0];
}

const parts = [];
const unsupportedParts = [];
for (const p of PARTS) {
  const titled = docsByKw(p.kw);
  // 제목 근거 가운데 필수 재료를 실제로 쓰는 문서만 인정한다.
  const evd = titled.filter(([, i]) => p.need.every((nd) => nd.split('|').some((x) => sets[i].has(x))));
  const opt = {}, sea = {};
  for (const [, i] of evd) {
    for (const x of sets[i]) {
      if (seaIds.has(x)) sea[x] = (sea[x] || 0) + 1;
      else if (!needAlts(p.need).includes(x)) opt[x] = (opt[x] || 0) + 1;
    }
  }
  const min = Math.max(1, Math.ceil(evd.length * 0.2));
  const entry = {
    id: p.id, n: p.n, need: p.need, m: p.m, role: p.role,
    opt: Object.entries(opt).filter(([, v]) => v >= min).sort((a, b) => b[1] - a[1]).map(([k]) => k).slice(0, 8),
    ev: evd.length,
    src: evd.slice(0, 4).map(([d]) => d.id),
  };
  if (p.sea) entry.sea = p.sea;
  if (p.stem) entry.stem = p.stem;
  if (p.gb) entry.gb = p.gb;
  const cut = {};
  for (const id of needAlts(p.need)) { const c = cutOf(evd, id); if (c) cut[id] = c; }
  if (Object.keys(cut).length) entry.cut = cut;
  parts.push(entry);
  if (evd.length === 0) unsupportedParts.push(p.n);
}

const dishes = DISHES.map((x) => {
  const ev = docsByKw(x.kw);
  return { id: x.id, n: x.n, parts: x.parts, ev: ev.length, src: ev.slice(0, 3).map(([d]) => d.id) };
});
const templates = TEMPLATES.map((t) => {
  const ev = docsByKw(t.kw);
  const out = { id: t.id, n: t.n, req: t.req, ev: ev.length };
  if (t.over) out.over = true;
  if (t.gb) out.gb = true;
  return out;
});

// ---------- 시간 분포 ----------
const METHW = { stir: /볶/, boil: /끓|삶|조려|조린|익혀/, grill: /구워|구운|굽/, fry: /튀기|튀겨/, steam: /찌|쪄|찜/, oven: /오븐/ };
const times = {};
for (const d of docs) {
  for (const sen of d.steps.split(/[.!?]\s|\d\s*\.\s/)) {
    const tm = sen.match(/(\d+)(?:\s*~\s*(\d+))?\s*분/);
    if (!tm) continue;
    const mins = tm[2] ? (+tm[1] + +tm[2]) / 2 : +tm[1];
    if (mins <= 0 || mins > 120) continue;
    const m = Object.keys(METHW).find((k) => METHW[k].test(sen));
    if (!m) continue;
    for (const id of IDS) if (D.ING[id] && ALIAS[id].test(sen)) (times[`${id}/${m}`] = times[`${id}/${m}`] || []).push(mins);
  }
}
const q = (a, f) => { const s = [...a].sort((x, y) => x - y); return s[Math.floor((s.length - 1) * f)]; };
const timeRows = [];
for (const [k, a] of Object.entries(times)) {
  const [id, m] = k.split('/');
  const w = D.ING[id].m[m];
  timeRows.push({ k, name: `${D.ING[id].n} ${D.METH[m].n}`, n: a.length, q1: q(a, 0.25), med: q(a, 0.5), q3: q(a, 0.75), lo: w ? w[1] : null, hi: w ? w[2] : null });
}
const timeChecked = timeRows.filter((r) => r.n >= 5 && r.lo !== null);
const timeInside = timeChecked.filter((r) => r.med >= r.lo * 0.5 && r.med <= r.hi * 2);
const timeOutside = timeChecked.filter((r) => !timeInside.includes(r));

// ---------- 게임에 없는 재료 빈도 (제목과 재료 칸) ----------
const GAP = ['무', '당면', '미역', '부추', '미나리', '다시마', '멸치', '콩', '연근', '우엉', '도라지', '고사리', '쑥갓', '갈치', '명태', '조기', '삼치', '꽁치', '낙지', '전복', '묵', '김', '콩나물', '생강', '들깨', '찹쌀', '쌀가루', '밀가루', '유부', '베이컨', '블루베리', '호두', '잣', '대추'];
const gap = GAP.filter((w) => w !== '콩나물').map((w) => {
  const re = new RegExp(`(?<![가-힣])${w}(?![가-힣])|(?<![가-힣])${w}[은는을를과와,]`);
  return [w, docs.filter((d) => re.test(d.ings || d.title)).length];
}).sort((a, b) => b[1] - a[1]);

// 판정은 맛으로만 한다. 안전 표시는 쓰지 않는다.
for (const id of Object.keys(D.ING)) delete D.ING[id].danger;
D.P.bell = '<path d="M18 8a6 6 0 0 0-12 0c0 7-3 9-3 9h18s-3-2-3-9"/><path d="M13.7 21a2 2 0 0 1-3.4 0"/>';

// ---------- 저장 ----------
D.GOOD = newGood.sort();
D.PARTS = parts;
D.DISHES = dishes;
D.TEMPLATES = templates;
D.SOURCES = manifest.map((m) => ({ id: m.id, n: m.name, license: m.license, url: m.url, sha256: m.sha256 }));
fs.writeFileSync(dataPath, JSON.stringify(D));

// ---------- 감사 보고서 ----------
const nameOf = (id) => D.ING[id]?.n || D.SEA[id]?.n || id;
const pairName = (k) => k.split('+').map(nameOf).join(' + ');
const structured = docs.filter((d) => d.ings).length;
const lines = [
  '# 레시피 데이터 감사 보고서', '',
  '`node tools/recipes/build.mjs` 가 만든 파일입니다. 손으로 고치지 마세요.', '',
  '## 자료', '',
  '| 자료 | 이용 조건 | sha256 |', '|---|---|---|',
  ...manifest.map((m) => `| [${m.name}](${m.url}) | ${m.license} | \`${m.sha256.slice(0, 12)}\` |`), '',
  `말뭉치 ${n}건 (재료 칸을 찾은 문서 ${structured}건). 정밀레시피 30건은 정답지라 규칙 제작에서 뺐습니다.`, '',
  '## 궁합 감사', '',
  `기존 ${audit.supported.length + audit.refuted.length + audit.noevidence.length}쌍: 근거 있음 ${audit.supported.length}, 근거 없음(표본 부족) ${audit.noevidence.length}, 반박됨 ${audit.refuted.length}. 반박 후보 중 ${dropped.length}쌍을 삭제하고 말뭉치에서 강한 쌍 ${added.length}개를 더해 ${newGood.length}쌍이 됐습니다.`, '',
  '판정 기준: 근거 있음은 동시 출현 3회 이상에 PMI 0 초과. 반박됨은 기대 출현 3회 이상인데 0회이거나 PMI -0.5 미만. 나머지는 근거 없음.', '',
  '### 반박 후보', '', audit.refuted.map((k) => pairName(k) + (dropped.includes(k) ? ' (삭제)' : ' (검수 후 유지)')).join(', ') || '없음', '',
  '### 추가한 쌍', '', added.map((k) => `${pairName(k)}(${co[k]}회)`).join(', ') || '없음', '',
  '### 나쁜 궁합으로 등록됐지만 말뭉치에서는 같이 쓰인 쌍', '', badChallenged.map((k) => `${pairName(k)}(${co[k]}회)`).join(', ') || '없음', '',
  '## 구성 요소', '',
  `PARTS ${parts.length}개, 이름 있는 조립 ${dishes.length}개, 조립 규칙 ${templates.length}개.`, '',
  `말뭉치 근거 없는 구성 요소 ${unsupportedParts.length}개: ${unsupportedParts.join(', ') || '없음'}`, '',
  '| 조립 규칙 | 근거 문서 수 |', '|---|---|',
  ...templates.map((t) => `| ${t.n} | ${t.ev} |`), '',
  '## 조리 시간 창', '',
  `표본 5개 이상인 재료와 조리법 ${timeChecked.length}건 중 중앙값이 게임 적정 창의 절반에서 두 배 사이인 경우는 ${timeInside.length}건입니다. 조리 문장의 시간은 재료 전체를 합친 시간일 때가 많아 창을 자동으로 바꾸지 않고 목록만 남깁니다.`, '',
  '| 재료와 조리법 | 표본 | 사분위 (분) | 중앙값 | 게임 창 |', '|---|---|---|---|---|',
  ...timeOutside.map((r) => `| ${r.name} | ${r.n} | ${r.q1}~${r.q3} | ${r.med} | ${r.lo}~${r.hi} |`), '',
  '## 게임에 없는 재료 (빈도순)', '',
  gap.filter((g) => g[1] > 0).map((g) => `${g[0]} ${g[1]}`).join(', '), '',
];
fs.writeFileSync(path.join(root, 'docs', 'recipe-audit.md'), lines.join('\n'));

console.log({ docs: n, structured, good: { ...Object.fromEntries(Object.entries(audit).map(([k, v]) => [k, v.length])), added: added.length, now: newGood.length }, parts: parts.length, unsupported: unsupportedParts, time: [timeChecked.length, timeInside.length] });
console.log('refuted', audit.refuted.map(pairName).join(', '));
console.log('added', added.slice(0, 60).map((k) => `${pairName(k)}:${co[k]}`).join(', '));
console.log('bad?', badChallenged.map(pairName).join(', '));
console.log('low ev', parts.filter((p) => p.ev < 2).map((p) => `${p.n}:${p.ev}`).join(' '));
console.log('gap', gap.slice(0, 15).join(' '));
