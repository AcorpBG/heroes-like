#include "aurelion_rules/compat/godot_json.hpp"

#include <cstdint>
#include <string>

namespace aurelion::rules::compat {

namespace {

using state::State;
using state::Value;

constexpr int kOk = 0;
constexpr int kErrOutOfMemory = 6;
constexpr int kErrParseError = 43;
// Variant::MAX_RECURSION_DEPTH.
constexpr int kMaxRecursionDepth = 1024;
// String::_replacement_char, which append_utf32 puts for a NUL.
constexpr char32_t kReplacementChar = 0xfffd;

bool is_digit(char32_t c) {
	return c >= '0' && c <= '9';
}

bool is_hex_digit(char32_t c) {
	return is_digit(c) || (c >= 'a' && c <= 'f') || (c >= 'A' && c <= 'F');
}

bool is_ascii_alphabet_char(char32_t c) {
	return (c >= 'a' && c <= 'z') || (c >= 'A' && c <= 'Z');
}

[[noreturn]] void malformed(const char *what) {
	throw state::NotPorted(std::string("left to the engine: JSON text with ") + what + " (String::append_utf8 decodes it with replacement characters)");
}

// String::append_utf8 for well-formed UTF-8: the byte order mark skipped and
// the text ending at the first NUL byte, as the engine's loop stops there.
std::u32string decode_utf8(std::string_view bytes) {
	size_t at = 0;
	if (bytes.size() >= 3 && static_cast<uint8_t>(bytes[0]) == 0xef && static_cast<uint8_t>(bytes[1]) == 0xbb && static_cast<uint8_t>(bytes[2]) == 0xbf) {
		at = 3;
	}
	std::u32string out;
	out.reserve(bytes.size() - at);
	while (at < bytes.size()) {
		const uint8_t c = static_cast<uint8_t>(bytes[at]);
		if (c == 0) {
			break;
		}
		if (c < 0x80) {
			out.push_back(c);
			at += 1;
			continue;
		}
		size_t size = 0;
		uint32_t code = 0;
		uint32_t least = 0;
		if ((c & 0xe0) == 0xc0) {
			size = 2;
			code = c & 0x1f;
			least = 0x80;
		} else if ((c & 0xf0) == 0xe0) {
			size = 3;
			code = c & 0x0f;
			least = 0x800;
		} else if ((c & 0xf8) == 0xf0) {
			size = 4;
			code = c & 0x07;
			least = 0x10000;
		} else {
			malformed("an invalid UTF-8 lead byte");
		}
		if (at + size > bytes.size()) {
			malformed("a truncated UTF-8 sequence");
		}
		for (size_t k = 1; k < size; ++k) {
			const uint8_t next = static_cast<uint8_t>(bytes[at + k]);
			if ((next & 0xc0) != 0x80) {
				malformed("a bad UTF-8 continuation byte");
			}
			code = code << 6 | (next & 0x3f);
		}
		if (code < least || code > 0x10ffff || (code & 0xfffff800) == 0xd800) {
			malformed("an overlong, surrogate or out-of-range UTF-8 sequence");
		}
		out.push_back(static_cast<char32_t>(code));
		at += size;
	}
	return out;
}

void append_utf8(std::string &out, char32_t c) {
	if (c < 0x80) {
		out.push_back(static_cast<char>(c));
	} else if (c < 0x800) {
		out.push_back(static_cast<char>(0xc0 | (c >> 6)));
		out.push_back(static_cast<char>(0x80 | (c & 0x3f)));
	} else if (c < 0x10000) {
		out.push_back(static_cast<char>(0xe0 | (c >> 12)));
		out.push_back(static_cast<char>(0x80 | ((c >> 6) & 0x3f)));
		out.push_back(static_cast<char>(0x80 | (c & 0x3f)));
	} else {
		out.push_back(static_cast<char>(0xf0 | (c >> 18)));
		out.push_back(static_cast<char>(0x80 | ((c >> 12) & 0x3f)));
		out.push_back(static_cast<char>(0x80 | ((c >> 6) & 0x3f)));
		out.push_back(static_cast<char>(0x80 | (c & 0x3f)));
	}
}

enum TokenType {
	TK_CURLY_BRACKET_OPEN,
	TK_CURLY_BRACKET_CLOSE,
	TK_BRACKET_OPEN,
	TK_BRACKET_CLOSE,
	TK_IDENTIFIER,
	TK_STRING,
	TK_NUMBER,
	TK_COLON,
	TK_COMMA,
	TK_EOF,
};

const char *const kTokenName[] = {"'{'", "'}'", "'['", "']'", "identifier", "string", "number", "':'", "','", "EOF"};

struct Token {
	TokenType type = TK_EOF;
	// A string's or an identifier's text, as UTF-8.
	std::string text;
	double number = 0.0;
};

// JSON::_get_token, _parse_value, _parse_array and _parse_object.
class Parser {
public:
	Parser(State &state, const std::u32string &text) :
			state_(state), p_str_(text.c_str()), p_len_(static_cast<int>(text.size())) {}

	int index = 0;
	int line = 0;
	std::string err_str;

	int get_token(Token &r_token) {
		const char32_t *p_str = p_str_;
		while (p_len_ > 0) {
			switch (p_str[index]) {
				case '\n': {
					line++;
					index++;
					break;
				}
				case 0: {
					r_token.type = TK_EOF;
					return kOk;
				}
				case '{': {
					r_token.type = TK_CURLY_BRACKET_OPEN;
					index++;
					return kOk;
				}
				case '}': {
					r_token.type = TK_CURLY_BRACKET_CLOSE;
					index++;
					return kOk;
				}
				case '[': {
					r_token.type = TK_BRACKET_OPEN;
					index++;
					return kOk;
				}
				case ']': {
					r_token.type = TK_BRACKET_CLOSE;
					index++;
					return kOk;
				}
				case ':': {
					r_token.type = TK_COLON;
					index++;
					return kOk;
				}
				case ',': {
					r_token.type = TK_COMMA;
					index++;
					return kOk;
				}
				case '"': {
					index++;
					std::string str;
					while (true) {
						if (p_str[index] == 0) {
							err_str = "Unterminated string";
							return kErrParseError;
						} else if (p_str[index] == '"') {
							index++;
							break;
						} else if (p_str[index] == '\\') {
							// Escaped characters.
							index++;
							const char32_t next = p_str[index];
							if (next == 0) {
								err_str = "Unterminated string";
								return kErrParseError;
							}
							char32_t res = 0;
							switch (next) {
								case 'b':
									res = 8;
									break;
								case 't':
									res = 9;
									break;
								case 'n':
									res = 10;
									break;
								case 'f':
									res = 12;
									break;
								case 'r':
									res = 13;
									break;
								case 'u': {
									if (!hex4(index, res)) {
										return kErrParseError;
									}
									index += 4;
									if ((res & 0xfffffc00) == 0xd800) {
										if (p_str[index + 1] != '\\' || p_str[index + 2] != 'u') {
											err_str = "Invalid UTF-16 sequence in string, unpaired lead surrogate";
											return kErrParseError;
										}
										index += 2;
										char32_t trail = 0;
										if (!hex4(index, trail)) {
											return kErrParseError;
										}
										if ((trail & 0xfffffc00) == 0xdc00) {
											res = (res << 10UL) + trail - ((0xd800 << 10UL) + 0xdc00 - 0x10000);
											index += 4;
										} else {
											err_str = "Invalid UTF-16 sequence in string, unpaired lead surrogate";
											return kErrParseError;
										}
									} else if ((res & 0xfffffc00) == 0xdc00) {
										err_str = "Invalid UTF-16 sequence in string, unpaired trail surrogate";
										return kErrParseError;
									}
								} break;
								case '"':
								case '\\':
								case '/': {
									res = next;
								} break;
								default: {
									err_str = "Invalid escape sequence";
									return kErrParseError;
								}
							}
							// String::operator+= (append_utf32) puts the replacement
							// character for a NUL (with an error print, left out here).
							append_utf8(str, res == 0 ? kReplacementChar : res);
						} else {
							if (p_str[index] == '\n') {
								line++;
							}
							append_utf8(str, p_str[index]);
						}
						index++;
					}
					r_token.type = TK_STRING;
					r_token.text = std::move(str);
					return kOk;
				}
				default: {
					if (p_str[index] <= 32) {
						index++;
						break;
					}
					if (p_str[index] == '-' || is_digit(p_str[index])) {
						// A number.
						const char32_t *rptr = nullptr;
						const double number = to_float(&p_str[index], &rptr);
						index += static_cast<int>(rptr - &p_str[index]);
						r_token.type = TK_NUMBER;
						r_token.number = number;
						return kOk;
					} else if (is_ascii_alphabet_char(p_str[index])) {
						std::string id;
						while (is_ascii_alphabet_char(p_str[index])) {
							id.push_back(static_cast<char>(p_str[index]));
							index++;
						}
						r_token.type = TK_IDENTIFIER;
						r_token.text = std::move(id);
						return kOk;
					} else {
						err_str = "Unexpected character";
						return kErrParseError;
					}
				}
			}
		}
		err_str = "Unknown error getting token";
		return kErrParseError;
	}

	int parse_value(Value &value, Token &token, int p_depth) {
		if (p_depth > kMaxRecursionDepth) {
			err_str = "JSON structure is too deep";
			return kErrOutOfMemory;
		}
		if (token.type == TK_CURLY_BRACKET_OPEN) {
			const uint32_t d = state_.new_dict();
			const int err = parse_object(d, p_depth + 1);
			if (err) {
				return err;
			}
			value = Value::of_ref(state::Kind::Dict, d);
		} else if (token.type == TK_BRACKET_OPEN) {
			const uint32_t a = state_.new_array();
			const int err = parse_array(a, p_depth + 1);
			if (err) {
				return err;
			}
			value = Value::of_ref(state::Kind::Array, a);
		} else if (token.type == TK_IDENTIFIER) {
			const std::string &id = token.text;
			if (id == "true") {
				value = Value::of_bool(true);
			} else if (id == "false") {
				value = Value::of_bool(false);
			} else if (id == "null") {
				value = Value();
			} else {
				err_str = "Expected 'true', 'false', or 'null', got '" + id + "'";
				return kErrParseError;
			}
		} else if (token.type == TK_NUMBER) {
			value = Value::of_float(token.number);
		} else if (token.type == TK_STRING) {
			value = state_.string(token.text);
		} else {
			err_str = std::string("Expected value, got '") + kTokenName[token.type] + "'";
			return kErrParseError;
		}
		return kOk;
	}

private:
	State &state_;
	const char32_t *p_str_;
	int p_len_;

	// The four hex digits after index (a \u escape's), into res.
	bool hex4(int at, char32_t &res) {
		for (int j = 0; j < 4; j++) {
			const char32_t c = p_str_[at + j + 1];
			if (c == 0) {
				err_str = "Unterminated string";
				return false;
			}
			if (!is_hex_digit(c)) {
				err_str = "Malformed hex constant in string";
				return false;
			}
			char32_t v;
			if (is_digit(c)) {
				v = c - '0';
			} else if (c >= 'a' && c <= 'f') {
				v = c - 'a' + 10;
			} else {
				v = c - 'A' + 10;
			}
			res <<= 4;
			res |= v;
		}
		return true;
	}

	int parse_array(uint32_t array, int p_depth) {
		Token token;
		bool need_comma = false;
		while (index < p_len_) {
			int err = get_token(token);
			if (err != kOk) {
				return err;
			}
			if (token.type == TK_BRACKET_CLOSE) {
				return kOk;
			}
			if (need_comma) {
				if (token.type != TK_COMMA) {
					err_str = "Expected ','";
					return kErrParseError;
				}
				need_comma = false;
				continue;
			}
			Value v;
			err = parse_value(v, token, p_depth);
			if (err) {
				return err;
			}
			state_.append(array, v);
			need_comma = true;
		}
		err_str = "Expected ']'";
		return kErrParseError;
	}

	int parse_object(uint32_t object, int p_depth) {
		bool at_key = true;
		Value key;
		Token token;
		bool need_comma = false;
		while (index < p_len_) {
			if (at_key) {
				int err = get_token(token);
				if (err != kOk) {
					return err;
				}
				if (token.type == TK_CURLY_BRACKET_CLOSE) {
					return kOk;
				}
				if (need_comma) {
					if (token.type != TK_COMMA) {
						err_str = "Expected '}' or ','";
						return kErrParseError;
					}
					need_comma = false;
					continue;
				}
				if (token.type != TK_STRING) {
					err_str = "Expected key";
					return kErrParseError;
				}
				key = state_.string(token.text);
				err = get_token(token);
				if (err != kOk) {
					return err;
				}
				if (token.type != TK_COLON) {
					err_str = "Expected ':'";
					return kErrParseError;
				}
				at_key = false;
			} else {
				int err = get_token(token);
				if (err != kOk) {
					return err;
				}
				Value v;
				err = parse_value(v, token, p_depth);
				if (err) {
					return err;
				}
				state_.set(object, key, v);
				need_comma = true;
				at_key = true;
			}
		}
		err_str = "Expected '}'";
		return kErrParseError;
	}
};

} // namespace

JsonParse json_parse(State &state, std::string_view utf8) {
	const std::u32string text = decode_utf8(utf8);
	Parser parser(state, text);
	JsonParse out;
	const int len = static_cast<int>(text.size());
	// JSON::_parse_string.
	Token token;
	int err = parser.get_token(token);
	if (err == kOk) {
		Value data;
		err = parser.parse_value(data, token, 0);
		if (err == kOk) {
			out.data = data;
			if (parser.index < len) {
				err = parser.get_token(token);
				if (err || token.type != TK_EOF) {
					parser.err_str = "Expected 'EOF'";
					out.data = Value();
					err = kErrParseError;
				}
			}
		}
	}
	out.error = err;
	// JSON::parse: the line is 0 after a success.
	out.error_line = err == kOk ? 0 : parser.line;
	if (err != kOk) {
		out.error_message = parser.err_str;
	}
	return out;
}

double to_float(const char32_t *string, const char32_t **endPtr) {
	// built_in_strtod<char32_t>, as the engine has it.
	static const int maxExponent = 511;
	static const double powersOf10[] = {
		10.,
		100.,
		1.0e4,
		1.0e8,
		1.0e16,
		1.0e32,
		1.0e64,
		1.0e128,
		1.0e256
	};

	bool sign, expSign = false;
	double fraction, dblExp;
	const double *d;
	const char32_t *p;
	int c;
	int exp = 0;
	int fracExp = 0;
	int mantSize;
	int decPt;
	const char32_t *pExp;

	p = string;
	while (*p == ' ' || *p == '\t' || *p == '\n') {
		p += 1;
	}
	if (*p == '-') {
		sign = true;
		p += 1;
	} else {
		if (*p == '+') {
			p += 1;
		}
		sign = false;
	}

	decPt = -1;
	for (mantSize = 0;; mantSize += 1) {
		c = static_cast<int>(*p);
		if (!is_digit(static_cast<char32_t>(c))) {
			if ((c != '.') || (decPt >= 0)) {
				break;
			}
			decPt = mantSize;
		}
		p += 1;
	}

	pExp = p;
	p -= mantSize;
	if (decPt < 0) {
		decPt = mantSize;
	} else {
		mantSize -= 1;
	}
	if (mantSize > 18) {
		fracExp = decPt - 18;
		mantSize = 18;
	} else {
		fracExp = decPt - mantSize;
	}
	if (mantSize == 0) {
		fraction = 0.0;
		p = string;
		goto done;
	} else {
		int frac1, frac2;
		frac1 = 0;
		for (; mantSize > 9; mantSize -= 1) {
			c = static_cast<int>(*p);
			p += 1;
			if (c == '.') {
				c = static_cast<int>(*p);
				p += 1;
			}
			frac1 = 10 * frac1 + (c - '0');
		}
		frac2 = 0;
		for (; mantSize > 0; mantSize -= 1) {
			c = static_cast<int>(*p);
			p += 1;
			if (c == '.') {
				c = static_cast<int>(*p);
				p += 1;
			}
			frac2 = 10 * frac2 + (c - '0');
		}
		fraction = (1.0e9 * frac1) + frac2;
	}

	p = pExp;
	if ((*p == 'E') || (*p == 'e')) {
		p += 1;
		if (*p == '-') {
			expSign = true;
			p += 1;
		} else {
			if (*p == '+') {
				p += 1;
			}
			expSign = false;
		}
		if (!is_digit(*p)) {
			p = pExp;
			goto done;
		}
		while (is_digit(*p)) {
			exp = exp * 10 + static_cast<int>(*p - '0');
			p += 1;
		}
	}
	if (expSign) {
		exp = fracExp - exp;
	} else {
		exp = fracExp + exp;
	}

	if (exp < 0) {
		expSign = true;
		exp = -exp;
	} else {
		expSign = false;
	}

	if (exp > maxExponent) {
		// The engine also prints "Exponent too high"; this does not.
		exp = maxExponent;
	}
	dblExp = 1.0;
	for (d = powersOf10; exp != 0; exp >>= 1, ++d) {
		if (exp & 01) {
			dblExp *= *d;
		}
	}
	if (expSign) {
		fraction /= dblExp;
	} else {
		fraction *= dblExp;
	}

done:
	if (endPtr != nullptr) {
		*endPtr = p;
	}
	if (sign) {
		return -fraction;
	}
	return fraction;
}

} // namespace aurelion::rules::compat
