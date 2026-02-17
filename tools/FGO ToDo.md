## FGO ADDON TO DO LIST
- When a task is COMPLETED change the - to a +
- Do not remove anything from the list

```diff

# REMINDERS

- Heads down and do the - tasks
- tasks marked + are ones you have already completed and you makred +
- i'll check when ALL are completed!
- Always remember backup before extra large jobs

*holds your hand* since its seems like thats what you need

# GUI

+   - Move Tale and Talk tabs to the last position
+   - Change "XCMD" to Macro CMD

# Macros

+   - Why does this tab feel like its been reverted...
+       - Alliance and Horde buttons at the top that were hidden are back (along with Click At Home text)
+       - + Friend button is back at the bottom (active outside the zones)
+       - Location box is moved down 
+       - Location box entries have Create Macro instead of M
-   - 

# Macro CMD

+   - move /fgo m and the input box up
+       - shorten the input box by half 
+   - move the commands box up to align with the above move (extending it to above the Reload UI button)
+   - move the Add Del buttons up in line with the /fgo m and input box
+   - divide the space from the input box to the reload ui button between the 3 boxes with a slight gap between each
+   - change the 3 input box Ghost names to being ghost titles BEHIND the MIDDLE of the box not in the box at all

# Situate

+   - sitiate select slot button is not picking up Bartender bars to click on...
+   - make the placements window more like the Talk table
+       - use 01-09 not just 1-9
+       - indenting and more flare, its just boring

# Switches (Toggles)

+   - 

# Tale (Edit/Add / Gossip)

-   - 

# Talk (Rules / Gossiping)

-   - 

```
# Addon File Structure  NYI                    
```diff

# fr0z3nUI_GameOptions.lua  (Core)
# fr0z3nUI_GameOptions.toc  (Starter)
-   - Rename files,  ignore (),  once files renamed change their - to #
- fUI_GOMacros.lua          ()
- fUI_GOMacroHearth.lua     ()
- fUI_GOMacroHome.lua       ()
- fUI_GOMacroXCMD.lua       ()
- fUI_GOMacroXCMDUI.lua     ()
- fUI_GOSituate.lua         ()
- fUI_GOSituateUI.lua       ()
- fUI_GOSwitches.lua        ()
- fUI_GOSwitchesUI.lua      ()
- fUI_GOTale.lua            ()
- fUI_GOTaleUI.lua          ()
- fUI_GOTalk.lua            ()
- fUI_GOTalkUI.lua          ()
- fUI_GOTalkXP01EK.lua      (Eastern Kingdoms)
- fUI_GOTalkXP01KD.lua      (Kalimdor)
- fUI_GOTalkXP02.lua        (Outland)
- fUI_GOTalkXP03.lua        (Northrend)
- fUI_GOTalkXP04.lua        (Maelstrom)
- fUI_GOTalkXP05.lua        (Pandaria)
- fUI_GOTalkXP06.lua        (Draenor)
- fUI_GOTalkXP07.lua        (Broken Isles)
- fUI_GOTalkXP08KT.lua      (Kul Tiras)
- fUI_GOTalkXP08ZL.lua      (Zandalar)
- fUI_GOTalkXP09.lua        (Shadowlands)
- fUI_GOTalkXP10.lua        (Dragon Isles)
- fUI_GOTalkXP11.lua        (Khaz Algar)
- fUI_GOTalkXP12.lua        (??)
- fUI_GOTalkXPEV.lua        (Event Zones)
- fUI_GOTalkXPOP.lua        (Popup Picker)


```
## REMINDER FOR USER ONLY BELOW THIS LINE DO NOT READ BEYOND THIS POINT

- Macro simplification (FAO Macros)

rename all files from fr0z3nUI_GameOptions... to FUIGO... except the main fr0z3nUI_GameOptions.lua/toc files


1. Tale & Talk
Tale (Tab 1): The "Creation" tab. In WoW, you are essentially writing the "Tale" or the gossip entry here.
Talk (Tab 2): The "Display" tab. This is where the gossip is actually "spoken" or viewed.
Alphabetical: Switches → Tale → Talk
2. Tattle & Tome
Tattle (Tab 1): The "Creation" tab. This is where you input the gossip or "tattle" on others.
Tome (Tab 2): The "Display" tab. This acts as the library or Tome where all the entries are stored and read.
Alphabetical: Switches → Tattle → Tome
3. Tongue & Transcript
Tongue (Tab 1): The "Creation" tab. Refers to the language or "voice" you are giving the gossip.
Transcript (Tab 2): The "Display" tab. A clean, technical name for the list of recorded entries.
Alphabetical: Switches → Tongue → Transcript





