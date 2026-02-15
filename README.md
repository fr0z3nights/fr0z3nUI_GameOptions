# fr0z3nUI GameOptions

Game options & helpers. UI: `/fgo`.

## Install
1. Copy the folder `fr0z3nUI_GameOptions` into:
	- `World of Warcraft/_retail_/Interface/AddOns/`
2. Launch WoW and enable the addon.

## Slash Commands
- `/fgo` — open/toggle window
- `/fgo <id>` — open window and prefill a gossip option id
- `/fgo list` — print current gossip options (npc + option IDs)

## SavedVariables
- Account: `AutoGame_Acc`, `AutoGame_Settings`, `AutoGame_UI`
- Character: `AutoGame_Char`, `AutoGame_CharSettings`

Legacy migration:
- Reads/migrates from `AutoGossip_*` if present.

## Notes
- Designed to avoid unsafe interactions while in combat.
