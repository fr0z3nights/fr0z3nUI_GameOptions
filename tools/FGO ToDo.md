## FGO ADDON TO DO LIST
- When a task is COMPLETED change the - to a +
- Do not remove anything from the list

```diff

# GUI

+   - Remove "GameOptions" from title
+   - Rename "Edit/Add" to "Gossip"
+   - Rename "Rules" to "Gossiping"
+   - Rename "Macro /" to "Macros /"
+   - Rename "ActionBar" to "Situate" (files ActionBar/UI to Situate/UI)
+   - Reorder:  Gossip | Gossiping | Macros | Macros / | Situate | Toggles
+   - 

# Gossip (Edit/Add)

+   - 
+   - 
+   - 

# Gossip Rules (Rules)

+   - 
+   - 
+   - 

# Macros

+   - Move Script Errors button to the right of Rez Combat button
+   - Move HS Hearth and the text box next to it down to where script errors was
+   - Move HS O6 Garrison / HS 07 Dalaran / HS 11 Dornogal / HS 78 Whistle under the buttons below them
+   - Reimpliment the button height spacing between rows/columns of buttons (pushing buttons up from the bottom)
+   - Rename "Macro Scope: Account/Character" button to "Account/Character Macro"
+   - Move the Account/Character Macro button to the Left side of the macro buttons
+       - in line with the gap under the Instance IO button
+   - Move everything on the Home tab to the empty space at the top of the Macros tab and put a seperator line under it
+   - Remove the Home tab once its empty

# Macros /

+   - Remove "Macro /" title
+   - Remove "Create /fgo m <comman..." text
+   - Remove "Entry" text
+   - make the input windows usable...
+   - command input boxmove the input box to the top corner
+       - move to the top corner
+       - remove border, increase height
+       - remove "Command" and "Usage: /fgo m *" texts
+       - add Ghost text enter command name
+       - the "/fgo m " part is added by the addon (appears in commands window as /fgo m <commandname>)
+   - move the commands window to the right side and up, extending it to the bottom
+   - move the other winsows to the left
+       -remove the titles
+       - add Ghost Test in the boxes
+           - CHARACTERS | CHARACTERS MACRO | OTHERS MACRO (centered/lerger/caps/persistant)
+       - divide the spae between the tab row and bottom evenly between the 3 boxes
+           - small gap between each frame
+           - leave space at the bottom (size of an imaginary reload button on that side too)

# Situate

+   - remove "ActionBar" text
+   - move "Place macro..." text to the center under the tab bar
+   - Rename "Use Hover Slot" "Hover Slot", move to bottom left corner, add tooltip
+   - Rename "Detector: On/Off" to "Detector" yellow/grey text, move next to Hover Slot
+   - Rename "Enabled: On/Off Acc" "Enabled" yellow/grey text, tooltip, top Left corner under the tab bar
+   - Rename "Overwrite .." to "Overwrite" yellow/grey text, tooltip, move next to Detector
+   - rename "Debug..." to "Debug" yellow/grey text, tooltip, move next to Reload UI
+   - cant see the button unnder per-char: button but move that to the bottom too
+   - remove "entry" text
+   - move placements window to the right size, move up and extend down
+   - move everything that was left over on the right to the left and up
+   - think this window is wrong, but we'll figure that out later
+   - 

# Toggles

+   - Split the screen in 2 (figuretimvely)
+       - all TooltipX toggles centred on the left
+       - all other toggles centred on the right

```
# Addon File Structure  NYI                    
```diff

# fr0z3nUI_GameOptions.lua (Core)
# fr0z3nUI_GameOptions.toc (Starter)
# fr0z3nUI_GameOptions.lua ()

```
## REMINDER FOR USER ONLY BELOW THIS LINE DO NOT READ BEYOND THIS POINT

- Macro simplification (FAO Macros)









