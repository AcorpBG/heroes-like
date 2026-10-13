extends RefCounted
## Scripts that load on first use instead of being preloaded.
##
## A preload compiles its script, and everything that script preloads, when the
## owning script loads. Autoloads load before the boot screen can draw, so they
## reach the large rules scripts through here. Holding the reference keeps a
## static-only script from being freed and compiled again by the next load().

static var _scripts: Dictionary = {}


static func load_once(path: String) -> Script:
	var script: Script = _scripts.get(path)
	if script == null:
		script = load(path)
		_scripts[path] = script
	return script
