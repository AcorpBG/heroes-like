#include "aurelion_rules/port/registry.hpp"

#include <vector>

namespace aurelion::rules::port {

// Each defined in its subsystem's registry file.
Table day_table();

namespace {

// One line per subsystem: its table function, defined in the subsystem's
// registry file.
const std::vector<Table> &all_tables() {
	static const std::vector<Table> tables = {
		day_table(),
	};
	return tables;
}

const std::vector<Function> &all_functions() {
	static const std::vector<Function> functions = [] {
		std::vector<Function> joined;
		for (const Table &table : all_tables()) {
			joined.insert(joined.end(), table.functions, table.functions + table.count);
		}
		return joined;
	}();
	return functions;
}

} // namespace

const Table *tables(size_t &count) {
	count = all_tables().size();
	return all_tables().data();
}

const Function *functions(size_t &count) {
	count = all_functions().size();
	return all_functions().data();
}

const Function *find_function(std::string_view name) {
	for (const Function &function : all_functions()) {
		if (name == function.name) {
			return &function;
		}
	}
	return nullptr;
}

bool gdscript_only_static(uint32_t script, uint32_t name) {
	for (const Table &table : all_tables()) {
		for (size_t index = 0; index < table.gdscript_only_count; ++index) {
			if (table.gdscript_only[index].script == script && table.gdscript_only[index].name == name) {
				return true;
			}
		}
	}
	return false;
}

} // namespace aurelion::rules::port
