extends Node
# 게임 데이터 (data.json) + 공용 리소스 (아이콘, 이모지, 폰트, 색)

var P: Dictionary
var CUT: Dictionary
var TAGN: Dictionary
var CATN: Dictionary
var METH: Dictionary
var COOKM: Array
var REFLV: Dictionary
var ING: Dictionary
var SEA: Dictionary
var CONDI: Dictionary = {}
var THEMES: Array
var GOOD: Dictionary = {}
var BADX: Dictionary = {}
var APPS: Array
var KIND: Dictionary
var VESSEL: Dictionary
var VN: Dictionary
var PRE_N: Dictionary

var F_B: Font
var F_XB: Font
var F_BL: Font
var F_LCD: Font
var F_NUM: Font

const C_PAPER := Color("f2ede3")
const C_PAPER2 := Color("e8e1d3")
const C_CARD := Color("fbf8f2")
const C_INK := Color("1d1b18")
const C_INK2 := Color("3b3833")
const C_MUTE := Color("7d766b")
const C_LINE := Color("d3c9b8")
const C_ACCENT := Color("d9412a")
const C_ACCENT2 := Color("b5321f")
const C_OK := Color("2e7a47")
const C_WARN := Color("c98410")
const C_BAD := Color("c33a2c")
const C_LCD := Color("151412")
const C_LCDTXT := Color("ff6a3d")

const DCOL := {"raw": Color("9bb7c4"), "under2": Color("e9a0a0"), "under": Color("e8c36a"), "good": Color("2e7a47"), "over": Color("b06a2c"), "burnt": Color("2a2018")}
const DW := {"raw": 8, "under2": 30, "under": 60, "good": 100, "over": 80, "burnt": 100}

var _icons := {}
var _emo := {}


func _init() -> void:
	var txt := FileAccess.get_file_as_string("res://data/data.json")
	var J: Dictionary = JSON.parse_string(txt)
	P = J.P; CUT = J.CUT; TAGN = J.TAGN; CATN = J.CATN; METH = J.METH; COOKM = J.COOKM; REFLV = J.REFLV
	ING = J.ING; SEA = J.SEA; THEMES = J.THEMES; APPS = J.APPS; KIND = J.KIND; VESSEL = J.VESSEL; VN = J.VN; PRE_N = J.PRE_N
	for k in J.CONDI: CONDI[k] = true
	for k in J.GOOD: GOOD[k] = true
	for k in J.BADX: BADX[k] = true
	F_B = load("res://fonts/Pretendard-Bold.otf")
	F_XB = load("res://fonts/Pretendard-ExtraBold.otf")
	F_BL = load("res://fonts/Pretendard-Black.otf")
	F_LCD = load("res://fonts/DSEG7Classic-Bold.ttf")
	var fv := FontVariation.new()
	fv.base_font = F_XB
	fv.opentype_features = {"tnum": 1}
	F_NUM = fv


func pk(a: String, b: String) -> String:
	return a + "+" + b if a < b else b + "+" + a


func item(id: String) -> Dictionary:
	return ING[id] if ING.has(id) else SEA[id]


func tagv(it: Dictionary, k: String) -> float:
	if k == "prot": return float(it.get("prot", 0))
	return float(it.t.get(k, 0))


func fit_of(theme: Dictionary, it: Dictionary) -> float:
	var f := 0.0
	for k in theme.w: f += float(theme.w[k]) * tagv(it, k)
	return f


func is_sweet(it: Dictionary) -> bool:
	return float(it.t.get("sweet", 0)) >= 2 and float(it.t.get("dessert", 0)) >= 1


func is_savory(id: String, it: Dictionary) -> bool:
	return bool(it.get("prot", 0)) or CONDI.has(id) or float(it.t.get("spicy", 0)) >= 2 \
		or (float(it.t.get("korean", 0)) >= 2 and float(it.t.get("sweet", 0)) < 2)


func pair_type(a: String, b: String) -> int:
	var k := pk(a, b)
	if GOOD.has(k): return 1
	if BADX.has(k): return -1
	var A := item(a)
	var B := item(b)
	return -1 if (is_sweet(A) and is_savory(b, B)) or (is_sweet(B) and is_savory(a, A)) else 0


func app_by_id(aid: String) -> Dictionary:
	for a in APPS:
		if a.id == aid: return a
	return {}


func lv_factor(kind: String, lv: String) -> float:
	var L = KIND[kind].lv
	if L == null: return 1.0
	for x in L:
		if x[0] == lv: return float(x[2])
	return 1.0


func lv_name(kind: String, lv: String) -> String:
	var L = KIND[kind].lv
	if L == null: return ""
	for x in L:
		if x[0] == lv: return x[1]
	return ""


func preheat_sec(kind: String, method: String, lv: String) -> float:
	var v = VESSEL.get(method)
	if kind == "stove":
		var tb := {"pot": {"low": 540, "mid": 360, "high": 240}, "steamer": {"low": 540, "mid": 360, "high": 240},
			"fryer": {"low": 360, "mid": 240, "high": 180}, "pan": {"low": 60, "mid": 40, "high": 30}}
		return float(tb[v][lv])
	if kind == "oven": return 480.0
	return 0.0


# ---------- 화구 도구 ----------
const TOOL_ORDER := ["pan", "wok", "pot", "fryer", "steamer"]
const TOOLS := {"pan": ["프라이팬", ["none", "oil"]], "wok": ["웍", ["oil", "deep"]], "pot": ["냄비", ["water"]],
	"fryer": ["튀김 냄비", ["deep"]], "steamer": ["찜기", ["water"]]}
const PREPS := {"none": ["그대로", "pan"], "oil": ["기름 두르기", "oil"], "deep": ["기름 채우기", "oil"], "water": ["물 채우기", "drop"]}
const COMBO := {"pan/none": ["grill"], "pan/oil": ["grill", "stir"], "wok/oil": ["stir"], "wok/deep": ["fry"],
	"pot/water": ["boil"], "fryer/deep": ["fry"], "steamer/water": ["steam"]}


func vk_pre_n(vk: String) -> String:
	if vk.ends_with("/water"): return "물 끓이기"
	if vk.ends_with("/deep"): return "기름 예열"
	if vk.begins_with("pan") or vk.begins_with("wok"): return "팬 달구기"
	return "예열"


func vk_tool(vk: String) -> String:
	return vk.split("/")[0] if vk != "" else ""


func preheat_vk(kind: String, vk: String, lv: String) -> float:
	if kind == "stove":
		var tb := {"low": 60, "mid": 40, "high": 30}
		if vk.ends_with("/water"): tb = {"low": 540, "mid": 360, "high": 240}
		elif vk.ends_with("/deep"): tb = {"low": 360, "mid": 240, "high": 180}
		return float(tb[lv])
	if kind == "oven": return 480.0
	return 0.0


# ---------- 공용 포맷 ----------
static func fmt(s: float) -> String:
	var t := maxi(0, int(floor(s + 0.5)))
	return "%d:%02d" % [t / 60, t % 60]


static func nf(x) -> String:
	var f := float(x)
	if is_equal_approx(f, round(f)): return str(int(round(f)))
	return str(snappedf(f, 0.1))


static func jround(x: float) -> int:
	return int(floor(x + 0.5))


# ---------- 아이콘 (SVG 경로 -> 흰색 텍스처, modulate로 색 지정) ----------
func icon(name: String, size: int = 22, stroke: float = 1.9) -> Texture2D:
	var key := "%s_%d_%s" % [name, size, stroke]
	if _icons.has(key): return _icons[key]
	var px := size * 2
	var svg := '<svg xmlns="http://www.w3.org/2000/svg" viewBox="0 0 24 24" width="%d" height="%d" fill="none" stroke="#ffffff" stroke-width="%s" stroke-linecap="round" stroke-linejoin="round">%s</svg>' % [px, px, str(stroke), str(P.get(name, "")).replace("currentColor", "#ffffff")]
	var img := Image.new()
	img.load_svg_from_string(svg, 1.0)
	var tex := ImageTexture.create_from_image(img)
	_icons[key] = tex
	return tex


func emo(id: String) -> Texture2D:
	if _emo.has(id): return _emo[id]
	var t: Texture2D = load("res://emoji/%s.png" % id)
	_emo[id] = t
	return t


func emo_bb(id: String, size: int = 22) -> String:
	return "[img=%dx%d]res://emoji/%s.png[/img]" % [size, size, id]


var _art := {}

func art(n: String) -> Texture2D:
	if not _art.has(n): _art[n] = load("res://art/%s.png" % n)
	return _art[n]
