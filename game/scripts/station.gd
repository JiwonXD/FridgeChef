class_name Station
extends Control
# 주방 한 칸 (화구 하나, 오븐, 싱크대 ...). 칸 전체가 기구 그림이고, 이름은 툴팁, 타이머는 기구 위 작은 표시.

signal clicked(aid: String)

var aid := ""
var kind := ""
var title := ""
var round_shape := false    # 클릭 표시를 원으로

var running := false
var cooking := false
var preheating := false
var vk := ""                # 지금 올라간 도구 상태 ("pan/oil" ...)
var method := ""
var lv := ""
var item_ids: Array = []
var sauce := false
var washing := false
var timer := ""
var pct := 0.0
var active := false         # 작업 패널이 이 칸을 보고 있음
var hover := false

var flash_a := 0.0
var shake := 0.0
var t := 0.0


func setup(a: Dictionary, rect: Rect2) -> void:
	aid = a.id; kind = a.kind; title = a.n
	round_shape = kind == "stove" or kind == "marinate" or kind == "blend"
	position = rect.position; size = rect.size
	tooltip_text = title
	mouse_filter = Control.MOUSE_FILTER_STOP
	mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
	mouse_entered.connect(func(): hover = true; queue_redraw())
	mouse_exited.connect(func(): hover = false; queue_redraw())
	gui_input.connect(_on_input)


func _on_input(e: InputEvent) -> void:
	if e is InputEventMouseButton and e.pressed and e.button_index == MOUSE_BUTTON_LEFT:
		clicked.emit(aid)


func flash() -> void:
	flash_a = 1.0
	shake = 1.0


func _process(delta: float) -> void:
	t += delta
	flash_a = maxf(0, flash_a - delta * 1.4)
	shake = maxf(0, shake - delta * 2.5)
	if running or washing or flash_a > 0 or shake > 0 or active or hover: queue_redraw()


# ---------- 그리기 도구 ----------
func _rr(r: Rect2, col: Color, rad: int = 8, border: Color = Color(0, 0, 0, 0), bw: int = 0) -> void:
	var sb := StyleBoxFlat.new()
	sb.bg_color = col; sb.set_corner_radius_all(rad); sb.anti_aliasing = true
	if bw > 0: sb.border_color = border; sb.set_border_width_all(bw)
	draw_style_box(sb, r)


func _outline(col: Color, w: float) -> void:
	if round_shape:
		draw_arc(size / 2, minf(size.x, size.y) / 2 + 3, 0, TAU, 64, col, w, true)
	else:
		_rr(Rect2(Vector2(-3, -3), size + Vector2(6, 6)), Color(0, 0, 0, 0), 14, col, int(w))


func _shadow_circle(c: Vector2, R: float) -> void:
	for k in 4:
		draw_circle(c + Vector2(0, 3 + k), R + k * 1.5, Color(0.1, 0.08, 0.06, 0.08))


func _items_in_circle(c: Vector2, rad: float, sz: float, spin: float = 0.0) -> void:
	var n := item_ids.size()
	for k in n:
		var a: float = float(k) / maxi(1, n) * TAU - 1.2 + spin
		var rr := 0.0 if n == 1 else rad
		var p := c + Vector2(cos(a), sin(a)) * rr
		var bob := sin(t * 7 + k) * 1.5 if cooking and (method == "boil" or method == "fry") else 0.0
		draw_texture_rect(D.emo(item_ids[k]), Rect2(p - Vector2(sz, sz) / 2 + Vector2(0, bob), Vector2(sz, sz)), false)


func _ring(c: Vector2, R: float, p: float, col: Color) -> void:
	draw_arc(c, R, 0, TAU, 48, Color(0, 0, 0, 0.15), 4.0, true)
	if p > 0: draw_arc(c, R, -PI / 2, -PI / 2 + TAU * clampf(p, 0, 1), 48, col, 4.0, true)


func _fit(n: String, box: Rect2) -> Rect2:
	var tex := D.art(n)
	var ts := tex.get_size()
	var k := minf(box.size.x / ts.x, box.size.y / ts.y)
	var sz := ts * k
	var rr := Rect2(box.position + (box.size - sz) / 2, sz)
	draw_texture_rect(tex, rr, false)
	return rr


func _at(rr: Rect2, fx: float, fy: float) -> Vector2:
	return rr.position + rr.size * Vector2(fx, fy)


# ---------- 본체 ----------
func _draw() -> void:
	var off := Vector2(sin(t * 60) * 3 * shake, 0)
	var r := Rect2(off, size)
	match kind:
		"stove": _draw_burner(r)
		"oven": _draw_oven(r)
		"micro": _draw_micro(r)
		"blend": _draw_blender(r)
		"chill": _draw_freezer(r)
		"marinate": _draw_bowl(r)
		"sink": _draw_sink(r)
	if active:
		_outline(Color(D.C_ACCENT, 0.75 + 0.25 * sin(t * 5)), 3.0)
	elif hover:
		_outline(Color(D.C_ACCENT, 0.55), 2.0)
	if timer != "": _pill()
	if flash_a > 0: _outline(Color(1, 0.75, 0.3, flash_a), 5.0)


func _pill() -> void:
	var w := 70.0
	var pr := Rect2(Vector2(size.x / 2 - w / 2, size.y - 14), Vector2(w, 24))
	_rr(pr.grow(2), Color(1, 1, 1, 0.9), 13)
	_rr(pr, Color("1d1b18"), 12)
	var col := D.C_WARN if preheating else D.C_LCDTXT
	var tw := D.F_LCD.get_string_size(timer, HORIZONTAL_ALIGNMENT_LEFT, -1, 14).x
	draw_string(D.F_LCD, Vector2(pr.get_center().x - tw / 2, pr.position.y + 18), timer, HORIZONTAL_ALIGNMENT_LEFT, -1, 14, col)
	if not preheating and pct > 0:
		_rr(Rect2(pr.position + Vector2(10, 20), Vector2((w - 20) * clampf(pct, 0, 1), 2)), col, 1)


func _flames(c: Vector2, rad: float) -> void:
	var lvn := 2
	if lv == "low": lvn = 1
	elif lv == "high": lvn = 3
	var n := 16
	for k in n:
		var a := float(k) / n * TAU
		var fl := 0.65 + 0.35 * sin(t * 18 + k * 2.3)
		var ln := (3.0 + lvn * 2.6) * fl
		var dir := Vector2(cos(a), sin(a))
		draw_line(c + dir * rad, c + dir * (rad + ln), Color(0.3, 0.5, 1.0, 0.85), 3.0, true)
		draw_line(c + dir * rad, c + dir * (rad + ln * 0.55), Color(0.75, 0.9, 1.0, 0.95), 1.6, true)


const BD := 78.0   # 화구 위 도구 몸통 지름

func _vessel_geo(tool: String, c: Vector2) -> Dictionary:
	# 도구 그림 위치와 안쪽 원 (내용물 그릴 자리)
	var tex := D.art(tool)
	var ts := tex.get_size()
	if tool == "pan" or tool == "wok":
		var rf := 0.395 if tool == "pan" else 0.41
		var cf := Vector2(0.41, 0.41) if tool == "pan" else Vector2(0.43, 0.41)
		var w := BD / (2.0 * rf)
		var sz := Vector2(w, w * ts.y / ts.x)
		return {"rect": Rect2(c - sz * cf, sz), "c": c, "r": BD * 0.5 * 0.86, "rim": BD}
	var w2 := BD / 0.766 * 1.04
	var sz2 := Vector2(w2, w2 * ts.y / ts.x)
	var rc := c - Vector2(0, 4)
	return {"rect": Rect2(rc - Vector2(sz2.x * 0.5, sz2.y * 0.43), sz2), "c": rc, "r": w2 * 0.35, "rim": w2 * 0.766}


func _draw_burner(r: Rect2) -> void:
	var c := r.get_center()
	var tool := D.vk_tool(vk)
	var hot := cooking or preheating
	if tool == "":
		if hot: _flames(c, r.size.x * 0.2)
		return
	if hot: _flames(c, BD * 0.47)
	var g := _vessel_geo(tool, c)
	var vc: Vector2 = g.c
	var vr: float = g.r
	for k in 3:
		draw_circle(c + Vector2(2, 4 + k), BD * 0.5 + k * 1.5, Color(0, 0, 0, 0.10))
	draw_texture_rect(D.art(tool), g.rect, false)
	# 내용물 (물, 기름)
	if vk == "pan/oil" or vk == "wok/oil":
		draw_circle(vc, vr * 0.75, Color(0.95, 0.75, 0.25, 0.20))
		draw_arc(vc + Vector2(-vr * 0.2, -vr * 0.25), vr * 0.3, -2.6, -1.6, 12, Color(1, 1, 0.85, 0.55), 2.0, true)
	elif vk == "wok/deep":
		draw_circle(vc, vr * 0.85, Color(0.85, 0.58, 0.16, 0.80))
		draw_arc(vc, vr * 0.6, -2.6, -1.5, 16, Color(1, 1, 0.85, 0.5), 3.0, true)
	elif vk == "fryer/deep":
		draw_circle(vc, vr, Color(0.85, 0.58, 0.16, 0.55))
		draw_arc(vc, vr * 0.7, -2.6, -1.5, 16, Color(1, 1, 0.85, 0.5), 3.0, true)
	elif vk == "pot/water":
		draw_circle(vc, vr, Color(0.55, 0.72, 0.85, 0.35))
		draw_arc(vc + Vector2(-vr * 0.15, -vr * 0.2), vr * 0.55, -2.5, -1.4, 16, Color(1, 1, 1, 0.45), 2.0, true)
	# 끓는 거품
	if hot and vk == "pot/water":
		for k in 9:
			var ph := fmod(t * 0.9 + k * 0.37, 1.0)
			var bp := vc + Vector2(cos(k * 2.4), sin(k * 1.7)) * vr * 0.65
			draw_arc(bp, 1.5 + ph * 3.5, 0, TAU, 12, Color(1, 1, 1, 0.85 * (1 - ph)), 1.3, true)
	elif cooking and vk.ends_with("/deep"):
		for k in 10:
			var ph := fmod(t * 1.6 + k * 0.29, 1.0)
			var bp := vc + Vector2(cos(k * 2.1), sin(k * 1.3)) * vr * 0.6
			draw_arc(bp, 1.2 + ph * 2.5, 0, TAU, 10, Color(1, 0.95, 0.75, 0.75 * (1 - ph)), 1.2, true)
	_items_in_circle(vc, vr * 0.45, 40.0 if item_ids.size() == 1 else 30.0)
	if tool == "steamer" and hot:
		var lr: float = g.rim
		draw_texture_rect(D.art("glass_lid"), Rect2(vc - Vector2(lr, lr) / 2 + Vector2(0, sin(t * 9) * 0.6 if cooking else 0.0), Vector2(lr, lr)), false)
	if cooking and (method == "boil" or method == "steam"):
		for k in 5:
			var ph := fmod(t * 0.55 + k * 0.2, 1.0)
			draw_circle(vc + Vector2(-vr * 0.6 + k * vr * 0.3 + sin(t + k) * 3, -ph * vr * 1.4), 5 + ph * 9, Color(1, 1, 1, 0.38 * (1 - ph)))
	if running and not preheating:
		_ring(c, BD * 0.5 + 6, pct, D.C_ACCENT)


func _window_items(win: Rect2, spin: float = 0.0) -> void:
	var n := item_ids.size()
	if n == 0: return
	var sz := minf(win.size.y * 0.75, 44.0)
	if spin != 0.0:
		_items_in_circle(win.get_center(), win.size.x * 0.22, sz * (1.0 if n == 1 else 0.8), spin)
		return
	var step := minf(sz * 0.9, (win.size.x - sz) / maxf(1, n - 1))
	var x0 := win.get_center().x - step * (n - 1) / 2.0
	for k in n:
		var p := Vector2(x0 + step * k, win.get_center().y)
		draw_texture_rect(D.emo(item_ids[k]), Rect2(p - Vector2(sz, sz) / 2, Vector2(sz, sz)), false)


func _draw_oven(r: Rect2) -> void:
	var on := running or vk != ""
	var rr := _fit("oven_on" if on else "oven", r)
	var win := Rect2(_at(rr, 0.152, 0.523), rr.size * Vector2(0.70, 0.337))
	_window_items(win)
	if on: _rr(win, Color(1.0, 0.55, 0.15, 0.12 + 0.06 * sin(t * 3)), 4)


func _draw_micro(r: Rect2) -> void:
	var rr := _fit("microwave_on" if running else "microwave", r)
	var win := Rect2(_at(rr, 0.156, 0.444), rr.size * Vector2(0.512, 0.382))
	_window_items(win, t * 1.5 if running else 0.001)
	if running: _rr(win, Color(1.0, 0.85, 0.4, 0.15), 4)


func _draw_blender(r: Rect2) -> void:
	var rr := _fit("blender", r)
	var a := t * (30.0 if running else 0.0)
	var bc := _at(rr, 0.45, 0.62)
	var bs := rr.size.x * 0.34
	draw_set_transform(bc, a, Vector2(1.0, 0.45))
	draw_texture_rect(D.art("blade"), Rect2(-Vector2(bs, bs) / 2, Vector2(bs, bs)), false)
	draw_set_transform(Vector2.ZERO, 0, Vector2.ONE)
	var jc := _at(rr, 0.45, 0.40)
	_items_in_circle(jc + Vector2(sin(t * 20) * 2 if running else 0.0, 0), rr.size.x * 0.13, rr.size.x * 0.3, a * 0.08)


func _draw_freezer(r: Rect2) -> void:
	var open := not item_ids.is_empty()
	var rr := _fit("freezer_open" if open else "freezer", r)
	var slots := [0.30, 0.49, 0.72]
	var sz := rr.size.y * 0.30
	for k in item_ids.size():
		var p := _at(rr, slots[k % 3], 0.40 + 0.22 * float(k / 3 % 2))
		draw_texture_rect(D.emo(item_ids[k]), Rect2(p - Vector2(sz, sz) / 2, Vector2(sz, sz)), false)
	if running:
		var inn := Rect2(_at(rr, 0.21, 0.15), rr.size * Vector2(0.68, 0.7))
		for k in 9:
			var ph := fmod(t * 0.35 + k * 0.17, 1.0)
			draw_circle(inn.position + Vector2(4 + fmod(k * 37.0, inn.size.x - 8), 3 + ph * (inn.size.y - 6)), 1.6, Color(1, 1, 1, 0.95))


func _draw_bowl(r: Rect2) -> void:
	var c := r.get_center()
	var R := minf(r.size.x, r.size.y) * 0.5
	_shadow_circle(c, R * 0.95)
	_fit("bowl", Rect2(c - Vector2(R, R), Vector2(R, R) * 2))
	if sauce: draw_circle(c, R * 0.7, Color(0.72, 0.36, 0.12, 0.45))
	_items_in_circle(c, R * 0.34, 40.0 if item_ids.size() == 1 else 32.0)


func _draw_sink(r: Rect2) -> void:
	var rr := r if D.art("kitchen_bg") != null else _fit("sink", r)
	var fp := _at(rr, 0.49, 0.27) if D.art("kitchen_bg") != null else _at(rr, 0.5, 0.40)
	var c := _at(rr, 0.49, 0.60) if D.art("kitchen_bg") != null else _at(rr, 0.5, 0.625)
	if washing:
		draw_line(fp, c, Color(0.6, 0.8, 1.0, 0.85), 5.0, true)
		for k in 3:
			var ph := fmod(t * 1.2 + k * 0.33, 1.0)
			draw_arc(c, 10 + ph * rr.size.y * 0.3, 0, TAU, 40, Color(0.45, 0.7, 0.95, 0.7 * (1 - ph)), 2.0, true)
		_items_in_circle(c, 22, 46)
