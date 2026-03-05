# fr0z3nUI_GameOptions — Changelog

Format: `YYMMDD-###` (sanity stamp) — short summary.


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
