#pragma once

// A session as a port gets it (scripts/core/DayEngine.gd builds it): its view,
// a Dictionary of SessionData's fields, the session's own overworld, battle and
// flags Dictionaries among them, with its metadata under "meta".

#include "aurelion_rules/port/gd.hpp"

namespace aurelion::rules::port::session_view {

// session.overworld: SessionData types it Dictionary.
inline gd::DictRef overworld(const state::State &state, gd::DictRef session) {
	return gd::as_dict(gd::field(state, session, state::key::overworld));
}

// The session's metadata: get_meta() and set_meta() read and write it.
inline gd::DictRef meta(const state::State &state, gd::DictRef session) {
	return gd::as_dict(gd::field(state, session, state::key::meta));
}

} // namespace aurelion::rules::port::session_view
