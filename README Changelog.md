# fr0z3nUI_GameOptions — Changelog

Format: `YYMMDD-###` (sanity stamp) — short summary.


## 260311-001
- Gossip/Talk: removed the `InCombatLockdown()` gate for auto-select attempts (Zygor-style; lets us see what the client allows/blocks in combat).
- Gossip/Talk: added a 10s cooldown after `DeclineQuest()` to prevent immediate re-automation loops.
- Bumped TOC `## Version` to `2026.03.11.01`.


## 260311-002
- Switches/Chromie: hide the floating Chromie Time indicator when you're in Present Time (only shows while Chromie Time is active).
- Bumped TOC `## Version` to `2026.03.11.02`.


## 260310-001
- TooltipX: fixed a Retail tooltip taint/error caused by comparing a "secret string" unit token returned by `tooltip:GetUnit()` (prevents `attempt to compare local 'unit' (a secret string value tainted by 'fr0z3nUI_GameOptions')`).
- Bumped TOC `## Version` to `2026.03.10`.


## 260310-002
- TooltipX: fixed Retail error when `UnitIsUnit(unit, "mouseover")` was called with a secret-string tooltip unit token (now filters secret units before calling Unit APIs).
- Bumped TOC `## Version` to `2026.03.10.1`.


## 260310-003
- Profs/Talk: hardened Midnight Fishing/Cooking fallback detection to ignore secret-string values returned by `GetProfessionInfo()` before calling `:lower()`/`:find()`.
- Bumped TOC `## Version` to `2026.03.10.2`.


## 260310-004
- Profs: fixed tracked-tier refresh and `KnowsTier(2156/2159)` to use the specialized Midnight Cooking/Fishing helpers (avoids caching/returning false just because skill level is 0 or APIs are half-ready).
- Profs: `KnowsCookingMidnight()` no longer returns false early based only on base Cooking category presence; it only returns definitive false when profession lines can be enumerated.
- Bumped TOC `## Version` to `2026.03.10.3`.


## 260310-005
- Talk DB: trainer rules that branch on Midnight Cooking/Fishing now treat `nil` (unknown/not-ready) as "not known" for the "Train Me" option, preventing `TryAutoSelect` from falling through to `no-match`.
- Bumped TOC `## Version` to `2026.03.10.4`.


## 260310-006
- Gossip/Talk: added per-rule close support in the auto-select engine: use `action = "close"` to close the gossip window instead of selecting, or `close = true` to close shortly after selecting.
- Bumped TOC `## Version` to `2026.03.10.5`.


## 260310-007
- Macros/Slash: added `/fgo mountequip` to warn when the mount equipment slot is empty.
- Bumped TOC `## Version` to `2026.03.10.6`.


## 260310-008
- Macros/Slash: added `/fgo vault` to toggle the Great Vault (Weekly Rewards) window.
- Bumped TOC `## Version` to `2026.03.10.7`.


## 260310-009
- Macros/Slash: added `/fgo sharpen` to toggle `ResampleAlwaysSharpen` (prints `Sharper On/Off`).
- Bumped TOC `## Version` to `2026.03.10.8`.


## 260310-010
- Macros/Slash: added `/fgo whispin` to set `whisperMode` to `inline`.
- Bumped TOC `## Version` to `2026.03.10.9`.


## 260310-011
- Macros/Slash: added `/fgo cmove` to toggle Click2Move (`autointeract`).
- Bumped TOC `## Version` to `2026.03.10.10`.


## 260310-012
- Macros/Slash: renamed `/fgo cmove` -> `/fgo clickmove` (same Click2Move toggle).
- Bumped TOC `## Version` to `2026.03.10.11`.


## 260310-013
- Switches/UI: added Pet Walk controls above Chromie (Pet Walk ACC toggle, per-character Disable, Config popout).
- Pet Walk: added a lightweight battle-pet keeper implementation (random/favorites/specific; safe resummon triggers).
- Bumped TOC `## Version` to `2026.03.10.12`.


## 260306-001
- Talk (Melandria / Midnight Fishing): improved Midnight Fishing detection fallback to read specialization info from `GetProfessionInfo()` when the Professions UI category probe (`C_TradeSkillUI.GetCategoryInfo(2159)`) is not ready.
- Gossip: memoize profession checks per gossip-open session (refreshes immediately after manual close/re-open).


## 260303-001
- Textures picker: fixed addon-media textures with numeric filenames (e.g. `32441.tga`) being misinterpreted as texture fileIDs after spell icon support.

## 260301-004
- Print output: only the option number is green (not `OID:`), spacing aligned (`NPC:  ...`, `OID:  <num>  ...`).


## 260303-002
- Textures: added a Tex/ID mode toggle next to the texture input so numeric entries can be treated as addon media (Tex) or fileID (ID). Default is Tex.

## 260303-003
- Textures: reduced the mode toggle button footprint (T/I labels).

## 260303-004
- Textures: made fileID vs texture meaning explicit (stores fileIDs as `fileid:<num>`); default meaning is texture.
- Preserves legacy numeric-only fileIDs only when the number is not a known addon-media texture name.

## 260303-005
- Textures UI: re-laid out controls (Alpha/Scale side-by-side under texture input, added Zoom slider, moved Size/Pos above sliders, moved Quest+Spell/Class/Spec controls up).
- Textures conditions: Class/Spec inputs are now dropdowns; Spec list is tied to the chosen Class.
- Hearth: `/fgo hs loc` now mirrors `/run HearthZone:GetZone()` and prefers map-based Zone+Continent naming.
## 260301-003
- Tale Print: improved Print-on-show debouncing to prevent duplicate prints.
- Print output: shortened `OptionID` label to `OID`.

## 260301-002
- Talk DB packs: added missing `NPCs()` helper to all database files (fixes `fUI_GOTalk10.lua` using `NPCs()` without defining it).

## 260301-001
- Mission Table helper: prefers `Enum.PlayerInteractionType` values when available; falls back to numeric only when missing.
- Added sanity output in `/fgo debug`.
- Bumped TOC `## Version` to `2026.03.01`.
