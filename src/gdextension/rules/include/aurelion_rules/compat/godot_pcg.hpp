#pragma once

// Godot 4.6.2's RandomNumberGenerator, bit for bit (docs/native-rules-engine-transition.md,
// section 4 "Engine-exact helpers"). From core/math/random_pcg.h/.cpp and
// thirdparty/misc/pcg.cpp of the 4.6.2-stable tag (Godot: MIT; the minimal PCG32
// code: (c) 2014 M.E. O'Neill, Apache License 2.0). Fuzzed against the engine by
// tools/rules_compat/capture_vectors.gd and rules_selftest.
//
// How GDScript uses it: `rng.seed = s` reseeds (the increment stays Godot's
// default), `rng.state = x` then overwrites the state alone. The battle stream is
// stored as str(rng.state): the uint64 state seen as a signed int.

#include <cmath>
#include <cstdint>

namespace aurelion::rules::compat {

class GodotPcg {
public:
	static constexpr uint64_t kDefaultSeed = 12047754176567800795ULL; // RandomPCG::DEFAULT_SEED
	static constexpr uint64_t kDefaultInc = 1442695040888963407ULL; // PCG_DEFAULT_INC_64

	GodotPcg() { seed(kDefaultSeed); }

	// RandomNumberGenerator.seed = p_seed (pcg32_srandom_r with the default increment).
	void seed(uint64_t p_seed) {
		state_ = 0U;
		inc_ = (kDefaultInc << 1u) | 1u;
		next();
		state_ += p_seed;
		next();
	}
	// RandomNumberGenerator.state
	void set_state(uint64_t p_state) { state_ = p_state; }
	uint64_t state() const { return state_; }

	// randi(): pcg32_random_r.
	uint32_t next() {
		const uint64_t oldstate = state_;
		state_ = oldstate * 6364136223846793005ULL + (inc_ | 1);
		const uint32_t xorshifted = static_cast<uint32_t>(((oldstate >> 18u) ^ oldstate) >> 27u);
		const uint32_t rot = static_cast<uint32_t>(oldstate >> 59u);
		return (xorshifted >> rot) | (xorshifted << ((0u - rot) & 31u));
	}

	// pcg32_boundedrand_r: uniform in [0, bound).
	uint32_t bounded(uint32_t bound) {
		const uint32_t threshold = (0u - bound) % bound;
		for (;;) {
			const uint32_t r = next();
			if (r >= threshold) {
				return r % bound;
			}
		}
	}

	// randi_range(from, to). The binding takes C ints: GDScript's int64 arguments
	// are truncated to 32 bits first, and the answer is a 32-bit int.
	int64_t randi_range(int64_t p_from64, int64_t p_to64) {
		const int32_t p_from = static_cast<int32_t>(static_cast<uint32_t>(static_cast<uint64_t>(p_from64)));
		const int32_t p_to = static_cast<int32_t>(static_cast<uint32_t>(static_cast<uint64_t>(p_to64)));
		if (p_from == p_to) {
			return p_from;
		}
		const int64_t min = p_from < p_to ? p_from : p_to;
		const int64_t max = p_from < p_to ? p_to : p_from;
		const uint32_t diff = static_cast<uint32_t>(max - min);
		int64_t result;
		if (diff == UINT32_MAX) {
			result = static_cast<int64_t>(next()) + min;
		} else {
			result = static_cast<int64_t>(bounded(diff + 1U)) + min;
		}
		// RandomPCG::random returns int: the sum is truncated to 32 bits.
		return static_cast<int32_t>(static_cast<uint32_t>(static_cast<uint64_t>(result)));
	}

	// randf(): a 32-bit float (real_t in official builds), which GDScript widens.
	// Two draws, or one when the first is 0.
	double randf() {
		const uint32_t proto_exp_offset = next();
		if (proto_exp_offset == 0) {
			return 0.0;
		}
		const float significand = static_cast<float>(next() | 0x80000001u);
		return static_cast<double>(std::ldexp(significand, -32 - clz32(proto_exp_offset)));
	}

private:
	static int clz32(uint32_t x) {
		int count = 0;
		for (uint32_t bit = 0x80000000u; bit != 0 && (x & bit) == 0; bit >>= 1) {
			++count;
		}
		return count;
	}

	uint64_t state_ = 0;
	uint64_t inc_ = 0;
};

} // namespace aurelion::rules::compat
