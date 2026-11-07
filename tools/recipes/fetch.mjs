// 1차 자료를 내려받아 해시를 manifest.json에 고정한다.
// 원본은 raw/ 에 두고 저장소에는 넣지 않는다 (manifest로 같은 파일인지 확인).
//   node tools/recipes/fetch.mjs
// 식품안전나라, 농식품 공공데이터 인증키가 tools/recipes/keys.env 에 있으면 함께 받는다.
//   FOODSAFETY_KEY=...
//   MAFRA_KEY=...
import fs from 'node:fs';
import path from 'node:path';
import crypto from 'node:crypto';
import { fileURLToPath } from 'node:url';

const here = path.dirname(fileURLToPath(import.meta.url));
const rawDir = path.join(here, 'raw');
fs.mkdirSync(rawDir, { recursive: true });
const UA = { 'User-Agent': 'Mozilla/5.0 FridgeChef-recipe-pipeline' };

const FILES = [
  { id: 'gosu', pk: '15050910', detail: 'uddi:69d46184-9441-4d4d-9c3f-e4de66a49643_201909261053', hist: 7, ext: 'csv', name: '농림수산식품교육문화정보원 고수요리법', license: '이용허락범위 제한 없음' },
  { id: 'eat', pk: '15117929', detail: 'uddi:41d9e2d5-0936-483f-b60b-8e28463c46d7', hist: 2, ext: 'csv', name: '한국농수산식품유통공사 eaT 공공급식 요리별 요리방법', license: '이용허락범위 제한 없음' },
  { id: 'hansik30', pk: '15142529', detail: 'uddi:f2ac3432-267a-417d-a073-ac4df4181ae9', hist: 2, ext: 'zip', name: '한식진흥원 한식 정밀레시피(밥류)', license: '공공누리 제1유형(출처 표시)' },
];

async function dataGoKr(f) {
  const ref = { ...UA, Referer: `https://www.data.go.kr/data/${f.pk}/fileData.do`, 'X-Requested-With': 'XMLHttpRequest' };
  const q = `publicDataPk=${f.pk}&publicDataDetailPk=${encodeURIComponent(f.detail)}&fileDetailSn=1&publicDataHistSn=${f.hist}`;
  const r = await fetch(`https://www.data.go.kr/tcs/dss/selectFileDataDownload.do?${q}`, { headers: ref });
  const m = (await r.text()).match(/"atchFileId":"([^"]+)"/);
  if (!m) throw new Error(`${f.id}: 파일 정보를 찾지 못함`);
  const d = await fetch(`https://www.data.go.kr/cmm/cmm/fileDownload.do?atchFileId=${m[1]}&fileDetailSn=1&insertDataPrcus=N`, { headers: ref });
  if (!d.ok) throw new Error(`${f.id}: HTTP ${d.status}`);
  return Buffer.from(await d.arrayBuffer());
}

async function pages(url, each, total) {
  const rows = [];
  for (let i = 1; i <= total; i += each) {
    const r = await fetch(url(i, Math.min(i + each - 1, total)), { headers: UA });
    const j = await r.json();
    const key = Object.keys(j)[0];
    const got = j[key]?.row;
    if (!got) throw new Error(`응답 오류: ${JSON.stringify(j).slice(0, 200)}`);
    rows.push(...got);
  }
  return Buffer.from(JSON.stringify(rows));
}

function readKeys() {
  const p = path.join(here, 'keys.env');
  const out = {};
  if (!fs.existsSync(p)) return out;
  for (const line of fs.readFileSync(p, 'utf8').split(/\r?\n/)) {
    const m = line.match(/^\s*([A-Z_]+)\s*=\s*(\S+)/);
    if (m) out[m[1]] = m[2];
  }
  return out;
}

const manifest = [];
function save(f, buf) {
  const file = `${f.id}.${f.ext}`;
  fs.writeFileSync(path.join(rawDir, file), buf);
  const sha256 = crypto.createHash('sha256').update(buf).digest('hex');
  manifest.push({ id: f.id, name: f.name, license: f.license, url: f.url, file, bytes: buf.length, sha256 });
  console.log(file, buf.length, sha256.slice(0, 12));
}

for (const f of FILES) {
  f.url = `https://www.data.go.kr/data/${f.pk}/fileData.do`;
  save(f, await dataGoKr(f));
}

const keys = readKeys();
if (keys.FOODSAFETY_KEY) {
  const k = keys.FOODSAFETY_KEY;
  save({ id: 'mfds', ext: 'json', name: '식품의약품안전처 식품안전나라 조리식품 레시피 DB', license: '식품안전나라 Open API 이용 조건', url: 'https://www.foodsafetykorea.go.kr/api/openApiInfo.do' },
    await pages((a, b) => `http://openapi.foodsafetykorea.go.kr/api/${k}/COOKRCP01/json/${a}/${b}`, 1000, 1156));
}
if (keys.MAFRA_KEY) {
  const k = keys.MAFRA_KEY;
  const u = (g) => (a, b) => `http://211.237.50.150:7080/openapi/${k}/json/Grid_20150827000000000${g}_1/${a}/${b}`;
  const lic = '농식품 공공데이터 포털 이용 조건';
  const url = 'https://data.mafra.go.kr';
  save({ id: 'mafra_basic', ext: 'json', name: '농림축산식품부 레시피 기본정보', license: lic, url }, await pages(u(226), 1000, 537));
  save({ id: 'mafra_ing', ext: 'json', name: '농림축산식품부 레시피 재료정보', license: lic, url }, await pages(u(227), 1000, 6104));
  save({ id: 'mafra_step', ext: 'json', name: '농림축산식품부 레시피 과정정보', license: lic, url }, await pages(u(228), 1000, 3022));
}
fs.writeFileSync(path.join(here, 'manifest.json'), JSON.stringify(manifest, null, 2) + '\n');
console.log('manifest', manifest.length);
