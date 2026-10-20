
## Delve entry notification

The detected `Delve Tier N Entered` message is independent of the auto-entry cooldown and prints once per world entry inside a delve instance. Detection checks at most once per second until tier data is available, rather than stopping after a short startup window. If tier data remains unavailable for 30 seconds inside, a single diagnostic is printed and checks continue. The selected entrance tier is not used as a substitute for the detected tier.

## XAura

The Macro tab's **XAura** toggle maintains `FGO XAura`. It defaults to on per character; a saved off preference is respected. Disabling cancels pending updates without deleting or changing the macro. New macros use character slots.

Add numeric spell IDs to the ordered `ns.MacroAuraIDs` list in `fUI_GOMacroAuraDB.lua`, with names as comments. Earlier entries have priority. The database includes the 13 supplied costume IDs; Trick (24753) is excluded because it cannot be cancelled. Runtime logic stays in `fUI_GOMacro.lua`.

On enable, world entry, or player aura changes, match readable beneficial auras only by spell ID. Harmful auras are not scanned. The macro uses the detected localized aura name:

```text
/cancelaura Wight Costume
/dejunk destroy
```

Only one matching aura is selected. After cancellation, another active listed aura can replace it. If no listed aura is active, leave the existing macro unchanged. When creating a missing macro without a match, write only `/dejunk destroy`.

Updates are coalesced and deferred during combat, then rescan after combat. Secret/unreadable aura data is skipped. Macro presses remain manual, and WoW's aura-cancellation restrictions apply. `/dejunk destroy` invokes the installed Dejunk addon's configured destruction behavior; XAura does not choose which items Dejunk destroys.

## Teleport equipment and GearMatic

### Guild Cloak automatic macro

On the Macro page, toggle **Guild Cloak** to enable automatic maintenance of `FGO TP Cloak`. The setting is per character and defaults to on; an explicitly saved off setting is preserved. Enabling immediately creates or updates the macro; subsequent updates happen only after world entry (including login/reload). Disabling cancels pending updates but leaves the macro intact and usable.

Only carried/equipped cloaks for your faction are considered, in this order:

| Priority | Cloak | Alliance | Horde |
| --- | --- | --- | --- |
| 1 | Shroud of Cooperation | 63352 | 63353 |
| 2 | Wrap of Unity | 63206 | 63207 |
| 3 | Cloak of Coordination | 65360 | 65274 |

The first ready cloak wins. If all owned cloaks are on cooldown, choose the one ready soonest (ties use the priority above). Live cooldowns are checked without storing a cooldown cache. If none are carried/equipped, the macro is inert (`#showtooltip` only).

The macro uses `#showtooltip item:ID`, `/fgo gmtp`, `/equip item:ID`, and `/use item:ID`. Equipping may require another press once the equipment-use cooldown finishes. New macros use character slots; an existing same-name macro is updated in place.

World-entry checks wait one second for data to settle. Combat defers the update until combat ends; unavailable ownership/cooldown data gets up to five attempts, one second apart, before reporting failure and leaving the macro unchanged. There are no periodic, bag-change, or cooldown-expiry refreshes.

### Dalaran Ring automatic macro

Toggle **Dalaran Ring** on the Macro page to create/update `FGO TP Dalaran`. This independent per-character setting defaults to on; an explicitly saved off setting is preserved. It refreshes on enable and login/reload only, not after teleports or zone changes. It uses the same combat deferral, data retries, and cooldown-selection rules as Guild Cloak. Disabling cancels pending updates without removing or changing the macro.

Supported variants, in tie-break priority order: `40586, 44935, 40585, 44934, 45688, 45690, 45691, 45689, 48954, 48955, 48956, 48957, 51557, 51558, 51559, 51560`.

Only carried/equipped rings are considered. Select the first ready variant, or the one ready soonest if all are on cooldown. With no supported ring, the macro is inert (`#showtooltip` only). The generated body shows the selected ring, runs `/fgo gmtp`, equips the ring, and uses it. Another press may be needed after the equip cooldown. Original ring slots are restored by the teleport-gear recovery.

### Timeless automatic macro

Toggle **Timeless** on the Macro page to create/update `FGO TP Timeless`. The setting is per character, defaults to on (preserving an explicitly saved off setting), and refreshes only on enable and login/reload. Disabling cancels pending updates without deleting or changing the macro. New macros use character slots.

Prefer carried non-gear Time-Lost Artifact (219222), even if the trinket is also available:

```text
#showtooltip
/use item:219222
```

Otherwise, use carried/equipped Time-Lost Artifact trinket (103678):

```text
#showtooltip
/fgo gmtp
/equip item:103678
/use item:103678
```

Selection is based on ownership, not cooldown. Banked items are excluded. If neither is available, the macro is inert (`#showtooltip` only). Combat deferral and bounded ownership-data retries follow the other teleport macros. The trinket may require another press after its equip cooldown; `/fgo gmtp` restores the original trinket after teleport.

### Manual teleport gear macros

Put `/fgo gmtp` before equipping teleport gear:

```text
/fgo gmtp
/equip Time-Lost Artifact
/use Time-Lost Artifact
```

- Captures the exact items in cloak (15), ring (11/12), and trinket (13/14) slots, then pauses GearMatic autoequip.
- After world entry (excluding login/reload), or after 300 seconds without teleporting, restores changed slots before re-enabling GearMatic. Originally empty slots are emptied again if normal bag space is available.
- Repeating `/fgo gmtp` while waiting refreshes the 300-second timeout without replacing the original snapshot. Once restoration starts, another invocation is refused until recovery finishes.
- Restoration waits for combat/death, occupied cursor, or item locks to clear, retrying every 0.5 seconds for at most 30 seconds. Unresolved slots are reported before GearMatic is re-enabled.
- The snapshot is discarded after completion or failure; the next operation captures your current gear. It is not saved across reload/logout.
- `/fgo gmon` starts restoration immediately if gear is pending; otherwise it enables GearMatic normally.
- GearMatic's own normal gear selection resumes afterward; this does not permanently pin the restored items.

## Housing macros (Saved Locations)

The old Home1/Home2 macro buttons are deprecated/removed.
The old `/fgo home1`/`/fgo home2` slash commands are also removed.

Current flow:
- Open the FGO window -> Home tab -> Saved Locations -> Create Macro (per entry)
- Or use chat: `/fgo hm macro <id>` to print the `/click ...` macro body

# CVar Enable/Disable Print Macros

/fgo vault

What it does:

/run C_AddOns.LoadAddOn("Blizzard_WeeklyRewards");
/run if WeeklyRewardsFrame:IsShown() then WeeklyRewardsFrame:Hide() else WeeklyRewardsFrame:Show() end

#### #### #### #### #### #### #### 

/fgo mountequip

What it does:

/run if not C_MountJournal.GetAppliedMountEquipmentID() then print(WrapTextInColorCode("WARNING: Mount equipment slot is EMPTY!", "ffff8000")) end

#### #### #### #### #### #### #### 

/fgo loot

What it does:

/run local k,v = "autoLootDefault" v = C_CVar.GetCVar(k) C_CVar.SetCVar(k, 1 - v) print("Auto Loot " .. (v == "1" and "Disabled" or "Enabled"))

#### #### #### #### #### #### #### 

/fgo script

What it does:

/run local k,v = "ScriptErrors" v = C_CVar.GetCVar(k) C_CVar.SetCVar(k, 1 - v) print("ScriptErrors " .. (v == "1" and "Disabled" or "Enabled"))

#### #### #### #### #### #### #### 

/fgo mouse

What it does:

/run local k,v = "lootUnderMouse" v = C_CVar.GetCVar(k) C_CVar.SetCVar(k, 1 - v) print("Loot Under Mouse " .. (v == "1" and "Disabled" or "Enabled"))

#### #### #### #### #### #### #### 

/fgo clickmove

What it does:

/run local k,v = "autointeract" v = C_CVar.GetCVar(k) C_CVar.SetCVar(k, 1 - v) print("Click2Move " .. (v == "1" and "Disabled" or "Enabled"))

#### #### #### #### #### #### #### 

/fgo trade

What it does:

/run local k,v = "blockTrades" v = C_CVar.GetCVar(k) C_CVar.SetCVar(k, 1 - v) print("Block Trades " .. (v == "1" and "Disabled" or "Enabled"))

#### #### #### #### #### #### #### 

/fgo friend

What it does:

/run local k,v = "UnitNameFriendlyPlayerName" v = C_CVar.GetCVar(k) C_CVar.SetCVar(k, 1 - v) print("Friendly Names " .. (v == "1" and "Disabled" or "Enabled"))

#### #### #### #### #### #### #### 

/fgo bars

What it does:

/run local k,v = "lockActionBars" v = C_CVar.GetCVar(k) C_CVar.SetCVar(k, 1 - v) print("ActionBar Lock " .. (v == "1" and "Disabled" or "Enabled"))

#### #### #### #### #### #### #### 

/fgo bagrev

What it does:

/run local k,v = "reverseCleanupBags" v = C_CVar.GetCVar(k) C_CVar.SetCVar(k, 1 - v) print("Bag Sort Reverse " .. (v == "1" and "Disabled" or "Enabled"))

#### #### #### #### #### #### #### 

/fgo sharpen

What it does:

/run local o = GetCVarBool("ResampleAlwaysSharpen"); SetCVar("ResampleAlwaysSharpen", not o); print("Sharper " .. (o and "Off" or "On"))

#### #### #### #### #### #### #### 

/fgo whispin

What it does:

/run SetCVar("whisperMode", "inline")

#### #### #### #### #### #### #### 

/fgo token

What it does:

/run C_WowTokenPublic.UpdateMarketPrice(); C_Timer.After(2,function () print("WoW Token: ") print(GetMoneyString(    C_WowTokenPublic.GetCurrentMarketPrice())) end);

#### #### #### #### #### #### #### 

/fgo setup

What it does:

/console autoLootDefault 1
/console deselectOnClick 1
/console autoClearAFK 10
/console lootUnderMouse 0
/console autoLootDefault 1
/console cameraSmoothStyle 0
/script SetCVar("nameplateOtherBottomInset", 0.24);SetCVar("nameplateOtherTopInset", 0.11)

#### #### #### #### #### #### #### #### #### #### 

/fgo fish

What it does:

/console autoLootDefault 1
/console Sound_EnableMusic 0
/console Sound_MasterVolume 1

Suggested macro

/fgo fish
/dismount [noflying, mounted]
/leavevehicle [canexitvehicle,noflying]
/cast Fishing

Alternate macro

/fgo fish
/fgo mu soff
/dismount [noflying, mounted]
/leavevehicle [canexitvehicle,noflying]
/cast Fishing

#### #### #### #### #### #### #### #### #### #### 

/fgo logout

What it does:

/console Sound_MasterVolume 0.5
/console Sound_EnableMusic 1

Suggested Macro Layout

/stopmacro [flying]
/fgo logout
/fgo mu soff
/cancelaura safari hat
/zygor hide
/dejunk destroy
/dismount
/logout

#### #### #### #### #### #### #### #### #### #### 

/fgo exit

What it does:

/console Sound_MasterVolume 0.5
/console Sound_EnableMusic 1

Suggested Macro:

/stopmacro [flying]
/fgo exit
/fgo mu soff
/cancelaura safari hat
/zygor hide
/dejunk destroy
/dismount
/logout

# HEARTH Macro

Button Name
HS Hearth -> Create Macro

Created Macro
FGO HS Hearth

Macro Body
/fgo hs hearth
/use item:212337

Behind /fgo Command
/run local s,d=GetItemCooldown(212337); s=s+d-GetTime(); local n,r=UnitFullName('player'); local ck=(n and r and r~='' and (n..'-'..r)) or ((UnitName('player') or '')..'-'..(GetRealmName() or '')); local root=fr0z3nUI_AutoOpen_UI; local z=root and root.hearth and root.hearth.zoneByChar and root.hearth.zoneByChar[ck] or ''; local b=GetBindLocation() or ''; local to=(z=='' and b) or (b=='' and z) or (b..', '..z); if s>1 then print(format('Hearthing in %d mins to %s', s/60, to)) else print(format('Hearthing to %s', to)) end

Notes: `/use item:212337` line would still need to use the selected toyΓÇÖs itemID (or 6948 if you want the base Hearthstone).

## FGO HS 06 Garrison

Button Name
HS Garrison

Created Macro
FGO HS Garrison

Macro Body
/fgo hs garrison
/use item:110560

Behind /fgo Command
/run local s,d=GetItemCooldown(110560); s=s+d-GetTime(); print(format(s>1 and "Hearthing to Garrison in %d mins" or "Hearthing to Garrison", s/60))

## FGO HS 07 Dalaran

Button Name
HS 07 Dalaran

Created Macro
FGO HS 07 Dalaran

Macro Body
/fgo hs dalaran
/use item:140192

Behind /fgo Command
/run local s,d=GetItemCooldown(140192); s=s+d-GetTime(); print(format(s>1 and "Hearthing to Dalaran in %d mins" or "Hearthing to Dalaran", s/60))

## FGO HS 11 Dornogal

Button Name
HS 11 Dornogal

Created Macro
FGO HS 11 Dornogal

Macro Body
/fgo hs dornogal
/use item:243056

Behind /fgo Command
/run local s,d=GetItemCooldown(243056); s=s+d-GetTime(); print(format(s>1 and "Portal to Dornogal in %d mins" or "Portal to Dornogal Opening", s/60))

## FGO HS Arcantina

Button Name
HS Arcantina

Created Macro
FGO HS 12 Arcantina

Macro Body
/fgo hs arcantina
/use item:253629

Behind /fgo Command
/run local s,d=GetItemCooldown(253629); s=s+d-GetTime(); print(format(s>1 and "Arcantina Time in %d mins" or "Arcantina Time!", s/60))

## FGO HS 78 Whistle

Button Name
HS 78 Whistle

Created Macro
FGO HS 78 Whistle

New Macro Body
/fgo hs whistle
/use item:141605
/use item:205255

Behind /fgo Command
/run local s,d=GetItemCooldown(141605); s=s+d-GetTime(); print(format(s>1 and "Whistle in %d mins" or "Whistles!", s/60))

## FGO HS Delve

Button Name
HS Delve

Created Macro
FGO HS Delve

New Macro Body
/fgo hs delve
/use item:230850

Behind /fgo Command
/run local s,d=GetItemCooldown(230850); s=s+d-GetTime(); print(format(s>1 and "Ride to a Delve in %d mins" or "Yay! Off To A Midnight Delve", s/60)); print("Shift Click Delve-o-Bot for elsewhere")

## FGO HS Instance IO

Button Name
Instance IO

Created Macro
FGO InstanceIO

Current Macro Body
/run LFGTeleport(IsInLFGDungeon())
/run LFGTeleport(IsInLFGDungeon())
/run print("Attempting Dungeon Teleport")

Notes: typically treated as a protected action. A slash command implemented in addon code may be blocked

## FGO HS Instance Reset

Button Name
Instance Reset

Created Macro
FGO InstanceReset

Current Macro Body
/script ResetInstances();

Notes:`ResetInstances()` may be protected/restricted depending on state; safest to keep as a macro.

## FGO HS Rez

Button Name
Rez

Created Macro
FGO Rez

Current Macro Body
/use Ancestral Spirit
/cast Redemption
/cast Resurrection
/cast Resuscitate
/cast Return
/cast Revive
/cast Raise Ally

Notes: Casting spells is a protected action; addons canΓÇÖt securely choose/cast these spells on-demand.

## FGO HS Rez Combat

Button Name
Rez Combat

Created Macro
FGO Rez Combat

Current Macro Body
/cast Rebirth
/cast Intercession
/cast Raise Ally

Notes: Same protected-action restriction as Rez.

## FGO HS Script Errors

Button Name
Script Errors

Created Macro
FGO ScriptErrors

New Macro Body
/fgo scripterrors

Behind /fgo Command
/run local k="ScriptErrors"; local v=tonumber(C_CVar.GetCVar(k)) or 0; C_CVar.SetCVar(k, v==1 and 0 or 1); print("ScriptErrors "..(v==1 and "Disabled" or "Enabled"))
