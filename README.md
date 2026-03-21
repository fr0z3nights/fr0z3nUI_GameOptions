# fr0z3nUI GameOptions (FGO)

FGO is a personal “toolbox” addon: one window that collects a bunch of small quality-of-life helpers (toggles, loot/chat cleanup, gossip helpers, macro helpers, bank/trade helpers, tax tracking, and a few small utilities).

The whole point is the GUI. You can ignore slash commands entirely if you want — they’re mostly just shortcuts.

## Install
1. Copy the folder `fr0z3nUI_GameOptions` into:
	- `World of Warcraft/_retail_/Interface/AddOns/`
2. Launch WoW and enable the addon.

## Quick Start (the 60-second version)
1. Open the window: `/fgo`
2. Go to **Switches** and turn on only what you actually want.
3. If you want cleaner loot/money chat: open **Loot** and set it up.
4. If you want gossip auto-select rules: open **Tale** (build rules) and **Talk** (browse/manage rules).

## Reading The Button States (ACC vs CHAR)
FGO uses two common scopes:
- **ACC** = account-wide (applies to all characters)
- **CHAR** = per-character (only this character)

On the **Switches** tab you’ll see this in the button text:
- `ON ACC / OFF ACC` means the account-wide master toggle.
- Some features have **segmented buttons** like `Feature | Enable | Config`:
	- `Feature` is usually the **ACC master**.
	- `Enable` is the **per-character enable/override**.
	- `Config` opens a small popout window for options.

## UI Guide (Tabs)

### Switches (Quick Toggles)
This tab is the “turn stuff on/off without hunting in Blizzard menus” page.

**Right column (general helpers):**
- **Queue Accept** (cycles `ACC ON` → `ON` → `OFF`)
	- When enabled, if a dungeon queue pops, **clicking the world** will accept.
	- Clicking other UI elements should not accept.
- **Pet Popup Debug** (`ON ACC` / `OFF ACC`)
	- Logs StaticPopup dialogs so you can identify what’s firing.
- **Pet Battle** (`ON ACC` / `OFF ACC`)
	- Auto-accepts the pet battle confirmation popup.

**Right column (segmented feature rows):**
- **Chromie | Lock | Config**
	- `Chromie` = shows the on-screen Chromie indicator when available (`ON ACC` / `OFF ACC`).
	- `Lock` = locks dragging for this character (`ON CHAR` / `OFF CHAR`).
	- `Config` = edits the indicator frame style.
- **Mount Up | Enable | Config**
	- `Mount Up` = account master toggle (`ON ACC` / `OFF ACC`).
	- `Enable` = enables/disables Mount Up on this character.
	- `Config` = opens Mount Up options.
- **Pet Walk | Enable | Config**
	- `Pet Walk` = account master toggle (tries to keep a battle pet summoned).
	- `Enable` = enables/disables Pet Walk on this character.
	- `Config` = opens Pet Walk options.
- **Mail | Enable | Config** (Mail Notifier)
	- `Mail` = account master toggle.
	- `Enable` = per-character override (wins over the ACC value).
	- `Config` = opens the Mail Notifier popout.

**Right column (small utilities):**
- **Reload Button** (`ON ACC` / `OFF ACC` + a size in parentheses)
	- Click normally to enable/disable the floating Reload UI button.
	- Click the **right third** of the button to cycle font sizes.
- **Tutorials** (`ON ACC` / `OFF ACC`)
	- ON attempts to keep tutorials enabled; OFF applies HideTutorial logic.

**Left column (Tooltip controls + TooltipX):**
- **Tooltip Border** (`HIDE ACC` / `OFF ACC`)
	- HIDE hides tooltip borders.
	- OFF stops forcing hide (it does not restore borders).
- **TooltipX Module** (`ON ACC` / `OFF ACC`)
	- Master toggle for all TooltipX behavior. Default is OFF.
- **TooltipX Combat Hide** (`ON ACC` / `OFF ACC`)
	- If ON, hides most tooltips while in combat.
- **TooltipX Reveal Key** (cycles `CTRL` → `ALT` → `SHIFT` → `NONE`)
	- Hold this key in combat to show hidden tooltips.
- **TooltipX Show Target / Focus / Mouseover / Friendly**
	- Lets those specific unit tooltips remain visible in combat.
- **TooltipX Cleanup**
	- Hides common quest objective progress lines in tooltips.
	- Cleanup has a **Mode** (`STRICT` / `MORE`) and a **Scope** (`COMBAT` / `ALWAYS`).
- **TooltipX Debug**
	- Prints a short reason when TooltipX hides/cleans a tooltip (throttled).

Tip: if a TooltipX button shows `(disabled)`, enable **TooltipX Module** first.

### Loot (LootIt: Clean Loot/Money Chat)
This tab is where you make loot/money messages less spammy.

Common setup:
1. Use the **Hide/Show** button next to `You receive loot:`
	- `Hide` suppresses Blizzard’s default loot line.
2. Check **Show Loot Only Line**
	- Reprints a simplified loot line (just the item link).
3. Optional: turn on **Quality** and choose **Before/After**
	- Adds the DF+ profession quality icon to some gathered item links.

Other useful controls on this tab:
- **Loot In Line**
	- Set a number > 1 to combine loot spam into one line.
	- `Gold` and `Currency` decide whether those are included in combined lines.
	- `Per` mode toggles `Loot Window` vs `Print Per` combine behavior.
- **Money icons (Gold/Silver/Copper)**
	- Controls which coin denominations are shown when money is printed.
- **Show My Name Always**
	- Forces your name to show in LootIt output.
- **Output** dropdown
	- Picks which chat window LootIt prints to.

Extra popouts (buttons next to **Reset Defaults**):
- **Alias**
	- Opens the **Alias** popout (a side panel) where you can rename item links / currency links, ignore specific items, and delay-print spammy items.
	- Basic workflow:
		1) Click **Alias**.
		2) Use the tiny **I / C** toggle to choose **ItemID** (I) or **CurrencyID** (C).
		3) Paste/enter the ID.
		4) Type your short name.
		5) Click **Account** to save.
	- **Ignore (hide from loot chat)** (items only): hides that item from chat output.
	- **Delay print (sec)** (items only): buffers that item and prints it once after the delay (`0` = off).
	- **Character** is not a “save”: it toggles *disable/enable* for this character (useful if you want an alias generally, but not on one toon).
- **Info**
	- Opens an **Info** popout with example formats (Achievement + Experience) and a scroll list of supported message types.

Other output helpers (under the Reset Defaults row):
- **Achievement** + **Achievement Output**
	- Toggles and routes achievement reprints to a chosen chat window.
- **Experience** + **Experience Output**
	- Toggles and routes XP reprints to a chosen chat window.
	- **Bonus**: show/hide bonus XP in the Experience output.
		- When hidden, an asterisk (`*`) indicates bonus XP was included.
	- **Quest**: hides quest system messages (only reprints ones completed with XP).
	- **XP Label** (`Before` / `After`): toggles whether `XP` prints before or after the number.
- **Professions** + **Profession Output**
	- Toggles and routes profession skill-up reprints to a chosen chat window.

Bottom-left buttons:
- **Debug**
	- Toggles LootIt debug capture.
- **Played**
	- Hides `/played` output lines.

### Tale (Build Rules)
Tale is the “gossip editing” tab (it used to be named Gossip internally). You use it to collect info and create rules.

The three buttons at the bottom are the important ones:
- **Print** (ON/OFF)
	- ON prints the current NPC’s gossip options when the gossip window opens.
- **Print threshold** (the small number box)
	- Minimum option count before Print-on-show fires (default 2).
- **Debug** (ON/OFF)
	- ON prints detailed gossip info and why auto-select did/didn’t fire.

### Talk (Browse/Manage Rules)
Talk is your rules browser.

What you do here:
- Browse all rules (the list area)
- Click a rule to edit its **prio** (priority)
	- Higher prio wins when multiple rules match.
	- The prio editor only appears for rules that are editable (acc/char).

### Situate (Keep Action Bars Consistent)
Situate places existing macros/spells/items (including toys) into specific action bar slots. It’s blocked in combat.

Basic workflow:
1. Use the spec selector (`<` / `>`) to choose which spec layout you’re editing.
2. In **Placements**, click **Add**.
3. Pick a **Slot** (or use “Click an action button to select slot”).
4. Choose what to place:
	- **Macro** / **Spell** / **Item** (or drag-and-drop onto “Drop here”).
5. Click **Apply All** to write everything to the bars.

Convenience buttons:
- **Hover Fill** / **Cursor Fill** help pick targets faster.
- **Remember: ON/OFF** controls whether a picked target is remembered.
- **Assistant** offers guided help for common setups.

### Macro (Macros + Home)
This tab is a “macro helper” page: it stores small snippets and helps you generate common utility macros (including a few built-in ones).

If you just want to add a helper macro without thinking:
- Click **+ Macro** and pick from the list.

### Macro CMD (Named Command Snippets)
Macro CMD is the “data-driven” command list. Think: a library of named snippets you can run.

How to use it:
1. Click the `/fgo x|m|c|d` prefix to cycle modes: `x → m → c → d`.
2. Type a **command name**.
3. Edit the big boxes (the contents depend on mode):
	- `x` mode has Characters + Main/Other text.
	- Other modes store a single command snippet.
4. Use the right-side list:
	- `E` = load/edit
	- `D` = delete
	- `DB` indicates a built-in seed entry.

Note: Macro CMD is for `/run`, `/script`, `/console`, `/print` style commands. Protected actions like `/cast` won’t work here.

### Trade (Deposit / Buy / Sell by ItemID)
Trade is a quick item-by-item helper for bank/trade-vendor style workflows.

Typical use:
1. Click the big mode title to cycle: **Deposit Item** → **Purchase Item** → **Sell Item**.
2. Type an **ItemID** in the box.
3. Use the scope buttons:
	- **Character** / **Realm** / **Account** decide where the rule is stored.

### Tax (Track Dues)
Tax is a bookkeeping tab (guild/loot tax style tracking).

Typical use:
1. Click the scope title to switch between **Guild** and **Character**.
2. Enter your **Tax %**.
3. Use the rest of the panel to track what is due/paid and to pay via supported bank options.

### Tabard
Tabard helper UI.

### Textures
Texture/art helpers and related migrations/debug (mostly for internal UI consistency and art-layer cleanup).

## Optional: Slash Commands (Shortcuts)
You do not need these for normal use, but they’re handy.

- `/fgo` — open/toggle the window
- `/fgo scope` — print the full command index
- `/fgo list` — print current gossip options (NPC + option IDs)
- `/fgo deposit` — run the deposit helper (bank UI must be open)

## SavedVariables
- Account: `AutoGame_Acc`, `AutoGame_Settings`, `AutoGame_UI`
- Character: `AutoGame_Char`, `AutoGame_CharSettings`

## Notes
- FGO tries to avoid unsafe/protected interactions in combat.
