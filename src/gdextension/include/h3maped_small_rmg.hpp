#pragma once

#include <godot_cpp/variant/dictionary.hpp>

namespace godot::h3maped_small_rmg {

bool supports_scope(const Dictionary &normalized_config);
Dictionary selection_identity(const Dictionary &normalized_config);
Dictionary inspect_port(const Dictionary &normalized_config);
Dictionary generation_not_ready_result(const Dictionary &normalized_config, const Dictionary &extension_profile);
Dictionary validator_gated_generation_result(const Dictionary &normalized_config, const Dictionary &extension_profile);
Dictionary archived_legacy_disabled_result(const Dictionary &normalized_config, const Dictionary &extension_profile, const Dictionary &runtime_policy_classification);

} // namespace godot::h3maped_small_rmg
