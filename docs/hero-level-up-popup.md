# Hero level-up popup

The adventure map automatically presents unreviewed hero promotions with the hero portrait, previous/current levels, earned command-stat and daily movement increases, and existing specialty offers. Multiple earned levels are summarized together; specialty choices are then resolved in queue order. Heroes who have mastered every specialty still receive a command-gain notice with Continue.

Chest and other adventure XP trigger the popup after their reward dialog closes. Battle XP uses the same progression state and appears on return to the map. Other modal UI and enemy-turn playback finish before a promotion opens. Town defenders are also reviewed without changing the selected hero, camera, route, or another hero's build.

Choose later, Escape, and the close button acknowledge the notification while retaining unchosen specialties in the hero commands. The per-hero `level_up_presented` field persists through saves; later gains trigger a new notice. Legacy saves with outstanding specialty choices receive one reminder; established heroes without pending choices do not replay old gains. Stale hero/level/choice callbacks are rejected, and repeated callbacks cannot spend a second choice.

`HeroProgressionRules` owns the summary and acknowledgment baseline. `OverworldRules` validates and applies choices using the existing specialty rules. `HeroLevelUpDialog` renders the modal and sends intents; `OverworldShell` schedules it and preserves exclusive input ownership. XP thresholds, rewards, and stat/specialty balance are unchanged. The UI uses existing art and platform-neutral Godot controls.

Focused verification: `tests/hero_level_up_regression.py --godot <Godot executable> --output .artifacts/hero_level_up`. The probe uses an isolated profile, bounded offscreen rendering on Windows, and the existing xvfb wrapper on Linux. It covers XP thresholds, multiple levels, saved acknowledgment, legacy/mastered heroes, stale callbacks, battle writeback, inactive defenders, chest-to-promotion UI, specialty buttons, Escape, and modal queuing. No full repository suite is required for this slice.

Validation on Windows/Godot 4.6.2: all 50 focused checks pass and the 1280x720 popup was visually reviewed. Temporary captures/logs are deleted after review and can be rebuilt with the probe. No full suite or Linux execution was performed.
