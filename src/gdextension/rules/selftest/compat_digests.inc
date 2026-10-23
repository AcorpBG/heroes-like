// The engine's digests for the engine-exact helpers: the official Godot 4.6.2-stable
// builds running tools/rules_compat/capture_vectors.gd (2026-10-20, Windows 10
// and Ubuntu 24.04). Regenerate only when that file and compat_fuzz.cpp change
// together.
//
// The two official builds agree on every helper but round(): the Windows build
// (MinGW) answers +-1 for +-0.49999999999999994 and the Linux build (glibc) +-0,
// so float_round has one digest per platform (godot_math.hpp, godot_round). A
// MinGW build of the self-test under Wine checks the Windows one.
//
// Their float text differs too: the Windows build prints through msvcrt.dll,
// the Linux build through glibc (godot_string.hpp, num). json_float has the
// Windows digest (captured 2026-10-23, Windows 10); the Linux one is captured
// in the Linux pass, and until then the Linux self-test reports it missing.
//
// json_parse (captured 2026-10-23, Windows 10) is plain double arithmetic in
// the engine's own strtod, so both platforms share its digest.
//
// portable_math is not the engine's: it is the core's own pow, exp and log
// (compat/portable_math.hpp, decision D4 option B), pinned from the MSVC build
// of 2026-10-23. Every build must give it; the Linux pass checks GCC and MinGW.

struct CompatExpected {
	const char *helper;
	const char *sha256;
};

constexpr int64_t kCompatCount = 1 << 20;

constexpr CompatExpected kCompatExpected[] = {
	{ "pcg", "be75773c1adfce439f87569e7aae6902e002d4a4a619f429c1e7e53f7326506b" },
	{ "int_text", "57fa68456336c424d5aa00a9782e0d2f99b4a759c2296e14f9a11e755b076b95" },
	{ "string", "fd1907f163b2c679454b69f1f8a846d86a6fc2fe650edbdec707ceb6d502419e" },
	{ "posmod", "e39d4ada98eb6b887dba94b2c3b1675f258398a262ba83d085ef253a89638f8a" },
	{ "int_div", "7ea934fc74d9f7d76943cf238e6799a6236d9077bbdfa8ba9a39290b0cfd67f5" },
#ifdef _WIN32
	{ "float_round", "73b7410c43d6fc9283d80636e3d4b679d53432afedece9db348dfd09514044f2" },
#else
	{ "float_round", "59f6bb5969c6b831f6e97c262029a89b9fe89df2862b95adea3b6688f20afe2f" },
#endif
	{ "snapped", "155441e46fa42754d0b8f4c8dcfd3c41bbcf362d282de991e1735e9540f43722" },
	{ "variant_minmax", "278cf3d6c53fea7977cad2b1c4aa2e64d3b0ade64633336e9cd53a830356815c" },
	{ "typed_minmax", "9825aee45c61ddea540e22aa16c3eb8fe109c2177cef193327e4db723f48b4c7" },
	{ "sort", "42d87a139039f1a35597a10bfc40d827fef650d51328872dbf937f7d8bf601ef" },
#ifdef _WIN32
	{ "json_float", "4666bda411d8a7292df57b30b27644aad906b6b11d4677180d43063e4f6df669" },
#endif
	{ "json_parse", "ba995e47e94d2eef67b588ffd573047bd81d6f48771d9312e52e62a409a6d218" },
	{ "portable_math", "103a007b8c1148c6853233d64162f3d72d82a2a16be250ca4d6807644faa6bad" },
};
