extends Node
# 조립 인식과 판정 검증. 결과 수치를 그대로 출력한다.
#   Godot --headless --path game test_assembly.tscn

var fails := 0
const KOREAN_THEME := 6    # 외국인 동료 환영 한식


func _ready() -> void:
	unit_cases()
	holdout()
	false_positive()
	reachability()
	taste_only()
	print("RESULT fails=", fails)
	get_tree().quit(1 if fails else 0)


func check(ok: bool, label: String) -> void:
	if not ok:
		fails += 1
		print("FAIL ", label)


func mk(g: Game, id: String, m: String, seas: Array = [], cid = null, cut: String = "W") -> Dictionary:
	var it := g.new_item(id)
	it.cut = cut
	it.seas = seas
	if id == "egg": it.cracked = true
	if m == "blend": it.blend = 30.0
	elif m == "chill": it.chill = 600.0
	elif m != "raw":
		var d := g.mdata(it, m)
		it.cook[m] = (float(d[1]) + float(d[2])) / 2.0 / g.cut_f(it, m)
		it.heat[m] = "mid"
		it.hotEnd = g.now
	if m != "raw" and m != "chill" and cid != null: it.comp = cid
	g.items.append(it)
	return it


func unit_cases() -> void:
	var g := Game.new("t", 0, ["pork"])
	var a := mk(g, "ribs", "boil", ["soy"], 1, "B")
	var b := mk(g, "potato", "boil", ["soy"], 1)
	var c := mk(g, "carrot", "boil", [], 1)
	var r := mk(g, "rice", "micro", [], 2)
	check(g.dish_info([a, b, c]).name == "갈비찜", "갈비찜 구성 요소: " + g.dish_info([a, b, c]).name)
	check(g.dish_info([a, b, c, r]).name == "갈비찜 정식", "갈비찜 정식: " + g.dish_info([a, b, c, r]).name)
	check(g.siblings(a).size() == 3, "같은 냄비 재료는 한 덩어리")
	var pid := g.plate_put_comp(a.uid, -1)
	check(g.get_plate(pid).uids.size() == 3, "덩어리째 접시로")
	g.plate_take_comp(a.uid)
	check(g.plates.is_empty(), "덩어리째 내리기")
	var beef := mk(g, "beef", "stir", ["soy"], 3, "S")
	check(g.dish_info([beef, r]).name == "불고기덮밥", "불고기덮밥: " + g.dish_info([beef, r]).name)
	# 접시별 채점과 가중 평균
	var groups := [[a.uid, b.uid, c.uid, r.uid], [beef.uid]]
	g.picks = ["ribs", "potato", "carrot", "rice", "beef"]
	var R := g.serve(groups)
	check(R.plates.size() == 2, "접시 2개 채점")
	check(R.plates[0].name == "갈비찜 정식", "큰 접시가 먼저")
	var want := 0
	for c0 in R.res.cats: want += int(c0.sc)
	check(int(R.res.total) == want, "합계 일치")
	# 조리법이 다르면 이름을 주지 않고 감점
	var g2 := Game.new("t", 0, ["pork"])
	var f := mk(g2, "ribs", "fry", ["soy"], 1, "B")
	var info := g2.dish_info([f])
	check(info.tier == 0 and info.near.size() > 0, "조리법 다른 갈비는 근접 판정")
	var e := g2.evaluate([f])
	check(e.cats[3].notes.any(func(n): return n.text.contains("갈비")), "조리법 감점 표시")
	# 레시피 썰기 불일치 감점
	var g3 := Game.new("t", 0, ["pork"])
	var w := mk(g3, "beef", "stir", ["soy"], 1, "W")
	var e3 := g3.evaluate([w])
	check(e3.cats[2].notes.any(func(n): return n.text.contains(D.CUT["S"].n)), "불고기 썰기 감점")


func _norm(s: String) -> String:
	return s.replace(" ", "")


# 보류 자료 재현: 정밀레시피를 게임 재료로 옮겨 이름을 맞히는지 본다.
func holdout() -> void:
	var cases: Array = JSON.parse_string(FileAccess.get_file_as_string("res://data/holdout_cases.json"))
	var total := 0
	var exact := 0
	var family := 0
	var graded := 0
	var scoresum := 0
	for c in cases:
		if c.missing != "":
			print("  재현 불가 ", c.name, " (", c.missing, ")")
			continue
		total += 1
		var g := Game.new("t", KOREAN_THEME, ["pork"])
		var its := []
		var k := 1
		for gr in c.groups:
			for id in gr.ids:
				if its.any(func(i): return i.id == id and i.comp == k): continue
				var it := mk(g, id, gr.m, gr.seas, k)
				# 정밀레시피는 손질 규격을 지키므로 재료별 기준 썰기로 놓는다
				it.washed = true
				it.peeled = true
				if gr.m != "raw":
					var ref: String = g.mdata(it, gr.m)[3]
					var mins: float = float(it.cook[gr.m]) * g.cut_f(it, gr.m)
					it.cut = ref
					it.cook[gr.m] = mins
				its.append(it)
			k += 1
		var info := g.dish_info(its)
		var want: String = _norm(c.name)
		var got: String = _norm(info.name)
		var suffix := ""
		for sf in ["비빔밥", "덮밥", "국밥", "볶음밥", "쌈밥"]:
			if want.ends_with(sf): suffix = sf
		var ex := got == want
		var fam: bool = ex or got.contains(want) or (suffix != "" and got.contains(suffix) and int(info.tier) == 2)
		if ex: exact += 1
		if fam: family += 1
		g.picks = []
		var r := g.evaluate(its)
		if int(r.total) >= 80: graded += 1
		scoresum += int(r.total)
		print("  ", "O" if ex else ("~" if fam else "X"), " ", c.name, " -> ", info.name, " tier ", info.tier, " score ", r.total)
	print("HOLDOUT reproducible=", total, "/", cases.size(), " exact=", exact, " family=", family, " A이상=", graded, " avg=", scoresum / maxi(1, total))


# 오탐: 무작위 조합에 조립 요리 이름을 붙이는 비율
func false_positive() -> void:
	seed(12345)
	var ids: Array = D.ING.keys()
	var ms: Array = ["stir", "boil", "grill", "fry", "steam", "raw"]
	var tier2 := 0
	var tier1 := 0
	var N := 1000
	var examples := []
	for i in N:
		var g := Game.new("t", 0, ["pork"])
		var its := []
		var groups := 1 + randi() % 3
		for gi in groups:
			var m: String = ms[randi() % ms.size()]
			for j in 1 + randi() % 3:
				var id: String = ids[randi() % ids.size()]
				if not g.mdata(g.new_item(id), m).is_empty(): its.append(mk(g, id, m, [], gi + 1))
		var info := g.dish_info(its)
		if info.tier == 2:
			tier2 += 1
			if examples.size() < 12: examples.append("%s=%s" % [info.name, ",".join(its.map(func(x): return x.id))])
		elif info.tier == 1: tier1 += 1
	print("FALSEPOS n=", N, " 조립이름=", tier2, " 구성요소이름=", tier1)
	print("  예 ", " | ".join(examples))


# 도달 가능성: 냉장고 1만 판
func reachability() -> void:
	seed(777)
	var per := {}
	var norice := 0
	for i in 10000:
		var ti := i % D.THEMES.size()
		var g := Game.new("t", ti)
		var th: Dictionary = D.THEMES[ti]
		var rr := Game.reachable(g.fridge, th)
		if not g.fridge.has("rice"): norice += 1
		if not per.has(ti): per[ti] = {"min": 999, "fitmin": 999, "lo": 0, "n": 0, "sum": 0, "drink": 0}
		per[ti].min = mini(per[ti].min, rr.all)
		per[ti].fitmin = mini(per[ti].fitmin, rr.fit)
		per[ti].sum += rr.all
		per[ti].n += 1
		if rr.all < Game.MIN_REACH or rr.fit < Game.MIN_FIT: per[ti].lo += 1
		if not rr.need_drink_ok: per[ti].drink += 1
	for ti in per:
		print("  ", D.THEMES[ti].n, " 최소=", per[ti].min, " 평균=", per[ti].sum / per[ti].n, " 주제맞음최소=", per[ti].fitmin, " 미달판=", per[ti].lo, " 음료없음=", per[ti].drink, "/", per[ti].n)
	var bad := 0
	for ti in per: bad += per[ti].lo + per[ti].drink
	check(norice == 0, "즉석밥 없는 냉장고")
	print("REACH 미달 총 ", bad, "/10000 즉석밥없음=", norice)


# 판정은 맛으로만: 안전 규칙 문구와 추가 감점이 없어야 한다
func taste_only() -> void:
	var bad := 0
	for id in D.ING:
		check(not D.ING[id].has("danger"), "안전 표시 남음 " + id)
		var g := Game.new("t", 0, ["pork"])
		var raw := g.new_item(id)
		g.items.append(raw)
		for c in g.evaluate([raw]).cats:
			for n in c.notes:
				if n.text.contains("위험") or n.text.contains("식중독") or n.text.contains("속까지"): bad += 1
	check(bad == 0, "안전 문구 남음")
	print("TASTE 재료=", D.ING.size(), " 안전문구=", bad)
