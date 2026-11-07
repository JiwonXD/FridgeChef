class_name Game
extends RefCounted
# 게임 상태와 규칙 (화면과 분리). HTML 버전 로직을 그대로 옮김.

const LIMIT := 1800.0
const FRIDGE_N := 18

var name := ""
var theme: Dictionary
var theme_i := 0
var fridge: Array = []
var picks: Array = []
var now := 0.0
var items: Array = []
var uid := 1
var apps := {}
var sel: Array = []
var logs: Array = []
var over := false
var result := {}
var events: Array = []   # 화면에 전달할 사건: {k:"toast"|"sfx"|"done", ...}
var plates: Array = []   # 조립한 접시: {pid, uids, pass}
var next_pid := 1
var next_cid := 1        # 구성 요소 번호. 같은 기구에서 함께 조리한 재료는 한 덩어리


func _init(nm: String, ti: int = -1, fr: Array = []) -> void:
	name = nm
	theme_i = ti if ti >= 0 else randi() % D.THEMES.size()
	theme = D.THEMES[theme_i]
	fridge = fr if fr.size() else make_fridge(theme)
	for a in D.APPS: apps[a.id] = {"hot": null, "s": null}


static func _shuf(a: Array) -> Array:
	var b := a.duplicate()
	b.shuffle()
	return b


# 냉장고는 레시피 근거가 있는 요리를 만들 수 있어야 한다.
const MIN_REACH := 5
const MIN_FIT := 3


func make_fridge(th: Dictionary) -> Array:
	var best: Array = []
	var best_n := -1
	for attempt in 40:
		var fr := _roll_fridge(th)
		var rr := reachable(fr, th)
		var n: int = mini(rr.fit, MIN_FIT) * 10 + mini(rr.all, MIN_REACH) + (10 if rr.need_drink_ok else 0)
		if n > best_n: best = fr; best_n = n
		if rr.fit >= MIN_FIT and rr.all >= MIN_REACH and rr.need_drink_ok: break
	return best


# 재료 ID 목록으로 만들 수 있는 구성 요소 수. fit은 주제에 맞는 것만 센다.
static func reachable(fr: Array, th: Dictionary) -> Dictionary:
	var all := 0
	var fit := 0
	var drink := false
	for p in D.PARTS:
		if not _need_ok(p, fr): continue
		all += 1
		var s := 0.0
		var nn := 0
		for x in fr:
			if _in_need(p, x): s += D.fit_of(th, D.ING[x]); nn += 1
		var best_m := -9
		for m in p.m: best_m = maxi(best_m, int(th.m.get(m, 0)))
		if nn > 0 and s / nn >= 1.0 and best_m >= 0: fit += 1
		if p.role == "drink": drink = true
	return {"all": all, "fit": fit, "need_drink_ok": drink or not th.has("drink")}


static func _in_need(p: Dictionary, id: String) -> bool:
	for nd in p.need:
		if nd.split("|").has(id): return true
	return false


static func _need_ok(p: Dictionary, ids: Array) -> bool:
	for nd in p.need:
		var ok := false
		for alt in nd.split("|"):
			if ids.has(alt): ok = true; break
		if not ok: return false
	return true


func _roll_fridge(th: Dictionary) -> Array:
	var ids: Array = D.ING.keys()
	var pick: Array = []
	for i in _shuf(ids.filter(func(x): return D.fit_of(th, D.ING[x]) >= 5)).slice(0, 6): pick.append(i)
	var quota := {"meat": 2, "sea": 2, "dairy": 1, "veg": 4, "fruit": 2, "grain": 2}
	for c in quota:
		var have := pick.filter(func(x): return D.ING[x].cat == c).size()
		for i in _shuf(ids.filter(func(x): return D.ING[x].cat == c and not pick.has(x))):
			if have >= quota[c]: break
			pick.append(i); have += 1
	for i in _shuf(ids.filter(func(x): return not pick.has(x))):
		if pick.size() >= FRIDGE_N: break
		pick.append(i)
	var order := ["meat", "sea", "dairy", "veg", "fruit", "grain", "etc"]
	var out := pick.slice(0, FRIDGE_N)
	# 안정 정렬 (카테고리 순)
	var idx := {}
	for k in out.size(): idx[out[k]] = k
	out.sort_custom(func(a, b):
		var oa := order.find(D.ING[a].cat); var ob := order.find(D.ING[b].cat)
		return oa < ob if oa != ob else idx[a] < idx[b])
	return out


func begin_play() -> void:
	for id in picks: items.append(new_item(id))
	add_log("조리 시작")


# ---------- 아이템 ----------
func get_item(u: int):
	for it in items:
		if it.uid == u: return it
	return null


func new_item(id: String) -> Dictionary:
	var it := {"uid": uid, "id": id, "cut": "W", "washed": false, "peeled": false, "cracked": false, "battered": false, "mashed": false,
		"seas": [], "cook": {}, "heat": {}, "blend": 0.0, "chill": 0.0, "mar": 0.0, "hotEnd": null, "where": null, "exploded": false, "dry": false, "plate": null, "comp": null}
	uid += 1
	return it


func mdata(it: Dictionary, m: String) -> Array:
	var ing: Dictionary = D.ING[it.id]
	if it.id == "egg":
		var tab: Dictionary = ing.mc if it.cracked else ing.m
		return tab.get(m, [-3, 3, 6, "W"])
	return ing.m.get(m, [-2, 3, 6, "W"])


func size_of(it: Dictionary) -> float:
	return 5.0 if it.mashed else float(D.CUT[it.cut].s)


func cut_f(it: Dictionary, m: String) -> float:
	return pow(size_of(it) / float(D.CUT[mdata(it, m)[3]].s), 0.8)


func primary(it: Dictionary) -> String:
	var best := ""
	var bv := 0.0
	for m in it.cook:
		var d := mdata(it, m)
		var v: float = it.cook[m] / ((float(d[1]) + float(d[2])) / 2.0)
		if v > bv: bv = v; best = m
	return best if best != "" else "raw"


func doneness(it: Dictionary) -> Dictionary:
	var p := primary(it)
	if p == "raw": return {"p": p, "cls": "raw", "label": "생"}
	var d := mdata(it, p)
	var lo := float(d[1]); var hi := float(d[2])
	var mid := (lo + hi) / 2.0
	var fr := 0.0
	for m in it.cook:
		var dm := mdata(it, m)
		var f: float = it.cook[m] / ((float(dm[1]) + float(dm[2])) / 2.0)
		fr += f if m == p else f * 0.35
	var eq := fr * mid
	var cls: String; var label: String; var sc: float
	if eq < lo * 0.97:
		var r := eq / lo
		sc = clampf((r - 0.35) / 0.65, 0, 1) * 0.85
		cls = "under2" if r < 0.6 else "under"
		label = "설익음" if r < 0.6 else "덜 익음"
		if float(D.ING[it.id].raw) >= 1:
			sc = maxf(sc, 0.75); cls = "under"; label = "살짝 덜 익음"
	elif eq <= hi * 1.03:
		sc = 1.0; cls = "good"; label = "잘 익음"
	else:
		var r := eq / hi
		sc = clampf(1.0 - (r - 1.0) * 1.1, 0, 1)
		cls = "burnt" if r >= 1.8 else "over"
		label = "탔음" if r >= 1.8 else "많이 익음"
	return {"p": p, "eq": eq, "lo": lo, "hi": hi, "cls": cls, "label": label, "sc": sc}


# ---------- 시뮬레이션 ----------
func sim_to(t1: float) -> void:
	t1 = minf(t1, LIMIT)
	for guard in 50:
		var next_t := t1
		var next_a = null
		for a in D.APPS:
			var s = apps[a.id].s
			if s != null and s.end <= next_t: next_t = s.end; next_a = a
		accumulate(now, next_t)
		now = maxf(now, next_t)
		if next_a != null: finish_session(next_a, false)
		else: break


func accumulate(t0: float, t1: float) -> void:
	if t1 <= t0: return
	for a in D.APPS:
		var s = apps[a.id].s
		if s == null: continue
		for u in s.items:
			var it = get_item(u)
			if it == null: continue
			var from := maxf(maxf(t0, s.cookStart), s.added[u])
			var to := minf(t1, s.end)
			if to > from: apply_heat(it, a, s, to - from, to)


func apply_heat(it: Dictionary, a: Dictionary, s: Dictionary, sec: float, t_end: float) -> void:
	var m: String = s.method
	if D.COOKM.has(m):
		it.cook[m] = float(it.cook.get(m, 0.0)) + sec / 60.0 * D.lv_factor(a.kind, s.lv) * cut_f(it, m)
		it.heat[m] = s.lv; it.hotEnd = t_end; it.chill = 0.0
		if s.get("prep", "") == "none" and (m == "grill" or m == "stir"): it.dry = true
		if m == "micro" and it.id == "egg" and not it.cracked and not it.exploded:
			it.exploded = true
			add_log("전자레인지 달걀 폭발", true)
			events.append({"k": "boom", "aid": a.id})
	elif m == "blend": it.blend += sec
	elif m == "chill": it.chill += sec
	elif m == "marinate": it.mar += sec


func finish_session(a: Dictionary, manual: bool) -> void:
	var st: Dictionary = apps[a.id]
	var s = st.s
	if s == null: return
	for u in s.items:
		var it = get_item(u)
		if it != null: it.where = null
	if s.vk != "": st.hot = s.vk
	st.s = null
	if s.items.is_empty():
		add_log("%s %s 완료" % [a.n, D.vk_pre_n(s.vk)], true)
		if not manual:
			events.append({"k": "done", "aid": a.id, "text": "%s 예열 완료" % a.n})
		return
	var its: Array = s.items.map(func(u): return get_item(u)).filter(func(x): return x != null)
	add_log("%s %s %s" % [a.n, " ".join(its.map(func(i): return D.ING[i.id].n)), "꺼냄" if manual else "완료"], not manual)
	if not manual:
		events.append({"k": "done", "aid": a.id, "text": "%s %s 완료" % [a.n, "".join(its.map(func(i): return D.emo_bb(i.id, 22)))]})


func add_log(text: String, hl: bool = false) -> void:
	logs.push_front({"t": now, "text": text, "hl": hl})
	if logs.size() > 12: logs.resize(12)


func next_end() -> float:
	var t := INF
	for a in D.APPS:
		var s = apps[a.id].s
		if s != null: t = minf(t, s.end)
	return t


# ---------- 손질 ----------
func prep_list(it: Dictionary) -> Array:
	var ing: Dictionary = D.ING[it.id]
	var a := []
	if ing.has("wash") and not it.washed: a.append({"k": "wash", "icn": "drop", "n": "씻기", "t": 30})
	if ing.has("peel") and not it.peeled: a.append({"k": "peel", "icn": "peel", "n": ing.peel[1], "t": int(ing.peel[0])})
	if ing.has("crack") and not it.cracked: a.append({"k": "crack", "icn": "egg", "n": "깨서 풀기", "t": 20})
	if ing.has("batter") and not it.battered: a.append({"k": "batter", "icn": "batter", "n": "튀김옷 입히기", "t": 60})
	if ing.has("mash") and not it.mashed: a.append({"k": "mash", "icn": "mash", "n": "으깨기", "t": 60})
	return a


func cut_list(it: Dictionary) -> Array:
	var ing: Dictionary = D.ING[it.id]
	if it.mashed or it.blend >= 20: return []
	var out := []
	var cur := float(D.CUT[it.cut].s)
	for c in String(ing.cuts):
		if float(D.CUT[c].s) > cur:
			out.append({"k": c, "n": D.CUT[c].n, "t": maxi(10, D.jround(float(D.CUT[c].t) * float(ing.get("ct", 1)) / 5.0) * 5)})
	return out


func apply_prep(it: Dictionary, k: String) -> void:
	match k:
		"wash": it.washed = true
		"peel": it.peeled = true
		"crack": it.cracked = true
		"batter": it.battered = true
		"mash": it.mashed = true


func discard(u: int) -> void:
	var it = get_item(u)
	if it == null or it.where != null: return
	plate_take(u)
	items.erase(it); sel.erase(u)
	add_log("%s 버림" % D.ING[it.id].n)


func discard_comp(u: int) -> void:
	var it = get_item(u)
	if it == null: return
	for o in siblings(it): discard(o.uid)


func sel_counter() -> Array:
	var out := []
	for u in sel:
		var it = get_item(u)
		if it != null and it.where == null and it.plate == null: out.append(it)
	return out


# ---------- 접시 조립 ----------
func get_plate(pid: int):
	for pl in plates:
		if pl.pid == pid: return pl
	return null


func plate_put(u: int, pid: int) -> int:
	var it = get_item(u)
	if it == null or it.where != null: return -1
	plate_take(u)
	var pl = get_plate(pid)
	if pl == null:
		pl = {"pid": next_pid, "uids": [], "pass": false}
		next_pid += 1
		plates.append(pl)
	pl.uids.append(u)
	it.plate = pl.pid
	return pl.pid


func plate_take(u: int) -> void:
	var it = get_item(u)
	if it == null or it.plate == null: return
	var pl = get_plate(it.plate)
	it.plate = null
	if pl == null: return
	pl.uids.erase(u)
	if pl.uids.is_empty(): plates.erase(pl)


func plate_items(pl: Dictionary) -> Array:
	return pl.uids.map(func(u): return get_item(u)).filter(func(x): return x != null)


# 같은 덩어리 재료 (같은 자리에 함께 놓인 것만)
func siblings(it: Dictionary) -> Array:
	if it.comp == null: return [it]
	return items.filter(func(o): return o.comp == it.comp and o.where == null and o.plate == it.plate)


func plate_put_comp(u: int, pid: int) -> int:
	var it = get_item(u)
	if it == null or it.where != null: return -1
	var np := pid
	for o in siblings(it):
		np = plate_put(o.uid, np)
	return np


func plate_take_comp(u: int) -> void:
	var it = get_item(u)
	if it == null: return
	for o in siblings(it): plate_take(o.uid)


func set_pass(pid: int, on: bool) -> void:
	var pl = get_plate(pid)
	if pl != null: pl.pass = on


func passed_plates() -> Array:
	return plates.filter(func(p): return p.pass)


# ---------- 구성 요소와 조립 인식 ----------
# 접시의 재료를 덩어리로 나눈다. 익히지 않은 재료는 함께 버무린 한 덩어리로 본다.
func comp_groups(its: Array) -> Array:
	var by := {}
	var order := []
	for it in its:
		var key = it.comp if it.comp != null else "raw"
		if not by.has(key): by[key] = []; order.append(key)
		by[key].append(it)
	return order.map(func(k): return by[k])


func _group_method(gr: Array) -> String:
	var tally := {}
	var best := "raw"
	var bv := 0
	for it in gr:
		var m := primary(it)
		if it.blend >= 20: m = "blend"
		elif m == "raw" and it.chill >= 480: m = "chill"
		tally[m] = int(tally.get(m, 0)) + 1
		if tally[m] > bv: bv = tally[m]; best = m
	return best


# 덩어리 하나를 구성 요소로 판별한다. near는 재료는 맞지만 조리법이 다른 경우.
func match_part(gr: Array, prefer_wrap: bool = false) -> Dictionary:
	var ids := _uniq(gr.map(func(i): return i.id))
	var seas := []
	for i in gr: seas.append_array(i.seas)
	var m := _group_method(gr)
	var best = null
	var bs := -INF
	var near = null
	var ns := -INF
	for p in D.PARTS:
		if not Game._need_ok(p, ids): continue
		if p.has("sea") and not p.sea.any(func(x): return seas.has(x)): continue
		var inside := 0
		var hits := 0
		var extra := 0
		var veg := 0
		for x in ids:
			if Game._in_need(p, x): inside += 1
			elif p.opt.has(x): hits += 1
			elif D.AROMA.has(x): pass
			elif D.ING[x].cat == "veg": veg += 1    # 채소는 더 들어가도 같은 요리
			else: extra += 1
		if extra > 2 or (extra > 0 and p.need.size() < 2 and extra > 1): continue
		var sc: float = p.need.size() * 3.0 + mini(inside, p.need.size()) + hits - extra * 2.0 - veg * 0.5 + (1.0 if p.has("sea") else 0.0)
		if prefer_wrap and p.role == "wrap": sc += 2.0
		if p.role == "soup" and m == "boil": sc += 0.5
		if p.m.has(m):
			if sc > bs: bs = sc; best = p
		elif sc > ns and (p.has("sea") or p.need.size() > 1): ns = sc; near = p    # 양념까지 맞췄을 때만 그 요리를 노린 것으로 본다
	return {"part": best, "near": near if best == null else null, "m": m, "group": gr}


func _josa(w: String) -> String:
	if w.is_empty(): return "와"
	var c := w.unicode_at(w.length() - 1)
	if c < 0xAC00 or c > 0xD7A3: return "와"
	return "과" if (c - 0xAC00) % 28 != 0 else "와"


# 접시 전체를 요리로 인식한다. tier 2 조립 요리, 1 구성 요소만, 0 레시피 없음
func dish_info(its: Array) -> Dictionary:
	if its.is_empty(): return {"name": "빈 접시", "tier": 0, "parts": [], "near": []}
	var groups := comp_groups(its)
	var pre := groups.map(func(gr): return match_part(gr))
	var has_main: bool = pre.any(func(x): return x.part != null and x.part.role == "main")
	var ms: Array = groups.map(func(gr): return match_part(gr, has_main))
	var parts: Array = ms.filter(func(x): return x.part != null).map(func(x): return x.part)
	var near: Array = ms.filter(func(x): return x.near != null)
	if parts.is_empty(): return {"name": dish_name(its), "tier": 0, "parts": [], "near": near, "matches": ms}
	# 정체를 알 수 없는 덩어리가 섞이면 조립 요리로 치지 않는다 (양념 채소만 있는 덩어리는 괜찮다)
	var strays: Array = ms.filter(func(x): return x.part == null and not x.group.all(func(i): return D.AROMA.has(i.id)))
	if strays.size():
		return {"name": "%s 곁들임" % parts[0].n, "tier": 1, "parts": parts, "near": near, "matches": ms}
	var pid: Array = parts.map(func(p): return p.id)
	# 이름 있는 조립: 가장 많은 구성 요소를 쓰는 것
	var named = null
	for dd in D.DISHES:
		var ok := true
		for slot in dd.parts:
			var hit := false
			for alt in slot.split("|"):
				if pid.has(alt): hit = true; break
			if not hit: ok = false; break
		if ok and (named == null or dd.parts.size() > named.parts.size()): named = dd
	if named != null: return {"name": named.n, "tier": 2, "parts": parts, "near": near, "matches": ms, "dish": named}
	# 역할 규칙
	var roles := {}
	for p in parts:
		if not roles.has(p.role): roles[p.role] = []
		roles[p.role].append(p)
	for tp in D.TEMPLATES:
		var ok := true
		for r in tp.req:
			if roles.get(r, []).size() < int(tp.req[r]): ok = false; break
		if not ok: continue
		var main = roles.get("main", [null])[0]
		var soup = roles.get("soup", [null])[0]
		var side = roles.get("side", [null])[0]
		# 줄기가 있는 주요리를 앞세운다 (데친 낙지 + 낙지볶음이면 낙지볶음)
		for p in roles.get("main", []):
			if p.has("stem"): main = p; break
		for p in roles.get("side", []):
			if p.has("stem"): side = p; break
		if tp.get("over", false):
			var src = main if tp.req.has("main") else side
			if src == null or not src.has("stem"): continue
		if tp.get("gb", false) and (soup == null or not soup.has("gb")): continue
		var nm := String(tp.n)
		if main != null: nm = nm.replace("{main}", main.n).replace("{stem}", main.get("stem", main.n))
		if side != null: nm = nm.replace("{side}", side.n).replace("{stem}", side.get("stem", side.n))
		if soup != null: nm = nm.replace("{soup}", soup.n).replace("{gb}", soup.get("gb", soup.n))
		return {"name": nm, "tier": 2, "parts": parts, "near": near, "matches": ms, "template": tp}
	var nm2 := String(parts[0].n)
	for k in range(1, parts.size()):
		if k < 2: nm2 += "%s %s" % [_josa(nm2), parts[k].n]
	if parts.size() > 2: nm2 += " 외 %d가지" % (parts.size() - 2)
	return {"name": nm2, "tier": 1, "parts": parts, "near": near, "matches": ms}


# ---------- 조리 기구 ----------
# vk: 예열 상태 키 (화구는 "도구/준비", 오븐은 "oven", 나머지는 "")
func pre_for(aid: String, vk: String, lv: String, join_pre: bool) -> float:
	var st: Dictionary = apps[aid]
	if join_pre: return maxf(0.0, st.s.cookStart - now)
	if vk == "" or st.hot == vk: return 0.0
	return D.preheat_vk(D.app_by_id(aid).kind, vk, lv)


func start_session(aid: String, method: String, lv: String, T: float, pre_only: bool, join_pre: bool, its: Array, vk: String = "") -> void:
	var a := D.app_by_id(aid)
	var st: Dictionary = apps[aid]
	var pre := pre_for(aid, vk, lv, join_pre)
	var s
	if join_pre:
		s = st.s; s.T = T; s.end = s.cookStart + T; s.method = method
	else:
		var pr := vk.split("/")[1] if vk.contains("/") else ""
		s = {"method": method, "lv": lv, "T": 0.0 if pre_only else T, "start": now, "cookStart": now + pre, "items": [], "added": {}, "vk": vk, "prep": pr, "cid": next_cid}
		next_cid += 1
		s.end = s.cookStart + s.T
		if st.hot != vk: st.hot = null
		st.s = s
	for it in its:
		s.items.append(it.uid); s.added[it.uid] = now; it.where = aid
		_join_comp(it, s)
	if pre_only: add_log("%s %s" % [a.n, D.vk_pre_n(vk)])
	else: add_log("%s %s %s %s" % [a.n, " ".join(its.map(func(i): return D.ING[i.id].n)), D.METH[s.method].n, D.fmt(s.T)])
	for it in its: sel.erase(it.uid)


# 조리, 갈기는 재료를 한 덩어리로 묶는다. 냉동, 재우기는 묶지 않는다.
func _join_comp(it: Dictionary, s: Dictionary) -> void:
	if D.COOKM.has(s.method) or s.method == "blend": it.comp = s.cid


func add_to_session(aid: String, its: Array) -> void:
	var a := D.app_by_id(aid)
	var s = apps[aid].s
	for it in its:
		s.items.append(it.uid); s.added[it.uid] = now; it.where = aid
		_join_comp(it, s)
	add_log("%s %s 추가" % [a.n, " ".join(its.map(func(i): return D.ING[i.id].n))])
	for it in its: sel.erase(it.uid)


# ---------- 채점 ----------
func _N(pts: int, text: String) -> Dictionary:
	return {"pts": pts, "text": text, "c": "g" if pts >= 0 else ("m" if pts > -3 else "x")}


func _nm(it: Dictionary) -> String:
	return "%s %s" % [D.emo_bb(it.id, 20), D.ING[it.id].n]


func _uniq(a: Array) -> Array:
	var o := []
	for x in a:
		if not o.has(x): o.append(x)
	return o


# 접시 하나 채점
func evaluate(its: Array) -> Dictionary:
	var th := theme
	var info := dish_info(its)
	var cats := []
	if its.is_empty(): return {"cats": [], "total": 0, "empty": true, "dish": info}
	var ids := _uniq(its.map(func(i): return i.id))
	var seas_all := []
	for i in its: seas_all.append_array(i.seas)
	var seas := _uniq(seas_all)
	var dn := {}
	for it in its: dn[it.uid] = doneness(it)

	# 1) 주제 30
	if true:
		var sc := 30.0
		var notes := []
		var great := 0
		for id in ids:
			var g: Dictionary = D.ING[id]
			var f := D.fit_of(th, g)
			var n := "%s %s" % [D.emo_bb(id, 20), g.n]
			# 주제를 살리는 재료만 별로 치고, 곁들이는 재료(양파, 대파 등)는 조금만 깎는다
			if f >= 5: great += 1; notes.append(_N(0, "%s 주제에 딱" % n))
			elif f >= 2: sc -= 1; notes.append(_N(-1, "%s 무난" % n))
			elif f > -2: sc -= 2; notes.append(_N(-2, "%s 주제와 거리 있음" % n))
			elif f > -5: sc -= 5; notes.append(_N(-5, "%s 주제와 안 맞음" % n))
			else: sc -= 8; notes.append(_N(-8, "%s 주제와 반대" % n))
		for s in seas:
			if D.fit_of(th, D.SEA[s]) >= 5: great += 1
		if great == 0: sc -= 8; notes.append(_N(-8, "주제를 살린 재료 없음"))
		elif great * 3 < ids.size(): sc -= 3; notes.append(_N(-3, "주제 재료 비중이 적음"))
		if ids.size() == 1: sc -= 5; notes.append(_N(-5, "재료 한 가지뿐"))
		var ms: Array = its.map(func(it): return dn[it.uid].p)
		var pen_sum := 0.0
		for m in ms:
			var f := int(th.m.get(m, 0))
			pen_sum += 0 if f >= 2 else (-2 if f == 1 else (-4 if f == 0 else (-6 if f == -1 else -9)))
		var mp := D.jround(pen_sum / ms.size())
		sc += mp
		var main := ", ".join(_uniq(ms).map(func(m): return D.METH[m].n))
		notes.append(_N(mp, "%s 주제와 잘 어울림" % main if mp == 0 else "%s 주제와 %s안 맞음" % [main, "조금 " if mp >= -2 else ""]))
		for s in seas:
			var f := D.fit_of(th, D.SEA[s])
			if f >= 3: sc += 2; notes.append(_N(2, "%s 주제 맛 살림" % D.SEA[s].n))
			elif f < 0: sc -= 4; notes.append(_N(-4, "%s 주제와 반대 맛" % D.SEA[s].n))
		var blend_fruit := its.any(func(it): return it.blend >= 20 and D.ING[it.id].has("blend") and primary(it) == "raw")
		var chilled := its.any(func(it): return it.chill >= 480 and primary(it) == "raw")
		if th.has("drink"):
			if blend_fruit: sc += 3; notes.append(_N(3, "갈아 만든 음료"))
			else: sc -= 8; notes.append(_N(-8, "음료가 아님"))
			if chilled: sc += 3; notes.append(_N(3, "시원하게 냄"))
			else: sc -= 3; notes.append(_N(-3, "미지근함"))
		else:
			if blend_fruit and ["☀️", "🍰", "🥗", "🧒"].has(th.icon): sc += 3; notes.append(_N(3, "갈아 만든 음료 센스"))
			if chilled and ["🍰", "🥗"].has(th.icon): sc += 3; notes.append(_N(3, "시원하게 냄"))
		cats.append({"n": "주제", "max": 30, "sc": clampi(D.jround(sc), 0, 30), "notes": notes})

	# 2) 궁합 15 (같은 접시에 담긴 것끼리만)
	if true:
		var sets := [ids + seas]
		var biggest: int = sets[0].size()
		var sc := 4 if biggest < 2 else 9
		var notes := []
		var good := 0
		var seen := {}
		for st in sets:
			var all: Array = st
			for i in all.size():
				for j in range(i + 1, all.size()):
					var key: String = "%s+%s" % ([all[i], all[j]] if all[i] < all[j] else [all[j], all[i]])
					if seen.has(key): continue
					seen[key] = true
					var p := D.pair_type(all[i], all[j])
					var A := _pn(all[i]); var B := _pn(all[j])
					if p > 0: good += 1; sc += 3; notes.append(_N(3, "%s + %s" % [A, B]))
					elif p < 0: sc -= 5; notes.append(_N(-5, "%s + %s 안 어울림" % [A, B]))
		if info.tier == 2: sc += 6; notes.push_front(_N(6, "%s 조립" % info.name))
		elif info.tier == 1: sc += 2; notes.push_front(_N(2, info.name))
		if biggest < 2: notes.append(_N(0, "재료 하나뿐"))
		elif good == 0: notes.append(_N(0, "특별한 궁합 없음"))
		cats.append({"n": "궁합", "max": 15, "sc": clampi(sc, 0, 15), "notes": notes})

	# 3) 손질 15
	if true:
		var sc := 15
		var notes := []
		var bonus := 0
		for it in its:
			var g: Dictionary = D.ING[it.id]
			var p: String = dn[it.uid].p
			var n := _nm(it)
			if g.has("wash") and not it.washed: sc -= 2; notes.append(_N(-2, "%s 안 씻음" % n))
			if g.has("peel") and not it.peeled and float(g.peel[2]) < 0:
				sc += int(g.peel[2]); notes.append(_N(int(g.peel[2]), "%s %s 안 함" % [n, g.peel[1]]))
			var wo := String(g.wo)
			var whole_ok := wo == "*" or Array(wo.split(" ")).has(p) or String(g.cuts) == ""
			if it.cut == "W" and not whole_ok and not it.mashed and it.blend < 20: sc -= 3; notes.append(_N(-3, "%s 통째로 %s" % [n, D.METH[p].n]))
			if it.battered and p != "fry" and p != "oven": sc -= 2; notes.append(_N(-2, "%s 튀김옷 눅눅" % n))
			if p == "fry" and g.has("batter") and not it.battered: sc -= 2; notes.append(_N(-2, "%s 튀김옷 없이 튀김" % n))
			if it.blend >= 20 and not g.has("blend"): sc -= 3; notes.append(_N(-3, "%s 갈면 안 돼요" % n))
			if g.has("prot") and it.mar >= 600 and it.seas.size(): bonus += 2; notes.append(_N(2, "%s 양념에 재움" % n))
			if it.mashed and p != "raw" and it.id == "potato": bonus += 1; notes.append(_N(1, "%s 으깨기" % n))
		for mt in info.get("matches", []):
			if mt.part == null or not mt.part.has("cut"): continue
			for it in mt.group:
				var want: String = mt.part.cut.get(it.id, "")
				if want != "" and it.cut != want and not it.mashed:
					sc -= 2; notes.append(_N(-2, "%s %s" % [_nm(it), D.CUT[want].n]))
		sc = clampi(sc + bonus, 0, 15)
		if notes.is_empty(): notes.append(_N(0, "손질 깔끔"))
		cats.append({"n": "손질", "max": 15, "sc": sc, "notes": notes})

	# 4) 조리법 15
	if true:
		var sc := 15
		var notes := []
		var heat_noted := {}
		for it in its:
			var g: Dictionary = D.ING[it.id]
			var p: String = dn[it.uid].p
			var n := _nm(it)
			if it.exploded: sc -= 10; notes.append(_N(-10, "%s 전자레인지 폭발" % n)); continue
			if it.dry and (p == "grill" or p == "stir") and float(g.t.get("rich", 0)) < 2: sc -= 2; notes.append(_N(-2, "%s 기름 없이 눌어붙음" % n))
			var s := int(g.raw) if p == "raw" else int(mdata(it, p)[0])
			var pen := 0 if s >= 2 else (-1 if s == 1 else (-3 if s == 0 else (-5 if s == -1 else (-7 if s == -2 else -12))))
			sc += pen
			if it.id == "egg" and not it.cracked and s <= -3: notes.append(_N(pen, "%s 껍질째 %s" % [n, D.METH[p].n]))
			elif s <= -3: notes.append(_N(pen, "%s 날것 위험" % n))
			elif pen <= -5: notes.append(_N(pen, "%s %s 안 어울림" % [n, D.METH[p].n]))
			elif pen < 0: notes.append(_N(pen, "%s %s보다 나은 방법 있음" % [n, D.METH[p].n]))
			var lv = it.heat.get(p)
			var rules := []
			if p == "stir" and lv == "low": rules.append(["stir-low", -2, "약불 볶음 물 생김"])
			if p == "stir" and lv == "high": rules.append(["stir-high", 0, "강불 볶음 불맛"])
			if p == "fry" and lv == "low": rules.append(["fry-low", -3, "약불 튀김 기름 먹음"])
			if p == "fry" and lv == "high" and it.cut == "W" and String(g.cuts) != "": rules.append(["fry-high", -3, "강불 통튀김 겉만 탐"])
			if p == "grill" and lv == "high" and it.cut == "W" and g.has("prot"): rules.append(["grill-high", -2, "강불 통구이 겉 탐"])
			if p == "steam" and lv == "low": rules.append(["steam-low", -2, "약불 찜 김 부족"])
			for r in rules:
				if heat_noted.has(r[0]): continue
				heat_noted[r[0]] = true; sc += r[1]; notes.append(_N(r[1], r[2]))
		for mt in info.get("near", []):
			sc -= 3
			notes.append(_N(-3, "%s %s" % [mt.near.n, D.METH[mt.near.m[0]].n]))
		if not notes.any(func(x): return x.pts < 0): notes.push_front(_N(0, "재료에 맞는 조리법"))
		cats.append({"n": "조리법", "max": 15, "sc": clampi(sc, 0, 15), "notes": notes})

	# 5) 익힘과 온도 25
	if true:
		var sum := 0.0
		var notes := []
		var extra := 0
		var cold := 0
		for it in its:
			var g: Dictionary = D.ING[it.id]
			var d: Dictionary = dn[it.uid]
			var n := _nm(it)
			var s: float
			if d.p == "raw":
				var rw := float(g.raw)
				s = 1.0 if rw >= 1 else (0.6 if rw == 0 else 0.2)
				if rw < 0: notes.append(_N(-D.jround((1 - s) * 25 / its.size()), "%s 익히지 않음" % n))
				if g.has("danger"): extra -= 8; notes.append(_N(-8, "%s 날것 식중독 위험" % n))
			else:
				s = d.sc
				var tx := "%s %s %s분, 적정 %s~%s" % [n, d.label, "%.1f" % (floor(d.eq * 10.0 + 0.5) / 10.0), D.nf(d.lo), D.nf(d.hi)]
				notes.append(_N(0 if s >= 1 else -D.jround((1 - s) * 25 / its.size()), tx))
				if g.has("danger") and d.eq < d.lo * 0.85: extra -= 8; notes.append(_N(-8, "%s 속까지 안 익음" % n))
				var he = it.hotEnd
				var wait := now - (now if he == null else float(he))
				if it.chill < 480 and wait > 600:
					cold += 1
					if cold <= 3: extra -= 2; notes.append(_N(-2, "%s 식음 %d분 방치" % [n, D.jround(wait / 60)]))
			sum += s
		var sc := clampi(D.jround(sum / its.size() * 25 + extra), 0, 25)
		cats.append({"n": "익힘", "max": 25, "sc": sc, "notes": notes})

	for c in cats:
		var order := []
		var m := {}
		for n in c.notes:
			if m.has(n.text): m[n.text].pts += n.pts; m[n.text].k += 1
			else:
				var o: Dictionary = n.duplicate(); o.k = 1; m[n.text] = o; order.append(n.text)
		var merged := []
		for t in order:
			var o: Dictionary = m[t]
			if o.k > 1: o.text = "%s x%d" % [o.text, o.k]
			merged.append(o)
		c.notes = merged
	var total := 0
	for c in cats: total += c.sc
	return {"cats": cats, "total": maxi(0, total), "dish": info}


func _pn(id: String) -> String:
	if D.ING.has(id): return "%s%s" % [D.emo_bb(id, 20), D.ING[id].n]
	return D.SEA[id].n


func dish_name(its: Array) -> String:
	if its.is_empty(): return "빈 접시"
	var sorted := its.duplicate()
	var idx := {}
	for k in sorted.size(): idx[sorted[k].uid] = k
	sorted.sort_custom(func(a, b):
		var pa := int(D.ING[a.id].get("prot", 0)); var pb := int(D.ING[b.id].get("prot", 0))
		return pa > pb if pa != pb else idx[a.uid] < idx[b.uid])
	var main: Dictionary = sorted[0]
	var p := primary(main)
	var has := func(id): return its.any(func(i): return i.id == id and primary(i) == p)
	var any := func(id): return its.any(func(i): return i.id == id)
	var seas := []
	for i in its:
		for s in i.seas:
			if not seas.has(s): seas.append(s)
	var sea := func(k): return seas.has(k)
	var spicy: bool = has.call("kimchi") or has.call("chili") or sea.call("gochujang") or sea.call("gochugaru")
	var fruit := its.all(func(i): return float(D.ING[i.id].t.get("sweet", 0)) >= 2 or ["milk", "yogurt", "icecream"].has(i.id))
	if p == "boil" and any.call("tteok") and (sea.call("gochujang") or sea.call("gochugaru")): return "치즈 떡볶이" if any.call("cheese") else "떡볶이"
	if p == "boil" and any.call("kimchi") and not any.call("ramen"): return ("돼지고기 " if any.call("pork") else ("참치 " if any.call("tuna") else "")) + "김치찌개"
	if p == "boil" and sea.call("doenjang"): return "조개 된장찌개" if any.call("clam") else "된장찌개"
	if p == "boil" and sea.call("curry"): return "카레"
	if p == "boil" and any.call("spaghetti"):
		if any.call("tomato"): return "토마토 파스타"
		if any.call("clam"): return "봉골레 파스타"
		if sea.call("olive") or any.call("garlic"): return "알리오 올리오"
		return "파스타"
	if p == "stir" and any.call("beef") and sea.call("soy"): return "불고기"
	if p == "stir" and any.call("squid") and spicy: return "오징어 볶음"
	if p == "grill" and any.call("pancake"): return "과일 팬케이크" if any.call("banana") or any.call("strawberry") else "팬케이크"
	if any.call("dumpling") and p == "fry": return "군만두"
	if any.call("dumpling") and p == "steam": return "찐만두"
	var suf: String
	if its.any(func(i): return i.blend >= 20):
		suf = ("스무디" if any.call("milk") or any.call("yogurt") or any.call("icecream") else "주스") if fruit else "수프"
	elif p == "raw":
		if fruit: suf = "화채" if its.any(func(i): return i.chill >= 480) else "과일 샐러드"
		elif spicy or sea.call("soy") or sea.call("sesame"): suf = "무침"
		elif any.call("lettuce") and any.call("pork"): suf = "쌈"
		else: suf = "샐러드"
	elif p == "stir": suf = "볶음밥" if has.call("rice") else ("볶음면" if has.call("ramen") or has.call("udon") or has.call("spaghetti") else "볶음")
	elif p == "grill": suf = "토스트" if has.call("bread") or has.call("baguette") else ("프라이" if main.id == "egg" else "구이")
	elif p == "boil":
		if has.call("ramen"): suf = "라면"
		elif has.call("udon"): suf = "우동"
		elif spicy: suf = "찌개"
		elif main.id == "egg" and not main.cracked: suf = "삶은 달걀"
		else: suf = "수프"
	elif p == "fry": suf = "튀김"
	elif p == "steam": suf = "달걀찜" if main.id == "egg" and main.cracked else "찜"
	elif p == "oven": suf = "오븐 구이"
	else: suf = "레인지 요리"
	var skip: Array = {"볶음밥": ["rice"], "볶음면": ["ramen", "udon", "spaghetti"], "토스트": ["bread", "baguette"], "라면": ["ramen"], "우동": ["udon"], "삶은 달걀": ["egg"], "달걀찜": ["egg"], "프라이": ["egg"]}.get(suf, [])
	var names := []
	for i in sorted:
		if skip.has(i.id): continue
		var nm: String = String(D.ING[i.id].n).replace("라면사리", "라면").replace("즉석밥", "밥").replace(" 등심", "").replace(" 가루", "")
		if not names.has(nm): names.append(nm)
	var pre := {"gochujang": "매콤 ", "gochugaru": "매콤 ", "soy": "간장 ", "honey": "꿀 ", "butter": "버터 ", "lemonj": "레몬 ", "curry": "카레 ", "mayo": "마요 "}
	var p2 := ""
	for x in seas:
		if pre.has(x): p2 = pre[x]; break
	var extra := "모둠 " if names.size() > 2 else ""
	var s := "%s%s %s%s" % [p2, " ".join(names.slice(0, 2)), extra, suf]
	while s.contains("  "): s = s.replace("  ", " ")
	return s.strip_edges()


static func grade_of(s: int) -> String:
	return "S" if s >= 90 else ("A" if s >= 80 else ("B" if s >= 65 else ("C" if s >= 50 else "D")))


static func judge_line(s: int) -> String:
	if s >= 90: return "바로 메뉴판에 올립니다"
	if s >= 80: return "합격. 입사를 축하해요"
	if s >= 65: return "조금만 다듬으면 합격"
	if s >= 50: return "가능성은 보여요"
	if s >= 30: return "심사위원이 물을 찾습니다"
	return "다음 기회에"


static func chef_title(s: int) -> String:
	if s >= 95: return "전설의 셰프"
	if s >= 85: return "스타 셰프"
	if s >= 72: return "수석 셰프"
	if s >= 58: return "라인 쿡"
	if s >= 40: return "견습 요리사"
	return "요리 새싹"


# 접시마다 채점하고, 재료 수로 가중 평균해 한 판 점수를 낸다.
func serve(groups: Array) -> Dictionary:
	over = true
	var pls := []
	var its := []
	for gr in groups:
		var pi: Array = gr.map(func(u): return get_item(u)).filter(func(x): return x != null)
		if pi.is_empty(): continue
		var r := evaluate(pi)
		pls.append({"items": pi, "res": r, "name": r.dish.name})
		its.append_array(pi)
	pls.sort_custom(func(a, b): return a.items.size() > b.items.size())
	var res := {"cats": [], "total": 0}
	if pls.is_empty(): res.empty = true
	else:
		var weight := 0.0
		for pl in pls: weight += pl.items.size()
		for ci in pls[0].res.cats.size():
			var c0: Dictionary = pls[0].res.cats[ci]
			var s := 0.0
			var notes := []
			var seen := {}
			for pl in pls:
				s += float(pl.res.cats[ci].sc) * pl.items.size() / weight
				for nt in pl.res.cats[ci].notes:
					if seen.has(nt.text): continue
					seen[nt.text] = true
					notes.append(nt)
			res.cats.append({"n": c0.n, "max": c0.max, "sc": D.jround(s), "notes": notes})
		var ids := _uniq(its.map(func(i): return i.id))
		var unused := picks.filter(func(id): return not ids.has(id))
		var leftover := {}
		if unused.size():
			var pen: int = unused.size() * 4
			leftover = {"n": "남긴 재료", "max": 0, "sc": -pen, "notes": [_N(-pen, ", ".join(unused.map(func(id): return D.ING[id].n)))]}
			res.cats.append(leftover)
		var total := 0
		for c in res.cats: total += c.sc
		res.total = maxi(0, total)
		res.leftover = leftover
	var remain := LIMIT - now
	var bonus := 0 if res.has("empty") else mini(5, int(floor(remain / 240.0)))
	var dish: String = pls[0].name if pls.size() else "빈 접시"
	if pls.size() > 1: dish = "%s 외 %d접시" % [dish, pls.size() - 1]
	result = {"res": res, "bonus": bonus, "score": int(res.total) + bonus, "dish": dish, "items": its, "plates": pls, "remain": remain}
	return result


# 시간이 끝나면 패스 위 접시를 낸다. 패스가 비었으면 접시 전부, 접시도 없으면 조리대 전부를 한 접시로.
func time_over_groups() -> Array:
	for a in D.APPS:
		if apps[a.id].s != null: finish_session(a, true)
	var src := passed_plates()
	if src.is_empty(): src = plates
	if src.is_empty(): return [items.map(func(i): return i.uid)]
	return src.map(func(p): return p.uids.duplicate())
