#pragma once

// Godot 4.6.2's integer text and string hash, bit for bit (core/string/ustring.cpp
// of the 4.6.2-stable tag, MIT). Strings are UTF-8 std::string here; Godot's are
// UTF-32, so the hash decodes UTF-8 first. Locale-free; no float text: numbers
// with a fraction become text only in the Godot adapter (section 4 of
// docs/native-rules-engine-transition.md).

#include <cstdint>
#include <string>

namespace aurelion::rules::compat {

// str(int) / itos / String::num_int64(p, 10).
std::string itos(int64_t value);

// String::to_int(), which int(String) calls: the digits before the first '.'
// count, every other character is skipped, and each '-' met before the first
// non-zero digit flips the sign ("a-1b2" is -12, "--5" is 5). Past 19 digits the
// engine prints an error and answers INT64_MAX or INT64_MIN.
int64_t to_int(const std::string &text);

// String::is_valid_int().
bool is_valid_int(const std::string &text);

// String::hash(): djb2 over the UTF-32 code points.
uint32_t string_hash(const std::string &utf8);

// String::sha256_text(): SHA-256 of the UTF-8 bytes, lower-case hex.
std::string sha256_text(const std::string &utf8);

// SHA-256 of a byte buffer.
void sha256(const uint8_t *data, size_t size, uint8_t out[32]);

// Incremental SHA-256 (the self-test digests long output streams with it).
class Sha256 {
public:
	Sha256();
	void update(const uint8_t *data, size_t size);
	void finish(uint8_t out[32]);
	std::string finish_hex();

private:
	void block(const uint8_t *chunk);
	uint32_t h_[8];
	uint8_t buffer_[64];
	size_t buffered_ = 0;
	uint64_t length_ = 0;
};

std::string hex_encode(const uint8_t *data, size_t size);

} // namespace aurelion::rules::compat
