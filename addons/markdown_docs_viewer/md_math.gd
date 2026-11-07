@tool
extends Control
## Small offline TeX layout engine. Unsupported commands remain visible as source.
var source := ""
var font: Font
var italic: Font
var font_size := 20
var color := Color.WHITE
var error := ""
var _at := 0
var _depth := 0
var _box: Dictionary
const SYMBOLS := {"alpha":"α", "beta":"β", "gamma":"γ", "delta":"δ", "epsilon":"ε", "theta":"θ", "lambda":"λ", "mu":"μ", "pi":"π", "rho":"ρ", "sigma":"σ", "phi":"φ", "omega":"ω", "Gamma":"Γ", "Delta":"Δ", "Theta":"Θ", "Lambda":"Λ", "Sigma":"Σ", "Phi":"Φ", "Omega":"Ω", "infty":"∞", "times":"×", "cdot":"·", "pm":"±", "mp":"∓", "le":"≤", "leq":"≤", "ge":"≥", "geq":"≥", "ne":"≠", "neq":"≠", "approx":"≈", "equiv":"≡", "to":"→", "rightarrow":"→", "leftarrow":"←", "Rightarrow":"⇒", "in":"∈", "notin":"∉", "subset":"⊂", "subseteq":"⊆", "cup":"∪", "cap":"∩", "forall":"∀", "exists":"∃", "partial":"∂", "nabla":"∇", "sum":"∑", "prod":"∏", "int":"∫", "ldots":"…", "cdots":"⋯", "sin":"sin", "cos":"cos", "tan":"tan", "log":"log", "ln":"ln", "lim":"lim"}

func configure(value: String, normal: Font, slanted: Font, pixels: int, ink: Color) -> void:
	source = value
	font = normal
	italic = slanted
	font_size = pixels
	color = ink
	_at = 0
	_depth = 0
	error = ""
	_box = _sequence(pixels, false)
	if not error.is_empty(): _box = _text(source, pixels, false)
	custom_minimum_size = Vector2(_box.w + 24, _box.a + _box.d + 24)
	tooltip_text = source if error.is_empty() else error + "\n" + source
	queue_redraw()

func _text(value: String, pixels: int, slanted := true) -> Dictionary:
	var f := italic if slanted else font
	return {"w": f.get_string_size(value, HORIZONTAL_ALIGNMENT_LEFT, -1, pixels).x, "a": f.get_ascent(pixels), "d": f.get_descent(pixels), "ops": [{"text": value, "font": f, "size": pixels, "p": Vector2.ZERO}]}

func _place(target: Array, box: Dictionary, offset: Vector2) -> void:
	for op in box.ops:
		var shifted: Dictionary = op.duplicate()
		shifted.p += offset
		if shifted.has("end"): shifted.end += offset
		target.append(shifted)

func _sequence(pixels: int, group: bool) -> Dictionary:
	var result := {"w": 0.0, "a": 0.0, "d": 0.0, "ops": []}
	while _at < source.length():
		if source[_at] == "}":
			_at += 1
			if not group: error = "Unexpected closing brace"
			return result
		if source[_at] in [" ", "\n", "\t"]:
			_at += 1
			continue
		var atom := _atom(pixels)
		var sup: Dictionary = {}
		var sub: Dictionary = {}
		while _at < source.length() and source[_at] in ["^", "_", "'"]:
			var marker := source[_at]
			_at += 1
			var script := _text("′", maxi(9, roundi(pixels * 0.72)), false) if marker == "'" else _atom(maxi(9, roundi(pixels * 0.72)))
			if marker == "_": sub = script
			else:
				if not sup.is_empty():
					_place(sup.ops, script, Vector2(sup.w, 0))
					sup.w += script.w
				else: sup = script
		var extra := 0.0
		if not sup.is_empty():
			var dy: float = -pixels * 0.5
			_place(atom.ops, sup, Vector2(atom.w + 1, dy))
			atom.a = maxf(atom.a, sup.a - dy)
			extra = maxf(extra, sup.w + 1)
		if not sub.is_empty():
			var dy: float = pixels * 0.32
			_place(atom.ops, sub, Vector2(atom.w + 1, dy))
			atom.d = maxf(atom.d, sub.d + dy)
			extra = maxf(extra, sub.w + 1)
		atom.w += extra
		_place(result.ops, atom, Vector2(result.w, 0))
		result.w += atom.w
		result.a = maxf(result.a, atom.a)
		result.d = maxf(result.d, atom.d)
	if group: error = "Unclosed math group"
	return result

func _atom(pixels: int) -> Dictionary:
	while _at < source.length() and source[_at] in [" ", "\n", "\t"]: _at += 1
	if _at >= source.length():
		error = "Missing math argument"
		return _text("", pixels)
	var ch := source[_at]
	_at += 1
	if ch == "{":
		_depth += 1
		if _depth > 32:
			error = "Math nesting exceeds 32 levels"
			_at = source.length()
			return _text("", pixels)
		var group := _sequence(pixels, true)
		_depth -= 1
		return group
	if ch != "\\": return _text(ch, pixels, ch.to_lower() != ch.to_upper())
	var start := _at
	while _at < source.length() and source[_at].to_lower() != source[_at].to_upper(): _at += 1
	var command := source.substr(start, _at - start)
	if command.is_empty():
		if _at >= source.length(): return _text("", pixels)
		command = source[_at]
		_at += 1
		return _text(" " if command in [",", ";", " ", "!"] else command, pixels, false)
	if command in ["left", "right"]: return _atom(pixels)
	if command in ["quad", "qquad"]: return _text("  " if command == "quad" else "    ", pixels, false)
	if command in ["text", "mathrm", "operatorname"] and _at < source.length() and source[_at] == "{":
		var close := source.find("}", _at + 1)
		if close >= 0:
			var value := source.substr(_at + 1, close - _at - 1)
			_at = close + 1
			return _text(value, pixels, false)
	if command in ["frac", "dfrac", "tfrac"]:
		var numerator := _atom(maxi(9, roundi(pixels * 0.85)))
		var denominator := _atom(maxi(9, roundi(pixels * 0.85)))
		var width := maxf(numerator.w, denominator.w) + 8
		var axis := -pixels * 0.25
		var result := {"w": width + 4, "a": numerator.a + numerator.d + 4 - axis, "d": denominator.a + denominator.d + 4 + axis, "ops": []}
		_place(result.ops, numerator, Vector2((width - numerator.w) / 2, axis - 4 - numerator.d))
		_place(result.ops, denominator, Vector2((width - denominator.w) / 2, axis + 4 + denominator.a))
		result.ops.append({"p": Vector2(0, axis), "end": Vector2(width, axis)})
		return result
	if command == "sqrt":
		var body := _atom(pixels)
		var result := _text("√", pixels, false)
		var width: float = result.w
		_place(result.ops, body, Vector2(width, 0))
		result.ops.append({"p": Vector2(width, -body.a), "end": Vector2(width + body.w, -body.a)})
		result.w += body.w + 3
		result.a = maxf(result.a, body.a + 2)
		result.d = maxf(result.d, body.d)
		return result
	if SYMBOLS.has(command): return _text(SYMBOLS[command], pixels, false)
	error = "Unsupported TeX command: \\" + command
	return _text("\\" + command, pixels, false)

func _draw() -> void:
	if _box.is_empty(): return
	var origin := Vector2(maxf(12, (size.x - float(_box.w)) / 2), 12 + float(_box.a))
	for op in _box.ops:
		if op.has("text"): draw_string(op.font, origin + op.p, op.text, HORIZONTAL_ALIGNMENT_LEFT, -1, op.size, color)
		else: draw_line(origin + op.p, origin + op.end, color, 1.0, true)
