extends SceneTree
# 탁상 벨 그림. 금색 돔, 위쪽 꼭지, 나무 받침. 다시 만들 때:
#   Godot --headless --script tools/gen_bell_art.gd -- game/art/bell.png

const SVG := """<svg xmlns="http://www.w3.org/2000/svg" width="256" height="256" viewBox="0 0 256 256">
<defs>
<linearGradient id="gold" x1="0" y1="0" x2="1" y2="0">
<stop offset="0" stop-color="#8a5a12"/><stop offset="0.18" stop-color="#e2ac3a"/><stop offset="0.36" stop-color="#fff0b4"/>
<stop offset="0.55" stop-color="#e9b744"/><stop offset="0.82" stop-color="#b57e1e"/><stop offset="1" stop-color="#6e4610"/>
</linearGradient>
<linearGradient id="band" x1="0" y1="0" x2="1" y2="0">
<stop offset="0" stop-color="#7a4f12"/><stop offset="0.3" stop-color="#ffe9a0"/><stop offset="0.6" stop-color="#d9a233"/><stop offset="1" stop-color="#5f3c0d"/>
</linearGradient>
<linearGradient id="wood" x1="0" y1="0" x2="1" y2="0">
<stop offset="0" stop-color="#2f1a0d"/><stop offset="0.3" stop-color="#7a4a26"/><stop offset="0.65" stop-color="#55311a"/><stop offset="1" stop-color="#26140a"/>
</linearGradient>
<linearGradient id="knob" x1="0" y1="0" x2="1" y2="0">
<stop offset="0" stop-color="#7a4f12"/><stop offset="0.4" stop-color="#fff3c4"/><stop offset="1" stop-color="#8d5f16"/>
</linearGradient>
</defs>
<ellipse cx="128" cy="222" rx="112" ry="20" fill="#2a1a0c" fill-opacity="0.28"/>
<path d="M18 186 Q18 170 40 164 L216 164 Q238 170 238 186 L238 196 Q238 222 128 222 Q18 222 18 196 Z" fill="url(#wood)"/>
<ellipse cx="128" cy="184" rx="110" ry="30" fill="#6b3f20"/>
<ellipse cx="128" cy="180" rx="92" ry="23" fill="#2a170b"/>
<path d="M34 170 Q34 66 128 62 Q222 66 222 170 Q222 196 128 196 Q34 196 34 170 Z" fill="url(#gold)"/>
<path d="M32 164 Q32 150 44 146 Q128 176 212 146 Q224 150 224 164 Q224 200 128 200 Q32 200 32 164 Z" fill="url(#band)"/>
<path d="M44 146 Q128 176 212 146" fill="none" stroke="#6e4610" stroke-opacity="0.55" stroke-width="2.5"/>
<path d="M62 132 Q62 88 104 76 Q80 96 76 138 Z" fill="#fffbe6" fill-opacity="0.8"/>
<ellipse cx="164" cy="104" rx="14" ry="8" transform="rotate(35 164 104)" fill="#fff6d0" fill-opacity="0.55"/>
<path d="M112 66 Q112 58 118 56 L138 56 Q144 58 144 66 Z" fill="url(#band)"/>
<rect x="120" y="36" width="16" height="22" rx="4" fill="url(#knob)"/>
<ellipse cx="128" cy="33" rx="21" ry="9" fill="url(#knob)"/>
<ellipse cx="122" cy="30" rx="8" ry="3" fill="#fffbe6" fill-opacity="0.85"/>
</svg>"""


func _init() -> void:
	var out: String = OS.get_cmdline_user_args()[0]
	var img := Image.new()
	var err := img.load_svg_from_string(SVG, 1.0)
	if err != OK:
		push_error("svg %d" % err)
		quit(1)
		return
	print("saved ", img.get_width(), "x", img.get_height(), " ", img.save_png(out))
	quit()
