# Complete audio generation checklist

Source: `generation-queue.csv`. All items are ungenerated. P0 replaces nonfinal assets; P1 adds production variety; P2 is deferred/optional breadth. Counts are edited deliverable files, not model calls. Detailed prompts, current cue IDs, integration dependencies and source refs are in the CSV.

## P0

### Ambience

- [ ] `ambient_day_pulse` — Day_Pulse ambience; 1 file(s); 45-90 s each; loop.
- [ ] `ambient_dirt` — Dirt ambience; 1 file(s); 45-90 s each; loop.
- [ ] `ambient_grass` — Grass ambience; 1 file(s); 45-90 s each; loop.
- [ ] `ambient_lava` — Lava ambience; 1 file(s); 45-90 s each; loop.
- [ ] `ambient_mire` — Mire ambience; 1 file(s); 45-90 s each; loop.
- [ ] `ambient_pressure` — Pressure ambience; 1 file(s); 45-90 s each; loop.
- [ ] `ambient_rough` — Rough ambience; 1 file(s); 45-90 s each; loop.
- [ ] `ambient_sand` — Sand ambience; 1 file(s); 45-90 s each; loop.
- [ ] `ambient_snow` — Snow ambience; 1 file(s); 45-90 s each; loop.
- [ ] `ambient_underground` — Underground ambience; 1 file(s); 45-90 s each; loop.
- [ ] `ambient_water` — Water ambience; 1 file(s); 45-90 s each; loop.

### Battle

- [ ] `replace_audio_placeholder_cast` — Cast; 1 file(s); 0.22 s each; one-shot.
- [ ] `replace_audio_placeholder_defend` — Defend; 1 file(s); 0.1 s each; one-shot.
- [ ] `replace_audio_placeholder_hit` — Hit; 1 file(s); 0.1 s each; one-shot.
- [ ] `replace_audio_placeholder_idle_soft` — Idle Soft; 1 file(s); 0.07 s each; one-shot.
- [ ] `replace_audio_placeholder_melee_release` — Melee Release; 1 file(s); 0.12 s each; one-shot.
- [ ] `replace_audio_placeholder_ranged_release` — Ranged Release; 1 file(s); 0.15 s each; one-shot.
- [ ] `replace_audio_placeholder_retaliation` — Retaliation; 1 file(s); 0.13 s each; one-shot.
- [ ] `replace_audio_placeholder_retreat_order` — Retreat Order; 1 file(s); 0.21 s each; one-shot.
- [ ] `replace_audio_placeholder_status_apply` — Status Apply; 1 file(s); 0.19 s each; one-shot.
- [ ] `replace_audio_placeholder_status_clear` — Status Clear; 1 file(s); 0.15 s each; one-shot.
- [ ] `replace_audio_placeholder_surrender_order` — Surrender Order; 1 file(s); 0.21 s each; one-shot.
- [ ] `replace_audio_placeholder_turn_ready` — Turn Ready; 1 file(s); 0.11 s each; one-shot.
- [ ] `replace_audio_placeholder_unit_rout` — Unit Rout; 1 file(s); 0.26 s each; one-shot.
- [ ] `replace_audio_placeholder_unit_step` — Unit Step; 1 file(s); 0.08 s each; one-shot.
- [ ] `replace_audio_spell_briar_bind` — Spell Control Bind; 1 file(s); 0.27 s each; one-shot.
- [ ] `replace_audio_spell_cinder_burst` — Spell Damage Fire; 1 file(s); 0.26 s each; one-shot.
- [ ] `replace_audio_spell_coal_rain` — Spell Damage Rain; 1 file(s); 0.3 s each; one-shot.
- [ ] `replace_audio_spell_command_ward` — Spell Buff; 1 file(s); 0.24 s each; one-shot.
- [ ] `replace_audio_spell_graft_mend` — Spell Recovery; 1 file(s); 0.28 s each; one-shot.
- [ ] `replace_audio_spell_prism_bastion` — Spell Cleanse; 1 file(s); 0.27 s each; one-shot.
- [ ] `replace_audio_spell_resonant_chorus` — Spell Tempo Chorus; 1 file(s); 0.29 s each; one-shot.
- [ ] `replace_audio_spell_sunlance_arc` — Spell Damage Lance; 1 file(s); 0.24 s each; one-shot.

### Music

- [ ] `music_battle` — Battle; 3 file(s); 90-150 s each; loop.
- [ ] `music_battle_brasshollow` — Battle Brasshollow; 3 file(s); 90-150 s each; loop.
- [ ] `music_battle_embercourt` — Battle Embercourt; 3 file(s); 90-150 s each; loop.
- [ ] `music_battle_mireclaw` — Battle Mireclaw; 3 file(s); 90-150 s each; loop.
- [ ] `music_battle_sunvault` — Battle Sunvault; 3 file(s); 90-150 s each; loop.
- [ ] `music_battle_thornwake` — Battle Thornwake; 3 file(s); 90-150 s each; loop.
- [ ] `music_battle_veilmourn` — Battle Veilmourn; 3 file(s); 90-150 s each; loop.
- [ ] `music_menu` — Menu; 3 file(s); 120-180 s each; loop.
- [ ] `music_outcome` — Outcome; 3 file(s); 30-60 s each; loop.
- [ ] `music_outcome_defeat` — Outcome Defeat; 3 file(s); 30-60 s each; loop.
- [ ] `music_outcome_victory` — Outcome Victory; 3 file(s); 30-60 s each; loop.
- [ ] `music_overworld` — Overworld; 3 file(s); 120-180 s each; loop.
- [ ] `music_overworld_brasshollow` — Overworld Brasshollow; 3 file(s); 120-180 s each; loop.
- [ ] `music_overworld_embercourt` — Overworld Embercourt; 3 file(s); 120-180 s each; loop.
- [ ] `music_overworld_mireclaw` — Overworld Mireclaw; 3 file(s); 120-180 s each; loop.
- [ ] `music_overworld_sunvault` — Overworld Sunvault; 3 file(s); 120-180 s each; loop.
- [ ] `music_overworld_thornwake` — Overworld Thornwake; 3 file(s); 120-180 s each; loop.
- [ ] `music_overworld_veilmourn` — Overworld Veilmourn; 3 file(s); 120-180 s each; loop.
- [ ] `music_town` — Town; 3 file(s); 120-180 s each; loop.
- [ ] `music_town_brasshollow` — Town Brasshollow; 3 file(s); 120-180 s each; loop.
- [ ] `music_town_embercourt` — Town Embercourt; 3 file(s); 120-180 s each; loop.
- [ ] `music_town_mireclaw` — Town Mireclaw; 3 file(s); 120-180 s each; loop.
- [ ] `music_town_sunvault` — Town Sunvault; 3 file(s); 120-180 s each; loop.
- [ ] `music_town_thornwake` — Town Thornwake; 3 file(s); 120-180 s each; loop.
- [ ] `music_town_veilmourn` — Town Veilmourn; 3 file(s); 120-180 s each; loop.

### Presentation

- [ ] `replace_audio_placeholder_artifact_claim` — Overworld Artifact Recovered; 1 file(s); 0.42 s each; one-shot.
- [ ] `replace_audio_placeholder_artifact_equip` — Overworld Artifact Equipped; 1 file(s); 0.26 s each; one-shot.
- [ ] `replace_audio_placeholder_artifact_stow` — Overworld Artifact Stowed; 1 file(s); 0.28 s each; one-shot.
- [ ] `replace_audio_placeholder_blocked_object` — Overworld Object Blocked; 1 file(s); 0.34 s each; one-shot.
- [ ] `replace_audio_placeholder_capture` — Overworld Object Captured; 1 file(s); 0.42 s each; one-shot.
- [ ] `replace_audio_placeholder_collect` — Overworld Object Depleted; 1 file(s); 0.28 s each; one-shot.
- [ ] `replace_audio_placeholder_guard_warning` — Overworld Object Guarded; 1 file(s); 0.34 s each; one-shot.
- [ ] `replace_audio_placeholder_invalid_route` — Overworld Route Blocked; 1 file(s); 0.3 s each; one-shot.
- [ ] `replace_audio_placeholder_load_resume` — System Load Resumed; 1 file(s); 0.36 s each; one-shot.
- [ ] `replace_audio_placeholder_map_step` — Overworld Route Moved; 1 file(s); 0.22 s each; one-shot.
- [ ] `replace_audio_placeholder_object_focus` — Overworld Object Selected; 1 file(s); 0.26 s each; one-shot.
- [ ] `replace_audio_placeholder_object_visit` — Overworld Object Visited; 1 file(s); 0.3 s each; one-shot.
- [ ] `replace_audio_placeholder_recruit` — Town Recruitment Muster; 1 file(s); 0.36 s each; one-shot.
- [ ] `replace_audio_placeholder_resource_tick` — Overworld Resource Collected; 1 file(s); 0.24 s each; one-shot.
- [ ] `replace_audio_placeholder_route_closed` — Overworld Route Closed; 1 file(s); 0.44 s each; one-shot.
- [ ] `replace_audio_placeholder_route_open` — Overworld Route Open; 1 file(s); 0.42 s each; one-shot.
- [ ] `replace_audio_placeholder_save_confirm` — System Save Confirmed; 1 file(s); 0.32 s each; one-shot.
- [ ] `replace_audio_placeholder_spell_school_soft` — Overworld Field Spell Cast; 1 file(s); 0.48 s each; one-shot.
- [ ] `replace_audio_placeholder_town_build` — Town Construction Complete; 1 file(s); 0.42 s each; one-shot.
- [ ] `replace_audio_placeholder_town_capture` — Overworld Town Captured; 1 file(s); 0.46 s each; one-shot.
- [ ] `replace_audio_placeholder_town_hero_hire` — Town Hero Hired; 1 file(s); 0.42 s each; one-shot.
- [ ] `replace_audio_placeholder_town_market_exchange` — Town Market Exchange Completed; 1 file(s); 0.36 s each; one-shot.
- [ ] `replace_audio_placeholder_town_route_response` — Town Route Response Dispatched; 1 file(s); 0.38 s each; one-shot.
- [ ] `replace_audio_placeholder_town_specialty_rank` — Town Specialty Rank Gained; 1 file(s); 0.4 s each; one-shot.
- [ ] `replace_audio_placeholder_town_spell_study` — Town Spell Studied; 1 file(s); 0.4 s each; one-shot.
- [ ] `replace_audio_placeholder_town_unit_transfer` — Town Army Redeployed; 1 file(s); 0.38 s each; one-shot.

### Ui

- [ ] `replace_ui_adjust` — Slider Adjust; 1 file(s); 0.06 s each; one-shot.
- [ ] `replace_ui_click` — Button Click; 1 file(s); 0.07 s each; one-shot.
- [ ] `replace_ui_confirm` — Confirm Action; 1 file(s); 0.12 s each; one-shot.
- [ ] `replace_ui_invalid` — Invalid Action; 1 file(s); 0.15 s each; one-shot.
- [ ] `replace_ui_select` — List Select; 1 file(s); 0.08 s each; one-shot.
- [ ] `replace_ui_tab` — Tab Change; 1 file(s); 0.09 s each; one-shot.

## P1

### Impacts

- [ ] `impact_cloth` — Cloth impact bank; 4 file(s); 0.1-0.6 s each; one-shot.
- [ ] `impact_machine` — Machine impact bank; 4 file(s); 0.1-0.6 s each; one-shot.
- [ ] `impact_metal` — Metal impact bank; 4 file(s); 0.1-0.6 s each; one-shot.
- [ ] `impact_stone` — Stone impact bank; 4 file(s); 0.1-0.6 s each; one-shot.
- [ ] `impact_wet` — Wet impact bank; 4 file(s); 0.1-0.6 s each; one-shot.
- [ ] `impact_wood` — Wood impact bank; 4 file(s); 0.1-0.6 s each; one-shot.

### Magic

- [ ] `magic_beacon_cast` — Beacon / cast; 2 file(s); 0.4-2.0 s each; one-shot.
- [ ] `magic_beacon_cleanse` — Beacon / cleanse; 2 file(s); 0.4-2.0 s each; one-shot.
- [ ] `magic_beacon_empower` — Beacon / empower; 2 file(s); 0.4-2.0 s each; one-shot.
- [ ] `magic_beacon_expire` — Beacon / expire; 2 file(s); 0.4-2.0 s each; one-shot.
- [ ] `magic_beacon_field_march` — Beacon / field_march; 2 file(s); 0.4-2.0 s each; one-shot.
- [ ] `magic_beacon_haste` — Beacon / haste; 2 file(s); 0.4-2.0 s each; one-shot.
- [ ] `magic_beacon_impact` — Beacon / impact; 2 file(s); 0.4-2.0 s each; one-shot.
- [ ] `magic_beacon_ward` — Beacon / ward; 2 file(s); 0.4-2.0 s each; one-shot.
- [ ] `magic_furnace_bind` — Furnace / bind; 2 file(s); 0.4-2.0 s each; one-shot.
- [ ] `magic_furnace_cast` — Furnace / cast; 2 file(s); 0.4-2.0 s each; one-shot.
- [ ] `magic_furnace_empower` — Furnace / empower; 2 file(s); 0.4-2.0 s each; one-shot.
- [ ] `magic_furnace_expire` — Furnace / expire; 2 file(s); 0.4-2.0 s each; one-shot.
- [ ] `magic_furnace_field_march` — Furnace / field_march; 2 file(s); 0.4-2.0 s each; one-shot.
- [ ] `magic_furnace_haste` — Furnace / haste; 2 file(s); 0.4-2.0 s each; one-shot.
- [ ] `magic_furnace_impact` — Furnace / impact; 2 file(s); 0.4-2.0 s each; one-shot.
- [ ] `magic_furnace_ward` — Furnace / ward; 2 file(s); 0.4-2.0 s each; one-shot.
- [ ] `magic_lens_cast` — Lens / cast; 2 file(s); 0.4-2.0 s each; one-shot.
- [ ] `magic_lens_cleanse` — Lens / cleanse; 2 file(s); 0.4-2.0 s each; one-shot.
- [ ] `magic_lens_empower` — Lens / empower; 2 file(s); 0.4-2.0 s each; one-shot.
- [ ] `magic_lens_expire` — Lens / expire; 2 file(s); 0.4-2.0 s each; one-shot.
- [ ] `magic_lens_field_reveal` — Lens / field_reveal; 2 file(s); 0.4-2.0 s each; one-shot.
- [ ] `magic_lens_haste` — Lens / haste; 2 file(s); 0.4-2.0 s each; one-shot.
- [ ] `magic_lens_impact` — Lens / impact; 2 file(s); 0.4-2.0 s each; one-shot.
- [ ] `magic_lens_ward` — Lens / ward; 2 file(s); 0.4-2.0 s each; one-shot.
- [ ] `magic_mire_bind` — Mire / bind; 2 file(s); 0.4-2.0 s each; one-shot.
- [ ] `magic_mire_cast` — Mire / cast; 2 file(s); 0.4-2.0 s each; one-shot.
- [ ] `magic_mire_empower` — Mire / empower; 2 file(s); 0.4-2.0 s each; one-shot.
- [ ] `magic_mire_expire` — Mire / expire; 2 file(s); 0.4-2.0 s each; one-shot.
- [ ] `magic_mire_field_reveal` — Mire / field_reveal; 2 file(s); 0.4-2.0 s each; one-shot.
- [ ] `magic_mire_haste` — Mire / haste; 2 file(s); 0.4-2.0 s each; one-shot.
- [ ] `magic_mire_heal` — Mire / heal; 2 file(s); 0.4-2.0 s each; one-shot.
- [ ] `magic_mire_impact` — Mire / impact; 2 file(s); 0.4-2.0 s each; one-shot.
- [ ] `magic_old_measure_bind` — Old Measure / bind; 2 file(s); 0.4-2.0 s each; one-shot.
- [ ] `magic_old_measure_cast` — Old Measure / cast; 2 file(s); 0.4-2.0 s each; one-shot.
- [ ] `magic_old_measure_cleanse` — Old Measure / cleanse; 2 file(s); 0.4-2.0 s each; one-shot.
- [ ] `magic_old_measure_expire` — Old Measure / expire; 2 file(s); 0.4-2.0 s each; one-shot.
- [ ] `magic_old_measure_field_march` — Old Measure / field_march; 2 file(s); 0.4-2.0 s each; one-shot.
- [ ] `magic_old_measure_field_reveal` — Old Measure / field_reveal; 2 file(s); 0.4-2.0 s each; one-shot.
- [ ] `magic_old_measure_impact` — Old Measure / impact; 2 file(s); 0.4-2.0 s each; one-shot.
- [ ] `magic_old_measure_ward` — Old Measure / ward; 2 file(s); 0.4-2.0 s each; one-shot.
- [ ] `magic_root_bind` — Root / bind; 2 file(s); 0.4-2.0 s each; one-shot.
- [ ] `magic_root_cast` — Root / cast; 2 file(s); 0.4-2.0 s each; one-shot.
- [ ] `magic_root_empower` — Root / empower; 2 file(s); 0.4-2.0 s each; one-shot.
- [ ] `magic_root_expire` — Root / expire; 2 file(s); 0.4-2.0 s each; one-shot.
- [ ] `magic_root_field_march` — Root / field_march; 2 file(s); 0.4-2.0 s each; one-shot.
- [ ] `magic_root_heal` — Root / heal; 2 file(s); 0.4-2.0 s each; one-shot.
- [ ] `magic_root_impact` — Root / impact; 2 file(s); 0.4-2.0 s each; one-shot.
- [ ] `magic_root_ward` — Root / ward; 2 file(s); 0.4-2.0 s each; one-shot.
- [ ] `magic_veil_bind` — Veil / bind; 2 file(s); 0.4-2.0 s each; one-shot.
- [ ] `magic_veil_cast` — Veil / cast; 2 file(s); 0.4-2.0 s each; one-shot.
- [ ] `magic_veil_empower` — Veil / empower; 2 file(s); 0.4-2.0 s each; one-shot.
- [ ] `magic_veil_expire` — Veil / expire; 2 file(s); 0.4-2.0 s each; one-shot.
- [ ] `magic_veil_field_march` — Veil / field_march; 2 file(s); 0.4-2.0 s each; one-shot.
- [ ] `magic_veil_haste` — Veil / haste; 2 file(s); 0.4-2.0 s each; one-shot.
- [ ] `magic_veil_impact` — Veil / impact; 2 file(s); 0.4-2.0 s each; one-shot.
- [ ] `magic_veil_ward` — Veil / ward; 2 file(s); 0.4-2.0 s each; one-shot.

### Movement

- [ ] `move_dirt` — Travel steps: dirt; 4 file(s); 0.15-0.5 s each; one-shot.
- [ ] `move_grass` — Travel steps: grass; 4 file(s); 0.15-0.5 s each; one-shot.
- [ ] `move_mud` — Travel steps: mud; 4 file(s); 0.15-0.5 s each; one-shot.
- [ ] `move_sand` — Travel steps: sand; 4 file(s); 0.15-0.5 s each; one-shot.
- [ ] `move_shallow_water` — Travel steps: shallow_water; 4 file(s); 0.15-0.5 s each; one-shot.
- [ ] `move_snow` — Travel steps: snow; 4 file(s); 0.15-0.5 s each; one-shot.
- [ ] `move_stone` — Travel steps: stone; 4 file(s); 0.15-0.5 s each; one-shot.
- [ ] `move_underground` — Travel steps: underground; 4 file(s); 0.15-0.5 s each; one-shot.
- [ ] `move_wood` — Travel steps: wood; 4 file(s); 0.15-0.5 s each; one-shot.

### Notifications

- [ ] `notice_hero_level_up` — Hero Level Up; 1 file(s); 0.3-2.0 s each; one-shot.
- [ ] `notice_new_day` — New Day; 1 file(s); 0.3-2.0 s each; one-shot.
- [ ] `notice_new_week` — New Week; 1 file(s); 0.3-2.0 s each; one-shot.
- [ ] `notice_objective_complete` — Objective Complete; 1 file(s); 0.3-2.0 s each; one-shot.
- [ ] `notice_objective_update` — Objective Update; 1 file(s); 0.3-2.0 s each; one-shot.
- [ ] `notice_player_turn` — Player Turn; 1 file(s); 0.3-2.0 s each; one-shot.
- [ ] `notice_resource_shortfall` — Resource Shortfall; 1 file(s); 0.3-2.0 s each; one-shot.
- [ ] `notice_town_threat` — Town Threat; 1 file(s); 0.3-2.0 s each; one-shot.

### Resources

- [ ] `resource_aetherglass` — Aetherglass pickup; 2 file(s); 0.2-0.7 s each; one-shot.
- [ ] `resource_brass_scrip` — Brass scrip pickup; 2 file(s); 0.2-0.7 s each; one-shot.
- [ ] `resource_embergrain` — Embergrain pickup; 2 file(s); 0.2-0.7 s each; one-shot.
- [ ] `resource_gold` — Gold pickup; 2 file(s); 0.2-0.7 s each; one-shot.
- [ ] `resource_memory_salt` — Memory salt pickup; 2 file(s); 0.2-0.7 s each; one-shot.
- [ ] `resource_ore` — Ore pickup; 2 file(s); 0.2-0.7 s each; one-shot.
- [ ] `resource_peatwax` — Peatwax pickup; 2 file(s); 0.2-0.7 s each; one-shot.
- [ ] `resource_verdant_grafts` — Verdant grafts pickup; 2 file(s); 0.2-0.7 s each; one-shot.
- [ ] `resource_wood` — Wood pickup; 2 file(s); 0.2-0.7 s each; one-shot.

### Stingers

- [ ] `stinger_battle_enter` — Battle Enter; 1 file(s); 3-8 s each; one-shot.
- [ ] `stinger_battle_loss` — Battle Loss; 1 file(s); 3-8 s each; one-shot.
- [ ] `stinger_battle_win` — Battle Win; 1 file(s); 3-8 s each; one-shot.
- [ ] `stinger_campaign_chapter` — Campaign Chapter; 1 file(s); 3-8 s each; one-shot.
- [ ] `stinger_campaign_complete` — Campaign Complete; 1 file(s); 3-8 s each; one-shot.
- [ ] `stinger_rare_discovery` — Rare Discovery; 1 file(s); 3-8 s each; one-shot.

### Town Ambience

- [ ] `town_amb_brasshollow` — Brasshollow Combine town bed; 1 file(s); 60-90 s each; loop.
- [ ] `town_amb_embercourt` — Embercourt League town bed; 1 file(s); 60-90 s each; loop.
- [ ] `town_amb_mireclaw` — Mireclaw Covenant town bed; 1 file(s); 60-90 s each; loop.
- [ ] `town_amb_sunvault` — Sunvault Compact town bed; 1 file(s); 60-90 s each; loop.
- [ ] `town_amb_thornwake` — Thornwake Concord town bed; 1 file(s); 60-90 s each; loop.
- [ ] `town_amb_veilmourn` — Veilmourn Armada town bed; 1 file(s); 60-90 s each; loop.

### Unit Body

- [ ] `body_amphibian` — Amphibian body bank; 12 file(s); 0.2-2.5 s each; one-shot.
- [ ] `body_antlered` — Antlered body bank; 12 file(s); 0.2-2.5 s each; one-shot.
- [ ] `body_bear` — Bear body bank; 12 file(s); 0.2-2.5 s each; one-shot.
- [ ] `body_bog_brute` — Bog Brute body bank; 12 file(s); 0.2-2.5 s each; one-shot.
- [ ] `body_crystal` — Crystal body bank; 12 file(s); 0.2-2.5 s each; one-shot.
- [ ] `body_hound` — Hound body bank; 12 file(s); 0.2-2.5 s each; one-shot.
- [ ] `body_humanoid` — Humanoid body bank; 12 file(s); 0.2-2.5 s each; one-shot.
- [ ] `body_insect` — Insect body bank; 12 file(s); 0.2-2.5 s each; one-shot.
- [ ] `body_leviathan` — Leviathan body bank; 12 file(s); 0.2-2.5 s each; one-shot.
- [ ] `body_living_wood` — Living Wood body bank; 12 file(s); 0.2-2.5 s each; one-shot.
- [ ] `body_machine` — Machine body bank; 12 file(s); 0.2-2.5 s each; one-shot.
- [ ] `body_ray` — Ray body bank; 12 file(s); 0.2-2.5 s each; one-shot.
- [ ] `body_spectral` — Spectral body bank; 12 file(s); 0.2-2.5 s each; one-shot.
- [ ] `body_winged` — Winged body bank; 12 file(s); 0.2-2.5 s each; one-shot.
- [ ] `body_wyrm` — Wyrm body bank; 12 file(s); 0.2-2.5 s each; one-shot.

### Weapons

- [ ] `weapon_arcane` — Arcane release bank; 4 file(s); 0.2-1.2 s each; one-shot.
- [ ] `weapon_blade` — Blade release bank; 4 file(s); 0.2-1.2 s each; one-shot.
- [ ] `weapon_blunt` — Blunt release bank; 4 file(s); 0.2-1.2 s each; one-shot.
- [ ] `weapon_bolt` — Bolt release bank; 4 file(s); 0.2-1.2 s each; one-shot.
- [ ] `weapon_bow` — Bow release bank; 4 file(s); 0.2-1.2 s each; one-shot.
- [ ] `weapon_chain` — Chain release bank; 4 file(s); 0.2-1.2 s each; one-shot.
- [ ] `weapon_polearm` — Polearm release bank; 4 file(s); 0.2-1.2 s each; one-shot.
- [ ] `weapon_siege` — Siege release bank; 4 file(s); 0.2-1.2 s each; one-shot.
- [ ] `weapon_sling` — Sling release bank; 4 file(s); 0.2-1.2 s each; one-shot.
- [ ] `weapon_thrown` — Thrown release bank; 4 file(s); 0.2-1.2 s each; one-shot.

## P2

### Ability Optional

- [ ] `ability_backstab` — Reedline Backstab accent; 2 file(s); 0.2-1.0 s each; one-shot.
- [ ] `ability_bloodrush` — Bloodrush accent; 2 file(s); 0.2-1.0 s each; one-shot.
- [ ] `ability_brace` — River Brace accent; 2 file(s); 0.2-1.0 s each; one-shot.
- [ ] `ability_bramble_ground` — Bramble Stake accent; 2 file(s); 0.2-1.0 s each; one-shot.
- [ ] `ability_counter_ambush_flare` — Counter-Ambush Flare accent; 2 file(s); 0.2-1.0 s each; one-shot.
- [ ] `ability_fog_screen` — Mistwake Screen accent; 2 file(s); 0.2-1.0 s each; one-shot.
- [ ] `ability_fogwake` — Leviathan Fogwake accent; 2 file(s); 0.2-1.0 s each; one-shot.
- [ ] `ability_formation_guard` — Citadel Screen accent; 2 file(s); 0.2-1.0 s each; one-shot.
- [ ] `ability_foundry_aura` — Saint's Temper accent; 2 file(s); 0.2-1.0 s each; one-shot.
- [ ] `ability_harry` — Kindling Barrage accent; 2 file(s); 0.2-1.0 s each; one-shot.
- [ ] `ability_hookline` — Ferrychain Hookline accent; 2 file(s); 0.2-1.0 s each; one-shot.
- [ ] `ability_obituary` — Final Notice accent; 2 file(s); 0.2-1.0 s each; one-shot.
- [ ] `ability_overheat` — Debt Furnace accent; 2 file(s); 0.2-1.0 s each; one-shot.
- [ ] `ability_pressure_artillery` — Boiler Pressure Volley accent; 2 file(s); 0.2-1.0 s each; one-shot.
- [ ] `ability_reach` — Hook Reach accent; 2 file(s); 0.2-1.0 s each; one-shot.
- [ ] `ability_readiness_writ` — Beacon Muster accent; 2 file(s); 0.2-1.0 s each; one-shot.
- [ ] `ability_resonance_relay` — Resonant Relay accent; 2 file(s); 0.2-1.0 s each; one-shot.
- [ ] `ability_rot_cant` — Sporewake Rot Cant accent; 2 file(s); 0.2-1.0 s each; one-shot.
- [ ] `ability_shielding` — Bogplate Bulk accent; 2 file(s); 0.2-1.0 s each; one-shot.
- [ ] `ability_solar_array_lane` — Solar Array Lanes accent; 2 file(s); 0.2-1.0 s each; one-shot.
- [ ] `ability_sporeglass_mend` — Mending Fire accent; 2 file(s); 0.2-1.0 s each; one-shot.
- [ ] `ability_volley` — Lantern Volley accent; 2 file(s); 0.2-1.0 s each; one-shot.

### Campaign Optional

- [ ] `campaign_music_campaign_ashen_ledger` — Ashen Ledger motif suite; 3 file(s); 90-150 s each; loop.
- [ ] `campaign_music_campaign_bogbound_oath` — Bogbound Oath motif suite; 3 file(s); 90-150 s each; loop.
- [ ] `campaign_music_campaign_briarwheel_covenant` — Briarwheel Covenant motif suite; 3 file(s); 90-150 s each; loop.
- [ ] `campaign_music_campaign_broken_meridian` — The Broken Meridian motif suite; 3 file(s); 90-150 s each; loop.
- [ ] `campaign_music_campaign_charterless_compact` — The Charterless Compact motif suite; 3 file(s); 90-150 s each; loop.
- [ ] `campaign_music_campaign_coalwater_ordinance` — The Coalwater Ordinance motif suite; 3 file(s); 90-150 s each; loop.
- [ ] `campaign_music_campaign_fivefold_assay` — The Fivefold Assay motif suite; 3 file(s); 90-150 s each; loop.
- [ ] `campaign_music_campaign_frontier_claims` — Frontier Claims motif suite; 3 file(s); 90-150 s each; loop.
- [ ] `campaign_music_campaign_horn_glass_accord` — Horn and Glass Accord motif suite; 3 file(s); 90-150 s each; loop.
- [ ] `campaign_music_campaign_last_bell_sounding` — Last Bell Sounding motif suite; 3 file(s); 90-150 s each; loop.
- [ ] `campaign_music_campaign_mireglass_counterpoint` — Mireglass Counterpoint motif suite; 3 file(s); 90-150 s each; loop.
- [ ] `campaign_music_campaign_ninefold_survey` — Ninefold Survey Docket motif suite; 3 file(s); 90-150 s each; loop.
- [ ] `campaign_music_campaign_reedfall` — Lanterns Through Reedfall motif suite; 3 file(s); 90-150 s each; loop.
- [ ] `campaign_music_campaign_rootbound_canticles` — The Rootbound Canticles motif suite; 3 file(s); 90-150 s each; loop.
- [ ] `campaign_music_campaign_shards_of_daybreak` — Shards of Daybreak motif suite; 3 file(s); 90-150 s each; loop.
- [ ] `campaign_music_campaign_siltbound_writ` — The Siltbound Writ motif suite; 3 file(s); 90-150 s each; loop.
- [ ] `campaign_music_campaign_six_roads_relay` — The Six Roads Relay motif suite; 3 file(s); 90-150 s each; loop.
- [ ] `campaign_music_campaign_six_sealed_companies` — The Six Sealed Companies motif suite; 3 file(s); 90-150 s each; loop.
- [ ] `campaign_music_campaign_six_unbound_oaths` — The Six Unbound Oaths motif suite; 3 file(s); 90-150 s each; loop.
- [ ] `campaign_music_campaign_sixfold_testament` — The Sixfold Testament motif suite; 3 file(s); 90-150 s each; loop.
- [ ] `campaign_music_campaign_stonewake` — Warden of Stonewake motif suite; 3 file(s); 90-150 s each; loop.
- [ ] `campaign_music_campaign_unbound_road_ledger` — The Unbound Road Ledger motif suite; 3 file(s); 90-150 s each; loop.
- [ ] `campaign_music_campaign_uncrowned_circuit` — The Uncrowned Circuit motif suite; 3 file(s); 90-150 s each; loop.
- [ ] `campaign_music_campaign_wakebound_atlas` — The Wakebound Atlas motif suite; 3 file(s); 90-150 s each; loop.
- [ ] `campaign_music_campaign_wild_atlas_accord` — The Wild Atlas Accord motif suite; 3 file(s); 90-150 s each; loop.

### Local Ambience

- [ ] `local_camp` — Camp proximity bed; 1 file(s); 30-60 s each; loop.
- [ ] `local_forest` — Forest proximity bed; 1 file(s); 30-60 s each; loop.
- [ ] `local_forge` — Forge proximity bed; 1 file(s); 30-60 s each; loop.
- [ ] `local_harbor` — Harbor proximity bed; 1 file(s); 30-60 s each; loop.
- [ ] `local_market` — Market proximity bed; 1 file(s); 30-60 s each; loop.
- [ ] `local_mine` — Mine proximity bed; 1 file(s); 30-60 s each; loop.
- [ ] `local_portal` — Portal proximity bed; 1 file(s); 30-60 s each; loop.
- [ ] `local_river` — River proximity bed; 1 file(s); 30-60 s each; loop.
- [ ] `local_ruins` — Ruins proximity bed; 1 file(s); 30-60 s each; loop.
- [ ] `local_sawmill` — Sawmill proximity bed; 1 file(s); 30-60 s each; loop.
- [ ] `local_shrine` — Shrine proximity bed; 1 file(s); 30-60 s each; loop.
- [ ] `local_windmill` — Windmill proximity bed; 1 file(s); 30-60 s each; loop.

### Music Expansion

- [ ] `biome_music_biome_ash_lava_wastes` — Ash / Lava Wastes exploration variation; 3 file(s); 120-180 s each; loop.
- [ ] `biome_music_biome_coast_archipelago` — Coast / Archipelago exploration variation; 3 file(s); 120-180 s each; loop.
- [ ] `biome_music_biome_deep_forest` — Deep Forest exploration variation; 3 file(s); 120-180 s each; loop.
- [ ] `biome_music_biome_grasslands` — Grasslands exploration variation; 3 file(s); 120-180 s each; loop.
- [ ] `biome_music_biome_highland_ridge` — Rough Uplands exploration variation; 3 file(s); 120-180 s each; loop.
- [ ] `biome_music_biome_mire_fen` — Mire / Fen exploration variation; 3 file(s); 120-180 s each; loop.
- [ ] `biome_music_biome_rough_badlands` — Rough Badlands exploration variation; 3 file(s); 120-180 s each; loop.
- [ ] `biome_music_biome_snow_frost_marches` — Snow / Frost Marches exploration variation; 3 file(s); 120-180 s each; loop.
- [ ] `biome_music_biome_subterranean_underways` — Subterranean / Underways exploration variation; 3 file(s); 120-180 s each; loop.

### Sites

- [ ] `site_faction_landmark` — Faction Landmark interaction bank; 2 file(s); 0.3-1.5 s each; one-shot.
- [ ] `site_faction_outpost` — Faction Outpost interaction bank; 2 file(s); 0.3-1.5 s each; one-shot.
- [ ] `site_frontier_shrine` — Frontier Shrine interaction bank; 2 file(s); 0.3-1.5 s each; one-shot.
- [ ] `site_guarded_reward_site` — Guarded Reward Site interaction bank; 2 file(s); 0.3-1.5 s each; one-shot.
- [ ] `site_mine` — Mine interaction bank; 2 file(s); 0.3-1.5 s each; one-shot.
- [ ] `site_neutral_dwelling` — Neutral Dwelling interaction bank; 2 file(s); 0.3-1.5 s each; one-shot.
- [ ] `site_pickup` — Pickup interaction bank; 2 file(s); 0.3-1.5 s each; one-shot.
- [ ] `site_repeatable_service` — Repeatable Service interaction bank; 2 file(s); 0.3-1.5 s each; one-shot.
- [ ] `site_scenario_objective` — Scenario Objective interaction bank; 2 file(s); 0.3-1.5 s each; one-shot.
- [ ] `site_scouting_structure` — Scouting Structure interaction bank; 2 file(s); 0.3-1.5 s each; one-shot.
- [ ] `site_shrine` — Shrine interaction bank; 2 file(s); 0.3-1.5 s each; one-shot.
- [ ] `site_sign_waypoint` — Sign Waypoint interaction bank; 2 file(s); 0.3-1.5 s each; one-shot.
- [ ] `site_staged_resource_front` — Staged Resource Front interaction bank; 2 file(s); 0.3-1.5 s each; one-shot.
- [ ] `site_support_producer` — Support Producer interaction bank; 2 file(s); 0.3-1.5 s each; one-shot.
- [ ] `site_transit_object` — Transit Object interaction bank; 2 file(s); 0.3-1.5 s each; one-shot.
