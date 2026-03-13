# fr0z3nUI_GameOptions — Changelog

Format: `YYMMDD-###` (sanity stamp) — short summary.


# 260313-001
- Files: `fUI_GOSwitchesMU.lua`, `fUI_GOSwitchesUI.lua`, `fr0z3nUI_GameOptions.lua`, `fr0z3nUI_GameOptions.toc`
- Switches/UI: added "Mount Up" segmented controls (Mount Up ACC toggle, per-character Disable, Config popout).
- Mount Up: added an event-driven auto-mount helper (Smart/Favorites/Specific; delay; preferred mount via "Use Current Mount").
- Bumped TOC `## Version` to `2026.03.13.1`.


# 260313-002
- Files: `fUI_GOSwitchesMU.lua`, `fr0z3nUI_GameOptions.lua`, `fr0z3nUI_GameOptions.toc`
- Mount Up: treat dragonriding as regular flying (Skyriding era).
- Slash: added `/fgo mountup`, `/fgo mountupon`, `/fgo mountupoff`, `/fgo mountupconfig`.
- Bumped TOC `## Version` to `2026.03.13.2`.


# 260313-003
- Files: `fUI_GOSwitchesUI.lua`, `fr0z3nUI_GameOptions.lua`, `fr0z3nUI_GameOptions.toc`
- Switches/UI: keep the on-screen label as "Mount Up" (no "(Acc)" suffix); still controls account toggle.
- Slash: replaced Mount Up controls with `/fgo mu acc|on|son|off|soff|sw` (Account toggle + per-character Enable with silent variants).
- Slash: remapped `/fgo mountupon` + `/fgo mountupoff` as aliases for `/fgo mu on` + `/fgo mu off`.
- Slash: removed the old `/fgo mountupconfig` popout behavior (use Config button in Switches UI).
- Bumped TOC `## Version` to `2026.03.13.3`.


# 260313-004
- Files: `fUI_GOSwitchesUI.lua`, `fUI_GOSwitchesMU.lua`, `fr0z3nUI_GameOptions.lua`, `fr0z3nUI_GameOptions.toc`
- Switches/UI: Config segments now toggle popouts open/closed (Pet Walk / Mount Up / Chromie).
- Mount Up: added a floating "Mount Up" button (text-only like Reload UI float) controlled from the Mount Up config popout.
- Mount Up float: left-click toggles per-character Enable; right-drag moves only when unlocked; tooltip drag hint only shows when unlocked.
- Mount Up float colors: green (char enabled), orange (char disabled), red (account disabled; left-click disabled; tooltip points to `/fgo mu acc`).
- Bumped TOC `## Version` to `2026.03.13.4`.


# 260313-005
- Files: `fUI_GOSwitchesUI.lua`, `fr0z3nUI_GameOptions.toc`
- Switches/UI: enforce that only one Config popout can be open at a time.
- Bumped TOC `## Version` to `2026.03.13.5`.


# 260313-006
- Files: `fUI_GOSwitchesMU.lua`, `fr0z3nUI_GameOptions.lua`, `fr0z3nUI_GameOptions.toc`
- Mount Up: remove mode-based preferred mount behavior; picker is now always “smart”.
- Mount Up: preferred mounts are now per-situation (Flying/Ground/Water), so a ground preferred won’t be used while swimming.
- Mount Up Config: redesigned popout controls (scope toggle + Current/Clear; OSD/Lock split row; text size + delay editboxes).
- Bumped TOC `## Version` to `2026.03.13.6`.


# 260313-007
- Files: `fUI_GOSwitchesMU.lua`, `fr0z3nUI_GameOptions.toc`
- Mount Up picker: make Smart selection strict by situation type (Ground picks ground-only; Water picks aquatic-only; Flyable picks flying-only).
- Mount Up picker exception: while grounded, a Flying mount can only be chosen if it is explicitly set as the Ground preferred mount.
- Bumped TOC `## Version` to `2026.03.13.7`.


# 260313-008
- Files: `fUI_GOSwitchesMU.lua`, `fr0z3nUI_GameOptions.toc`
- Mount Up Config: rename the floating-button toggle segment from "OSD" to "Mount Up" (still a split Mount Up/Lock row).
- Bumped TOC `## Version` to `2026.03.13.8`.


# 260313-009
- Files: `fUI_GOSwitchesMU.lua`, `fr0z3nUI_GameOptions.toc`
- Mount Up Config: make Mount Up/Lock split buttons green/grey label style (no "ON/OFF" suffix).
- Bumped TOC `## Version` to `2026.03.13.9`.


# 260313-010

- Files: `fUI_GOSwitchesMU.lua`, `fr0z3nUI_GameOptions.toc`
- Mount Up Config: restore split button label to "OSD" (left segment) per spec.
- Bumped TOC `## Version` to `2026.03.13.10`.


# 260313-011
- Files: `fUI_GOSwitchesMU.lua`, `fr0z3nUI_GameOptions.toc`
- Mount Up Config: replace scope cycling + Current/Clear with 3 fixed buttons (Flying/Ground/Aquatic).
- Mount Up Config: left-click sets current mount for that scope; right-click clears back to Random/Favorite.
- Mount Up Config: scope button text is green when a preferred mount is set, yellow when cleared.
- Mount Up Config: mount display is now a long borderless hover-highlight box to the right (font +2).
- Bumped TOC `## Version` to `2026.03.13.11`.


# 260313-012
- Files: `fUI_GOSwitches.lua`, `fUI_GOSwitchesMU.lua`, `fr0z3nUI_GameOptions.toc`
- Floating buttons: tooltip titles now include a blue `[FGO]` prefix (`[FGO] Reload UI`, `[FGO] Mount Up`).
- Floating buttons: tooltip line font size reduced by 1pt (applied only while our tooltip is shown).
- Bumped TOC `## Version` to `2026.03.13.12`.


# 260313-013
- Files: `fUI_GOSwitchesMU.lua`, `fr0z3nUI_GameOptions.toc`
- Mount Up Config: remove hover highlight from mount-name display fields (display-only).
- Bumped TOC `## Version` to `2026.03.13.13`.


# 260313-014
- Files: `fUI_GOSwitchesMU.lua`, `fr0z3nUI_GameOptions.toc`
- Mount Up picker: broaden mount type ID mapping (e.g. Flying=248, Aquatic=231/232/254) so strict filtering still finds valid mounts.
- Mount Up picker: only treat a zone as a "flying" situation if at least one usable flying mount exists (prevents no-candidate dead-end).
- Bumped TOC `## Version` to `2026.03.13.14`.


# 260313-015
- Files: `fUI_GOSwitchesMU.lua`, `fr0z3nUI_GameOptions.toc`
- Mount Up Config: fix Flying/Ground/Aquatic buttons not responding by explicitly enabling mouse + raising frame levels.
- Bumped TOC `## Version` to `2026.03.13.15`.


# 260313-016
- Files: `fUI_GOSwitchesMU.lua`, `fr0z3nUI_GameOptions.toc`
- Mount Up Config: convert OSD/Lock into a true single split button (one frame; left/right click zones), sized like Reload UI (90x18).
- Bumped TOC `## Version` to `2026.03.13.16`.


# 260313-017
- Files: `fUI_GOSwitchesMU.lua`, `fUI_GOSwitchesBP.lua`, `fUI_GOSwitchesCT.lua`, `fr0z3nUI_GameOptions.toc`
- Config popouts: enforce that Pet Walk / Mount Up / Chromie config windows auto-close each other on open (prevents stacking).
- Bumped TOC `## Version` to `2026.03.13.17`.


# 260313-018
- Files: `fUI_GOSwitchesMU.lua`, `fr0z3nUI_GameOptions.toc`
- Mount Up picker: Dugis-style flyable behavior — if the area is flyable, attempt Flying first; only fall back to Ground if no usable flying candidates exist.
- Bumped TOC `## Version` to `2026.03.13.18`.


# 260313-019
- Files: `fUI_GOSwitchesMU.lua`, `fr0z3nUI_GameOptions.toc`
- Mount Up picker: when desired type is Flying, treat unknown/"other" mountTypeIDs as flying candidates (prevents false Ground fallback in flyable zones).
- Bumped TOC `## Version` to `2026.03.13.19`.


# 260313-020
- Files: `fUI_GOSwitchesMU.lua`, `fr0z3nUI_GameOptions.lua`, `fr0z3nUI_GameOptions.toc`
- Slash: add `/fgo mu types` and `/fgo mu mounted` debug helpers to dump mountTypeIDs from your client (to replace heuristics with hard mappings).
- Bumped TOC `## Version` to `2026.03.13.20`.


# 260313-021
- Files: `fUI_GOSwitchesMU.lua`, `fr0z3nUI_GameOptions.toc`
- Mount Up picker: mountType classification now uses the same hard ID mapping as Dugi (230 ground, 248 flying, 402 adv flying, 231/232/254 aquatic) and no longer treats unknown/"other" mount types as flying candidates.
- Bumped TOC `## Version` to `2026.03.13.21`.


# 260313-022
- Files: `fUI_GOSwitchesMU.lua`, `fr0z3nUI_GameOptions.toc`
- Mount Up picker: add hard mountTypeID mappings observed on your client (Ground=284; Flying=424) so strict flying selection works without heuristics.
- Bumped TOC `## Version` to `2026.03.13.22`.


# 260313-023
- Files: `fUI_GOSwitchesMU.lua`, `fr0z3nUI_GameOptions.toc`
- Mount Up picker: restrict the hard Flying mapping to `mountTypeID=424` (keep `402` as flying); remove `437` from flying mapping.
- Bumped TOC `## Version` to `2026.03.13.23`.


# 260313-024
- Files: `fUI_GOSwitchesMU.lua`, `fr0z3nUI_GameOptions.toc`
- Mount Up picker: add `mountTypeID=437` back as Flying (alongside `424` and `402`).
- Bumped TOC `## Version` to `2026.03.13.24`.


# 260313-025
- Files: `fUI_GOSwitchesMU.lua`, `fr0z3nUI_GameOptions.toc`
- Mount Up Config: move Delay control to the bottom of the window.
- Bumped TOC `## Version` to `2026.03.13.25`.


# 260313-026
- Files: `fUI_GOSwitchesMU.lua`, `fUI_GOSwitchesBP.lua`, `fUI_GOSwitchesCT.lua`, `fr0z3nUI_GameOptions.toc`
- Config popouts: add the same top title-bar background strip used by the main GameOptions window (more consistent look).
- Bumped TOC `## Version` to `2026.03.13.26`.


# 260313-027
- Files: `fUI_GOSwitchesMU.lua`, `fUI_GOSwitchesBP.lua`, `fUI_GOSwitchesCT.lua`, `fr0z3nUI_GameOptions.toc`
- Config popouts: rebuild frames on `BackdropTemplate` (same base as the main window) instead of reskinned `BasicFrameTemplateWithInset`.
- Bumped TOC `## Version` to `2026.03.13.27`.


# 260313-028
- Files: `fUI_GOSwitchesMU.lua`, `fUI_GOSwitchesBP.lua`, `fUI_GOSwitchesCT.lua`, `fr0z3nUI_GameOptions.toc`
- Config popouts: dock to the main window and remove the visible gap between frames.
- Bumped TOC `## Version` to `2026.03.13.28`.


# 260313-029
- Files: `fUI_GOSwitchesMU.lua`, `fr0z3nUI_GameOptions.lua`, `fr0z3nUI_GameOptions.toc`
- Mount Up Config: add a top Preferred Scope selector button (FACTION/GUILD/CLASS/RACE/CHARACTER), styled like LootIt Tax's Guild/Character scope button.
- Mount Up: preferred Flying/Ground/Aquatic mounts are now stored per selected scope (account-wide for faction/guild/class/race; per-character for character).
- Mount Up Config: move the Flying/Ground/Aquatic rows into the vertical middle of the popout.
- Bumped TOC `## Version` to `2026.03.13.29`.


# 260313-030
- Files: `fUI_GOSwitchesMU.lua`, `fr0z3nUI_GameOptions.lua`, `fr0z3nUI_GameOptions.toc`
- Mount Up Config: shrink OSD text-size input box and add an `XY` toggle next to it.
- Mount Up float position: `XY` ON (default) saves position account-wide outside Preferred Scope; `XY` OFF saves position per Preferred Scope.
- Mount Up float position: when `XY` is OFF and a scope has no saved position yet, it seeds by copying the current Account position into that scope.
- Bumped TOC `## Version` to `2026.03.13.30`.


# 260313-031
- Files: `fUI_GOSwitchesMU.lua`, `fr0z3nUI_GameOptions.lua`, `fr0z3nUI_GameOptions.toc`
- Mount Up Config: add a read-only scope target line under the Preferred Scope selector (ex: `GUILD: Area 52::MyGuild`).
- Mount Up: automatic one-time migration helper to seed the current scope from legacy `mountUpPreferredMountID*Acc` (does not override a user-set Random/Favorite).
- Debug: add `/fgo mu preferred` to print current Preferred Scope + the three resolved preferred mountIDs + mount names.
- Mount Up Config: if a preferred mount is currently not usable/collected, show the mount line in orange and add a tooltip reason; Mount Up falls back to Random/Favorite.
- Bumped TOC `## Version` to `2026.03.13.31`.


# 260313-032
- Files: `fUI_GOSwitchesMU.lua`, `fr0z3nUI_GameOptions.toc`
- Mount Up Config: simplify the scope target line to show only the plain name (faction/guild/class/race/character) with no realm, keys, or prefixes.
- Bumped TOC `## Version` to `2026.03.13.32`.


# 260313-033
- Files: `fUI_GOSwitchesMU.lua`, `fr0z3nUI_GameOptions.toc`
- Mount Up Config: when setting preferred mounts from the Flying/Ground/Aquatic buttons, validate the current mount type matches the row (and print a short reason if it can't set), so the Flying slot can't be accidentally set from a ground mount.
- Bumped TOC `## Version` to `2026.03.13.33`.


# 260313-034
- Files: `fUI_GOSwitchesMU.lua`, `fr0z3nUI_GameOptions.toc`
- Mount Up Config: shorten the Flying/Ground/Aquatic buttons by ~1/3 and let the mount name display boxes use the extra width.
- Bumped TOC `## Version` to `2026.03.13.34`.


# 260313-035
- Files: `fUI_GOSwitchesMU.lua`, `fr0z3nUI_GameOptions.toc`
- Mount Up Config: fix right-click clear on the Flying/Ground/Aquatic buttons so it no longer silently no-ops due to scope target checks.
- Bumped TOC `## Version` to `2026.03.13.35`.



# 260313-037
- Files: `fUI_GOSwitchesMU.lua`, `fr0z3nUI_GameOptions.toc`
- Mount Up Config: fix Flying preferred button by resolving the mounted mountID via Mount Journal "active" state (aura-based detection could fail for some mounts).
- Reverted the previous mouse-up click hardening and the extra chat prints.
- Bumped TOC `## Version` to `2026.03.13.37`.


# 260313-038
- Files: `fUI_GOSwitchesMU.lua`, `fr0z3nUI_GameOptions.toc`
- Mount Up Config: ensure the top (Flying) row stays clickable by raising the rows container frame level so header/scope UI cannot overlap it.
- Bumped TOC `## Version` to `2026.03.13.38`.


# 260313-039
- Files: `fUI_GOSwitchesMU.lua`, `fr0z3nUI_GameOptions.toc`
- Mount Up Config: remove hover highlight from the preferred mount name boxes and add hover highlight to the Flying/Ground/Aquatic buttons.
- Bumped TOC `## Version` to `2026.03.13.39`.


# 260313-040
- Files: `fUI_GOSwitchesMU.lua`, `fr0z3nUI_GameOptions.toc`
- Mount Up Config: add a `DBG` toggle and click logging for the Flying/Ground/Aquatic preferred buttons to diagnose click interception vs handler early-returns.
- Bumped TOC `## Version` to `2026.03.13.40`.


# 260313-041
- Files: `fUI_GOSwitchesMU.lua`, `fr0z3nUI_GameOptions.toc`
- Mount Up Config: MU DBG now prints a read-back of the stored preferred mountID after set/clear, to distinguish storage/scope issues from UI refresh issues.
- Bumped TOC `## Version` to `2026.03.13.41`.


# 260313-042
- Files: `fUI_GOSwitchesMU.lua`, `fr0z3nUI_GameOptions.toc`
- Mount Up Config: fix scoped preferred mount clear (0) incorrectly falling back to legacy preferred mount IDs; once a scope+slot is "touched", 0 is treated as authoritative.
- Bumped TOC `## Version` to `2026.03.13.42`.


# 260313-043
- Files: `fUI_GOSwitchesMU.lua`, `fr0z3nUI_GameOptions.toc`
- Mount Up Config: remove the horizontal gap between the Flying/Ground/Aquatic buttons and the mount name display boxes.
- Bumped TOC `## Version` to `2026.03.13.43`.


# 260313-044
- Files: `fr0z3nUI_GameOptions.lua`, `fr0z3nUI_GameOptions.toc`
- UI: hide Mount Up / Pet Walk / Chromie config popouts when the main `/fgo` window closes.
- Bumped TOC `## Version` to `2026.03.13.44`.


# 260313-045
- Files: `fr0z3nUI_GameOptions.lua`, `fr0z3nUI_GameOptions.toc`
- Mount Up: change per-character status prints to `Mount Up Enabled` (green) / `Mount Up Disabled` (orange).
- Bumped TOC `## Version` to `2026.03.13.45`.


# 260313-046
- Files: `fr0z3nUI_GameOptions.lua`, `fr0z3nUI_GameOptions.toc`
- Mount Up: make the `Mount Up` label use the same blue color as the `[FGO]` prefix in chat output.
- Bumped TOC `## Version` to `2026.03.13.46`.


# 260313-047
- Files: `fUI_GOSwitchesUI.lua`, `fUI_GOSwitchesBP.lua`, `fr0z3nUI_GameOptions.toc`
- Pet Walk: change the character segment to an MU-style `Enable` indicator (green when enabled; uses inverted legacy `petWalkDisabledChar`).
- Pet Walk: add a floating `Pet Walk` button (OSD) with Lock support; when locked, right-click dismisses the current pet.
- Pet Walk Config: add OSD/Lock split, Input (text size), and XY (Acc/Char) position toggle.
- Bumped TOC `## Version` to `2026.03.13.47`.


# 260313-048
- Files: `fUI_GOSwitchesUI.lua`, `fr0z3nUI_GameOptions.toc`
- Switches/UI: move `Tooltip Border` above `TooltipX Module`.
- Switches/UI: reorder top segments to Chromie -> Mount Up -> Pet Walk, with the remaining buttons below.
- Bumped TOC `## Version` to `2026.03.13.48`.


# 260313-049
- Files: `fUI_GOTalkUI.lua`, `fr0z3nUI_GameOptions.toc`
- Talk tab: after reload/login, the rules tree now starts fully collapsed (no persisted expansion state across sessions).
- Bumped TOC `## Version` to `2026.03.13.49`.


# 260313-050
- Files: `fUI_GOSwitchesUI.lua`, `fUI_GOSwitches.lua`, `fr0z3nUI_GameOptions.lua`, `fr0z3nUI_GameOptions.toc`
- Switches/UI: `Reload Button` now has a split click zone; the right 1/3 cycles the floating button font size (12/14/16/18/20).
- Floating Reload UI: applies the saved font size via `AutoGossip_UI.reloadFloatTextSize`.
- Bumped TOC `## Version` to `2026.03.13.50`.


# 260312-013
- Files: `fUI_GOSituate.lua`, `fUI_GOSituateUI.lua`, `fUI_GOSituatePF.lua`, `fr0z3nUI_GameOptions.toc`
- Situate: Profession scope now reads the shared per-character cached `knownProfessionKeys` (same source as gossip hints), with fallback to direct API probing if cache is unknown.
- Situate: expands `GetProfessions()` handling to up to 5 indices on the fallback path.
- Bumped TOC `## Version` to `2026.03.12.13`.


# 260312-012
- Files: `fUI_GOSituatePF.lua`, `fr0z3nUI_GameOptions.toc`
- Profs: add stable profession key detection for Archaeology (skillLineID 794) so `Prof:Archaeology`-style hints can work.
- Profs: Archaeology has no expansion-tier categoryIDs in our reference, so it tracks as a profession key only.
- Bumped TOC `## Version` to `2026.03.12.12`.


# 260312-008
- Files: `fUI_GOTalkUP.lua`, `fUI_GOSituatePF.lua`, `fr0z3nUI_GameOptions.toc`
- Profs: cache a per-character set of known base professions (e.g., "Mining") so hints can be profession-specific.
- Gossip/Talk: support robust profession-based hint checks via `print = { profession = "Mining", msg = "Train Mining" }` or `print = "Prof:Mining"`.
- Bumped TOC `## Version` to `2026.03.12.08`.


# 260312-009
- Files: `fUI_GOSituatePF.lua`, `fr0z3nUI_GameOptions.toc`
- Profs: treat an empty `GetProfessions()` result as authoritative once player context is ready (lets `Prof:*` hints fire on characters with no professions yet).
- Bumped TOC `## Version` to `2026.03.12.09`.


# 260312-010
- Files: `fUI_GOSituatePF.lua`, `fr0z3nUI_GameOptions.toc`
- Profs: profession keys are now stored using stable skillLineIDs (locale-safe) instead of localized names.
- Profs: automatically refresh/cache all expansion-tier categoryIDs for the character's known professions (e.g., Dragon Isles Mining) so this works for any user.
- Bumped TOC `## Version` to `2026.03.12.10`.


# 260312-011
- Files: `fUI_GOSituatePF.lua`, `fr0z3nUI_GameOptions.toc`
- Profs: expanded tier maps to include Cooking/Fishing/Skinning (and Riding) and detect up to 5 `GetProfessions()` returns.
- Profs: dynamic tier refresh now covers expansion tiers for secondary professions too (so “DF Fishing/Cooking/etc” works for any user).
- Bumped TOC `## Version` to `2026.03.12.11`.


# 260312-007
- Files: `fUI_GOTalkUP.lua`, `fUI_GOSituatePF.lua`, `fr0z3nUI_GameOptions.toc`
- Gossip/Talk: hint printing no longer calls professions APIs directly; it reads the cached tier state only.
- Gossip/Talk: if the tier state is unknown/not cached (`nil`), the hint is suppressed (prevents false reminders during early frames).
- Profs: added `Profs.GetCachedTier(categoryID)` helper (cache-only, no probing).
- Bumped TOC `## Version` to `2026.03.12.07`.


# 260312-006
- Files: `fUI_GOTalkUP.lua`, `fUI_GOTalk01EK.lua`, `fr0z3nUI_GameOptions.toc`
- Gossip/Talk: removed the Midnight Cooking/Fishing `Knows*`/memo gating from the EK trainer rules (no more profession checks during rule evaluation).
- Gossip/Talk: added per-rule selection-time hints via `print = "MidnightFishing"` / `print = "MidnightCooking"` that print a reminder only if you don't know the tier.
- Bumped TOC `## Version` to `2026.03.12.06`.


# 260312-005
- Files: `fUI_GOTalk.lua`, `fUI_GOTalk01EK.lua`, `fr0z3nUI_GameOptions.toc`
- Gossip/Talk: restored opt-in quest gating via `NPC.__meta.stopIfQuestAvailable/stopIfQuestTurnIn` so trainer/options don't auto-fire while a specified quest is being picked up / turned in.
- Talk DB: restored Drathen (253468) gating for `Fishy Dis-pondencies` (92869).
- Bumped TOC `## Version` to `2026.03.12.05`.


# 260312-004
- Files: `fUI_GOTalk.lua`, `fr0z3nUI_GameOptions.toc`
- Gossip auto-select: fix intermittent "rule matches but doesn't fire" by changing the repeat-selection loop guard to allow a small retry burst when the client ignores the first selection.

## 260312-003
- Gossip/Talk: let scheduled retries bypass the 0.25s debounce (prevents “debug makes it work” timing issues when the first select is ignored).
- Bumped TOC `## Version` to `2026.03.12.03`.


## 260312-002
- Gossip/Talk: treat missing `C_GossipInfo` selection APIs as retryable (`why=no-api`) so auto-select doesn’t depend on debug-print timing.
- Bumped TOC `## Version` to `2026.03.12.02`.


## 260312-001
- Gossip/Talk: add a silent first-run post-select confirm+retry (fixes auto-select working only when debug printing is enabled).
- Bumped TOC `## Version` to `2026.03.12.01`.


## 260311-006
- Gossip/Talk: removed the `DeclineQuest()` cooldown tracking/blocking (Zygor-style).
- Bumped TOC `## Version` to `2026.03.11.06`.


## 260311-005
- Gossip/Talk: force-initialize gossip engine state on gossip open (pre-arms timestamps/first-run flags) so first-run doesn’t fail.
- Bumped TOC `## Version` to `2026.03.11.05`.


## 260311-004
- Gossip/Talk: moved the gossip auto-select engine + print helpers into `fUI_GOTalk.lua` (core now delegates).
- Gossip/Talk: hardened the auto-select debounce timers so first-run can’t error on nil timestamps.
- Bumped TOC `## Version` to `2026.03.11.04`.


## 260311-003
- Gossip/Talk: reverted the quest-style gossip entry handling (active/available quests in the auto-select list) and removed the related quest-based option-blocking; this stops pet-battle gossips getting interfered with again.
- Bumped TOC `## Version` to `2026.03.11.03`.


## 260311-002
- Switches/Chromie: hide the floating Chromie Time indicator when you're in Present Time (only shows while Chromie Time is active).
- Bumped TOC `## Version` to `2026.03.11.02`.


## 260311-001
- Gossip/Talk: removed the `InCombatLockdown()` gate for auto-select attempts (Zygor-style; lets us see what the client allows/blocks in combat).
- Gossip/Talk: added a 10s cooldown after `DeclineQuest()` to prevent immediate re-automation loops.
- Bumped TOC `## Version` to `2026.03.11.01`.


## 260310-013
- Switches/UI: added Pet Walk controls above Chromie (Pet Walk ACC toggle, per-character Disable, Config popout).
- Pet Walk: added a lightweight battle-pet keeper implementation (random/favorites/specific; safe resummon triggers).
- Bumped TOC `## Version` to `2026.03.10.12`.


## 260310-012
- Macros/Slash: renamed `/fgo cmove` -> `/fgo clickmove` (same Click2Move toggle).
- Bumped TOC `## Version` to `2026.03.10.11`.


## 260310-011
- Macros/Slash: added `/fgo cmove` to toggle Click2Move (`autointeract`).
- Bumped TOC `## Version` to `2026.03.10.10`.


## 260310-010
- Macros/Slash: added `/fgo whispin` to set `whisperMode` to `inline`.
- Bumped TOC `## Version` to `2026.03.10.9`.


## 260310-009
- Macros/Slash: added `/fgo sharpen` to toggle `ResampleAlwaysSharpen` (prints `Sharper On/Off`).
- Bumped TOC `## Version` to `2026.03.10.8`.


## 260310-008
- Macros/Slash: added `/fgo vault` to toggle the Great Vault (Weekly Rewards) window.
- Bumped TOC `## Version` to `2026.03.10.7`.


## 260310-007
- Macros/Slash: added `/fgo mountequip` to warn when the mount equipment slot is empty.
- Bumped TOC `## Version` to `2026.03.10.6`.


## 260310-006
- Gossip/Talk: added per-rule close support in the auto-select engine: use `action = "close"` to close the gossip window instead of selecting, or `close = true` to close shortly after selecting.
- Bumped TOC `## Version` to `2026.03.10.5`.


## 260310-005
- Talk DB: trainer rules that branch on Midnight Cooking/Fishing now treat `nil` (unknown/not-ready) as "not known" for the "Train Me" option, preventing `TryAutoSelect` from falling through to `no-match`.
- Bumped TOC `## Version` to `2026.03.10.4`.


## 260310-004
- Profs: fixed tracked-tier refresh and `KnowsTier(2156/2159)` to use the specialized Midnight Cooking/Fishing helpers (avoids caching/returning false just because skill level is 0 or APIs are half-ready).
- Profs: `KnowsCookingMidnight()` no longer returns false early based only on base Cooking category presence; it only returns definitive false when profession lines can be enumerated.
- Bumped TOC `## Version` to `2026.03.10.3`.


## 260310-003
- Profs/Talk: hardened Midnight Fishing/Cooking fallback detection to ignore secret-string values returned by `GetProfessionInfo()` before calling `:lower()`/`:find()`.
- Bumped TOC `## Version` to `2026.03.10.2`.


## 260310-002
- TooltipX: fixed Retail error when `UnitIsUnit(unit, "mouseover")` was called with a secret-string tooltip unit token (now filters secret units before calling Unit APIs).
- Bumped TOC `## Version` to `2026.03.10.1`.


## 260310-001
- TooltipX: fixed a Retail tooltip taint/error caused by comparing a "secret string" unit token returned by `tooltip:GetUnit()` (prevents `attempt to compare local 'unit' (a secret string value tainted by 'fr0z3nUI_GameOptions')`).
- Bumped TOC `## Version` to `2026.03.10`.


## 260306-001
- Talk (Melandria / Midnight Fishing): improved Midnight Fishing detection fallback to read specialization info from `GetProfessionInfo()` when the Professions UI category probe (`C_TradeSkillUI.GetCategoryInfo(2159)`) is not ready.
- Gossip: memoize profession checks per gossip-open session (refreshes immediately after manual close/re-open).


## 260303-005
- Textures UI: re-laid out controls (Alpha/Scale side-by-side under texture input, added Zoom slider, moved Size/Pos above sliders, moved Quest+Spell/Class/Spec controls up).
- Textures conditions: Class/Spec inputs are now dropdowns; Spec list is tied to the chosen Class.
- Hearth: `/fgo hs loc` now mirrors `/run HearthZone:GetZone()` and prefers map-based Zone+Continent naming.


## 260303-004
- Textures: made fileID vs texture meaning explicit (stores fileIDs as `fileid:<num>`); default meaning is texture.
- Preserves legacy numeric-only fileIDs only when the number is not a known addon-media texture name.


## 260303-003
- Textures: reduced the mode toggle button footprint (T/I labels).


## 260303-002
- Textures: added a Tex/ID mode toggle next to the texture input so numeric entries can be treated as addon media (Tex) or fileID (ID). Default is Tex.


## 260303-001
- Textures picker: fixed addon-media textures with numeric filenames (e.g. `32441.tga`) being misinterpreted as texture fileIDs after spell icon support.


## 260301-004
- Print output: only the option number is green (not `OID:`), spacing aligned (`NPC:  ...`, `OID:  <num>  ...`).


## 260301-003
- Tale Print: improved Print-on-show debouncing to prevent duplicate prints.
- Print output: shortened `OptionID` label to `OID`.


## 260301-002
- Talk DB packs: added missing `NPCs()` helper to all database files (fixes `fUI_GOTalk10.lua` using `NPCs()` without defining it).


## 260301-001
- Mission Table helper: prefers `Enum.PlayerInteractionType` values when available; falls back to numeric only when missing.
- Added sanity output in `/fgo debug`.
- Bumped TOC `## Version` to `2026.03.01`.
