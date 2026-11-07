// 원본 파일 파싱과 재료 정규화.
import fs from 'node:fs';
import path from 'node:path';
import { execFileSync } from 'node:child_process';

export function decode(buf) {
  const s = new TextDecoder('utf-8').decode(buf);
  if ((s.match(/�/g) || []).length > 20) return new TextDecoder('euc-kr').decode(buf);
  return s;
}

export function parseCsv(s) {
  const out = [];
  let row = [], f = '', q = false;
  for (let i = 0; i < s.length; i++) {
    const c = s[i];
    if (q) {
      if (c === '"') { if (s[i + 1] === '"') { f += '"'; i++; } else q = false; } else f += c;
    } else if (c === '"') q = true;
    else if (c === ',') { row.push(f); f = ''; }
    else if (c === '\n') { row.push(f.replace(/\r$/, '')); out.push(row); row = []; f = ''; }
    else f += c;
  }
  if (f || row.length) { row.push(f); out.push(row); }
  return out;
}

const stripHtml = (h) => h.replace(/<[^>]+>/g, ' ').replace(/&nbsp;|&amp;|&lt;|&gt;|&#\d+;/g, ' ').replace(/[ \t\r\n]+/g, ' ').trim();

// 고수요리법 일부는 "시간||설명||조리||재료||출처" 구조, 나머지는 줄글이다.
function shapeGosu(title, raw, i) {
  const x = stripHtml(raw);
  const doc = { id: `gosu${i}`, src: 'gosu', title: title.replace(/\s+/g, ' ').trim(), text: x, steps: x, ings: '', structured: false };
  const parts = x.split('||');
  if (parts.length >= 4) {
    doc.steps = parts[2] || x;
    doc.ings = parts[3] || '';
    doc.structured = true;
    const t = (parts[0] || '').match(/(\d+)\s*분/);
    if (t) doc.total = +t[1];
    return doc;
  }
  const m = x.match(/재\s*료[^가-힣A-Za-z0-9]{0,6}(.{10,400}?)(?:만드는|만들기|조리\s*(?:법|방법)|방법|[①❶]|\b1\s*[.)])/);
  if (m) doc.ings = m[1];
  return doc;
}

export function loadCorpus(rawDir) {
  const docs = [];
  const gosu = parseCsv(decode(fs.readFileSync(path.join(rawDir, 'gosu.csv')))).slice(1).filter((r) => r.length >= 3 && r[1].trim());
  gosu.forEach((r, i) => docs.push(shapeGosu(r[1], r[2], i)));
  const eat = parseCsv(decode(fs.readFileSync(path.join(rawDir, 'eat.csv')))).slice(1).filter((r) => r[0]);
  eat.forEach((r, i) => docs.push({ id: `eat${i}`, src: 'eat', title: r[0].trim(), text: r[1] || '', steps: r[1] || '', ings: '', structured: false }));
  const mfds = path.join(rawDir, 'mfds.json');
  if (fs.existsSync(mfds)) {
    for (const r of JSON.parse(fs.readFileSync(mfds, 'utf8'))) {
      const steps = Object.keys(r).filter((k) => /^MANUAL\d+$/.test(k)).sort().map((k) => r[k]).filter(Boolean).join(' ');
      docs.push({ id: `mfds${r.RCP_SEQ}`, src: 'mfds', title: r.RCP_NM, text: `${r.RCP_PARTS_DTLS} ${steps}`, steps, ings: r.RCP_PARTS_DTLS, structured: true });
    }
  }
  const mb = path.join(rawDir, 'mafra_basic.json');
  if (fs.existsSync(mb)) {
    const ing = JSON.parse(fs.readFileSync(path.join(rawDir, 'mafra_ing.json'), 'utf8'));
    const st = JSON.parse(fs.readFileSync(path.join(rawDir, 'mafra_step.json'), 'utf8'));
    for (const r of JSON.parse(fs.readFileSync(mb, 'utf8'))) {
      const ings = ing.filter((x) => x.RECIPE_ID === r.RECIPE_ID).map((x) => x.IRDNT_NM).join(', ');
      const steps = st.filter((x) => x.RECIPE_ID === r.RECIPE_ID).sort((a, b) => a.COOKING_NO - b.COOKING_NO).map((x) => x.COOKING_DC).join(' ');
      docs.push({ id: `mafra${r.RECIPE_ID}`, src: 'mafra_basic', title: r.RECIPE_NM_KO, text: `${ings} ${steps}`, steps, ings, structured: true });
    }
  }
  return docs;
}

// 정밀레시피: zip 안의 레시피별 HWPX (zip 안의 zip) -> section XML 텍스트
export function loadHoldout(zipPath, workDir) {
  const tar = process.env.SystemRoot ? path.join(process.env.SystemRoot, 'System32', 'tar.exe') : 'tar';
  fs.rmSync(workDir, { recursive: true, force: true });
  fs.mkdirSync(workDir, { recursive: true });
  execFileSync(tar, ['-xf', zipPath, '-C', workDir]);
  const out = [];
  for (const f of fs.readdirSync(workDir).filter((x) => x.endsWith('.hwpx'))) {
    const d = path.join(workDir, `x_${out.length}`);
    fs.mkdirSync(d);
    execFileSync(tar, ['-xf', path.join(workDir, f), '-C', d]);
    const secs = fs.readdirSync(path.join(d, 'Contents')).filter((n) => /^section/.test(n));
    const xml = secs.map((n) => fs.readFileSync(path.join(d, 'Contents', n), 'utf8')).join('');
    const cells = [...xml.matchAll(/<hp:t[^>]*>([^<]*)/g)].map((m) => m[1].trim()).filter(Boolean);
    out.push({ name: f.replace(/^\d+\.\s*/, '').replace('.hwpx', ''), cells });
  }
  return out;
}

// 재료 별칭. 앞뒤 금지 문자로 오매칭(파프리카의 파, 여러가지의 가지 등)을 막는다.
const R = (s) => new RegExp(s);
export const ALIAS = {
  pork: R('삼겹살|돼지고기|돼지갈비|돼지|목살|돈육|제육|돈가스|돈까스|보쌈|편육'),
  beef: R('소고기|쇠고기|한우|등심|안심|불고기감|양지머리|차돌박이|육우'),
  ribs: R('(?<!돼지)갈비(?!탕면)'),
  mince: R('다짐육|다진\\s*(?:고기|소고기|쇠고기|돼지고기)|간\\s*(?:고기|소고기|쇠고기)|함박'),
  chicken: R('닭(?!가슴살)|영계|치킨'),
  breast: R('닭가슴살'),
  sausage: R('소시지|소세지|비엔나'),
  ham: R('스팸|통조림\\s*햄|(?<![가-힣])햄(?!버거)'),
  shrimp: R('새우(?!젓)|대하'),
  salmon: R('연어'),
  mackerel: R('고등어'),
  squid: R('오징어|갑오징어'),
  octopus: R('문어|낙지|쭈꾸미|주꾸미'),
  clam: R('조개|바지락|모시조개|홍합|백합|대합|꼬막|재첩'),
  crab: R('꽃게|게살|게맛살'),
  oyster: R('(?<![가-힣])굴(?!소스)|생굴|굴밥|굴국'),
  tuna: R('참치'),
  egg: R('달걀|계란|메추리알'),
  cheese: R('치즈'),
  milk: R('우유|밀크'),
  yogurt: R('요거트|요구르트'),
  tofu: R('두부|순두부|연두부'),
  kimchi: R('김치|묵은지'),
  cabbage: R('배추|양배추|봄동'),
  lettuce: R('상추|양상추'),
  potato: R('감자|포테이토'),
  sweetpotato: R('고구마|스위트\\s*포테이토'),
  onion: R('양파'),
  garlic: R('마늘(?!종|쫑)'),
  greenonion: R('대파|쪽파|실파|(?<![가-힣])파(?![가-힣])|다진\\s*파'),
  mushroom: R('버섯'),
  chili: R('청양고추|풋고추|홍고추|청고추|꽈리고추|고추(?!장|가루)'),
  paprika: R('파프리카|피망'),
  cucumber: R('오이(?!지)'),
  tomato: R('토마토'),
  avocado: R('아보카도'),
  eggplant: R('(?<![여러몇두세한])(?<![가-힣]\\s)가지(?!고|런|만|씩|를\\s*넣|\\s*재료)'),
  carrot: R('당근|홍당무'),
  corn: R('옥수수'),
  broccoli: R('브로콜리'),
  zucchini: R('애호박|(?<!단)(?<!늙은)호박(?!즙)'),
  spinach: R('시금치'),
  sprouts: R('콩나물|숙주'),
  perilla: R('깻잎'),
  pumpkin: R('단호박|늙은호박'),
  banana: R('바나나'),
  strawberry: R('딸기'),
  apple: R('사과(?!식초|즙)|애플'),
  pear: R('(?<![가-힣])배(?:즙|\\s*\\d|\\s*\\d*\\/|꿀|\\s*1)|배꿀'),
  mandarin: R('(?<![가-힣])귤|감귤|밀감'),
  grape: R('포도(?!주|씨|당)'),
  watermelon: R('수박'),
  peach: R('복숭아'),
  pineapple: R('파인애플'),
  mango: R('망고'),
  kiwi: R('키위'),
  cherry: R('체리'),
  lemon: R('레몬(?!즙)'),
  rice: R('(?<![가-힣])밥(?!상|솥|맛)|볶음밥|덮밥|비빔밥|주먹밥|김밥|즉석밥|찬밥|쌀밥'),
  ramen: R('라면'),
  spaghetti: R('스파게티|스파게띠|파스타'),
  udon: R('우동'),
  tteok: R('떡(?!갈비)|가래떡'),
  bread: R('식빵'),
  baguette: R('바게트|바게뜨'),
  croissant: R('크루아상|크로와상'),
  dumpling: R('만두'),
  pancake: R('핫케이크|팬케이크|펜케이크'),
  chocolate: R('초콜릿|초콜렛|초코'),
  icecream: R('아이스크림'),
  peanut: R('땅콩'),
  chestnut: R('(?<![가-힣])밤(?![가-힣])|밤을|밤은|밤죽|밤크림|알밤'),
  fishcake: R('어묵|오뎅'),
  salt: R('소금'),
  pepper: R('후추|후춧'),
  sugar: R('설탕'),
  soy: R('간장(?!게장)'),
  gochujang: R('고추장'),
  doenjang: R('된장'),
  gochugaru: R('고춧가루|고추가루'),
  sesame: R('참기름'),
  vinegar: R('식초'),
  honey: R('(?<![가-힣])꿀|벌꿀'),
  butter: R('(?<!땅콩)버터'),
  lemonj: R('레몬즙'),
  ketchup: R('케첩|케찹'),
  mayo: R('마요네즈'),
  curry: R('카레'),
  olive: R('올리브'),
};

export const IDS = Object.keys(ALIAS);

// 재료 묶음에서 게임 ID 집합을 찾는다. 재료 칸이 있으면 재료 칸과 제목만 본다.
export function idsIn(doc) {
  const hay = doc.ings ? `${doc.title} ${doc.ings}` : `${doc.title} ${doc.text}`;
  const s = new Set();
  for (const k of IDS) if (ALIAS[k].test(hay)) s.add(k);
  return s;
}
