# fr0z3nUI_GameOptions — Changelog

Format: `YYMMDD-###` (sanity stamp) — short summary.

# 260322-025
- Files: `fUI_GOSwitchesMU.lua`, `fr0z3nUI_GameOptions.toc`
- Mount Up (Config): pressing Enter in the Delay box now applies/commits the value (same as clicking away).
- Bumped TOC `## Version` to `2026.03.22.25`.

# 260322-026
- Files: `fUI_GOSwitchesMU.lua`, `fr0z3nUI_GameOptions.toc`
- Mount Up (Config): aligned the Delay label/input to the same left/right edges as the OSD/Lock button row.
- Bumped TOC `## Version` to `2026.03.22.26`.

# 260322-024
- Files: `fUI_GOSwitchesMU.lua`, `fr0z3nUI_GameOptions.toc`
- Mount Up (Config): corrected layout so Reap/Cast/Loot toggles sit next to the Delay box (after it), and `DBG` stays on the OSD/Lock row.
- Bumped TOC `## Version` to `2026.03.22.24`.

# 260322-023
- Files: `fUI_GOSwitchesMU.lua`, `fr0z3nUI_GameOptions.toc`
- Mount Up (Config): moved Delay control above the OSD/Lock row.
- Mount Up (Config): added Reap (Gather) / Cast / Loot toggles to choose whether those retry paths use your configured Delay (otherwise they keep the quick ~0.2s retry).
- Bumped TOC `## Version` to `2026.03.22.23`.

# 260322-022
- Files: `fUI_GOLootChat.lua`, `fr0z3nUI_GameOptions.toc`
- Loot (Achievement): fix GUID extraction so class-colored names work again (GUID is not the last chat event arg).
- Bumped TOC `## Version` to `2026.03.22.22`.

# 260322-021
- Files: `fUI_GOLootChat.lua`, `fr0z3nUI_GameOptions.toc`
- XP debug: make quest turn-in/two-source behavior diagnosable (logs inferred XP + liteSig, timer scheduling, and explicit cancel/suppress reasons when the LootIt tab Debug toggle is on).
- Bumped TOC `## Version` to `2026.03.22.21`.

# 260322-020
- Files: `fUI_GOLootChat.lua`, `fr0z3nUI_GameOptions.toc`
- Loot Experience (quest turn-ins): if the system-side XP line is handled by the no-match timer fallback, the XP_UPDATE “no-delta” path no longer prints the raw stored message (prevents the raw `Experience gained: ...` line from appearing first).
- Bumped TOC `## Version` to `2026.03.22.20`.

# 260322-019
- Files: `fUI_GOLootChat.lua`, `fr0z3nUI_GameOptions.toc`
- Loot Experience (quest turn-ins): prevent the stored raw `Experience gained: ...` no-match line from printing via XP_UPDATE when the formatted XP line already printed (fixes the remaining two-source duplicate).
- Loot Experience: only treat `CHAT_MSG_COMBAT_MISC_INFO` lines as XP when they look XP-related (avoids swallowing unrelated misc lines).
- Bumped TOC `## Version` to `2026.03.22.19`.

# 260322-018
- Files: `fUI_GOLootChat.lua`, `fr0z3nUI_GameOptions.toc`
- XP debug: reduce the “1 line/sec” throttle so quest turn-in bursts show the follow-up XP-source debug lines (still gated by the LootIt tab Debug toggle; unthrottled if Capture stacks is enabled).
- Bumped TOC `## Version` to `2026.03.22.18`.

# 260322-017
- Files: `fUI_GOLootChat.lua`, `fr0z3nUI_GameOptions.toc`
- Loot Experience (quest turn-ins): prevent duplicate XP prints when Blizzard fires both a system XP line and a combat/chat XP line by replacing the XP_UPDATE “no-match” fallback with a short timer fallback (cancels itself if the other source prints / quest-title delayed print is pending).
- Bumped TOC `## Version` to `2026.03.22.17`.

# 260322-015
- Files: `fUI_GOTax.lua`, `fUI_GOTaxUI.lua`, `fr0z3nUI_GameOptions.toc`
- Tax tab: added a Guild Bank `XS` button (mirrors WarBank `XS`) opposite the Min Gold box; toggles “pay excess” to the Guild Bank.
- Bumped TOC `## Version` to `2026.03.22.15`.

# 260322-016
- Files: `fUI_GOTax.lua`, `fr0z3nUI_GameOptions.toc`
- Tax tab: both `XS` buttons now treat “excess” as anything above `Min Gold + (Guild Owed + WarBank Owed)` (prevents one bank’s XS from eating money needed to pay the other bank’s owed).
- Bumped TOC `## Version` to `2026.03.22.16`.

# 260322-014
- Files: `fUI_GOSwitchesMU.lua`, `fr0z3nUI_GameOptions.toc`
- Mount Up float: while moving, the label now updates periodically so grey/green reflects the current area in real time (useful for knowing when to stop to mount).
- Bumped TOC `## Version` to `2026.03.22.14`.

# 260322-013
- Files: `fUI_GOSwitchesMU.lua`, `fr0z3nUI_GameOptions.toc`
- Mount Up float: revert grey-state back to logic-only “area” detection (indoors + no usable mount found); removed the UI error-message latch approach.
- Bumped TOC `## Version` to `2026.03.22.13`.

# 260322-012
- Files: `fUI_GOSwitchesMU.lua`, `fr0z3nUI_GameOptions.toc`
- Mount Up float: grey state is a true no-mount-area indicator (set by the actual “can’t mount here” error). It no longer clears just because you started moving; it clears once you’re actually mountable again.
- Bumped TOC `## Version` to `2026.03.22.12`.

# 260322-011
- Files: `fUI_GOSwitchesMU.lua`, `fr0z3nUI_GameOptions.toc`
- Mount Up float: if it turns grey due to a no-mount-area error, it clears as soon as you start moving away (and otherwise expires quickly), so it doesn’t stay grey until a successful mount.
- Bumped TOC `## Version` to `2026.03.22.11`.

# 260322-010
- Files: `fUI_GOSwitchesMU.lua`, `fr0z3nUI_GameOptions.toc`
- Mount Up float: grey state now means “this area doesn’t allow mounting” (no usable mount can be picked), so it’s obvious why Mount Up won’t fire.
- Bumped TOC `## Version` to `2026.03.22.10`.

# 260322-009
- Files: `fUI_GOSwitchesMU.lua`, `fr0z3nUI_GameOptions.toc`
- Mount Up float: grey state is now *indoors-only* (pure location restriction), not other “can’t mount” states.
- Bumped TOC `## Version` to `2026.03.22.09`.

# 260322-008
- Files: `fUI_GOSwitchesMU.lua`, `fr0z3nUI_GameOptions.toc`
- Mount Up float: label turns grey when Mount Up is enabled but your current location blocks mounting (e.g. indoors / taxi / vehicle / pet battle).
- Bumped TOC `## Version` to `2026.03.22.08`.

# 260322-007
- Files: `fUI_GOLootChat.lua`, `fr0z3nUI_GameOptions.toc`
- Loot Experience: when the same XP amount arrives from both sources in a tight window, suppress the plain XP reprint and keep the more-informative variant (quest-title/appended line, or a labeled line).
- Bumped TOC `## Version` to `2026.03.22.07`.

# 260322-001
- Files: `fUI_GOMacros.lua`, `fr0z3nUI_GameOptions.toc`
- Macros (Food/Drink): prevent auto-updater from overwriting `FGO Food` / `FGO Drink` with the `#showtooltip` placeholder when no valid best item can be chosen yet (defers until a real candidate exists).
- Bumped TOC `## Version` to `2026.03.22.01`.

# 260322-002
- Files: `fr0z3nUI_GameOptions.lua`, `fUI_GOMacros.lua`, `fr0z3nUI_GameOptions.toc`
- Slash: add `/fgo yum` to force-create/update the generated `FGO Food` and `FGO Drink` macros immediately.
- Bumped TOC `## Version` to `2026.03.22.02`.

# 260322-003
- Files: `fr0z3nUI_GameOptions.lua`, `fr0z3nUI_GameOptions.toc`
- Slash: make `/fgo yum` fully silent (no chat prints).
- Bumped TOC `## Version` to `2026.03.22.03`.

# 260322-004
- Files: `fr0z3nUI_GameOptions.lua`, `fr0z3nUI_GameOptions.toc`
- Slash: add `/fgo yump` (yum + print) for a one-off forced update with status output.
- Bumped TOC `## Version` to `2026.03.22.04`.

# 260322-005
- Files: `fUI_GOLootChat.lua`, `fr0z3nUI_GameOptions.toc`
- Loot (Achievement): class-color the character name in the custom achievement output line (uses GUID->class when available).
- Bumped TOC `## Version` to `2026.03.22.05`.

# 260322-006
- Files: `fUI_GOLootChat.lua`, `fUI_GOTalk.lua`, `fUI_GOTalk01EK.lua`, `fUI_GOTalk01KD.lua`, `fUI_GOTalk02.lua`, `fUI_GOTalk03.lua`, `fUI_GOTalk04.lua`, `fUI_GOTalk05.lua`, `fUI_GOTalk06.lua`, `fUI_GOTalk07.lua`, `fUI_GOTalk08KT.lua`, `fUI_GOTalk08ZL.lua`, `fUI_GOTalk09.lua`, `fUI_GOTalk10.lua`, `fUI_GOTalk11.lua`, `fUI_GOTalk12.lua`, `fUI_GOTalkEV.lua`, `fr0z3nUI_GameOptions.toc`
- Talk (DB authoring): unify NPC helpers to a single `NPC("Name", idOrTable)` call style (multi-ID supported via table), and make pack layout/name headers name-first.
- Talk (debug): print NPC as `Name (ID)` instead of `ID: Name`.
- Bumped TOC `## Version` to `2026.03.22.06`.

# 260321-001
- Files: `fUI_GOMacros.lua`, `fr0z3nUI_GameOptions.toc`
- Macros (Food): add `/use [combat] item:5512` (Healthstone) as a combat-only first line in the generated `FGO Food` macro.
- Bumped TOC `## Version` to `2026.03.21.01`.

# 260321-002
- Files: `fUI_GOMacros.lua`, `fr0z3nUI_GameOptions.toc`
- Macros (Food/Drink): add right-click conjure lines (guarded with `[known:...]`) to generated `FGO Food` and `FGO Drink` macros.
- Bumped TOC `## Version` to `2026.03.21.02`.

# 260321-003
- Files: `fUI_GOMacros.lua`, `fr0z3nUI_GameOptions.toc`
- Macros (Food/Drink): generated `FGO Food` / `FGO Drink` now ignore `+ Macro` optional injections (prevents optional `#showtooltip` placeholder from binding to Healthstone instead of food/drink).
- Bumped TOC `## Version` to `2026.03.21.03`.

# 260321-004
- Files: `fUI_GOMacros.lua`, `fr0z3nUI_GameOptions.toc`
- Macros (Food/Drink): improve tooltip parsing/ranking (more robust enUS restore patterns, percent handling, continuation fallback) so “best” selection matches real food/drink tooltips more reliably.
- Bumped TOC `## Version` to `2026.03.21.04`.

# 260321-005
- Files: `fUI_GOSwitchesMU.lua`, `fr0z3nUI_GameOptions.toc`
- Mount Up: do not auto-mount while you are actively eating/drinking (blocks Mount Up when the generic regen aura is present).
- Bumped TOC `## Version` to `2026.03.21.05`.

# 260321-006
- Files: `fUI_GOSwitchesMU.lua`, `fUI_GOSwitchesBP.lua`, `fr0z3nUI_GameOptions.toc`
- Floating buttons: when locked, right-click triggers the “special” action instead of drag.
	- Mount Up float: right-click runs Mount Special (same behavior as `/mountspecial`).
	- Pet Walk float: right-click dismisses your currently summoned battle pet.
- Bumped TOC `## Version` to `2026.03.21.06`.

# 260321-007
- Files: `fUI_GOSwitchesMU.lua`, `fr0z3nUI_GameOptions.toc`
- Mount Up: fix a taint error in the eating/drinking gate on some clients (“secret number” aura spellIDs can’t be compared directly) by stringifying spellID before matching.
- Bumped TOC `## Version` to `2026.03.21.07`.

# 260321-008
- Files: `fUI_GOSwitchesMU.lua`, `fr0z3nUI_GameOptions.toc`
- Mount Up: fix follow-up taint error (“secret string”) by avoiding all direct spellID comparisons; use `AuraUtil.FindAuraBySpellID` for eating/drinking detection, with a name-only fallback.
- Bumped TOC `## Version` to `2026.03.21.08`.

# 260321-009
- Files: `fUI_GOMacros.lua`, `fr0z3nUI_GameOptions.toc`
- Macros (Food/Drink): fix generated `FGO Food` / `FGO Drink` not auto-updating after a `/reload` (auto-update now treats “macro exists” as active, not only the one-session `createdFood/createdDrink` flags).
- Bumped TOC `## Version` to `2026.03.21.09`.

# 260321-010
- Files: `fUI_GOMacros.lua`, `fr0z3nUI_GameOptions.toc`
- Macros: avoid no-op rewrites (if the existing macro body already matches, skip `EditMacro` and don’t print a duplicate “Updated macro ...” line).
- Bumped TOC `## Version` to `2026.03.21.10`.

# 260321-011
- Files: `fUI_GOMacros.lua`, `fr0z3nUI_GameOptions.toc`
- Macros (Food/Drink): remove success spam (“Created/Updated macro ...”) for the generated `FGO Food` / `FGO Drink` macros; failures still print.
- Bumped TOC `## Version` to `2026.03.21.11`.

# 260321-012
- Files: `fUI_GOMacros.lua`, `fr0z3nUI_GameOptions.toc`
- Macros (Food/Drink): silence combat-deferral messages; macro updates still defer in combat and retry after combat automatically.
- Bumped TOC `## Version` to `2026.03.21.12`.

# 260321-013
- Files: `fUI_GOTrade.lua`, `fr0z3nUI_GameOptions.toc`
- Trade (Restock): fix overbuying stacked vendor items by converting unit “need” into the correct `BuyMerchantItem` purchase quantity (uses merchant per-purchase stack size); pending-bought tracking now increments by units bought.
- Bumped TOC `## Version` to `2026.03.21.13`.

# 260321-014
- Files: `fUI_GOTrade.lua`, `fr0z3nUI_GameOptions.toc`
- Trade (Restock): fail closed when a restock rule can’t be classified/grouped yet (no category/use-key) — never fall back to buying each rule item.
- Trade (Restock): expand food/drink “Use:” parsing so mana-only drinks classify correctly; restock grouping now prefers the highest-tier usable item.
- Bumped TOC `## Version` to `2026.03.21.14`.

# 260321-015
- Files: `fUI_GOTrade.lua`, `fr0z3nUI_GameOptions.toc`
- Trade (Restock): cap each `BuyMerchantItem` call to the item’s real max stack size (e.g., buy in 20s), so vendor “bundle sizes” (like 5) don’t dictate buy chunking.
- Bumped TOC `## Version` to `2026.03.21.15`.

# 260321-016
- Files: `fUI_GOTrade.lua`, `fr0z3nUI_GameOptions.toc`
- Trade (Restock): when multiple tier rules share a restock group, the group target now follows the chosen best-tier item’s configured target (no more taking the max target across the group).
- Bumped TOC `## Version` to `2026.03.21.16`.

# 260321-017
- Files: `fUI_GOTrade.lua`, `fr0z3nUI_GameOptions.toc`
- Trade (Restock): fix under-buying by treating `BuyMerchantItem(idx, quantity)` as item-units on this client; buy calls now request the configured unit amounts (rounded to vendor bundle size) instead of “purchase counts”.
- Bumped TOC `## Version` to `2026.03.21.17`.

# 260321-018
- Files: `fUI_GOTrade.lua`, `fr0z3nUI_GameOptions.toc`
- Trade (Restock): fix mana-user detection so it checks for an actual mana pool (not the current primary power type), preventing paladin specs/forms from incorrectly being treated as “non-mana”.
- Bumped TOC `## Version` to `2026.03.21.18`.

# 260321-019
- Files: `fUI_GOTrade.lua`, `fr0z3nUI_GameOptions.toc`
- Trade Debug: merchant debug header now prints `usesMana`, `maxMana`, and `powerType` to make drink gating diagnostics unambiguous.
- Bumped TOC `## Version` to `2026.03.21.19`.

# 260321-020
- Files: `fUI_GOTrade.lua`, `fr0z3nUI_GameOptions.toc`
- Trade (Restock): reduce chat spam by printing the `Buying:` line only once per item per merchant session (instead of once per chunk).
- Bumped TOC `## Version` to `2026.03.21.20`.

# 260321-021
- Files: `fUI_GOTrade.lua`, `fr0z3nUI_GameOptions.toc`
- Trade (Restock): fix “not caching” / false-negative classification by not caching tooltip misses as `false`; if tooltip lines aren’t ready yet, restock now waits and retries.
- Bumped TOC `## Version` to `2026.03.21.22`.

# 260321-022
- Files: `fUI_GOTrade.lua`, `fr0z3nUI_GameOptions.toc`
- Trade (Restock/UI): fix mana-only drinks being misclassified as restoring health just because the word “health” appeared in the tooltip line; now only parsed “of your health/mana” counts.
- Bumped TOC `## Version` to `2026.03.21.23`.

# 260321-023
- Files: `fUI_GOTradeUI.lua`, `fr0z3nUI_GameOptions.toc`
- Trade UI (Items list): fix Health% column showing a value for mana-only drinks; Health%/Mana% now display only when the tooltip explicitly restores that resource.

# 260321-024
- Files: `fUI_GOSwitchesMU.lua`, `fr0z3nUI_GameOptions.toc`
- Mount Up: eating/drinking gate now only blocks while the active “consuming” aura is present (movement-cancelled, no fixed duration), so Mount Up works again immediately after you finish eating/drinking.
- Bumped TOC `## Version` to `2026.03.21.25`.

# 260321-025
- Files: `fUI_GOSwitchesMU.lua`, `fr0z3nUI_GameOptions.toc`
- Mount Up: fix regression where eating/drinking could be interrupted by an auto-mount after you stop moving; eating/drinking is now reliably detected again.
- Mount Up: if Mount Up was armed while you were eating/drinking, it now retries shortly after the consuming aura ends (so you mount after finishing without needing a second trigger).
- Bumped TOC `## Version` to `2026.03.21.26`.

# 260321-026
- Files: `fUI_GOSwitchesMU.lua`, `fr0z3nUI_GameOptions.toc`
- Mount Up: add a 20-second “finish eating/drinking then mount” timer (cancelled on movement) so mounting still happens after consumption even if the normal 8-second arm window expires.
- Bumped TOC `## Version` to `2026.03.21.27`.

# 260321-027
- Files: `fUI_GOTrade.lua`, `fr0z3nUI_GameOptions.toc`
- Trade (Restock): fix `Buying:` chat line to display the actual bundle-rounded units requested from the vendor (and show `need` when it differs), matching the resulting loot/stack splits.
- Bumped TOC `## Version` to `2026.03.21.28`.

# 260321-028
- Files: `fUI_GOTrade.lua`, `fr0z3nUI_GameOptions.toc`
- Trade (Restock): stop rounding purchases to the merchant item `stackCount`/`quantity` (treat it as the default buy size); restock now attempts to buy the exact needed unit count when possible.
- Bumped TOC `## Version` to `2026.03.21.29`.

# 260321-029
- Files: `fUI_GOTradeUI.lua`, `fr0z3nUI_GameOptions.toc`
- Trade UI: fix a runtime error where `NormalizeBankTarget` was nil in some click paths.
- Bumped TOC `## Version` to `2026.03.21.30`.

# 260321-030
- Files: `fUI_GOLootChat.lua`, `fr0z3nUI_GameOptions.toc`
- LootChat (XP): suppress occasional double-prints where the same XP amount appears twice (one line with a source label, followed by a plain XP line).
- Bumped TOC `## Version` to `2026.03.21.31`.
- Bumped TOC `## Version` to `2026.03.21.24`.

# 260320-001
- Files: `fUI_GOTax.lua`, `fr0z3nUI_GameOptions.toc`
- Tax: prefix bank move chat lines with `[Tax]` so the source is obvious when diagnosing unexpected prints.
- Bumped TOC `## Version` to `2026.03.20.01`.

# 260320-002
- Files: `fUI_GOLootChat.lua`, `fr0z3nUI_GameOptions.toc`
- LootChat: fix false-positive “money message” detection for single-letter amount tokens (`g/s/c`) so addon messages like `"8612 guides are loaded"` aren't suppressed/reprinted as `"<player>: 8612"`.
- Bumped TOC `## Version` to `2026.03.20.02`.

# 260320-003
- Files: `fUI_GOTax.lua`, `fr0z3nUI_GameOptions.toc`
- Tax: remove the explicit chat prefix on bank-move prints (restores the original plain `"<player>: <gold>"` style line).
- Bumped TOC `## Version` to `2026.03.20.03`.

# 260320-004
- Files: `fUI_GOTax.lua`, `fr0z3nUI_GameOptions.toc`
- Tax: normalize bank-move chat wording to consistently say `withdrawn from <BankName>` / `deposited to <BankName>` and print a friendly bank label (`Warband Bank` vs `WarBank`).
- Bumped TOC `## Version` to `2026.03.20.04`.

# 260320-005
- Files: `fUI_GOLootChat.lua`, `fr0z3nUI_GameOptions.toc`
- LootChat: tighten money detection so status/config lines containing words like `gold=on` aren't rewritten as `"<player>: 1"`, and addon prints containing coin textures mid-line won't lose their trailing text.
- Bumped TOC `## Version` to `2026.03.20.05`.

# 260320-006
- Files: `fUI_GOLootChat.lua`, `fr0z3nUI_GameOptions.toc`
- LootChat: fix remaining money false-positive where config/status text like `n=1, gold=on` could still be parsed/rewritten as `"<player>: 1"`.
- Bumped TOC `## Version` to `2026.03.20.06`.

# 260320-007
- Files: `fr0z3nUI_GameOptions.lua`, `fr0z3nUI_GameOptions.toc`
- Slash `/fgo status`: remove the duplicate trailing `version=...` line (Loot status already prints version).
- Bumped TOC `## Version` to `2026.03.20.07`.

# 260320-008
- Files: `fUI_GOTrade.lua`, `fr0z3nUI_GameOptions.toc`
- Trade (Restock): wait for item/merchant cache to be ready before buying, so restock selection/counting doesn’t run with partial tooltip/item-data.
- Bumped TOC `## Version` to `2026.03.20.08`.

# 260320-009
- Files: `fUI_GOTradeUI.lua`, `fr0z3nUI_GameOptions.toc`
- Trade UI (Items list): auto-refresh the items window when rules change and when item cache finishes loading, so names/columns and newly-added items appear without reopening.
- Bumped TOC `## Version` to `2026.03.20.09`.

# 260320-010
- Files: `fUI_GOMacros.lua`, `fUI_GOMacroUI.lua`, `fr0z3nUI_GameOptions.toc`
- Macros tab: add bottom `Food` / `Drink` buttons to create/update the `FGO Food` and `FGO Drink` macros based on best bag food/drink.
- Macros tab: add `Conjured` (green/grey) toggle next to `+ Macro` to prefer conjured items when ranking.
- Bumped TOC `## Version` to `2026.03.20.10`.

# 260319-001
- Files: `fUI_GOLootUI.lua`, `fr0z3nUI_GameOptions.toc`
- Loot tab (Experience): fix compact dropdown sizing so the `Quest` toggle button doesn't get pushed off-screen and appear missing.
- Bumped TOC `## Version` to `2026.03.19.01`.

# 260319-002
- Files: `fUI_GOCore.lua`, `fUI_GOLoot*.lua`, `fUI_GOTrade*.lua`, `fUI_GOTax*.lua`, `fUI_GOSwitchesMN.lua`, `fr0z3nUI_GameOptions.toc`
- LootIt embedding: stop binding to a separately-loaded standalone `fr0z3nUI_LootIt` global; always initialize/use the embedded `ns.LootIt` instance so the Loot/Trade/Tax tabs and `/fgo` status can't be hijacked by an old addon folder.
- Bumped TOC `## Version` to `2026.03.19.02`.

# 260318-001
- Files: `fUI_GOLootChat.lua`, `fr0z3nUI_GameOptions.toc`
- Experience in Loot (QuestXP): fix the delayed fallback printer so it always includes the quest title (some clients provide `QUEST_COMPLETE` without a `%s` placeholder, which previously caused a generic `"Quest completed"` line).
- Bumped TOC `## Version` to `2026.03.18.01`.

# 260317-068
- Files: `fUI_GOLootChat.lua`, `fr0z3nUI_GameOptions.toc`
- Experience in Loot (QuestXP): fix quest completion → XP merge timing by using a consistent `GetTime()`-based timestamp for both system “Quest completed” lines and XP parsing.
- Experience in Loot (QuestXP): widen the merge window and add a delayed fallback print so a suppressed “Quest completed” line can’t vanish if no XP line arrives.

# 260318-005
- Files: `fUI_GOTrade.lua`, `fUI_GOTradeUI.lua`, `fr0z3nUI_GameOptions.toc`
- Trade/Purchase (Merchant): treat missing merchant item links right after open as a cache-wait state so the merchant ticker doesn't idle-out and require a reopen.
- Trade UI: Purchase list shows `C A R` scope indicator (Character/Account/Realm) colored green/orange for enabled/disabled; left-side buttons shortened and the list panel widened ~20% while staying on the tab.
- Bumped TOC `## Version` to `2026.03.18.05`.

# 260318-006
- Files: `fUI_GOTrade.lua`, `fr0z3nUI_GameOptions.toc`
- Trade/Purchase (Merchant): resolve merchant item IDs using multiple APIs (not just `GetMerchantItemLink`) for better compatibility with UI replacements; also sync merchant debug output to the same `tradeDebug` toggle so "no purchase" cases print why.
- Bumped TOC `## Version` to `2026.03.18.06`.

# 260318-007
- Files: `fUI_GOTrade.lua`, `fr0z3nUI_GameOptions.toc`
- Trade/Purchase (Merchant): improved debug lines to show which rule is being processed and whether it's waiting on cache vs not sold by the current merchant.
- Bumped TOC `## Version` to `2026.03.18.07`.

# 260318-008
- Files: `fUI_GOLootChat.lua`, `fr0z3nUI_GameOptions.toc`
- Experience in Loot (QuestXP): never print a standalone "Quest completed: <title>" fallback line. Quest completion spam remains hidden, and the quest title only appears when it can be appended onto an XP gain line. Also briefly delays unnamed XP output so completions that arrive after the XP event can still attach.
- Bumped TOC `## Version` to `2026.03.18.08`.

# 260318-009
- Files: `fUI_GOTrade.lua`, `fr0z3nUI_GameOptions.toc`
- Trade/Purchase (Merchant): prevent repeated buy attempts for items you already have equipped / Unique(1) by flooring Buy-mode "have" counts using `GetItemCount(..., includeBank=false)`.
- Bumped TOC `## Version` to `2026.03.18.09`.

# 260318-010
- Files: `fUI_GOTrade.lua`, `fr0z3nUI_GameOptions.toc`
- Trade/Purchase (Merchant): avoid restarting the merchant ticker if it's already running (prevents double-start from wiping session tracking and causing immediate repeat-buy attempts before bags update).
- Bumped TOC `## Version` to `2026.03.18.10`.

# 260318-011
- Files: `fUI_GOCore.lua`, `fUI_GOTrade.lua`, `fr0z3nUI_GameOptions.toc`
- Trade/Purchase (Merchant): if a buy attempt triggers the UI error "You can't carry any more", latch that itemID as blocked for the remainder of the merchant session so the ticker stops re-attempting and spamming the popup (common with Unique/max-count items).
- Bumped TOC `## Version` to `2026.03.18.11`.

# 260318-012
- Files: `fUI_GOLootChat.lua`, `fr0z3nUI_GameOptions.toc`
- Experience in Loot (QuestXP): XP line quest title now has an extra leading space and is colored white (instead of default chat grey).
- Bumped TOC `## Version` to `2026.03.18.12`.

# 260318-013
- Files: `fUI_GOLootChat.lua`, `fr0z3nUI_GameOptions.toc`
- Experience in Loot (Discovery XP): location name now has an extra leading space and is colored light blue (instead of default chat grey).
- Bumped TOC `## Version` to `2026.03.18.13`.

# 260318-014
- Files: `fUI_GOTrade.lua`, `fr0z3nUI_GameOptions.toc`
- Trade/Purchase (Merchant): after buying a non-stackable item where the rule target is 1, block further buys of that item for the rest of the merchant session to prevent an immediate second attempt (and "can't carry any more" popup) during bag/cache lag.
- Bumped TOC `## Version` to `2026.03.18.14`.

# 260318-004
- Files: `fUI_GOTrade.lua`, `fr0z3nUI_GameOptions.toc`
- Trade/Purchase (Merchant): keep the merchant ticker alive while the vendor item list is still populating on first open (treat `GetMerchantNumItems()==0` as a cache-wait state in Buy mode).
- Bumped TOC `## Version` to `2026.03.18.04`.

# 260318-003
- Files: `fUI_GOCore.lua`, `fUI_GOTrade.lua`, `fr0z3nUI_GameOptions.toc`
- Trade/Purchase (Merchant): fix a first-open issue where vendor automation could fail until you reopened the vendor, by not keying the merchant ticker off `MerchantFrame:IsShown()` and by wiring merchant interaction events from the Interaction Manager (with dedupe).
- Bumped TOC `## Version` to `2026.03.18.03`.

# 260318-002
- Files: `fUI_GOLootChat.lua`, `fr0z3nUI_GameOptions.toc`
- Experience in Loot (QuestXP): attach the quest title to plain XP gain lines even when the XP parser can't identify the message kind (infer unnamed vs kill from presence of a mob string).
- Bumped TOC `## Version` to `2026.03.18.02`.
- Bumped TOC `## Version` to `2026.03.17.68`.

# 260317-069
- Files: `fUI_GOLootChat.lua`, `fr0z3nUI_GameOptions.toc`
- Experience in Loot (QuestXP): quest accepted/completed suppression no longer depends on LootIt's main enabled toggle (it is an Experience feature).
- Experience in Loot (QuestXP): add low-noise XP debug lines when quest status is stored/suppressed/fallback-printed.
- Bumped TOC `## Version` to `2026.03.17.69`.

# 260317-070
- Files: `fUI_GOLootChat.lua`, `fr0z3nUI_GameOptions.toc`
- Experience in Loot (QuestXP): recognize and suppress the alternate quest completion format `"<Quest Title> completed."` in System messages, so it can merge into the XP line (or fallback-print).
- Experience in Loot (QuestXP): ensure the System-message filter is installed whenever QuestXP is enabled (even if LootIt main is off).
- Bumped TOC `## Version` to `2026.03.17.70`.

# 260317-071
- Files: `fUI_GOLootChat.lua`, `fr0z3nUI_GameOptions.toc`
- Experience in Loot (QuestXP): fix a Lua error introduced in 070 where `MaybePrintXPDebug()` was referenced before being defined (forward declaration).
- Bumped TOC `## Version` to `2026.03.17.71`.

# 260317-072
- Files: `fUI_GOLootChat.lua`, `fr0z3nUI_GameOptions.toc`
- Experience in Loot (QuestXP): attach quest completion titles based on XP message kind (unnamed/quest XP) instead of relying on whether the XP parser produced a non-empty `mob` string.
- Bumped TOC `## Version` to `2026.03.17.72`.

# 260317-073
- Files: `fUI_GOLootChat.lua`, `fr0z3nUI_GameOptions.toc`
- Experience in Loot (QuestXP): prevent `QUEST_TURNED_IN` from wiping the stored quest title when `GetTitleForQuestID()` returns nil (cache/timing).
- Experience in Loot (QuestXP): suppress the generic System line `"Quest completed"` (no title) when a recent titled completion is pending, so the quest name can appear on the XP line instead.
- Bumped TOC `## Version` to `2026.03.17.73`.

# 260317-064
- Files: `fUI_GOTradeBank.lua`, `fUI_GOTrade.lua`, `fr0z3nUI_GameOptions.toc`
- Deposit (Personal Bank): add a `PutItemInBank()` fallback after cursor pickup (often still works with the 12.0 bank panel even when Character bank slots aren’t enumerable as container bags).
- Deposit debug: `/fgo deposit debug` now prints bank UI shown state, selected bank type, and which `C_Bank` deposit functions are present.
- Bumped TOC `## Version` to `2026.03.17.64`.

# 260317-065
- Files: `fUI_GOTradeBank.lua`, `fr0z3nUI_GameOptions.toc`
- Deposit (Personal Bank): when `C_Bank` deposit APIs aren’t available, deposit now uses `C_Container.UseContainerItem()` for whole stacks (bank-open right-click behavior) and `SplitPickupContainerItemSafe()` + `PutItemInBank()` for partial stacks.
- Deposit (Personal Bank): blocked/undepositable items are now skipped instead of aborting the entire deposit run.
- Bumped TOC `## Version` to `2026.03.17.65`.

# 260317-063
- Files: `fUI_GOTradeBank.lua`, `fr0z3nUI_GameOptions.toc`
- Deposit (Personal Bank, 12.0+): prefer `C_Bank` deposit APIs (Character bank type + `ItemLocation`) instead of trying to locate “bank bag” container IDs; keeps the old cursor/container placement as a fallback.
- Bumped TOC `## Version` to `2026.03.17.63`.

# 260317-062
- Files: `fUI_GOTradeBank.lua`, `fUI_GOTrade.lua`, `fr0z3nUI_GameOptions.toc`
- Deposit (Personal Bank): update deposit mover to work with the new bank panel (Personal Bank behaves like Warbank) by placing into the bank’s container panel instead of relying on legacy `PutItemInBank()`.
- Deposit: all “scan player bags” loops now only iterate backpack/equipped bags (+ reagent bag) so bank containers aren’t treated as inventory when the bank UI is open.
- Deposit: Personal Bank failures now print the specific reason (pickup/place/full/blocked).
- Bumped TOC `## Version` to `2026.03.17.62`.

# 260317-061
- Files: `fUI_GOTradeUI.lua`, `fr0z3nUI_GameOptions.toc`
- Deposit (UI): destination-filtered Items list now shows rules even when disabled/overridden (so you can re-enable them), and in Personal/Guild/Warbank views it also includes `bank` (auto) rules since those would deposit to that destination when that bank UI is open.
- Bumped TOC `## Version` to `2026.03.17.61`.


# 260317-067
- Files: `fUI_GOTrade.lua`, `fr0z3nUI_GameOptions.toc`
- Deposit (Slash): restore `/fgo deposit <target>` run behavior (e.g. `personal/guild/warbank`) so you can force a specific deposit path for debugging; `/fgo deposit` still auto-selects based on which bank UI is open.
- Bumped TOC `## Version` to `2026.03.17.67`.
# 260317-060
- Files: `fUI_GOTradeBank.lua`, `fUI_GOTradeUI.lua`, `fr0z3nUI_GameOptions.toc`
- Deposit (UI): the right-side Items list filtering now uses the deposit engine’s effective resolver (same Char/Realm/Acc precedence + disable flags) so the list can’t drift from runtime behavior.
- Bumped TOC `## Version` to `2026.03.17.60`.

# 260317-059
- Files: `fUI_GOTradeBank.lua`, `fUI_GOTrade.lua`, `fr0z3nUI_GameOptions.toc`
- Deposit: restore “one deposit list” behavior by storing a destination tag per rule (`bank`/`personal`/`guild`/`warbank`) and computing the effective destination with Char > Realm > Account precedence + disable flags.
- Deposit: runtime `/fgo deposit` (and `bank` auto) now deposits based on each rule’s stored destination (plus `bank` auto-to-open-bank) and does **not** read the UI destination selector, preventing the old “button overrides deposit” bug.
- Deposit: `/fgo deposit status|debug` now shows `resolved=` destination when target is `bank` (auto), plus a per-destination effective breakdown in debug.
- Bumped TOC `## Version` to `2026.03.17.59`.

# 260317-058
- Files: `fUI_GOTradeBank.lua`, `fr0z3nUI_GameOptions.toc`
- Deposit: when no explicit target is provided, `/fgo deposit` and `/fgo deposit status|debug` now default to the Deposit tab’s saved target (`cfg.target`) instead of always using `bank`.
- Bumped TOC `## Version` to `2026.03.17.58`.

# 260317-057
- Files: `fUI_GOTrade.lua`, `fUI_GOTradeBank.lua`, `fr0z3nUI_GameOptions.toc`
- Deposit: add `/fgo deposit status [target]` and `/fgo deposit debug [target]` to print a one-shot report (bank-open detection, normalized target/list, effective rule count, and debug breakdown/sample IDs).
- Deposit: allow `/fgo deposit <target>` to run with an explicit target (`bank`/`personal`/`guild`/`warbank`).
- Bumped TOC `## Version` to `2026.03.17.57`.

# 260317-054
- Files: `fUI_GOMacroUI.lua`, `fr0z3nUI_GameOptions.toc`
- HM Portal: the UI "FGO HM Portal" Create button now captures/sets the portal target (same as `/fgo hm portal set`) when standing in the desired plot.
- Bumped TOC `## Version` to `2026.03.17.54`.

# 260317-055
- Files: `fUI_GOMacroUI.lua`, `fr0z3nUI_GameOptions.toc`
- HM Portal (UI): clicking the "FGO HM Portal" row label now captures/sets the portal target (like `/fgo hm portal set`); the small `M` button remains macro-only.
- Bumped TOC `## Version` to `2026.03.17.55`.

# 260317-056
- Files: `fUI_GOMacroUI.lua`, `fr0z3nUI_GameOptions.toc`
- HM (UI): add an `S` button on the Alliance/Horde/Portal rows to print status (Portal uses the same output as `/fgo hm portal status`; Home rows print saved target + secure button attributes).
- Bumped TOC `## Version` to `2026.03.17.56`.

# 260317-053
- Files: `fUI_GOTradeUI.lua`, `fr0z3nUI_GameOptions.toc`
- Trade/Deposit: when a Warbound item auto-switches the deposit target to Warbank, immediately refresh/rebind the right-side Items list and scope state so edits apply to Warbank.
- Trade/Deposit: treat legacy `guildbank` target strings as `guild` (target normalization).
- Bumped TOC `## Version` to `2026.03.17.53`.

# 260317-042
- Files: `fUI_GOTradeUI.lua`, `fr0z3nUI_GameOptions.toc`
- Trade/Deposit: fix debug gating so Trade `Debug` prints can’t be lost to a Lua local-ordering pitfall; add a guaranteed debug line when cycling bank targets so we can confirm the click handler fired + see the before/after target.
- Bumped TOC `## Version` to `2026.03.17.42`.

# 260317-043
- Files: `fUI_GOTradeUI.lua`, `fr0z3nUI_GameOptions.toc`
- Trade/Deposit: when cycling bank targets, force an Items list rebuild via an exposed list-builder fallback (and print which refresh function is being used when Trade `Debug` is enabled).
- Bumped TOC `## Version` to `2026.03.17.43`.

# 260317-044
- Files: `fUI_GOTradeUI.lua`, `fr0z3nUI_GameOptions.toc`
- Trade/Deposit: add entry-trace for the Items list builder and wrap refresh/build calls in `pcall` to surface any errors preventing the list from rebuilding/printing debug output.
- Bumped TOC `## Version` to `2026.03.17.44`.

# 260317-045
- Files: `fUI_GOTradeUI.lua`, `fr0z3nUI_GameOptions.toc`
- Trade/Deposit: wrap the list-count debug block in `pcall` and print any caught errors so we can see why `TradeUI list: ...` isn’t showing.
- Bumped TOC `## Version` to `2026.03.17.45`.

# 260317-046
- Files: `fUI_GOTradeUI.lua`, `fr0z3nUI_GameOptions.toc`
- Trade/Deposit: change the list-count debug line to use safe string concatenation (`tostring`) instead of `string.format`, to avoid any formatting/type issues hiding the output.
- Bumped TOC `## Version` to `2026.03.17.46`.

# 260317-047
- Files: `fUI_GOTradeUI.lua`, `fr0z3nUI_GameOptions.toc`
- Trade/Deposit: reduce debug spam during Items list rebuilds so the important per-target counts line reliably shows in chat.
- Bumped TOC `## Version` to `2026.03.17.47`.

# 260317-048
- Files: `fUI_GOTradeUI.lua`, `fr0z3nUI_GameOptions.toc`
- Trade/Deposit: when cycling bank targets with Trade `Debug` enabled, print the per-scope rule counts for the newly selected target directly (bypasses any Items list UI refresh issues).
- Bumped TOC `## Version` to `2026.03.17.48`.

# 260317-049
- Files: `fUI_GOTradeUI.lua`, `fr0z3nUI_GameOptions.toc`
- Trade/Deposit: merge target-cycle + per-scope counts into a single debug line (avoids chat dropping the “second line” during rapid refresh/rebuild).
- Bumped TOC `## Version` to `2026.03.17.49`.

# 260317-050
- Files: `fUI_GOTradeUI.lua`, `fr0z3nUI_GameOptions.toc`
- Trade/Deposit: fix the combined target-cycle debug line being swallowed by WoW chat due to a literal `|` (escape prefix) in the message.
- Bumped TOC `## Version` to `2026.03.17.50`.

# 260317-051
- Files: `fUI_GOTradeUI.lua`, `fr0z3nUI_GameOptions.toc`
- Trade/Deposit: print target-cycle + per-scope rule counts on the same click/refresh debug line so the numbers can’t be lost as a separate chat message.
- Bumped TOC `## Version` to `2026.03.17.51`.

# 260317-052
- Files: `fUI_GOTradeUI.lua`, `fr0z3nUI_GameOptions.toc`
- Trade/Deposit: emit the cycle+counts debug line via `DEFAULT_CHAT_FRAME:AddMessage` (with `|` escaping) to guarantee it shows even if addon `Print()` routing drops it.
- Bumped TOC `## Version` to `2026.03.17.52`.

# 260317-040
- Files: `fUI_GOTradeBank.lua`, `fUI_GOTradeUI.lua`, `fr0z3nUI_GameOptions.toc`
- Trade/Deposit: fix empty Personal/Guild/Warbank Items lists when rules existed under legacy target keys (migrates `either`/`personalbank`/`guildbank`/`warband` into `bank`/`personal`/`guild`/`warbank`).
- Bumped TOC `## Version` to `2026.03.17.40`.

# 260317-041
- Files: `fUI_GOTradeUI.lua`, `fr0z3nUI_GameOptions.toc`
- Trade/Deposit: when Trade `Debug` is enabled, the Items list now prints the detected target and rule counts per scope so we can see exactly why a per-target list appears empty.
- Bumped TOC `## Version` to `2026.03.17.41`.

# 260317-039
- Files: `fUI_GOTradeUI.lua`, `fr0z3nUI_GameOptions.toc`
- Trade/Deposit: when selecting a Warbound item auto-switches the deposit target to Warbank, the right-side Items list now switches/refreshes too (and scope edits apply to the Warbank list immediately).
- Bumped TOC `## Version` to `2026.03.17.39`.

# 260317-036
- Files: `fUI_GOMacroHome.lua`, `fUI_GOMacroUI.lua`, `fr0z3nUI_GameOptions.toc`
- HM Alliance/Horde (Home1/Home2): moved the saved destinations to account-wide storage (`AutoGame_Settings.fgoHomeTeleports`) so you don't have to capture per-character.
- Migration: if legacy per-character slots exist, they are copied into the account table when missing.
- Bumped TOC `## Version` to `2026.03.17.36`.

# 260317-037
- Files: `fUI_GOMacroHome.lua`, `fr0z3nUI_GameOptions.toc`
- HM Portal: added `/fgo hm portal status` debug output (shows saved target + secure button attributes + cooldown) and reduced misleading spam (won't claim "Found ID" unless a stale-GUID retry actually occurred).
- Bumped TOC `## Version` to `2026.03.17.37`.

# 260317-038
- Files: `fUI_GOMacroHome.lua`, `fr0z3nUI_GameOptions.toc`
- Fix: HM Portal no longer errors on click due to a Lua local-scope ordering bug (`GetPlayerFactionKey` being treated as a missing global).
- Bumped TOC `## Version` to `2026.03.17.38`.

# 260317-035
- Files: `fUI_GOMacroHome.lua`, `fUI_GOMacroUI.lua`, `fr0z3nUI_GameOptions.toc`
- HM Portal: redesigned to use a dedicated secure-click button (`/click FGO_HMPortalTeleport`) backed by an account-wide saved target per faction (capture with `/fgo hm portal set` while standing in the desired +Friend plot).
- Slash: `/fgo hm portal` now prints the macro body + capture instructions (no longer tries to execute secure teleports directly).
- Bumped TOC `## Version` to `2026.03.17.35`.

# 260317-034
- Files: `fr0z3nUI_GameOptions.lua`, `fr0z3nUI_GameOptions.toc`
- Slash: `/fgo mountequip` warning text now says “Mount needs Inflatable Mount Shoes”.
- Bumped TOC `## Version` to `2026.03.17.34`.

# 260317-033
- Files: `fUI_GOTalkUP.lua`, `fr0z3nUI_GameOptions.toc`
- TalkUP: added a conservative fallback to auto-confirm Spirit Healer-style resurrect popups when they fire as `DEATH`/`XP_LOSS` without any gossip option selection context (gated by popup text).
- Bumped TOC `## Version` to `2026.03.17.33`.

# 260317-032
- Files: `fUI_GOTalkUP.lua`, `fUI_GOTalk01KD.lua`, `fr0z3nUI_GameOptions.toc`
- TalkUP: Spirit Healer resurrect confirm can fire as `XP_LOSS`; treat it as a gossip-ish confirm so existing `GOSSIP_CONFIRM` rules can match.
- Talk DB: expanded Spirit Healer confirm-text matching to cover XP-loss phrasing.
- Bumped TOC `## Version` to `2026.03.17.32`.

# 260317-031
- Files: `fUI_GOTalkUP.lua`, `fUI_GOTalk01KD.lua`, `fr0z3nUI_GameOptions.toc`
- TalkUP: allow Spirit Healer resurrect confirmation popups to auto-confirm even when they fire as `DEATH` (no reliable gossip option selection).
- Talk DB: made the Spirit Healer confirm-text match more tolerant (corpse wording variants).
- Bumped TOC `## Version` to `2026.03.17.31`.

# 260317-030
- Files: `README.md`, `fr0z3nUI_GameOptions.toc`
- Docs: expanded the Loot tab section to cover the “Achievement / Experience / Professions” output controls (Bonus/Quest/XP Label) and the `Alias`/`Info` popouts.
- Bumped TOC `## Version` to `2026.03.17.30`.

# 260317-029
- Files: `README.md`, `fr0z3nUI_GameOptions.toc`
- Docs: rewrote the README into a GUI-first “FGO for Dummies” style guide (ACC vs CHAR, Switches segmented controls/TooltipX, and click-by-click workflows per tab).
- Bumped TOC `## Version` to `2026.03.17.29`.

# 260317-028
- Files: `README.md`, `fr0z3nUI_GameOptions.toc`
- Docs: expanded the README into a proper “what this addon is + how to use it” guide (tab overview + updated `/fgo` command cheat sheet).
- Bumped TOC `## Version` to `2026.03.17.28`.

# 260317-027
- Files: `fUI_GOLootChat.lua`, `fr0z3nUI_GameOptions.toc`
- Fix: resolved a chat-frame hook error (`FormatSelfLine` nil) triggered by direct money receipt prints after adding AddMessage capture logging.
- Bumped TOC `## Version` to `2026.03.17.27`.

# 260317-026
- Files: `fUI_GOLootChat.lua`, `fr0z3nUI_GameOptions.toc`
- LootIt: capture debug now logs direct chat-frame `AddMessage` prints (which can bypass normal chat event filters), so `/fgo li capture dump` can see lines like the textureless money “You gained: …” case.
- Bumped TOC `## Version` to `2026.03.17.26`.

# 260317-025
- Files: `fUI_GOLootChat.lua`, `fr0z3nUI_GameOptions.toc`
- LootIt: money capture/reprint now recognizes textureless numeric coin lines like `You gained: 7,536 63 26` (gold/silver/copper) so they can be suppressed/reprinted/combined like normal money messages.
- Bumped TOC `## Version` to `2026.03.17.25`.

# 260317-024
- Files: `fr0z3nUI_GameOptions.lua`, `fUI_GOSwitchesCT.lua`, `fr0z3nUI_GameOptions.toc`
- Chromie Time (GUI): bottom-of-window status label is now anchored to the full FGO window width to prevent truncation like `Chromie Ti...`.
- Chromie Time (floating indicator): reverted the earlier auto-sizing behavior back to the original fixed-size indicator.
- Bumped TOC `## Version` to `2026.03.17.24`.

# 260317-023
- Files: `fUI_GOSwitchesCT.lua`, `fr0z3nUI_GameOptions.toc`
- Chromie indicator: the movable “Chromie Time” indicator frame now auto-sizes its width to the text (prevents truncation like `Chromie Ti...`).
- Bumped TOC `## Version` to `2026.03.17.23`.

# 260317-022
- Files: `fr0z3nUI_GameOptions.lua`, `fr0z3nUI_GameOptions.toc`
- UI: reordered the tab buttons into alphabetical order (visual order only; tab IDs/panels unchanged).
- Bumped TOC `## Version` to `2026.03.17.22`.

# 260317-021
- Files: `fUI_GOTax.lua`, `fr0z3nUI_GameOptions.toc`
- Tax: guild home realm no longer gets stuck as `UNKNOWN` when WoW omits the realm string for same-realm guilds.
- Bumped TOC `## Version` to `2026.03.17.21`.

# 260317-020
- Files: `fr0z3nUI_GameOptions.lua`, `fr0z3nUI_GameOptions.toc`
- UI: renamed the tab label from `LootIt` to `Loot`.
- Bumped TOC `## Version` to `2026.03.17.20`.

# 260317-019
- Files: `fr0z3nUI_GameOptions.lua`, `fUI_GOTaleUI.lua`, `fUI_GOTaxUI.lua`, `fr0z3nUI_GameOptions.toc`
- Chromie Time: replaced the old 2-line top-right label with a single-line bottom-center status line on the Switches/Tabard/Tale/Talk/Textures/LootIt/Tax/Trade tabs.
- Tale UI: shortened `Print`/`Debug` buttons; made the Print threshold input frameless.
- Tax UI: moved the `Manual` toggle button below `Min Gold`.
- Bumped TOC `## Version` to `2026.03.17.19`.

# 260317-018
- Files: `fUI_GOTaxUI.lua`, `fr0z3nUI_GameOptions.toc`
- Tax UI: moved the guild name line up slightly to add space below it.
- Bumped TOC `## Version` to `2026.03.17.18`.

# 260317-017
- Files: `fUI_GOTaxUI.lua`, `fr0z3nUI_GameOptions.toc`
- Tax: cache the detected guild name + home realm per character once known, and update the cache if it changes.
- Tax UI: if the home realm is temporarily unknown, reuse the cached home realm for that character (otherwise show `UNKNOWN`).
- Bumped TOC `## Version` to `2026.03.17.17`.

# 260317-016
- Files: `fUI_GOTax.lua`, `fUI_GOTaxUI.lua`, `fr0z3nUI_GameOptions.toc`
- Tax UI: guild name keeps its original large auto-fit sizing; the realm line stays smaller (button-text sized).
- Tax UI: when the guild home realm can’t be determined, the realm line now shows `UNKNOWN` (no fallback to your current realm).
- Bumped TOC `## Version` to `2026.03.17.16`.

# 260317-015
- Files: `fUI_GOTextures.lua`, `fr0z3nUI_GameOptions.toc`
- Textures: stop printing the “ArtLayer migration already completed …” line on every `/reload` (now only prints when Textures debug is ON).
- Bumped TOC `## Version` to `2026.03.17.15`.

# 260317-014
- Files: `fUI_GOSituatePF.lua`, `fr0z3nUI_GameOptions.toc`
- Popouts: fixed “one popout at a time” by initializing the popout manager early (so modules that register popouts during load are actually registered).
- Bumped TOC `## Version` to `2026.03.17.14`.

# 260317-013
- Files: `fUI_GOLootUI.lua`, `fr0z3nUI_GameOptions.toc`
- LootIt Suppress: popout now opens out to the right (Mail-style) instead of hovering over the tab, and uses the cleaner popout backdrop styling.
- Bumped TOC `## Version` to `2026.03.17.13`.

# 260317-012
- Files: `fUI_GOLootChat.lua`, `fr0z3nUI_GameOptions.toc`
- Fix: resolved a login-time chat-hook crash when `IsSecretString` is not defined (suppression helpers now correctly use a local secret-string guard).
- Bumped TOC `## Version` to `2026.03.17.12`.

# 260317-011
- Files: `fUI_GOTax.lua`, `fUI_GOTaxUI.lua`, `fr0z3nUI_GameOptions.toc`
- Tax: guild identity is now keyed by Guild GUID (best-effort migration from legacy `realm::guildName` buckets for the current guild).
- Tax UI: guild header is now two lines: Guild name + Home realm (both faction-colored).
- Bumped TOC `## Version` to `2026.03.17.11`.

# 260317-010
- Files: `fr0z3nUI_GameOptions.lua`, `fUI_GOLootUI.lua`, `fUI_GOTexturesUI.lua`, `fUI_GOCore.lua`, `fUI_GOMacroUI.lua`, `fUI_GOSituateUI.lua`, `fUI_GOSwitchesBP.lua`, `fUI_GOSwitchesCT.lua`, `fUI_GOSwitchesMU.lua`, `fUI_GOTradeUI.lua`, `fr0z3nUI_GameOptions.toc`
- Suppress: moved the `Suppress` button/popout onto the LootIt tab (tab-local parent), while keeping it positioned above the main `Reload UI` button.
- Popouts: added a small registry so only one popout can be open at a time (opening any popout auto-closes the rest).
- LootIt: removed the accidental dedicated `ERG` suppression toggle; ERG noise should be handled via the generic Suppress rules list.
- Bumped TOC `## Version` to `2026.03.17.10`.

# 260317-005
- Files: `fUI_GOLootUI.lua`, `fUI_GOLootChat.lua`, `fUI_GOCore.lua`, `fr0z3nUI_GameOptions.toc`
- LootIt UI: added a `Played` toggle next to `Debug` (default OFF) that hides `/played` system output lines.
- Loot Experience: `Quest` mode now also suppresses quest-log removal lines like “The quest X has been removed from your quest log.”
- Tooltips: updated the `Quest` and `Before/After` (XP label position) tooltips for clarity.
- Bumped TOC `## Version` to `2026.03.17.05`.

# 260317-006
- Files: `fUI_GOLootUI.lua`, `fr0z3nUI_GameOptions.toc`
- LootIt UI: moved the LootIt tab contents down so the Enable button no longer overlaps the tab strip.
- Bumped TOC `## Version` to `2026.03.17.06`.

# 260317-007
- Files: `fUI_GOLootUI.lua`, `fr0z3nUI_GameOptions.toc`
- LootIt UI: aligned `Debug`/`Played` buttons with the main `Reload UI` button row.
- Bumped TOC `## Version` to `2026.03.17.07`.

# 260317-008
- Files: `fUI_GOLootChat.lua`, `fr0z3nUI_GameOptions.toc`
- Played: fixed suppression for `/played` lines that bypass chat event filters (direct `AddMessage` prints).
- Bumped TOC `## Version` to `2026.03.17.08`.

# 260317-009
- Files: `fr0z3nUI_GameOptions.lua`, `fUI_GOLootChat.lua`, `fUI_GOCore.lua`, `fr0z3nUI_GameOptions.toc`
- Suppress: added a `Suppress` popout button above `Reload UI` with an SV-backed, per-line substring suppress list (toggle/add/delete).
- Suppress: rules apply to both chat event filters and direct `AddMessage` prints (covers many addon `Print()` spam lines).
- Bumped TOC `## Version` to `2026.03.17.09`.

# 260317-001
- Files: `fUI_GOLootChat.lua`, `fr0z3nUI_GameOptions.toc`
- Loot Experience: suppress the original XP system/combat chat line when the parser can’t match it (prevents duplicate lines when XP_UPDATE fallback prints).
- Loot Experience: for quest XP, append the most recent turned-in quest title (from `QUEST_TURNED_IN`) when available.
- Bumped TOC `## Version` to `2026.03.17.01`.

# 260317-002
- Files: `fUI_GOMacroXCMD.lua`, `fr0z3nUI_GameOptions.toc`
- Macro-XCMD: stop injecting `/stopmacro [advfly]` (it causes the in-game error “Unknown macro option: advfly”).
- Bumped TOC `## Version` to `2026.03.17.02`.

# 260317-003
- Files: `fUI_GOLootChat.lua`, `fr0z3nUI_GameOptions.toc`
- Loot Experience: suppress and reprint the quest system lines (`Quest accepted:` / `Quest completed:`) when experience rewriting is enabled, so the stock “completed” line doesn’t linger.
- Bumped TOC `## Version` to `2026.03.17.03`.

# 260317-004
- Files: `fUI_GOLootUI.lua`, `fUI_GOLootChat.lua`, `fUI_GOCore.lua`, `fr0z3nUI_GameOptions.toc`
- Loot Experience: added a separate `Quest` toggle button (next to `Bonus`) that hides the quest Accepted/Completed system lines.
- Loot Experience: when `Quest` is ON, only the quest *title* from the Completed line is appended to the XP gain output (e.g. `12345 XP Temple Throwdown`).
- Bumped TOC `## Version` to `2026.03.17.04`.

# 260316-030
- Files: `fr0z3nUI_GameOptions.lua`, `fr0z3nUI_GameOptions.toc`
- Slash: fixed `/fgo deposit` being mis-parsed as Macro-CMD mode `/fgo d eposit` (caused by the single-letter mode “glue” parser for `/fgo d <key>`).
- Bumped TOC `## Version` to `2026.03.16.33`.


# 260317-066
- Files: `fUI_GOTrade.lua`, `fr0z3nUI_GameOptions.toc`
- Deposit (Slash): `/fgo deposit` is now the only run-mode depositor; any explicit target word (e.g. `personal/guild/warbank`) is ignored so deposit always follows the currently open bank UI.
- Deposit (Slash): `/fgo deposit status|debug [target]` still accepts an optional target argument for reporting only.
- Bumped TOC `## Version` to `2026.03.17.66`.
# 260316-031
- Files: `fUI_GOLootChat.lua`, `fr0z3nUI_GameOptions.toc`
- Loot Experience: pad the XP number block with dim `0`s instead of leading spaces (better alignment in proportional chat fonts).
- Bumped TOC `## Version` to `2026.03.16.34`.

# 260316-032
- Files: `fr0z3nUI_GameOptions.lua`, `fr0z3nUI_GameOptions.toc`
- Slash: added direct `/fgo deposit` routing to the hosted LootIt/Trade deposit helper (previously only worked as `/fgo li deposit`).
- Bumped TOC `## Version` to `2026.03.16.35`.

# 260316-033
- Files: `fr0z3nUI_GameOptions.lua`, `fr0z3nUI_GameOptions.toc`
- Slash: removed `/fgo li` bloat for common LootIt commands by promoting them to top-level: `/fgo mail ...`, `/fgo alias ...`, `/fgo capture ...`, `/fgo chatdebug ...`, `/fgo delayflush ...`, `/fgo status`.
- Parser: marked these as known full commands so they won't be split by Macro-CMD mode glue (e.g. `mail` no longer becomes `m ail`).
- Help: updated `/fgo li ?` output to show the new `/fgo ...` commands (kept `/fgo li on|off|toggle`).
- Bumped TOC `## Version` to `2026.03.16.36`.

# 260316-034
- Files: `fr0z3nUI_GameOptions.lua`, `fr0z3nUI_GameOptions.toc`
- Help: changed LootIt help output and `/fgo scope` to prefer `/fgo lootit ...` (kept `/fgo li ...` as a legacy alias).
- Slash: added `/fgo trade food ...` as an alias for the Trade "food" helper command.
- Bumped TOC `## Version` to `2026.03.16.37`.

# 260316-026
- Files: `fUI_GOTalk.lua`, `fr0z3nUI_GameOptions.toc`
- Gossip rules: support `mount = true` to disable MountUp (Character) silently (equivalent to `/fgo mu soff`) before auto-selecting the matched gossip option.
- Bumped TOC `## Version` to `2026.03.16.29`.

# 260316-027
- Files: `fUI_GOTalk.lua`, `fr0z3nUI_GameOptions.toc`
- Gossip rules: `mount = true` now also dismounts silently before auto-select (safeguarded to avoid dismounting while flying/falling).
- Bumped TOC `## Version` to `2026.03.16.30`.

# 260316-028
- Files: `fUI_GOSwitchesMU.lua`, `fr0z3nUI_GameOptions.toc`
- MountUp: improved reliability by re-arming a mount attempt after player cast/channel completion and after loot closes (fixes common gather case where MountUp would not re-trigger until you moved).
- Bumped TOC `## Version` to `2026.03.16.31`.

# 260316-029
- Files: `fUI_GOTalk06.lua`, `fr0z3nUI_GameOptions.toc`
- Talk DB (Draenor pet battles): removed `xpop` confirm metadata (no confirm popup), keeping `mount = true` behavior.
- Bumped TOC `## Version` to `2026.03.16.32`.

# 260316-025
- Files: `fUI_GOTradeUI.lua`, `fr0z3nUI_GameOptions.toc`
- UI (Trade): list header now uses mode-specific titles: `Bank Items`/`Personal Items`/`Guild Items`/`Warbank Items`, `Purchase Items`, `Sell Items`.
- UI (Trade): removed the “Deposit/Buy/Sell … rules: #” subtitle; `Rules: #` is now in the top-right of the list window.
- UI (Trade): item rows sit directly under the list title; list frame is lifted to avoid overlapping the main `Reload UI` row.
- UX (Trade): the list refreshes immediately after adding/removing an item rule.
- Bumped TOC `## Version` to `2026.03.16.28`.

# 260316-014
- Files: `fUI_GOCore.lua`, `fr0z3nUI_GameOptions.lua`, `fr0z3nUI_GameOptions.toc`
- Core boundary: moved the main addon event frame + event registrations out of `fr0z3nUI_GameOptions.lua` into `fUI_GOCore.lua` so runtime/event wiring is early; core now delegates to `ns.FGO_OnEvent(...)` implemented in main.
- Bumped TOC `## Version` to `2026.03.16.17`.

# 260316-015
- Files: `fUI_GOCore.lua`, `fUI_GOTextureMail.lua`, `fUI_GOTradeBank.lua`, `fr0z3nUI_GameOptions.toc`
- Fix: resolved Lua load/runtime blockers (`<eof>`/unexpected `end`) in core + mail notifier module; repaired `Mail.HandleSlash` debug handling.
- Safety: guarded `DepositCfgAcc()` against nil DB during early load to avoid TradeBank crashing on startup.
- Bumped TOC `## Version` to `2026.03.16.18`.

# 260316-016
- Files: `fr0z3nUI_GameOptions.lua`, `fUI_GOTexturesUI.lua`, `fr0z3nUI_GameOptions.toc`
- UI: LootIt/Tax/Trade tabs now render inside a proper content inset (below the tab bar) to prevent controls being clipped/out-of-frame.
- UI: Mail config popout now opens beside the main window (instead of centered over it).
- Bumped TOC `## Version` to `2026.03.16.19`.

# 260316-017
- Files: `fr0z3nUI_GameOptions.lua`, `fUI_GOTaxUI.lua`, `fr0z3nUI_GameOptions.toc`
- UI: Tax tab now reuses the main frame `Reload UI` button when available (prevents a duplicate Reload button on the Tax tab).
- Bumped TOC `## Version` to `2026.03.16.20`.

# 260316-018
- Files: `fUI_GOTexturesUI.lua`, `fr0z3nUI_GameOptions.toc`
- UI: Mail popout no longer anchors its Debug button to the main window (prevents Debug appearing on the Textures tab when Mail is opened).
- Bumped TOC `## Version` to `2026.03.16.21`.

# 260316-019
- Files: `fUI_GOTradeUI.lua`, `fr0z3nUI_GameOptions.toc`
- UI: Trade tab now uses a left/right split layout; controls are contained on the left.
- UI: Items list is now a permanent right-side panel (no toggle popout) and refreshes when mode/target changes (e.g. Bank button).
- Bumped TOC `## Version` to `2026.03.16.22`.

# 260316-020
- Files: `fUI_GOTexturesUI.lua`, `fUI_GOTaxUI.lua`, `fr0z3nUI_GameOptions.toc`
- Fix: Mail popout now lazily (re)builds its UI on open so it can’t get stuck blank after `/reload`.
- UI: Tax owed rows now align under the Vendor↔Loot and Mail↔System gaps (instead of a generic left/right split).
- Bumped TOC `## Version` to `2026.03.16.23`.

# 260316-021
- Files: `fUI_GOTexturesUI.lua`, `fUI_GOTextureMail.lua`, `fr0z3nUI_GameOptions.toc`
- Fix: Mail popout now preloads/builds its content once the Mail module is available (tab-style), even if the popout was opened early.
- Bumped TOC `## Version` to `2026.03.16.24`.

# 260316-022
- Files: `fUI_GOSwitchesUI.lua`, `fUI_GOTexturesUI.lua`, `fUI_GOSwitchesMN.lua`, `fr0z3nUI_GameOptions.toc`
- UI: moved Mail Notifier controls to the Switches tab using a 3-segment control (Mail=ACC on/off, Enable=CHAR on/off, Config=popout).
- UI: removed the obsolete enable/mode button from the Mail Notifier popout; updated the popout title to “Mail Notifier”; removed the Textures header Mail button.
- Rename: `fUI_GOTextureMail.lua` → `fUI_GOSwitchesMN.lua`.
- Bumped TOC `## Version` to `2026.03.16.25`.

# 260316-023
- Files: `fr0z3nUI_GameOptions.lua`, `fUI_GOTexturesUI.lua`, `fr0z3nUI_GameOptions.toc`
- Fix: ensured LootIt hosted env wiring runs at addon load (not just after using `/fgo li`), so the Mail Notifier popout config fields populate reliably.
- Safety: Mail Notifier popout also wires env on-demand before building UI.
- Bumped TOC `## Version` to `2026.03.16.26`.

# 260316-024
- Files: `fUI_GOTexturesUI.lua`, `fr0z3nUI_GameOptions.toc`
- Fix: after building the Mail Notifier popout, it now calls the embedded mail editor `Refresh()` immediately so controls populate without needing to click Scope.
- Bumped TOC `## Version` to `2026.03.16.27`.

# 260316-013
- Files: `fUI_GOCore.lua`, `fUI_GOLootAliasDB.lua`, `fUI_GOLoot.lua`, `fUI_GOLootChat.lua`, `fUI_GOLootAlias.lua`, `fUI_GOLootUI.lua`, `fUI_GOTrade.lua`, `fUI_GOTradeBank.lua`, `fUI_GOTradeUI.lua`, `fUI_GOTextureMail.lua`, `fUI_GOTax.lua`, `fUI_GOTaxUI.lua`, `fUI_GOTexturesUI.lua`, `fr0z3nUI_GameOptions.toc`
- LootIt: migrated remaining module entrypoints to prefer the shared addon namespace `ns.LootIt` (global kept only as a fallback/compat alias).
- LootIt: moved `fUI_GOLootAliasDB.lua` earlier in the TOC so built-in alias tables exist before core snapshots them.
- Bumped TOC `## Version` to `2026.03.16.16`.

# 260316-011
- Files: `fUI_GOCore.lua`, `fr0z3nUI_GameOptions.lua`, `fr0z3nUI_GameOptions.toc`
- LootIt/Core: moved the UI shim + bootstrap wiring + `/fgo li` handler implementation out of core and into the main GameOptions file (core is now runtime/DB/events only).
- LootIt/Main: main now calls `LI.Bootstrap.WireAll(LI.CoreBuildBootstrapEnv())` once at load.
- Bumped TOC `## Version` to `2026.03.16.14`.

# 260316-012
- Files: `fUI_GOCore.lua`, `fr0z3nUI_GameOptions.lua`, `fr0z3nUI_GameOptions.toc`
- LootIt: treat this as a single addon namespace — core now publishes LootIt as `ns.LootIt`, and the main file prefers `ns.LootIt` over `_G.fr0z3nUI_LootIt` (global kept only as a compatibility alias).
- Bumped TOC `## Version` to `2026.03.16.15`.

# 260316-010
- Files: `fUI_GOCore.lua`, `fr0z3nUI_GameOptions.toc`
- LootIt/Core: renamed `fUI_GOLootItHost.lua` to `fUI_GOCore.lua` (no logic changes; just a cleanup rename).
- Bumped TOC `## Version` to `2026.03.16.13`.

# 260316-009
- Files: `fUI_GOLootItHost.lua`, `fr0z3nUI_GameOptions.toc`
- LootIt/Core: merged the former `fUI_GOLootBootstrap.lua` (UI/env wiring) and `fUI_GOLootUIV.lua` (slash handler) into the Host/core file; removed both from the TOC so LootIt initializes from a single early file.
- Bumped TOC `## Version` to `2026.03.16.12`.

# 260316-008
- Files: `fUI_GOLootUI.lua`, `fr0z3nUI_GameOptions.toc`
- LootIt/UI: the LootIt panel Reset button now clears the new FGO-backed SV tables (`AutoGame_Acc.lootIt`, `AutoGame_Char.lootIt`) in-place (so reset works after SV consolidation).
- Bumped TOC `## Version` to `2026.03.16.11`.

# 260316-007
- Files: `fUI_GOLootItHost.lua`, `fr0z3nUI_GameOptions.toc`
- SavedVariables: hosted LootIt/Tax/Trade now persist inside FGO SV (`AutoGame_Acc.lootIt`, `AutoGame_Char.lootIt`); removed `fr0z3nUI_LootItDB` / `fr0z3nUI_LootItCharDB` from the TOC.
- Note: this resets prior LootIt settings unless they are reconfigured.
- Bumped TOC `## Version` to `2026.03.16.10`.

# 260316-006
- Files: `fUI_GOTradeBank.lua`, `fUI_GOLootItHost.lua`, `fUI_GOTrade.lua`, `fr0z3nUI_GameOptions.toc`
- LootIt/Trade: extracted the full deposit/bank engine (deposit runners, deposit button, bank ticker, bank-open state, guild bank query session helpers) into the dedicated `fUI_GOTradeBank.lua` file.
- LootIt/Host: rewired event wiring to call the moved exports (`LI.RunDeposit`, `LI.UpdateDepositButtonVisibility`, bank interaction open/close setters, bank ticker start/stop), keeping Host focused on wiring.
- LootIt/Trade: removed bank/deposit lifecycle handlers from `fUI_GOTrade.lua` so there is a single source of truth.
- Fix: repaired an accidental corruption in `fUI_GOTrade.lua` during handler removal (restored player-name color helper + realm/scope trade-rule resolution).
- Fix: restored missing `DepositCfgChar()` buy tables in `fUI_GOTradeBank.lua` and fixed guild-bank helper scoping (local `QueryGuildBankTabIfNeeded`, local `GetCurrentGuildKey`).
- Bumped TOC `## Version` to `2026.03.16.09`.

# 260316-005
- Files: `fUI_GOTrade.lua`, `fr0z3nUI_GameOptions.toc`
- LootIt/Trade: moved the merchant vendor buy/sell/restock engine (merchant ticker + rule resolution + food selling/restock helpers) into `fUI_GOTrade.lua` so Trade owns Trade.
- Fix: restores missing `StartMerchantTradeTicker` / `StopMerchantTradeTicker` / `RunMerchantTradeOnce` that were previously only present in older/live Host code.
- Fix: `GetItemRequiredPlayerLevel()` now reads the correct `GetItemInfo` return (avoids treating item level as required level when uncached).
- Slash: `/fgo li food debug` now falls back to `LI.DebugSellOldFoodAtMerchant` when the env debug hook isn’t present.
- Bumped TOC `## Version` to `2026.03.16.08`.

# 260316-003
- Files: `fr0z3nUI_GameOptions.lua`, `fUI_GOTexturesUI.lua`, `fUI_GOLootBootstrap.lua`, `fUI_GOLootItHost.lua`, `fr0z3nUI_GameOptions.toc`
- UI: promoted LootIt’s former internal tabs to native FGO tabs: `LootIt`, `Tax`, `Trade`.
- UI: Mail config is now a `Mail` button popout on the `Textures` tab (no separate LootIt config window / nested tabs).
- Compat: LootIt’s existing `CreateConfigUI()` / `SelectTab("mail")` calls now route into the FGO window + Mail popout.
- Cleanup: removed `fUI_GOLootItUI.lua` (UI shim now lives in `fUI_GOLootBootstrap.lua`).
- Bumped TOC `## Version` to `2026.03.16.04`.

# 260316-004
- Files: `fr0z3nUI_GameOptions.toc`, `fUI_GOLootItHost.lua`, `fUI_GOLoot.lua`, `fUI_GOLootChat.lua`, `fUI_GOLootUIV.lua`, `fUI_GOLootUI.lua`, `fUI_GOLootAlias.lua`, `fUI_GOLootBootstrap.lua`, `fUI_GOTrade.lua`, `fUI_GOTradeUI.lua`
- LootIt: consolidated bootstrap so `fUI_GOLootItHost.lua` loads first and owns `LI.ADDON` + `[FGO]` prefix.
- Cleanup: removed unused `fUI_GOLootItNS.lua` (ns-bridge).
- Cleanup: removed redundant per-file `fr0z3nUI_LootIt = LI` bootstrapping; LootIt modules now depend on Host and avoid side effects.
- Bumped TOC `## Version` to `2026.03.16.07`.

# 260316-002
- Files: `fr0z3nUI_GameOptions.lua`, `fr0z3nUI_GameOptions.toc`, `fUI_GOLootItHost.lua`, `fUI_GOLootBootstrap.lua`, `fUI_GOLootUIV.lua`, `fUI_GOLoot.lua`, `fUI_GOLootAlias.lua`, `fUI_GOLootChat.lua`, `fUI_GOTrade.lua`, `fUI_GOTextureMail.lua`
- Slash: removed LootIt’s `/fli` registration from the FGO build; LootIt is now driven by the native `/fgo` router.
- Slash: added `/fgo li ...` (and `/fgo lootit ...` alias) for LootIt commands; avoids collision with existing `/fgo loot` (Auto Loot).
- Output: LootIt host output prefix now shows `[FGO]` so it feels native.
- Bumped TOC `## Version` to `2026.03.16.02`.

# 260316-001
- Files: `fr0z3nUI_GameOptions.toc`, `fUI_GOLootIt*.lua`, `fUI_GOLoot*.lua`, `fUI_GOTrade*.lua`, `fUI_GOTax*.lua`, `fUI_GOTextureMail.lua`
- LootIt: hosted inside FGO (modules migrated as `fUI_GO*`; no `fr0z3nUI_LootIt*` wrapper spam).
- Safety: added a double-load guard so enabling standalone LootIt at the same time won’t double-init.
- Bumped TOC `## Version` to `2026.03.16.01`.

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


# 260313-051
- Files: `fUI_GOSituatePF.lua`, `fUI_GOSituate.lua`, `fUI_GOSituateUI.lua`, `fr0z3nUI_GameOptions.toc`
- Situate: Expansion detection now prefers continent `mapID` mapping (locale-independent), fixing the `Expansion` button showing Unknown on non-English clients.
- SituatePF: avoid caching an all-nil `GetProfessions()` result as "no professions" on first refresh; Profession button now sees the character's professions once skills are loaded.
- Situate/UI: Profession list refresh now forces a profession-key refresh when opening/using the account Profession selector.
- Bumped TOC `## Version` to `2026.03.13.51`.


# 260313-052
- Files: `fUI_GOSwitchesUI.lua`, `fr0z3nUI_GameOptions.toc`
- Switches/UI: moved both columns up by ~1.5 button heights.
- Bumped TOC `## Version` to `2026.03.13.52`.


# 260313-053
- Files: `fUI_GOSituate.lua`, `fUI_GOSituateUI.lua`, `fr0z3nUI_GameOptions.lua`, `fr0z3nUI_GameOptions.toc`
- Situate: expansion detection now resolves by matching known continent mapIDs anywhere in the map parent chain (less dependent on `mapType`).
- Slash: added `/fgo situate info` to print map ancestry + resolved expansion key + cached profession keys for debugging.
- Bumped TOC `## Version` to `2026.03.13.53`.


# 260313-054
- Files: `fUI_GOSituate.lua`, `fUI_GOSituateUI.lua`, `fr0z3nUI_GameOptions.toc`
- Situate: added Midnight zone mapID fallbacks so Expansion resolves to `midnight` in Quel'Thalas/Midnight zones even before continent/root mapIDs are confirmed.
- Bumped TOC `## Version` to `2026.03.13.54`.


# 260313-055
- Files: `fUI_GOSituateUI.lua`, `fr0z3nUI_GameOptions.toc`
- Situate/UI: fixed drag/drop from the Professions/Spellbook UI by resolving cursor `spell` drags (spellbook index + bookType) into a real spellID before writing.
- Bumped TOC `## Version` to `2026.03.13.55`.


# 260313-056
- Files: `fUI_GOSwitchesUI.lua`, `fr0z3nUI_GameOptions.toc`
- Switches/UI: moved both columns down by ~0.5 button height.
- Bumped TOC `## Version` to `2026.03.13.56`.


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
