extends SceneTree
# 즉석밥 그림 (상표 없는 흰 용기 + 벗겨진 필름). 다시 만들 때:
#   Godot --headless --script tools/gen_rice_icon.gd -- game/emoji/rice.png

func _init() -> void:
	var out: String = OS.get_cmdline_user_args()[0]
	var rng := RandomNumberGenerator.new()
	rng.seed = 2026
	var grains := ""
	for i in 150:
		var x := rng.randf_range(27.0, 101.0)
		var y := rng.randf_range(35.0, 93.0)
		var a := rng.randf_range(0.0, 180.0)
		var c := "#ffffff" if i % 3 else "#f6f5ee"
		grains += '<ellipse cx="%.1f" cy="%.1f" rx="5.2" ry="2.5" transform="rotate(%.0f %.1f %.1f)" fill="%s" stroke="#c4c6ba" stroke-width="0.8"/>' % [x, y, a, x, y, c]
	var svg := """<svg xmlns="http://www.w3.org/2000/svg" width="128" height="128" viewBox="0 0 128 128">
<rect x="12" y="30" width="104" height="88" rx="15" fill="#a4adaa"/>
<rect x="12" y="30" width="104" height="80" rx="15" fill="#cdd3d0"/>
<rect x="7" y="17" width="114" height="90" rx="18" fill="#fbfcfb" stroke="#7f8a86" stroke-width="3"/>
<rect x="19" y="27" width="90" height="70" rx="12" fill="#d8d9cc" stroke="#a9afa9" stroke-width="2"/>
<clipPath id="well"><rect x="20" y="28" width="88" height="68" rx="11"/></clipPath>
<g clip-path="url(#well)">%s</g>
<path d="M58 17 L103 17 Q121 17 121 35 L121 66 Z" fill="#8fbcd8" fill-opacity="0.72" stroke="#5f8aa6" stroke-width="1.5"/>
<path d="M72 21 L112 53" stroke="#ffffff" stroke-opacity="0.9" stroke-width="3" stroke-linecap="round"/>
<path d="M58 17 L121 66 L107 74 L47 26 Z" fill="#c6dfee" stroke="#5f8aa6" stroke-width="1.5"/>
<path d="M55 25 L106 67" stroke="#ffffff" stroke-width="2.5" stroke-linecap="round"/>
</svg>""" % grains
	var img := Image.new()
	var err := img.load_svg_from_string(svg, 1.0)
	if err != OK:
		push_error("svg %d" % err)
		quit(1)
		return
	print("saved ", img.get_width(), "x", img.get_height(), " ", img.save_png(out))
	quit()
