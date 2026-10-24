// MapEditorShell's members that its rules share (Phase 7, slice 7.13): the
// working copy and the dirty flag, whose setters bump the edit revision, and
// the session values the rules pass around.

#include "aurelion_rules/port/map_editor.hpp"

namespace aurelion::rules::port::map_editor {

namespace key = state::key;
using state::Kind;

namespace {

// _editor_edit_revision += 1, as the setters of _session and _dirty do. The
// call's write-back sets the members in their declaration order, _session and
// _dirty before the revision, so the revision the C++ counted is the one the
// object keeps, whatever the setters counted on the way.
void bump_revision(State &state, const Value &editor) {
	const int64_t revision = gd::to_int(state, gd::member(state, editor, key::_editor_edit_revision));
	gd::set_member(state, editor, key::_editor_edit_revision, gd::int_value(gd::add(revision, 1)));
}

} // namespace

void set_session(State &state, const Value &editor, const Value &session) {
	gd::set_member(state, editor, key::_session, session_object(state, session));
	bump_revision(state, editor);
}

void set_dirty(State &state, const Value &editor, bool dirty) {
	gd::set_member(state, editor, key::_dirty, gd::bool_value(dirty));
	bump_revision(state, editor);
}

Value session(State &state, const Value &editor) {
	return gd::member(state, editor, key::_session);
}

DictRef session_view(State &state, const Value &session) {
	if (session.kind == Kind::Nil) {
		throw state::ScriptError("Invalid access to a property of a session that is null");
	}
	return gd::object_view(state, session);
}

Value session_object(State &state, const Value &session) {
	return session.kind == Kind::Dict ? gd::view_object(state, session.ref) : session;
}

} // namespace aurelion::rules::port::map_editor
