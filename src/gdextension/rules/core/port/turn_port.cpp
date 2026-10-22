#include "aurelion_rules/port/turn_port.hpp"

#include <cstdlib>

#ifdef _WIN32
#ifndef WIN32_LEAN_AND_MEAN
#define WIN32_LEAN_AND_MEAN
#endif
#ifndef NOMINMAX
#define NOMINMAX
#endif
#include <windows.h>
#endif

namespace aurelion::rules::port::turn {

namespace {

// Godot's RandomPCG: PCG_DEFAULT_INC_64 and PCG's multiplier.
constexpr uint64_t kDefaultInc = 1442695040888963407ULL;
constexpr uint64_t kMultiplier = 6364136223846793005ULL;

} // namespace

Value seeded_rng(State &state, int64_t seed) {
	// pcg32_srandom_r(rng, seed, kDefaultInc): two steps around adding the seed.
	const uint64_t inc = (kDefaultInc << 1u) | 1u;
	uint64_t pcg = inc;
	pcg += static_cast<uint64_t>(seed);
	pcg = pcg * kMultiplier + inc;
	return gd::rng_new(state, seed, static_cast<int64_t>(pcg));
}

std::string environment(const char *name) {
#ifdef _WIN32
	// OS.set_environment changes the Win32 environment, which the C runtime's
	// copy (getenv, _dupenv_s) does not follow: read it as Godot does.
	std::wstring wide_name;
	for (const char *c = name; *c != '\0'; ++c) {
		wide_name.push_back(static_cast<wchar_t>(static_cast<unsigned char>(*c)));
	}
	const DWORD size = GetEnvironmentVariableW(wide_name.c_str(), nullptr, 0);
	if (size == 0) {
		return std::string();
	}
	std::wstring value(size, L'\0');
	const DWORD length = GetEnvironmentVariableW(wide_name.c_str(), value.data(), size);
	if (length == 0 || length >= size) {
		return std::string();
	}
	const int bytes = WideCharToMultiByte(CP_UTF8, 0, value.data(), static_cast<int>(length), nullptr, 0, nullptr, nullptr);
	std::string text(static_cast<size_t>(bytes > 0 ? bytes : 0), '\0');
	if (bytes > 0) {
		WideCharToMultiByte(CP_UTF8, 0, value.data(), static_cast<int>(length), text.data(), bytes, nullptr, nullptr);
	}
	return text;
#else
	const char *value = std::getenv(name);
	return value == nullptr ? std::string() : std::string(value);
#endif
}

} // namespace aurelion::rules::port::turn
