// 정답지: 한식진흥원 정밀레시피 30건을 게임 재료로 옮겨 테스트 케이스를 만든다.
// 규칙(parts.mjs)은 이 파일을 보지 않고 만든다. 결과는 Godot 테스트가 채점한다.
//   node tools/recipes/holdout.mjs
import fs from 'node:fs';
import os from 'node:os';
import path from 'node:path';
import { fileURLToPath } from 'node:url';
import { loadHoldout, ALIAS, IDS } from './lib.mjs';

const here = path.dirname(fileURLToPath(import.meta.url));
const root = path.join(here, '..', '..');
const D = JSON.parse(fs.readFileSync(path.join(root, 'game', 'data', 'data.json'), 'utf8'));
const recipes = loadHoldout(path.join(here, 'raw', 'hansik30.zip'), path.join(os.tmpdir(), 'fc_hansik30'));
const SEA = new Set(Object.keys(D.SEA));
const UNITS = /^[\d.\-/]+$|^(mm|cm|in|g|oz|lb|℃|℉|과정|내용|단위변환|길이|용량|온도)$/;
// 게임에 핵심 재료가 없어 재현할 수 없는 요리
const MISSING = { 오곡밥: '잡곡', 잡곡밥: '잡곡', 보리밥: '보리', 곤드레나물밥: '곤드레', 누룽지: '누룽지 조리', 순댓국밥: '순대', 우렁된장비빔밥: '우렁', 우거지사골국밥: '우거지', 김밥: '김', 잡채덮밥: '당면', 산채비빔밥: '산채', 새싹비빔밥: '새싹', 영양돌솥밥: '잡곡', 흰밥: '쌀 짓기', 콩나물밥: '쌀 짓기', 주먹밥: '김' };

const METH = [['fry', /튀기|튀겨|튀긴/], ['stir', /볶/], ['steam', /쪄|찐다|찌는|찜기/], ['grill', /구워|굽는|부쳐|부친|프라이|지단/], ['boil', /끓|삶|데치|데쳐|조려|조린/]];
function methodOf(text) {
  let best = null, at = -1;
  for (const [m, re] of METH) {
    const all = [...text.matchAll(new RegExp(re.source, 'g'))];
    if (all.length && all[all.length - 1].index > at) { at = all[all.length - 1].index; best = m; }
  }
  return best || 'raw';
}
const idsOf = (s) => IDS.filter((k) => ALIAS[k].test(s));

const cases = [];
const timeRows = [];
for (const r of recipes) {
  const start = r.cells.indexOf('조리하기');
  const end = r.cells.findIndex((c, i) => i > start && c === '담기');
  const head = r.cells.slice(0, r.cells.indexOf('식재료') > 0 ? r.cells.indexOf('식재료') : start).join(' ');
  const seas = idsOf(head).filter((k) => SEA.has(k));
  const body = r.cells.slice(start + 1, end > 0 ? end : undefined).filter((c) => !UNITS.test(c));
  const sections = [];
  let cur = null;
  for (const c of body) {
    const isStep = /^\d+\s*\./.test(c) || /[.)]$/.test(c) || c.length > 14;
    if (!isStep && !/^[℃(]/.test(c)) { cur = { title: c, text: '' }; sections.push(cur); } else if (cur) cur.text += ` ${c}`;
  }
  const groups = [];
  for (const s of sections) {
    const ids = idsOf(`${s.title} ${s.text}`).filter((k) => !SEA.has(k));
    if (!ids.length) continue;
    groups.push({ title: s.title, ids, m: methodOf(s.text), seas });
    for (const sen of s.text.split(/(?=\d+\s*\.\s)/)) {
      const tm = sen.match(/약?\s*(\d+)\s*분(?:\s*(\d+)\s*초)?(?:간|\s*더)/);
      if (!tm) continue;
      const min = +tm[1] + (+tm[2] || 0) / 60;
      const m = methodOf(sen);
      if (m === 'raw') continue;
      for (const id of idsOf(sen)) {
        if (!D.ING[id] || !D.ING[id].m[m]) continue;
        const w = D.ING[id].m[m];
        timeRows.push({ recipe: r.name, id, m, min, lo: w[1], hi: w[2] });
      }
    }
  }
  const tail = r.cells.slice(end > 0 ? end : start).join(' ');
  if (/밥/.test(`${r.name} ${tail}`) && !groups.some((g) => g.ids.includes('rice') && g.m !== 'raw')) groups.push({ title: '밥', ids: ['rice'], m: 'micro', seas: [] });
  cases.push({ name: r.name, missing: MISSING[r.name] || '', groups });
}
fs.writeFileSync(path.join(root, 'game', 'data', 'holdout_cases.json'), JSON.stringify(cases));

const inside = timeRows.filter((t) => t.min >= t.lo && t.min <= t.hi);
const near = timeRows.filter((t) => t.min >= t.lo * 0.5 && t.min <= t.hi * 2);
const lines = [
  `정밀레시피 시간 ${timeRows.length}건: 적정 창 안 ${inside.length} (${Math.round(inside.length / Math.max(1, timeRows.length) * 100)}%), 절반에서 두 배 사이 ${near.length} (${Math.round(near.length / Math.max(1, timeRows.length) * 100)}%)`,
  ...timeRows.filter((t) => !near.includes(t)).map((t) => `  ${t.recipe} ${D.ING[t.id].n} ${D.METH[t.m].n} ${t.min.toFixed(1)}분, 게임 창 ${t.lo}~${t.hi}`),
];
fs.writeFileSync(path.join(root, 'docs', 'holdout-time.txt'), lines.join('\n') + '\n');
console.log(cases.length, 'cases, reproducible', cases.filter((c) => !c.missing).length);
console.log(lines.join('\n'));
for (const c of cases) if (!c.missing) console.log(c.name, JSON.stringify(c.groups.map((g) => [g.title, g.m, g.ids.join(',')])));
