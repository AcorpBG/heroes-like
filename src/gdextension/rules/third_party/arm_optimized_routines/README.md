# Arm optimized-routines: pow, exp and log

The double-precision `pow`, `exp` and `log` of Arm's optimized-routines, the only ones the rules use (decision D4,
option B, owner decision 2026-10-23; `docs/native-rules-engine-transition.md`, Phase 8, P8-2). The core reaches them
through `aurelion_rules/compat/portable_math.hpp`; the GDScript copies that still compute a rule call
`AurelionRules.math_pow`.

- **Source:** https://github.com/ARM-software/optimized-routines, tag `v26.07` (released 2026-07-29), commit
  `4be260a5117480382690c6d8c300bc784e927d76`, directory `math/`.
- **Licence:** `MIT OR Apache-2.0 WITH LLVM-exception`, used here under the MIT licence. `LICENSE` is upstream's file,
  unchanged (both texts). Copyright Arm Limited: the notices in `LICENSE` and in each file's header stay as they are.

## Files

Upstream SHA-256 of each file before the local changes:

| File | SHA-256 (v26.07) |
|---|---|
| `LICENSE` | `650afbf29f214451e02241adc42534e82c9d6ae2b38e2444b92b5a1ffcaf9346` |
| `math/exp.c` | `219b5f666c84864e80ef5ef33bc5453b4702ea74fc5cbf997c3dfacdcf5738cf` |
| `math/exp_data.c` | `a5e84677e7693c7d22195f86faac5fdc6f92bff7ea2e54c0e7888203a78ffc24` |
| `math/log.c` | `10e3774a72279c75d3842bc651a9d81e8fe31f9717caac736a603170ed509530` |
| `math/log_data.c` | `327cf1819870930486eecb5491c68d5887a712b954e5ec82f3f70bfd9e46fdd3` |
| `math/math_config.h` | `9a3ee029ba2b58444fafb51427bf0dc390d117f26115cd5a7033a5cc03042881` |
| `math/math_err.c` | `202a5f0b4983da16567bf707b8da02f9c1aa84bfaf1e9e2931009153b4a86676` |
| `math/pow.c` | `4497df6d64e0043c04df2cb308ae2918922b0f53e10f133006fba4e9eb5e8fb7` |
| `math/pow_common.h` | `367906e9face47b4ad4b3c08cae7d3d5b6737d9462881ce1a5fdbebd1f0e9325` |
| `math/pow_log_data.c` | `d28818bd95355e6854766a3818a6ec0866f7afcef592fe1e836d05d3f465392e` |

## Local changes

Only `exp.c`, `log.c` and `pow.c` differ from upstream:

1. The entry points are renamed `arm_math_exp`, `arm_math_log` and `arm_math_pow`, so they never replace the C
   runtime's `exp`, `log` and `pow` in the same binary.
2. The test-harness lines are removed (`#include "test_defs.h"`, `#include "test_sig.h"` and the `TEST_*` lines at
   the end), and so are the `#if USE_GLIBC_ABI` blocks of glibc aliases.
3. `exp.c`: `r += xtail;` runs without its `__builtin_constant_p` guard, which MSVC does not have. The guard only
   skipped adding a constant `0.0`, which leaves the result as it is.

## Build

`aurelion_rules_math` in `src/gdextension/rules/CMakeLists.txt` compiles these files as C11 with the rules' flags (no
fast-math; `/fp:precise` on MSVC, `-ffp-contract=off` on GCC and MinGW) and with `HAVE_FAST_FMA=0`,
`HAVE_FAST_ROUND=0`, `HAVE_FAST_LROUND=0`, `WANT_ROUNDING=1`, `WANT_ERRNO=0` and `USE_GLIBC_ABI=0`. That pins the
generic paths without fused multiply-add or rounding instructions, so MSVC, GCC and MinGW on x86-64 (and an ARM64
build) compute the same bits. `rules_selftest` checks it: its `portable_math` digest covers 2^20 rounds of the game's
input ranges and arbitrary floats and must be the same on every build.

Upstream's worst-case errors without FMA: `exp` 0.511 ULP, `log` about 0.52 ULP, `pow` 0.54 ULP.

## Why this and not CORE-MATH

The game needs the same bits in every build, not correct rounding. CORE-MATH's results are correctly rounded, but its
double `pow`, `exp` and `log` are written for GCC and Clang (`__builtin_fma`, 128-bit integers, `x86intrin.h`), which
MSVC, the compiler of the Windows build, does not have, and its `pow.c` alone is about 2,000 lines. Arm's routines are
portable C99 that MSVC compiles with the three changes above, seven small files, and the same code that glibc, musl,
Bionic and newlib ship.

## Updating

Take the same files from a newer tag, apply the three changes again, rebuild, and run `rules_selftest`. A changed
`portable_math` digest means the results changed: that is a behaviour change of the rules, merged as its own step with
the six-seed check against main, like D4 itself.
