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

// session.get_instance_id(): the view's "instance_id", which DayEngine.gd's
// views carry (the read scopes key their caches by it).
inline int64_t instance_id(const state::State &state, gd::DictRef session) {
	state::Value id;
	if (!state.lookup(session, gd::str(state::key::instance_id), id) || id.kind != state::Kind::Int) {
		throw state::NotPorted("session.get_instance_id() of a view without the session's instance_id");
	}
	return id.i;
}

} // namespace aurelion::rules::port::session_view
