## FGO ADDON TO DO LIST
- When a task is COMPLETED change the - to a +
- Do not remove anything from the list

```diff

# REMINDERS
- DO NOT DO ANYTHING IN THIS LIST UNTIL MARCH 2nd, 2026 QUOTA EXCEEDED
- Heads down and do the - tasks
- tasks marked + are ones you have already completed and you makred +
- i'll check when ALL are completed!
- Always remember backup before extra large jobs

# GUI

+   -

# Macros

-   -   /fgo hs loc is not keeping the set Hearthstone locatin, the first part is right but the part after the,
-           - /run HearthZone:GetZone() at least reports it better (old macros still have it)
-           - Remove the /fgo hs loc cmd stuff, just make it an alt cmd for /run HearthZone:GetZone()
-               - if possible make it "Zone, Continant" instead of the current "Inn Name, Continant"

# Macro CMD

+   -

# Situate

+   -

# Switches (Toggles)

+   - 

# Tale (Edit/Add / Gossip)

+   -

# Talk (Rules / Gossiping)

-   - Link C:\WoW\_retail_\Interface\AddOns\LightskyUniversal in z Library/Helpers (see Adding to Library.md)
-   - Scan z Library/Helpers/ addons for Garrison Mission Table setting that auto completed the initial quest
-       - Add it to my addon with the ability to disable it as an entry in the Talk tab list
-           - make it appear like a normal gossip entry under Draenor then Garrison

# Textures

+   - Remove "Widget:" text
+   - Move widget dropdown to where the widge text was, shorted by 1/4, no border
+   - Move New / Delete / Refresh buttons over next to widget dropdown
+   - move Type: text to under widget dropdown
+   - Move level input box next to type, remove lable, add ghost text "Level", no border
+   - move texture input / pick button to the top in line with widget dropdown
+       - remove label, add ghost text "Texture", no border
+   - remove text
+       - Strata:, move dropdown into its place, shorten by 1/3
+       - Layer/Sub:, move dropdown next to strata's, shorten by 1/3, input box next to it, shorten by 1/2, no border
+       - Blend:, move dropdown under strata's, shorten by 1/3, no border, move "Tip: blend..." next to it
+       - Faction:, change "Both" to "Faction" in dropdown, no border, 
+       - Characters...:, add as ghost text in input box, move to where blend used to be
+   - Change to buttons, Yellow/Grey = On/Off (no on/off text)
+       - Enabled tickbox "Widget", default on
+       - Clickthrough "Click", tooltip, move next to Widget, default on
+       - Unlock, "Unlock", remove text, tooltip, move next to Click, default off
+       - Combat, 3stage toggle "Off"(grey)/"In Combat"(red)/"No Combat"(yellow), move below Widget, default off
+       - Remove "Has Mail"  as its not needed since i have a mail notifier elsewhere
+       - Hide when quest complete "Quest", move next to Combat
+           - with its input box, shorten (7 characters), no border, ghost text "QuestID"
+   - Characters box is not interactable
+   - Explain what Seen/ignore realm tickboxes do and the entry box between them
-   - 

```
# Addon File Structure  NYI                    
```diff

# fr0z3nUI_GameOptions.lua  (Core)
# fr0z3nUI_GameOptions.toc  (Starter)
# fUI_GOMacros.lua          ()
# fUI_GOMacroHearth.lua     ()
# fUI_GOMacroHome.lua       ()
# fUI_GOMacroXCMD.lua       ()
# fUI_GOMacroXCMDUI.lua     ()
# fUI_GOSituate.lua         ()
# fUI_GOSituateUI.lua       ()
# fUI_GOSwitches.lua        ()
# fUI_GOSwitchesUI.lua      ()
# fUI_GOTale.lua            ()
# fUI_GOTaleUI.lua          ()
# fUI_GOTalk.lua            ()
# fUI_GOTalkUI.lua          ()
# fUI_GOTalk01EK.lua      (Eastern Kingdoms)
# fUI_GOTalk01KD.lua      (Kalimdor)
# fUI_GOTalk02.lua        (Outland)
# fUI_GOTalk03.lua        (Northrend)
# fUI_GOTalk04.lua        (Maelstrom)
# fUI_GOTalk05.lua        (Pandaria)
# fUI_GOTalk06.lua        (Draenor)
# fUI_GOTalk07.lua        (Broken Isles)
# fUI_GOTalk08KT.lua      (Kul Tiras)
# fUI_GOTalk08ZL.lua      (Zandalar)
# fUI_GOTalk09.lua        (Shadowlands)
# fUI_GOTalk10.lua        (Dragon Isles)
# fUI_GOTalk11.lua        (Khaz Algar)
# fUI_GOTalk12.lua        (??)
# fUI_GOTalkEV.lua        (Event Zones)
# fUI_GOTalkUP.lua        (Popup Picker)


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




