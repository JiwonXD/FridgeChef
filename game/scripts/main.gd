extends Control
# 냉털 셰프: 화면 구성, 입력, 연출

const RANK_PATH := "user://ranking.json"
const NAME_PATH := "user://last_name.txt"

var g: Game = null
var screen := "title"
var busy := false
var M = null
var modal_kind := ""
var act_state = null
var t_now := 0.0
var result_at := 0
var final_at := 0
var final_left := 0

var scr := {}
var ov: Control
var fx: Control
var blocker: Control

# 타이틀
var name_in: LineEdit
var title_rank: VBoxContainer
var title_rank_h: HBoxContainer
var belt: Control
var belt_items: Array = []
var belt_off := 0.0

# 재료 고르기
var pk_grid: Control
var pk_cnt: Label
var pk_go: Button
var pk_icon: TextureRect
var pk_name: Label
var pk_desc: Label

# 주방
var stations := {}
var sink: Station
var board: Control
var acts: Panel
var clock_lbl: Label
var tbar_fill: Panel
var w30: Button
var w60: Button
var wnext: Button
var serve_btn: Button
var note_btn: Button
var k_icon: TextureRect
var k_name: Label
var busy_box: Control
var busy_ic: TextureRect
var busy_emo: TextureRect
var busy_t: Label
var item_cards := {}
var toast_y := 0

# 마지막
var rcpt: Panel
var final_rank: VBoxContainer
var final_rank_h: HBoxContainer
var auto_lbl: Label


# =====================================================================
# 공용 UI 도구
# =====================================================================
func _sb(bg: Color, border: Color = Color(0, 0, 0, 0), bw: int = 0, rad: int = 4, m: int = -1) -> StyleBoxFlat:
	var s := StyleBoxFlat.new()
	s.bg_color = bg
	s.border_color = border
	s.set_border_width_all(bw)
	s.set_corner_radius_all(rad)
	s.anti_aliasing = true
	if m >= 0: s.set_content_margin_all(m)
	return s


func make_theme() -> Theme:
	var t := Theme.new()
	t.default_font = D.F_B
	t.default_font_size = 16
	t.set_color("font_color", "Label", D.C_INK)
	var empty := StyleBoxEmpty.new()
	# 기본 버튼 = 주 버튼 (빨강, 아래 턱이 있는 눌리는 버튼)
	_btn_styles(t, "Button", D.C_ACCENT, Color("e0553d"), Color("9c2a17"), 10, 4)
	_btn_styles(t, "Ghost", Color("f8f8f6"), Color.WHITE, Color("c6c9c7"), 10, 3, Color("dcdedc"))
	_btn_styles(t, "Key", Color("3a3631"), Color("46423c"), Color("141210"), 10, 3)
	_btn_styles(t, "Mini", Color("f8f8f6"), Color.WHITE, Color("c6c9c7"), 10, 3, Color("dcdedc"))
	_btn_styles(t, "Soft", Color("eceded"), Color("e2e4e3"), Color("d3d6d4"), 10, 2)
	_btn_styles(t, "Pill", Color("eceded"), Color("e2e4e3"), Color("d3d6d4"), 15, 2)
	_btn_styles(t, "Opt", Color.WHITE, Color("f2f3f2"), Color("dcdedc"), 12, 2, Color("dcdedc"))
	_btn_styles(t, "OptOn", Color("fde6dd"), Color("fde6dd"), D.C_ACCENT, 12, 2, D.C_ACCENT)
	t.set_type_variation("Flat", "Button")
	for st in ["normal", "hover", "pressed", "disabled", "focus"]: t.set_stylebox(st, "Flat", empty)
	var le := _sb(Color.WHITE, Color("c6c9c7"), 2, 12); le.content_margin_left = 18; le.content_margin_right = 18
	t.set_stylebox("normal", "LineEdit", le)
	var lf := _sb(Color(0, 0, 0, 0), D.C_ACCENT, 3, 12)
	t.set_stylebox("focus", "LineEdit", lf)
	t.set_color("font_color", "LineEdit", D.C_INK)
	t.set_color("font_placeholder_color", "LineEdit", Color(D.C_MUTE, 0.7))
	t.set_color("caret_color", "LineEdit", D.C_ACCENT)
	t.set_color("selection_color", "LineEdit", Color(D.C_ACCENT, 0.25))
	t.set_font("font", "LineEdit", D.F_XB)
	t.set_font_size("font_size", "LineEdit", 24)
	var tp := _sb(D.C_INK, D.C_INK, 0, 3); tp.content_margin_left = 9; tp.content_margin_right = 9; tp.content_margin_top = 4; tp.content_margin_bottom = 5
	t.set_stylebox("panel", "TooltipPanel", tp)
	t.set_color("font_color", "TooltipLabel", D.C_PAPER)
	t.set_font("font", "TooltipLabel", D.F_XB)
	t.set_font_size("font_size", "TooltipLabel", 13)
	return t


func _btn_styles(t: Theme, k: String, bg: Color, hov: Color, edge: Color, rad: int, eb: int, border: Color = Color(0, 0, 0, 0)) -> void:
	if k != "Button": t.set_type_variation(k, "Button")
	var states := {"normal": [bg, eb], "hover": [hov, eb], "pressed": [hov, 1], "disabled": [bg, eb]}
	for st in states:
		var v: Array = states[st]
		var sb := _sb(v[0], edge, 0, rad)
		if border.a > 0:
			sb.border_color = border
			sb.set_border_width_all(2)
			sb.border_width_bottom = maxi(2, v[1])
		else:
			sb.border_width_bottom = v[1]
		t.set_stylebox(st, k, sb)
	t.set_stylebox("focus", k, StyleBoxEmpty.new())


func lbl(text: String, sz: int = 16, col: Color = D.C_INK, font: Font = null) -> Label:
	var l := Label.new()
	l.text = text
	l.add_theme_font_override("font", font if font else D.F_XB)
	l.add_theme_font_size_override("font_size", sz)
	l.add_theme_color_override("font_color", col)
	l.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	l.mouse_filter = Control.MOUSE_FILTER_IGNORE
	return l


func rich(text: String, sz: int = 14, col: Color = D.C_INK2) -> RichTextLabel:
	var r := RichTextLabel.new()
	r.bbcode_enabled = true
	r.fit_content = true
	r.scroll_active = false
	r.autowrap_mode = TextServer.AUTOWRAP_OFF
	r.add_theme_font_override("normal_font", D.F_XB)
	r.add_theme_font_size_override("normal_font_size", sz)
	r.add_theme_color_override("default_color", col)
	r.mouse_filter = Control.MOUSE_FILTER_IGNORE
	r.text = text
	return r


func ico(n: String, sz: int = 22, col: Color = D.C_INK, stroke: float = 1.9) -> TextureRect:
	var r := TextureRect.new()
	r.texture = D.icon(n, sz, stroke)
	r.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	r.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	r.custom_minimum_size = Vector2(sz, sz)
	r.size = Vector2(sz, sz)
	r.modulate = col
	r.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	r.mouse_filter = Control.MOUSE_FILTER_IGNORE
	return r


func emo(id: String, sz: int = 32) -> TextureRect:
	var r := TextureRect.new()
	r.texture = D.emo(id)
	r.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	r.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	r.custom_minimum_size = Vector2(sz, sz)
	r.size = Vector2(sz, sz)
	r.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	r.mouse_filter = Control.MOUSE_FILTER_IGNORE
	return r


func panel(bg: Color, border: Color = Color(0, 0, 0, 0), bw: int = 0, rad: int = 4) -> Panel:
	var p := Panel.new()
	p.add_theme_stylebox_override("panel", _sb(bg, border, bw, rad))
	p.mouse_filter = Control.MOUSE_FILTER_IGNORE
	return p


func place(c: Control, x: float, y: float, w: float = -1, h: float = -1) -> Control:
	c.position = Vector2(x, y)
	if w >= 0 and h >= 0: c.size = Vector2(w, h)
	return c


func hbox(sep: int = 8) -> HBoxContainer:
	var h := HBoxContainer.new()
	h.add_theme_constant_override("separation", sep)
	h.mouse_filter = Control.MOUSE_FILTER_IGNORE
	return h


func vbox(sep: int = 6) -> VBoxContainer:
	var v := VBoxContainer.new()
	v.add_theme_constant_override("separation", sep)
	v.mouse_filter = Control.MOUSE_FILTER_IGNORE
	return v


func spacer() -> Control:
	var c := Control.new()
	c.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	c.mouse_filter = Control.MOUSE_FILTER_IGNORE
	return c


func _fg(variant: String) -> Color:
	if variant == "" : return Color.WHITE
	if variant == "OptOn": return D.C_ACCENT2
	if variant == "Key": return Color("eceded")
	return D.C_INK


func btn(icn: String, text: String, hint: String = "", variant: String = "", mn: Vector2 = Vector2(0, 44), isz: int = 20) -> Button:
	var b := Button.new()
	b.theme_type_variation = variant
	b.focus_mode = Control.FOCUS_NONE
	b.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
	set_btn(b, icn, text, hint, mn, isz)
	juice(b)
	return b


func set_btn(b: Button, icn: String, text: String, hint: String = "", mn: Vector2 = Vector2(-1, -1), isz: int = 20) -> void:
	if mn.x < 0: mn = b.get_meta("mn", Vector2(0, 44))
	b.set_meta("mn", mn)
	if b.has_meta("box"):
		var old: Node = b.get_meta("box")
		b.remove_child(old); old.queue_free()
	var fg := _fg(b.theme_type_variation)
	var small := mn.y < 36
	var h := hbox(5 if small else 8)
	h.alignment = BoxContainer.ALIGNMENT_CENTER
	if icn != "": h.add_child(ico(icn, isz, fg))
	if text != "": h.add_child(lbl(text, 13 if small else 17, fg, D.F_XB))
	if hint != "": h.add_child(lbl(hint, 12 if small else 13, Color(fg, 0.75), D.F_NUM))
	b.add_child(h)
	b.set_meta("box", h)
	var w := h.get_combined_minimum_size().x + (10 if small else 34)
	b.custom_minimum_size = Vector2(maxf(mn.x, w), mn.y)
	b.size = b.custom_minimum_size
	h.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)


func juice(b: Control) -> void:
	b.resized.connect(func(): b.pivot_offset = b.size / 2)
	b.pivot_offset = b.size / 2
	if b is BaseButton:
		b.button_down.connect(func(): _tw_scale(b, 0.94, 0.06))
		b.button_up.connect(func(): _tw_scale(b, 1.0, 0.12))


func _tw_scale(c: Control, v: float, d: float) -> void:
	if not is_instance_valid(c): return
	var tw := c.create_tween()
	tw.tween_property(c, "scale", Vector2(v, v), d).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)


func dis(b: BaseButton, v: bool) -> void:
	b.disabled = v
	b.modulate.a = 0.32 if v else 1.0
	b.mouse_default_cursor_shape = Control.CURSOR_ARROW if v else Control.CURSOR_POINTING_HAND


func clear(c: Node) -> void:
	for ch in c.get_children():
		c.remove_child(ch)
		ch.queue_free()


func lcd_box(text: String, sz: int, w: float, h: float) -> Panel:
	var p := panel(D.C_LCD, D.C_LCD, 0, 4)
	p.size = Vector2(w, h)
	p.custom_minimum_size = Vector2(w, h)
	var ghost := lbl("88:88", sz, Color(D.C_LCDTXT, 0.08), D.F_LCD)
	ghost.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	ghost.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	p.add_child(ghost)
	var l := lbl(text, sz, D.C_LCDTXT, D.F_LCD)
	l.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	l.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	p.add_child(l)
	p.set_meta("lbl", l)
	p.set_meta("ghost", ghost)
	return p


func sfx(n: String) -> void:
	Sfx.play(n)


# =====================================================================
# 시작
# =====================================================================
func _ready() -> void:
	randomize()
	_load_settings()
	theme = make_theme()
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	var bg := ColorRect.new(); bg.color = D.C_PAPER; bg.mouse_filter = Control.MOUSE_FILTER_IGNORE
	bg.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	add_child(bg)
	for n in ["title", "pick", "game", "final"]:
		var c := Control.new()
		c.size = Vector2(1280, 720)
		c.visible = false
		c.mouse_filter = Control.MOUSE_FILTER_IGNORE
		add_child(c)
		scr[n] = c
	build_title()
	build_pick()
	build_final()
	blocker = Control.new(); blocker.size = Vector2(1280, 720); blocker.mouse_filter = Control.MOUSE_FILTER_STOP; blocker.visible = false
	add_child(blocker)
	ov = Control.new(); ov.size = Vector2(1280, 720); ov.visible = false; ov.mouse_filter = Control.MOUSE_FILTER_STOP
	add_child(ov)
	fx = Control.new(); fx.size = Vector2(1280, 720); fx.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(fx)
	go_title()
	var args := OS.get_cmdline_user_args()
	if args.has("--shots"): call_deferred("autopilot")


func show_scr(n: String) -> void:
	for k in scr: scr[k].visible = (k == n)


# =====================================================================
# 랭킹 저장 (user:// = %APPDATA%\FridgeChef)
# =====================================================================
func load_rank() -> Array:
	if not FileAccess.file_exists(RANK_PATH): return []
	var d = JSON.parse_string(FileAccess.get_file_as_string(RANK_PATH))
	return d if typeof(d) == TYPE_ARRAY else []


func save_rank(list: Array) -> void:
	var f := FileAccess.open(RANK_PATH, FileAccess.WRITE)
	if f == null: return
	f.store_string(JSON.stringify(list))
	f.close()


static func rank_less(a, b) -> bool:
	if a.score != b.score: return a.score > b.score
	if a.used != b.used: return a.used < b.used
	return a.ts < b.ts


func add_record(rec: Dictionary) -> Array:
	var list := load_rank()
	list.append(rec)
	list.sort_custom(rank_less)
	var rank := 0
	for i in list.size():
		if list[i].ts == rec.ts: rank = i + 1; break
	save_rank(list.slice(0, 300))
	return [rank, list.size()]


func render_rank(box: VBoxContainer, head: HBoxContainer, hl_ts: int = -1) -> void:
	var list := load_rank()
	list.sort_custom(rank_less)
	clear(head)
	head.add_child(ico("trophy", 26, D.C_INK))
	head.add_child(lbl("TOP 10", 24, D.C_INK, D.F_BL))
	head.add_child(spacer())
	if list.size():
		var cnt := lbl(str(list.size()), 14, D.C_MUTE, D.F_NUM)
		cnt.tooltip_text = "도전 수"
		cnt.mouse_filter = Control.MOUSE_FILTER_PASS
		head.add_child(cnt)
	clear(box)
	if list.is_empty():
		for i in 10:
			var blank := _rank_row(false)
			blank.get_child(0).add_child(lbl(str(i + 1), 18, D.C_LINE, D.F_NUM))
			box.add_child(blank)
		return
	var rows := list.slice(0, 10)
	var me := -1
	for i in list.size():
		if int(list[i].ts) == hl_ts: me = i; break
	var idxs := range(rows.size())
	if me >= 10: idxs = range(9) + [me]
	for i in idxs:
		var r: Dictionary = list[i]
		var row := _rank_row(int(r.ts) == hl_ts)
		var h: HBoxContainer = row.get_child(0)
		var rk := lbl(str(i + 1), 18, D.C_ACCENT if i < 3 else D.C_MUTE, D.F_NUM)
		rk.custom_minimum_size = Vector2(34, 0)
		h.add_child(rk)
		var nm := lbl(str(r.name), 18, D.C_INK, D.F_BL)
		nm.custom_minimum_size = Vector2(150, 0); nm.clip_text = true
		h.add_child(nm)
		var ds := lbl(str(r.get("dish", "")), 14, D.C_MUTE)
		ds.size_flags_horizontal = Control.SIZE_EXPAND_FILL; ds.clip_text = true
		ds.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
		h.add_child(ds)
		var sc := lbl(str(int(r.score)), 20, D.C_INK, D.F_NUM)
		sc.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
		sc.custom_minimum_size = Vector2(44, 0)
		h.add_child(sc)
		box.add_child(row)


func _rank_row(hl: bool) -> Panel:
	var row := Panel.new()
	row.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var st := _sb(Color("fbe3d9") if hl else Color(0, 0, 0, 0), D.C_LINE, 0, 0)
	st.border_width_bottom = 2
	row.add_theme_stylebox_override("panel", st)
	row.custom_minimum_size = Vector2(0, 42)
	var h := hbox(10)
	h.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	h.offset_left = 6; h.offset_right = -8
	row.add_child(h)
	return row


# =====================================================================
# 타이틀
# =====================================================================
func build_title() -> void:
	var r: Control = scr.title
	var w1 := lbl("냉털", 96, D.C_INK, D.F_BL)
	place(w1, 60, 100)
	r.add_child(w1)
	var w2 := lbl("셰프", 96, D.C_ACCENT, D.F_BL)
	place(w2, 60, 194)
	r.add_child(w2)
	var lcd := lcd_box("30:00", 30, 150, 50)
	place(lcd, 300, 234)
	r.add_child(lcd)
	# 닉네임
	name_in = LineEdit.new()
	name_in.placeholder_text = "닉네임"
	name_in.max_length = 10
	name_in.context_menu_enabled = false
	place(name_in, 64, 346, 456, 58)
	name_in.text_submitted.connect(func(_t): start_game())
	r.add_child(name_in)
	var sb := btn("play", "시작", "", "", Vector2(134, 58), 18)
	sb.tooltip_text = "Enter"
	place(sb, 530, 346)
	sb.pressed.connect(start_game)
	r.add_child(sb)
	# 랭킹
	title_rank_h = hbox(10)
	place(title_rank_h, 728, 48, 488, 40)
	r.add_child(title_rank_h)
	var ul := ColorRect.new(); ul.color = D.C_INK; place(ul, 728, 92, 488, 3); r.add_child(ul)
	title_rank = vbox(0)
	place(title_rank, 728, 96, 488, 440)
	r.add_child(title_rank)
	# 컨베이어
	belt = Control.new()
	belt.clip_contents = true
	belt.mouse_filter = Control.MOUSE_FILTER_IGNORE
	place(belt, 0, 560, 1280, 104)
	belt.draw.connect(_draw_belt)
	r.add_child(belt)
	var ids: Array = D.ING.keys()
	ids.shuffle()
	for i in 16:
		var e := emo(ids[i], 56)
		place(e, i * 96.0, 22, 56, 56)
		belt.add_child(e)
		belt_items.append(e)
	var mb := btn("menu", "", "", "Ghost", Vector2(44, 44), 22)
	mb.tooltip_text = "메뉴 Esc"
	place(mb, 1172, 670)
	mb.pressed.connect(open_menu)
	r.add_child(mb)


func _draw_belt() -> void:
	var w := belt.size.x
	belt.draw_rect(Rect2(0, 10, w, 84), Color("2f2c28"))
	belt.draw_rect(Rect2(0, 14, w, 76), Color("3b3833"))
	var off := fmod(belt_off, 32.0)
	var x := -off
	while x < w:
		belt.draw_line(Vector2(x, 16), Vector2(x, 88), Color("4a4640"), 2)
		x += 32
	belt.draw_rect(Rect2(0, 8, w, 3), D.C_INK)
	belt.draw_rect(Rect2(0, 92, w, 3), D.C_INK)


func go_title() -> void:
	close_ov()
	busy = false
	act_state = null
	blocker.visible = false
	screen = "title"
	show_scr("title")
	render_rank(title_rank, title_rank_h)
	if FileAccess.file_exists(NAME_PATH) and name_in.text == "":
		name_in.text = FileAccess.get_file_as_string(NAME_PATH).strip_edges()
	name_in.grab_focus.call_deferred()
	name_in.select_all.call_deferred()


func start_game() -> void:
	if screen != "title" and screen != "final": return
	var nm := name_in.text.strip_edges()
	if nm == "":
		name_in.grab_focus()
		sfx("buzz")
		var tw := name_in.create_tween()
		for k in 4: tw.tween_property(name_in, "position:x", 64.0 + (8 if k % 2 == 0 else -8), 0.04)
		tw.tween_property(name_in, "position:x", 64.0, 0.04)
		return
	var f := FileAccess.open(NAME_PATH, FileAccess.WRITE)
	if f: f.store_string(nm); f.close()
	name_in.release_focus()
	g = Game.new(nm)
	g.picks = []
	pk_icon.texture = D.emo("theme%d" % g.theme_i)
	pk_name.text = g.theme.n
	pk_desc.text = g.theme.d
	screen = "pick"
	show_scr("pick")
	render_pick(true)
	sfx("fanfare")


# =====================================================================
# 재료 고르기
# =====================================================================
func build_pick() -> void:
	var r: Control = scr.pick
	var fridge_bg := ColorRect.new(); fridge_bg.color = Color("dde6ea"); place(fridge_bg, 0, 112, 1280, 608); r.add_child(fridge_bg)
	# 유리 선반
	for k in [1, 2, 3]:
		var sy: float = 112 + 18 + k * (181 + 12) - 12
		var sh := ColorRect.new(); sh.color = Color("c3d2d9"); place(sh, 0, sy, 1280, 7); r.add_child(sh)
		var hl := ColorRect.new(); hl.color = Color("f4f8fa"); place(hl, 0, sy, 1280, 2); r.add_child(hl)
		var sd := ColorRect.new(); sd.color = Color(0.2, 0.3, 0.35, 0.1); place(sd, 0, sy + 7, 1280, 8); r.add_child(sd)
	var top := panel(D.C_CARD)
	place(top, 0, 0, 1280, 112)
	r.add_child(top)
	for i in 6:
		var sl := ColorRect.new(); sl.color = Color(0.2, 0.25, 0.3, 0.05 * (6 - i)); place(sl, 0, 112 + i * 2, 1280, 2); r.add_child(sl)
	pk_icon = TextureRect.new()
	pk_icon.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	pk_icon.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	place(pk_icon, 28, 24, 64, 64)
	pk_icon.tooltip_text = "오늘의 주제"
	r.add_child(pk_icon)
	pk_name = lbl("", 34, D.C_INK, D.F_BL)
	place(pk_name, 106, 18, 700, 44)
	r.add_child(pk_name)
	pk_desc = lbl("", 16, D.C_MUTE, D.F_XB)
	place(pk_desc, 108, 64, 700, 24)
	r.add_child(pk_desc)
	var nb := btn("book", "", "", "Ghost", Vector2(52, 52), 24)
	nb.tooltip_text = "레시피 노트"
	place(nb, 960, 30)
	nb.pressed.connect(open_note)
	r.add_child(nb)
	pk_cnt = lbl("0", 36, D.C_ACCENT, D.F_NUM)
	pk_cnt.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	place(pk_cnt, 1012, 28, 44, 52)
	pk_cnt.mouse_filter = Control.MOUSE_FILTER_PASS
	pk_cnt.tooltip_text = "고른 재료"
	r.add_child(pk_cnt)
	var gl := ico("check", 20, D.C_MUTE, 3.0)
	place(gl, 1060, 44)
	r.add_child(gl)
	pk_go = btn("play", "요리 시작", "", "", Vector2(170, 56), 18)
	pk_go.tooltip_text = "Enter"
	place(pk_go, 1090, 28)
	pk_go.pressed.connect(begin_play)
	r.add_child(pk_go)
	pk_grid = Control.new()
	pk_grid.mouse_filter = Control.MOUSE_FILTER_IGNORE
	place(pk_grid, 0, 112, 1280, 608)
	r.add_child(pk_grid)


func render_pick(pop: bool = false) -> void:
	clear(pk_grid)
	var cw := 194.0
	var ch := 181.0
	for i in g.fridge.size():
		var id: String = g.fridge[i]
		var it: Dictionary = D.ING[id]
		var on := g.picks.has(id)
		var b := Button.new()
		b.theme_type_variation = "Flat"
		b.focus_mode = Control.FOCUS_NONE
		b.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
		place(b, 28 + (i % 6) * (cw + 12), 18 + (i / 6) * (ch + 12), cw, ch)
		var tags := []
		var tv: Array = []
		for k in it.t:
			if float(it.t[k]) > 0: tv.append([k, float(it.t[k])])
		tv.sort_custom(func(a, c): return a[1] > c[1])
		for x in tv.slice(0, 2): tags.append("#" + D.TAGN[x[0]])
		b.tooltip_text = "%s  %s" % [it.n, " ".join(tags)]
		# 선반 위에 그대로 놓인 재료
		var foot := Vector2(cw / 2, ch - 20)
		b.draw.connect(func():
			b.draw_set_transform(foot, 0, Vector2(1, 0.22))
			if on:
				b.draw_circle(Vector2.ZERO, 66, Color(D.C_ACCENT, 0.25))
				b.draw_arc(Vector2.ZERO, 66, 0, TAU, 48, D.C_ACCENT, 5.0, true)
			elif b.is_hovered():
				b.draw_arc(Vector2.ZERO, 66, 0, TAU, 48, Color(D.C_ACCENT, 0.5), 4.0, true)
			b.draw_circle(Vector2.ZERO, 44, Color(0.2, 0.3, 0.35, 0.28))
			b.draw_set_transform(Vector2.ZERO))
		b.mouse_entered.connect(b.queue_redraw)
		b.mouse_exited.connect(b.queue_redraw)
		var ey := ch - 118 - (10 if on else 0)
		var e := emo(id, 104)
		place(e, (cw - 104) / 2, ey, 104, 104)
		b.add_child(e)
		if on:
			var ck := panel(D.C_ACCENT, D.C_ACCENT, 0, 13)
			place(ck, cw / 2 + 34, ey - 2, 26, 26)
			var ci := ico("check", 18, Color.WHITE, 3.0); place(ci, 4, 4)
			ck.add_child(ci)
			b.add_child(ck)
		b.pressed.connect(toggle_pick.bind(id))
		b.pivot_offset = Vector2(cw, ch) / 2
		pk_grid.add_child(b)
		if pop:
			b.scale = Vector2(0.7, 0.7); b.modulate.a = 0
			var tw := b.create_tween().set_parallel()
			tw.tween_property(b, "scale", Vector2.ONE, 0.32).set_delay(i * 0.025).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
			tw.tween_property(b, "modulate:a", 1.0, 0.2).set_delay(i * 0.025)
	pk_cnt.text = str(g.picks.size())
	dis(pk_go, g.picks.is_empty())


func toggle_pick(id: String) -> void:
	if screen != "pick": return
	if g.picks.has(id): g.picks.erase(id)
	else: g.picks.append(id)
	sfx("pop" if g.picks.has(id) else "click")
	render_pick()
	var i := g.fridge.find(id)
	var b: Control = pk_grid.get_child(i)
	b.scale = Vector2(1.07, 1.07) if g.picks.has(id) else Vector2(0.95, 0.95)
	b.create_tween().tween_property(b, "scale", Vector2.ONE, 0.25).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)


func begin_play() -> void:
	if screen != "pick" or g.picks.is_empty(): return
	g.begin_play()
	build_game()
	screen = "play"
	show_scr("game")
	render_all()
	# 작업대로 재료가 차례로 올라옴
	for i in board.get_child_count():
		var c: Control = board.get_child(i)
		var y := c.position.y
		c.position.y = y - 40; c.modulate.a = 0
		var tw := c.create_tween().set_parallel()
		tw.tween_property(c, "position:y", y, 0.3).set_delay(i * 0.04).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
		tw.tween_property(c, "modulate:a", 1.0, 0.2).set_delay(i * 0.04)
	sfx("click")


# =====================================================================
# 주방 (도면 kitchen_layout.png 좌표 그대로)
# =====================================================================
const FLOOR := Rect2(276, 273, 727, 447)
const LAYOUT := {
	"cooktop": Rect2(34, 26, 214, 210), "sink": Rect2(289, 52, 226, 146), "tray": Rect2(540, 47, 190, 146), "board": Rect2(754, 47, 190, 146), "work": Rect2(956, 30, 310, 196),
	"freeze": Rect2(32, 270, 206, 151), "bowl": Rect2(80, 490, 110, 110),
	"oven": Rect2(1068, 246, 175, 163), "micro": Rect2(1072, 420, 168, 130), "blend": Rect2(1120, 578, 70, 92),
	"s1": Rect2(51, 40, 84, 84), "s2": Rect2(147, 40, 84, 84), "s3": Rect2(51, 133, 84, 84), "s4": Rect2(147, 133, 84, 84)}
const PANEL_Y := 390.0
const BG_BOARD := Rect2(547, 45, 206, 160)   # 배경 그림 속 도마 자리 (도마를 옮겨 그릴 때 잘라 쓴다)
const BG_BLANK := Rect2(760, 45, 206, 160)   # 배경의 빈 상판. 옛 도마 자리를 덮는다

var W := {}            # 작업 패널 상태. 비어 있으면 닫힘
var board_st: Station
var tray_btn: Button
var menu_back := ""
const SET_PATH := "user://settings.cfg"


func build_game() -> void:
	var r: Control = scr.game
	clear(r)
	stations.clear()
	item_cards.clear()
	W = {}
	var bgc := Control.new(); bgc.size = Vector2(1280, 720); bgc.mouse_filter = Control.MOUSE_FILTER_IGNORE
	bgc.texture_repeat = CanvasItem.TEXTURE_REPEAT_ENABLED
	bgc.draw.connect(_draw_kitchen.bind(bgc))
	r.add_child(bgc)
	sink = Station.new()
	sink.setup({"id": "sink", "kind": "sink", "n": "싱크대", "ic": "drop"}, LAYOUT.sink)
	sink.clicked.connect(open_area)
	r.add_child(sink)
	var cut_st := Station.new()
	cut_st.setup({"id": "board", "kind": "cutboard", "n": "도마"}, LAYOUT.board)
	cut_st.clicked.connect(func(_a): open_board())
	r.add_child(cut_st)
	board_st = cut_st
	tray_btn = Button.new()
	tray_btn.theme_type_variation = "Flat"
	tray_btn.focus_mode = Control.FOCUS_NONE
	tray_btn.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
	tray_btn.tooltip_text = "쟁반"
	var tr_r: Rect2 = LAYOUT.tray
	place(tray_btn, tr_r.position.x, tr_r.position.y, tr_r.size.x, tr_r.size.y)
	tray_btn.draw.connect(_draw_tray_btn)
	tray_btn.mouse_entered.connect(tray_btn.queue_redraw)
	tray_btn.mouse_exited.connect(tray_btn.queue_redraw)
	tray_btn.pressed.connect(open_tray)
	r.add_child(tray_btn)
	# 작업대 (도마 위 재료)
	var bd: Rect2 = LAYOUT.work
	board = Control.new()
	board.mouse_filter = Control.MOUSE_FILTER_IGNORE
	place(board, bd.position.x + 4, bd.position.y + 4, bd.size.x - 8, bd.size.y - 8)
	r.add_child(board)
	for a in D.APPS:
		var st := Station.new()
		st.setup(a, LAYOUT[a.id])
		st.clicked.connect(open_area)
		r.add_child(st)
		stations[a.id] = st
	# 가운데 바닥
	var cx := FLOOR.position.x + 20
	var cw := FLOOR.size.x - 40
	k_icon = TextureRect.new()
	k_icon.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	k_icon.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	k_icon.texture = D.emo("theme%d" % g.theme_i)
	place(k_icon, cx, 283, 30, 30)
	k_icon.tooltip_text = g.theme.d
	r.add_child(k_icon)
	k_name = lbl(g.theme.n, 20, D.C_INK, D.F_BL)
	place(k_name, cx + 38, 283, 480, 28)
	k_name.tooltip_text = g.theme.d
	k_name.mouse_filter = Control.MOUSE_FILTER_PASS
	r.add_child(k_name)
	note_btn = btn("book", "", "", "Ghost", Vector2(34, 34), 18)
	note_btn.tooltip_text = "레시피 노트"
	place(note_btn, cx + cw - 74, 279)
	note_btn.pressed.connect(open_note)
	r.add_child(note_btn)
	var mb := btn("menu", "", "", "Ghost", Vector2(34, 34), 18)
	mb.tooltip_text = "메뉴 Esc"
	place(mb, cx + cw - 34, 279)
	mb.pressed.connect(open_menu)
	r.add_child(mb)
	# 타이머 (주방 타이머 기기)
	var ty := 318.0
	var dev := Panel.new()
	var ds := _sb(Color("26231f"), Color("14120f"), 0, 16)
	ds.border_width_bottom = 4
	ds.shadow_color = Color(0.2, 0.14, 0.08, 0.25); ds.shadow_size = 10; ds.shadow_offset = Vector2(0, 4)
	dev.add_theme_stylebox_override("panel", ds)
	dev.mouse_filter = Control.MOUSE_FILTER_IGNORE
	place(dev, cx, ty, 420, 62)
	r.add_child(dev)
	var ghost := lbl("88:88", 36, Color(D.C_LCDTXT, 0.07), D.F_LCD)
	place(ghost, 18, 3, 160, 48)
	dev.add_child(ghost)
	clock_lbl = lbl("30:00", 36, D.C_LCDTXT, D.F_LCD)
	place(clock_lbl, 18, 3, 160, 48)
	clock_lbl.tooltip_text = "남은 게임 시간"
	clock_lbl.mouse_filter = Control.MOUSE_FILTER_PASS
	dev.add_child(clock_lbl)
	var tb := panel(Color(1, 1, 1, 0.08), Color(0, 0, 0, 0), 0, 2)
	place(tb, 18, 51, 160, 4)
	dev.add_child(tb)
	tbar_fill = panel(D.C_LCDTXT, Color(0, 0, 0, 0), 0, 2)
	place(tbar_fill, 0, 0, 160, 4)
	tb.add_child(tbar_fill)
	var bx := 194.0
	w30 = btn("ff", "", "0:30", "Key", Vector2(66, 48), 16)
	w30.tooltip_text = "30초 기다리기"
	place(w30, bx, 7); bx += w30.size.x + 6
	w30.pressed.connect(func(): act(30, "clock"))
	dev.add_child(w30)
	w60 = btn("ff", "", "1:00", "Key", Vector2(66, 48), 16)
	w60.tooltip_text = "1분 기다리기"
	place(w60, bx, 7); bx += w60.size.x + 6
	w60.pressed.connect(func(): act(60, "clock"))
	dev.add_child(w60)
	wnext = btn("next", "", "--:--", "Key", Vector2(86, 48), 16)
	wnext.tooltip_text = "다음 완료까지 기다리기"
	place(wnext, bx, 7); bx += wnext.size.x + 12
	wnext.pressed.connect(_wait_next)
	dev.add_child(wnext)
	dev.size.x = bx
	serve_btn = Button.new()
	serve_btn.theme_type_variation = "Flat"
	serve_btn.focus_mode = Control.FOCUS_NONE
	serve_btn.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
	serve_btn.tooltip_text = "패스"
	place(serve_btn, cx + bx + 12, ty, cw - bx - 12, 62)
	serve_btn.draw.connect(_draw_pass)
	serve_btn.mouse_entered.connect(serve_btn.queue_redraw)
	serve_btn.mouse_exited.connect(serve_btn.queue_redraw)
	serve_btn.pressed.connect(open_pass)
	r.add_child(serve_btn)
	# 작업 패널 (영역을 눌렀을 때)
	acts = Panel.new()
	var asb := _sb(D.C_CARD, Color(0, 0, 0, 0), 0, 16)
	asb.shadow_color = Color(0.2, 0.14, 0.08, 0.22); asb.shadow_size = 14; asb.shadow_offset = Vector2(0, 5)
	acts.add_theme_stylebox_override("panel", asb)
	place(acts, cx, PANEL_Y, cw, 720 - PANEL_Y - 10)
	r.add_child(acts)
	# 시간이 흐르는 동안
	busy_box = Control.new()
	busy_box.mouse_filter = Control.MOUSE_FILTER_IGNORE
	place(busy_box, FLOOR.position.x, PANEL_Y, FLOOR.size.x, 720 - PANEL_Y)
	busy_box.visible = false
	r.add_child(busy_box)
	var bb := Panel.new()
	var bsb := _sb(Color("26231f"), Color(0, 0, 0, 0), 0, 18)
	bsb.shadow_color = Color(0, 0, 0, 0.3); bsb.shadow_size = 18; bsb.shadow_offset = Vector2(0, 6)
	bb.add_theme_stylebox_override("panel", bsb)
	place(bb, (busy_box.size.x - 270) / 2, 100, 270, 92)
	busy_box.add_child(bb)
	busy_emo = emo("pork", 60)
	place(busy_emo, 16, 16, 60, 60)
	bb.add_child(busy_emo)
	busy_ic = ico("clock", 30, D.C_PAPER)
	place(busy_ic, 88, 31)
	busy_ic.pivot_offset = Vector2(15, 15)
	bb.add_child(busy_ic)
	busy_t = lbl("", 28, D.C_LCDTXT, D.F_LCD)
	busy_t.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	place(busy_t, 130, 16, 124, 60)
	bb.add_child(busy_t)


func _draw_kitchen(c: Control) -> void:
	var bg := D.art("kitchen_bg")
	if bg != null:
		c.draw_texture_rect(bg, Rect2(0, 0, 1280, 720), false)
		_draw_moved_board(c, bg)
		_draw_tray(c, LAYOUT.tray)
		return
	var f := FLOOR
	c.draw_texture_rect(D.art("floor"), Rect2(f.position.x, f.position.y, f.size.x, 720 - f.position.y), true)
	# 조리대 그림자 (바닥으로 떨어지는)
	for i in 8:
		var a := 0.10 * (1.0 - i / 8.0)
		c.draw_rect(Rect2(f.position.x, f.position.y + i * 2, f.size.x, 2), Color(0.25, 0.17, 0.08, a))
		c.draw_rect(Rect2(f.position.x + i * 2, f.position.y, 2, 720 - f.position.y), Color(0.25, 0.17, 0.08, a))
		c.draw_rect(Rect2(f.end.x - 2 - i * 2, f.position.y, 2, 720 - f.position.y), Color(0.25, 0.17, 0.08, a))
	var top := D.art("counter")
	c.draw_texture_rect(top, Rect2(0, 0, 1280, f.position.y), true)
	c.draw_texture_rect(top, Rect2(0, f.position.y, f.position.x, 720 - f.position.y), true)
	c.draw_texture_rect(top, Rect2(f.end.x, f.position.y, 1280 - f.end.x, 720 - f.position.y), true)
	c.draw_rect(Rect2(0, 0, 1280, 6), Color("cfc4b0"))
	var lip := Color("d9d0bf")
	c.draw_rect(Rect2(f.position.x, f.position.y - 6, f.size.x, 6), lip)
	c.draw_rect(Rect2(f.position.x - 6, f.position.y, 6, 720 - f.position.y), lip)
	c.draw_rect(Rect2(f.end.x, f.position.y, 6, 720 - f.position.y), lip)
	# 도마
	var bd: Rect2 = LAYOUT.board
	for i in 4:
		var gg := 2.0 + i * 2.0
		c.draw_style_box(_sb(Color(0.25, 0.17, 0.08, 0.06), Color(0, 0, 0, 0), 0, 16 + int(gg)), Rect2(bd.position + Vector2(-gg / 2, 3 + gg / 2), bd.size + Vector2(gg, gg / 2)))
	c.draw_style_box(_sb(Color("ddc49b"), Color(0, 0, 0, 0), 0, 16), bd)
	var ib := bd.grow(-4)
	var pts := _rrect_pts(ib, 14.0)
	var uvs := PackedVector2Array()
	for q in pts: uvs.append((q - ib.position) / 256.0)
	c.draw_colored_polygon(pts, Color.WHITE, uvs, D.art("board"))
	# 레인지 상판
	var ct: Rect2 = LAYOUT.cooktop
	c.draw_style_box(_sb(Color("1f1d1b"), Color(0, 0, 0, 0), 0, 16), ct)
	c.draw_line(ct.position + Vector2(14, 3), Vector2(ct.end.x - 14, ct.position.y + 3), Color(1, 1, 1, 0.08), 2)


# 배경에 그려진 도마를 오른쪽으로 옮기고, 옛 자리는 빈 상판으로 덮는다
func _draw_moved_board(c: Control, bg: Texture2D) -> void:
	var ts := bg.get_size()
	var k := ts / Vector2(1280, 720)
	var blank := Rect2(BG_BLANK.position * k, BG_BLANK.size * k)
	var src := Rect2(BG_BOARD.position * k, BG_BOARD.size * k)
	c.draw_texture_rect_region(bg, BG_BOARD, blank)
	var bd: Rect2 = LAYOUT.board
	var s := bd.size.x / 192.0
	c.draw_texture_rect_region(bg, Rect2(bd.position - (Vector2(554, 52) - BG_BOARD.position) * s, BG_BOARD.size * s), src)


# 플레이팅용 나무 쟁반
func _draw_tray(c: Control, r: Rect2) -> void:
	for i in 4:
		var gg := 2.0 + i * 2.0
		c.draw_style_box(_sb(Color(0.25, 0.17, 0.08, 0.07), Color(0, 0, 0, 0), 0, 10 + int(gg)), Rect2(r.position + Vector2(-gg / 2, 3 + gg / 2), r.size + Vector2(gg, gg / 2)))
	c.draw_style_box(_sb(Color("5d3a20"), Color(0, 0, 0, 0), 0, 10), r)
	var top := Rect2(r.position, Vector2(r.size.x, r.size.y - 4))
	c.draw_style_box(_sb(Color("7b4f2c"), Color(0, 0, 0, 0), 0, 10), top)
	var inner := top.grow(-6)
	c.draw_style_box(_sb(Color("94673d"), Color(0, 0, 0, 0), 0, 6), inner)
	for k in 4:
		var y := inner.position.y + 16 + k * (inner.size.y - 28) / 3.0
		c.draw_line(Vector2(inner.position.x + 6, y), Vector2(inner.end.x - 6, y + 1), Color(0.3, 0.17, 0.08, 0.13), 1.0)


# 접시 또는 그릇 한 벌. 위에서 본 흰 도자기
func _draw_dish(b: CanvasItem, kind: String, c: Vector2, dw: float, a: float = 1.0) -> void:
	b.draw_set_transform(c + Vector2(0, dw * 0.42), 0, Vector2(1, 0.3))
	b.draw_circle(Vector2.ZERO, dw * 0.42, Color(0.2, 0.1, 0.04, 0.25 * a))
	b.draw_set_transform(Vector2.ZERO)
	if kind == "bowl":
		var r := dw * 0.44
		b.draw_circle(c, r, Color(0.96, 0.96, 0.94, a))
		b.draw_arc(c, r, 0, TAU, 48, Color(0.7, 0.72, 0.7, a), 1.5, true)
		b.draw_circle(c, r * 0.8, Color(0.88, 0.89, 0.86, a))
		b.draw_circle(c, r * 0.5, Color(0.93, 0.93, 0.9, a))
		return
	var tex := D.art("plate")
	var dh := dw * tex.get_size().y / tex.get_size().x
	b.draw_texture_rect(tex, Rect2(c - Vector2(dw, dh) / 2, Vector2(dw, dh)), false, Color(1, 1, 1, a))


# 국물이나 음료 하나만 담기면 그릇, 나머지는 접시
func _dish_kind(its: Array) -> String:
	var parts: Array = g.dish_info(its).parts
	if parts.size() == 1 and parts[0].role in ["soup", "drink"]: return "bowl"
	return "plate"


func _draw_tray_btn() -> void:
	var r := Rect2(Vector2.ZERO, tray_btn.size)
	if W.get("area", "") == "tray": tray_btn.draw_style_box(_sb(Color(0, 0, 0, 0), D.C_ACCENT, 3, 10), r)
	elif tray_btn.is_hovered(): tray_btn.draw_style_box(_sb(Color(0, 0, 0, 0), Color(D.C_ACCENT, 0.55), 2, 10), r)


func open_tray() -> void:
	if busy or screen != "play": return
	if W.get("area", "") == "tray":
		close_work(); return
	W = {"area": "tray", "picks": []}
	sfx("pop")
	render_all()


func _work_tray(v: VBoxContainer) -> void:
	_work_head(v, ico("cloche", 30, D.C_INK), "쟁반")
	var plates_here: Array = g.plates.filter(func(p): return not p.pass)
	if plates_here.size():
		var h := _row(v, "cloche", "접시")
		for pl in plates_here:
			var pb := _plate_btn(pl)
			pb.pressed.connect(open_plate.bind(pl.pid))
			h.add_child(pb)
	var h2 := _row(v, "plus", "새 접시에 담기")
	var fl := HFlowContainer.new()
	fl.add_theme_constant_override("h_separation", 6)
	fl.add_theme_constant_override("v_separation", 6)
	fl.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	for gr in _counter_groups():
		var b := _group_btn(gr, false, "%s 0:10" % _group_name(gr))
		b.pressed.connect(do_plate.bind(gr[0].uid, -1))
		fl.add_child(b)
	h2.add_child(fl)


func _rrect_pts(r: Rect2, rad: float) -> PackedVector2Array:
	var pts := PackedVector2Array()
	var cs := [Vector2(r.end.x - rad, r.position.y + rad), Vector2(r.end.x - rad, r.end.y - rad), Vector2(r.position.x + rad, r.end.y - rad), Vector2(r.position.x + rad, r.position.y + rad)]
	for k in 4:
		for j in 7:
			var a := -PI / 2 + k * PI / 2 + j * (PI / 2) / 6.0
			pts.append(cs[k] + Vector2(cos(a), sin(a)) * rad)
	return pts


# =====================================================================
# 작업 패널: 영역을 누르면 그 영역에서 할 수 있는 것만 바닥 가운데에 뜸
# =====================================================================
func open_area(aid: String) -> void:
	if busy or screen != "play": return
	if W.get("area", "") == aid:
		close_work()
		return
	W = {"area": aid, "picks": []}
	if aid != "sink":
		var a := D.app_by_id(aid)
		var K: Dictionary = D.KIND[a.kind]
		var st: Dictionary = g.apps[aid]
		W.lv = String(K.get("def", ""))
		W.T = 60 if a.kind == "blend" else (600 if a.kind == "chill" or a.kind == "marinate" else 300)
		W.method = K.methods[0]
		if a.kind == "stove":
			var vk := ""
			if st.s != null: vk = st.s.vk
			elif st.hot != null: vk = st.hot
			if vk == "": vk = "pan/oil"
			W.tool = D.vk_tool(vk)
			W.prep = vk.split("/")[1]
			W.method = D.COMBO[vk][0]
		if st.s != null:
			W.method = st.s.method
			W.lv = st.s.lv
	sfx("click")
	render_all()


func open_item(u: int) -> void:
	if busy or screen != "play": return
	var it = g.get_item(u)
	if it == null: return
	if it.where != null:
		open_area(it.where)
		return
	if W.get("area", "") != "" and W.area != "board" and W.area != "sink":
		# 기구 패널이 열려 있으면 재료를 바로 담기/빼기
		_toggle_pick(u)
		return
	if W.get("area", "") == "sink":
		_toggle_pick(u)
		return
	if W.get("area", "") == "plate":
		do_plate(u, W.pid)
		return
	if W.get("area", "") == "tray":
		do_plate(u, -1)
		return
	if W.get("area", "") == "pass":
		W = {}
	if W.get("area", "") == "board" and W.get("uid", -1) == u:
		close_work()
		return
	if W.get("area", "") == "comp" and g.siblings(it).any(func(o): return o.uid == W.get("uid", -1)):
		close_work()
		return
	W = {"area": "comp" if g.siblings(it).size() > 1 else "board", "uid": u, "picks": []}
	sfx("pop")
	render_all()


func close_work() -> void:
	W = {}
	sfx("click")
	render_all()


func _toggle_pick(u: int) -> void:
	var it = g.get_item(u)
	if it == null or it.where != null: return
	if not _pick_ok(it): sfx("buzz"); return
	# 한 덩어리는 함께 움직인다
	var on: bool = not W.picks.has(u)
	for o in g.siblings(it):
		if on and not W.picks.has(o.uid): W.picks.append(o.uid)
		elif not on: W.picks.erase(o.uid)
	sfx("pop" if on else "click")
	render_all()


func _pick_ok(it: Dictionary) -> bool:
	if W.get("area", "") == "sink": return D.ING[it.id].has("wash") and not it.washed
	return true


func _wvk() -> String:
	var a := D.app_by_id(W.area)
	if a.kind == "stove": return "%s/%s" % [W.tool, W.prep]
	if a.kind == "oven": return "oven"
	return ""


func render_work() -> void:
	clear(acts)
	var area: String = W.get("area", "")
	acts.visible = area != ""
	if area == "": return
	acts.size.y = 720.0 - PANEL_Y - 10.0
	var v := vbox(6)
	v.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	v.offset_left = 16; v.offset_right = -16; v.offset_top = 10; v.offset_bottom = -10
	acts.add_child(v)
	if area == "board": _work_board(v) if W.uid >= 0 else _work_board_pick(v)
	elif area == "plate": _work_plate(v)
	elif area == "comp": _work_comp(v)
	elif area == "tray": _work_tray(v)
	elif area == "pass": _work_pass(v)
	elif area == "sink": _work_sink(v)
	else:
		var st: Dictionary = g.apps[area]
		if st.s != null and st.s.T > 0: _work_running(v)
		else: _work_setup(v)
	_fit_acts.call_deferred(v)


# 내용만큼만 창을 연다. 아래 바닥이 그대로 보이게.
func _fit_acts(v: VBoxContainer) -> void:
	if not is_instance_valid(v): return
	await get_tree().process_frame
	if not is_instance_valid(v): return
	acts.size.y = clampf(v.get_combined_minimum_size().y + 20.0, 110.0, 720.0 - PANEL_Y - 10.0)


func _work_head(v: VBoxContainer, icn: Control, title: String, extra: Array = [], right: Array = []) -> HBoxContainer:
	var h := hbox(10)
	h.custom_minimum_size = Vector2(0, 32)
	h.add_child(icn)
	h.add_child(lbl(title, 18, D.C_INK, D.F_BL))
	for e in extra: h.add_child(e)
	h.add_child(spacer())
	for e in right: h.add_child(e)
	var cl := btn("x", "", "", "Soft", Vector2(36, 32), 16)
	cl.tooltip_text = "닫기 Esc"
	cl.pressed.connect(close_work)
	h.add_child(cl)
	v.add_child(h)
	return h


func _row(v: VBoxContainer, icn: String, tip: String) -> HBoxContainer:
	var h := hbox(8)
	var r := _rl(ico(icn, 20, D.C_MUTE))
	r.tooltip_text = tip
	r.mouse_filter = Control.MOUSE_FILTER_PASS
	r.custom_minimum_size = Vector2(28, 36)
	h.add_child(r)
	v.add_child(h)
	return h


func _chip_btn(text: String, on: bool, locked: bool, fn: Callable, icn: Control = null, tip: String = "") -> Button:
	var w := D.F_XB.get_string_size(text, HORIZONTAL_ALIGNMENT_LEFT, -1, 13).x + 28
	if icn != null: w = maxf(w, icn.get_combined_minimum_size().x + 20)
	var b := opt_btn(icn, text, on, tip, maxf(56, w))
	b.custom_minimum_size.y = 42 if icn != null else 36
	if locked and not on: dis(b, true)
	elif not locked: b.pressed.connect(fn)
	return b


func _tool_tile(t: String, on: bool, locked: bool) -> Button:
	var b := Button.new()
	b.theme_type_variation = "OptOn" if on else "Opt"
	b.focus_mode = Control.FOCUS_NONE
	b.custom_minimum_size = Vector2(72, 56)
	b.tooltip_text = D.TOOLS[t][0]
	b.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
	var tr := TextureRect.new()
	tr.texture = D.art(t)
	tr.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	tr.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	if t == "wok": tr.modulate = Color("b8b2aa")
	tr.mouse_filter = Control.MOUSE_FILTER_IGNORE
	place(tr, 10, 4, 52, 48)
	b.add_child(tr)
	if locked and not on: dis(b, true)
	elif not locked:
		b.pressed.connect(func():
			W.tool = t
			W.prep = D.TOOLS[t][1][0]
			W.method = D.COMBO["%s/%s" % [t, W.prep]][0]
			sfx("click"); render_all())
	return b


func _time_row(h: HBoxContainer, mx: float) -> void:
	for dd in [-60, -10]:
		var b := btn("", D.fmt(absf(dd)).insert(0, "-"), "", "Mini", Vector2(52, 36))
		b.pressed.connect(func(): W.T = clampf(W.T + dd, 10, mx); sfx("tick"); render_all())
		h.add_child(b)
	h.add_child(lcd_box(D.fmt(W.T), 20, 84, 36))
	for dd in [10, 60]:
		var b := btn("", "+" + D.fmt(dd), "", "Mini", Vector2(52, 36))
		b.pressed.connect(func(): W.T = clampf(W.T + dd, 10, mx); sfx("tick"); render_all())
		h.add_child(b)


func _picker(v: VBoxContainer, tip: String) -> void:
	var h := _row(v, "board", tip)
	var fl := HFlowContainer.new()
	fl.add_theme_constant_override("h_separation", 6)
	fl.add_theme_constant_override("v_separation", 6)
	fl.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	for gr in _counter_groups():
		var it: Dictionary = gr[0]
		var b := _group_btn(gr, W.picks.has(it.uid), _group_name(gr), 30)
		if not _pick_ok(it): dis(b, true)
		else: b.pressed.connect(_toggle_pick.bind(it.uid))
		fl.add_child(b)
	h.add_child(fl)


# 조리대 위 재료를 덩어리로 묶어서 돌려준다
func _counter_groups() -> Array:
	var out := []
	var seen := {}
	for it in g.items:
		if it.where != null or it.plate != null: continue
		if it.comp != null:
			if seen.has(it.comp): continue
			seen[it.comp] = true
		out.append(g.siblings(it))
	return out


func _group_name(gr: Array) -> String:
	var mt := g.match_part(gr)
	if mt.part != null: return mt.part.n
	return " ".join(gr.map(func(i): return D.ING[i.id].n))


func _group_btn(gr: Array, on: bool, tip: String, es: int = 36) -> Button:
	var b := Button.new()
	b.theme_type_variation = "OptOn" if on else "Opt"
	b.focus_mode = Control.FOCUS_NONE
	b.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
	b.tooltip_text = tip
	var n := mini(4, gr.size())
	var step := es - 8 if n > 1 else es
	b.custom_minimum_size = Vector2(14 + es + (n - 1) * step, es + 10)
	for k in n:
		var e := emo(gr[k].id, es)
		place(e, 7 + k * step, 5, es, es)
		b.add_child(e)
	juice(b)
	return b


func _picks() -> Array:
	var out := []
	for u in W.picks:
		var it = g.get_item(u)
		if it != null and it.where == null and it.plate == null: out.append(it)
	return out


func _work_setup(v: VBoxContainer) -> void:
	var a := D.app_by_id(W.area)
	var K: Dictionary = D.KIND[a.kind]
	var st: Dictionary = g.apps[a.id]
	var join: bool = st.s != null    # 예열 중인 기구에 재료 넣기
	_work_head(v, ico(a.ic, 26, D.C_INK), a.n)
	if a.kind == "stove":
		var r1 := _row(v, "burner", "도구")
		for t in D.TOOL_ORDER: r1.add_child(_tool_tile(t, W.tool == t, join))
		var r2 := _row(v, "drop", "준비")
		for p in D.TOOLS[W.tool][1]:
			r2.add_child(_chip_btn(D.PREPS[p][0], W.prep == p, join, func():
				W.prep = p; W.method = D.COMBO["%s/%s" % [W.tool, p]][0]; sfx("click"); render_all()))
		var sep := ColorRect.new(); sep.color = Color("dcdedc"); sep.custom_minimum_size = Vector2(2, 30); sep.size_flags_vertical = Control.SIZE_SHRINK_CENTER
		r2.add_child(sep)
		for m in D.COMBO[_wvk()]:
			r2.add_child(_chip_btn("", W.method == m, false, func(): W.method = m; sfx("click"); render_all(), ico(D.METH[m].ic, 24), D.METH[m].n))
	var r3 := _row(v, "flame" if a.kind == "stove" else ("micro" if a.kind == "micro" else "clock"), "세기와 시간")
	if K.lv != null:
		for L in K.lv:
			var fl: Control = null
			if a.kind == "stove":
				fl = hbox(0)
				for q in (1 if L[0] == "low" else (2 if L[0] == "mid" else 3)): fl.add_child(ico("flame", 14, Color.WHITE))
			r3.add_child(_chip_btn("" if fl != null else L[1], W.lv == L[0], join, func(): W.lv = L[0]; sfx("click"); render_all(), fl, L[1]))
	_time_row(r3, float(K.get("max", 1800)))
	_picker(v, "넣을 재료")
	v.add_child(spacer())
	# 아래: 예열, 완료 시각, 버튼
	var vk := _wvk()
	var pre := g.pre_for(a.id, vk, W.lv, join)
	var f := hbox(10)
	if pre > 0:
		f.add_child(_tipico("thermo", D.vk_pre_n(vk), D.C_WARN))
		f.add_child(lbl(D.fmt(pre), 15, D.C_WARN, D.F_NUM))
	elif vk != "" and (st.hot == vk or join):
		f.add_child(_tipico("thermo", "예열됨", D.C_OK))
		f.add_child(ico("check", 18, D.C_OK))
	var its := _picks()
	if its.size():
		f.add_child(_tipico("clock", "완료까지", D.C_INK))
		f.add_child(lbl(D.fmt(pre + W.T), 15, D.C_INK, D.F_NUM))
	f.add_child(spacer())
	var ok: Button
	if its.is_empty():
		ok = btn("thermo", "예열", "0:10", "", Vector2(0, 40), 18)
		if vk == "" or join or pre <= 0: dis(ok, true)
	else:
		ok = btn("in", "넣기", "0:10", "", Vector2(0, 40), 18)
	ok.pressed.connect(work_go)
	f.add_child(ok)
	v.add_child(f)


func _work_running(v: VBoxContainer) -> void:
	var a := D.app_by_id(W.area)
	var st: Dictionary = g.apps[a.id]
	var s = st.s
	var ex := []
	for u in s.items:
		var it = g.get_item(u)
		if it != null: ex.append(emo(it.id, 30))
	_work_head(v, ico(a.ic, 26, D.C_INK), a.n, ex)
	var info := hbox(8)
	var stn: Station = stations[a.id]
	var how: String = D.METH[s.method].n
	if D.KIND[a.kind].lv != null: how += " " + D.lv_name(a.kind, s.lv)
	if a.kind == "stove": how = "%s %s" % [D.TOOLS[D.vk_tool(s.vk)][0], how]
	info.add_child(_tipico(D.METH[s.method].ic, how, D.C_INK))
	info.add_child(_tipico("clock", "남은 시간", D.C_INK))
	info.add_child(lbl(stn.timer, 15, D.C_INK, D.F_NUM))
	v.add_child(info)
	_picker(v, "더 넣을 재료")
	v.add_child(spacer())
	var f := hbox(10)
	f.add_child(spacer())
	var out := btn("out", "꺼내기", "0:10", "Ghost", Vector2(0, 40), 18)
	out.pressed.connect(func(): var id: String = W.area; W = {}; take_back(id))
	f.add_child(out)
	var add := btn("plus", "추가", "0:10", "", Vector2(0, 40), 18)
	dis(add, _picks().is_empty())
	add.pressed.connect(work_go)
	f.add_child(add)
	v.add_child(f)


func _work_sink(v: VBoxContainer) -> void:
	_work_head(v, ico("drop", 26, D.C_INK), "싱크대")
	_picker(v, "씻을 재료")
	v.add_child(spacer())
	var f := hbox(10)
	f.add_child(spacer())
	var its := _picks()
	var ok := btn("drop", "씻기", D.fmt(30 * its.size()), "", Vector2(0, 40), 18)
	dis(ok, its.is_empty())
	ok.pressed.connect(func():
		var ids: Array = its.map(func(i): return i.id)
		W = {}
		var fn := func():
			for i in its: i.washed = true
		sfx("click")
		act(30 * its.size(), "drop", fn, {"wash": ids}))
	f.add_child(ok)
	v.add_child(f)


func _work_board(v: VBoxContainer) -> void:
	var it = g.get_item(W.uid)
	if it == null: W = {}; render_work(); return
	var gi: Dictionary = D.ING[it.id]
	var d := g.doneness(it)
	var ex := []
	for s in state_icons(it):
		var si := ico(s[0], 18, D.C_MUTE)
		si.tooltip_text = s[1]; si.mouse_filter = Control.MOUSE_FILTER_PASS
		ex.append(si)
	if it.seas.size(): ex.append(_tipico("shaker", " ".join(it.seas.map(func(x): return D.SEA[x].n)), D.C_MUTE, 18))
	var chip := panel(D.DCOL[d.cls], D.DCOL[d.cls], 0, 12)
	var cl := lbl(d.label, 13, Color.WHITE, D.F_BL)
	cl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	chip.custom_minimum_size = Vector2(cl.get_combined_minimum_size().x + 22, 26)
	chip.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	cl.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	chip.add_child(cl)
	ex.append(chip)
	var del := btn("trash", "", "", "Soft", Vector2(36, 32), 16)
	del.tooltip_text = "버리기"
	del.get_meta("box").get_child(0).modulate = D.C_BAD
	del.pressed.connect(func(): W = {}; g.discard(it.uid); sfx("click"); render_all())
	_work_head(v, emo(it.id, 34), gi.n, ex, [del])
	var row := _row(v, "knife", "손질")
	var pl := g.prep_list(it)
	var cl2 := g.cut_list(it)
	for p in pl:
		var b := _act_btn(p.icn, p.n, D.fmt(p.t))
		b.pressed.connect(do_prep.bind(it.uid, p.k))
		row.add_child(b)
	if pl.size() and cl2.size():
		var sep := ColorRect.new(); sep.color = Color("dcdedc"); sep.custom_minimum_size = Vector2(2, 40); sep.size_flags_vertical = Control.SIZE_SHRINK_CENTER
		row.add_child(sep)
	for p in cl2:
		var b := _act_btn("c_" + p.k, p.n, D.fmt(p.t))
		b.pressed.connect(do_cut.bind(it.uid, p.k))
		row.add_child(b)
	if pl.is_empty() and cl2.is_empty():
		row.add_child(_tipico("check", "손질 끝", D.C_OK))
	var r2 := _row(v, "shaker", "밑간 최대 3개")
	var grid := GridContainer.new()
	grid.columns = 8
	grid.add_theme_constant_override("h_separation", 5)
	grid.add_theme_constant_override("v_separation", 5)
	var can_sea: bool = it.seas.size() < 3
	for k in D.SEA:
		var b := btn("", D.SEA[k].n, "", "Pill", Vector2(70, 30))
		b.tooltip_text = "밑간 0:15"
		dis(b, not can_sea or it.seas.has(k))
		b.pressed.connect(do_season.bind(it.uid, k))
		grid.add_child(b)
	r2.add_child(grid)
	var r3 := _row(v, "cloche", "접시에 담기")
	var nb := btn("plus", "", "0:10", "Soft", Vector2(0, 40), 14)
	nb.tooltip_text = "새 접시"
	nb.pressed.connect(do_plate.bind(it.uid, -1))
	r3.add_child(nb)
	for pq in g.plates:
		if pq.pass: continue
		var pb := _plate_btn(pq)
		pb.pressed.connect(do_plate.bind(it.uid, pq.pid))
		r3.add_child(pb)


func _plate_btn(pl: Dictionary) -> Button:
	var b := Button.new()
	b.theme_type_variation = "Soft"
	b.focus_mode = Control.FOCUS_NONE
	b.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
	var its := g.plate_items(pl)
	b.custom_minimum_size = Vector2(16 + 26 * mini(4, its.size()), 40)
	b.tooltip_text = "%s 0:10" % g.dish_info(its).name
	for k in mini(4, its.size()):
		var e := emo(its[k].id, 24); place(e, 8 + k * 26, 8, 24, 24); b.add_child(e)
	juice(b)
	return b


func _plate_token(pl: Dictionary, p: Vector2, cw: float, chh: float) -> void:
	var its := g.plate_items(pl)
	var b := Button.new()
	b.theme_type_variation = "Flat"
	b.focus_mode = Control.FOCUS_NONE
	b.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
	place(b, p.x, p.y, cw, chh)
	var sel: bool = W.get("area", "") == "plate" and W.get("pid", -1) == pl.pid
	var kind := _dish_kind(its)
	var dw := cw - 2.0
	var dc := Vector2(cw / 2, chh / 2 - 2)
	b.draw.connect(func():
		_draw_dish(b, kind, dc, dw)
		if sel: b.draw_arc(dc, dw * 0.56, 0, TAU, 40, D.C_ACCENT, 3.0, true)
		elif b.is_hovered(): b.draw_arc(dc, dw * 0.56, 0, TAU, 40, Color(D.C_ACCENT, 0.5), 2.0, true))
	b.mouse_entered.connect(b.queue_redraw)
	b.mouse_exited.connect(b.queue_redraw)
	var n := mini(5, its.size())
	for k in n:
		var a := float(k) / n * TAU - 1.6
		var es: int = int(dw * (0.42 if n > 1 else 0.56))
		var q := dc + (Vector2(cos(a), sin(a)) * dw * 0.2 if n > 1 else Vector2.ZERO) - Vector2(es, es) / 2.0
		var e := emo(its[k].id, es)
		place(e, q.x, q.y, es, es)
		b.add_child(e)
	b.tooltip_text = g.dish_info(its).name
	b.pressed.connect(open_plate.bind(pl.pid))
	board.add_child(b)


func open_plate(pid: int) -> void:
	if busy or screen != "play": return
	if W.get("area", "") == "plate" and W.get("pid", -1) == pid:
		close_work(); return
	W = {"area": "plate", "pid": pid, "picks": []}
	sfx("pop")
	render_all()


func open_board() -> void:
	if busy or screen != "play": return
	if W.get("area", "") == "board":
		close_work(); return
	W = {"area": "board", "uid": -1, "picks": []}
	sfx("pop")
	render_all()


func do_plate(u: int, pid: int) -> void:
	var it = g.get_item(u)
	if it == null or it.where != null: return
	if pid >= 0 and it.plate == pid: return
	sfx("plate")
	var fn := func():
		var np := g.plate_put_comp(u, pid)
		W = {"area": "plate", "pid": np, "picks": []}
	act(10, "cloche", fn, {"emo": it.id})


func _work_board_pick(v: VBoxContainer) -> void:
	_work_head(v, ico("board", 30, D.C_INK), "도마")
	var h := _row(v, "board", "도마에 올릴 재료")
	var fl := HFlowContainer.new()
	fl.add_theme_constant_override("h_separation", 6)
	fl.add_theme_constant_override("v_separation", 6)
	fl.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	for gr in _counter_groups():
		var b := _group_btn(gr, false, _group_name(gr))
		var u: int = gr[0].uid
		var ar := "comp" if gr.size() > 1 else "board"
		b.pressed.connect(func(): W = {"area": ar, "uid": u, "picks": []}; sfx("pop"); render_all())
		fl.add_child(b)
	h.add_child(fl)


func _work_plate(v: VBoxContainer) -> void:
	var pl = g.get_plate(W.pid)
	if pl == null: W = {}; render_work(); return
	var its := g.plate_items(pl)
	var info := g.dish_info(its)
	var ex := []
	if info.tier == 2: ex.append(_tipico("check", "레시피 조립", D.C_OK, 20))
	_work_head(v, ico("cloche", 30, D.C_INK), info.name, ex)
	var h := _row(v, "cloche", "담긴 구성 요소")
	for gr in g.comp_groups(its):
		var b := _group_btn(gr, true, "%s 내리기" % _group_name(gr))
		var u: int = gr[0].uid
		b.pressed.connect(func():
			if gr[0].comp == null:
				for o in gr: g.plate_take(o.uid)
			else: g.plate_take_comp(u)
			if g.get_plate(pl.pid) == null: W = {}
			sfx("click"); render_all())
		h.add_child(b)
	var h2 := _row(v, "plus", "더 담기")
	var fl := HFlowContainer.new()
	fl.add_theme_constant_override("h_separation", 6)
	fl.add_theme_constant_override("v_separation", 6)
	fl.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	for gr in _counter_groups():
		var b := _group_btn(gr, false, "%s 담기 0:10" % _group_name(gr))
		b.pressed.connect(do_plate.bind(gr[0].uid, pl.pid))
		fl.add_child(b)
	h2.add_child(fl)
	var f := hbox(10)
	f.add_child(spacer())
	var send := btn("next", "", "0:10", "", Vector2(0, 40), 18)
	send.tooltip_text = "패스에 올리기"
	send.pressed.connect(send_plate.bind(pl.pid))
	f.add_child(send)
	v.add_child(f)


func _work_comp(v: VBoxContainer) -> void:
	var it = g.get_item(W.uid)
	if it == null: W = {}; render_work(); return
	var gr := g.siblings(it)
	var ex := []
	for o in gr:
		var d := g.doneness(o)
		var e := emo(o.id, 26)
		e.tooltip_text = "%s  %s" % [D.ING[o.id].n, d.label]
		e.mouse_filter = Control.MOUSE_FILTER_PASS
		ex.append(e)
	var del := btn("trash", "", "", "Soft", Vector2(36, 32), 16)
	del.tooltip_text = "버리기"
	del.get_meta("box").get_child(0).modulate = D.C_BAD
	del.pressed.connect(func(): W = {}; g.discard_comp(it.uid); sfx("click"); render_all())
	_work_head(v, ico("cloche", 30, D.C_INK), _group_name(gr), ex, [del])
	var r3 := _row(v, "cloche", "접시에 담기")
	var nb := btn("plus", "", "0:10", "Soft", Vector2(0, 40), 14)
	nb.tooltip_text = "새 접시"
	nb.pressed.connect(do_plate.bind(it.uid, -1))
	r3.add_child(nb)
	for pq in g.plates:
		if pq.pass: continue
		var pb := _plate_btn(pq)
		pb.pressed.connect(do_plate.bind(it.uid, pq.pid))
		r3.add_child(pb)


# ---------- 패스: 완성한 접시를 올리고 탁상 벨을 누른다 ----------
func open_pass() -> void:
	if busy or screen != "play": return
	if W.get("area", "") == "pass":
		close_work(); return
	W = {"area": "pass", "picks": []}
	sfx("pop")
	render_all()


func send_plate(pid: int) -> void:
	if busy: return
	var pl = g.get_plate(pid)
	if pl == null: return
	sfx("plate")
	var fn := func():
		g.set_pass(pid, true)
		W = {"area": "pass", "picks": []}
	act(10, "cloche", fn)


func _work_pass(v: VBoxContainer) -> void:
	_work_head(v, ico("bell", 28, D.C_INK), "패스")
	var pp := g.passed_plates()
	var h := _row(v, "cloche", "패스 위 접시")
	for pl in pp:
		var its := g.plate_items(pl)
		var b := _group_btn(its, true, "%s 내리기" % g.dish_info(its).name)
		var pid: int = pl.pid
		b.pressed.connect(func(): g.set_pass(pid, false); sfx("click"); render_all())
		h.add_child(b)
	var rest: Array = g.plates.filter(func(p): return not p.pass)
	if rest.size():
		var h2 := _row(v, "next", "쟁반 접시")
		for pl in rest:
			var its := g.plate_items(pl)
			var b := _group_btn(its, false, "%s 올리기 0:10" % g.dish_info(its).name)
			b.pressed.connect(send_plate.bind(pl.pid))
			h2.add_child(b)
	v.add_child(spacer())
	var f := hbox(10)
	var cooking := D.APPS.filter(func(a): return g.apps[a.id].s != null and g.apps[a.id].s.items.size() > 0)
	for a in cooking: f.add_child(_tipico(a.ic, "%s 조리 중" % a.n, D.C_WARN, 22))
	var served := []
	for pl in pp: served.append_array(pl.uids)
	var left := g.items.filter(func(i): return not served.has(i.uid))
	if left.size(): f.add_child(_chip([ico("warn", 18, D.C_WARN)], str(left.size()), D.C_WARN, "패스에 없는 재료"))
	f.add_child(spacer())
	var bell := btn("bell", "", "1:00", "", Vector2(0, 46), 22)
	bell.tooltip_text = "벨 누르기"
	dis(bell, pp.is_empty())
	bell.pressed.connect(ring_bell)
	f.add_child(bell)
	v.add_child(f)


func ring_bell() -> void:
	if busy: return
	var pp := g.passed_plates()
	if pp.is_empty(): return
	var groups: Array = pp.map(func(p): return p.uids.duplicate())
	W = {}
	sfx("ding")
	act(60, "cloche", func(): serve(groups))


# 스테인리스 패스 선반
func _draw_pass() -> void:
	var b := serve_btn
	var r := Rect2(Vector2.ZERO, b.size)
	var on: bool = W.get("area", "") == "pass"
	b.draw_style_box(_sb(Color("b9bdbb"), Color(0, 0, 0, 0), 0, 8), Rect2(0, 4, r.size.x, r.size.y - 4))
	b.draw_style_box(_sb(Color("dfe2e0"), Color(0, 0, 0, 0), 0, 8), Rect2(0, 0, r.size.x, r.size.y - 8))
	b.draw_rect(Rect2(10, 6, r.size.x - 20, 2), Color(1, 1, 1, 0.8))
	var pp := g.passed_plates() if g != null else []
	var step := minf(52.0, (r.size.x - 66.0) / maxf(1, pp.size()))
	for k in pp.size():
		_draw_dish(b, _dish_kind(g.plate_items(pp[k])), Vector2(30 + k * step, 26), 48.0)
	if on: b.draw_style_box(_sb(Color(0, 0, 0, 0), D.C_ACCENT, 3, 8), r)
	elif b.is_hovered(): b.draw_style_box(_sb(Color(0, 0, 0, 0), Color(D.C_ACCENT, 0.5), 2, 8), r)


func render_pass() -> void:
	if not is_instance_valid(serve_btn): return
	clear(serve_btn)
	serve_btn.queue_redraw()
	var pp := g.passed_plates()
	var names := []
	var step := minf(52.0, (serve_btn.size.x - 66.0) / maxf(1, pp.size()))
	for k in pp.size():
		var its := g.plate_items(pp[k])
		names.append(g.dish_info(its).name)
		var n := mini(3, its.size())
		for j in n:
			var a := float(j) / n * TAU - 1.6
			var q := Vector2(30 + k * step, 26) + (Vector2(cos(a), sin(a)) * 8.0 if n > 1 else Vector2.ZERO) - Vector2(11, 11)
			var e := emo(its[j].id, 22)
			place(e, q.x, q.y, 22, 22)
			e.mouse_filter = Control.MOUSE_FILTER_IGNORE
			serve_btn.add_child(e)
	var bi := ico("bell", 26, D.C_ACCENT if pp.size() else D.C_MUTE)
	place(bi, serve_btn.size.x - 40, 14)
	bi.mouse_filter = Control.MOUSE_FILTER_IGNORE
	serve_btn.add_child(bi)
	serve_btn.tooltip_text = "패스" if names.is_empty() else "\n".join(names)


func work_go() -> void:
	if busy or W.is_empty(): return
	var a := D.app_by_id(W.area)
	var st: Dictionary = g.apps[a.id]
	var its := _picks()
	var st_node: Station = stations[a.id]
	var to := st_node.global_position + st_node.size / 2
	var k := 0
	for it in its:
		if item_cards.has(it.uid):
			var c: Control = item_cards[it.uid]
			fly(it.id, c.global_position + c.size / 2, to, k * 0.05)
			k += 1
	if st.s != null and st.s.T > 0:
		g.add_to_session(a.id, its)
	else:
		var join: bool = st.s != null
		g.start_session(a.id, W.method, W.lv, W.T, its.is_empty(), join, its, _wvk())
	W = {}
	sfx("door" if a.kind in ["oven", "micro", "chill"] else "click")
	render_all()
	act(10, a.ic)


# ---------- 렌더 ----------
func render_all() -> void:
	if g == null or not is_instance_valid(board): return
	update_clock()
	render_counter()
	if is_instance_valid(tray_btn): tray_btn.queue_redraw()
	render_pass()
	render_work()
	update_stations()
	render_top_btns()


func update_clock() -> void:
	var left := Game.LIMIT - g.now
	clock_lbl.text = D.fmt(left)
	var low := left <= 300
	clock_lbl.add_theme_color_override("font_color", Color("ff3b2f") if low else D.C_LCDTXT)
	if low: clock_lbl.modulate.a = 0.55 if fmod(t_now, 1.0) < 0.5 else 1.0
	else: clock_lbl.modulate.a = 1.0
	tbar_fill.size.x = 170.0 * left / Game.LIMIT


func render_top_btns() -> void:
	var ne := g.next_end()
	var d := busy or screen != "play"
	dis(w30, d); dis(w60, d)
	dis(wnext, d or ne == INF)
	set_btn(wnext, "next", "", "--:--" if ne == INF else D.fmt(ne - g.now))
	dis(serve_btn, d)
	dis(note_btn, d)


func state_icons(it: Dictionary) -> Array:
	var s := []
	if it.washed: s.append(["drop", "씻음"])
	if it.peeled: s.append(["peel", D.ING[it.id].peel[1]])
	if it.cracked: s.append(["egg", "풀어 둠"])
	if it.cut != "W": s.append(["c_" + it.cut, D.CUT[it.cut].n])
	if it.mashed: s.append(["mash", "으깸"])
	if it.battered: s.append(["batter", "튀김옷"])
	if it.blend >= 20: s.append(["blender", "갈았음"])
	if it.chill >= 480: s.append(["snow", "차가움"])
	if it.mar >= 600: s.append(["bowl", "재움"])
	return s


func _dish(it: Dictionary) -> String:
	if not it.heat.is_empty() or not it.cook.is_empty(): return "plate"
	if it.cut != "W" or it.peeled or it.cracked or it.battered or it.mashed or not it.seas.is_empty() or float(it.mar) > 0 or float(it.blend) > 0:
		return "prep_bowl"
	return ""


func _draw_token(b: Button, it: Dictionary) -> void:
	var sel: bool = (W.get("area", "") == "board" and W.get("uid", -1) == it.uid) or W.get("picks", []).has(it.uid)
	var hov := b.is_hovered() and it.where == null
	var c := Vector2(b.size.x / 2, 42)
	var dish := _dish(it)
	var on_board: bool = W.get("area", "") == "board" and W.get("uid", -1) == it.uid
	if dish != "" and not on_board:
		var tex := D.art(dish)
		var dw := 60.0 if dish == "plate" else 56.0
		var dh := dw * tex.get_size().y / tex.get_size().x
		var dc := Vector2(b.size.x / 2, 26)
		b.draw_set_transform(dc + Vector2(0, dh * 0.42), 0, Vector2(1, 0.3))
		b.draw_circle(Vector2.ZERO, dw * 0.42, Color(0.3, 0.18, 0.06, 0.18))
		b.draw_set_transform(Vector2.ZERO)
		b.draw_texture_rect(tex, Rect2(dc - Vector2(dw, dh) / 2, Vector2(dw, dh)), false, Color(1, 1, 1, 0.35 if it.where != null else 1.0))
		if sel:
			b.draw_arc(dc, dw * 0.55, 0, TAU, 40, D.C_ACCENT, 3.0, true)
		if hov and not sel:
			b.draw_style_box(_sb(Color(1, 1, 1, 0.3), Color(0, 0, 0, 0), 0, 12), Rect2(Vector2.ZERO, b.size))
		return
	# 그림자 / 선택 표시
	b.draw_set_transform(c, 0, Vector2(1, 0.32))
	if sel:
		b.draw_circle(Vector2.ZERO, 28, Color(D.C_ACCENT, 0.25))
		b.draw_arc(Vector2.ZERO, 28, 0, TAU, 40, D.C_ACCENT, 3.0, true)
	b.draw_circle(Vector2.ZERO, 18 if not (sel or hov) else 15, Color(0.3, 0.18, 0.06, 0.22))
	b.draw_set_transform(Vector2.ZERO)
	if hov and not sel:
		b.draw_style_box(_sb(Color(1, 1, 1, 0.3), Color(0, 0, 0, 0), 0, 12), Rect2(Vector2.ZERO, b.size))


func render_counter() -> void:
	clear(board)
	item_cards.clear()
	var cw := 64.0
	var chh := 72.0
	# 뒷줄 날재료, 앞줄 손질(유리 볼) / 익힘(접시). 손질 중인 재료는 도마 위
	var on_board: int = W.get("uid", -1) if W.get("area", "") == "board" else -1
	var rows := [[], []]
	var comp_rep := {}    # 덩어리 대표 uid -> 재료들
	for gr in _counter_groups():
		if gr.size() > 1:
			comp_rep[gr[0].uid] = gr
			rows[1].append(gr[0])
		elif gr[0].uid != on_board: rows[0 if _dish(gr[0]) == "" else 1].append(gr[0])
	var board_plates: Array = g.plates.filter(func(p): return not p.pass)
	var pos := {}
	for ri in 2:
		var n: int = rows[ri].size()
		var step := minf(cw + 2, (board.size.x - cw) / maxf(1, n - 1))
		for k in n:
			var key = rows[ri][k].get("plate", null)
			pos["p%d" % key if key != null else rows[ri][k].uid] = Vector2(k * step, ri * (board.size.y - chh))
	# 쟁반 위 접시: 3개까지 한 줄, 그 이상은 두 줄
	var tr_in: Rect2 = LAYOUT.tray
	var pn := board_plates.size()
	var prows := 1 if pn <= 3 else 2
	var pcols := maxi(1, int(ceil(float(pn) / prows)))
	var pw: float = 112.0 if pn == 1 else (86.0 if pn == 2 else 60.0)
	var ph := pw + 6.0
	for k in pn:
		var stepx := minf(pw, (tr_in.size.x - 16 - pw) / maxf(1, pcols - 1))
		var x0 := tr_in.position.x + (tr_in.size.x - (pw + stepx * (pcols - 1))) / 2.0
		var y0 := tr_in.position.y + (tr_in.size.y - 4 - ph * prows) / 2.0
		_plate_token(board_plates[k], Vector2(x0 + (k % pcols) * stepx, y0 + (k / pcols) * ph) - board.position, pw, ph)
	for u in comp_rep: _comp_token(comp_rep[u], pos[u], cw, chh)
	var bd: Rect2 = LAYOUT.board
	for i in g.items.size():
		var it: Dictionary = g.items[i]
		if it.where != null or it.plate != null: continue    # 기구 안이나 조립 접시에 있으면 거기서 보임
		if g.siblings(it).size() > 1: continue               # 덩어리는 따로 그린다
		var d := g.doneness(it)
		var sel: bool = (W.get("area", "") == "board" and W.get("uid", -1) == it.uid) or W.get("picks", []).has(it.uid)
		var away = it.where != null
		var b := Button.new()
		b.theme_type_variation = "Flat"
		b.focus_mode = Control.FOCUS_NONE
		b.mouse_default_cursor_shape = Control.CURSOR_ARROW if away else Control.CURSOR_POINTING_HAND
		var p: Vector2 = bd.get_center() - board.position - Vector2(cw, chh) / 2 if it.uid == on_board else pos[it.uid]
		place(b, p.x, p.y, cw, chh)
		b.pivot_offset = Vector2(cw, chh) / 2
		b.draw.connect(_draw_token.bind(b, it))
		b.mouse_entered.connect(b.queue_redraw)
		b.mouse_exited.connect(b.queue_redraw)
		var part_n: String = _group_name([it])
		var tip := "%s  %s" % [part_n, d.label]
		var lift := -4.0 if sel else 0.0
		var e := emo(it.id, 40)
		place(e, (cw - 40) / 2, 4 + lift, 40, 40)
		if away: e.modulate.a = 0.3
		b.add_child(e)
		var bar := panel(Color(0.4, 0.28, 0.12, 0.15), Color(0, 0, 0, 0), 0, 2)
		place(bar, cw / 2 - 16, 60, 32, 4)
		b.add_child(bar)
		var fill := panel(D.DCOL[d.cls], Color(0, 0, 0, 0), 0, 2)
		place(fill, 0, 0, 32.0 * D.DW[d.cls] / 100.0, 4)
		bar.add_child(fill)
		b.set_meta("fill", fill)
		var icons := state_icons(it)
		if it.seas.size(): icons.append(["shaker", " ".join(it.seas.map(func(x): return D.SEA[x].n))])
		var sh := vbox(1)
		place(sh, cw - 14, 2, 12, 46)
		for s in icons.slice(0, 3): sh.add_child(ico(s[0], 11, D.C_INK2))
		b.add_child(sh)
		if away:
			var wb := panel(D.C_ACCENT, Color(0, 0, 0, 0), 0, 11)
			place(wb, cw / 2 + 6, 26, 22, 22)
			var wi := ico(D.app_by_id(it.where).ic, 14, Color.WHITE)
			place(wi, 4, 4)
			wb.add_child(wi)
			b.add_child(wb)
			tip = "%s  %s" % [D.ING[it.id].n, D.app_by_id(it.where).n]
		b.tooltip_text = tip
		b.pressed.connect(open_item.bind(it.uid))
		board.add_child(b)
		item_cards[it.uid] = b


# 함께 조리한 덩어리: 그릇 하나에 재료가 함께 담겨 있다
func _comp_token(gr: Array, p: Vector2, cw: float, chh: float) -> void:
	var b := Button.new()
	b.theme_type_variation = "Flat"
	b.focus_mode = Control.FOCUS_NONE
	b.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
	place(b, p.x, p.y, cw, chh)
	var picked: bool = W.picks.has(gr[0].uid) if W.has("picks") else false
	var sel: bool = picked or (W.get("area", "") == "comp" and gr.any(func(o): return o.uid == W.get("uid", -1)))
	var tex_n := "bowl" if g.primary(gr[0]) in ["boil", "steam"] else "plate"
	b.draw.connect(func():
		var tex := D.art(tex_n)
		var dw := 62.0
		var dh := dw * tex.get_size().y / tex.get_size().x
		var dc := Vector2(cw / 2, 28)
		b.draw_set_transform(dc + Vector2(0, dh * 0.42), 0, Vector2(1, 0.3))
		b.draw_circle(Vector2.ZERO, dw * 0.42, Color(0.3, 0.18, 0.06, 0.2))
		b.draw_set_transform(Vector2.ZERO)
		b.draw_texture_rect(tex, Rect2(dc - Vector2(dw, dh) / 2, Vector2(dw, dh)), false)
		if sel: b.draw_arc(dc, dw * 0.55, 0, TAU, 40, D.C_ACCENT, 3.0, true)
		elif b.is_hovered(): b.draw_arc(dc, dw * 0.55, 0, TAU, 40, Color(D.C_ACCENT, 0.5), 2.0, true))
	b.mouse_entered.connect(b.queue_redraw)
	b.mouse_exited.connect(b.queue_redraw)
	var n := mini(4, gr.size())
	for k in n:
		var a := float(k) / n * TAU - 1.6
		var e := emo(gr[k].id, 24)
		var q := Vector2(cw / 2, 28) + Vector2(cos(a), sin(a)) * 11.0 - Vector2(12, 12)
		place(e, q.x, q.y, 24, 24)
		b.add_child(e)
	var bar := panel(Color(0.4, 0.28, 0.12, 0.15), Color(0, 0, 0, 0), 0, 2)
	place(bar, cw / 2 - 16, 60, 32, 4)
	b.add_child(bar)
	var d := g.doneness(gr[0])
	var fill := panel(D.DCOL[d.cls], Color(0, 0, 0, 0), 0, 2)
	place(fill, 0, 0, 32.0 * D.DW[d.cls] / 100.0, 4)
	bar.add_child(fill)
	b.set_meta("fill", fill)
	b.set_meta("rep", gr[0].uid)
	b.tooltip_text = _group_name(gr)
	b.pressed.connect(open_item.bind(gr[0].uid))
	board.add_child(b)
	for o in gr: item_cards[o.uid] = b


func refresh_bars() -> void:
	for it in g.items:
		if not item_cards.has(it.uid): continue
		var b: Button = item_cards[it.uid]
		if b.has_meta("rep") and b.get_meta("rep") != it.uid: continue
		var d := g.doneness(it)
		var fill: Panel = b.get_meta("fill")
		fill.size.x = 32.0 * D.DW[d.cls] / 100.0
		fill.add_theme_stylebox_override("panel", _sb(D.DCOL[d.cls], Color(0, 0, 0, 0), 0, 2))


func _act_btn(icn: String, tip: String, t: String) -> Button:
	var b := Button.new()
	b.theme_type_variation = "Soft"
	b.focus_mode = Control.FOCUS_NONE
	b.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
	b.tooltip_text = "%s %s" % [tip, t]
	var v := vbox(1)
	v.alignment = BoxContainer.ALIGNMENT_CENTER
	v.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	var i := ico(icn, 24, D.C_INK); i.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	v.add_child(i)
	var l := lbl(t, 13, D.C_MUTE, D.F_NUM); l.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	v.add_child(l)
	b.custom_minimum_size = Vector2(56, 52)
	b.add_child(v)
	juice(b)
	return b


func update_stations() -> void:
	var d := busy or screen != "play"
	var area: String = W.get("area", "")
	sink.active = area == "sink"
	board_st.active = area == "board"
	board_st.queue_redraw()
	for a in D.APPS:
		var st: Station = stations[a.id]
		var ap: Dictionary = g.apps[a.id]
		var s = ap.s
		st.active = area == a.id
		st.running = s != null
		st.preheating = s != null and g.now < s.cookStart
		st.cooking = s != null and not st.preheating and s.T > 0
		st.vk = s.vk if s != null and s.vk != "" else (ap.hot if ap.hot != null else "")
		st.method = s.method if s != null else ""
		st.lv = s.lv if s != null else ""
		var ids := []
		var sauce := false
		if s != null:
			for u in s.items:
				var it = g.get_item(u)
				if it != null:
					ids.append(it.id)
					if it.seas.size(): sauce = true
		st.item_ids = ids
		st.sauce = sauce
		var stt := ""
		var pct := 0.0
		var tt := ""
		if s != null:
			if st.preheating:
				stt = D.vk_pre_n(s.vk)
				pct = (g.now - s.start) / maxf(1, s.cookStart - s.start)
				tt = D.fmt(s.cookStart - g.now)
			else:
				stt = D.METH[s.method].n
				pct = (g.now - s.cookStart) / maxf(1, s.T)
				tt = D.fmt(s.end - g.now)
			if s.T == 0 and not st.preheating: stt = "예열 완료"
		elif ap.hot != null:
			stt = "예열됨"
		st.timer = tt
		st.pct = pct
		st.tooltip_text = a.n if stt == "" else "%s  %s" % [a.n, stt]
		st.mouse_default_cursor_shape = Control.CURSOR_ARROW if d else Control.CURSOR_POINTING_HAND
		st.queue_redraw()
	sink.queue_redraw()


# ---------- 시간이 걸리는 행동 ----------
func act(sec: float, icn: String, fn = null, opts: Dictionary = {}) -> void:
	if busy or g == null or g.over or screen != "play": return
	busy = true
	var start := g.now
	var end := minf(Game.LIMIT, start + sec)
	act_state = {"start": start, "end": end, "sec": sec, "t0": Time.get_ticks_msec(), "dur": clampf(250 + sec * 5, 300, 1300), "fn": fn, "icn": icn}
	busy_box.visible = true
	blocker.visible = true
	busy_ic.texture = D.icon(icn, 30)
	busy_ic.position.x = 88 if opts.has("emo") else 52
	busy_emo.visible = opts.has("emo")
	if opts.has("emo"): busy_emo.texture = D.emo(opts.emo)
	if opts.has("wash"):
		sink.washing = true
		sink.item_ids = opts.wash
	busy_box.modulate.a = 0
	busy_box.create_tween().tween_property(busy_box, "modulate:a", 1.0, 0.12)
	render_top_btns()
	update_stations()


func _step_act() -> void:
	var a = act_state
	var k := minf(1.0, float(Time.get_ticks_msec() - a.t0) / a.dur)
	g.sim_to(a.start + (a.end - a.start) * k)
	busy_t.text = D.fmt(a.end - g.now)
	if String(a.icn).begins_with("c_") or a.icn == "peel" or a.icn == "mash":
		busy_ic.rotation = sin(t_now * 22) * 0.45
	elif a.icn == "clock":
		busy_ic.rotation = t_now * 6
	else:
		busy_ic.rotation = 0
		busy_ic.position.y = 31 + sin(t_now * 14) * 3
	update_clock()
	update_stations()
	refresh_bars()
	drain_events()
	if k >= 1.0:
		act_state = null
		busy_box.visible = false
		blocker.visible = false
		busy = false
		busy_ic.rotation = 0
		sink.washing = false
		sink.item_ids = []
		if a.fn != null and g.now >= a.start + a.sec - 0.01: a.fn.call()
		render_all()
		if g.now >= Game.LIMIT: time_over()


func drain_events() -> void:
	for e in g.events:
		match e.k:
			"done":
				toast(e.text, true)
				sfx("ding")
				if stations.has(e.aid): stations[e.aid].flash()
			"boom":
				sfx("boom")
				if stations.has(e.aid): stations[e.aid].flash(); stations[e.aid].shake = 2.0
	g.events.clear()


func _wait_next() -> void:
	var t := g.next_end()
	if t < INF: act(ceil(t - g.now), "clock")


func do_prep(u: int, k: String) -> void:
	var it = g.get_item(u)
	if it == null or it.where != null: return
	var p = null
	for x in g.prep_list(it):
		if x.k == k: p = x
	if p == null: return
	sfx("water" if k == "wash" else "chop")
	var opts := {"emo": it.id}
	if k == "wash": opts = {"wash": [it.id]}
	act(p.t, p.icn, func(): g.apply_prep(it, k), opts)


func do_cut(u: int, c: String) -> void:
	var it = g.get_item(u)
	if it == null or it.where != null: return
	var p = null
	for x in g.cut_list(it):
		if x.k == c: p = x
	if p == null: return
	sfx("chop")
	act(p.t, "c_" + c, func(): it.cut = c, {"emo": it.id})


func do_season(u: int, s: String) -> void:
	var it = g.get_item(u)
	if it == null or it.where != null or it.seas.has(s) or it.seas.size() >= 3: return
	sfx("click")
	var fn := func():
		if not it.seas.has(s): it.seas.append(s)
	act(15, "shaker", fn, {"emo": it.id})


func fly(id: String, from: Vector2, to: Vector2, delay: float = 0.0) -> void:
	var e := emo(id, 40)
	e.position = from - Vector2(20, 20)
	e.pivot_offset = Vector2(20, 20)
	fx.add_child(e)
	var tw := e.create_tween()
	tw.tween_interval(delay)
	tw.set_parallel()
	tw.tween_property(e, "position", to - Vector2(20, 20), 0.38).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN_OUT)
	tw.tween_property(e, "scale", Vector2(1.3, 1.3), 0.19).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_OUT)
	tw.tween_property(e, "scale", Vector2(0.7, 0.7), 0.19).set_delay(0.19)
	tw.set_parallel(false)
	tw.tween_callback(e.queue_free)


func toast(text: String, hl: bool = false) -> void:
	var p := panel(D.C_ACCENT if hl else D.C_INK, Color(0, 0, 0, 0), 0, 4)
	var r := rich(text, 16, D.C_PAPER if not hl else Color.WHITE)
	r.add_theme_font_override("normal_font", D.F_BL)
	place(r, 16, 8, 600, 26)
	p.add_child(r)
	fx.add_child(p)
	await get_tree().process_frame
	if not is_instance_valid(p): return
	var w := r.get_content_width() + 32
	p.size = Vector2(w, 42)
	var cx := FLOOR.get_center().x if screen != "title" else 640.0
	var y0 := 378 + toast_y * 48
	toast_y = (toast_y + 1) % 3
	p.position = Vector2(cx - w / 2, y0 - 14)
	p.modulate.a = 0
	var tw := p.create_tween()
	tw.set_parallel()
	tw.tween_property(p, "position:y", float(y0), 0.22).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	tw.tween_property(p, "modulate:a", 1.0, 0.15)
	tw.set_parallel(false)
	tw.tween_interval(1.6)
	tw.tween_property(p, "modulate:a", 0.0, 0.3)
	tw.tween_callback(p.queue_free)


# =====================================================================
# 모달
# =====================================================================
func open_ov(content: Control) -> void:
	clear(ov)
	var dim := ColorRect.new(); dim.color = Color(D.C_INK, 0.55); dim.size = Vector2(1280, 720)
	ov.add_child(dim)
	ov.add_child(content)
	ov.visible = true
	var center := func():
		content.position = ((Vector2(1280, 720) - content.size) / 2).round()
		content.pivot_offset = content.size / 2
	content.resized.connect(center)
	center.call()
	content.modulate.a = 0.0
	content.create_tween().tween_property(content, "modulate:a", 1.0, 0.1)


func close_ov() -> void:
	clear(ov)
	ov.visible = false
	modal_kind = ""


func mod_panel(w: float, h: float) -> Panel:
	var p := Panel.new()
	var s := _sb(D.C_CARD, Color(0, 0, 0, 0), 0, 18)
	s.shadow_color = Color(0, 0, 0, 0.3); s.shadow_size = 28; s.shadow_offset = Vector2(0, 10)
	p.add_theme_stylebox_override("panel", s)
	p.size = Vector2(w, h)
	return p


func opt_btn(icn_node: Control, text: String, on: bool, tip: String = "", w: float = 80) -> Button:
	var b := Button.new()
	b.theme_type_variation = "OptOn" if on else "Opt"
	b.focus_mode = Control.FOCUS_NONE
	b.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
	b.custom_minimum_size = Vector2(w, 64)
	b.tooltip_text = tip
	var v := vbox(3)
	v.alignment = BoxContainer.ALIGNMENT_CENTER
	v.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	if icn_node:
		icn_node.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
		icn_node.modulate = D.C_ACCENT2 if on else D.C_INK
		v.add_child(icn_node)
	if text != "":
		var l := lbl(text, 13, D.C_ACCENT2 if on else D.C_INK, D.F_XB); l.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		v.add_child(l)
	b.add_child(v)
	juice(b)
	return b


# ---------- 조리 기구에 넣기 ----------
func mod_box(w: float, sep: int) -> Array:
	var p := PanelContainer.new()
	var s := _sb(D.C_CARD, Color(0, 0, 0, 0), 0, 18)
	s.shadow_color = Color(0, 0, 0, 0.3); s.shadow_size = 28; s.shadow_offset = Vector2(0, 10)
	s.content_margin_left = 24; s.content_margin_right = 24; s.content_margin_top = 20; s.content_margin_bottom = 22
	p.add_theme_stylebox_override("panel", s)
	p.custom_minimum_size = Vector2(w, 0)
	var v := vbox(sep)
	p.add_child(v)
	return [p, v]


func _rl(c: Control) -> Control:
	var w := CenterContainer.new()
	w.custom_minimum_size = Vector2(40, 40)
	w.mouse_filter = Control.MOUSE_FILTER_IGNORE
	w.add_child(c)
	return w


func _minfo() -> Panel:
	var p := panel(Color(0, 0, 0, 0))
	p.custom_minimum_size = Vector2(0, 32)
	var h := hbox(8)
	h.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	h.offset_left = 12
	p.add_child(h)
	return p


func close_modal() -> void:
	close_ov()
	M = null
	screen = "play"
	render_all()


func take_back(aid: String) -> void:
	if busy or screen != "play": return
	var a := D.app_by_id(aid)
	var st: Dictionary = g.apps[aid]
	if st.s == null: return
	var its: Array = st.s.items.duplicate()
	g.finish_session(a, true)
	g.events.clear()
	if a.kind in ["oven", "micro", "chill"]: sfx("door")
	render_all()
	var st_node: Station = stations[aid]
	var from := st_node.global_position + st_node.size / 2
	for u in its:
		if item_cards.has(u):
			var c: Control = item_cards[u]
			fly(g.get_item(u).id, from, c.global_position + c.size / 2)
	act(10, "out")


# ---------- 레시피 노트 ----------
func open_note() -> void:
	if busy or (screen != "play" and screen != "pick"): return
	var back := screen
	var p := mod_panel(1220, 690)
	var h := hbox(10)
	place(h, 24, 16, 1172, 40)
	h.add_child(ico("book", 28, D.C_INK))
	h.add_child(lbl("레시피 노트", 24, D.C_INK, D.F_BL))
	p.add_child(h)
	var half := int(ceil(g.fridge.size() / 2.0))
	for col in 2:
		var v := vbox(0)
		place(v, 24 + col * 594, 64, 578, 0)
		for ix in range(col * half, mini(g.fridge.size(), (col + 1) * half)):
			v.add_child(_note_row(g.fridge[ix]))
		p.add_child(v)
	var lg := hbox(8)
	place(lg, 24, 640, 900, 30)
	for x in [[1, "x0.6", "약불 0.6배"], [2, "x1", "중불, 오븐 200° 기준"], [3, "x1.5", "강불 1.5배"]]:
		var fl := []
		for q in x[0]: fl.append(ico("flame", 14, D.C_MUTE))
		lg.add_child(_chip(fl, x[1], D.C_MUTE, x[2]))
	lg.add_child(_chip([ico("c_M", 18, D.C_MUTE)], "", D.C_MUTE, "잘게 썰수록 빨리 익음"))
	p.add_child(lg)
	var cb := btn("x", "", "", "Ghost", Vector2(44, 44), 18)
	cb.tooltip_text = "닫기 Esc"
	place(cb, 1220 - 24 - cb.size.x, 632)
	cb.pressed.connect(func(): close_ov(); screen = back)
	p.add_child(cb)
	screen = "modal"
	modal_kind = "note:" + back
	open_ov(p)


func _note_row(id: String) -> Control:
	var gi: Dictionary = D.ING[id]
	var row := Panel.new()
	row.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var st := _sb(Color(0, 0, 0, 0), D.C_LINE, 0, 0); st.border_width_bottom = 2
	row.add_theme_stylebox_override("panel", st)
	row.custom_minimum_size = Vector2(578, 60)
	var h := hbox(8)
	place(h, 4, 0, 574, 60)
	h.add_child(emo(id, 32))
	var nl := lbl(gi.n, 16, D.C_INK, D.F_BL); nl.custom_minimum_size = Vector2(108, 0)
	h.add_child(nl)
	var pp := hbox(4); pp.custom_minimum_size = Vector2(52, 0)
	if gi.has("wash"): pp.add_child(_tipico("drop", "씻기"))
	if gi.has("peel") and float(gi.peel[2]) < 0: pp.add_child(_tipico("peel", gi.peel[1]))
	if gi.has("crack"): pp.add_child(_tipico("egg", "깨서 풀기"))
	h.add_child(pp)
	var tab: Dictionary = gi.m.duplicate()
	if id == "egg":
		tab = gi.mc.duplicate(); tab.merge(gi.m, true)
	var ms := []
	for m in tab:
		if float(tab[m][0]) >= 2: ms.append([m, tab[m]])
	ms.sort_custom(func(x, y): return float(x[1][0]) > float(y[1][0]))
	if float(gi.raw) >= 2: h.add_child(_chip([ico("m_raw", 18, D.C_OK)], "생", D.C_OK, "생으로 가능"))
	for x in ms.slice(0, 3):
		var m: String = x[0]
		var d: Array = x[1]
		var icons: Array = [ico(D.METH[m].ic, 18, D.C_INK2)]
		if d[3] != "W": icons.append(ico("c_" + d[3], 16, D.C_INK2))
		h.add_child(_chip(icons, "%s~%s분" % [D.nf(d[1]), D.nf(d[2])], D.C_INK2, "%s %s %s" % [D.METH[m].n, D.REFLV[m], D.CUT[d[3]].n]))
	if id == "egg": h.add_child(_chip([ico("micro", 18, D.C_BAD), ico("warn", 16, D.C_BAD)], "", D.C_BAD, "껍질째 전자레인지 금지"))
	row.add_child(h)
	return row


func _tipico(n: String, tip: String, col: Color = D.C_INK2, sz: int = 20) -> TextureRect:
	var i := ico(n, sz, col)
	i.tooltip_text = tip
	i.mouse_filter = Control.MOUSE_FILTER_PASS
	return i


func _chip(icons: Array, text: String, col: Color, tip: String) -> Control:
	var p := Panel.new()
	p.add_theme_stylebox_override("panel", _sb(Color.WHITE, col, 2, 3))
	p.tooltip_text = tip
	p.mouse_filter = Control.MOUSE_FILTER_PASS
	var h := hbox(4)
	for i in icons: h.add_child(i)
	if text != "": h.add_child(lbl(text, 13, col, D.F_NUM))
	var w := h.get_combined_minimum_size().x + 14
	p.custom_minimum_size = Vector2(w, 30)
	p.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	place(h, 7, 0, w - 14, 30)
	p.add_child(h)
	return p


# ---------- 제출 ----------
func time_over() -> void:
	if g.over: return
	var groups := g.time_over_groups()
	g.events.clear()
	toast("시간 종료", true)
	sfx("buzz")
	serve(groups)


# =====================================================================
# 결과
# =====================================================================
var res_box: Control
var res_dish: Label
var res_sel := -1


func serve(groups: Array) -> void:
	if g.over and screen == "result": return
	var R := g.serve(groups)
	res_sel = -1
	screen = "result"
	modal_kind = "result"
	var res: Dictionary = R.res
	var p := mod_panel(1220, 680)
	# 왼쪽: 접시 (조립한 접시마다 따로)
	var pls: Array = R.plates
	var np := mini(3, pls.size())
	var pd: float = 250.0 if np == 1 else (170.0 if np == 2 else 118.0)
	var gap := 12.0
	var x0 := 195.0 - (pd * np + gap * (np - 1)) / 2.0
	var kk := 0
	for pi in np:
		var pits: Array = pls[pi].items
		var plate := Button.new()
		plate.theme_type_variation = "Flat"
		plate.focus_mode = Control.FOCUS_NONE
		place(plate, x0 + pi * (pd + gap), 24 + (250 - pd) / 2.0, pd, pd)
		var hr := pd / 2.0
		var this_i: int = pi
		plate.draw.connect(func():
			for k in 5: plate.draw_circle(Vector2(hr, hr + 4 + k), hr - 1 + k, Color(0.25, 0.17, 0.08, 0.05))
			plate.draw_circle(Vector2(hr, hr), hr - 1, Color("dcdedc"))
			plate.draw_circle(Vector2(hr, hr), hr - 3, Color.WHITE)
			plate.draw_circle(Vector2(hr, hr), hr * 0.83, D.C_LINE)
			plate.draw_circle(Vector2(hr, hr), hr * 0.82, Color("f8f8f6"))
			if res_sel == this_i: plate.draw_arc(Vector2(hr, hr), hr - 1, 0, TAU, 64, D.C_ACCENT, 3.0, true))
		plate.tooltip_text = pls[pi].name
		if pls.size() > 1:
			plate.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
			plate.pressed.connect(func():
				res_sel = -1 if res_sel == this_i else this_i
				sfx("click")
				for c in plate.get_parent().get_children():
					if c is Button: c.queue_redraw()
				_show_result_rows(R, false))
		p.add_child(plate)
		var n := mini(8, pits.size())
		var es: float = round(56.0 * pd / 250.0)
		for k in n:
			var ang := float(k) / n * TAU - 1.2
			var rr := hr * 0.43 if n > 1 else 0.0
			var e := emo(pits[k].id, int(es))
			e.mouse_filter = Control.MOUSE_FILTER_IGNORE
			var tp := Vector2(hr, hr) + Vector2(cos(ang), sin(ang)) * rr - Vector2(es, es) / 2
			e.position = tp - Vector2(0, 160)
			e.modulate.a = 0
			e.pivot_offset = Vector2(es, es) / 2
			plate.add_child(e)
			var tw := e.create_tween().set_parallel()
			tw.tween_property(e, "position", tp, 0.45).set_delay(0.15 + kk * 0.1).set_trans(Tween.TRANS_BOUNCE).set_ease(Tween.EASE_OUT)
			tw.tween_property(e, "modulate:a", 1.0, 0.15).set_delay(0.15 + kk * 0.1)
			kk += 1
	var dish := lbl(R.dish, 27, D.C_INK, D.F_BL)
	dish.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	dish.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	place(dish, 20, 282, 350, 70)
	dish.vertical_alignment = VERTICAL_ALIGNMENT_TOP
	p.add_child(dish)
	res_dish = dish
	var th := hbox(6)
	th.alignment = BoxContainer.ALIGNMENT_CENTER
	place(th, 20, 352, 350, 22)
	th.add_child(emo("theme%d" % g.theme_i, 20))
	th.add_child(lbl(g.theme.n, 14, D.C_MUTE))
	p.add_child(th)
	var sc := hbox(8)
	sc.alignment = BoxContainer.ALIGNMENT_CENTER
	place(sc, 20, 382, 350, 100)
	var q := lbl("0", 92, D.C_ACCENT, D.F_NUM)
	sc.add_child(q)
	if R.bonus:
		var bl := lbl("+%d" % R.bonus, 26, D.C_OK, D.F_NUM)
		bl.tooltip_text = "남은 시간 보너스"; bl.mouse_filter = Control.MOUSE_FILTER_PASS
		sc.add_child(bl)
	p.add_child(sc)
	var scl := hbox(16)
	scl.alignment = BoxContainer.ALIGNMENT_CENTER
	place(scl, 20, 484, 350, 22)
	scl.add_child(_tipico("bot", "완성도", D.C_MUTE, 16))
	scl.add_child(lbl(str(res.total), 14, D.C_MUTE, D.F_NUM))
	scl.add_child(_tipico("clock", "남은 시간", D.C_MUTE, 16))
	scl.add_child(lbl(D.fmt(R.remain), 14, D.C_MUTE, D.F_NUM))
	p.add_child(scl)
	var gp := panel(D.C_INK, D.C_INK, 0, 3)
	place(gp, 112, 520, 70, 70)
	var gl := lbl(Game.grade_of(res.total), 44, D.C_PAPER, D.F_BL)
	gl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	gl.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	gp.add_child(gl)
	gp.pivot_offset = Vector2(35, 35)
	gp.modulate.a = 0
	p.add_child(gp)
	# 오른쪽: 심사평
	var rx := 400.0
	var jd := hbox(12)
	place(jd, rx, 24, 790, 48)
	jd.add_child(ico("bot", 40, D.C_INK))
	jd.add_child(lbl(Game.judge_line(res.total), 22, D.C_INK, D.F_BL))
	p.add_child(jd)
	var jl := ColorRect.new(); jl.color = Color("c6c9c7"); place(jl, rx, 78, 790, 2); p.add_child(jl)
	res_box = Control.new()
	res_box.mouse_filter = Control.MOUSE_FILTER_IGNORE
	place(res_box, rx, 86, 790, 580)
	p.add_child(res_box)
	var rb := btn("trophy", "랭킹", "", "", Vector2(0, 50), 20)
	rb.tooltip_text = "Enter"
	place(rb, 198, 530)
	rb.pressed.connect(finish)
	p.add_child(rb)
	open_ov(p)
	# 연출: 점수 올라감, 막대 차오름, 등급 도장
	_show_result_rows(R, true)
	var tw := create_tween()
	tw.tween_method(func(v): q.text = str(int(v)), 0.0, float(res.total), 0.9).set_delay(0.3)
	tw.tween_callback(func():
		gp.scale = Vector2(2.4, 2.4); gp.modulate.a = 1.0; gp.rotation = -0.25
		var t2 := gp.create_tween().set_parallel()
		t2.tween_property(gp, "scale", Vector2.ONE, 0.22).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN)
		t2.tween_property(gp, "rotation", -0.06, 0.22)
		sfx("thud"))
	if res.total >= 80: sfx("fanfare")
	elif res.total < 50: sfx("sad")
	else: sfx("ding")
	result_at = Time.get_ticks_msec()


# 오른쪽 심사평. res_sel이 -1이면 전체, 아니면 그 접시.
func _show_result_rows(R: Dictionary, animate: bool) -> void:
	clear(res_box)
	var cats: Array = R.res.cats
	res_dish.text = R.dish
	if res_sel >= 0:
		var pl: Dictionary = R.plates[res_sel]
		res_dish.text = pl.name
		cats = pl.res.cats.duplicate()
		if not R.res.get("leftover", {}).is_empty(): cats.append(R.res.leftover)
	var cy := 0.0
	for c in cats:
		var row := Control.new()
		row.mouse_filter = Control.MOUSE_FILTER_IGNORE
		place(row, 0, cy, 790, 0)
		var cn := lbl(c.n, 16, D.C_INK if c.max else D.C_BAD, D.F_BL)
		place(cn, 0, 4, 96, 24)
		row.add_child(cn)
		var cs := lbl("%d" % c.sc, 18, D.C_INK if c.max else D.C_BAD, D.F_NUM)
		cs.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
		place(cs, 700, 4, 50, 24)
		row.add_child(cs)
		var rh := 32.0
		if c.max:
			var mx := lbl("/%d" % c.max, 13, D.C_MUTE, D.F_NUM)
			place(mx, 752, 9, 40, 20)
			row.add_child(mx)
			var bb := panel(D.C_PAPER2, Color(0, 0, 0, 0), 0, 2)
			place(bb, 108, 10, 580, 12)
			row.add_child(bb)
			var ratio: float = float(c.sc) / float(c.max)
			var col := D.C_OK if ratio >= 0.8 else (D.C_WARN if ratio >= 0.5 else D.C_BAD)
			var bf := panel(col, Color(0, 0, 0, 0), 0, 2)
			place(bf, 0, 0, 0 if animate else 580 * ratio, 12)
			bb.add_child(bf)
			if animate:
				bf.create_tween().tween_property(bf, "size:x", 580 * ratio, 0.8).set_delay(0.35).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
			var notes: Array = c.notes.duplicate()
			notes.sort_custom(func(x, y): return x.pts < y.pts)
			for nt in notes.slice(0, 3):
				var rt := rich(nt.text, 14, D.C_INK2)
				place(rt, 108, rh, 560, 22)
				row.add_child(rt)
				var pt := lbl("+%d" % nt.pts if nt.pts > 0 else (str(nt.pts) if nt.pts < 0 else "✓"), 14, D.C_OK if nt.c == "g" else (D.C_WARN if nt.c == "m" else D.C_BAD), D.F_NUM)
				if nt.pts == 0: pt.text = ""; var ck := ico("check", 16, D.C_OK); place(ck, 734, rh + 3); row.add_child(ck)
				pt.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
				place(pt, 690, rh, 60, 22)
				row.add_child(pt)
				rh += 22
			rh += 6
		else:
			var wl := lbl(c.notes[0].text, 14, D.C_INK2, D.F_XB)
			wl.clip_text = true
			wl.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
			place(wl, 108, 4, 580, 24)
			row.add_child(wl)
		var sep := ColorRect.new(); sep.color = D.C_LINE; place(sep, 0, rh, 790, 2); row.add_child(sep)
		row.size.y = rh + 2
		res_box.add_child(row)
		cy += rh + 6


func finish() -> void:
	if screen != "result" or Time.get_ticks_msec() - result_at < 700: return
	close_ov()
	screen = "final"
	var R := g.result
	var rec := {"name": g.name, "score": R.score, "q": R.res.total, "bonus": R.bonus, "dish": R.dish, "theme": g.theme.n, "used": D.jround(g.now), "ts": int(Time.get_unix_time_from_system() * 1000)}
	var rr := add_record(rec)
	build_receipt(R, rr[0], rr[1])
	render_rank(final_rank, final_rank_h, rec.ts)
	show_scr("final")
	sfx("fanfare")
	final_at = Time.get_ticks_msec()
	final_left = 60
	auto_lbl.text = str(final_left)


# =====================================================================
# 마지막 화면
# =====================================================================
func build_final() -> void:
	var r: Control = scr.final
	rcpt = Panel.new()
	var rsb := _sb(D.C_CARD, Color(0, 0, 0, 0), 0, 18)
	rsb.shadow_color = Color(0.25, 0.17, 0.08, 0.15); rsb.shadow_size = 16; rsb.shadow_offset = Vector2(0, 6)
	rcpt.add_theme_stylebox_override("panel", rsb)
	place(rcpt, 64, 48, 520, 624)
	r.add_child(rcpt)
	final_rank_h = hbox(10)
	place(final_rank_h, 640, 48, 576, 40)
	r.add_child(final_rank_h)
	var ul := ColorRect.new(); ul.color = D.C_INK; place(ul, 640, 92, 576, 3); r.add_child(ul)
	final_rank = vbox(0)
	place(final_rank, 640, 96, 576, 440)
	r.add_child(final_rank)
	var ah := hbox(4)
	place(ah, 1140, 640, 76, 24)
	ah.alignment = BoxContainer.ALIGNMENT_END
	ah.add_child(ico("home", 14, D.C_MUTE))
	auto_lbl = lbl("60", 13, D.C_MUTE, D.F_NUM)
	ah.add_child(auto_lbl)
	ah.tooltip_text = "자동으로 처음 화면"
	r.add_child(ah)


func build_receipt(R: Dictionary, rank: int, total: int) -> void:
	clear(rcpt)
	var v := vbox(4)
	place(v, 26, 22, 468, 580)
	rcpt.add_child(v)
	var th := hbox(6)
	th.add_child(emo("theme%d" % g.theme_i, 20))
	th.add_child(lbl(g.theme.n, 15, D.C_MUTE))
	v.add_child(th)
	v.add_child(lbl(g.name, 34, D.C_INK, D.F_BL))
	var tot := lbl(str(R.score), 104, D.C_ACCENT, D.F_NUM)
	v.add_child(tot)
	v.add_child(lbl(Game.chef_title(R.score), 26, D.C_INK, D.F_BL))
	var rk := hbox(8)
	rk.add_child(ico("trophy", 22, D.C_INK))
	rk.add_child(lbl("%d위" % rank, 19, D.C_INK, D.F_BL))
	rk.add_child(lbl("/ %d" % total, 15, D.C_MUTE, D.F_NUM))
	v.add_child(rk)
	var er := hbox(4)
	er.custom_minimum_size = Vector2(0, 56)
	for it in R.items.slice(0, 10): er.add_child(emo(it.id, 40))
	v.add_child(er)
	var ln := ColorRect.new(); ln.color = D.C_LINE; ln.custom_minimum_size = Vector2(0, 2); v.add_child(ln)
	var dh := hbox(8)
	var dn := lbl(R.dish, 15, D.C_INK2); dn.size_flags_horizontal = Control.SIZE_EXPAND_FILL; dn.clip_text = true
	dh.add_child(dn)
	dh.add_child(lbl(str(R.res.total), 15, D.C_INK, D.F_NUM))
	v.add_child(dh)
	for row in [["ff", "시간 보너스", "+%d" % R.bonus], ["clock", "사용 시간", D.fmt(g.now)]]:
		var h := hbox(8)
		h.add_child(_tipico(row[0], row[1], D.C_INK2, 18))
		h.add_child(spacer())
		h.add_child(lbl(row[2], 15, D.C_INK, D.F_NUM))
		v.add_child(h)
	var fb := hbox(10)
	place(fb, 26, 624 - 26 - 50, 468, 50)
	var ag := btn("retry", "다시", "", "", Vector2(0, 50), 20)
	ag.tooltip_text = "Enter"
	ag.pressed.connect(again)
	fb.add_child(ag)
	var hm := btn("home", "처음", "", "Ghost", Vector2(0, 50), 20)
	hm.tooltip_text = "Esc"
	hm.pressed.connect(go_title)
	fb.add_child(hm)
	rcpt.add_child(fb)
	tot.pivot_offset = Vector2(0, 52)
	tot.scale = Vector2(0.6, 0.6)
	tot.create_tween().tween_property(tot, "scale", Vector2.ONE, 0.35).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)


func again() -> void:
	if screen != "final" or Time.get_ticks_msec() - final_at < 700: return
	name_in.text = g.name
	screen = "title"
	start_game()


# =====================================================================
# 매 프레임, 입력
# =====================================================================
var _sec_acc := 0.0


func _process(delta: float) -> void:
	t_now += delta
	if screen == "title" and belt:
		belt_off += delta * 40.0
		for e in belt_items:
			e.position.x -= delta * 40.0
			if e.position.x < -70: e.position.x += 16 * 96.0
		belt.queue_redraw()
	Sfx.ambient(_amb_want())
	if act_state != null: _step_act()
	elif screen == "play" or screen == "modal":
		if g != null and clock_lbl and is_instance_valid(clock_lbl) and Game.LIMIT - g.now <= 300: update_clock()
	if screen == "final":
		_sec_acc += delta
		if _sec_acc >= 1.0:
			_sec_acc -= 1.0
			final_left -= 1
			auto_lbl.text = str(maxi(0, final_left))
			if final_left <= 0: go_title()


# 주방에서 돌아가는 기기 소리
const AMB := {"grill": "sizzle", "stir": "sizzle", "fry": "fryer", "boil": "boil", "steam": "steam"}

func _amb_want() -> Dictionary:
	var w := {}
	if g == null or g.over or not scr.game.visible: return w
	for a in D.APPS:
		var s = g.apps[a.id].s
		if s == null: continue
		match a.kind:
			"stove":
				if g.now < s.cookStart or s.items.is_empty(): w.flame = true
				else: w[AMB.get(s.method, "flame")] = true
			"oven": w.oven = true
			"micro": w.micro = true
			"blend": w.blender = true
	return w


func _input(e: InputEvent) -> void:
	if not (e is InputEventKey) or not e.pressed or e.echo: return
	var k: int = e.keycode
	if k == KEY_F11:
		var m := DisplayServer.window_get_mode()
		DisplayServer.window_set_mode(DisplayServer.WINDOW_MODE_MAXIMIZED if m == DisplayServer.WINDOW_MODE_FULLSCREEN else DisplayServer.WINDOW_MODE_FULLSCREEN)
		get_viewport().set_input_as_handled()
		return
	var enter := k == KEY_ENTER or k == KEY_KP_ENTER
	match screen:
		"title":
			if k == KEY_ESCAPE and modal_kind == "": open_menu()
			elif k == KEY_F8 and modal_kind == "": confirm_clear()
			elif modal_kind == "clear":
				if enter: _do_clear()
				elif k == KEY_ESCAPE: close_ov()
			else: return
		"pick":
			if enter: begin_play()
			elif k == KEY_ESCAPE: open_menu()
			else: return
		"play":
			if k == KEY_ESCAPE and not busy:
				if not W.is_empty(): close_work()
				else: open_menu()
			else: return
		"modal":
			if k == KEY_ESCAPE:
				if modal_kind == "menu": close_menu()
				elif modal_kind == "load": close_modal()
				elif modal_kind.begins_with("note:"):
					var back := modal_kind.substr(5)
					close_ov(); screen = back
			else: return
		"result":
			if enter: finish()
			else: return
		"final":
			if enter: again()
			elif k == KEY_ESCAPE: go_title()
			else: return
		_:
			return
	get_viewport().set_input_as_handled()


func open_menu() -> void:
	if busy: return
	if screen == "modal" and modal_kind == "menu": return
	if screen == "title": name_in.release_focus()
	menu_back = screen
	screen = "modal"
	_draw_menu()


func _draw_menu() -> void:
	var pv := mod_box(380, 10)
	var p: PanelContainer = pv[0]
	var v: VBoxContainer = pv[1]
	var h := hbox(10)
	h.add_child(ico("menu", 26, D.C_INK))
	h.add_child(lbl("메뉴", 22, D.C_INK, D.F_BL))
	v.add_child(h)
	var add := func(icn: String, text: String, tip: String, fn: Callable, variant: String = "Soft"):
		var b := btn(icn, text, "", variant, Vector2(332, 48), 20)
		b.tooltip_text = tip
		b.pressed.connect(fn)
		v.add_child(b)
	add.call("play", "계속하기", "Esc", close_menu, "")
	add.call("mute" if Sfx.muted else "sound", "효과음 %s" % ("꺼짐" if Sfx.muted else "켜짐"), "", func():
		Sfx.muted = not Sfx.muted; _save_settings(); close_ov(); _draw_menu())
	add.call("music" if Sfx.music_on else "music_off", "배경음악 %s" % ("켜짐" if Sfx.music_on else "꺼짐"), "", func():
		Sfx.set_music(not Sfx.music_on); _save_settings(); close_ov(); _draw_menu())
	var fs := DisplayServer.window_get_mode() == DisplayServer.WINDOW_MODE_FULLSCREEN
	add.call("full", "전체 화면 %s" % ("켜짐" if fs else "꺼짐"), "F11", func():
		DisplayServer.window_set_mode(DisplayServer.WINDOW_MODE_MAXIMIZED if fs else DisplayServer.WINDOW_MODE_FULLSCREEN); close_ov(); _draw_menu())
	if menu_back == "play" or menu_back == "pick":
		add.call("home", "처음 화면", "이번 판 기록 안 됨", func(): close_ov(); W = {}; go_title())
	add.call("power", "게임 종료", "", func(): get_tree().quit())
	open_ov(p)
	modal_kind = "menu"


func close_menu() -> void:
	close_ov()
	screen = menu_back if menu_back != "" else "title"
	if screen == "title": name_in.grab_focus.call_deferred()
	if screen == "play": render_all()


func _save_settings() -> void:
	var c := ConfigFile.new()
	c.set_value("audio", "muted", Sfx.muted)
	c.set_value("audio", "music", Sfx.music_on)
	c.save(SET_PATH)


func _load_settings() -> void:
	var c := ConfigFile.new()
	if c.load(SET_PATH) == OK:
		Sfx.muted = bool(c.get_value("audio", "muted", false))
		Sfx.music_on = bool(c.get_value("audio", "music", true))
	Sfx.set_music(Sfx.music_on)


func confirm_clear() -> void:
	var pv := mod_box(460, 18)
	var p: PanelContainer = pv[0]
	var v: VBoxContainer = pv[1]
	var h := hbox(10)
	h.add_child(ico("trash", 26, D.C_BAD))
	h.add_child(lbl("랭킹 전체 삭제", 20, D.C_INK, D.F_BL))
	v.add_child(h)
	var hb := hbox(10)
	hb.add_child(spacer())
	var c := btn("x", "", "", "Ghost", Vector2(56, 46), 18)
	c.tooltip_text = "취소 Esc"
	c.pressed.connect(close_ov)
	hb.add_child(c)
	var ok := btn("trash", "지우기", "", "", Vector2(0, 46), 18)
	ok.tooltip_text = "Enter"
	ok.pressed.connect(_do_clear)
	hb.add_child(ok)
	v.add_child(hb)
	open_ov(p)
	modal_kind = "clear"
	name_in.release_focus()


func _do_clear() -> void:
	save_rank([])
	close_ov()
	render_rank(title_rank, title_rank_h)
	name_in.grab_focus()


# =====================================================================
# 스크린샷 자동 진행 (개발용: --shots)
# =====================================================================
func _shot(n: String, wait: float = 0.9) -> void:
	await get_tree().create_timer(wait).timeout
	var img := get_viewport().get_texture().get_image()
	var dir := OS.get_environment("SHOT_DIR")
	img.save_png("%s/%s.png" % [dir, n])
	print("SHOT ", n)


func _click(c: Control) -> void:
	if c is BaseButton: c.pressed.emit()


func autopilot() -> void:
	await get_tree().create_timer(0.5).timeout
	name_in.text = "테스터"
	await _shot("01_title")
	start_game()
	g = Game.new("테스터", 0)
	g.fridge = ["pork", "mince", "shrimp", "squid", "egg", "cheese", "kimchi", "onion", "greenonion", "chili", "potato", "mushroom", "apple", "lemon", "rice", "ramen", "tteok", "fishcake"]
	pk_icon.texture = D.emo("theme0"); pk_name.text = g.theme.n; pk_desc.text = g.theme.d
	render_pick(true)
	for id in ["kimchi", "pork", "onion", "greenonion", "rice", "tteok"]: toggle_pick(id)
	await _shot("02_pick")
	begin_play()
	await _shot("03_kitchen")
	# 손질 (도마 재료 클릭)
	open_item(g.items[1].uid)
	await _shot("04_selected")
	do_cut(g.items[1].uid, "B")
	await _shot("05_busy", 0.35)
	await get_tree().create_timer(1.5).timeout
	# 화구 1: 냄비 물 채우기, 김치 + 고기 끓이기
	open_area("s1")
	W.tool = "pot"; W.prep = "water"; W.method = "boil"
	W.picks = [g.items[0].uid, g.items[1].uid]
	render_all()
	await _shot("06_modal")
	work_go()
	await get_tree().create_timer(1.6).timeout
	# 화구 2: 웍 기름 예열
	open_area("s2")
	W.tool = "wok"; W.prep = "oil"; W.method = "stir"
	render_all()
	await _shot("06b_wok")
	work_go()
	await get_tree().create_timer(1.6).timeout
	# 전자레인지: 즉석밥
	open_area("micro")
	W.picks = [g.items[4].uid]
	render_all()
	work_go()
	await get_tree().create_timer(1.6).timeout
	for step in [["s3", "steamer", "water", "steam", 2], ["s4", "fryer", "deep", "fry", -1], ["oven", "", "", "", 5], ["freeze", "", "", "", 3]]:
		open_area(step[0])
		if step[1] != "": W.tool = step[1]; W.prep = step[2]; W.method = step[3]
		W.picks = [g.items[step[4]].uid] if step[4] >= 0 else []
		render_all()
		work_go()
		await get_tree().create_timer(1.2).timeout
	act(120, "clock")
	await get_tree().create_timer(0.9).timeout
	await _shot("07_cooking")
	take_back("micro")
	await get_tree().create_timer(1.5).timeout
	await _shot("07b_taken")
	open_board()
	await _shot("07c_board")
	close_work()
	do_plate(g.items[4].uid, -1)
	await get_tree().create_timer(1.2).timeout
	await _shot("07d_plate")
	close_work()
	open_menu()
	await _shot("07e_menu")
	close_menu()
	open_note()
	await _shot("08_note")
	close_ov(); screen = "play"
	_wait_next()
	await get_tree().create_timer(2.0).timeout
	_wait_next()
	await get_tree().create_timer(2.0).timeout
	_wait_next()
	await get_tree().create_timer(2.0).timeout
	# 김치와 돼지고기를 한 냄비에: 덩어리째 밥 접시로
	await _shot("08b_comp")
	open_tray()
	await _shot("08b2_tray")
	close_work()
	open_item(g.items[0].uid)
	await _shot("08c_comp_panel")
	do_plate(g.items[0].uid, g.plates[0].pid)
	await get_tree().create_timer(1.2).timeout
	await _shot("08d_assembled")
	print("DISH ", g.dish_info(g.plate_items(g.plates[0])).name)
	var tt = g.items.filter(func(i): return i.id == "tteok")[0]
	if tt.where != null:
		take_back(tt.where)
		await get_tree().create_timer(1.2).timeout
	do_plate(tt.uid, -1)
	await get_tree().create_timer(1.2).timeout
	close_work()
	for pl in g.plates.duplicate():
		send_plate(pl.pid)
		await get_tree().create_timer(1.2).timeout
	await _shot("09_pass")
	ring_bell()
	await get_tree().create_timer(3.5).timeout
	await _shot("10_result")
	var plate_btn: Button = null
	for c in ov.get_children():
		for c2 in c.get_children():
			if c2 is Button and c2.tooltip_text != "" and plate_btn == null and c2.tooltip_text != "Enter": plate_btn = c2
	if plate_btn != null:
		plate_btn.pressed.emit()
		await _shot("10b_plate")
	result_at = 0
	finish()
	await _shot("11_final")
	print("RANK FILE ", ProjectSettings.globalize_path(RANK_PATH), " ", FileAccess.file_exists(RANK_PATH))
	get_tree().quit()
