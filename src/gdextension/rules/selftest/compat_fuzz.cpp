// The engine-exact helpers on the same inputs tools/rules_compat/capture_vectors.gd
// gives the engine: same Park-Miller draws, same order, same answer bytes. Keep
// the two files in step; a draw added on one side shifts every digest after it.

#include "compat_fuzz.hpp"

#include "aurelion_rules/compat/godot_math.hpp"
#include "aurelion_rules/compat/godot_pcg.hpp"
#include "aurelion_rules/compat/godot_string.hpp"
#include "aurelion_rules/compat/sort_array.hpp"

#include <cmath>
#include <cstring>
#include <limits>
#include <vector>

namespace compat = aurelion::rules::compat;

namespace {

constexpr int64_t kInt64Max = std::numeric_limits<int64_t>::max();
constexpr int64_t kInt64Min = std::numeric_limits<int64_t>::min();
constexpr uint64_t kCanonicalNanBits = 0x7FF8000000000000ULL;
constexpr int32_t kCodePoints[14] = { 0x2D, 0x2B, 0x2E, 0x20, 0x61, 0x5A, 0x5F, 0x09, 0xE9, 0x3A9, 0x4E2D, 0x1F600, 0x30, 0x2D };

void append_utf8(std::string &text, uint32_t cp) {
	if (cp < 0x80) {
		text.push_back(static_cast<char>(cp));
	} else if (cp < 0x800) {
		text.push_back(static_cast<char>(0xC0 | (cp >> 6)));
		text.push_back(static_cast<char>(0x80 | (cp & 0x3F)));
	} else if (cp < 0x10000) {
		text.push_back(static_cast<char>(0xE0 | (cp >> 12)));
		text.push_back(static_cast<char>(0x80 | ((cp >> 6) & 0x3F)));
		text.push_back(static_cast<char>(0x80 | (cp & 0x3F)));
	} else {
		text.push_back(static_cast<char>(0xF0 | (cp >> 18)));
		text.push_back(static_cast<char>(0x80 | ((cp >> 12) & 0x3F)));
		text.push_back(static_cast<char>(0x80 | ((cp >> 6) & 0x3F)));
		text.push_back(static_cast<char>(0x80 | (cp & 0x3F)));
	}
}

class Fuzz {
public:
	explicit Fuzz(int64_t helper_index) :
			state_(1 + helper_index * 7919) {}

	// --- the input stream ---

	int64_t next31() {
		state_ = (state_ * 48271) % 2147483647;
		return state_;
	}

	int64_t below(int64_t bound) { return next31() % bound; }

	int64_t u63() {
		const int64_t high = next31() & 0x7FFFFFFF;
		const int64_t middle = next31() & 0xFFFF;
		const int64_t low = next31() & 0xFFFF;
		return (high << 32) | (middle << 16) | low;
	}

	int64_t rand_int() {
		const int64_t mode = below(6);
		if (mode == 0) {
			return below(201) - 100;
		}
		if (mode == 1) {
			return below(2000001) - 1000000;
		}
		if (mode == 2) {
			static const int64_t bases[6] = { 2147483647LL, -2147483648LL, 4294967295LL, -4294967296LL, 2147483648LL, -2147483649LL };
			const int64_t base = bases[below(6)];
			const int64_t offset = below(5);
			return base + offset - 2;
		}
		if (mode == 3) {
			int64_t value = u63();
			if (below(2) == 1) {
				value = -value - 1;
			}
			return value;
		}
		if (mode == 4) {
			static const int64_t specials[7] = { 0, 1, -1, kInt64Max, kInt64Min, kInt64Min + 1, kInt64Max - 1 };
			return specials[below(7)];
		}
		return below(64);
	}

	static double bits_to_float(int64_t bits) {
		const uint64_t raw = static_cast<uint64_t>(bits);
		double value;
		std::memcpy(&value, &raw, sizeof(value));
		return value;
	}

	double rand_float() {
		const int64_t mode = below(6);
		if (mode == 0) {
			return static_cast<double>(below(4001) - 2000) / 2.0;
		}
		if (mode == 1) {
			return static_cast<double>(below(2000001) - 1000000) / 1000.0;
		}
		if (mode == 2) {
			return static_cast<double>(rand_int());
		}
		if (mode == 3) {
			int64_t bits = u63();
			if (below(2) == 1) {
				bits = -bits - 1;
			}
			return bits_to_float(bits);
		}
		if (mode == 4) {
			static const double specials[16] = {
				0.0, -0.0, 0.5, -0.5, 1.5, -1.5, 2.5,
				std::numeric_limits<double>::infinity(), -std::numeric_limits<double>::infinity(), std::numeric_limits<double>::quiet_NaN(),
				bits_to_float(0x7E37E43C8800759CLL), -bits_to_float(0x01A56E1FC2F8F359LL), bits_to_float(0x43E0000000000000LL), -bits_to_float(0x43E0000000000000LL),
				bits_to_float(0x432FFFFFFFFFFFFFLL), bits_to_float(0x3FDFFFFFFFFFFFFFLL)
			};
			return specials[below(16)];
		}
		const double numerator = static_cast<double>(next31());
		const double denominator = static_cast<double>(next31());
		const double direction = below(2) == 0 ? 1.0 : -1.0;
		return numerator / denominator * direction;
	}

	compat::Number rand_number() {
		const bool as_float = below(2) == 1;
		const int64_t mode = below(3);
		if (mode == 0) {
			const int64_t small = below(7) - 3;
			return as_float ? compat::Number::of_float(static_cast<double>(small)) : compat::Number::of_int(small);
		}
		if (mode == 1) {
			static const double specials[7] = { 0.0, -0.0, std::numeric_limits<double>::quiet_NaN(), std::numeric_limits<double>::infinity(), -std::numeric_limits<double>::infinity(), 0.5, -0.5 };
			const double pick = specials[below(7)];
			return as_float ? compat::Number::of_float(pick) : compat::Number::of_int(0);
		}
		return as_float ? compat::Number::of_float(rand_float()) : compat::Number::of_int(rand_int());
	}

	int64_t range_bound() {
		const int64_t mode = below(4);
		if (mode == 0) {
			return below(201) - 100;
		}
		if (mode == 1) {
			return rand_int();
		}
		if (mode == 2) {
			return below(2) == 0 ? -2147483648LL : 2147483647LL;
		}
		return below(10);
	}

	std::string rand_string() {
		std::string text;
		if (below(16) == 0) {
			if (below(2) == 0) {
				text = "-";
			}
			const int64_t digits = 17 + below(5);
			for (int64_t d = 0; d < digits; ++d) {
				append_utf8(text, static_cast<uint32_t>(0x30 + below(10)));
			}
			return text;
		}
		const int64_t length = below(25);
		for (int64_t c = 0; c < length; ++c) {
			const int64_t pick = below(24);
			if (pick < 10) {
				append_utf8(text, static_cast<uint32_t>(0x30 + pick));
			} else {
				append_utf8(text, static_cast<uint32_t>(kCodePoints[pick - 10]));
			}
		}
		return text;
	}

	void rand_divisor_pair(int64_t &left, int64_t &right) {
		left = rand_int();
		right = rand_int();
		if (right == 0) {
			right = 1 + below(9);
		}
		if (right == -1 && left == kInt64Min) {
			left = 0;
		}
	}

	// --- the answers ---

	void emit_int(int64_t value) {
		uint64_t bits = static_cast<uint64_t>(value);
		for (int i = 0; i < 8; ++i) {
			buffer_.push_back(static_cast<uint8_t>(bits & 0xFF));
			bits >>= 8;
		}
	}

	void emit_float(double value) {
		if (std::isnan(value)) {
			emit_int(static_cast<int64_t>(kCanonicalNanBits));
			return;
		}
		uint64_t bits;
		std::memcpy(&bits, &value, sizeof(bits));
		emit_int(static_cast<int64_t>(bits));
	}

	void emit_bool(bool value) { buffer_.push_back(value ? 1 : 0); }

	void emit_text(const std::string &text) {
		uint32_t length = static_cast<uint32_t>(text.size());
		for (int i = 0; i < 4; ++i) {
			buffer_.push_back(static_cast<uint8_t>(length & 0xFF));
			length >>= 8;
		}
		buffer_.insert(buffer_.end(), text.begin(), text.end());
	}

	void emit_number(const compat::Number &value) {
		if (value.is_float) {
			buffer_.push_back(2);
			emit_float(value.f);
		} else {
			buffer_.push_back(1);
			emit_int(value.i);
		}
	}

	void flush(bool force = false) {
		if (force || buffer_.size() >= 65536) {
			if (!buffer_.empty()) {
				sha_.update(buffer_.data(), buffer_.size());
			}
			buffer_.clear();
		}
	}

	std::string finish() {
		flush(true);
		return sha_.finish_hex();
	}

private:
	int64_t state_;
	std::vector<uint8_t> buffer_;
	compat::Sha256 sha_;
};

void fuzz_pcg(Fuzz &f, int64_t count) {
	compat::GodotPcg rng;
	for (int64_t i = 0; i < count; ++i) {
		rng.seed(static_cast<uint64_t>(f.rand_int()));
		f.emit_int(static_cast<int64_t>(rng.state()));
		if (f.below(4) == 0) {
			rng.set_state(static_cast<uint64_t>(f.rand_int()));
		}
		const int64_t draws = f.below(4) + 1;
		for (int64_t k = 0; k < draws; ++k) {
			const int64_t op = f.below(5);
			if (op == 0) {
				f.emit_int(static_cast<int64_t>(rng.next()));
			} else if (op == 1) {
				const int64_t from = f.range_bound();
				const int64_t to = f.range_bound();
				f.emit_int(rng.randi_range(from, to));
			} else if (op == 2) {
				f.emit_float(rng.randf());
			} else if (op == 3) {
				f.emit_int(rng.randi_range(0, 99));
			} else {
				const int64_t low = f.below(1000) - 500;
				const int64_t high = low + f.below(64);
				f.emit_int(rng.randi_range(low, high));
			}
			f.emit_int(static_cast<int64_t>(rng.state()));
		}
		f.flush();
	}
}

void fuzz_int_text(Fuzz &f, int64_t count) {
	for (int64_t i = 0; i < count; ++i) {
		const int64_t value = f.rand_int();
		f.emit_text(compat::itos(value));
		f.emit_text(compat::itos(value));
		const double number = f.rand_float();
		f.emit_text(compat::itos(compat::float_to_int(number)));
		f.flush();
	}
}

void fuzz_string(Fuzz &f, int64_t count) {
	for (int64_t i = 0; i < count; ++i) {
		const std::string text = f.rand_string();
		f.emit_int(compat::to_int(text));
		f.emit_bool(compat::is_valid_int(text));
		f.emit_int(static_cast<int64_t>(compat::string_hash(text)));
		f.emit_text(compat::sha256_text(text));
		f.flush();
	}
}

void fuzz_posmod(Fuzz &f, int64_t count) {
	for (int64_t i = 0; i < count; ++i) {
		int64_t left = 0;
		int64_t right = 0;
		f.rand_divisor_pair(left, right);
		f.emit_int(compat::posmod(left, right));
		f.flush();
	}
}

void fuzz_int_div(Fuzz &f, int64_t count) {
	for (int64_t i = 0; i < count; ++i) {
		int64_t left = 0;
		int64_t right = 0;
		f.rand_divisor_pair(left, right);
		f.emit_int(compat::int_div(left, right));
		f.emit_int(compat::int_mod(left, right));
		f.flush();
	}
}

void fuzz_float_round(Fuzz &f, int64_t count) {
	for (int64_t i = 0; i < count; ++i) {
		const double value = f.rand_float();
		f.emit_float(compat::godot_round(value));
		f.emit_float(compat::godot_floor(value));
		f.emit_float(compat::godot_ceil(value));
		f.emit_int(compat::float_to_int(value));
		f.emit_float(static_cast<double>(f.rand_int()));
		f.flush();
	}
}

void fuzz_snapped(Fuzz &f, int64_t count) {
	static const double steps[9] = { 0.0, 1.0, 0.5, 0.1, 0.01, 0.25, 5.0, -0.5, 0.001 };
	for (int64_t i = 0; i < count; ++i) {
		const double value = f.rand_float();
		const double step = f.below(4) != 0 ? steps[f.below(9)] : f.rand_float();
		f.emit_float(compat::snappedf(value, step));
		f.flush();
	}
}

void fuzz_variant_minmax(Fuzz &f, int64_t count) {
	for (int64_t i = 0; i < count; ++i) {
		const compat::Number a = f.rand_number();
		const compat::Number b = f.rand_number();
		const compat::Number c = f.rand_number();
		f.emit_number(compat::variant_max({ a, b }));
		f.emit_number(compat::variant_min({ a, b }));
		f.emit_number(compat::variant_clamp(a, b, c));
		f.emit_number(compat::variant_max({ a, b, c }));
		f.emit_number(compat::variant_min({ a, b, c }));
		f.flush();
	}
}

void fuzz_typed_minmax(Fuzz &f, int64_t count) {
	for (int64_t i = 0; i < count; ++i) {
		const double x = f.rand_float();
		const double y = f.rand_float();
		const double z = f.rand_float();
		f.emit_float(compat::engine_max(x, y));
		f.emit_float(compat::engine_min(x, y));
		f.emit_float(compat::engine_clamp(x, y, z));
		f.emit_float(std::fabs(x));
		const int64_t p = f.rand_int();
		const int64_t q = f.rand_int();
		const int64_t r = f.rand_int();
		f.emit_int(compat::engine_max(p, q));
		f.emit_int(compat::engine_min(p, q));
		f.emit_int(compat::engine_clamp(p, q, r));
		f.emit_int(compat::absi(p));
		f.flush();
	}
}

void fuzz_sort(Fuzz &f, int64_t count) {
	std::vector<int64_t> majors;
	std::vector<int64_t> minors;
	std::vector<int64_t> order;
	for (int64_t i = 0; i < count; ++i) {
		const int64_t size = f.below(41);
		const int64_t major_values = 1 + f.below(4);
		const int64_t minor_values = 1 + f.below(3);
		majors.clear();
		minors.clear();
		order.clear();
		for (int64_t index = 0; index < size; ++index) {
			const int64_t major = f.below(major_values);
			const int64_t minor = f.below(minor_values);
			majors.push_back(major);
			minors.push_back(minor);
			order.push_back(index);
		}
		compat::sort_custom(order.data(), size, [&](int64_t left, int64_t right) {
			if (majors[static_cast<size_t>(left)] != majors[static_cast<size_t>(right)]) {
				return majors[static_cast<size_t>(left)] < majors[static_cast<size_t>(right)];
			}
			return minors[static_cast<size_t>(left)] < minors[static_cast<size_t>(right)];
		});
		f.emit_int(size);
		for (int64_t index : order) {
			f.emit_int(index);
		}
		f.flush();
	}
}

// JSON.stringify of a float: random floats, dyadic fractions (exact ties at
// every place) and the floats next to powers of ten and their reciprocals.
void fuzz_json_float(Fuzz &f, int64_t count) {
	for (int64_t i = 0; i < count; ++i) {
		f.emit_text(compat::json_float(f.rand_float()));
		const double numerator = static_cast<double>(f.below(2000001) - 1000000);
		f.emit_text(compat::json_float(numerator / static_cast<double>(int64_t(1) << f.below(60))));
		int64_t power = 1;
		for (int64_t k = f.below(19); k > 0; --k) {
			power *= 10;
		}
		const double whole = static_cast<double>(power);
		int64_t bits;
		std::memcpy(&bits, &whole, sizeof(bits));
		double near = Fuzz::bits_to_float(bits + f.below(5) - 2);
		if (f.below(2) == 1) {
			near = 1.0 / near;
		}
		f.emit_text(compat::json_float(near));
		f.flush();
	}
}

} // namespace

std::vector<CompatDigest> compat_digests(int64_t count) {
	using Runner = void (*)(Fuzz &, int64_t);
	struct Helper {
		const char *name;
		Runner run;
	};
	static const Helper helpers[] = {
		{ "pcg", fuzz_pcg },
		{ "int_text", fuzz_int_text },
		{ "string", fuzz_string },
		{ "posmod", fuzz_posmod },
		{ "int_div", fuzz_int_div },
		{ "float_round", fuzz_float_round },
		{ "snapped", fuzz_snapped },
		{ "variant_minmax", fuzz_variant_minmax },
		{ "typed_minmax", fuzz_typed_minmax },
		{ "sort", fuzz_sort },
		{ "json_float", fuzz_json_float },
	};
	std::vector<CompatDigest> digests;
	int64_t helper_index = 0;
	for (const Helper &helper : helpers) {
		Fuzz fuzz(helper_index);
		helper.run(fuzz, count);
		digests.push_back(CompatDigest{ helper.name, fuzz.finish() });
		helper_index += 1;
	}
	return digests;
}
