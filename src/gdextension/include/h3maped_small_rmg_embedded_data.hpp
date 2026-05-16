#pragma once

#include <cstddef>

namespace godot::h3maped_small_rmg::embedded_data {

const char *random_map_template_catalog_json();
std::size_t random_map_template_catalog_json_size();
const char *object_catalog_by_type_json();
std::size_t object_catalog_by_type_json_size();
const char *decoration_obstacles_csv();
std::size_t decoration_obstacles_csv_size();
const char *reward_proxy_catalog_json();
std::size_t reward_proxy_catalog_json_size();
const char *monster_candidate_summary_json();
std::size_t monster_candidate_summary_json_size();

} // namespace godot::h3maped_small_rmg::embedded_data
