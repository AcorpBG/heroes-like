cmake_minimum_required(VERSION 3.22)
project(aurelion_rules LANGUAGES CXX)

# The game's rules in C++ (docs/native-rules-engine-transition.md). A project of
# its own, so a rules change never rebuilds the map generator, and its flags
# apply to this tree only.
#
#   aurelion_rules_core  pure std:: core, compiled once per tree
#   aurelion_rules       the GDExtension (src/gdextension/rules.gdextension)
#   rules_selftest       golden vectors without Godot

set(CMAKE_CXX_STANDARD 17)
set(CMAKE_CXX_STANDARD_REQUIRED ON)
set(CMAKE_CXX_EXTENSIONS OFF)

get_property(AURELION_MULTI_CONFIG GLOBAL PROPERTY GENERATOR_IS_MULTI_CONFIG)
if(NOT AURELION_MULTI_CONFIG AND NOT CMAKE_BUILD_TYPE)
	set(CMAKE_BUILD_TYPE RelWithDebInfo CACHE STRING "Build type" FORCE)
endif()

# Both flavours are optimized alike and keep debug info, which the build
# scripts archive outside git (tools/build_native.py). Release and
# RelWithDebInfo compile the same code; only the godot-cpp flavour differs.
# No fast-math, no FMA contraction, no -march: results must match on MSVC, GCC
# and MinGW.
if(MSVC)
	set(AURELION_RULES_OPT_FLAGS "/O2 /Ob2 /DNDEBUG /Zi /fp:precise")
else()
	set(AURELION_RULES_OPT_FLAGS "-O2 -g -DNDEBUG -ffp-contract=off")
endif()
foreach(AURELION_CONFIG RELEASE RELWITHDEBINFO MINSIZEREL)
	set(CMAKE_CXX_FLAGS_${AURELION_CONFIG} "${AURELION_RULES_OPT_FLAGS}")
	if(MSVC)
		# A PDB in both flavours, without the incremental-link padding.
		set(CMAKE_SHARED_LINKER_FLAGS_${AURELION_CONFIG} "/DEBUG:FULL /INCREMENTAL:NO /OPT:REF /OPT:ICF")
		set(CMAKE_EXE_LINKER_FLAGS_${AURELION_CONFIG} "/DEBUG:FULL /INCREMENTAL:NO /OPT:REF /OPT:ICF")
	endif()
endforeach()

set(AURELION_GODOTCPP_TARGET "template_debug" CACHE STRING "godot-cpp flavour: template_debug or template_release")
set_property(CACHE AURELION_GODOTCPP_TARGET PROPERTY STRINGS "template_debug;template_release")
if(NOT AURELION_GODOTCPP_TARGET STREQUAL "template_debug" AND NOT AURELION_GODOTCPP_TARGET STREQUAL "template_release")
	message(FATAL_ERROR "AURELION_GODOTCPP_TARGET must be template_debug or template_release, got '${AURELION_GODOTCPP_TARGET}'.")
endif()
set(GODOTCPP_TARGET "${AURELION_GODOTCPP_TARGET}" CACHE STRING "godot-cpp flavour" FORCE)
# The adapter catches every exception the core throws, so the STL must keep
# them (godot-cpp turns them off by default, _HAS_EXCEPTIONS=0 on MSVC).
set(GODOTCPP_DISABLE_EXCEPTIONS OFF CACHE BOOL "Keep C++ exceptions for the rules adapter" FORCE)

set(AURELION_PROJECT_ROOT "${CMAKE_CURRENT_LIST_DIR}/../../.." CACHE PATH "Godot project root.")
get_filename_component(AURELION_PROJECT_ROOT "${AURELION_PROJECT_ROOT}" ABSOLUTE)
set(AURELION_RULES_SOURCE_TREE "" CACHE STRING "Tree id of src/gdextension/rules when building from an archive without .git")
include("${CMAKE_CURRENT_LIST_DIR}/../cmake/AurelionGodotCpp.cmake")
aurelion_resolve_godot_cpp_root("${AURELION_PROJECT_ROOT}" AURELION_GODOT_CPP_ROOT)
set(AURELION_GODOT_CPP_COMMIT "" CACHE STRING "godot-cpp commit when building from an archive without .git")
set(AURELION_GODOT_CPP_COMMIT_RESOLVED "${AURELION_GODOT_CPP_COMMIT}")
if(AURELION_GODOT_CPP_COMMIT_RESOLVED STREQUAL "")
	find_package(Git QUIET)
	if(GIT_FOUND)
		execute_process(
			COMMAND "${GIT_EXECUTABLE}" -C "${AURELION_GODOT_CPP_ROOT}" rev-parse HEAD
			OUTPUT_VARIABLE AURELION_GODOT_CPP_COMMIT_RESOLVED OUTPUT_STRIP_TRAILING_WHITESPACE
			RESULT_VARIABLE AURELION_GODOT_CPP_COMMIT_RESULT ERROR_QUIET)
		if(NOT AURELION_GODOT_CPP_COMMIT_RESULT EQUAL 0)
			set(AURELION_GODOT_CPP_COMMIT_RESOLVED "")
		endif()
	endif()
endif()
if(AURELION_GODOT_CPP_COMMIT_RESOLVED STREQUAL "")
	set(AURELION_GODOT_CPP_COMMIT_RESOLVED "unknown")
endif()

if(NOT MSVC)
	# No build paths in the binaries: the same sources give the same bytes in
	# any directory. The last matching map wins, so the innermost comes last.
	string(APPEND CMAKE_CXX_FLAGS " -ffile-prefix-map=${AURELION_PROJECT_ROOT}/= -ffile-prefix-map=${AURELION_GODOT_CPP_ROOT}/=godot-cpp/ -ffile-prefix-map=${CMAKE_BINARY_DIR}/=build/")
endif()

# godot-cpp first: it sets the MSVC runtime the targets below inherit.
add_subdirectory("${AURELION_GODOT_CPP_ROOT}" "${CMAKE_CURRENT_BINARY_DIR}/godot-cpp")

set(AURELION_RULES_GENERATED_DIR "${CMAKE_CURRENT_BINARY_DIR}/generated")
add_custom_target(aurelion_rules_source_tree
	COMMAND "${CMAKE_COMMAND}"
		"-DROOT=${AURELION_PROJECT_ROOT}"
		"-DOUT=${AURELION_RULES_GENERATED_DIR}/aurelion_rules_source_tree.hpp"
		"-DOVERRIDE=${AURELION_RULES_SOURCE_TREE}"
		-P "${CMAKE_CURRENT_LIST_DIR}/cmake/source_tree.cmake"
	WORKING_DIRECTORY "${CMAKE_CURRENT_BINARY_DIR}"
	BYPRODUCTS "${AURELION_RULES_GENERATED_DIR}/aurelion_rules_source_tree.hpp"
	COMMENT "Rules source tree id"
	VERBATIM)

add_library(aurelion_rules_core STATIC
	core/ai_search.cpp
	core/battle_hex.cpp
	core/battle_state.cpp
	core/build_info.cpp
	core/compat/godot_string.cpp
	core/port/ability_helpers.cpp
	core/port/action_playback.cpp
	core/port/action_pressure.cpp
	core/port/ai_battle_preview.cpp
	core/port/ai_hero_rules.cpp
	core/port/ai_hero_rules_candidates.cpp
	core/port/ai_hero_rules_defense.cpp
	core/port/ai_hero_rules_entries.cpp
	core/port/ai_hero_rules_knowledge.cpp
	core/port/ai_hero_rules_power.cpp
	core/port/ai_hero_rules_regions.cpp
	core/port/ai_hero_rules_routes.cpp
	core/port/ai_hero_rules_search.cpp
	core/port/ai_hero_rules_sight.cpp
	core/port/ai_hero_rules_surface.cpp
	core/port/ai_hero_rules_values.cpp
	core/port/ai_hero_rules_war.cpp
	core/port/ai_port.cpp
	core/port/ai_registry.cpp
	core/port/artifact_rules.cpp
	core/port/attack_effects.cpp
	core/port/attack_events.cpp
	core/port/battle_aftermath.cpp
	core/port/battle_ai_abilities.cpp
	core/port/battle_ai_attack_scores.cpp
	core/port/battle_ai_contextual.cpp
	core/port/battle_ai_decisions.cpp
	core/port/battle_ai_estimates.cpp
	core/port/battle_ai_modifiers.cpp
	core/port/battle_ai_payloads.cpp
	core/port/battle_ai_reads.cpp
	core/port/battle_ai_rules.cpp
	core/port/battle_ai_spell_choice.cpp
	core/port/battle_ai_spell_scores.cpp
	core/port/battle_auto_resolve.cpp
	core/port/battle_commanders.cpp
	core/port/battle_context.cpp
	core/port/battle_context_aftermath.cpp
	core/port/battle_damage_rules_ai.cpp
	core/port/battle_end_heroes.cpp
	core/port/battle_end_sites.cpp
	core/port/battle_end_towns.cpp
	core/port/battle_finalize.cpp
	core/port/battle_footprint.cpp
	core/port/battle_forces.cpp
	core/port/battle_payload.cpp
	core/port/battle_rules.cpp
	core/port/battle_rules_ai.cpp
	core/port/battle_stacks.cpp
	core/port/board_setup.cpp
	core/port/commander_payload.cpp
	core/port/common_mine_rules.cpp
	core/port/consequence_previews.cpp
	core/port/content_service_ai.cpp
	core/port/creature_dwelling_rules_ai.cpp
	core/port/damage_modifiers.cpp
	core/port/damage_pressure.cpp
	core/port/damage_stream.cpp
	core/port/day_boundary.cpp
	core/port/day_economy.cpp
	core/port/day_registry.cpp
	core/port/difficulty_rules.cpp
	core/port/difficulty_rules_ai.cpp
	core/port/enemy_adventure_rules.cpp
	core/port/enemy_adventure_rules_ai.cpp
	core/port/enemy_orders.cpp
	core/port/enemy_states.cpp
	core/port/enemy_turn.cpp
	core/port/enemy_turn_rules.cpp
	core/port/fog.cpp
	core/port/gd.cpp
	core/port/hero_command_rules.cpp
	core/port/hero_command_rules_ai.cpp
	core/port/hero_commit.cpp
	core/port/hero_progression_rules.cpp
	core/port/mine_rules.cpp
	core/port/mine_rules_ai.cpp
	core/port/move_orders.cpp
	core/port/movement.cpp
	core/port/native_transit_rules.cpp
	core/port/native_transit_rules_ai.cpp
	core/port/overworld_forecast.cpp
	core/port/overworld_level_rules.cpp
	core/port/overworld_level_rules_ai.cpp
	core/port/overworld_normalize.cpp
	core/port/overworld_rules.cpp
	core/port/overworld_rules_ai_economy.cpp
	core/port/overworld_rules_ai_logistics.cpp
	core/port/overworld_rules_ai_lookup.cpp
	core/port/overworld_rules_ai_market.cpp
	core/port/overworld_rules_ai_recovery.cpp
	core/port/overworld_rules_ai_sites.cpp
	core/port/overworld_rules_ai_towns.cpp
	core/port/overworld_state_normalize.cpp
	core/port/overworld_towns_normalize.cpp
	core/port/overworld_transit_normalize.cpp
	core/port/player_elimination.cpp
	core/port/player_identity_rules.cpp
	core/port/player_identity_rules_ai.cpp
	core/port/player_orders.cpp
	core/port/presentation.cpp
	core/port/registry.cpp
	core/port/registry_tables.cpp
	core/port/resource_node_payload_rules_ai.cpp
	core/port/round_effects.cpp
	core/port/scenario_evaluation.cpp
	core/port/scenario_factory_ai.cpp
	core/port/spell_battle.cpp
	core/port/spell_effects.cpp
	core/port/spell_events.cpp
	core/port/spell_rules.cpp
	core/port/spell_rules_ai.cpp
	core/port/spell_summaries.cpp
	core/port/stack_effects.cpp
	core/port/stat_totals.cpp
	core/port/target_selection.cpp
	core/port/town_development_rules_ai.cpp
	core/port/town_rules_ai.cpp
	core/port/turn_forecast.cpp
	core/port/turn_order.cpp
	core/port/unit_abilities.cpp
	core/port/visit_building_rules_ai.cpp
	core/port/water_travel_rules_ai.cpp
)
add_dependencies(aurelion_rules_core aurelion_rules_source_tree)
target_include_directories(aurelion_rules_core PUBLIC include PRIVATE "${AURELION_RULES_GENERATED_DIR}")
target_compile_definitions(aurelion_rules_core PRIVATE "AURELION_GODOT_CPP_COMMIT=\"${AURELION_GODOT_CPP_COMMIT_RESOLVED}\"")
set_target_properties(aurelion_rules_core PROPERTIES POSITION_INDEPENDENT_CODE ON)

add_library(aurelion_rules SHARED
	gdextension/register_types.cpp
	gdextension/aurelion_rules_api.cpp
	gdextension/battle_port_bridge.cpp
	gdextension/battle_state_bridge.cpp
)
target_link_libraries(aurelion_rules PRIVATE aurelion_rules_core godot::cpp)
target_compile_definitions(aurelion_rules PRIVATE "AURELION_RULES_FLAVOUR=\"${AURELION_GODOTCPP_TARGET}\"")
get_target_property(AURELION_GODOT_CPP_INCLUDES godot::cpp INTERFACE_INCLUDE_DIRECTORIES)
if(AURELION_GODOT_CPP_INCLUDES)
	target_include_directories(aurelion_rules SYSTEM PRIVATE ${AURELION_GODOT_CPP_INCLUDES})
endif()

add_executable(rules_selftest
	selftest/ai_search_selftest.cpp
	selftest/rules_selftest.cpp
	selftest/compat_fuzz.cpp
)
target_link_libraries(rules_selftest PRIVATE aurelion_rules_core)

# The G1 replay of the battle port (tools/battle_port_g1): captured calls, native
# only. Built on request, stays in the build tree.
add_executable(battle_port_replay g1/battle_port_replay.cpp)
target_link_libraries(battle_port_replay PRIVATE aurelion_rules_core)

foreach(AURELION_RULES_TARGET aurelion_rules_core aurelion_rules rules_selftest battle_port_replay)
	if(MSVC)
		target_compile_options(${AURELION_RULES_TARGET} PRIVATE /W4)
	else()
		target_compile_options(${AURELION_RULES_TARGET} PRIVATE -Wall -Wextra)
	endif()
endforeach()

if(WIN32 AND NOT MSVC)
	target_link_options(rules_selftest PRIVATE -static -static-libgcc -static-libstdc++)
endif()

if(CMAKE_SYSTEM_NAME STREQUAL "Linux")
	set(AURELION_GODOT_PLATFORM "linux")
	set(AURELION_OUTPUT_PREFIX "lib")
elseif(CMAKE_SYSTEM_NAME STREQUAL "Windows" OR WIN32)
	set(AURELION_GODOT_PLATFORM "windows")
	set(AURELION_OUTPUT_PREFIX "")
else()
	message(FATAL_ERROR "Unsupported GDExtension target platform '${CMAKE_SYSTEM_NAME}'.")
endif()

set(AURELION_BIN_OUTPUT_DIR "${AURELION_PROJECT_ROOT}/bin")
set_target_properties(aurelion_rules PROPERTIES
	PREFIX "${AURELION_OUTPUT_PREFIX}"
	OUTPUT_NAME "aurelion_rules.${AURELION_GODOT_PLATFORM}.${AURELION_GODOTCPP_TARGET}.x86_64"
)
foreach(AURELION_RULES_OUTPUT aurelion_rules rules_selftest)
	set_target_properties(${AURELION_RULES_OUTPUT} PROPERTIES
		LIBRARY_OUTPUT_DIRECTORY "${AURELION_BIN_OUTPUT_DIR}"
		RUNTIME_OUTPUT_DIRECTORY "${AURELION_BIN_OUTPUT_DIR}"
		PDB_OUTPUT_DIRECTORY "${AURELION_BIN_OUTPUT_DIR}"
	)
	foreach(AURELION_CONFIG DEBUG RELEASE RELWITHDEBINFO MINSIZEREL)
		set_target_properties(${AURELION_RULES_OUTPUT} PROPERTIES
			LIBRARY_OUTPUT_DIRECTORY_${AURELION_CONFIG} "${AURELION_BIN_OUTPUT_DIR}"
			RUNTIME_OUTPUT_DIRECTORY_${AURELION_CONFIG} "${AURELION_BIN_OUTPUT_DIR}"
			PDB_OUTPUT_DIRECTORY_${AURELION_CONFIG} "${AURELION_BIN_OUTPUT_DIR}"
		)
	endforeach()
endforeach()
# Import libraries and exports stay in the build tree, not in bin/.
set_target_properties(aurelion_rules PROPERTIES ARCHIVE_OUTPUT_DIRECTORY "${CMAKE_CURRENT_BINARY_DIR}/lib")
foreach(AURELION_CONFIG DEBUG RELEASE RELWITHDEBINFO MINSIZEREL)
	set_target_properties(aurelion_rules PROPERTIES ARCHIVE_OUTPUT_DIRECTORY_${AURELION_CONFIG} "${CMAKE_CURRENT_BINARY_DIR}/lib")
endforeach()
