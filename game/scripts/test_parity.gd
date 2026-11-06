extends Node

func _ready() -> void:
	var cases: Array = JSON.parse_string(FileAccess.get_file_as_string("res://data/parity_cases.json"))
	var re := RegEx.new()
	re.compile("\\[img=[^\\]]*\\][^\\[]*\\[/img\\]")
	var bad := 0
	for c in cases:
		var inp: Dictionary = c.inp
		var g := Game.new("t", int(inp.ti), ["pork"])
		g.picks = inp.picks
		g.now = float(inp.now)
		var its := []
		for it in inp.items:
			for k in ["uid"]: it[k] = int(it[k])
			its.append(it)
		g.items = its
		var r := g.evaluate(its)
		var dish := g.dish_name(its)
		var mine := []
		for cat in r.cats:
			mine.append([cat.n, cat.sc, cat.notes.map(func(x): return str(x.pts) + "|" + re.sub(x.text, "E", true))])
		var ok: bool = int(r.total) == int(c.total) and dish == c.dish
		if ok:
			for i in mine.size():
				if mine[i][0] != c.cats[i][0] or int(mine[i][1]) != int(c.cats[i][1]) or JSON.stringify(mine[i][2]) != JSON.stringify(c.cats[i][2]):
					ok = false
		if not ok:
			bad += 1
			if bad <= 5:
				print("MISMATCH total ", r.total, " vs ", c.total, " dish ", dish, " vs ", c.dish)
				for i in mine.size():
					print("  G ", JSON.stringify(mine[i]))
					if i < c.cats.size(): print("  J ", JSON.stringify(c.cats[i]))
	print("PARITY ", cases.size() - bad, "/", cases.size())
	get_tree().quit()
