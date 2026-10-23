// JSON.stringify (JSON::_stringify) over the State's values; see
// aurelion_rules/compat/json_writer.hpp.

#include "aurelion_rules/compat/json_writer.hpp"

#include "aurelion_rules/compat/godot_string.hpp"
#include "aurelion_rules/port/gd.hpp"

#include <algorithm>
#include <vector>

namespace aurelion::rules::compat {

namespace {

using state::Kind;
using state::State;
using state::Value;

// StringLikeVariantOrder: String-likes by their text (UTF-8 byte order is code
// point order), anything else by Variant's <, its type first.
bool key_less(const State &state, const Value &a, const Value &b) {
	if (a.is_string_like() && b.is_string_like()) {
		return state.text(a.ref) < state.text(b.ref);
	}
	if (a.kind != b.kind) {
		return gd::type_of(a) < gd::type_of(b);
	}
	switch (a.kind) {
		case Kind::Int:
			return a.i < b.i;
		case Kind::Float:
			return a.f < b.f;
		case Kind::Bool:
			return !a.b && b.b;
		default:
			return false;
	}
}

} // namespace

void append_json_string(std::string &out, std::string_view text) {
	out += '"';
	for (const char c : text) {
		switch (c) {
			case '\\':
				out += "\\\\";
				break;
			case '\b':
				out += "\\b";
				break;
			case '\f':
				out += "\\f";
				break;
			case '\n':
				out += "\\n";
				break;
			case '\r':
				out += "\\r";
				break;
			case '\t':
				out += "\\t";
				break;
			case '\v':
				out += "\\v";
				break;
			case '"':
				out += "\\\"";
				break;
			default:
				out += c;
		}
	}
	out += '"';
}

std::string vector_text(const Value &value) {
	if (value.kind == Kind::Vector2i) {
		return "(" + itos(value.vx()) + ", " + itos(value.vy()) + ")";
	}
	return "(" + itos(value.vx()) + ", " + itos(value.vy()) + ", " + itos(value.vz()) + ")";
}

std::string key_text(const State &state, const Value &value) {
	switch (value.kind) {
		case Kind::String:
		case Kind::StringName:
			return state.text(value.ref);
		case Kind::Int:
			return itos(value.i);
		case Kind::Float:
			return num(value.f);
		case Kind::Bool:
			return value.b ? "true" : "false";
		case Kind::Nil:
			return "<null>";
		case Kind::Vector2i:
		case Kind::Vector3i:
			return vector_text(value);
		default:
			return gd::type_name(value);
	}
}

void JsonWriter::write(std::string &out, const Value &value, int depth) const {
	switch (value.kind) {
		case Kind::Nil:
		case Kind::Opaque:
			out += "null";
			return;
		case Kind::Bool:
			out += value.b ? "true" : "false";
			return;
		case Kind::Int:
			out += itos(value.i);
			return;
		case Kind::Float:
			out += json_float(value.f, full_precision);
			return;
		case Kind::String:
		case Kind::StringName:
			append_json_string(out, state.text(value.ref));
			return;
		case Kind::Vector2i:
		case Kind::Vector3i:
			append_json_string(out, vector_text(value));
			return;
		case Kind::Array: {
			const state::ValueList &items = state.array(value.ref).items;
			list(out, items.size(), depth, [&](size_t index) { write(out, items[index], depth + 1); });
			return;
		}
		case Kind::PackedByte:
		case Kind::PackedInt32:
		case Kind::PackedString: {
			const state::PackedNode &node = state.packed(value.ref);
			list(out, node.size(), depth, [&](size_t index) {
				if (node.kind == Kind::PackedByte) {
					out += itos(node.bytes[index]);
				} else if (node.kind == Kind::PackedInt32) {
					out += itos(node.ints[index]);
				} else {
					append_json_string(out, state.text(node.atoms[index]));
				}
			});
			return;
		}
		case Kind::Dict: {
			const state::DictNode &node = state.dict(value.ref);
			std::vector<size_t> order(node.keys.size());
			for (size_t index = 0; index < order.size(); ++index) {
				order[index] = index;
			}
			const state::ValueList &keys = node.keys.list();
			if (sort_keys) {
				std::sort(order.begin(), order.end(), [&](size_t a, size_t b) { return key_less(state, keys[a], keys[b]); });
			}
			if (order.empty()) {
				// An empty Array is "[]", an empty Dictionary its two
				// statement ends and its closing indent.
				out += '{';
				out += newline();
				out += newline();
				pad(out, depth);
				out += '}';
				return;
			}
			out += '{';
			out += newline();
			for (size_t index = 0; index < order.size(); ++index) {
				if (index > 0) {
					out += ',';
					out += newline();
				}
				pad(out, depth + 1);
				append_json_string(out, key_text(state, keys[order[index]]));
				out += indent.empty() ? ":" : ": ";
				write(out, node.values[order[index]], depth + 1);
			}
			out += newline();
			pad(out, depth);
			out += '}';
			return;
		}
	}
}

} // namespace aurelion::rules::compat
