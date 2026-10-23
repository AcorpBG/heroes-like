// rules_selftest: the native rules core without Godot.
//
// 1. Golden vectors: inputs with GDScript's answers, captured from the game's
//    own GDScript searches in shadow mode (battle_hex_vectors.inc,
//    ai_search_vectors.inc). No content files are read.
// 2. A sweep over generated boards, digested; the digest must be the same
//    under MSVC, GCC and MinGW and from one run to the next.
// 3. The engine-exact helpers (core/compat) on 2^20 inputs each, digested and
//    compared with the engine's digests (compat_digests.inc, captured by
//    tools/rules_compat/capture_vectors.gd). The core's own pow, exp and log
//    (portable_math, decision D4 option B) are digested alike against the
//    core's digest, which must be the same under MSVC, GCC and MinGW.
//
// Exit 0 and a RULES_SELFTEST ok line, or exit 1 with the first difference.

#include "ai_search_selftest.hpp"
#include "aurelion_rules/battle_hex.hpp"
#include "aurelion_rules/build_info.hpp"
#include "compat_fuzz.hpp"

#include <cstdint>
#include <cstdio>
#include <cstring>
#include <string>
#include <vector>

namespace hex = aurelion::rules::battle_hex;

namespace {

#include "battle_hex_vectors.inc"
#include "compat_digests.inc"

// The sweep's digest on every compiler (FNV-1a 64 over every answer).
constexpr uint64_t kSweepDigest = 0xc6f6ecf4989d40bdULL;
constexpr int64_t kSweepBoards = 20000;

struct Failure {
	bool failed = false;
	std::string message;
};

std::vector<std::string> split_spaces(const std::string &line) {
	std::vector<std::string> tokens;
	std::string current;
	for (char c : line) {
		if (c == ' ') {
			if (!current.empty()) {
				tokens.push_back(current);
				current.clear();
			}
		} else {
			current.push_back(c);
		}
	}
	if (!current.empty()) {
		tokens.push_back(current);
	}
	return tokens;
}

bool parse_int(const std::string &text, int64_t &value) {
	if (text.empty()) {
		return false;
	}
	size_t index = 0;
	bool negative = false;
	if (text[0] == '-') {
		negative = true;
		index = 1;
	}
	if (index >= text.size()) {
		return false;
	}
	int64_t result = 0;
	for (; index < text.size(); ++index) {
		const char c = text[index];
		if (c < '0' || c > '9') {
			return false;
		}
		result = result * 10 + (c - '0');
	}
	value = negative ? -result : result;
	return true;
}

bool parse_mask(const std::string &text, uint8_t *open) {
	if (text.size() != 25) {
		return false;
	}
	for (int64_t digit = 0; digit < 25; ++digit) {
		const char c = text[static_cast<size_t>(digit)];
		int64_t value = 0;
		if (c >= '0' && c <= '9') {
			value = c - '0';
		} else if (c >= 'a' && c <= 'f') {
			value = 10 + (c - 'a');
		} else {
			return false;
		}
		for (int64_t bit = 0; bit < 4; ++bit) {
			const int64_t id = digit * 4 + bit;
			if (id < hex::kCellCount) {
				open[id] = static_cast<uint8_t>((value >> bit) & 1);
			}
		}
	}
	return true;
}

std::string pairs_text(const std::vector<hex::CellSteps> &cells) {
	std::string text;
	char buffer[32];
	for (const hex::CellSteps &cell : cells) {
		if (!text.empty()) {
			text.push_back(' ');
		}
		std::snprintf(buffer, sizeof(buffer), "%d,%d", static_cast<int>(cell.id), static_cast<int>(cell.steps));
		text += buffer;
	}
	return text;
}

// One vector: "<kind> <inputs...> : <answer>", or "<kind> <inputs...> :" when the
// answer is empty. Returns false with a message when the native answer differs or
// the line does not parse.
bool check_vector(const char *line_text, std::string &message) {
	const std::string line(line_text);
	const size_t colon = line.find(" :");
	std::string answer = colon == std::string::npos ? std::string() : line.substr(colon + 2);
	if (!answer.empty() && answer[0] == ' ') {
		answer.erase(0, 1);
	}
	const std::vector<std::string> tokens = split_spaces(line.substr(0, colon));
	if (colon == std::string::npos || tokens.size() < 2) {
		message = "unparsed vector: " + line;
		return false;
	}
	uint8_t open[hex::kCellCount];
	if (!parse_mask(tokens[1], open)) {
		message = "bad mask: " + line;
		return false;
	}
	std::vector<int64_t> numbers;
	for (size_t i = 2; i < tokens.size(); ++i) {
		int64_t value = 0;
		if (!parse_int(tokens[i], value)) {
			message = "bad number: " + line;
			return false;
		}
		numbers.push_back(value);
	}
	std::string got;
	if (tokens[0] == "R" && numbers.size() == 4) {
		got = pairs_text(hex::reachable(open, hex::Body{ numbers[0], numbers[1] }, numbers[2], numbers[3]));
	} else if (tokens[0] == "W" && numbers.size() == 6) {
		got = pairs_text(hex::walk_steps(open, hex::Body{ numbers[0], numbers[1] }, hex::PlacedBody{ numbers[2], numbers[3], numbers[4] }, numbers[5]));
	} else if (tokens[0] == "F" && numbers.empty()) {
		got = hex::field_stays_open(open) ? "1" : "0";
	} else {
		message = "unknown vector: " + line;
		return false;
	}
	if (got != answer) {
		message = "vector differs: " + line + "\n  native: " + got;
		return false;
	}
	return true;
}

struct Fnv {
	uint64_t value = 1469598103934665603ULL;
	void add(int64_t number) {
		uint64_t bits = static_cast<uint64_t>(number);
		for (int i = 0; i < 8; ++i) {
			value ^= bits & 0xffULL;
			value *= 1099511628211ULL;
			bits >>= 8;
		}
	}
};

struct XorShift {
	uint64_t state;
	uint64_t next() {
		state ^= state << 13;
		state ^= state >> 7;
		state ^= state << 17;
		return state;
	}
	int64_t below(int64_t bound) {
		return static_cast<int64_t>(next() % static_cast<uint64_t>(bound));
	}
};

// Every search on kSweepBoards generated boards of 0-45% blocked hexes.
uint64_t sweep_digest() {
	XorShift random{ 0x9E3779B97F4A7C15ULL };
	Fnv digest;
	uint8_t open[hex::kCellCount];
	for (int64_t board = 0; board < kSweepBoards; ++board) {
		const int64_t blocked_percent = random.below(46);
		for (int64_t id = 0; id < hex::kCellCount; ++id) {
			open[id] = random.below(100) < blocked_percent ? 0 : 1;
		}
		const hex::Body body{ 1 + random.below(2), random.below(2) == 0 ? -1 : 1 };
		const int64_t start_id = random.below(hex::kCellCount);
		const int64_t max_steps = random.below(9);
		for (const hex::CellSteps &cell : hex::reachable(open, body, start_id, max_steps)) {
			digest.add(cell.id);
			digest.add(cell.steps);
		}
		digest.add(-1);
		const int64_t target_q = random.below(hex::kColumns + 1) - 1;
		const int64_t target_r = random.below(hex::kRows);
		const int64_t target_tail = random.below(2) == 0 ? target_q : target_q + (random.below(2) == 0 ? -1 : 1);
		const int64_t gap = random.below(4);
		for (const hex::CellSteps &cell : hex::walk_steps(open, body, hex::PlacedBody{ target_q, target_r, target_tail }, gap)) {
			digest.add(cell.id);
			digest.add(cell.steps);
		}
		digest.add(-2);
		digest.add(hex::field_stays_open(open) ? 1 : 0);
	}
	return digest.value;
}

} // namespace

int main(int argc, char **argv) {
	const bool print_only = argc > 1 && std::strcmp(argv[1], "--print-digest") == 0;
	const aurelion::rules::BuildInfo info = aurelion::rules::build_info();
	std::printf("rules_selftest: source_tree=%s compiler=%s\n", info.source_tree.c_str(), info.compiler.c_str());

	int64_t checked = 0;
	for (const char *vector : kBattleHexVectors) {
		std::string message;
		if (!check_vector(vector, message)) {
			std::printf("RULES_SELFTEST failed: %s\n", message.c_str());
			return 1;
		}
		checked += 1;
	}

	const uint64_t first = sweep_digest();
	const uint64_t second = sweep_digest();
	std::printf("rules_selftest: vectors=%lld sweep_digest=%016llx\n", static_cast<long long>(checked), static_cast<unsigned long long>(first));
	if (first != second) {
		std::printf("RULES_SELFTEST failed: two sweeps differ (%016llx, %016llx)\n", static_cast<unsigned long long>(first), static_cast<unsigned long long>(second));
		return 1;
	}
	if (!print_only && first != kSweepDigest) {
		std::printf("RULES_SELFTEST failed: sweep digest %016llx, expected %016llx\n", static_cast<unsigned long long>(first), static_cast<unsigned long long>(kSweepDigest));
		return 1;
	}
	std::string search_message;
	int64_t search_checked = 0;
	if (!ai_search_selftest(print_only, search_message, search_checked)) {
		std::printf("RULES_SELFTEST failed: %s\n", search_message.c_str());
		return 1;
	}
	checked += search_checked;

	int64_t helpers = 0;
	for (const CompatDigest &digest : compat_digests(kCompatCount)) {
		const char *expected = nullptr;
		for (const CompatExpected &entry : kCompatExpected) {
			if (digest.helper == entry.helper) {
				expected = entry.sha256;
			}
		}
		std::printf("rules_selftest: compat %s %s\n", digest.helper.c_str(), digest.sha256.c_str());
		if (!print_only && (expected == nullptr || digest.sha256 != expected)) {
			std::printf("RULES_SELFTEST failed: compat helper %s digest %s, engine %s\n", digest.helper.c_str(), digest.sha256.c_str(), expected == nullptr ? "(none)" : expected);
			return 1;
		}
		helpers += 1;
	}
	std::printf("RULES_SELFTEST ok vectors=%lld compat_helpers=%lld\n", static_cast<long long>(checked), static_cast<long long>(helpers));
	return 0;
}
