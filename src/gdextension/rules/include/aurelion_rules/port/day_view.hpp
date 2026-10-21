#pragma once

// A session as the day port gets it (scripts/core/DayEngine.gd): its view, a
// Dictionary of SessionData's fields, the session's own overworld, battle and
// flags Dictionaries among them, with its metadata under "meta".

#include "aurelion_rules/port/gd.hpp"

namespace aurelion::rules::port::day_view {

// session.overworld: SessionData types it Dictionary.
inline gd::DictRef overworld(const state::State &state, gd::DictRef session) {
	return gd::as_dict(gd::field(state, session, state::key::overworld));
}

} // namespace aurelion::rules::port::day_view
