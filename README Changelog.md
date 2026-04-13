# fr0z3nUI_GameOptions — Changelog

Format: `YYYY.MM.DD.NN` (TOC `## Version`) — short summary. Newest at the top.

Discipline: bump TOC `## Version` on every behavior/UI change (sanity check stays meaningful).

## 2026.04.13.18
- Files: `fUI_GOSwitchesMU.lua`, `README Changelog.md`, `fr0z3nUI_GameOptions.toc`
- MountUp: Treat aura/spellID `1269922` as Food (eating) so MU won't interrupt/attempt mount while the buff is active.

## 2026.04.13.17
- Files: `fr0z3nUI_GameOptions.lua`, `README Changelog.md`, `fr0z3nUI_GameOptions.toc`
- Fix: Restore pre-existing `/fgo fish` help/scope output and keep migrating legacy `cfish` Macro CMD key to `fish` (this is independent of the removed Fishing (FB) Switches module).

## 2026.04.13.16
- Files: `fUI_GOSwitchesUI.lua`, `fr0z3nUI_GameOptions.lua`, `README Changelog.md`, `fr0z3nUI_GameOptions.toc`
- Switches: Remove the Fishing (FB) module completely (no Switches row/buttons, no config popout, no TOC load).

## 2026.04.13.15
- Files: `fUI_GOTalk.lua`, `fUI_GOTalk07.lua`, `fUI_GOTalk01EK.lua`, `fUI_GOTalk01KD.lua`, `fUI_GOTalk02.lua`, `fUI_GOTalk03.lua`, `fUI_GOTalk04.lua`, `fUI_GOTalk05.lua`, `fUI_GOTalk06.lua`, `fUI_GOTalk08KT.lua`, `fUI_GOTalk08ZL.lua`, `fUI_GOTalk09.lua`, `fUI_GOTalk10.lua`, `fUI_GOTalk11.lua`, `fUI_GOTalk12.lua`, `fUI_GOTalkEV.lua`, `README Changelog.md`, `fr0z3nUI_GameOptions.toc`
- GOTalk: Add rule shorthand `pcn = "Name-Realm"` / `pcn = {"Name-Realm", ...}` (character gating) and document it across DB pack headers; convert the remaining `PlayerIsCharacter(...)` when-closure to `pcn = ...`.

## 2026.04.13.05
- Files: `fUI_GOTax.lua`, `README Changelog.md`, `fr0z3nUI_GameOptions.toc`
- Tax: Detail XS line now prints as `Deposit <available> (XS <paid>)` instead of `<available> - <paid> XS` (avoids reading like a subtraction when both numbers are equal).

## 2026.04.13.06
- Files: `fUI_GOTax.lua`, `README Changelog.md`, `fr0z3nUI_GameOptions.toc`
- Tax: Detail XS line now shows `Min <minGold> (XS <paid>)` (more useful than repeating the same number when all available gold is paid to XS).

## 2026.04.13.07
- Files: `fUI_GOTax.lua`, `README Changelog.md`, `fr0z3nUI_GameOptions.toc`
- Tax: Detail XS line now prints `Deposit <totalMoney> - <paidToXS>` where `totalMoney` includes Min Gold (matches expected `Min+excess` snapshot like `10996 - 996`).

## 2026.04.13.08
- Files: `fUI_GOTax.lua`, `README Changelog.md`, `fr0z3nUI_GameOptions.toc`
- Tax: Detail XS line now prints `Deposit <totalMinusOwed> - <paidToXS> XS` (subtracts the owed portion first so the left number represents the Min+XS pool, e.g. `10996 - 996 XS` when 1g was owed).

## 2026.04.13.09
- Files: `fUI_GOTax.lua`, `README Changelog.md`, `fr0z3nUI_GameOptions.toc`
- Tax: Detail XS line now prints `Deposit <minPlusXS> - <paidToXS> XS` where `<minPlusXS>` is computed from the same snapshot (`GetMoney`, `Min Gold`, `available`) and reflects other-bank owed reduction + XS split (avoids misleading totals).

## 2026.04.13.10
- Files: `fUI_GOTax.lua`, `README Changelog.md`, `fr0z3nUI_GameOptions.toc`
- Tax: Detail XS line left number is now the raw pre-deposit money snapshot (`GetMoney()`), printing `Deposit <totalMoney> - <paidToXS> XS` (does not subtract owed/XS splits from the left-hand value).

## 2026.04.13.11
- Files: `fUI_GOTax.lua`, `README Changelog.md`, `fr0z3nUI_GameOptions.toc`
- Tax: Detail XS line now subtracts the owed slice first, printing `Deposit <totalMoney - paidToOwed> - <paidToXS> XS` (matches cases like 1g owed + 996 XS => `10996 - 996 XS` when total was 10997).

## 2026.04.13.12
- Files: `fUI_GOTalk.lua`, `README Changelog.md`, `fr0z3nUI_GameOptions.toc`
- GOTalk: Guard PlayerChoiceFrame hide/close fallback when `choiceInfo` is nil (prevents Blizzard_PlayerChoice.lua nil-index error while closing interactions).

## 2026.04.13.13
- Files: `fUI_GOTalk.lua`, `fUI_GOTalkEV.lua`, `README Changelog.md`, `fr0z3nUI_GameOptions.toc`
- GOTalk: Add rule shorthand `qil = 123` / `qil = {123,456}` (quest-in-log condition) so DB packs don’t need inline `when = function() ... end` closures.

## 2026.04.13.14
- Files: `fUI_GOTalk07.lua`, `fUI_GOTalk01EK.lua`, `fUI_GOTalk01KD.lua`, `fUI_GOTalk02.lua`, `fUI_GOTalk03.lua`, `fUI_GOTalk04.lua`, `fUI_GOTalk05.lua`, `fUI_GOTalk06.lua`, `fUI_GOTalk08KT.lua`, `fUI_GOTalk08ZL.lua`, `fUI_GOTalk09.lua`, `fUI_GOTalk10.lua`, `fUI_GOTalk11.lua`, `fUI_GOTalk12.lua`, `fUI_GOTalkEV.lua`, `README Changelog.md`, `fr0z3nUI_GameOptions.toc`
- GOTalk: Document `qil` shorthand in all DB pack headers; convert remaining `PlayerHasQuestInLog(...)` when-closure to `qil = ...`.

## 2026.04.13.02
- Files: `fUI_GOTax.lua`, `fUI_GOTaxUI.lua`, `README Changelog.md`, `fr0z3nUI_GameOptions.toc`
- Tax: Print button now cycles deposit prints Off → Basic → Detail → Full (single button).
- Tax: Detail is now compact (shows deposit and owed/XS attribution); Full shows the prior multi-line breakdown.

## 2026.04.13.03
- Files: `fUI_GOTax.lua`, `README Changelog.md`, `fr0z3nUI_GameOptions.toc`
- Tax: Shorten Detail deposit lines to `Deposited (...)` and use `GB`/`WB` labels (keeps gold icon formatting).

## 2026.04.13.04
- Files: `fUI_GOTax.lua`, `README Changelog.md`, `fr0z3nUI_GameOptions.toc`
- Tax: Adjust Detail deposit format to `GB/WB Deposit ...` lines; XS line now shows `available - XS` (keeps gold icon formatting).

## 2026.04.11.11
- Files: `fUI_GOSwitchesFB.lua`, `fUI_GOSwitchesUI.lua`, `fr0z3nUI_GameOptions.toc`
- Switches: Added Fishing (FB) 3-segment row (Fish / Enable / Config) placed between Mail and Safari.
- Switches: Fishing Config opens a minimal right-side popout (placeholder for future settings).

## 2026.04.11.12
- Files: `fUI_GOSwitchesFB.lua`, `fr0z3nUI_GameOptions.toc`
- Fishing (FB): Replaced placeholder popout with functional controls: Apply/Restore fishing audio+loot CVars (via seeded Macro CMD entries) and configure/use a preferred bobber ToyID and lure ItemID using secure-action buttons.

## 2026.04.11.13
- Files: `fUI_GOSwitchesFB.lua`, `fr0z3nUI_GameOptions.toc`
- Fishing (FB): Reworked the popout layout (intermediate iteration).

## 2026.04.11.14
- Files: `fUI_GOSwitchesFB.lua`, `fr0z3nUI_GameOptions.toc`
- Fishing (FB): Removed embedded Macro-style “Fish” button; popout now focuses on configuring and directly using bobber ToyID + lure ItemID via secure toy/item buttons.

## 2026.04.11.15
- Files: `fUI_GOSwitchesFB.lua`, `fUI_GOSwitchesUI.lua`, `fr0z3nUI_GameOptions.toc`
- Fishing (FB): Auto-applies the fishing prep CVars while the player is actively channeling Fishing, and restores prior CVar values when fishing ends (no UI interaction required).

## 2026.04.11.16
- Files: `fUI_GOSwitchesFB.lua`, `fr0z3nUI_GameOptions.toc`
- Fishing (FB): Removed the automatic CVar watcher; added a popout button to create/update a real fishing macro (`FGO_Fish`) from your configured lure/bobber IDs, plus a small on-screen reminder while channeling Fishing.

## 2026.04.11.17
- Files: `fUI_GOSwitchesFB.lua`, `fUI_GOSwitchesUI.lua`, `fr0z3nUI_GameOptions.toc`
- Fishing (FB): Display the configured bobber/lure in the Fishing popout and in the Fish button tooltip (shows item links when available).

## 2026.04.11.18
- Files: `fUI_GOSwitchesFB.lua`, `fr0z3nUI_GameOptions.toc`
- Fishing (FB): Fix blocked action error when opening the Fishing config in combat by preventing popout creation during combat lockdown.

## 2026.04.11.19
- Files: `fUI_GOSwitchesFB.lua`, `fr0z3nUI_GameOptions.toc`
- Fishing (FB): Remove the protected "Use" buttons (they caused blocked `SetPoint` errors). Keep the macro workflow + bobber/lure display.

## 2026.04.11.20
- Files: `fUI_GOSwitchesFB.lua`, `fr0z3nUI_GameOptions.toc`
- Fishing (FB): Rebuild Fishing Config as a standard FGO popout window (same structure/anchoring/padding style as Mail Config).

## 2026.04.12.02
- Files: `fUI_GOTax.lua`, `README Changelog.md`, `fr0z3nUI_GameOptions.toc`
- Tax: Revert the XS “other bank owed” gating; excess is again computed above `Min Gold + (Guild Owed + WarBank Owed)` so one bank’s XS can’t consume gold needed to pay the other bank’s owed.

## 2026.04.11.04
- Files: `fUI_GOTrade.lua`, `fr0z3nUI_GameOptions.toc`
- Trade (Merchant): Allow the sell pass (including Low Food selling) to run even at merchants with 0 items for sale ("no stock" vendors can still buy from you). Buy/restock rules are skipped when the merchant list is empty, but Low Food + sell rules are no longer blocked.
- Trade (Merchant): tradeDebug summary now includes `foodEnabled` + `foodDiff`.

## 2026.04.11.07
- Files: `fUI_GOTalk01EK.lua`, `fr0z3nUI_GameOptions.toc`
- GOTalk: Fix `fUI_GOTalk01EK.lua` failing to load due to Lua's 200-active-locals limit (caused by many repeated `local t = NPC(...)` declarations) by scoping large sections into blocks.

## 2026.04.11.08
- Files: `fUI_GOTalk01EK.lua`, `fr0z3nUI_GameOptions.toc`
- GOTalk: Refactor `fUI_GOTalk01EK.lua` to reuse a single `t` variable (`t = NPC(...)`) instead of declaring `local t` repeatedly, preventing future growth from reintroducing the Lua local-limit load failure.

## 2026.04.11.09
- Files: `fUI_GOTalk01KD.lua`, `fUI_GOTalk02.lua`, `fUI_GOTalk03.lua`, `fUI_GOTalk04.lua`, `fUI_GOTalk05.lua`, `fUI_GOTalk06.lua`, `fUI_GOTalk07.lua`, `fUI_GOTalk08KT.lua`, `fUI_GOTalk08ZL.lua`, `fUI_GOTalk09.lua`, `fUI_GOTalk10.lua`, `fUI_GOTalk11.lua`, `fUI_GOTalk12.lua`, `fUI_GOTalkEV.lua`, `fr0z3nUI_GameOptions.toc`
- GOTalk: Refactor remaining DB packs to reuse a single `t` variable (`t = NPC(...)`) so none of them can hit Lua's 200-active-locals load failure as they grow.

## 2026.04.11.10
- Files: `fUI_GOTalk02.lua`, `fUI_GOTalk04.lua`, `fr0z3nUI_GameOptions.toc`
- GOTalk: Add the reusable `t` variable to the (currently empty) XP02/XP04 DB packs so future entries don’t accidentally reintroduce the repeated-`local t` pattern.

## 2026.04.11.06
- Files: `fUI_GOTax.lua`, `fr0z3nUI_GameOptions.toc`
- FGO Tax (Warbank): Prevent duplicate auto-pay executions from overlapping warbank-open signals (InteractionManager + bank ticker + money events), which could schedule two deposits from the same money snapshot and then trigger a compensating withdraw back to Min Gold.

## 2026.04.11.05
- Files: `fUI_GOTalk.lua`, `fr0z3nUI_GameOptions.toc`
- GOTalk: Fix `close = true` not closing some non-gossip interaction UIs by also closing PlayerChoice/QuestChoice-style frames (in addition to Gossip/Quest + InteractionManager).

# 2026.04.10.41
- Files: `fUI_GOTalk05.lua`, `fr0z3nUI_GameOptions.toc`
- GOTalk: Marked Master Lao option `40512` ("Please, sit and make yourself comfortable.") as manual-only so it won't be auto-selected.

## 2026.04.11.01
- Files: `fUI_GOTax.lua`, `fr0z3nUI_GameOptions.toc`
- FGO Tax: When BOTH EB/XS toggles are enabled (Guild Bank + Warbank), the **excess** (above MinGold + total owed) is split between banks to keep cached balances even. If one bank is lower by at least the excess amount, all excess goes to the lower bank; otherwise it splits to equalize then 50/50.
- FGO Tax: Added best-effort cached balance tracking for Guild Bank / Warbank and updates it on bank open and detected deposits/withdraws while a bank is open.

## 2026.04.11.02
- Files: `fUI_GOTax.lua`, `fr0z3nUI_GameOptions.toc`
- FGO Tax: Added Tax-debug-only logging for XS excess split decisions (shows cached balances and the computed split).

## 2026.04.11.03
- Files: `fUI_GOTax.lua`, `fUI_GOTaxUI.lua`, `fr0z3nUI_GameOptions.toc`
- FGO Tax: Renamed internal config fields from `*EB` to `*XS` (with automatic migration/cleanup) to match the UI label.

# 2026.04.10.40
- Files: `fUI_GOTrade.lua`, `fr0z3nUI_GameOptions.toc`
- Trade (Merchant): Fix ticker crash in tradeDebug tick-summary (`GetPendingBought` nil) by making pending-bought helpers shared scope.

# 2026.04.10.39
- Files: `fUI_GOTrade.lua`, `fr0z3nUI_GameOptions.toc`
- Trade (Merchant): Fix Lua scoping bug where merchant ticker/session state was accidentally split between globals and locals (due to locals being declared after `RunMerchantTradeOnce`). This could cause “reopen does nothing” (food sell pass skipped) and mismatched close tick summaries.

# 2026.04.10.38
- Files: `fUI_GOTrade.lua`, `fr0z3nUI_GameOptions.toc`
- Trade (Merchant): Removed `BAG_UPDATE_DELAYED` auto-restart of the merchant ticker while a vendor is open (prevents buyback from triggering an immediate auto-resell).
- Trade (Merchant): Low Food selling now counts as ticker ops (prevents false “idle” classification while actively selling).
- Trade (Merchant): Added deterministic tradeDebug output for “no actions” cases and an explicit idle-stop line with a reason; tick summary generation now follows `tradeDebug` (matches close logging).

# 2026.04.10.34
- Files: `fUI_GOTrade.lua`, `fr0z3nUI_GameOptions.toc`
- Trade (Merchant): Ticker start line now prints the same version as `/fgo status` and keeps it on one line: `Merchant ticker: start (<version>)`.
- Trade (Merchant): Low Food keep logic now treats protected non-low food as still “usable non-low”, so low food (e.g. Lava Cake) won’t be kept just because the better food is protected by restock rules.

# 2026.04.10.35
- Files: `fUI_GOCore.lua`, `fr0z3nUI_GameOptions.toc`
- Trade (Merchant): Added tradeDebug diagnostics showing why the merchant ticker stops (`MERCHANT_CLOSED` vs verified `PIM_HIDE`) to help chase “reopen stops immediately” cases.

# 2026.04.10.36
- Files: `fUI_GOTrade.lua`, `fUI_GOCore.lua`, `fr0z3nUI_GameOptions.toc`
- Trade (Merchant): Added tradeDebug diagnostics around post-buy gating (`BAG_UPDATE_DELAYED` seen) and prints a one-line last-tick summary on merchant close to explain what happened between buy and sell.

# 2026.04.10.33
- Files: `fUI_GOTrade.lua`, `fr0z3nUI_GameOptions.toc`
- Trade (Merchant): Low Food debug slot lines now include an explicit reason tag (e.g. `eligible`, `protected`, `bestLowFallback`, `notLow`, `noReq`, `noPrice`, `locked`) so “SELL”/“KEEP” is self-explanatory.

# 2026.04.10.32
- Files: `fUI_GOTrade.lua`, `fr0z3nUI_GameOptions.toc`
- Trade (Merchant): Fix sanity line on ticker start (prints via core `Print`, no longer depends on missing `LI.PrintSanity`).
- Trade (Merchant): Low Food selling now sells “low” food if you have any usable non-low food (prevents keeping Lava Cake when Sunsalad exists).
- Trade (Merchant): If ticker start is called while already running, re-arm the sell pass so quick reopen/duplicate-show paths still sell.

# 2026.04.10.31
- Files: `fUI_GOCore.lua`, `fr0z3nUI_GameOptions.toc`
- Trade (Merchant): Don’t stop the merchant ticker on transient `PLAYER_INTERACTION_MANAGER_FRAME_HIDE` events; delay/verify close so the sell pass can run reliably.

# 2026.04.10.30
- Files: `fUI_GOTrade.lua`, `fr0z3nUI_GameOptions.toc`
- Trade (Merchant): Low Food debug now respects protected/restock item IDs, so “SELL” output matches what will actually be sold.

# 2026.04.10.29
- Files: `fUI_GOTrade.lua`, `fr0z3nUI_GameOptions.lua`, `fr0z3nUI_GameOptions.toc`
- Trade (Merchant): Merchant ticker start now runs the actual sanity probe (prints `Sanity: <version>`), replacing the placeholder `(<sanitycheck>)` label.

# 2026.04.10.28
- Files: `fUI_GOTrade.lua`, `fr0z3nUI_GameOptions.toc`
- Trade (Merchant): Post-buy sell gating is now stricter: waits for purchased item counts to actually appear in bag scans (prevents Low Food selling from running “too soon”).

# 2026.04.10.27
- Files: `fUI_GOTrade.lua`, `fr0z3nUI_GameOptions.toc`
- Trade (Merchant): Low Food debug no longer prints on merchant open; it prints when the sell pass actually runs (post-buy + post-`BAG_UPDATE_DELAYED`).
- Trade (Merchant): Low Food selling now runs even when `sellRules=0` (still respects the post-buy `BAG_UPDATE_DELAYED` gate).
- Trade (Merchant): Restock compare debug is de-duped per merchant session; ticker start line includes `(<sanitycheck>)`.

# 2026.04.10.26
- Files: `fUI_GOTrade.lua`, `fr0z3nUI_GameOptions.toc`
- Trade (Merchant): Low Food selling now runs after buy/restock and respects the post-buy `BAG_UPDATE_DELAYED` gate (so “SELL” corresponds to actual selling).

# 2026.04.10.25
- Files: `fUI_GOTrade.lua`, `fUI_GOCore.lua`, `fr0z3nUI_GameOptions.toc`
- Trade (Merchant): Buy/restock runs first; if a buy happens, selling is delayed until `BAG_UPDATE_DELAYED` so bag counts are up-to-date.

# 2026.04.10.24
- Files: `fUI_GOTrade.lua`, `fr0z3nUI_GameOptions.toc`
- Trade (Merchant): Fixed merchant ticker crash after decoupling vendor automation from UI mode.

# 2026.04.10.23
- Files: `fUI_GOTrade.lua`, `fr0z3nUI_GameOptions.toc`
- Trade (Merchant): Vendor automation no longer depends on the Trade UI mode; at a merchant it runs buy/restock rules and sell rules independently (if present).

# 2026.04.10.22
- Files: `fUI_GOTrade.lua`, `fr0z3nUI_GameOptions.toc`
- Trade (Merchant): Merchant buy/restock no longer gets blocked by `tradeMode=sell` when there are no sell rules (auto-picks the mode that has rules).

# 2026.04.10.21
- Files: `fUI_GOTrade.lua`, `fr0z3nUI_GameOptions.toc`
- Trade (Merchant): Fixed Restock compare debug crash and added hp/s-based bag fallback when score classification isn\'t cached yet.

# 2026.04.10.20
- Files: `fUI_GOTrade.lua`, `fr0z3nUI_GameOptions.toc`
- Trade (Merchant): Debug now explicitly warns when `mode=sell` prevents buy/restock (so Restock compare won’t print).

# 2026.04.10.19
- Files: `fUI_GOTrade.lua`, `fr0z3nUI_GameOptions.toc`
- Trade (Merchant): Restock debug now prints vendor-best vs bag-best food comparisons (req + score) and the `desiredScore` threshold used.

# 2026.04.10.18
- Files: `fUI_GOTrade.lua`, `fr0z3nUI_GameOptions.toc`
- Trade (Merchant): Low Food threshold math fixed so diff=N keeps the last N levels (e.g. lvl 80 diff 5 => 76–80 not low).

# 2026.04.10.17
- Files: `fUI_GOTrade.lua`, `fr0z3nUI_GameOptions.toc`
- Trade (Merchant): Low Food threshold is now strict (`req < threshold`), so req==threshold (e.g. 75 at lvl 80 with diff=5) is not treated as low.

# 2026.04.10.16
- Files: `fUI_GOTrade.lua`, `fr0z3nUI_GameOptions.toc`
- Trade (Merchant): when Trade Debug is enabled, Low Food debug auto-prints on merchant open (hp/s + KEEP/SELL/SKIP).

# 2026.04.10.15
- Files: `fUI_GOTrade.lua`, `fr0z3nUI_GameOptions.toc`
- Trade (Merchant): Low Food debug now prints hp/s + KEEP/SELL/SKIP decision visuals.

# 2026.04.10.14
- Files: `fUI_GOTrade.lua`, `fr0z3nUI_GameOptions.toc`
- Trade (Merchant): Low Food keep-best logic now compares actual food health regen (tooltip) instead of required level.

# 2026.04.10.13
- Files: `fUI_GOTrade.lua`, `fr0z3nUI_GameOptions.toc`
- Trade (Merchant): Low Food selling now keeps ALL of your single best low-food item when you have no better usable food.

# 2026.04.10.12
- Files: `fUI_GOTrade.lua`, `fr0z3nUI_GameOptions.toc`
- Trade (Merchant): Low Food selling now keeps one best low-food stack if you have no better usable food (prevents selling your last food).

# 2026.04.10.11
- Files: `fUI_GOTrade.lua`, `fr0z3nUI_GameOptions.toc`
- Trade (Merchant): Low Food sell output now strips hyperlink brackets again (keeps item clickable without showing `[Name]`).

# 2026.04.10.10
- Files: `fUI_GOTrade.lua`, `fr0z3nUI_GameOptions.toc`
- Trade (Merchant): change Low Food selling output to "<Name:> <Gold>  <Amount> <ItemLink>  (Low Food <Level>)".

# 2026.04.10.09
- Files: `fUI_GOTalk.lua`, `fr0z3nUI_GameOptions.toc`
- GOTalk: improve `close = true` reliability by also closing InteractionManager-owned windows and using a multi-step delayed close ladder (handles frame transitions).

# 2026.04.10.08
 LootIt: Suppress popout now appends seeds at the bottom of the main Rules list (no separate list).

# 2026.04.10.06
 LootIt: rename Loot DB file to `fUI_GOLootDB.lua` and add Suppress seeds section (DB-toggled, not SV rules).

# 2026.04.10.05
 LootIt: enable Professions + "Learned" output by default.

# 2026.04.10.04
 LootIt: add Professions "Learned" toggle button; reprint recipe-learned messages as "<Name:> Learned <Item>".

- Files: `fUI_GOTalk.lua`, `fUI_GOTalk01EK.lua`, `fr0z3nUI_GameOptions.toc`
- Burning Steppes (Alonsus Faol 246863): first character runs the full intro option (`138706`), all later characters auto-pick the skip option (`138705`).

# 2026.04.10.02
- Files: `fUI_GOTalk.lua`, `fr0z3nUI_GameOptions.toc`
- GOTalk: fix `close = true` rules by adding reliable close fallbacks (GossipFrame/QuestFrame close buttons + hide panel) and a one-time delayed re-close.

# 2026.04.09.06
- Files: `fUI_GOTalk01EK.lua`, `fUI_GOTalk01KD.lua`, `fUI_GOTalk02.lua`, `fUI_GOTalk03.lua`, `fUI_GOTalk04.lua`, `fUI_GOTalk05.lua`, `fUI_GOTalk06.lua`, `fUI_GOTalk07.lua`, `fUI_GOTalk08KT.lua`, `fUI_GOTalk08ZL.lua`, `fUI_GOTalk09.lua`, `fUI_GOTalk10.lua`, `fUI_GOTalk11.lua`, `fUI_GOTalk12.lua`, `fUI_GOTalkEV.lua`, `fr0z3nUI_GameOptions.toc`
- GOTalk (Manapoof): when quest `86839` is in your log, prefer gossip option `47010` (Stratholme).
- GOTalk (Manapoof): on a specific character (`Name-Realm` placeholder), prefer option `47009` (Gnomeregan), but still below the Stratholme quest rule.
- Refactor: moved the Talk rule helper predicates back into each Talk DB pack (keeps rule entries short).

# 2026.04.09.05
- Files: `fUI_GOTalk07.lua`, `fr0z3nUI_GameOptions.toc`
- GOTalk (Manapoof): when quest `86839` is in your log, prefer gossip option `47010` (Stratholme).
- GOTalk (Manapoof): on a specific character (`Name-Realm` placeholder), prefer option `47009` (Gnomeregan), but still below the Stratholme quest rule.
- Refactor: moved Talk rule helper predicates into `fUI_GOTalk.lua` so DB packs don't need to define functions.

# 2026.04.09.01
- Files: `fUI_GOTax.lua`, `fr0z3nUI_GameOptions.toc`
- Tax/Warbank: when in Guild scope but not currently in a guild, fall back to character config so Warbank deposit/withdraw/manual tracking doesn’t silently no-op.

# 2026.04.09.02
- Files: `fUI_GOCore.lua`, `fUI_GOTradeBank.lua`, `fUI_GOTax.lua`, `fr0z3nUI_GameOptions.toc`
- Tax/Warbank: fix BANKFRAME_CLOSED reset wiring so warbank open-state is properly cleared between sessions (prevents “open once after reload, then never re-triggers after close/reopen”).
- Debug (Tax debug only): print core banking interaction + bankframe open/close events to diagnose missing close signals.

# 2026.04.08.03
- Files: `fUI_GOTrade.lua`, `fr0z3nUI_GameOptions.toc`
- Trade (Merchant): when Trade mode is `deposit`, infer merchant buy/sell mode from configured rules so buy/restock can start on `MERCHANT_SHOW` without opening the Trade UI.

# 2026.04.08.02
- Files: `fr0z3nUI_GameOptions.lua`, `fr0z3nUI_GameOptions.toc`
- Slash: add `/fgo yumd` (yum + dump) to force-update `FGO Food` / `FGO Drink` and print the selected items + computed stats.

# 2026.04.08.01
- Files: `fUI_GOMacros.lua`, `fr0z3nUI_GameOptions.toc`
- Food/Drink (Yum): if tooltip parsing yields 0 hp/s or mp/s (new/odd tooltip formats), fall back to picking the highest required-level usable food/drink so `/fgo yum` doesn't report "no valid food/drink" when you have consumables.

# 2026.04.07.04
- Files: `fUI_GOTrade.lua`, `fr0z3nUI_GameOptions.toc`
- Trade (Merchant): prewarm the merchant item list incrementally on the ticker so buy/restock has item+tooltip cache sooner (helps cases where purchases only start after opening the Trade UI).

# 2026.04.07.03
- Files: `fUI_GOLootChat.lua`, `fr0z3nUI_GameOptions.toc`
- LootIt: dedupe achievement reprints so the same achievement can’t print twice in quick succession (common when both `CHAT_MSG_ACHIEVEMENT` and `CHAT_MSG_GUILD_ACHIEVEMENT` fire).

# 2026.04.07.02
- Files: `fr0z3nUI_GameOptions.toc`
- Bumped TOC `## Version` to `2026.04.07.02`.

# 2026.04.07.01
- Files: `fUI_GOTalk.lua`, `fr0z3nUI_GameOptions.toc`
- GOTalk: `stopIfQuestAvailable` now gates purely on what the gossip frame reports as an available quest, avoiding false negatives from `IsQuestFlaggedCompleted` on repeatable quests (fixes cases like Darkmoon travel NPC still auto-selecting while the quest is offered).

# 2026.04.06.17
- Files: `fUI_GOLootAlias.lua`, `fr0z3nUI_GameOptions.toc`
- LootIt Alias: fix alias “shadow placeholder” not hiding when the UI auto-fills the alias text for an existing ID; placeholder now refreshes immediately on programmatic `SetText`.

# 2026.04.06.16
- Files: `fUI_GOLootAlias.lua`, `fr0z3nUI_GameOptions.toc`
- LootIt Alias: fix Account button getting stuck in repeated “Alias removed” when the only alias is the built-in addon alias (e.g. currency 1166); Account now toggles the addon alias enable/disable in that state.

# 2026.04.06.15
- Files: `fr0z3nUI_GameOptions.lua`, `fUI_GOLootAlias.lua`, `fr0z3nUI_GameOptions.toc`
- LootIt Alias: make the Alias UI a true popout (fixed size, anchored outside the LootIt tab, dialog-style backdrop) instead of an oversized in-panel overlay.
- LootIt Alias: update Account/Character button coloring to match the Trade tab scheme (green/orange/yellow) and remove the red styling.

# 2026.04.06.14
- Files: `fUI_GOLootChat.lua`, `fr0z3nUI_GameOptions.toc`
- LootIt: dedupe currency outputs across `CHAT_MSG_CURRENCY` and currency-in-`CHAT_MSG_LOOT` so a single currency gain can’t produce both `TW Token x540` and `TW Token`.

# 2026.04.06.13
- Files: `fUI_GOLootChat.lua`, `fr0z3nUI_GameOptions.toc`
- LootIt: make transfer-line detection resilient to color codes/textures/NBSP so “transferred … to …” messages reliably bypass the generic item rewrite (prevents stray `TW Token` echoes).

# 2026.04.06.12
- Files: `fUI_GOLootChat.lua`, `fr0z3nUI_GameOptions.toc`
- LootIt: broaden transfer-line suppression to also catch bracket-only messages like “X transferred [Timewarped Badge]x540 to Y” (some clients omit hyperlinks), preventing a second aliased `TW Token` output.

# 2026.04.06.11
- Files: `fUI_GOLootChat.lua`, `fr0z3nUI_GameOptions.toc`
- LootIt: dedupe direct `ChatFrame:AddMessage` currency prints against recent `CHAT_MSG_CURRENCY`/loot-currency rewrites to prevent double outputs (fixes `TW Token x550` + `TW Token` duplicates).

# 2026.04.06.10
- Files: `fUI_GOLootChat.lua`, `fr0z3nUI_GameOptions.toc`
- LootIt: stop rewriting `CHAT_MSG_SYSTEM` transfer lines (e.g. “transferred … to …”) that include item/currency links; these are not loot and were causing duplicate alias outputs like `TW Token`.

# 2026.04.06.09
- Files: `fUI_GOLootChat.lua`, `fr0z3nUI_GameOptions.toc`
- LootIt: fix a boss-fight secret-string crash in the `ChatFrame:AddMessage` hook (avoid calling `:match()` on secret values by checking `issecretvalue` first).

# 2026.04.06.08
- Files: `fUI_GOLootChat.lua`, `fr0z3nUI_GameOptions.toc`
- LootIt: fix `chatdebug dump/filters/events` output being incorrectly suppressed by the direct `ChatFrame:AddMessage` loot/money suppressor (debug lines were being misdetected as money and causing spam).

# 2026.04.06.07
- Files: `fUI_GOLootChat.lua`, `fr0z3nUI_GameOptions.toc`
- LootIt: add secret-string diagnostics so `/fgo li chatdebug events` reports when chat payloads are unreadable (`issecretvalue`), including per-event counts + last-seen times (helps confirm boss-fight restrictions vs. filter removal).

# 2026.04.06.06
- Files: `fUI_GOLootChat.lua`, `fr0z3nUI_GameOptions.toc`
- LootIt: add `/fgo li chatdebug events` to show last-seen timestamps + counts for loot/xp/system/profession handlers and direct `ChatFrame:AddMessage` prints (diagnose boss-fight “stops working” without changing loot parsing).

# 2026.04.06.05
- Files: `fUI_GOLootChat.lua`, `fr0z3nUI_GameOptions.toc`
- LootIt: fix `chatdebug filters` audit hook crash by using the string form of `hooksecurefunc` (some clients don’t accept passing the function reference).

# 2026.04.06.04
- Files: `fUI_GOLootChat.lua`, `fr0z3nUI_GameOptions.toc`
- LootIt: make `chatdebug filters` robust on clients where `ChatFrame_GetMessageEventFilters` is unavailable by tracking `ChatFrame_AddMessageEventFilter`/`ChatFrame_RemoveMessageEventFilter` via `hooksecurefunc`, including recent add/remove ops + stack traces.

# 2026.04.06.03
- Files: `fUI_GOCore.lua`, `fUI_GOLootChat.lua`, `fr0z3nUI_GameOptions.toc`
- LootIt: revert encounter/combat filter-watch behavior (stop auto re-applying filters during bosses) and instead improve `chatdebug dump` to audit which chat filters are currently installed, plus add `/fgo li chatdebug filters`.

# 2026.04.06.02
- Files: `fUI_GOCore.lua`, `fUI_GOLootChat.lua`, `fr0z3nUI_GameOptions.toc`
- LootIt: add a lightweight in-combat / in-encounter “filter watch” that re-applies chat filters if they get stripped mid-fight (prevents capture/reprint from dropping during long boss combats).

# 2026.04.06.01
- Files: `fUI_GOCore.lua`, `fr0z3nUI_GameOptions.toc`
- LootIt: re-apply chat filters on combat + encounter start/end so loot/profession/xp capture+reprint doesn’t silently drop during boss fights (some boss mods reset chat filters mid-fight).

# 2026.04.05.09
- Files: `fr0z3nUI_GameOptions.lua`, `fUI_GOMacros.lua`, `fr0z3nUI_GameOptions.toc`
- Slash: add `/fgo yumtest` to print the current best Food/Drink candidates + computed rates (debug helper).

# 2026.04.05.08
- Files: `fUI_GOMacros.lua`, `fr0z3nUI_GameOptions.toc`
- Food/Drink macros: fix parsing for "X% of your maximum health/mana every second over Y sec" tooltips so percent-based foods/drinks rank correctly against flat restore items.

# 2026.04.05.07
- Files: `fUI_GOMacros.lua`, `fr0z3nUI_GameOptions.toc`
- Food/Drink macros: add one-shot follow-up rescan a few seconds after `PLAYER_ENTERING_WORLD`, and refresh on `MERCHANT_CLOSED`.
- Food/Drink macros: throttle `RequestLoadItemDataByID` calls and force refresh when pending item info arrives.

# 2026.04.05.06
- Files: `fUI_GOMacros.lua`, `fr0z3nUI_GameOptions.toc`
- Food/Drink macros: refresh is now also triggered by `BAG_UPDATE` / `ITEM_PUSH` (still throttled) for better reliability right after looting/buying items.

# 2026.04.05.05
- Files: `fUI_GOMacros.lua`, `fr0z3nUI_GameOptions.toc`
- Food/Drink macros: improve tooltip parsing for modern "(Eat/Drink) to restore ..." wording, including the common "health and mana" single-value format.
- Fixes cases where buying a higher-tier food/drink doesn't update `FGO Food` / `FGO Drink` until a manual `/fgo yum`.

# 2026.04.05.04
- Files: `fUI_GOSwitchesQA.lua`, `fr0z3nUI_GameOptions.toc`
- Queue Accept: overlay visibility no longer depends on the Repeat Sound toggle.
- Queue Accept: repeat sound now runs from the overlay update loop (keeps it tied to the visible overlay).
- Queue Accept: fixed PlaySound success detection (was treating `pcall` success as “sound played”).

# 2026.04.05.03
- Files: `fr0z3nUI_GameOptions.lua`, `fUI_GOSwitchesQA.lua`, `fr0z3nUI_GameOptions.toc`
- Slash: add `/fgo arms` as a silent alias for `/fgo arm` (no chat prints).
- Queue Accept: if proposal events are missed (e.g. /reload mid-proposal), repeat-sound loop can still start when the overlay logic detects an active proposal.

# 2026.04.05.02
- Files: `fUI_GOSwitchesQA.lua`, `fr0z3nUI_GameOptions.toc`
- Queue Accept: fix repeat-sound loop start timing so it still repeats when `LFG_PROPOSAL_SHOW` fires before `GetLFGProposal()`/dialog state is fully ready (short retry window).

# 2026.04.05.01
- Files: `fUI_GOSwitchesQA.lua`, `fUI_GOSwitchesUI.lua`, `fr0z3nUI_GameOptions.toc`
- Queue Accept: fix repeat-sound loop so it continues while a proposal is active even if the overlay hides (repeat logic is now timer-driven instead of `OnUpdate`).
- Queue Accept config: toggling `Repeat Sound` / changing the interval now takes effect immediately for an active proposal.

# 2026.04.04.03
- Files: `fr0z3nUI_GameOptions.lua`, `fUI_GOSwitchesQA.lua`, `fUI_GOSwitchesUI.lua`, `fr0z3nUI_GameOptions.toc`
- Queue Accept: Switches UI now uses a 3-button row: `Queue` (account default) / `Enable` (per-character override) / `Config`.
- Queue Accept config popout: optional master-volume boost on queue pop with restore %, and optional repeating queue sound with an interval.
- SavedVariables: migrated legacy `queueAcceptMode="on"` into a boolean per-character override; legacy 3-state API remains supported.

# 2026.04.04.02
- Files: `fUI_GOTalk01EK.lua`, `fr0z3nUI_GameOptions.toc`
- Talk quest gate: fix NPC `__meta.stopIfQuestTurnIn` being overwritten by repeated assignments; now uses a questID list so any matching turn-in can block auto-select and keep gossip open.

# 2026.04.04.01
- Files: `fUI_GOSwitches.lua`, `fUI_GOTax.lua`, `fr0z3nUI_GameOptions.toc`
- Safari floating button: avoid GUID `strsplit` crash when `UnitGUID("target")` is a Retail "secret" string value (taint-safe via `pcall`).
- Tax: harden system money message parsing against "secret" strings so chat money events can't crash the addon.

# 2026.04.01.17
- Files: `fUI_GOSwitches.lua`, `fr0z3nUI_GameOptions.toc`
- Safari floating button: convert to `SecureActionButtonTemplate` (`type="toy"`) so toy use is handled by the secure action system (more reliable across characters).

# 2026.04.01.16
- Files: `fUI_GOSwitches.lua`, `fr0z3nUI_GameOptions.toc`
- Safari floating button: click handler now registers `AnyUp` and gates on left-click to avoid edge cases.
- Safari floating button: Shift-click debug now also posts to `UIErrorsFrame` and includes pet-battle state + a brief label flash to prove the click fired.

# 2026.04.01.15
- Files: `fUI_GOSwitches.lua`, `fr0z3nUI_GameOptions.toc`
- Safari floating button: harden toy-use click so it doesn't early-return; add fallback call path for better cross-character reliability.
- Safari floating button: Shift-click prints a short debug line (combat + toy usable) to confirm the click handler is firing.

# 2026.04.01.14
- Files: `fUI_GOSwitches.lua`, `fUI_GOSwitchesUI.lua`, `fr0z3nUI_GameOptions.lua`, `fr0z3nUI_GameOptions.toc`
- SafariHat: convert to a real Click-style multi-entry rules list (seed + SavedVariables overlay) stored in `AutoGossip_Acc.safariHatRulesAcc`.
- Safari config popout: list shows effective rules; per-row `ON/OFF` toggle; delete is available for non-seed rules.
- Safari floating button: hides unless your current target matches an enabled rule.

# 2026.04.01.13
- Files: `fUI_GOSwitches.lua`, `fr0z3nUI_GameOptions.toc`
- Safari floating button: read Safari settings from `AutoGossip_UI` (matching the UI), and hide unless an NPCID is configured + currently targeted.

# 2026.04.01.12
- Files: `fUI_GOSwitchesUI.lua`, `fr0z3nUI_GameOptions.toc`
- Safari config popout: now matches the Click popout style, including a scrollable seed list sourced from `ns.SafariHat_DB`.

# 2026.04.01.11
- Files: `fUI_GOMacroXCMDB.lua`, `fr0z3nUI_GameOptions.toc`
- SafariHat DB: reorder curated entry layout to `questID, npcID, textSize, name` (quest-first).

# 2026.04.01.10
- Files: `fUI_GOMacroXCMDB.lua`, `fr0z3nUI_GameOptions.toc`
- SafariHat DB: fix `AddSafariHat(...)` argument order to match the curated entries (`npcID, questID, textSize, name`) and remove invalid trailing commas from calls.

# 2026.04.01.09
- Files: `fUI_GOMacroXCMDB.lua`, `fUI_GOSwitches.lua`, `fr0z3nUI_GameOptions.toc`
- SafariHat DB: refactor `SafariHat_DB` into a ClickAlias-style seed list (data-only entries), not a config/default struct.
- Floating Safari button now always uses toy `92738` directly.

# 2026.04.01.08
- Files: `fUI_GOSwitchesUI.lua`, `fUI_GOSwitches.lua`, `fr0z3nUI_GameOptions.lua`, `fr0z3nUI_GameOptions.toc`
- Safari config: add a `Name` input after `NPCID` (used for display in the floating button tooltip).

# 2026.04.01.07
- Files: `fUI_GOMacroXCMDB.lua`, `fUI_GOSwitches.lua`, `fr0z3nUI_GameOptions.toc`
- Add a `SafariHat_DB` section (data-only) and have the floating Safari button read the toy ID from it (fallback remains `92738`).
- Files: `fUI_GOMacroXCMDUI.lua`, `fr0z3nUI_GameOptions.toc`
- Click Debug: add index-based metadata lookup fallback (`GetAddOnMetadata(i, ...)`) for clients that return nil when queried by addon name.

# 2026.04.01.06
- Files: `fUI_GOSwitches.lua`, `fUI_GOSwitchesUI.lua`, `fr0z3nUI_GameOptions.lua`, `fr0z3nUI_GameOptions.toc`
- Switches tab: add `Safari / Enable / Config` row below Mail.
- Floating button: add a draggable `Safari` button that uses Safari Hat toy `92738` (still requires your click).
- Config: NPCID gate (only show when targeting that NPC), QuestID gate (hide if quest completed), and text Size.

# 2026.04.01.05
- Files: `fUI_GOMacroXCMDUI.lua`, `fr0z3nUI_GameOptions.toc`
- Click popout: Arm FB toggle now always reads `Arm FB`; color alone indicates Off (grey) / On (Char orange) / On (Acc green).

# 2026.04.01.04
- Files: `fUI_GOMacroXCMD.lua`, `fUI_GOMacroXCMDUI.lua`, `fr0z3nUI_GameOptions.lua`, `fr0z3nUI_GameOptions.toc`
- Click popout: add a numeric text-size box (like the Reload float) for the floating Click-Alias `Arm` button.
- Floating Arm button label now applies the saved text size.

# 2026.04.01.03
- Files: `fUI_GOMacroXCMD.lua`, `fUI_GOMacroXCMDUI.lua`, `fr0z3nUI_GameOptions.lua`, `fr0z3nUI_GameOptions.toc`
- Click popout: Arm FB toggle is now 3-state: `Off` (grey) → `On` (orange, per-character) → `On` (green, account).
- Floating Arm button visibility now respects the selected scope.

# 2026.04.01.02
- Files: `fUI_GOMacroXCMDUI.lua`, `fr0z3nUI_GameOptions.toc`
- Click popout: Float toggle button now shows `Arm FB` with green/grey state coloring and a tooltip.

# 2026.04.01.01
- Files: `fUI_GOMacroXCMD.lua`, `fUI_GOMacroXCMDUI.lua`, `fr0z3nUI_GameOptions.lua`, `fr0z3nUI_GameOptions.toc`
- Click popout: `Auto-arm` is now an On/Off button (not a checkbox).
- Click popout: add `Float` On/Off button to show a floating `Arm` button for click-alias arming without opening the popout.
- Slash: `/fgo arm` with no args now arms Click aliases (existing `/fgo arm <mode> <key>` Macro CMD behavior unchanged).

# 2026.03.28.16
- Files: `fUI_GOSwitchesMU.lua`, `fr0z3nUI_GameOptions.toc`
- Mount Up: improve eating/drinking detection so pending mounts are reliably blocked when Food & Drink starts (spellID-based cast/channel check + aura filter fallbacks).

# 2026.03.28.15
- Files: `fUI_GOMacroHearth.lua`, `fUI_GOSwitchesMN.lua`, `fr0z3nUI_GameOptions.toc`
- Macro Hearth: call `C_Item.GetItemCount` with the full argument set for better client/stub compatibility.
- Mail notifier bootstrap: suppress a LuaLS false-positive on `C_Timer.NewTicker(interval, Tick, maxTries)` (WoW API supports the 3rd arg).

# 2026.03.28.14
- Files: `fUI_GOMacroXCMD.lua`, `fr0z3nUI_GameOptions.toc`
- Click aliases: fix a load-order bug where seed/merge logic could call `TrimSafe()` before it was defined (nil crash when adding/arming after clearing aliases).

# 2026.03.28.13
- Files: `fUI_GOMacroXCMD.lua`, `fUI_GOMacroXCMDUI.lua`, `fr0z3nUI_GameOptions.toc`
- Click aliases: Click popout list now always includes the DB seed entries (even if SavedVariables is empty).
- Click aliases: seed entries can be edited but not deleted; per-row toggle is now On/Off (enabled/disabled) instead of a one-shot Arm.

# 2026.03.28.12
- Files: `fUI_GOMacroXCMD.lua`, `fr0z3nUI_GameOptions.toc`
- Click aliases: improve auto-arm for lazily-created addon buttons by retrying when common UI windows open (auction house, merchant, tradeskill, bank) and when other addons load.

# 2026.03.28.11
- Files: `fUI_GOMacroXCMDB.lua`, `fUI_GOMacroXCMD.lua`, `fr0z3nUI_GameOptions.toc`
- Click aliases: add a seed section (`ns.ClickAlias_DB`) so you can keep a curated alias list in the repo.
- Click aliases: seeds are imported only when your saved alias table is empty (won't overwrite existing aliases).

# 2026.03.28.10
- Files: `fUI_GOMacroXCMDUI.lua`, `fr0z3nUI_GameOptions.toc`
- Click popout: after a successful Add/Update, the Shorthand/Original boxes are now cleared and edit-mode is exited, preventing accidental rename/overwrite when adding the next alias.

# 2026.03.28.09
- Files: `fUI_GOMacros.lua`, `fr0z3nUI_GameOptions.lua`, `fr0z3nUI_GameOptions.toc`
- Food/Drink macros: when bag slots or item tooltip data aren't ready at login, the updater now schedules a few automatic retries instead of getting stuck until `/reload`.
- `/fgo yump`: message now distinguishes "bags not ready" / "item data pending" from a true "no food/drink found" case.

# 2026.03.28.08
- Files: `fUI_GOMacroXCMDUI.lua`, `fr0z3nUI_GameOptions.toc`
- Click Debug: stop auto-printing the full report to chat on every refresh; now it prints only on explicit `Refresh` and automatically only when an action fails.
- Click popout: simplify "Saved" hint text when Debug is OFF.

# 2026.03.28.07

# 2026.03.28.06
- Files: `fUI_GOMacroXCMDUI.lua`, `fr0z3nUI_GameOptions.toc`
- Click Debug: improve version detection so the header shows the actual TOC version (fallback to `C_AddOns.GetAddOnMetadata`).

# 2026.03.28.05
- Files: `fUI_GOMacroXCMDUI.lua`, `fr0z3nUI_GameOptions.toc`
- Click Debug: fix a Lua scoping issue where handlers called a nil global `EnsureDebugFrame` (debug window now opens reliably).

# 2026.03.28.04
- Files: `fUI_GOMacroXCMDUI.lua`, `fr0z3nUI_GameOptions.toc`
- Click Debug: change `Debug` to a persistent on/off toggle; when ON it auto-opens/refreshes the debug window and prints the report after Save/Arm actions and when opening the popout.
- Stored under `AutoGame_UI.clickAliasDebugAcc`.

# 2026.03.28.03
- Files: `fUI_GOMacroXCMD.lua`, `fUI_GOMacroXCMDUI.lua`, `fr0z3nUI_GameOptions.toc`
- Click aliases: fix a bug where `clickAliasesAcc` was being wiped if it was a normal key/value map (this caused Save then Arm to fail with "Alias missing").
- Click Debug: show the proxy `clickbutton` target name when available.

# 2026.03.28.02
- Files: `fUI_GOMacroXCMDUI.lua`, `fr0z3nUI_GameOptions.toc`
- Click popout: add a `Debug` button that opens a copy-friendly debug window and also prints the same report to chat.
- Debug report includes: version, combat state, auto-arm state, alias counts (SV + runtime list), last save/arm outcome, and per-alias global/proxy checks.

# 2026.03.28.01
- Files: `fUI_GOMacroXCMDUI.lua`, `fr0z3nUI_GameOptions.toc`
- Click popout: use `ns.ClickAlias_*` APIs for list/save/delete to avoid SavedVariables table mismatch edge cases.
- Click popout: hint line appends a compact status suffix (`vX | acc=N`) on open to verify the loaded build and detected alias count.

# 2026.03.27.06
- Files: `fUI_GOMacroXCMD.lua`, `fUI_GOMacroXCMDUI.lua`, `fr0z3nUI_GameOptions.toc`
- Click aliases: accept/migrate legacy `clickAliasesAcc` formats (string values) so the list populates and Arm finds mappings.

# 2026.03.27.05
- Files: `fUI_GOMacroXCMD.lua`, `fUI_GOMacroXCMDUI.lua`, `fr0z3nUI_GameOptions.toc`
- Click aliases: migrate storage from `AutoGame_Settings` to `AutoGame_Acc` so aliases persist reliably and the Click list reflects saved entries immediately.
- Click aliases: auto-arm toggle storage also moved to `AutoGame_Acc` for consistency.

# 2026.03.27.04
- Files: `fUI_GOMacroXCMD.lua`, `fUI_GOMacroXCMDUI.lua`, `fr0z3nUI_GameOptions.toc`
- Click aliases: fix a UI runtime error (local `Trim` used before definition) that prevented the Click popout from working.
- Click aliases: stop auto-creating `AutoGame_Settings` when missing; missing SV now prompts reload instead of saving into a throwaway table.

# 2026.03.27.03
- Files: `fUI_GOMacroXCMD.lua`, `fUI_GOMacroXCMDUI.lua`, `fr0z3nUI_GameOptions.toc`
- Click aliases: stop auto-creating `AutoGame_Settings` when missing; missing SV now shows "Settings not loaded (reload)" instead of saving into a throwaway table.

# 2026.03.27.02
- Files: `fUI_GOMacroXCMD.lua`, `fUI_GOMacroXCMDUI.lua`, `fr0z3nUI_GameOptions.toc`
- Click popout: fix alias persistence by always using/creating `AutoGame_Settings` (avoid writing into a throwaway/nil settings table).
- Click popout: show an explicit empty-state label ("No aliases") and ensure rows are explicitly shown when present.
- Click popout: hint line now reports `Saved... (N)` count after Add to help diagnose stale load situations.

# 2026.03.27.01
- Files: `fUI_GOMacroXCMD.lua`, `fUI_GOMacroXCMDUI.lua`, `fr0z3nUI_GameOptions.toc`
- Macro CMD: add a new `Click` popout to manage `/click` shorthands (`Shorthand` -> `Original`).
- Click popout: scrollable list (mousewheel; scrollbar hidden) and Enter-to-add.
- Runtime: creates secure proxy buttons out of combat so `/click <shorthand>` clicks the original button.

# 2026.03.26.11
- Files: `fUI_GOSwitchesMU.lua`, `fr0z3nUI_GameOptions.toc`
- Mount Up: fix taint from comparing aura `duration` (secret number) by removing aura-property scanning; reverted to safe `AuraUtil.FindAuraBySpellID/Name` matching.

# 2026.03.26.10
- Files: `fUI_GOMacros.lua`, `fr0z3nUI_GameOptions.toc`
- Food/Drink macros: fix percent-based “% Mana” parsing for non-mana classes/specs by using the player's active power type (and a non-zero fallback) instead of assuming mana powerType `0`.

# 2026.03.26.09
- Files: `fUI_GOMacros.lua`, `fr0z3nUI_GameOptions.toc`
- Food/Drink macros: reverted “Prefer Conjured” to absolute priority (conjured overrides non-conjured again).

# 2026.03.26.08
- Files: `fUI_GOMacros.lua`, `fr0z3nUI_GameOptions.toc`
- Food/Drink macros: changed “Prefer Conjured” to a tie-breaker so conjured items don't override clearly better regen (e.g., Chocolate Lava Cake beating mana bun when higher rate).

# 2026.03.26.07
- Files: `fr0z3nUI_GameOptions.lua`, `fr0z3nUI_GameOptions.toc`
- Slash: fix `/fgo help` and make `/fgo list` case-insensitive so they don't fall through to Macro CMD (`/fgo d ...`).

# 2026.03.26.06
- Files: `fUI_GOSwitchesMU.lua`, `fr0z3nUI_GameOptions.toc`
- Mount Up: disabled hardcoded food/drink spellID list; now blocks mounting when a player buff matches the consumption aura properties (duration `20s`, and physical school when exposed by the client).

# 2026.03.26.05
- Files: `fUI_GOSwitchesMU.lua`, `fr0z3nUI_GameOptions.toc`
- Mount Up: removed generic aura-scan fallback to avoid false positives (now spellID/name list only).

# 2026.03.26.04
- Files: `fUI_GOSwitchesMU.lua`, `fr0z3nUI_GameOptions.toc`
- Mount Up: tightened fallback scan to only consider short (≤20s) cancelable auras.

# 2026.03.26.03
- Files: `fUI_GOSwitchesMU.lua`, `fr0z3nUI_GameOptions.toc`
- Mount Up: expanded eating/drinking aura spellIDs and added a generic helpful-aura fallback scan to reduce future ID chasing.

# 2026.03.26.02
- Files: `fUI_GOSwitchesMU.lua`, `fr0z3nUI_GameOptions.toc`
- Mount Up: treat Food & Drink aura spellID `452389` as eating/drinking (blocks auto-mount).

# 2026.03.26.01
- Files: `fUI_GOLootUI.lua`, `fr0z3nUI_GameOptions.toc`
- Loot Suppress popout: rules list is now mousewheel-scrollable (scrollbar hidden).
- Loot Suppress popout: pressing Enter in the input box adds the rule.

# 2026.03.25.12
- Files: `fUI_GOSwitchesMU.lua`, `fr0z3nUI_GameOptions.toc`
- Mount Up: fix a taint error comparing aura names ("secret string" values); eating/drinking detection now only uses `AuraUtil.FindAuraBySpellID/Name` (no aura-field comparisons).

# 2026.03.25.11
- Files: `fUI_GOSwitchesMU.lua`, `fr0z3nUI_GameOptions.toc`
- Mount Up: fix a taint error comparing aura spellIDs ("secret number" values); eating/drinking detection no longer compares aura-provided `spellId` values.

# 2026.03.25.10
- Files: `fUI_GOSwitchesMU.lua`, `fr0z3nUI_GameOptions.toc`
- Mount Up: conjured food/drink "Refreshment" (spellID `167152`) now blocks mounting.

# 2026.03.25.09
- Files: `fUI_GOSwitchesMU.lua`, `fr0z3nUI_GameOptions.toc`
- Mount Up: fix eating/drinking detection so consumption reliably blocks mounting again (uses localized spell names + multiple aura detection paths).

# 2026.03.25.08
- Files: `fUI_GOSwitchesMU.lua`, `fr0z3nUI_GameOptions.lua`, `fr0z3nUI_GameOptions.toc`
- Mount Up (Config): add a bottom-right `Ground` toggle that prevents using flying mounts even in flyable zones.
- Mount Up (Slash): add `/fgo mu gon` and `/fgo mu goff`.

# 2026.03.25.07
- Files: `fUI_GOSwitchesMU.lua`, `fr0z3nUI_GameOptions.toc`
- Mount Up: add a 10s delay after casting Recuperate (spellID `1231411`) before Mount Up is allowed to fire.

# 2026.03.25.06
- Files: `fUI_GOMacroXCMDB.lua`, `fr0z3nUI_GameOptions.lua`, `fr0z3nUI_GameOptions.toc`
- Macro CMD (seeds): revert `fish`, `exit`, `logout` defaults to only the intended `/fgo <cmd>` behavior (“What it does” in README), not the full suggested multi-line macro layouts.

# 2026.03.25.05
- Files: `fr0z3nUI_GameOptions.lua`, `fUI_GOMacroXCMDB.lua`, `README Macros.md`, `fr0z3nUI_GameOptions.toc`
- Slash: back-compat restore for legacy README commands like `/fgo cloot`, `/fgo cmouse`, `/fgo ctrade`, etc. They no longer get mis-parsed as Macro CMD `c` mode.
- Macro CMD (seeds): update `fish` and `exit` defaults to match the documented macro bodies, and add a default `logout` Macro CMD seed.
- Docs: add “Alt:” lines for modern command names (`/fgo loot`, `/fgo mouse`, `/fgo script`, etc.).

# 2026.03.25.04
- Files: `fr0z3nUI_GameOptions.lua`, `fr0z3nUI_GameOptions.toc`
- Slash: fix `/fgo cscript` being mis-parsed as Macro CMD `c` mode (`/fgo c script`). It now acts as a back-compat alias of `/fgo script`.
- Slash: `/fgo script` now prefers running the editable Macro CMD `script` entry when present, but falls back to directly toggling `ScriptErrors` when the Macro CMD entry doesn’t exist.

# 2026.03.25.03
- Files: `fUI_GOLootChat.lua`, `fr0z3nUI_GameOptions.toc`
- Loot (Achievement): fix rewritten achievement output so the `Name:` colon inherits the class color (colon is now included in the colored name prefix).

# 2026.03.25.02
- Files: `fUI_GOSituatePF.lua`, `fr0z3nUI_GameOptions.toc`
- Professions: fix Midnight Cooking detection returning a stale/incorrect `known=false` after training; detection now avoids treating “0 skill” as “missing” and can identify Midnight Cooking by skill-line name when enumerating trade-skill lines.

# 2026.03.25.01
- Files: `fUI_GOTalkUP.lua`, `fr0z3nUI_GameOptions.toc`
- Talk: Midnight Cooking hint no longer trusts cached `known=false`; it re-checks `KnowsCookingMidnight()` when the cache isn’t `true`, so the “missing” warning stops immediately after training.

# 2026.03.24.08
- Files: `fUI_GOTalkUP.lua`, `fr0z3nUI_GameOptions.toc`
- Talk: Midnight Cooking trainer hint now prints in the orange warning style, with text `SKILL:  Midnight Cooking Missing`.

# 2026.03.24.07
- Files: `fUI_GOTalk.lua`, `fr0z3nUI_GameOptions.toc`
- Talk: fix a runtime error where the manual `C_GossipInfo.SelectOption` hook called nil globals (`GetCurrentNpcID` / `GetDbNpcTable`) due to Lua local scoping; helpers are now forward-declared so the closure captures the correct locals.

# 2026.03.24.06
- Files: `fUI_GOSituatePF.lua`, `fr0z3nUI_GameOptions.toc`
- Professions: Midnight Cooking detection no longer trusts a stale cached `known=true`; it will self-correct back to `false` when the authoritative skill-line enumeration proves it’s not learned.

# 2026.03.24.05
- Files: `fUI_GOSituatePF.lua`, `fUI_GOTalkUP.lua`, `fr0z3nUI_GameOptions.toc`
- Professions: fix false-positive “Midnight Cooking is known” detection (category presence is not proof of learning).
- Talk (Debug): Midnight Cooking/Fishing hints now log `Hint ...: knows=...` when `debugAcc` is enabled.

# 2026.03.24.04
- Files: `fUI_GOTalk.lua`, `fUI_GOTalkUP.lua`, `fr0z3nUI_GameOptions.toc`
- Talk: `print = ...` hints now also fire when you manually click a gossip option (hooked `C_GossipInfo.SelectOption`).
- Talk (Debug): selecting Midnight Cooking/Fishing options now dumps the live gossip OID list to chat to help fix rule ID mismatches.

# 2026.03.24.03
- Files: `fUI_GOTalk.lua`, `fUI_GOTalkUP.lua`, `fr0z3nUI_GameOptions.toc`
- Talk: `print = ...` hints on gossip rules now actually print when an option is auto-selected (e.g. trainer reminders like “Train Midnight Cooking”).
- Talk: Midnight Cooking/Fishing hints do a targeted profession-tier refresh if the cache is still unknown.

# 2026.03.24.02
- Files: `fUI_GOSwitches.lua`, `fUI_GOSwitchesUI.lua`, `fr0z3nUI_GameOptions.toc`
- Switches/UI: compacted Queue Accept area into two rows under Mail (PopUp / PopDbg / Reload, then Action / NPC Name / Tutorial).
- Switches/UI: Reload toggle now uses a real text-size input box (instead of click-right-third cycling).
- Switches: added 3-state CVars for `ActionButtonUseKeyDown` (Action) and `nameplateShowFriendlyNPCs` (NPC Name): OFF ACC / ON ACC / ON CHAR.

# 2026.03.24.01
- Files: `fUI_GOLootChat.lua`, `fr0z3nUI_GameOptions.toc`
- Loot (Achievement): fix class-colored sender name formatting when `C_ClassColor:GenerateHexColor()` returns `AARRGGBB` (prevents stray `c9` prefix and wrong orange tint; restores correct class colors).

# 2026.03.22.26
- Files: `fUI_GOSwitchesMU.lua`, `fr0z3nUI_GameOptions.toc`
- Mount Up (Config): aligned the Delay label/input to the same left/right edges as the OSD/Lock button row.

# 2026.03.22.25
- Files: `fUI_GOSwitchesMU.lua`, `fr0z3nUI_GameOptions.toc`
- Mount Up (Config): pressing Enter in the Delay box now applies/commits the value (same as clicking away).

# 2026.03.22.24
- Files: `fUI_GOSwitchesMU.lua`, `fr0z3nUI_GameOptions.toc`
- Mount Up (Config): corrected layout so Reap/Cast/Loot toggles sit next to the Delay box (after it), and `DBG` stays on the OSD/Lock row.

# 2026.03.22.23
- Files: `fUI_GOSwitchesMU.lua`, `fr0z3nUI_GameOptions.toc`
- Mount Up (Config): moved Delay control above the OSD/Lock row.
- Mount Up (Config): added Reap (Gather) / Cast / Loot toggles to choose whether those retry paths use your configured Delay (otherwise they keep the quick ~0.2s retry).

# 2026.03.22.22
- Files: `fUI_GOLootChat.lua`, `fr0z3nUI_GameOptions.toc`
- Loot (Achievement): fix GUID extraction so class-colored names work again (GUID is not the last chat event arg).

# 2026.03.22.21
- Files: `fUI_GOLootChat.lua`, `fr0z3nUI_GameOptions.toc`
- XP debug: make quest turn-in/two-source behavior diagnosable (logs inferred XP + liteSig, timer scheduling, and explicit cancel/suppress reasons when the LootIt tab Debug toggle is on).

# 2026.03.22.20
- Files: `fUI_GOLootChat.lua`, `fr0z3nUI_GameOptions.toc`
- Loot Experience (quest turn-ins): if the system-side XP line is handled by the no-match timer fallback, the XP_UPDATE “no-delta” path no longer prints the raw stored message (prevents the raw `Experience gained: ...` line from appearing first).

# 2026.03.22.19
- Files: `fUI_GOLootChat.lua`, `fr0z3nUI_GameOptions.toc`
- Loot Experience (quest turn-ins): prevent the stored raw `Experience gained: ...` no-match line from printing via XP_UPDATE when the formatted XP line already printed (fixes the remaining two-source duplicate).
- Loot Experience: only treat `CHAT_MSG_COMBAT_MISC_INFO` lines as XP when they look XP-related (avoids swallowing unrelated misc lines).

# 2026.03.22.18
- Files: `fUI_GOLootChat.lua`, `fr0z3nUI_GameOptions.toc`
- XP debug: reduce the “1 line/sec” throttle so quest turn-in bursts show the follow-up XP-source debug lines (still gated by the LootIt tab Debug toggle; unthrottled if Capture stacks is enabled).

# 2026.03.22.17
- Files: `fUI_GOLootChat.lua`, `fr0z3nUI_GameOptions.toc`
- Loot Experience (quest turn-ins): prevent duplicate XP prints when Blizzard fires both a system XP line and a combat/chat XP line by replacing the XP_UPDATE “no-match” fallback with a short timer fallback (cancels itself if the other source prints / quest-title delayed print is pending).

# 2026.03.22.16
- Files: `fUI_GOTax.lua`, `fr0z3nUI_GameOptions.toc`
- Tax tab: both `XS` buttons now treat “excess” as anything above `Min Gold + (Guild Owed + WarBank Owed)` (prevents one bank’s XS from eating money needed to pay the other bank’s owed).

# 2026.03.22.15
- Files: `fUI_GOTax.lua`, `fUI_GOTaxUI.lua`, `fr0z3nUI_GameOptions.toc`
- Tax tab: added a Guild Bank `XS` button (mirrors WarBank `XS`) opposite the Min Gold box; toggles “pay excess” to the Guild Bank.

# 2026.03.22.14
- Files: `fUI_GOSwitchesMU.lua`, `fr0z3nUI_GameOptions.toc`
- Mount Up float: while moving, the label now updates periodically so grey/green reflects the current area in real time (useful for knowing when to stop to mount).

# 2026.03.22.13
- Files: `fUI_GOSwitchesMU.lua`, `fr0z3nUI_GameOptions.toc`
- Mount Up float: revert grey-state back to logic-only “area” detection (indoors + no usable mount found); removed the UI error-message latch approach.

# 2026.03.22.12
- Files: `fUI_GOSwitchesMU.lua`, `fr0z3nUI_GameOptions.toc`
- Mount Up float: grey state is a true no-mount-area indicator (set by the actual “can’t mount here” error). It no longer clears just because you started moving; it clears once you’re actually mountable again.

# 2026.03.22.11
- Files: `fUI_GOSwitchesMU.lua`, `fr0z3nUI_GameOptions.toc`
- Mount Up float: if it turns grey due to a no-mount-area error, it clears as soon as you start moving away (and otherwise expires quickly), so it doesn’t stay grey until a successful mount.

# 2026.03.22.10
- Files: `fUI_GOSwitchesMU.lua`, `fr0z3nUI_GameOptions.toc`
- Mount Up float: grey state now means “this area doesn’t allow mounting” (no usable mount can be picked), so it’s obvious why Mount Up won’t fire.

# 2026.03.22.09
- Files: `fUI_GOSwitchesMU.lua`, `fr0z3nUI_GameOptions.toc`
- Mount Up float: grey state is now *indoors-only* (pure location restriction), not other “can’t mount” states.

# 2026.03.22.08
- Files: `fUI_GOSwitchesMU.lua`, `fr0z3nUI_GameOptions.toc`
- Mount Up float: label turns grey when Mount Up is enabled but your current location blocks mounting (e.g. indoors / taxi / vehicle / pet battle).

# 2026.03.22.07
- Files: `fUI_GOLootChat.lua`, `fr0z3nUI_GameOptions.toc`
- Loot Experience: when the same XP amount arrives from both sources in a tight window, suppress the plain XP reprint and keep the more-informative variant (quest-title/appended line, or a labeled line).

# 2026.03.22.06
- Files: `fUI_GOLootChat.lua`, `fUI_GOTalk.lua`, `fUI_GOTalk01EK.lua`, `fUI_GOTalk01KD.lua`, `fUI_GOTalk02.lua`, `fUI_GOTalk03.lua`, `fUI_GOTalk04.lua`, `fUI_GOTalk05.lua`, `fUI_GOTalk06.lua`, `fUI_GOTalk07.lua`, `fUI_GOTalk08KT.lua`, `fUI_GOTalk08ZL.lua`, `fUI_GOTalk09.lua`, `fUI_GOTalk10.lua`, `fUI_GOTalk11.lua`, `fUI_GOTalk12.lua`, `fUI_GOTalkEV.lua`, `fr0z3nUI_GameOptions.toc`
- Talk (DB authoring): unify NPC helpers to a single `NPC("Name", idOrTable)` call style (multi-ID supported via table), and make pack layout/name headers name-first.
- Talk (debug): print NPC as `Name (ID)` instead of `ID: Name`.

# 2026.03.22.05
- Files: `fUI_GOLootChat.lua`, `fr0z3nUI_GameOptions.toc`
- Loot (Achievement): class-color the character name in the custom achievement output line (uses GUID->class when available).

# 2026.03.22.04
- Files: `fr0z3nUI_GameOptions.lua`, `fr0z3nUI_GameOptions.toc`
- Slash: add `/fgo yump` (yum + print) for a one-off forced update with status output.

# 2026.03.22.03
- Files: `fr0z3nUI_GameOptions.lua`, `fr0z3nUI_GameOptions.toc`
- Slash: make `/fgo yum` fully silent (no chat prints).

# 2026.03.22.02
- Files: `fr0z3nUI_GameOptions.lua`, `fUI_GOMacros.lua`, `fr0z3nUI_GameOptions.toc`
- Slash: add `/fgo yum` to force-create/update the generated `FGO Food` and `FGO Drink` macros immediately.

# 2026.03.22.01
- Files: `fUI_GOMacros.lua`, `fr0z3nUI_GameOptions.toc`
- Macros (Food/Drink): prevent auto-updater from overwriting `FGO Food` / `FGO Drink` with the `#showtooltip` placeholder when no valid best item can be chosen yet (defers until a real candidate exists).

# 2026.03.21.31
- Files: `fUI_GOLootChat.lua`, `fr0z3nUI_GameOptions.toc`
- LootChat (XP): suppress occasional double-prints where the same XP amount appears twice (one line with a source label, followed by a plain XP line).

# 2026.03.21.30
- Files: `fUI_GOTradeUI.lua`, `fr0z3nUI_GameOptions.toc`
- Trade UI: fix a runtime error where `NormalizeBankTarget` was nil in some click paths.

# 2026.03.21.29
- Files: `fUI_GOTrade.lua`, `fr0z3nUI_GameOptions.toc`
- Trade (Restock): stop rounding purchases to the merchant item `stackCount`/`quantity` (treat it as the default buy size); restock now attempts to buy the exact needed unit count when possible.

# 2026.03.21.28
- Files: `fUI_GOTrade.lua`, `fr0z3nUI_GameOptions.toc`
- Trade (Restock): fix `Buying:` chat line to display the actual bundle-rounded units requested from the vendor (and show `need` when it differs), matching the resulting loot/stack splits.

# 2026.03.21.27
- Files: `fUI_GOSwitchesMU.lua`, `fr0z3nUI_GameOptions.toc`
- Mount Up: add a 20-second “finish eating/drinking then mount” timer (cancelled on movement) so mounting still happens after consumption even if the normal 8-second arm window expires.

# 2026.03.21.26
- Files: `fUI_GOSwitchesMU.lua`, `fr0z3nUI_GameOptions.toc`
- Mount Up: fix regression where eating/drinking could be interrupted by an auto-mount after you stop moving; eating/drinking is now reliably detected again.
- Mount Up: if Mount Up was armed while you were eating/drinking, it now retries shortly after the consuming aura ends (so you mount after finishing without needing a second trigger).

# 2026.03.21.25
- Files: `fUI_GOSwitchesMU.lua`, `fr0z3nUI_GameOptions.toc`
- Mount Up: eating/drinking gate now only blocks while the active “consuming” aura is present (movement-cancelled, no fixed duration), so Mount Up works again immediately after you finish eating/drinking.

# 2026.03.21.23
- Files: `fUI_GOTradeUI.lua`, `fr0z3nUI_GameOptions.toc`
- Trade UI (Items list): fix Health% column showing a value for mana-only drinks; Health%/Mana% now display only when the tooltip explicitly restores that resource.

# 2026.03.21.23
- Files: `fUI_GOTrade.lua`, `fr0z3nUI_GameOptions.toc`
- Trade (Restock/UI): fix mana-only drinks being misclassified as restoring health just because the word “health” appeared in the tooltip line; now only parsed “of your health/mana” counts.

# 2026.03.21.22
- Files: `fUI_GOTrade.lua`, `fr0z3nUI_GameOptions.toc`
- Trade (Restock): fix “not caching” / false-negative classification by not caching tooltip misses as `false`; if tooltip lines aren’t ready yet, restock now waits and retries.

# 2026.03.21.20
- Files: `fUI_GOTrade.lua`, `fr0z3nUI_GameOptions.toc`
- Trade (Restock): reduce chat spam by printing the `Buying:` line only once per item per merchant session (instead of once per chunk).

# 2026.03.21.19
- Files: `fUI_GOTrade.lua`, `fr0z3nUI_GameOptions.toc`
- Trade Debug: merchant debug header now prints `usesMana`, `maxMana`, and `powerType` to make drink gating diagnostics unambiguous.

# 2026.03.21.18
- Files: `fUI_GOTrade.lua`, `fr0z3nUI_GameOptions.toc`
- Trade (Restock): fix mana-user detection so it checks for an actual mana pool (not the current primary power type), preventing paladin specs/forms from incorrectly being treated as “non-mana”.

# 2026.03.21.17
- Files: `fUI_GOTrade.lua`, `fr0z3nUI_GameOptions.toc`
- Trade (Restock): fix under-buying by treating `BuyMerchantItem(idx, quantity)` as item-units on this client; buy calls now request the configured unit amounts (rounded to vendor bundle size) instead of “purchase counts”.

# 2026.03.21.16
- Files: `fUI_GOTrade.lua`, `fr0z3nUI_GameOptions.toc`
- Trade (Restock): when multiple tier rules share a restock group, the group target now follows the chosen best-tier item’s configured target (no more taking the max target across the group).

# 2026.03.21.15
- Files: `fUI_GOTrade.lua`, `fr0z3nUI_GameOptions.toc`
- Trade (Restock): cap each `BuyMerchantItem` call to the item’s real max stack size (e.g., buy in 20s), so vendor “bundle sizes” (like 5) don’t dictate buy chunking.

# 2026.03.21.14
- Files: `fUI_GOTrade.lua`, `fr0z3nUI_GameOptions.toc`
- Trade (Restock): fail closed when a restock rule can’t be classified/grouped yet (no category/use-key) — never fall back to buying each rule item.
- Trade (Restock): expand food/drink “Use:” parsing so mana-only drinks classify correctly; restock grouping now prefers the highest-tier usable item.

# 2026.03.21.13
- Files: `fUI_GOTrade.lua`, `fr0z3nUI_GameOptions.toc`
- Trade (Restock): fix overbuying stacked vendor items by converting unit “need” into the correct `BuyMerchantItem` purchase quantity (uses merchant per-purchase stack size); pending-bought tracking now increments by units bought.

# 2026.03.21.12
- Files: `fUI_GOMacros.lua`, `fr0z3nUI_GameOptions.toc`
- Macros (Food/Drink): silence combat-deferral messages; macro updates still defer in combat and retry after combat automatically.

# 2026.03.21.11
- Files: `fUI_GOMacros.lua`, `fr0z3nUI_GameOptions.toc`
- Macros (Food/Drink): remove success spam (“Created/Updated macro ...”) for the generated `FGO Food` / `FGO Drink` macros; failures still print.

# 2026.03.21.10
- Files: `fUI_GOMacros.lua`, `fr0z3nUI_GameOptions.toc`
- Macros: avoid no-op rewrites (if the existing macro body already matches, skip `EditMacro` and don’t print a duplicate “Updated macro ...” line).

# 2026.03.21.09
- Files: `fUI_GOMacros.lua`, `fr0z3nUI_GameOptions.toc`
- Macros (Food/Drink): fix generated `FGO Food` / `FGO Drink` not auto-updating after a `/reload` (auto-update now treats “macro exists” as active, not only the one-session `createdFood/createdDrink` flags).

# 2026.03.21.08
- Files: `fUI_GOSwitchesMU.lua`, `fr0z3nUI_GameOptions.toc`
- Mount Up: fix follow-up taint error (“secret string”) by avoiding all direct spellID comparisons; use `AuraUtil.FindAuraBySpellID` for eating/drinking detection, with a name-only fallback.

# 2026.03.21.07
- Files: `fUI_GOSwitchesMU.lua`, `fr0z3nUI_GameOptions.toc`
- Mount Up: fix a taint error in the eating/drinking gate on some clients (“secret number” aura spellIDs can’t be compared directly) by stringifying spellID before matching.

# 2026.03.21.06
- Files: `fUI_GOSwitchesMU.lua`, `fUI_GOSwitchesBP.lua`, `fr0z3nUI_GameOptions.toc`
- Floating buttons: when locked, right-click triggers the “special” action instead of drag.
	- Mount Up float: right-click runs Mount Special (same behavior as `/mountspecial`).
	- Pet Walk float: right-click dismisses your currently summoned battle pet.

# 2026.03.21.05
- Files: `fUI_GOSwitchesMU.lua`, `fr0z3nUI_GameOptions.toc`
- Mount Up: do not auto-mount while you are actively eating/drinking (blocks Mount Up when the generic regen aura is present).

# 2026.03.21.04
- Files: `fUI_GOMacros.lua`, `fr0z3nUI_GameOptions.toc`
- Macros (Food/Drink): improve tooltip parsing/ranking (more robust enUS restore patterns, percent handling, continuation fallback) so “best” selection matches real food/drink tooltips more reliably.

# 2026.03.21.03
- Files: `fUI_GOMacros.lua`, `fr0z3nUI_GameOptions.toc`
- Macros (Food/Drink): generated `FGO Food` / `FGO Drink` now ignore `+ Macro` optional injections (prevents optional `#showtooltip` placeholder from binding to Healthstone instead of food/drink).

# 2026.03.21.02
- Files: `fUI_GOMacros.lua`, `fr0z3nUI_GameOptions.toc`
- Macros (Food/Drink): add right-click conjure lines (guarded with `[known:...]`) to generated `FGO Food` and `FGO Drink` macros.

# 2026.03.21.01
- Files: `fUI_GOMacros.lua`, `fr0z3nUI_GameOptions.toc`
- Macros (Food): add `/use [combat] item:5512` (Healthstone) as a combat-only first line in the generated `FGO Food` macro.

# 2026.03.20.10
- Files: `fUI_GOMacros.lua`, `fUI_GOMacroUI.lua`, `fr0z3nUI_GameOptions.toc`
- Macros tab: add bottom `Food` / `Drink` buttons to create/update the `FGO Food` and `FGO Drink` macros based on best bag food/drink.
- Macros tab: add `Conjured` (green/grey) toggle next to `+ Macro` to prefer conjured items when ranking.

# 2026.03.20.09
- Files: `fUI_GOTradeUI.lua`, `fr0z3nUI_GameOptions.toc`
- Trade UI (Items list): auto-refresh the items window when rules change and when item cache finishes loading, so names/columns and newly-added items appear without reopening.

# 2026.03.20.08
- Files: `fUI_GOTrade.lua`, `fr0z3nUI_GameOptions.toc`
- Trade (Restock): wait for item/merchant cache to be ready before buying, so restock selection/counting doesn’t run with partial tooltip/item-data.

# 2026.03.20.07
- Files: `fr0z3nUI_GameOptions.lua`, `fr0z3nUI_GameOptions.toc`
- Slash `/fgo status`: remove the duplicate trailing `version=...` line (Loot status already prints version).

# 2026.03.20.06
- Files: `fUI_GOLootChat.lua`, `fr0z3nUI_GameOptions.toc`
- LootChat: fix remaining money false-positive where config/status text like `n=1, gold=on` could still be parsed/rewritten as `"<player>: 1"`.

# 2026.03.20.05
- Files: `fUI_GOLootChat.lua`, `fr0z3nUI_GameOptions.toc`
- LootChat: tighten money detection so status/config lines containing words like `gold=on` aren't rewritten as `"<player>: 1"`, and addon prints containing coin textures mid-line won't lose their trailing text.

# 2026.03.20.04
- Files: `fUI_GOTax.lua`, `fr0z3nUI_GameOptions.toc`
- Tax: normalize bank-move chat wording to consistently say `withdrawn from <BankName>` / `deposited to <BankName>` and print a friendly bank label (`Warband Bank` vs `WarBank`).

# 2026.03.20.03
- Files: `fUI_GOTax.lua`, `fr0z3nUI_GameOptions.toc`
- Tax: remove the explicit chat prefix on bank-move prints (restores the original plain `"<player>: <gold>"` style line).

# 2026.03.20.02
- Files: `fUI_GOLootChat.lua`, `fr0z3nUI_GameOptions.toc`
- LootChat: fix false-positive “money message” detection for single-letter amount tokens (`g/s/c`) so addon messages like `"8612 guides are loaded"` aren't suppressed/reprinted as `"<player>: 8612"`.

# 2026.03.20.01
- Files: `fUI_GOTax.lua`, `fr0z3nUI_GameOptions.toc`
- Tax: prefix bank move chat lines with `[Tax]` so the source is obvious when diagnosing unexpected prints.

# 2026.03.19.02
- Files: `fUI_GOCore.lua`, `fUI_GOLoot*.lua`, `fUI_GOTrade*.lua`, `fUI_GOTax*.lua`, `fUI_GOSwitchesMN.lua`, `fr0z3nUI_GameOptions.toc`
- LootIt embedding: stop binding to a separately-loaded standalone `fr0z3nUI_LootIt` global; always initialize/use the embedded `ns.LootIt` instance so the Loot/Trade/Tax tabs and `/fgo` status can't be hijacked by an old addon folder.

# 2026.03.19.01
- Files: `fUI_GOLootUI.lua`, `fr0z3nUI_GameOptions.toc`
- Loot tab (Experience): fix compact dropdown sizing so the `Quest` toggle button doesn't get pushed off-screen and appear missing.

# 2026.03.18.14
- Files: `fUI_GOTrade.lua`, `fr0z3nUI_GameOptions.toc`
- Trade/Purchase (Merchant): after buying a non-stackable item where the rule target is 1, block further buys of that item for the rest of the merchant session to prevent an immediate second attempt (and "can't carry any more" popup) during bag/cache lag.

# 2026.03.18.13
- Files: `fUI_GOLootChat.lua`, `fr0z3nUI_GameOptions.toc`
- Experience in Loot (Discovery XP): location name now has an extra leading space and is colored light blue (instead of default chat grey).

# 2026.03.18.12
- Files: `fUI_GOLootChat.lua`, `fr0z3nUI_GameOptions.toc`
- Experience in Loot (QuestXP): XP line quest title now has an extra leading space and is colored white (instead of default chat grey).

# 2026.03.18.11
- Files: `fUI_GOCore.lua`, `fUI_GOTrade.lua`, `fr0z3nUI_GameOptions.toc`
- Trade/Purchase (Merchant): if a buy attempt triggers the UI error "You can't carry any more", latch that itemID as blocked for the remainder of the merchant session so the ticker stops re-attempting and spamming the popup (common with Unique/max-count items).

# 2026.03.18.10
- Files: `fUI_GOTrade.lua`, `fr0z3nUI_GameOptions.toc`
- Trade/Purchase (Merchant): avoid restarting the merchant ticker if it's already running (prevents double-start from wiping session tracking and causing immediate repeat-buy attempts before bags update).

# 2026.03.18.09
- Files: `fUI_GOTrade.lua`, `fr0z3nUI_GameOptions.toc`
- Trade/Purchase (Merchant): prevent repeated buy attempts for items you already have equipped / Unique(1) by flooring Buy-mode "have" counts using `GetItemCount(..., includeBank=false)`.

# 2026.03.18.08
- Files: `fUI_GOLootChat.lua`, `fr0z3nUI_GameOptions.toc`
- Experience in Loot (QuestXP): never print a standalone "Quest completed: <title>" fallback line. Quest completion spam remains hidden, and the quest title only appears when it can be appended onto an XP gain line. Also briefly delays unnamed XP output so completions that arrive after the XP event can still attach.

# 2026.03.18.07
- Files: `fUI_GOTrade.lua`, `fr0z3nUI_GameOptions.toc`
- Trade/Purchase (Merchant): improved debug lines to show which rule is being processed and whether it's waiting on cache vs not sold by the current merchant.

# 2026.03.18.06
- Files: `fUI_GOTrade.lua`, `fr0z3nUI_GameOptions.toc`
- Trade/Purchase (Merchant): resolve merchant item IDs using multiple APIs (not just `GetMerchantItemLink`) for better compatibility with UI replacements; also sync merchant debug output to the same `tradeDebug` toggle so "no purchase" cases print why.

# 2026.03.18.05
- Files: `fUI_GOTrade.lua`, `fUI_GOTradeUI.lua`, `fr0z3nUI_GameOptions.toc`
- Trade/Purchase (Merchant): treat missing merchant item links right after open as a cache-wait state so the merchant ticker doesn't idle-out and require a reopen.
- Trade UI: Purchase list shows `C A R` scope indicator (Character/Account/Realm) colored green/orange for enabled/disabled; left-side buttons shortened and the list panel widened ~20% while staying on the tab.

# 2026.03.18.04
- Files: `fUI_GOTrade.lua`, `fr0z3nUI_GameOptions.toc`
- Trade/Purchase (Merchant): keep the merchant ticker alive while the vendor item list is still populating on first open (treat `GetMerchantNumItems()==0` as a cache-wait state in Buy mode).

# 2026.03.18.03
- Files: `fUI_GOCore.lua`, `fUI_GOTrade.lua`, `fr0z3nUI_GameOptions.toc`
- Trade/Purchase (Merchant): fix a first-open issue where vendor automation could fail until you reopened the vendor, by not keying the merchant ticker off `MerchantFrame:IsShown()` and by wiring merchant interaction events from the Interaction Manager (with dedupe).

# 2026.03.18.02
- Files: `fUI_GOLootChat.lua`, `fr0z3nUI_GameOptions.toc`
- Experience in Loot (QuestXP): attach the quest title to plain XP gain lines even when the XP parser can't identify the message kind (infer unnamed vs kill from presence of a mob string).

# 2026.03.18.01
- Files: `fUI_GOLootChat.lua`, `fr0z3nUI_GameOptions.toc`
- Experience in Loot (QuestXP): fix the delayed fallback printer so it always includes the quest title (some clients provide `QUEST_COMPLETE` without a `%s` placeholder, which previously caused a generic `"Quest completed"` line).

# 2026.03.17.73
- Files: `fUI_GOLootChat.lua`, `fr0z3nUI_GameOptions.toc`
- Experience in Loot (QuestXP): prevent `QUEST_TURNED_IN` from wiping the stored quest title when `GetTitleForQuestID()` returns nil (cache/timing).
- Experience in Loot (QuestXP): suppress the generic System line `"Quest completed"` (no title) when a recent titled completion is pending, so the quest name can appear on the XP line instead.

# 2026.03.17.72
- Files: `fUI_GOLootChat.lua`, `fr0z3nUI_GameOptions.toc`
- Experience in Loot (QuestXP): attach quest completion titles based on XP message kind (unnamed/quest XP) instead of relying on whether the XP parser produced a non-empty `mob` string.

# 2026.03.17.71
- Files: `fUI_GOLootChat.lua`, `fr0z3nUI_GameOptions.toc`
- Experience in Loot (QuestXP): fix a Lua error introduced in 070 where `MaybePrintXPDebug()` was referenced before being defined (forward declaration).

# 2026.03.17.70
- Files: `fUI_GOLootChat.lua`, `fr0z3nUI_GameOptions.toc`
- Experience in Loot (QuestXP): recognize and suppress the alternate quest completion format `"<Quest Title> completed."` in System messages, so it can merge into the XP line (or fallback-print).
- Experience in Loot (QuestXP): ensure the System-message filter is installed whenever QuestXP is enabled (even if LootIt main is off).

# 2026.03.17.69
- Files: `fUI_GOLootChat.lua`, `fr0z3nUI_GameOptions.toc`
- Experience in Loot (QuestXP): quest accepted/completed suppression no longer depends on LootIt's main enabled toggle (it is an Experience feature).
- Experience in Loot (QuestXP): add low-noise XP debug lines when quest status is stored/suppressed/fallback-printed.

# 2026.03.17.68
- Files: `fUI_GOLootChat.lua`, `fr0z3nUI_GameOptions.toc`
- Experience in Loot (QuestXP): fix quest completion → XP merge timing by using a consistent `GetTime()`-based timestamp for both system “Quest completed” lines and XP parsing.
- Experience in Loot (QuestXP): widen the merge window and add a delayed fallback print so a suppressed “Quest completed” line can’t vanish if no XP line arrives.

# 2026.03.17.67
- Files: `fUI_GOTrade.lua`, `fr0z3nUI_GameOptions.toc`
- Deposit (Slash): restore `/fgo deposit <target>` run behavior (e.g. `personal/guild/warbank`) so you can force a specific deposit path for debugging; `/fgo deposit` still auto-selects based on which bank UI is open.

# 2026.03.17.66
- Files: `fUI_GOTrade.lua`, `fr0z3nUI_GameOptions.toc`
- Deposit (Slash): `/fgo deposit` is now the only run-mode depositor; any explicit target word (e.g. `personal/guild/warbank`) is ignored so deposit always follows the currently open bank UI.
- Deposit (Slash): `/fgo deposit status|debug [target]` still accepts an optional target argument for reporting only.

# 2026.03.17.65
- Files: `fUI_GOTradeBank.lua`, `fr0z3nUI_GameOptions.toc`
- Deposit (Personal Bank): when `C_Bank` deposit APIs aren’t available, deposit now uses `C_Container.UseContainerItem()` for whole stacks (bank-open right-click behavior) and `SplitPickupContainerItemSafe()` + `PutItemInBank()` for partial stacks.
- Deposit (Personal Bank): blocked/undepositable items are now skipped instead of aborting the entire deposit run.

# 2026.03.17.64
- Files: `fUI_GOTradeBank.lua`, `fUI_GOTrade.lua`, `fr0z3nUI_GameOptions.toc`
- Deposit (Personal Bank): add a `PutItemInBank()` fallback after cursor pickup (often still works with the 12.0 bank panel even when Character bank slots aren’t enumerable as container bags).
- Deposit debug: `/fgo deposit debug` now prints bank UI shown state, selected bank type, and which `C_Bank` deposit functions are present.

# 2026.03.17.63
- Files: `fUI_GOTradeBank.lua`, `fr0z3nUI_GameOptions.toc`
- Deposit (Personal Bank, 12.0+): prefer `C_Bank` deposit APIs (Character bank type + `ItemLocation`) instead of trying to locate “bank bag” container IDs; keeps the old cursor/container placement as a fallback.

# 2026.03.17.62
- Files: `fUI_GOTradeBank.lua`, `fUI_GOTrade.lua`, `fr0z3nUI_GameOptions.toc`
- Deposit (Personal Bank): update deposit mover to work with the new bank panel (Personal Bank behaves like Warbank) by placing into the bank’s container panel instead of relying on legacy `PutItemInBank()`.
- Deposit: all “scan player bags” loops now only iterate backpack/equipped bags (+ reagent bag) so bank containers aren’t treated as inventory when the bank UI is open.
- Deposit: Personal Bank failures now print the specific reason (pickup/place/full/blocked).

# 2026.03.17.61
- Files: `fUI_GOTradeUI.lua`, `fr0z3nUI_GameOptions.toc`
- Deposit (UI): destination-filtered Items list now shows rules even when disabled/overridden (so you can re-enable them), and in Personal/Guild/Warbank views it also includes `bank` (auto) rules since those would deposit to that destination when that bank UI is open.


# 2026.03.17.60
- Files: `fUI_GOTradeBank.lua`, `fUI_GOTradeUI.lua`, `fr0z3nUI_GameOptions.toc`
- Deposit (UI): the right-side Items list filtering now uses the deposit engine’s effective resolver (same Char/Realm/Acc precedence + disable flags) so the list can’t drift from runtime behavior.

# 2026.03.17.59
- Files: `fUI_GOTradeBank.lua`, `fUI_GOTrade.lua`, `fr0z3nUI_GameOptions.toc`
- Deposit: restore “one deposit list” behavior by storing a destination tag per rule (`bank`/`personal`/`guild`/`warbank`) and computing the effective destination with Char > Realm > Account precedence + disable flags.
- Deposit: runtime `/fgo deposit` (and `bank` auto) now deposits based on each rule’s stored destination (plus `bank` auto-to-open-bank) and does **not** read the UI destination selector, preventing the old “button overrides deposit” bug.
- Deposit: `/fgo deposit status|debug` now shows `resolved=` destination when target is `bank` (auto), plus a per-destination effective breakdown in debug.

# 2026.03.17.58
- Files: `fUI_GOTradeBank.lua`, `fr0z3nUI_GameOptions.toc`
- Deposit: when no explicit target is provided, `/fgo deposit` and `/fgo deposit status|debug` now default to the Deposit tab’s saved target (`cfg.target`) instead of always using `bank`.

# 2026.03.17.57
- Files: `fUI_GOTrade.lua`, `fUI_GOTradeBank.lua`, `fr0z3nUI_GameOptions.toc`
- Deposit: add `/fgo deposit status [target]` and `/fgo deposit debug [target]` to print a one-shot report (bank-open detection, normalized target/list, effective rule count, and debug breakdown/sample IDs).
- Deposit: allow `/fgo deposit <target>` to run with an explicit target (`bank`/`personal`/`guild`/`warbank`).

# 2026.03.17.56
- Files: `fUI_GOMacroUI.lua`, `fr0z3nUI_GameOptions.toc`
- HM (UI): add an `S` button on the Alliance/Horde/Portal rows to print status (Portal uses the same output as `/fgo hm portal status`; Home rows print saved target + secure button attributes).

# 2026.03.17.55
- Files: `fUI_GOMacroUI.lua`, `fr0z3nUI_GameOptions.toc`
- HM Portal (UI): clicking the "FGO HM Portal" row label now captures/sets the portal target (like `/fgo hm portal set`); the small `M` button remains macro-only.

# 2026.03.17.54
- Files: `fUI_GOMacroUI.lua`, `fr0z3nUI_GameOptions.toc`
- HM Portal: the UI "FGO HM Portal" Create button now captures/sets the portal target (same as `/fgo hm portal set`) when standing in the desired plot.

# 2026.03.17.53
- Files: `fUI_GOTradeUI.lua`, `fr0z3nUI_GameOptions.toc`
- Trade/Deposit: when a Warbound item auto-switches the deposit target to Warbank, immediately refresh/rebind the right-side Items list and scope state so edits apply to Warbank.
- Trade/Deposit: treat legacy `guildbank` target strings as `guild` (target normalization).

# 2026.03.17.52
- Files: `fUI_GOTradeUI.lua`, `fr0z3nUI_GameOptions.toc`
- Trade/Deposit: emit the cycle+counts debug line via `DEFAULT_CHAT_FRAME:AddMessage` (with `|` escaping) to guarantee it shows even if addon `Print()` routing drops it.

# 2026.03.17.51
- Files: `fUI_GOTradeUI.lua`, `fr0z3nUI_GameOptions.toc`
- Trade/Deposit: print target-cycle + per-scope rule counts on the same click/refresh debug line so the numbers can’t be lost as a separate chat message.

# 2026.03.17.50
- Files: `fUI_GOTradeUI.lua`, `fr0z3nUI_GameOptions.toc`
- Trade/Deposit: fix the combined target-cycle debug line being swallowed by WoW chat due to a literal `|` (escape prefix) in the message.

# 2026.03.17.49
- Files: `fUI_GOTradeUI.lua`, `fr0z3nUI_GameOptions.toc`
- Trade/Deposit: merge target-cycle + per-scope counts into a single debug line (avoids chat dropping the “second line” during rapid refresh/rebuild).

# 2026.03.17.48
- Files: `fUI_GOTradeUI.lua`, `fr0z3nUI_GameOptions.toc`
- Trade/Deposit: when cycling bank targets with Trade `Debug` enabled, print the per-scope rule counts for the newly selected target directly (bypasses any Items list UI refresh issues).

# 2026.03.17.47
- Files: `fUI_GOTradeUI.lua`, `fr0z3nUI_GameOptions.toc`
- Trade/Deposit: reduce debug spam during Items list rebuilds so the important per-target counts line reliably shows in chat.

# 2026.03.17.46
- Files: `fUI_GOTradeUI.lua`, `fr0z3nUI_GameOptions.toc`
- Trade/Deposit: change the list-count debug line to use safe string concatenation (`tostring`) instead of `string.format`, to avoid any formatting/type issues hiding the output.

# 2026.03.17.45
- Files: `fUI_GOTradeUI.lua`, `fr0z3nUI_GameOptions.toc`
- Trade/Deposit: wrap the list-count debug block in `pcall` and print any caught errors so we can see why `TradeUI list: ...` isn’t showing.

# 2026.03.17.44
- Files: `fUI_GOTradeUI.lua`, `fr0z3nUI_GameOptions.toc`
- Trade/Deposit: add entry-trace for the Items list builder and wrap refresh/build calls in `pcall` to surface any errors preventing the list from rebuilding/printing debug output.

# 2026.03.17.43
- Files: `fUI_GOTradeUI.lua`, `fr0z3nUI_GameOptions.toc`
- Trade/Deposit: when cycling bank targets, force an Items list rebuild via an exposed list-builder fallback (and print which refresh function is being used when Trade `Debug` is enabled).

# 2026.03.17.42
- Files: `fUI_GOTradeUI.lua`, `fr0z3nUI_GameOptions.toc`
- Trade/Deposit: fix debug gating so Trade `Debug` prints can’t be lost to a Lua local-ordering pitfall; add a guaranteed debug line when cycling bank targets so we can confirm the click handler fired + see the before/after target.

# 2026.03.17.41
- Files: `fUI_GOTradeUI.lua`, `fr0z3nUI_GameOptions.toc`
- Trade/Deposit: when Trade `Debug` is enabled, the Items list now prints the detected target and rule counts per scope so we can see exactly why a per-target list appears empty.

# 2026.03.17.40
- Files: `fUI_GOTradeBank.lua`, `fUI_GOTradeUI.lua`, `fr0z3nUI_GameOptions.toc`
- Trade/Deposit: fix empty Personal/Guild/Warbank Items lists when rules existed under legacy target keys (migrates `either`/`personalbank`/`guildbank`/`warband` into `bank`/`personal`/`guild`/`warbank`).

# 2026.03.17.39
- Files: `fUI_GOTradeUI.lua`, `fr0z3nUI_GameOptions.toc`
- Trade/Deposit: when selecting a Warbound item auto-switches the deposit target to Warbank, the right-side Items list now switches/refreshes too (and scope edits apply to the Warbank list immediately).

# 2026.03.17.38
- Files: `fUI_GOMacroHome.lua`, `fr0z3nUI_GameOptions.toc`
- Fix: HM Portal no longer errors on click due to a Lua local-scope ordering bug (`GetPlayerFactionKey` being treated as a missing global).

# 2026.03.17.37
- Files: `fUI_GOMacroHome.lua`, `fr0z3nUI_GameOptions.toc`
- HM Portal: added `/fgo hm portal status` debug output (shows saved target + secure button attributes + cooldown) and reduced misleading spam (won't claim "Found ID" unless a stale-GUID retry actually occurred).

# 2026.03.17.36
- Files: `fUI_GOMacroHome.lua`, `fUI_GOMacroUI.lua`, `fr0z3nUI_GameOptions.toc`
- HM Alliance/Horde (Home1/Home2): moved the saved destinations to account-wide storage (`AutoGame_Settings.fgoHomeTeleports`) so you don't have to capture per-character.
- Migration: if legacy per-character slots exist, they are copied into the account table when missing.

# 2026.03.17.35
- Files: `fUI_GOMacroHome.lua`, `fUI_GOMacroUI.lua`, `fr0z3nUI_GameOptions.toc`
- HM Portal: redesigned to use a dedicated secure-click button (`/click FGO_HMPortalTeleport`) backed by an account-wide saved target per faction (capture with `/fgo hm portal set` while standing in the desired +Friend plot).
- Slash: `/fgo hm portal` now prints the macro body + capture instructions (no longer tries to execute secure teleports directly).

# 2026.03.17.34
- Files: `fr0z3nUI_GameOptions.lua`, `fr0z3nUI_GameOptions.toc`
- Slash: `/fgo mountequip` warning text now says “Mount needs Inflatable Mount Shoes”.

# 2026.03.17.33
- Files: `fUI_GOTalkUP.lua`, `fr0z3nUI_GameOptions.toc`
- TalkUP: added a conservative fallback to auto-confirm Spirit Healer-style resurrect popups when they fire as `DEATH`/`XP_LOSS` without any gossip option selection context (gated by popup text).

# 2026.03.17.32
- Files: `fUI_GOTalkUP.lua`, `fUI_GOTalk01KD.lua`, `fr0z3nUI_GameOptions.toc`
- TalkUP: Spirit Healer resurrect confirm can fire as `XP_LOSS`; treat it as a gossip-ish confirm so existing `GOSSIP_CONFIRM` rules can match.
- Talk DB: expanded Spirit Healer confirm-text matching to cover XP-loss phrasing.

# 2026.03.17.31
- Files: `fUI_GOTalkUP.lua`, `fUI_GOTalk01KD.lua`, `fr0z3nUI_GameOptions.toc`
- TalkUP: allow Spirit Healer resurrect confirmation popups to auto-confirm even when they fire as `DEATH` (no reliable gossip option selection).
- Talk DB: made the Spirit Healer confirm-text match more tolerant (corpse wording variants).

# 2026.03.17.30
- Files: `README.md`, `fr0z3nUI_GameOptions.toc`
- Docs: expanded the Loot tab section to cover the “Achievement / Experience / Professions” output controls (Bonus/Quest/XP Label) and the `Alias`/`Info` popouts.

# 2026.03.17.29
- Files: `README.md`, `fr0z3nUI_GameOptions.toc`
- Docs: rewrote the README into a GUI-first “FGO for Dummies” style guide (ACC vs CHAR, Switches segmented controls/TooltipX, and click-by-click workflows per tab).

# 2026.03.17.28
- Files: `README.md`, `fr0z3nUI_GameOptions.toc`
- Docs: expanded the README into a proper “what this addon is + how to use it” guide (tab overview + updated `/fgo` command cheat sheet).

# 2026.03.17.27
- Files: `fUI_GOLootChat.lua`, `fr0z3nUI_GameOptions.toc`
- Fix: resolved a chat-frame hook error (`FormatSelfLine` nil) triggered by direct money receipt prints after adding AddMessage capture logging.

# 2026.03.17.26
- Files: `fUI_GOLootChat.lua`, `fr0z3nUI_GameOptions.toc`
- LootIt: capture debug now logs direct chat-frame `AddMessage` prints (which can bypass normal chat event filters), so `/fgo li capture dump` can see lines like the textureless money “You gained: …” case.

# 2026.03.17.25
- Files: `fUI_GOLootChat.lua`, `fr0z3nUI_GameOptions.toc`
- LootIt: money capture/reprint now recognizes textureless numeric coin lines like `You gained: 7,536 63 26` (gold/silver/copper) so they can be suppressed/reprinted/combined like normal money messages.

# 2026.03.17.24
- Files: `fr0z3nUI_GameOptions.lua`, `fUI_GOSwitchesCT.lua`, `fr0z3nUI_GameOptions.toc`
- Chromie Time (GUI): bottom-of-window status label is now anchored to the full FGO window width to prevent truncation like `Chromie Ti...`.
- Chromie Time (floating indicator): reverted the earlier auto-sizing behavior back to the original fixed-size indicator.

# 2026.03.17.23
- Files: `fUI_GOSwitchesCT.lua`, `fr0z3nUI_GameOptions.toc`
- Chromie indicator: the movable “Chromie Time” indicator frame now auto-sizes its width to the text (prevents truncation like `Chromie Ti...`).

# 2026.03.17.22
- Files: `fr0z3nUI_GameOptions.lua`, `fr0z3nUI_GameOptions.toc`
- UI: reordered the tab buttons into alphabetical order (visual order only; tab IDs/panels unchanged).

# 2026.03.17.21
- Files: `fUI_GOTax.lua`, `fr0z3nUI_GameOptions.toc`
- Tax: guild home realm no longer gets stuck as `UNKNOWN` when WoW omits the realm string for same-realm guilds.

# 2026.03.17.20
- Files: `fr0z3nUI_GameOptions.lua`, `fr0z3nUI_GameOptions.toc`
- UI: renamed the tab label from `LootIt` to `Loot`.

# 2026.03.17.19
- Files: `fr0z3nUI_GameOptions.lua`, `fUI_GOTaleUI.lua`, `fUI_GOTaxUI.lua`, `fr0z3nUI_GameOptions.toc`
- Chromie Time: replaced the old 2-line top-right label with a single-line bottom-center status line on the Switches/Tabard/Tale/Talk/Textures/LootIt/Tax/Trade tabs.
- Tale UI: shortened `Print`/`Debug` buttons; made the Print threshold input frameless.
- Tax UI: moved the `Manual` toggle button below `Min Gold`.

# 2026.03.17.18
- Files: `fUI_GOTaxUI.lua`, `fr0z3nUI_GameOptions.toc`
- Tax UI: moved the guild name line up slightly to add space below it.

# 2026.03.17.17
- Files: `fUI_GOTaxUI.lua`, `fr0z3nUI_GameOptions.toc`
- Tax: cache the detected guild name + home realm per character once known, and update the cache if it changes.
- Tax UI: if the home realm is temporarily unknown, reuse the cached home realm for that character (otherwise show `UNKNOWN`).

# 2026.03.17.16
- Files: `fUI_GOTax.lua`, `fUI_GOTaxUI.lua`, `fr0z3nUI_GameOptions.toc`
- Tax UI: guild name keeps its original large auto-fit sizing; the realm line stays smaller (button-text sized).
- Tax UI: when the guild home realm can’t be determined, the realm line now shows `UNKNOWN` (no fallback to your current realm).

# 2026.03.17.15
- Files: `fUI_GOTextures.lua`, `fr0z3nUI_GameOptions.toc`
- Textures: stop printing the “ArtLayer migration already completed …” line on every `/reload` (now only prints when Textures debug is ON).

# 2026.03.17.14
- Files: `fUI_GOSituatePF.lua`, `fr0z3nUI_GameOptions.toc`
- Popouts: fixed “one popout at a time” by initializing the popout manager early (so modules that register popouts during load are actually registered).

# 2026.03.17.13
- Files: `fUI_GOLootUI.lua`, `fr0z3nUI_GameOptions.toc`
- LootIt Suppress: popout now opens out to the right (Mail-style) instead of hovering over the tab, and uses the cleaner popout backdrop styling.

# 2026.03.17.12
- Files: `fUI_GOLootChat.lua`, `fr0z3nUI_GameOptions.toc`
- Fix: resolved a login-time chat-hook crash when `IsSecretString` is not defined (suppression helpers now correctly use a local secret-string guard).

# 2026.03.17.11
- Files: `fUI_GOTax.lua`, `fUI_GOTaxUI.lua`, `fr0z3nUI_GameOptions.toc`
- Tax: guild identity is now keyed by Guild GUID (best-effort migration from legacy `realm::guildName` buckets for the current guild).
- Tax UI: guild header is now two lines: Guild name + Home realm (both faction-colored).

# 2026.03.17.10
- Files: `fr0z3nUI_GameOptions.lua`, `fUI_GOLootUI.lua`, `fUI_GOTexturesUI.lua`, `fUI_GOCore.lua`, `fUI_GOMacroUI.lua`, `fUI_GOSituateUI.lua`, `fUI_GOSwitchesBP.lua`, `fUI_GOSwitchesCT.lua`, `fUI_GOSwitchesMU.lua`, `fUI_GOTradeUI.lua`, `fr0z3nUI_GameOptions.toc`
- Suppress: moved the `Suppress` button/popout onto the LootIt tab (tab-local parent), while keeping it positioned above the main `Reload UI` button.
- Popouts: added a small registry so only one popout can be open at a time (opening any popout auto-closes the rest).
- LootIt: removed the accidental dedicated `ERG` suppression toggle; ERG noise should be handled via the generic Suppress rules list.

# 2026.03.17.09
- Files: `fr0z3nUI_GameOptions.lua`, `fUI_GOLootChat.lua`, `fUI_GOCore.lua`, `fr0z3nUI_GameOptions.toc`
- Suppress: added a `Suppress` popout button above `Reload UI` with an SV-backed, per-line substring suppress list (toggle/add/delete).
- Suppress: rules apply to both chat event filters and direct `AddMessage` prints (covers many addon `Print()` spam lines).

# 2026.03.17.08
- Files: `fUI_GOLootChat.lua`, `fr0z3nUI_GameOptions.toc`
- Played: fixed suppression for `/played` lines that bypass chat event filters (direct `AddMessage` prints).

# 2026.03.17.07
- Files: `fUI_GOLootUI.lua`, `fr0z3nUI_GameOptions.toc`
- LootIt UI: aligned `Debug`/`Played` buttons with the main `Reload UI` button row.

# 2026.03.17.06
- Files: `fUI_GOLootUI.lua`, `fr0z3nUI_GameOptions.toc`
- LootIt UI: moved the LootIt tab contents down so the Enable button no longer overlaps the tab strip.

# 2026.03.17.05
- Files: `fUI_GOLootUI.lua`, `fUI_GOLootChat.lua`, `fUI_GOCore.lua`, `fr0z3nUI_GameOptions.toc`
- LootIt UI: added a `Played` toggle next to `Debug` (default OFF) that hides `/played` system output lines.
- Loot Experience: `Quest` mode now also suppresses quest-log removal lines like “The quest X has been removed from your quest log.”
- Tooltips: updated the `Quest` and `Before/After` (XP label position) tooltips for clarity.

# 2026.03.17.04
- Files: `fUI_GOLootUI.lua`, `fUI_GOLootChat.lua`, `fUI_GOCore.lua`, `fr0z3nUI_GameOptions.toc`
- Loot Experience: added a separate `Quest` toggle button (next to `Bonus`) that hides the quest Accepted/Completed system lines.
- Loot Experience: when `Quest` is ON, only the quest *title* from the Completed line is appended to the XP gain output (e.g. `12345 XP Temple Throwdown`).

# 2026.03.17.03
- Files: `fUI_GOLootChat.lua`, `fr0z3nUI_GameOptions.toc`
- Loot Experience: suppress and reprint the quest system lines (`Quest accepted:` / `Quest completed:`) when experience rewriting is enabled, so the stock “completed” line doesn’t linger.

# 2026.03.17.02
- Files: `fUI_GOMacroXCMD.lua`, `fr0z3nUI_GameOptions.toc`
- Macro-XCMD: stop injecting `/stopmacro [advfly]` (it causes the in-game error “Unknown macro option: advfly”).

# 2026.03.17.01
- Files: `fUI_GOLootChat.lua`, `fr0z3nUI_GameOptions.toc`
- Loot Experience: suppress the original XP system/combat chat line when the parser can’t match it (prevents duplicate lines when XP_UPDATE fallback prints).
- Loot Experience: for quest XP, append the most recent turned-in quest title (from `QUEST_TURNED_IN`) when available.

# 2026.03.16.37
- Files: `fr0z3nUI_GameOptions.lua`, `fr0z3nUI_GameOptions.toc`
- Help: changed LootIt help output and `/fgo scope` to prefer `/fgo lootit ...` (kept `/fgo li ...` as a legacy alias).
- Slash: added `/fgo trade food ...` as an alias for the Trade "food" helper command.

# 2026.03.16.36
- Files: `fr0z3nUI_GameOptions.lua`, `fr0z3nUI_GameOptions.toc`
- Slash: removed `/fgo li` bloat for common LootIt commands by promoting them to top-level: `/fgo mail ...`, `/fgo alias ...`, `/fgo capture ...`, `/fgo chatdebug ...`, `/fgo delayflush ...`, `/fgo status`.
- Parser: marked these as known full commands so they won't be split by Macro-CMD mode glue (e.g. `mail` no longer becomes `m ail`).
- Help: updated `/fgo li ?` output to show the new `/fgo ...` commands (kept `/fgo li on|off|toggle`).

# 2026.03.16.35
- Files: `fr0z3nUI_GameOptions.lua`, `fr0z3nUI_GameOptions.toc`
- Slash: added direct `/fgo deposit` routing to the hosted LootIt/Trade deposit helper (previously only worked as `/fgo li deposit`).

# 2026.03.16.34
- Files: `fUI_GOLootChat.lua`, `fr0z3nUI_GameOptions.toc`
- Loot Experience: pad the XP number block with dim `0`s instead of leading spaces (better alignment in proportional chat fonts).

# 2026.03.16.33
- Files: `fr0z3nUI_GameOptions.lua`, `fr0z3nUI_GameOptions.toc`
- Slash: fixed `/fgo deposit` being mis-parsed as Macro-CMD mode `/fgo d eposit` (caused by the single-letter mode “glue” parser for `/fgo d <key>`).


# 2026.03.16.32
- Files: `fUI_GOTalk06.lua`, `fr0z3nUI_GameOptions.toc`
- Talk DB (Draenor pet battles): removed `xpop` confirm metadata (no confirm popup), keeping `mount = true` behavior.

# 2026.03.16.31
- Files: `fUI_GOSwitchesMU.lua`, `fr0z3nUI_GameOptions.toc`
- MountUp: improved reliability by re-arming a mount attempt after player cast/channel completion and after loot closes (fixes common gather case where MountUp would not re-trigger until you moved).

# 2026.03.16.30
- Files: `fUI_GOTalk.lua`, `fr0z3nUI_GameOptions.toc`
- Gossip rules: `mount = true` now also dismounts silently before auto-select (safeguarded to avoid dismounting while flying/falling).

# 2026.03.16.29
- Files: `fUI_GOTalk.lua`, `fr0z3nUI_GameOptions.toc`
- Gossip rules: support `mount = true` to disable MountUp (Character) silently (equivalent to `/fgo mu soff`) before auto-selecting the matched gossip option.

# 2026.03.16.28
- Files: `fUI_GOTradeUI.lua`, `fr0z3nUI_GameOptions.toc`
- UI (Trade): list header now uses mode-specific titles: `Bank Items`/`Personal Items`/`Guild Items`/`Warbank Items`, `Purchase Items`, `Sell Items`.
- UI (Trade): removed the “Deposit/Buy/Sell … rules: #” subtitle; `Rules: #` is now in the top-right of the list window.
- UI (Trade): item rows sit directly under the list title; list frame is lifted to avoid overlapping the main `Reload UI` row.
- UX (Trade): the list refreshes immediately after adding/removing an item rule.

# 2026.03.16.27
- Files: `fUI_GOTexturesUI.lua`, `fr0z3nUI_GameOptions.toc`
- Fix: after building the Mail Notifier popout, it now calls the embedded mail editor `Refresh()` immediately so controls populate without needing to click Scope.

# 2026.03.16.26
- Files: `fr0z3nUI_GameOptions.lua`, `fUI_GOTexturesUI.lua`, `fr0z3nUI_GameOptions.toc`
- Fix: ensured LootIt hosted env wiring runs at addon load (not just after using `/fgo li`), so the Mail Notifier popout config fields populate reliably.
- Safety: Mail Notifier popout also wires env on-demand before building UI.

# 2026.03.16.25
- Files: `fUI_GOSwitchesUI.lua`, `fUI_GOTexturesUI.lua`, `fUI_GOSwitchesMN.lua`, `fr0z3nUI_GameOptions.toc`
- UI: moved Mail Notifier controls to the Switches tab using a 3-segment control (Mail=ACC on/off, Enable=CHAR on/off, Config=popout).
- UI: removed the obsolete enable/mode button from the Mail Notifier popout; updated the popout title to “Mail Notifier”; removed the Textures header Mail button.
- Rename: `fUI_GOTextureMail.lua` → `fUI_GOSwitchesMN.lua`.

# 2026.03.16.24
- Files: `fUI_GOTexturesUI.lua`, `fUI_GOTextureMail.lua`, `fr0z3nUI_GameOptions.toc`
- Fix: Mail popout now preloads/builds its content once the Mail module is available (tab-style), even if the popout was opened early.

# 2026.03.16.23
- Files: `fUI_GOTexturesUI.lua`, `fUI_GOTaxUI.lua`, `fr0z3nUI_GameOptions.toc`
- Fix: Mail popout now lazily (re)builds its UI on open so it can’t get stuck blank after `/reload`.
- UI: Tax owed rows now align under the Vendor↔Loot and Mail↔System gaps (instead of a generic left/right split).

# 2026.03.16.22
- Files: `fUI_GOTradeUI.lua`, `fr0z3nUI_GameOptions.toc`
- UI: Trade tab now uses a left/right split layout; controls are contained on the left.
- UI: Items list is now a permanent right-side panel (no toggle popout) and refreshes when mode/target changes (e.g. Bank button).

# 2026.03.16.21
- Files: `fUI_GOTexturesUI.lua`, `fr0z3nUI_GameOptions.toc`
- UI: Mail popout no longer anchors its Debug button to the main window (prevents Debug appearing on the Textures tab when Mail is opened).

# 2026.03.16.20
- Files: `fr0z3nUI_GameOptions.lua`, `fUI_GOTaxUI.lua`, `fr0z3nUI_GameOptions.toc`
- UI: Tax tab now reuses the main frame `Reload UI` button when available (prevents a duplicate Reload button on the Tax tab).

# 2026.03.16.19
- Files: `fr0z3nUI_GameOptions.lua`, `fUI_GOTexturesUI.lua`, `fr0z3nUI_GameOptions.toc`
- UI: LootIt/Tax/Trade tabs now render inside a proper content inset (below the tab bar) to prevent controls being clipped/out-of-frame.
- UI: Mail config popout now opens beside the main window (instead of centered over it).

# 2026.03.16.18
- Files: `fUI_GOCore.lua`, `fUI_GOTextureMail.lua`, `fUI_GOTradeBank.lua`, `fr0z3nUI_GameOptions.toc`
- Fix: resolved Lua load/runtime blockers (`<eof>`/unexpected `end`) in core + mail notifier module; repaired `Mail.HandleSlash` debug handling.
- Safety: guarded `DepositCfgAcc()` against nil DB during early load to avoid TradeBank crashing on startup.

# 2026.03.16.17
- Files: `fUI_GOCore.lua`, `fr0z3nUI_GameOptions.lua`, `fr0z3nUI_GameOptions.toc`
- Core boundary: moved the main addon event frame + event registrations out of `fr0z3nUI_GameOptions.lua` into `fUI_GOCore.lua` so runtime/event wiring is early; core now delegates to `ns.FGO_OnEvent(...)` implemented in main.

# 2026.03.16.16
- Files: `fUI_GOCore.lua`, `fUI_GOLootAliasDB.lua`, `fUI_GOLoot.lua`, `fUI_GOLootChat.lua`, `fUI_GOLootAlias.lua`, `fUI_GOLootUI.lua`, `fUI_GOTrade.lua`, `fUI_GOTradeBank.lua`, `fUI_GOTradeUI.lua`, `fUI_GOTextureMail.lua`, `fUI_GOTax.lua`, `fUI_GOTaxUI.lua`, `fUI_GOTexturesUI.lua`, `fr0z3nUI_GameOptions.toc`
- LootIt: migrated remaining module entrypoints to prefer the shared addon namespace `ns.LootIt` (global kept only as a fallback/compat alias).
- LootIt: moved `fUI_GOLootAliasDB.lua` earlier in the TOC so built-in alias tables exist before core snapshots them.

# 2026.03.16.15
- Files: `fUI_GOCore.lua`, `fr0z3nUI_GameOptions.lua`, `fr0z3nUI_GameOptions.toc`
- LootIt: treat this as a single addon namespace — core now publishes LootIt as `ns.LootIt`, and the main file prefers `ns.LootIt` over `_G.fr0z3nUI_LootIt` (global kept only as a compatibility alias).

# 2026.03.16.14
- Files: `fUI_GOCore.lua`, `fr0z3nUI_GameOptions.lua`, `fr0z3nUI_GameOptions.toc`
- LootIt/Core: moved the UI shim + bootstrap wiring + `/fgo li` handler implementation out of core and into the main GameOptions file (core is now runtime/DB/events only).
- LootIt/Main: main now calls `LI.Bootstrap.WireAll(LI.CoreBuildBootstrapEnv())` once at load.

# 2026.03.16.13
- Files: `fUI_GOCore.lua`, `fr0z3nUI_GameOptions.toc`
- LootIt/Core: renamed `fUI_GOLootItHost.lua` to `fUI_GOCore.lua` (no logic changes; just a cleanup rename).

# 2026.03.16.12
- Files: `fUI_GOLootItHost.lua`, `fr0z3nUI_GameOptions.toc`
- LootIt/Core: merged the former `fUI_GOLootBootstrap.lua` (UI/env wiring) and `fUI_GOLootUIV.lua` (slash handler) into the Host/core file; removed both from the TOC so LootIt initializes from a single early file.

# 2026.03.16.11
- Files: `fUI_GOLootUI.lua`, `fr0z3nUI_GameOptions.toc`
- LootIt/UI: the LootIt panel Reset button now clears the new FGO-backed SV tables (`AutoGame_Acc.lootIt`, `AutoGame_Char.lootIt`) in-place (so reset works after SV consolidation).

# 2026.03.16.10
- Files: `fUI_GOLootItHost.lua`, `fr0z3nUI_GameOptions.toc`
- SavedVariables: hosted LootIt/Tax/Trade now persist inside FGO SV (`AutoGame_Acc.lootIt`, `AutoGame_Char.lootIt`); removed `fr0z3nUI_LootItDB` / `fr0z3nUI_LootItCharDB` from the TOC.
- Note: this resets prior LootIt settings unless they are reconfigured.

# 2026.03.16.09
- Files: `fUI_GOTradeBank.lua`, `fUI_GOLootItHost.lua`, `fUI_GOTrade.lua`, `fr0z3nUI_GameOptions.toc`
- LootIt/Trade: extracted the full deposit/bank engine (deposit runners, deposit button, bank ticker, bank-open state, guild bank query session helpers) into the dedicated `fUI_GOTradeBank.lua` file.
- LootIt/Host: rewired event wiring to call the moved exports (`LI.RunDeposit`, `LI.UpdateDepositButtonVisibility`, bank interaction open/close setters, bank ticker start/stop), keeping Host focused on wiring.
- LootIt/Trade: removed bank/deposit lifecycle handlers from `fUI_GOTrade.lua` so there is a single source of truth.
- Fix: repaired an accidental corruption in `fUI_GOTrade.lua` during handler removal (restored player-name color helper + realm/scope trade-rule resolution).
- Fix: restored missing `DepositCfgChar()` buy tables in `fUI_GOTradeBank.lua` and fixed guild-bank helper scoping (local `QueryGuildBankTabIfNeeded`, local `GetCurrentGuildKey`).

# 2026.03.16.08
- Files: `fUI_GOTrade.lua`, `fr0z3nUI_GameOptions.toc`
- LootIt/Trade: moved the merchant vendor buy/sell/restock engine (merchant ticker + rule resolution + food selling/restock helpers) into `fUI_GOTrade.lua` so Trade owns Trade.
- Fix: restores missing `StartMerchantTradeTicker` / `StopMerchantTradeTicker` / `RunMerchantTradeOnce` that were previously only present in older/live Host code.
- Fix: `GetItemRequiredPlayerLevel()` now reads the correct `GetItemInfo` return (avoids treating item level as required level when uncached).
- Slash: `/fgo li food debug` now falls back to `LI.DebugSellOldFoodAtMerchant` when the env debug hook isn’t present.

# 2026.03.16.07
- Files: `fr0z3nUI_GameOptions.toc`, `fUI_GOLootItHost.lua`, `fUI_GOLoot.lua`, `fUI_GOLootChat.lua`, `fUI_GOLootUIV.lua`, `fUI_GOLootUI.lua`, `fUI_GOLootAlias.lua`, `fUI_GOLootBootstrap.lua`, `fUI_GOTrade.lua`, `fUI_GOTradeUI.lua`
- LootIt: consolidated bootstrap so `fUI_GOLootItHost.lua` loads first and owns `LI.ADDON` + `[FGO]` prefix.
- Cleanup: removed unused `fUI_GOLootItNS.lua` (ns-bridge).
- Cleanup: removed redundant per-file `fr0z3nUI_LootIt = LI` bootstrapping; LootIt modules now depend on Host and avoid side effects.

# 2026.03.16.04
- Files: `fr0z3nUI_GameOptions.lua`, `fUI_GOTexturesUI.lua`, `fUI_GOLootBootstrap.lua`, `fUI_GOLootItHost.lua`, `fr0z3nUI_GameOptions.toc`
- UI: promoted LootIt’s former internal tabs to native FGO tabs: `LootIt`, `Tax`, `Trade`.
- UI: Mail config is now a `Mail` button popout on the `Textures` tab (no separate LootIt config window / nested tabs).
- Compat: LootIt’s existing `CreateConfigUI()` / `SelectTab("mail")` calls now route into the FGO window + Mail popout.
- Cleanup: removed `fUI_GOLootItUI.lua` (UI shim now lives in `fUI_GOLootBootstrap.lua`).

# 2026.03.16.02
- Files: `fr0z3nUI_GameOptions.lua`, `fr0z3nUI_GameOptions.toc`, `fUI_GOLootItHost.lua`, `fUI_GOLootBootstrap.lua`, `fUI_GOLootUIV.lua`, `fUI_GOLoot.lua`, `fUI_GOLootAlias.lua`, `fUI_GOLootChat.lua`, `fUI_GOTrade.lua`, `fUI_GOTextureMail.lua`
- Slash: removed LootIt’s `/fli` registration from the FGO build; LootIt is now driven by the native `/fgo` router.
- Slash: added `/fgo li ...` (and `/fgo lootit ...` alias) for LootIt commands; avoids collision with existing `/fgo loot` (Auto Loot).
- Output: LootIt host output prefix now shows `[FGO]` so it feels native.

# 2026.03.16.01
- Files: `fr0z3nUI_GameOptions.toc`, `fUI_GOLootIt*.lua`, `fUI_GOLoot*.lua`, `fUI_GOTrade*.lua`, `fUI_GOTax*.lua`, `fUI_GOTextureMail.lua`
- LootIt: hosted inside FGO (modules migrated as `fUI_GO*`; no `fr0z3nUI_LootIt*` wrapper spam).
- Safety: added a double-load guard so enabling standalone LootIt at the same time won’t double-init.

# 2026.03.13.56
- Files: `fUI_GOSwitchesUI.lua`, `fr0z3nUI_GameOptions.toc`
- Switches/UI: moved both columns down by ~0.5 button height.


# 2026.03.13.55
- Files: `fUI_GOSituateUI.lua`, `fr0z3nUI_GameOptions.toc`
- Situate/UI: fixed drag/drop from the Professions/Spellbook UI by resolving cursor `spell` drags (spellbook index + bookType) into a real spellID before writing.


# 2026.03.13.54
- Files: `fUI_GOSituate.lua`, `fUI_GOSituateUI.lua`, `fr0z3nUI_GameOptions.toc`
- Situate: added Midnight zone mapID fallbacks so Expansion resolves to `midnight` in Quel'Thalas/Midnight zones even before continent/root mapIDs are confirmed.


# 2026.03.13.53
- Files: `fUI_GOSituate.lua`, `fUI_GOSituateUI.lua`, `fr0z3nUI_GameOptions.lua`, `fr0z3nUI_GameOptions.toc`
- Situate: expansion detection now resolves by matching known continent mapIDs anywhere in the map parent chain (less dependent on `mapType`).
- Slash: added `/fgo situate info` to print map ancestry + resolved expansion key + cached profession keys for debugging.


# 2026.03.13.52
- Files: `fUI_GOSwitchesUI.lua`, `fr0z3nUI_GameOptions.toc`
- Switches/UI: moved both columns up by ~1.5 button heights.


# 2026.03.13.51
- Files: `fUI_GOSituatePF.lua`, `fUI_GOSituate.lua`, `fUI_GOSituateUI.lua`, `fr0z3nUI_GameOptions.toc`
- Situate: Expansion detection now prefers continent `mapID` mapping (locale-independent), fixing the `Expansion` button showing Unknown on non-English clients.
- SituatePF: avoid caching an all-nil `GetProfessions()` result as "no professions" on first refresh; Profession button now sees the character's professions once skills are loaded.
- Situate/UI: Profession list refresh now forces a profession-key refresh when opening/using the account Profession selector.


# 2026.03.13.50
- Files: `fUI_GOSwitchesUI.lua`, `fUI_GOSwitches.lua`, `fr0z3nUI_GameOptions.lua`, `fr0z3nUI_GameOptions.toc`
- Switches/UI: `Reload Button` now has a split click zone; the right 1/3 cycles the floating button font size (12/14/16/18/20).
- Floating Reload UI: applies the saved font size via `AutoGossip_UI.reloadFloatTextSize`.


# 2026.03.13.49
- Files: `fUI_GOTalkUI.lua`, `fr0z3nUI_GameOptions.toc`
- Talk tab: after reload/login, the rules tree now starts fully collapsed (no persisted expansion state across sessions).


# 2026.03.13.48
- Files: `fUI_GOSwitchesUI.lua`, `fr0z3nUI_GameOptions.toc`
- Switches/UI: move `Tooltip Border` above `TooltipX Module`.
- Switches/UI: reorder top segments to Chromie -> Mount Up -> Pet Walk, with the remaining buttons below.


# 2026.03.13.47
- Files: `fUI_GOSwitchesUI.lua`, `fUI_GOSwitchesBP.lua`, `fr0z3nUI_GameOptions.toc`
- Pet Walk: change the character segment to an MU-style `Enable` indicator (green when enabled; uses inverted legacy `petWalkDisabledChar`).
- Pet Walk: add a floating `Pet Walk` button (OSD) with Lock support; when locked, right-click dismisses the current pet.
- Pet Walk Config: add OSD/Lock split, Input (text size), and XY (Acc/Char) position toggle.


# 2026.03.13.46
- Files: `fr0z3nUI_GameOptions.lua`, `fr0z3nUI_GameOptions.toc`
- Mount Up: make the `Mount Up` label use the same blue color as the `[FGO]` prefix in chat output.


# 2026.03.13.45
- Files: `fr0z3nUI_GameOptions.lua`, `fr0z3nUI_GameOptions.toc`
- Mount Up: change per-character status prints to `Mount Up Enabled` (green) / `Mount Up Disabled` (orange).


# 2026.03.13.44
- Files: `fr0z3nUI_GameOptions.lua`, `fr0z3nUI_GameOptions.toc`
- UI: hide Mount Up / Pet Walk / Chromie config popouts when the main `/fgo` window closes.


# 2026.03.13.43
- Files: `fUI_GOSwitchesMU.lua`, `fr0z3nUI_GameOptions.toc`
- Mount Up Config: remove the horizontal gap between the Flying/Ground/Aquatic buttons and the mount name display boxes.


# 2026.03.13.42
- Files: `fUI_GOSwitchesMU.lua`, `fr0z3nUI_GameOptions.toc`
- Mount Up Config: fix scoped preferred mount clear (0) incorrectly falling back to legacy preferred mount IDs; once a scope+slot is "touched", 0 is treated as authoritative.


# 2026.03.13.41
- Files: `fUI_GOSwitchesMU.lua`, `fr0z3nUI_GameOptions.toc`
- Mount Up Config: MU DBG now prints a read-back of the stored preferred mountID after set/clear, to distinguish storage/scope issues from UI refresh issues.


# 2026.03.13.40
- Files: `fUI_GOSwitchesMU.lua`, `fr0z3nUI_GameOptions.toc`
- Mount Up Config: add a `DBG` toggle and click logging for the Flying/Ground/Aquatic preferred buttons to diagnose click interception vs handler early-returns.


# 2026.03.13.39
- Files: `fUI_GOSwitchesMU.lua`, `fr0z3nUI_GameOptions.toc`
- Mount Up Config: remove hover highlight from the preferred mount name boxes and add hover highlight to the Flying/Ground/Aquatic buttons.


# 2026.03.13.38
- Files: `fUI_GOSwitchesMU.lua`, `fr0z3nUI_GameOptions.toc`
- Mount Up Config: ensure the top (Flying) row stays clickable by raising the rows container frame level so header/scope UI cannot overlap it.


# 2026.03.13.37
- Files: `fUI_GOSwitchesMU.lua`, `fr0z3nUI_GameOptions.toc`
- Mount Up Config: fix Flying preferred button by resolving the mounted mountID via Mount Journal "active" state (aura-based detection could fail for some mounts).
- Reverted the previous mouse-up click hardening and the extra chat prints.


# 2026.03.13.35
- Files: `fUI_GOSwitchesMU.lua`, `fr0z3nUI_GameOptions.toc`
- Mount Up Config: fix right-click clear on the Flying/Ground/Aquatic buttons so it no longer silently no-ops due to scope target checks.



# 2026.03.13.34
- Files: `fUI_GOSwitchesMU.lua`, `fr0z3nUI_GameOptions.toc`
- Mount Up Config: shorten the Flying/Ground/Aquatic buttons by ~1/3 and let the mount name display boxes use the extra width.


# 2026.03.13.33
- Files: `fUI_GOSwitchesMU.lua`, `fr0z3nUI_GameOptions.toc`
- Mount Up Config: when setting preferred mounts from the Flying/Ground/Aquatic buttons, validate the current mount type matches the row (and print a short reason if it can't set), so the Flying slot can't be accidentally set from a ground mount.


# 2026.03.13.32
- Files: `fUI_GOSwitchesMU.lua`, `fr0z3nUI_GameOptions.toc`
- Mount Up Config: simplify the scope target line to show only the plain name (faction/guild/class/race/character) with no realm, keys, or prefixes.


# 2026.03.13.31
- Files: `fUI_GOSwitchesMU.lua`, `fr0z3nUI_GameOptions.lua`, `fr0z3nUI_GameOptions.toc`
- Mount Up Config: add a read-only scope target line under the Preferred Scope selector (ex: `GUILD: Area 52::MyGuild`).
- Mount Up: automatic one-time migration helper to seed the current scope from legacy `mountUpPreferredMountID*Acc` (does not override a user-set Random/Favorite).
- Debug: add `/fgo mu preferred` to print current Preferred Scope + the three resolved preferred mountIDs + mount names.
- Mount Up Config: if a preferred mount is currently not usable/collected, show the mount line in orange and add a tooltip reason; Mount Up falls back to Random/Favorite.


# 2026.03.13.30
- Files: `fUI_GOSwitchesMU.lua`, `fr0z3nUI_GameOptions.lua`, `fr0z3nUI_GameOptions.toc`
- Mount Up Config: shrink OSD text-size input box and add an `XY` toggle next to it.
- Mount Up float position: `XY` ON (default) saves position account-wide outside Preferred Scope; `XY` OFF saves position per Preferred Scope.
- Mount Up float position: when `XY` is OFF and a scope has no saved position yet, it seeds by copying the current Account position into that scope.


# 2026.03.13.29
- Files: `fUI_GOSwitchesMU.lua`, `fr0z3nUI_GameOptions.lua`, `fr0z3nUI_GameOptions.toc`
- Mount Up Config: add a top Preferred Scope selector button (FACTION/GUILD/CLASS/RACE/CHARACTER), styled like LootIt Tax's Guild/Character scope button.
- Mount Up: preferred Flying/Ground/Aquatic mounts are now stored per selected scope (account-wide for faction/guild/class/race; per-character for character).
- Mount Up Config: move the Flying/Ground/Aquatic rows into the vertical middle of the popout.


# 2026.03.13.28
- Files: `fUI_GOSwitchesMU.lua`, `fUI_GOSwitchesBP.lua`, `fUI_GOSwitchesCT.lua`, `fr0z3nUI_GameOptions.toc`
- Config popouts: dock to the main window and remove the visible gap between frames.


# 2026.03.13.27
- Files: `fUI_GOSwitchesMU.lua`, `fUI_GOSwitchesBP.lua`, `fUI_GOSwitchesCT.lua`, `fr0z3nUI_GameOptions.toc`
- Config popouts: rebuild frames on `BackdropTemplate` (same base as the main window) instead of reskinned `BasicFrameTemplateWithInset`.


# 2026.03.13.26
- Files: `fUI_GOSwitchesMU.lua`, `fUI_GOSwitchesBP.lua`, `fUI_GOSwitchesCT.lua`, `fr0z3nUI_GameOptions.toc`
- Config popouts: add the same top title-bar background strip used by the main GameOptions window (more consistent look).


# 2026.03.13.25
- Files: `fUI_GOSwitchesMU.lua`, `fr0z3nUI_GameOptions.toc`
- Mount Up Config: move Delay control to the bottom of the window.


# 2026.03.13.24
- Files: `fUI_GOSwitchesMU.lua`, `fr0z3nUI_GameOptions.toc`
- Mount Up picker: add `mountTypeID=437` back as Flying (alongside `424` and `402`).


# 2026.03.13.23
- Files: `fUI_GOSwitchesMU.lua`, `fr0z3nUI_GameOptions.toc`
- Mount Up picker: restrict the hard Flying mapping to `mountTypeID=424` (keep `402` as flying); remove `437` from flying mapping.


# 2026.03.13.22
- Files: `fUI_GOSwitchesMU.lua`, `fr0z3nUI_GameOptions.toc`
- Mount Up picker: add hard mountTypeID mappings observed on your client (Ground=284; Flying=424) so strict flying selection works without heuristics.


# 2026.03.13.21
- Files: `fUI_GOSwitchesMU.lua`, `fr0z3nUI_GameOptions.toc`
- Mount Up picker: mountType classification now uses the same hard ID mapping as Dugi (230 ground, 248 flying, 402 adv flying, 231/232/254 aquatic) and no longer treats unknown/"other" mount types as flying candidates.


# 2026.03.13.20
- Files: `fUI_GOSwitchesMU.lua`, `fr0z3nUI_GameOptions.lua`, `fr0z3nUI_GameOptions.toc`
- Slash: add `/fgo mu types` and `/fgo mu mounted` debug helpers to dump mountTypeIDs from your client (to replace heuristics with hard mappings).


# 2026.03.13.19
- Files: `fUI_GOSwitchesMU.lua`, `fr0z3nUI_GameOptions.toc`
- Mount Up picker: when desired type is Flying, treat unknown/"other" mountTypeIDs as flying candidates (prevents false Ground fallback in flyable zones).


# 2026.03.13.18
- Files: `fUI_GOSwitchesMU.lua`, `fr0z3nUI_GameOptions.toc`
- Mount Up picker: Dugis-style flyable behavior — if the area is flyable, attempt Flying first; only fall back to Ground if no usable flying candidates exist.


# 2026.03.13.17
- Files: `fUI_GOSwitchesMU.lua`, `fUI_GOSwitchesBP.lua`, `fUI_GOSwitchesCT.lua`, `fr0z3nUI_GameOptions.toc`
- Config popouts: enforce that Pet Walk / Mount Up / Chromie config windows auto-close each other on open (prevents stacking).


# 2026.03.13.16
- Files: `fUI_GOSwitchesMU.lua`, `fr0z3nUI_GameOptions.toc`
- Mount Up Config: convert OSD/Lock into a true single split button (one frame; left/right click zones), sized like Reload UI (90x18).


# 2026.03.13.15
- Files: `fUI_GOSwitchesMU.lua`, `fr0z3nUI_GameOptions.toc`
- Mount Up Config: fix Flying/Ground/Aquatic buttons not responding by explicitly enabling mouse + raising frame levels.


# 2026.03.13.14
- Files: `fUI_GOSwitchesMU.lua`, `fr0z3nUI_GameOptions.toc`
- Mount Up picker: broaden mount type ID mapping (e.g. Flying=248, Aquatic=231/232/254) so strict filtering still finds valid mounts.
- Mount Up picker: only treat a zone as a "flying" situation if at least one usable flying mount exists (prevents no-candidate dead-end).


# 2026.03.13.13
- Files: `fUI_GOSwitchesMU.lua`, `fr0z3nUI_GameOptions.toc`
- Mount Up Config: remove hover highlight from mount-name display fields (display-only).


# 2026.03.13.12
- Files: `fUI_GOSwitches.lua`, `fUI_GOSwitchesMU.lua`, `fr0z3nUI_GameOptions.toc`
- Floating buttons: tooltip titles now include a blue `[FGO]` prefix (`[FGO] Reload UI`, `[FGO] Mount Up`).
- Floating buttons: tooltip line font size reduced by 1pt (applied only while our tooltip is shown).


# 2026.03.13.11
- Files: `fUI_GOSwitchesMU.lua`, `fr0z3nUI_GameOptions.toc`
- Mount Up Config: replace scope cycling + Current/Clear with 3 fixed buttons (Flying/Ground/Aquatic).
- Mount Up Config: left-click sets current mount for that scope; right-click clears back to Random/Favorite.
- Mount Up Config: scope button text is green when a preferred mount is set, yellow when cleared.
- Mount Up Config: mount display is now a long borderless hover-highlight box to the right (font +2).


# 2026.03.13.10

- Files: `fUI_GOSwitchesMU.lua`, `fr0z3nUI_GameOptions.toc`
- Mount Up Config: restore split button label to "OSD" (left segment) per spec.


# 2026.03.13.09
- Files: `fUI_GOSwitchesMU.lua`, `fr0z3nUI_GameOptions.toc`
- Mount Up Config: make Mount Up/Lock split buttons green/grey label style (no "ON/OFF" suffix).
- Bumped TOC `## Version` to `2026.03.13.9`.


# 2026.03.13.08
- Files: `fUI_GOSwitchesMU.lua`, `fr0z3nUI_GameOptions.toc`
- Mount Up Config: rename the floating-button toggle segment from "OSD" to "Mount Up" (still a split Mount Up/Lock row).
- Bumped TOC `## Version` to `2026.03.13.8`.


# 2026.03.13.07
- Files: `fUI_GOSwitchesMU.lua`, `fr0z3nUI_GameOptions.toc`
- Mount Up picker: make Smart selection strict by situation type (Ground picks ground-only; Water picks aquatic-only; Flyable picks flying-only).
- Mount Up picker exception: while grounded, a Flying mount can only be chosen if it is explicitly set as the Ground preferred mount.
- Bumped TOC `## Version` to `2026.03.13.7`.


# 2026.03.13.06
- Files: `fUI_GOSwitchesMU.lua`, `fr0z3nUI_GameOptions.lua`, `fr0z3nUI_GameOptions.toc`
- Mount Up: remove mode-based preferred mount behavior; picker is now always “smart”.
- Mount Up: preferred mounts are now per-situation (Flying/Ground/Water), so a ground preferred won’t be used while swimming.
- Mount Up Config: redesigned popout controls (scope toggle + Current/Clear; OSD/Lock split row; text size + delay editboxes).
- Bumped TOC `## Version` to `2026.03.13.6`.


# 2026.03.13.05
- Files: `fUI_GOSwitchesUI.lua`, `fr0z3nUI_GameOptions.toc`
- Switches/UI: enforce that only one Config popout can be open at a time.
- Bumped TOC `## Version` to `2026.03.13.5`.


# 2026.03.13.04
- Files: `fUI_GOSwitchesUI.lua`, `fUI_GOSwitchesMU.lua`, `fr0z3nUI_GameOptions.lua`, `fr0z3nUI_GameOptions.toc`
- Switches/UI: Config segments now toggle popouts open/closed (Pet Walk / Mount Up / Chromie).
- Mount Up: added a floating "Mount Up" button (text-only like Reload UI float) controlled from the Mount Up config popout.
- Mount Up float: left-click toggles per-character Enable; right-drag moves only when unlocked; tooltip drag hint only shows when unlocked.
- Mount Up float colors: green (char enabled), orange (char disabled), red (account disabled; left-click disabled; tooltip points to `/fgo mu acc`).
- Bumped TOC `## Version` to `2026.03.13.4`.


# 2026.03.13.03
- Files: `fUI_GOSwitchesUI.lua`, `fr0z3nUI_GameOptions.lua`, `fr0z3nUI_GameOptions.toc`
- Switches/UI: keep the on-screen label as "Mount Up" (no "(Acc)" suffix); still controls account toggle.
- Slash: replaced Mount Up controls with `/fgo mu acc|on|son|off|soff|sw` (Account toggle + per-character Enable with silent variants).
- Slash: remapped `/fgo mountupon` + `/fgo mountupoff` as aliases for `/fgo mu on` + `/fgo mu off`.
- Slash: removed the old `/fgo mountupconfig` popout behavior (use Config button in Switches UI).
- Bumped TOC `## Version` to `2026.03.13.3`.


# 2026.03.13.02
- Files: `fUI_GOSwitchesMU.lua`, `fr0z3nUI_GameOptions.lua`, `fr0z3nUI_GameOptions.toc`
- Mount Up: treat dragonriding as regular flying (Skyriding era).
- Slash: added `/fgo mountup`, `/fgo mountupon`, `/fgo mountupoff`, `/fgo mountupconfig`.
- Bumped TOC `## Version` to `2026.03.13.2`.


# 2026.03.13.01
- Files: `fUI_GOSwitchesMU.lua`, `fUI_GOSwitchesUI.lua`, `fr0z3nUI_GameOptions.lua`, `fr0z3nUI_GameOptions.toc`
- Switches/UI: added "Mount Up" segmented controls (Mount Up ACC toggle, per-character Disable, Config popout).
- Mount Up: added an event-driven auto-mount helper (Smart/Favorites/Specific; delay; preferred mount via "Use Current Mount").
- Bumped TOC `## Version` to `2026.03.13.1`.


# 2026.03.12.13
- Files: `fUI_GOSituate.lua`, `fUI_GOSituateUI.lua`, `fUI_GOSituatePF.lua`, `fr0z3nUI_GameOptions.toc`
- Situate: Profession scope now reads the shared per-character cached `knownProfessionKeys` (same source as gossip hints), with fallback to direct API probing if cache is unknown.
- Situate: expands `GetProfessions()` handling to up to 5 indices on the fallback path.


# 2026.03.12.12
- Files: `fUI_GOSituatePF.lua`, `fr0z3nUI_GameOptions.toc`
- Profs: add stable profession key detection for Archaeology (skillLineID 794) so `Prof:Archaeology`-style hints can work.
- Profs: Archaeology has no expansion-tier categoryIDs in our reference, so it tracks as a profession key only.


# 2026.03.12.11
- Files: `fUI_GOSituatePF.lua`, `fr0z3nUI_GameOptions.toc`
- Profs: expanded tier maps to include Cooking/Fishing/Skinning (and Riding) and detect up to 5 `GetProfessions()` returns.
- Profs: dynamic tier refresh now covers expansion tiers for secondary professions too (so “DF Fishing/Cooking/etc” works for any user).


# 2026.03.12.10
- Files: `fUI_GOSituatePF.lua`, `fr0z3nUI_GameOptions.toc`
- Profs: profession keys are now stored using stable skillLineIDs (locale-safe) instead of localized names.
- Profs: automatically refresh/cache all expansion-tier categoryIDs for the character's known professions (e.g., Dragon Isles Mining) so this works for any user.


# 2026.03.12.09
- Files: `fUI_GOSituatePF.lua`, `fr0z3nUI_GameOptions.toc`
- Profs: treat an empty `GetProfessions()` result as authoritative once player context is ready (lets `Prof:*` hints fire on characters with no professions yet).


# 2026.03.12.08
- Files: `fUI_GOTalkUP.lua`, `fUI_GOSituatePF.lua`, `fr0z3nUI_GameOptions.toc`
- Profs: cache a per-character set of known base professions (e.g., "Mining") so hints can be profession-specific.
- Gossip/Talk: support robust profession-based hint checks via `print = { profession = "Mining", msg = "Train Mining" }` or `print = "Prof:Mining"`.


# 2026.03.12.07
- Files: `fUI_GOTalkUP.lua`, `fUI_GOSituatePF.lua`, `fr0z3nUI_GameOptions.toc`
- Gossip/Talk: hint printing no longer calls professions APIs directly; it reads the cached tier state only.
- Gossip/Talk: if the tier state is unknown/not cached (`nil`), the hint is suppressed (prevents false reminders during early frames).
- Profs: added `Profs.GetCachedTier(categoryID)` helper (cache-only, no probing).


# 2026.03.12.06
- Files: `fUI_GOTalkUP.lua`, `fUI_GOTalk01EK.lua`, `fr0z3nUI_GameOptions.toc`
- Gossip/Talk: removed the Midnight Cooking/Fishing `Knows*`/memo gating from the EK trainer rules (no more profession checks during rule evaluation).
- Gossip/Talk: added per-rule selection-time hints via `print = "MidnightFishing"` / `print = "MidnightCooking"` that print a reminder only if you don't know the tier.


# 2026.03.12.05
- Files: `fUI_GOTalk.lua`, `fUI_GOTalk01EK.lua`, `fr0z3nUI_GameOptions.toc`
- Gossip/Talk: restored opt-in quest gating via `NPC.__meta.stopIfQuestAvailable/stopIfQuestTurnIn` so trainer/options don't auto-fire while a specified quest is being picked up / turned in.
- Talk DB: restored Drathen (253468) gating for `Fishy Dis-pondencies` (92869).


# 2026.03.12.03
- Files: `fUI_GOTalk.lua`, `fr0z3nUI_GameOptions.toc`
- Gossip auto-select: fix intermittent "rule matches but doesn't fire" by changing the repeat-selection loop guard to allow a small retry burst when the client ignores the first selection.

## 260312-003
- Gossip/Talk: let scheduled retries bypass the 0.25s debounce (prevents “debug makes it work” timing issues when the first select is ignored).


## 260312-002
- Gossip/Talk: treat missing `C_GossipInfo` selection APIs as retryable (`why=no-api`) so auto-select doesn’t depend on debug-print timing.


## 260312-001
- Gossip/Talk: add a silent first-run post-select confirm+retry (fixes auto-select working only when debug printing is enabled).


## 260311-006
- Gossip/Talk: removed the `DeclineQuest()` cooldown tracking/blocking (Zygor-style).


## 260311-005
- Gossip/Talk: force-initialize gossip engine state on gossip open (pre-arms timestamps/first-run flags) so first-run doesn’t fail.


## 260311-004
- Gossip/Talk: moved the gossip auto-select engine + print helpers into `fUI_GOTalk.lua` (core now delegates).
- Gossip/Talk: hardened the auto-select debounce timers so first-run can’t error on nil timestamps.


## 260311-003
- Gossip/Talk: reverted the quest-style gossip entry handling (active/available quests in the auto-select list) and removed the related quest-based option-blocking; this stops pet-battle gossips getting interfered with again.


## 260311-002
- Switches/Chromie: hide the floating Chromie Time indicator when you're in Present Time (only shows while Chromie Time is active).


## 260311-001
- Gossip/Talk: removed the `InCombatLockdown()` gate for auto-select attempts (Zygor-style; lets us see what the client allows/blocks in combat).
- Gossip/Talk: added a 10s cooldown after `DeclineQuest()` to prevent immediate re-automation loops.


## 260310-013
- Switches/UI: added Pet Walk controls above Chromie (Pet Walk ACC toggle, per-character Disable, Config popout).
- Pet Walk: added a lightweight battle-pet keeper implementation (random/favorites/specific; safe resummon triggers).


## 260310-012
- Macros/Slash: renamed `/fgo cmove` -> `/fgo clickmove` (same Click2Move toggle).


## 260310-011
- Macros/Slash: added `/fgo cmove` to toggle Click2Move (`autointeract`).


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
