#pragma once

#include "aurelion_rules/port/gd.hpp"

namespace aurelion::rules::port::adventure_services {
using state::State;
using gd::Atom;
using gd::DictRef;

void apply_intelligence(State &state, DictRef context, gd::PackedRef tiles, int64_t level);
bool handles(State &state, DictRef site);
bool available(State &state, DictRef session, DictRef node, DictRef site, Atom controller, DictRef visitor = 0);
DictRef visit(State &state, DictRef session, DictRef node_result, DictRef site, bool refresh, Atom choice);
DictRef visit_ai(State &state, DictRef session, DictRef raid, DictRef empire, Atom controller, DictRef node_result, DictRef site);
} // namespace aurelion::rules::port::adventure_services
