#pragma once

// GDScript's number semantics, bit for bit, as Godot 4.6.2 computes them
// (core/math/math_funcs.h, core/typedefs.h, core/variant/variant_utility.cpp
// and variant_op.h of the 4.6.2-stable tag, MIT). Fuzzed against the engine by
// tools/rules_compat/capture_vectors.gd and rules_selftest.
//
// GDScript's untyped max(), min() and clamp() return one of their arguments as it
// came, int or float, so they work on Number. maxi/maxf and the other typed forms
// are the engine's MAX/MIN/CLAMP templates, which differ on ties, signed zeros
// and NaN.

#include <cmath>
#include <cstdint>
#include <initializer_list>

namespace aurelion::rules::compat {

// An int or a float as a Variant holds it.
struct Number {
	bool is_float = false;
	int64_t i = 0;
	double f = 0.0;

	static Number of_int(int64_t value) {
		Number n;
		n.i = value;
		return n;
	}
	static Number of_float(double value) {
		Number n;
		n.is_float = true;
		n.f = value;
		return n;
	}
	double as_double() const { return is_float ? f : static_cast<double>(i); }
};

// Variant OP_LESS on two numbers: an int meets a float as a double.
inline bool number_less(const Number &a, const Number &b) {
	if (!a.is_float && !b.is_float) {
		return a.i < b.i;
	}
	return a.as_double() < b.as_double();
}

inline bool number_greater(const Number &a, const Number &b) {
	if (!a.is_float && !b.is_float) {
		return a.i > b.i;
	}
	return a.as_double() > b.as_double();
}

// max(a, b, ...): the first argument, replaced by each later one it is less than.
inline Number variant_max(std::initializer_list<Number> args) {
	const Number *base = args.begin();
	for (const Number *arg = args.begin() + 1; arg != args.end(); ++arg) {
		if (number_less(*base, *arg)) {
			base = arg;
		}
	}
	return *base;
}

inline Number variant_min(std::initializer_list<Number> args) {
	const Number *base = args.begin();
	for (const Number *arg = args.begin() + 1; arg != args.end(); ++arg) {
		if (number_greater(*base, *arg)) {
			base = arg;
		}
	}
	return *base;
}

// clamp(x, lo, hi): lo when x < lo, then hi when that value > hi.
inline Number variant_clamp(const Number &x, const Number &lo, const Number &hi) {
	Number value = x;
	if (number_less(value, lo)) {
		value = lo;
	}
	if (number_greater(value, hi)) {
		value = hi;
	}
	return value;
}

// MAX/MIN/CLAMP of core/typedefs.h: maxi, maxf, mini, minf, clampi, clampf.
template <typename T>
inline T engine_max(T a, T b) {
	return a > b ? a : b;
}
template <typename T>
inline T engine_min(T a, T b) {
	return a < b ? a : b;
}
template <typename T>
inline T engine_clamp(T a, T lo, T hi) {
	return a < lo ? lo : (a > hi ? hi : a);
}

// absi(x) / abs(int): std::abs, so INT64_MIN stays INT64_MIN.
inline int64_t absi(int64_t x) {
	return x < 0 ? static_cast<int64_t>(0 - static_cast<uint64_t>(x)) : x;
}

// posmod(x, y). The engine answers 0 for y == 0 (with an error) and traps on
// INT64_MIN % -1; y == -1 always answers 0 here.
inline int64_t posmod(int64_t x, int64_t y) {
	if (y == 0 || y == -1) {
		return 0;
	}
	int64_t value = x % y;
	if ((value < 0 && y > 0) || (value > 0 && y < 0)) {
		value += y;
	}
	return value;
}

// int / int and int % int: C++ truncation. y == 0 is a script error in the engine
// and y == -1 with INT64_MIN traps; callers keep both out.
inline int64_t int_div(int64_t x, int64_t y) {
	return y == -1 ? static_cast<int64_t>(0 - static_cast<uint64_t>(x)) : x / y;
}
inline int64_t int_mod(int64_t x, int64_t y) {
	return y == -1 ? 0 : x % y;
}

// int(float): truncation, and x86-64's answer (INT64_MIN) for NaN and values
// outside the int64 range, which is what the official builds compute.
inline int64_t float_to_int(double x) {
	if (!(x >= -9223372036854775808.0 && x < 9223372036854775808.0)) {
		return INT64_MIN;
	}
	return static_cast<int64_t>(x);
}

// round() of a float, and roundf/roundi before their cast. Math::round is
// std::round, and the official builds' C runtimes disagree on one input pair:
// the Windows build (MinGW) answers +-1 for +-0.49999999999999994, as
// trunc(x + copysign(0.5, x)) does, and the Linux build (glibc) answers +-0.
// Each platform gets its own engine's answer, so GDScript and the native rules
// agree on both (and differ between them exactly as GDScript does).
inline double godot_round(double x) {
#ifdef _WIN32
	if (!(std::fabs(x) < 4503599627370496.0)) {
		return x; // already whole, infinite or NaN
	}
	return std::trunc(x + std::copysign(0.5, x));
#else
	return std::round(x);
#endif
}

// floor() and ceil() of a float, and their typed forms.
inline double godot_floor(double x) {
	return std::floor(x);
}
inline double godot_ceil(double x) {
	return std::ceil(x);
}

// snappedf(x, step) / Math::snapped.
inline double snappedf(double value, double step) {
	if (step != 0) {
		value = std::floor(value / step + 0.5) * step;
	}
	return value;
}

} // namespace aurelion::rules::compat
