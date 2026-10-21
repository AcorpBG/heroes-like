#pragma once

#include <cstdint>
#include <string>

// The ai_search golden vectors and sweep (ai_search_selftest.cpp). False with
// the first difference in message. print_only skips the pinned sweep digest.
bool ai_search_selftest(bool print_only, std::string &message, int64_t &checked);
