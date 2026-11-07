extends SceneTree
# 즉석밥 그림 (상표 없는 흰 원형 용기, 열린 뚜껑, 쌀밥). 다시 만들 때:
#   Godot --headless --script tools/gen_rice_icon.gd -- game/emoji/rice.png

func _init() -> void:
	var out: String = OS.get_cmdline_user_args()[0]
	var rng := RandomNumberGenerator.new()
	rng.seed = 2026
	var grains := ""
	for i in 300:
		var a := rng.randf_range(0.0, TAU)
		var r := sqrt(rng.randf())
		var x := 62.0 + cos(a) * r * 42.0
		var y := 66.0 + sin(a) * r * 19.0 - (1.0 - r * r) * 9.0
		var c := "#ffffff" if i % 3 else "#f7f4e8"
		grains += '<ellipse cx="%.1f" cy="%.1f" rx="4.2" ry="2.2" transform="rotate(%.0f %.1f %.1f)" fill="%s" stroke="#dcd9c8" stroke-width="0.5"/>' % [x, y, rng.randf_range(0.0, 180.0), x, y, c]
	var flutes := ""
	for i in 9:
		var x0 := 16.0 + i * 12.0
		var x1 := 32.0 + i * 8.0
		flutes += '<path d="M%.1f 80 L%.1f 112" stroke="#c9ccc4" stroke-width="1.4"/>' % [x0, x1]
	var svg := """<svg xmlns="http://www.w3.org/2000/svg" width="128" height="128" viewBox="0 0 128 128">
<defs><linearGradient id="side" x1="0" y1="0" x2="1" y2="0"><stop offset="0" stop-color="#cfd2ca"/><stop offset="0.35" stop-color="#fbfbf6"/><stop offset="1" stop-color="#c4c7bf"/></linearGradient></defs>
<g transform="rotate(32 92 44)">
<ellipse cx="94" cy="30" rx="24" ry="27" fill="#dfe8ea" fill-opacity="0.85" stroke="#9fb0b5" stroke-width="2"/>
<ellipse cx="94" cy="30" rx="17" ry="20" fill="#f4f8f8" fill-opacity="0.8"/>
</g>
<path d="M8 66 Q14 100 32 116 Q62 124 94 116 Q112 100 118 66 Z" fill="url(#side)" stroke="#a5a99f" stroke-width="2"/>
<g>%s</g>
<ellipse cx="63" cy="66" rx="57" ry="30" fill="#fdfdf9" stroke="#a5a99f" stroke-width="2.5"/>
<ellipse cx="63" cy="66" rx="48" ry="23" fill="#f4f3e8" stroke="#bcbfb5" stroke-width="1.5"/>
<g>%s</g>
</svg>""" % [flutes, grains]
	var img := Image.new()
	var err := img.load_svg_from_string(svg, 1.0)
	if err != OK:
		push_error("svg %d" % err)
		quit(1)
		return
	print("saved ", img.get_width(), "x", img.get_height(), " ", img.save_png(out))
	quit()
