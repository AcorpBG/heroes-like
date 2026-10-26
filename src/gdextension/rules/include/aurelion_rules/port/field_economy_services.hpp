#pragma once

#include "aurelion_rules/port/gd.hpp"

namespace aurelion::rules::port::field_economy_services {
bool handles(state::State &, gd::DictRef site);
bool available(state::State &, gd::DictRef session, gd::DictRef node, gd::DictRef site, gd::Atom owner, gd::DictRef visitor = 0);
gd::DictRef visit(state::State &, gd::DictRef session, gd::DictRef node_result, gd::DictRef site, bool refresh, gd::Atom choice);
gd::DictRef visit_ai(state::State &, gd::DictRef session, gd::DictRef raid, gd::DictRef empire, gd::Atom owner, gd::DictRef node_result, gd::DictRef site);
} // namespace aurelion::rules::port::field_economy_services
