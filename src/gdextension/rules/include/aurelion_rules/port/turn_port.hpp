#pragma once

// What the AI turn port's files share (Phase 4) beyond ai_port.hpp.

#include "aurelion_rules/port/gd.hpp"

#include <cstdint>
#include <string>

namespace aurelion::rules::port::turn {

using state::State;
using state::Value;

// var rng := RandomNumberGenerator.new(); rng.seed = seed: a new generator
// whose state is the one Godot's seeding leaves (RandomPCG::seed, PCG's
// srandom with the default stream).
Value seeded_rng(State &state, int64_t seed);

// OS.get_environment(name): the process's variable, or "" when unset.
std::string environment(const char *name);

} // namespace aurelion::rules::port::turn
