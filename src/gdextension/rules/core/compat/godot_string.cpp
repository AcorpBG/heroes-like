#include "aurelion_rules/compat/godot_string.hpp"

#include <cstring>

namespace aurelion::rules::compat {
namespace {

bool is_digit(uint32_t c) {
	return c >= '0' && c <= '9';
}

// The next code point of a UTF-8 string, as Godot's String::utf8 parse reads
// valid input. Strings reaching the core come from Godot's own UTF-8 output, so
// they are valid; a stray byte is taken as itself.
uint32_t next_code_point(const std::string &text, size_t &index) {
	const uint8_t lead = static_cast<uint8_t>(text[index]);
	size_t extra = 0;
	uint32_t cp = lead;
	if (lead >= 0xF0 && lead < 0xF8) {
		extra = 3;
		cp = lead & 0x07u;
	} else if (lead >= 0xE0) {
		extra = 2;
		cp = lead & 0x0Fu;
	} else if (lead >= 0xC0) {
		extra = 1;
		cp = lead & 0x1Fu;
	}
	if (extra > 0 && index + extra < text.size()) {
		for (size_t k = 1; k <= extra; ++k) {
			cp = (cp << 6) | (static_cast<uint8_t>(text[index + k]) & 0x3Fu);
		}
		index += extra + 1;
		return cp;
	}
	index += 1;
	return lead;
}

constexpr uint32_t kRoundConstants[64] = {
	0x428a2f98, 0x71374491, 0xb5c0fbcf, 0xe9b5dba5, 0x3956c25b, 0x59f111f1, 0x923f82a4, 0xab1c5ed5,
	0xd807aa98, 0x12835b01, 0x243185be, 0x550c7dc3, 0x72be5d74, 0x80deb1fe, 0x9bdc06a7, 0xc19bf174,
	0xe49b69c1, 0xefbe4786, 0x0fc19dc6, 0x240ca1cc, 0x2de92c6f, 0x4a7484aa, 0x5cb0a9dc, 0x76f988da,
	0x983e5152, 0xa831c66d, 0xb00327c8, 0xbf597fc7, 0xc6e00bf3, 0xd5a79147, 0x06ca6351, 0x14292967,
	0x27b70a85, 0x2e1b2138, 0x4d2c6dfc, 0x53380d13, 0x650a7354, 0x766a0abb, 0x81c2c92e, 0x92722c85,
	0xa2bfe8a1, 0xa81a664b, 0xc24b8b70, 0xc76c51a3, 0xd192e819, 0xd6990624, 0xf40e3585, 0x106aa070,
	0x19a4c116, 0x1e376c08, 0x2748774c, 0x34b0bcb5, 0x391c0cb3, 0x4ed8aa4a, 0x5b9cca4f, 0x682e6ff3,
	0x748f82ee, 0x78a5636f, 0x84c87814, 0x8cc70208, 0x90befffa, 0xa4506ceb, 0xbef9a3f7, 0xc67178f2,
};

uint32_t rotr(uint32_t x, uint32_t n) {
	return (x >> n) | (x << (32 - n));
}

} // namespace

std::string itos(int64_t value) {
	char buffer[24];
	int pos = 23;
	buffer[pos] = 0;
	// Negate in unsigned arithmetic so INT64_MIN prints as the engine prints it.
	uint64_t magnitude = value < 0 ? 0 - static_cast<uint64_t>(value) : static_cast<uint64_t>(value);
	do {
		buffer[--pos] = static_cast<char>('0' + (magnitude % 10));
		magnitude /= 10;
	} while (magnitude != 0);
	if (value < 0) {
		buffer[--pos] = '-';
	}
	return std::string(buffer + pos);
}

int64_t to_int(const std::string &text) {
	if (text.empty()) {
		return 0;
	}
	size_t to = text.find('.');
	if (to == std::string::npos) {
		to = text.size();
	}
	// _to_int<char32_t>: digits before the first '.', every other character
	// skipped, a '-' before the first non-zero digit flips the sign.
	uint64_t integer = 0;
	uint8_t digits = 0;
	bool positive = true;
	size_t index = 0;
	while (index < to) {
		const uint32_t c = next_code_point(text, index);
		if (is_digit(c)) {
			if (digits > 18) {
				const bool overflow = (integer > static_cast<uint64_t>(INT64_MAX / 10)) || (integer == static_cast<uint64_t>(INT64_MAX / 10) && ((positive && c > '7') || (!positive && c > '8')));
				if (overflow) {
					return positive ? INT64_MAX : INT64_MIN;
				}
			}
			integer *= 10;
			integer += c - '0';
			++digits;
		} else if (integer == 0 && c == '-') {
			positive = !positive;
		}
	}
	if (positive) {
		return static_cast<int64_t>(integer);
	}
	return static_cast<int64_t>(integer * static_cast<uint64_t>(-1));
}

bool is_valid_int(const std::string &text) {
	// Counted in code points; every character must be a digit apart from one
	// leading sign (a lone sign is not a number).
	size_t index = 0;
	size_t count = 0;
	bool valid = true;
	bool first_is_sign = false;
	while (index < text.size()) {
		const uint32_t c = next_code_point(text, index);
		if (count == 0 && (c == '+' || c == '-')) {
			first_is_sign = true;
		} else if (!is_digit(c)) {
			valid = false;
		}
		++count;
	}
	if (count == 0) {
		return false;
	}
	if (count == 1 && first_is_sign) {
		return false;
	}
	return valid;
}

uint32_t string_hash(const std::string &utf8) {
	uint32_t hashv = 5381;
	size_t index = 0;
	while (index < utf8.size()) {
		const uint32_t c = next_code_point(utf8, index);
		if (c == 0) {
			break; // String::hash stops at the first NUL
		}
		hashv = ((hashv << 5) + hashv) + c;
	}
	return hashv;
}

Sha256::Sha256() {
	const uint32_t initial[8] = { 0x6a09e667, 0xbb67ae85, 0x3c6ef372, 0xa54ff53a, 0x510e527f, 0x9b05688c, 0x1f83d9ab, 0x5be0cd19 };
	std::memcpy(h_, initial, sizeof(h_));
}

void Sha256::block(const uint8_t *chunk) {
	uint32_t w[64];
	for (int i = 0; i < 16; ++i) {
		w[i] = (static_cast<uint32_t>(chunk[i * 4]) << 24) | (static_cast<uint32_t>(chunk[i * 4 + 1]) << 16) | (static_cast<uint32_t>(chunk[i * 4 + 2]) << 8) | static_cast<uint32_t>(chunk[i * 4 + 3]);
	}
	for (int i = 16; i < 64; ++i) {
		const uint32_t s0 = rotr(w[i - 15], 7) ^ rotr(w[i - 15], 18) ^ (w[i - 15] >> 3);
		const uint32_t s1 = rotr(w[i - 2], 17) ^ rotr(w[i - 2], 19) ^ (w[i - 2] >> 10);
		w[i] = w[i - 16] + s0 + w[i - 7] + s1;
	}
	uint32_t a = h_[0], b = h_[1], c = h_[2], d = h_[3], e = h_[4], f = h_[5], g = h_[6], h = h_[7];
	for (int i = 0; i < 64; ++i) {
		const uint32_t s1 = rotr(e, 6) ^ rotr(e, 11) ^ rotr(e, 25);
		const uint32_t ch = (e & f) ^ (~e & g);
		const uint32_t t1 = h + s1 + ch + kRoundConstants[i] + w[i];
		const uint32_t s0 = rotr(a, 2) ^ rotr(a, 13) ^ rotr(a, 22);
		const uint32_t maj = (a & b) ^ (a & c) ^ (b & c);
		const uint32_t t2 = s0 + maj;
		h = g;
		g = f;
		f = e;
		e = d + t1;
		d = c;
		c = b;
		b = a;
		a = t1 + t2;
	}
	h_[0] += a;
	h_[1] += b;
	h_[2] += c;
	h_[3] += d;
	h_[4] += e;
	h_[5] += f;
	h_[6] += g;
	h_[7] += h;
}

void Sha256::update(const uint8_t *data, size_t size) {
	length_ += static_cast<uint64_t>(size);
	while (size > 0) {
		const size_t take = (64 - buffered_) < size ? (64 - buffered_) : size;
		std::memcpy(buffer_ + buffered_, data, take);
		buffered_ += take;
		data += take;
		size -= take;
		if (buffered_ == 64) {
			block(buffer_);
			buffered_ = 0;
		}
	}
}

void Sha256::finish(uint8_t out[32]) {
	const uint64_t bit_length = length_ * 8;
	const uint8_t pad = 0x80;
	update(&pad, 1);
	const uint8_t zero = 0;
	while (buffered_ != 56) {
		update(&zero, 1);
	}
	uint8_t length_bytes[8];
	for (int i = 0; i < 8; ++i) {
		length_bytes[i] = static_cast<uint8_t>(bit_length >> (56 - 8 * i));
	}
	update(length_bytes, 8);
	for (int i = 0; i < 8; ++i) {
		out[i * 4] = static_cast<uint8_t>(h_[i] >> 24);
		out[i * 4 + 1] = static_cast<uint8_t>(h_[i] >> 16);
		out[i * 4 + 2] = static_cast<uint8_t>(h_[i] >> 8);
		out[i * 4 + 3] = static_cast<uint8_t>(h_[i]);
	}
}

std::string Sha256::finish_hex() {
	uint8_t out[32];
	finish(out);
	return hex_encode(out, 32);
}

void sha256(const uint8_t *data, size_t size, uint8_t out[32]) {
	Sha256 context;
	context.update(data, size);
	context.finish(out);
}

std::string sha256_text(const std::string &utf8) {
	uint8_t out[32];
	sha256(reinterpret_cast<const uint8_t *>(utf8.data()), utf8.size(), out);
	return hex_encode(out, 32);
}

std::string hex_encode(const uint8_t *data, size_t size) {
	static const char hex[16] = { '0', '1', '2', '3', '4', '5', '6', '7', '8', '9', 'a', 'b', 'c', 'd', 'e', 'f' };
	std::string text;
	text.resize(size * 2);
	for (size_t i = 0; i < size; ++i) {
		text[i * 2] = hex[data[i] >> 4];
		text[i * 2 + 1] = hex[data[i] & 0xF];
	}
	return text;
}

} // namespace aurelion::rules::compat
