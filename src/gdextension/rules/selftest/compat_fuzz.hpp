#pragma once

// The engine-exact helpers fuzzed on the inputs tools/rules_compat/capture_vectors.gd
// gives the engine (compat_fuzz.cpp).

#include <cstdint>
#include <string>
#include <vector>

struct CompatDigest {
	std::string helper;
	std::string sha256;
};

// One SHA-256 per helper over its answers to `count` inputs, in the order
// capture_vectors.gd prints them.
std::vector<CompatDigest> compat_digests(int64_t count);
