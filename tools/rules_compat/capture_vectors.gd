extends SceneTree

## The engine's answers for the native rules' engine-exact helpers
## (docs/native-rules-engine-transition.md, section 4 "Engine-exact helpers").
##
## Each helper runs on COUNT inputs drawn from a Park-Miller stream that
## rules_selftest draws the same way (selftest/compat_fuzz.cpp), and its answers
## are digested with SHA-256. The printed digests go into
## selftest/compat_digests.inc; rules_selftest computes them again from
## src/gdextension/rules/core/compat and must match on MSVC, GCC and MinGW.
##
##   godot --headless --path . -s tools/rules_compat/capture_vectors.gd [-- --count N]
##
## Keep this file and compat_fuzz.cpp in step: same draws, same order, same bytes.
## Special floats are built from their bits: GDScript parses long literals with
## Godot's own strtod, which is not correctly rounded, and folds the literal -0.0
## to +0.0.

const COUNT := 1 << 20
const INT64_MAX := 9223372036854775807
const INT64_MIN := -9223372036854775807 - 1
const CANONICAL_NAN_BITS := 0x7FF8000000000000
const HELPERS := ["pcg", "int_text", "string", "posmod", "int_div", "float_round", "snapped", "variant_minmax", "typed_minmax", "sort", "json_float", "json_parse"]
const STRING_CHARS := [0x61, 0x5A, 0x20, 0x0A, 0xE9, 0x3A9, 0x4E2D, 0x1F600]
const SOUP := ["{", "}", "[", "]", ":", ",", "\"k\"", "\"a\"", "1", "-", "2.5e3", "true", "false", "null", "nul", "True", " ", "\n", "\t", "\r", "x", ".5", "1e", "\""]
const WORDS := ["true", "false", "null", "nul", "True"]
const KEYS := ["a", "b", "id", "a", "items"]
const SEPARATORS := [",", ", ", ",\n", " , "]
const ESCAPES := ["\\b", "\\t", "\\n", "\\f", "\\r", "\\\"", "\\\\", "\\/"]
const BAD_ESCAPES := ["\\x", "\\u12G4", "\\"]
const CODE_POINTS := [0x2D, 0x2B, 0x2E, 0x20, 0x61, 0x5A, 0x5F, 0x09, 0xE9, 0x3A9, 0x4E2D, 0x1F600, 0x30, 0x2D]

var _state := 1
var _buffer := StreamPeerBuffer.new()
var _hashing: HashingContext
var _bytes := PackedByteArray()
var _float_specials := []
var _number_specials := []

func _init() -> void:
	var count := COUNT
	var args := OS.get_cmdline_user_args()
	for index in args.size():
		if args[index] == "--count" and index + 1 < args.size():
			count = int(args[index + 1])
	_bytes.resize(8)
	_build_specials()
	var started := Time.get_ticks_msec()
	for helper_index in HELPERS.size():
		var helper: String = HELPERS[helper_index]
		_begin(helper_index)
		call("_fuzz_" + helper, count)
		print("COMPAT %s %s" % [helper, _finish()])
	print("COMPAT count %d seconds %.1f" % [count, float(Time.get_ticks_msec() - started) / 1000.0])
	quit(0)

# --- the input stream (compat_fuzz.cpp: Fuzz) ---

func _build_specials() -> void:
	var negative_zero := _bits_to_float(INT64_MIN)
	var big := _bits_to_float(0x7E37E43C8800759C) # 1e300
	var tiny := _bits_to_float(0x01A56E1FC2F8F359) # 1e-300
	var two63 := _bits_to_float(0x43E0000000000000)
	_float_specials = [0.0, negative_zero, 0.5, -0.5, 1.5, -1.5, 2.5, INF, -INF, NAN, big, -tiny, two63, -two63,
		_bits_to_float(0x432FFFFFFFFFFFFF), _bits_to_float(0x3FDFFFFFFFFFFFFF)] # 2^52 - 0.5, 0.5 - 2^-54
	_number_specials = [0.0, negative_zero, NAN, INF, -INF, 0.5, -0.5]

func _begin(helper_index: int) -> void:
	_state = 1 + helper_index * 7919
	_buffer.clear()
	_hashing = HashingContext.new()
	_hashing.start(HashingContext.HASH_SHA256)

func _finish() -> String:
	_flush(true)
	return _hashing.finish().hex_encode()

func _flush(force: bool = false) -> void:
	if force or _buffer.get_size() >= 65536:
		_hashing.update(_buffer.data_array)
		_buffer.clear()

func _next31() -> int:
	_state = (_state * 48271) % 2147483647
	return _state

func _below(bound: int) -> int:
	return _next31() % bound

func _u63() -> int:
	var high := _next31() & 0x7FFFFFFF
	var middle := _next31() & 0xFFFF
	var low := _next31() & 0xFFFF
	return (high << 32) | (middle << 16) | low

func _rand_int() -> int:
	var mode := _below(6)
	if mode == 0:
		return _below(201) - 100
	if mode == 1:
		return _below(2000001) - 1000000
	if mode == 2:
		var bases := [2147483647, -2147483648, 4294967295, -4294967296, 2147483648, -2147483649]
		var base: int = bases[_below(6)]
		return base + _below(5) - 2
	if mode == 3:
		var value := _u63()
		if _below(2) == 1:
			value = -value - 1
		return value
	if mode == 4:
		var specials := [0, 1, -1, INT64_MAX, INT64_MIN, INT64_MIN + 1, INT64_MAX - 1]
		return specials[_below(7)]
	return _below(64)

func _bits_to_float(bits: int) -> float:
	_bytes.encode_s64(0, bits)
	return _bytes.decode_double(0)

func _rand_float() -> float:
	var mode := _below(6)
	if mode == 0:
		return float(_below(4001) - 2000) / 2.0
	if mode == 1:
		return float(_below(2000001) - 1000000) / 1000.0
	if mode == 2:
		return float(_rand_int())
	if mode == 3:
		var bits := _u63()
		if _below(2) == 1:
			bits = -bits - 1
		return _bits_to_float(bits)
	if mode == 4:
		return _float_specials[_below(16)]
	var numerator := float(_next31())
	var denominator := float(_next31())
	var direction := 1.0 if _below(2) == 0 else -1.0
	return numerator / denominator * direction

# An int or a float, often equal across the two types, to show which one
# max/min/clamp hand back.
func _rand_number() -> Variant:
	var as_float := _below(2) == 1
	var mode := _below(3)
	if mode == 0:
		var small := _below(7) - 3
		return float(small) if as_float else small
	if mode == 1:
		var pick: float = _number_specials[_below(7)]
		return pick if as_float else 0
	return _rand_float() if as_float else _rand_int()

# --- emitting answers (compat_fuzz.cpp: Out) ---

func _emit_int(value: int) -> void:
	_buffer.put_64(value)

func _emit_float(value: float) -> void:
	if is_nan(value):
		_buffer.put_64(CANONICAL_NAN_BITS)
	else:
		_buffer.put_double(value)

func _emit_bool(value: bool) -> void:
	_buffer.put_u8(1 if value else 0)

func _emit_text(text: String) -> void:
	_buffer.put_utf8_string(text)

func _emit_number(value: Variant) -> void:
	if typeof(value) == TYPE_INT:
		_buffer.put_u8(1)
		_emit_int(value)
	else:
		_buffer.put_u8(2)
		_emit_float(value)

# --- the helpers ---

func _range_bound() -> int:
	var mode := _below(4)
	if mode == 0:
		return _below(201) - 100
	if mode == 1:
		return _rand_int()
	if mode == 2:
		return -2147483648 if _below(2) == 0 else 2147483647
	return _below(10)

func _fuzz_pcg(count: int) -> void:
	var rng := RandomNumberGenerator.new()
	for i in count:
		rng.seed = _rand_int()
		_emit_int(rng.state)
		if _below(4) == 0:
			rng.state = _rand_int()
		var draws := _below(4) + 1
		for k in draws:
			var op := _below(5)
			if op == 0:
				_emit_int(rng.randi())
			elif op == 1:
				var from := _range_bound()
				var to := _range_bound()
				_emit_int(rng.randi_range(from, to))
			elif op == 2:
				_emit_float(rng.randf())
			elif op == 3:
				_emit_int(rng.randi_range(0, 99))
			else:
				var low := _below(1000) - 500
				var high := low + _below(64)
				_emit_int(rng.randi_range(low, high))
			_emit_int(rng.state)
		_flush()

func _fuzz_int_text(count: int) -> void:
	for i in count:
		var value := _rand_int()
		_emit_text(str(value))
		_emit_text("%d" % value)
		var number := _rand_float()
		_emit_text("%d" % number)
		_flush()

func _rand_string() -> String:
	var text := ""
	if _below(16) == 0:
		if _below(2) == 0:
			text = "-"
		var digits := 17 + _below(5)
		for d in digits:
			text += String.chr(0x30 + _below(10))
		return text
	var length := _below(25)
	for c in length:
		var pick := _below(24)
		if pick < 10:
			text += String.chr(0x30 + pick)
		else:
			text += String.chr(CODE_POINTS[pick - 10])
	return text

func _fuzz_string(count: int) -> void:
	for i in count:
		var text := _rand_string()
		_emit_int(int(text))
		_emit_bool(text.is_valid_int())
		_emit_int(text.hash())
		_emit_text(text.sha256_text())
		_flush()

func _rand_divisor_pair() -> Array:
	var left := _rand_int()
	var right := _rand_int()
	if right == 0:
		right = 1 + _below(9)
	if right == -1 and left == INT64_MIN:
		left = 0
	return [left, right]

func _fuzz_posmod(count: int) -> void:
	for i in count:
		var pair := _rand_divisor_pair()
		_emit_int(posmod(pair[0], pair[1]))
		_flush()

func _fuzz_int_div(count: int) -> void:
	for i in count:
		var pair := _rand_divisor_pair()
		var left: int = pair[0]
		var right: int = pair[1]
		_emit_int(left / right)
		_emit_int(left % right)
		_flush()

func _fuzz_float_round(count: int) -> void:
	for i in count:
		var value := _rand_float()
		_emit_float(round(value))
		_emit_float(floor(value))
		_emit_float(ceil(value))
		_emit_int(int(value))
		_emit_float(float(_rand_int()))
		_flush()

func _fuzz_snapped(count: int) -> void:
	var steps := [0.0, 1.0, 0.5, 0.1, 0.01, 0.25, 5.0, -0.5, 0.001]
	for i in count:
		var value := _rand_float()
		var step: float = steps[_below(9)] if _below(4) != 0 else _rand_float()
		_emit_float(snappedf(value, step))
		_flush()

func _fuzz_variant_minmax(count: int) -> void:
	for i in count:
		var a = _rand_number()
		var b = _rand_number()
		var c = _rand_number()
		_emit_number(max(a, b))
		_emit_number(min(a, b))
		_emit_number(clamp(a, b, c))
		_emit_number(max(a, b, c))
		_emit_number(min(a, b, c))
		_flush()

func _fuzz_typed_minmax(count: int) -> void:
	for i in count:
		var x := _rand_float()
		var y := _rand_float()
		var z := _rand_float()
		_emit_float(maxf(x, y))
		_emit_float(minf(x, y))
		_emit_float(clampf(x, y, z))
		_emit_float(absf(x))
		var p := _rand_int()
		var q := _rand_int()
		var r := _rand_int()
		_emit_int(maxi(p, q))
		_emit_int(mini(p, q))
		_emit_int(clampi(p, q, r))
		_emit_int(absi(p))
		_flush()

func _fuzz_sort(count: int) -> void:
	for i in count:
		var size := _below(41)
		var major_values := 1 + _below(4)
		var minor_values := 1 + _below(3)
		var keys := []
		var order := []
		for index in size:
			var major := _below(major_values)
			var minor := _below(minor_values)
			keys.append([major, minor])
			order.append(index)
		order.sort_custom(func(left: int, right: int) -> bool:
			var a: Array = keys[left]
			var b: Array = keys[right]
			if a[0] != b[0]:
				return a[0] < b[0]
			return a[1] < b[1]
		)
		_emit_int(size)
		for index in order:
			_emit_int(index)
		_flush()

# JSON.stringify of a float: random floats, dyadic fractions (exact ties at
# every place) and the floats next to powers of ten and their reciprocals.
func _fuzz_json_float(count: int) -> void:
	for i in count:
		_emit_text(JSON.stringify(_rand_float()))
		var numerator := float(_below(2000001) - 1000000)
		_emit_text(JSON.stringify(numerator / float(1 << _below(60))))
		var power := 1
		for k in _below(19):
			power *= 10
		_bytes.encode_double(0, float(power))
		var near := _bits_to_float(_bytes.decode_s64(0) + _below(5) - 2)
		if _below(2) == 1:
			near = 1.0 / near
		_emit_text(JSON.stringify(near))
		_flush()

# --- JSON.parse: texts built from the draws (compat_fuzz.cpp: rand_json_text) ---

func _hex4(value: int) -> String:
	return ("%04x" if _below(2) == 0 else "%04X") % value

func _digits(count: int) -> String:
	var text := ""
	for d in count:
		text += String.chr(0x30 + _below(10))
	return text

func _rand_number_text() -> String:
	var text := ""
	if _below(4) == 0:
		text += "-"
	text += _digits(_below(25) if _below(4) == 0 else 1 + _below(6))
	if _below(2) == 0:
		text += "."
		text += _digits(_below(25) if _below(4) == 0 else _below(8))
	if _below(3) == 0:
		text += "e" if _below(2) == 0 else "E"
		var sign := _below(3)
		text += "" if sign == 0 else ("+" if sign == 1 else "-")
		text += _digits(0 if _below(4) == 0 else (3 if _below(16) == 0 else 1 + _below(2)))
	return text

func _rand_json_string() -> String:
	var text := "\""
	var pieces := _below(12)
	for i in pieces:
		var pick := _below(20)
		if pick < 8:
			text += String.chr(STRING_CHARS[pick])
		elif pick < 16:
			text += ESCAPES[pick - 8]
		elif pick == 16:
			text += "\\u" + _hex4(_below(65536))
		elif pick == 17:
			text += "\\u" + _hex4(0xD800 + _below(0x400))
			text += "\\u" + _hex4(0xDC00 + _below(0x400))
		elif pick == 18:
			text += "\\u0000"
		else:
			text += BAD_ESCAPES[_below(3)]
	if _below(16) != 0:
		text += "\""
	return text

func _rand_json_value(depth: int) -> String:
	var mode := _below(4 if depth >= 3 else 7)
	if mode == 0 or mode == 3:
		return _rand_number_text()
	if mode == 1:
		return _rand_json_string()
	if mode == 2:
		return WORDS[_below(5)]
	var text := "{" if mode == 6 else "["
	var count := _below(5)
	for i in count:
		if i > 0:
			text += SEPARATORS[_below(4)]
		if mode == 6:
			text += "\"" + KEYS[_below(5)] + "\"" + (":" if _below(2) == 0 else ": ")
		text += _rand_json_value(depth + 1)
	if count > 0 and _below(8) == 0:
		text += ","
	text += "}" if mode == 6 else "]"
	return text

func _rand_json_text() -> String:
	var mode := _below(10)
	if mode <= 1:
		return _rand_number_text()
	if mode == 2:
		return "[" + _rand_number_text() + "]"
	if mode == 3:
		return _rand_json_string()
	if mode <= 7:
		return _rand_json_value(0)
	if mode == 8:
		var soup := ""
		var pieces := _below(12)
		while pieces > 0:
			soup += SOUP[_below(24)]
			pieces -= 1
		return soup
	if _below(128) == 0:
		var depth := 1020 + _below(10)
		var closes := depth if _below(2) == 0 else depth - 1
		return "[".repeat(depth) + "]".repeat(closes)
	var text := " \n" + _rand_json_value(0) + "\n\t "
	if _below(4) == 0:
		text += "x"
	return text

func _emit_json_value(value: Variant) -> void:
	match typeof(value):
		TYPE_NIL:
			_buffer.put_u8(0)
		TYPE_BOOL:
			_buffer.put_u8(1)
			_emit_bool(value)
		TYPE_FLOAT:
			_buffer.put_u8(2)
			_emit_float(value)
		TYPE_STRING:
			_buffer.put_u8(3)
			_emit_text(value)
		TYPE_ARRAY:
			_buffer.put_u8(4)
			_emit_int(value.size())
			for item in value:
				_emit_json_value(item)
		TYPE_DICTIONARY:
			_buffer.put_u8(5)
			_emit_int(value.size())
			for key in value:
				_emit_text(key)
				_emit_json_value(value[key])
		_:
			_buffer.put_u8(9)

# JSON.new().parse(text): the error, its line and message, and the data.
func _fuzz_json_parse(count: int) -> void:
	for i in count:
		var json := JSON.new()
		var error := json.parse(_rand_json_text())
		_emit_int(error)
		_emit_int(json.get_error_line())
		_emit_text(json.get_error_message())
		_emit_json_value(json.data)
		_flush()
