#pragma once

// pow(), exp() and log() for every copy of the rules (decision D4, option B,
// 2026-10-23): ARM's optimized-routines (third_party/arm_optimized_routines),
// built on its generic paths, so the game, the match runner and every compiler
// and platform give the same bits. The C runtimes do not: the engine's MinGW,
// MSVC's UCRT and glibc round some results differently in the last bit. The
// GDScript copies that still compute a rule call these too
// (AurelionRules.math_pow).

extern "C" {
double arm_math_pow(double x, double y);
double arm_math_exp(double x);
double arm_math_log(double x);
}

namespace aurelion::rules::compat {

inline double portable_pow(double base, double exponent) { return arm_math_pow(base, exponent); }
inline double portable_exp(double x) { return arm_math_exp(x); }
inline double portable_log(double x) { return arm_math_log(x); }

} // namespace aurelion::rules::compat
