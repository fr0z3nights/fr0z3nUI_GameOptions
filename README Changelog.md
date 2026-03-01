# fr0z3nUI_GameOptions — Changelog

Format: `YYMMDD-###` (sanity stamp) — short summary.

## 260301-005
- Added a new “Tabard” tab (moved from LootIt) before “Tale”.
- Re-namespaced the Tabard module to GameOptions (`fr0z3nUI_GameOptionsTabard*`) and removed its old slash commands.

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
