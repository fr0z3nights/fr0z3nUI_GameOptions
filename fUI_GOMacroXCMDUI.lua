---@diagnostic disable: undefined-global

local addonName, ns = ...
if type(ns) ~= "table" then
    ns = {}
end

local function InitSV()
    if ns and type(ns._InitSV) == "function" then
        ns._InitSV()
    end
end

local function GetSettings()
    InitSV()
    local s = rawget(_G, "AutoGame_Settings") or rawget(_G, "AutoGossip_Settings")
    if type(s) ~= "table" then
        return nil
    end
    return s
end

local function EnsureCommandsArray()
    InitSV()
    local s = GetSettings()
    if not s then
        return {}
    end
    if type(s.macroCmdsAcc) ~= "table" then
        s.macroCmdsAcc = {}
    end
    if s.macroCmdsAcc[1] == nil and next(s.macroCmdsAcc) ~= nil then
        s.macroCmdsAcc = {}
    end
    return s.macroCmdsAcc
end

local function NormalizeMode(mode)
    mode = tostring(mode or ""):lower()
    if mode == "" then
        return "x"
    end
    -- Back-compat: old faction mode was 'f' (now merged into 'c').
    if mode == "f" then
        return "c"
    end
    if mode == "x" or mode == "m" or mode == "c" or mode == "d" then
        return mode
    end
    -- Unknown/legacy tags fall under d-mode ("everything else").
    return "d"
end

local function EnsureMode()
    InitSV()
    local s = GetSettings()
    if not s then
        return "x"
    end
    local cur = NormalizeMode(s.macroCmdModeAcc)
    s.macroCmdModeAcc = cur
    return cur
end

local function GetEntryMode(entry)
    if type(entry) ~= "table" then
        return "x"
    end
    local m = entry.mode
    if m == nil or m == "" then
        return "x"
    end
    return NormalizeMode(m)
end

local function Trim(s)
    if type(s) ~= "string" then
        return ""
    end
    return (s:gsub("^%s+", ""):gsub("%s+$", ""))
end

local function HideFauxScrollBarAndEnableWheel(sf, rowHeight)
    if not sf then
        return
    end

    local sb = sf.ScrollBar or sf.scrollBar
    if not sb and sf.GetChildren then
        local n = select("#", sf:GetChildren())
        for i = 1, n do
            local child = select(i, sf:GetChildren())
            if child and child.GetObjectType and child:GetObjectType() == "Slider" then
                sb = child
                break
            end
        end
    end
    sf._fgoScrollBar = sb

    if sb then
        sb:Hide()
        sb.Show = function() end
        if sb.SetAlpha then
            sb:SetAlpha(0)
        end
        if sb.EnableMouse then
            sb:EnableMouse(false)
        end
    end

    if sf.EnableMouseWheel then
        sf:EnableMouseWheel(true)
    end
    sf:SetScript("OnMouseWheel", function(self, delta)
        local bar = self._fgoScrollBar or self.ScrollBar or self.scrollBar
        if not (bar and bar.GetValue and bar.SetValue) then
            return
        end
        local step = rowHeight or 16
        bar:SetValue((bar:GetValue() or 0) - (delta * step))
    end)
end

local function HideScrollBarAndEnableWheel(sf, step)
    if not sf then
        return
    end

    local sb = sf.ScrollBar or sf.scrollBar
    if sb then
        sb:Hide()
        sb.Show = function() end
        if sb.SetAlpha then sb:SetAlpha(0) end
        if sb.EnableMouse then sb:EnableMouse(false) end
    end

    if sf.EnableMouseWheel then
        sf:EnableMouseWheel(true)
    end
    sf:SetScript("OnMouseWheel", function(self, delta)
        local bar = self.ScrollBar or self.scrollBar
        if not (bar and bar.GetValue and bar.SetValue) then
            return
        end
        local cur = bar:GetValue() or 0
        local s = step or 24
        bar:SetValue(cur - (delta * s))
    end)
end

local function SplitLines(text)
    text = tostring(text or "")
    text = text:gsub("\r\n", "\n"):gsub("\r", "\n")
    local out = {}
    for line in text:gmatch("([^\n]*)\n?") do
        if line == "" and #out > 0 and out[#out] == "" then
            -- end
            break
        end
        out[#out + 1] = line
    end
    -- Trim trailing empties
    while #out > 0 and Trim(out[#out]) == "" do
        table.remove(out, #out)
    end
    return out
end

local function JoinLines(lines)
    if type(lines) ~= "table" then
        return ""
    end
    return table.concat(lines, "\n")
end

local function NormalizeKey(s)
    s = tostring(s or "")
    s = s:gsub("^%s+", ""):gsub("%s+$", "")
    return s:lower()
end

local function NormalizeText(text)
    text = tostring(text or "")
    text = text:gsub("\r\n", "\n"):gsub("\r", "\n")
    return text
end

local function BuildBuiltinSeedIndex()
    local idx = {}
    local db = ns and ns.MacroXCMD_DB
    if type(db) ~= "table" then
        return idx
    end

    for _, e in ipairs(db) do
        if type(e) == "table" then
            local m = NormalizeMode(e.mode)
            local k = NormalizeKey(e.key)
            if k ~= "" then
                idx[m] = idx[m] or {}
                -- Keep first occurrence if duplicates exist.
                if not idx[m][k] then
                    idx[m][k] = e
                end
            end
        end
    end
    return idx
end

local function SameList(a, b)
    if type(a) ~= "table" or type(b) ~= "table" then
        return false
    end
    if #a ~= #b then
        return false
    end
    for i = 1, #a do
        local av = Trim(tostring(a[i] or ""))
        local bv = Trim(tostring(b[i] or ""))
        if av ~= bv then
            return false
        end
    end
    return true
end

local function IsEntryUneditedSeed(entry, seedIndex)
    if type(entry) ~= "table" then
        return false
    end
    local emode = GetEntryMode(entry)
    local key = NormalizeKey(entry.key)
    if key == "" then
        return false
    end

    local seed = seedIndex[emode] and seedIndex[emode][key] or nil
    if type(seed) ~= "table" then
        return false
    end

    if emode == "x" then
        local seedMains = seed.mains
        local entryMains = entry.mains
        if type(seedMains) ~= "table" then seedMains = {} end
        if type(entryMains) ~= "table" then entryMains = {} end
        if not SameList(seedMains, entryMains) then
            return false
        end
        if NormalizeText(seed.mainText) ~= NormalizeText(entry.mainText) then
            return false
        end
        if NormalizeText(seed.otherText) ~= NormalizeText(entry.otherText) then
            return false
        end
        return true
    end

    local seedText = seed.text
    if seedText == nil then
        seedText = seed.otherText
    end
    local entryText = entry.otherText
    if Trim(tostring(entryText or "")) == "" then
        entryText = entry.mainText
    end

    return NormalizeText(seedText) == NormalizeText(entryText)
end

local function EnsureDefaultMainsArray()
    local s = GetSettings()
    if not s then
        return {}
    end
    if type(s.macroCmdMainsDefaultAcc) ~= "table" then
        s.macroCmdMainsDefaultAcc = {}
    end
    if s.macroCmdMainsDefaultAcc[1] == nil and next(s.macroCmdMainsDefaultAcc) ~= nil then
        s.macroCmdMainsDefaultAcc = {}
    end
    return s.macroCmdMainsDefaultAcc
end

local function NormalizeLinesText(text)
    text = tostring(text or "")
    text = text:gsub("\r\n", "\n"):gsub("\r", "\n")
    return text
end

local function ValidateMacroCmdText(text)
    text = NormalizeLinesText(text)
    local lines = SplitLines(text)

    local perLine = {}
    local errors = 0
    local warns = 0

    local function add(lineIndex, severity, message)
        if not perLine[lineIndex] then
            perLine[lineIndex] = { severity = severity, messages = { message } }
        else
            local cur = perLine[lineIndex]
            if cur.severity ~= "error" and severity == "error" then
                cur.severity = "error"
            elseif cur.severity == "ok" and severity == "warn" then
                cur.severity = "warn"
            end
            cur.messages[#cur.messages + 1] = message
        end
        if severity == "error" then errors = errors + 1 end
        if severity == "warn" then warns = warns + 1 end
    end

    for i = 1, #lines do
        local line = tostring(lines[i] or "")
        local trimmed = Trim(line)
        if trimmed ~= "" then
            local check = trimmed
            -- Allow class-tagged lines in c-mode style:
            --   [DR] /cancelaura Moonkin Form
            --   @SM /cancelaura Ghost Wolf
            -- (Also accepts full tokens like [DRUID]/@SHAMAN for back-compat.)
            if trimmed:sub(1, 1) == "[" then
                local _, _, _, rest = trimmed:find("^%[([^%]]+)%]%s*(.-)$")
                if rest ~= nil then
                    check = Trim(rest)
                    if check == "" then
                        add(i, "error", "Tagged line is missing macro text after [CLASS].")
                    end
                end
            elseif trimmed:sub(1, 1) == "@" then
                local _, _, _, rest = trimmed:find("^@([%w_]+)%s+(.-)$")
                if rest ~= nil then
                    check = Trim(rest)
                    if check == "" then
                        add(i, "error", "Tagged line is missing macro text after @CLASS.")
                    end
                end
            end

            local lower = tostring(check or ""):lower()

            -- Hard invalid for macro text: non-empty lines must start with '/' or '#'.
            if check ~= "" and check:sub(1, 1) ~= "/" and check:sub(1, 1) ~= "#" then
                add(i, "error", "Line must start with '/' or '#' (macro syntax).")
            else
                -- "Maybe" / informational warnings.
                if lower:find("#showtooltip", 1, true) or lower:find("#show", 1, true) then
                    add(i, "warn", "#show/#showtooltip affects real macro icons/tooltips, not /fgo m execution.")
                end
                if lower:find("/cast", 1, true) == 1 or lower:find("/use", 1, true) == 1 then
                    add(i, "warn", "Casting/using via /fgo m can be blocked in some situations; if it fails, use a normal macro/button.")
                end
                if lower:find("/run ", 1, true) == 1 or lower:find("/script ", 1, true) == 1 then
                    add(i, "warn", "/run and /script can be blocked in some situations (combat/protected).")
                end
                if lower:find("/dugi", 1, true) == 1 then
                    add(i, "warn", "Requires Dugi to be loaded; otherwise the command does nothing.")
                end
                if lower:find("/dejunk", 1, true) == 1 then
                    add(i, "warn", "Requires Dejunk to be loaded; otherwise the command does nothing.")
                end
            end
        end
    end

    local summarySeverity = "ok"
    if errors > 0 then
        summarySeverity = "error"
    elseif warns > 0 then
        summarySeverity = "warn"
    end

    return {
        lines = lines,
        perLine = perLine,
        errors = errors,
        warns = warns,
        severity = summarySeverity,
    }
end

local function BuildColoredDisplayText(v)
    if type(v) ~= "table" or type(v.lines) ~= "table" then
        return ""
    end
    local out = {}
    for i = 1, #v.lines do
        local line = tostring(v.lines[i] or "")
        local info = v.perLine and v.perLine[i]
        if info and info.severity == "error" then
            out[#out + 1] = "|cffff0000" .. line .. "|r"
        elseif info and info.severity == "warn" then
            out[#out + 1] = "|cffffff00" .. line .. "|r"
        else
            out[#out + 1] = line
        end
    end
    return table.concat(out, "\n")
end

function ns.MacroXCMDUI_Build(panel)
    if not (panel and CreateFrame) then
        return function() end
    end

    InitSV()

    local mode = EnsureMode()

    local selectedIndex = nil
    local isLoadingFields = false

    local PAD_L, PAD_R = 10, 10
    -- Keep space at the bottom for the Reload UI button footprint.
    local PAD_B_LIST = 36
    local TOP_Y = 36
    local GAP = 3
    local BOX_GAP = 1
    local CMD_H = 32
    local STATUS_W = 160
    local LIST_W = 280

    -- Commands list (right)
    local listArea = CreateFrame("Frame", nil, panel, "BackdropTemplate")
    listArea:SetPoint("TOPRIGHT", panel, "TOPRIGHT", -PAD_R, -TOP_Y)
    listArea:SetPoint("BOTTOMRIGHT", panel, "BOTTOMRIGHT", -PAD_R, PAD_B_LIST)
    listArea:SetWidth(LIST_W)
    listArea:SetBackdrop({
        bgFile = "Interface/Tooltips/UI-Tooltip-Background",
        tile = true,
        tileSize = 16,
        insets = { left = 3, right = 3, top = 3, bottom = 3 },
    })
    listArea:SetBackdropColor(0, 0, 0, 0.25)

    local btnAdd = CreateFrame("Button", nil, panel, "UIPanelButtonTemplate")
    btnAdd:SetSize(60, 20)
    btnAdd:SetText("Add")

    -- Align Add with the /fgo m row, above the Characters box.
    -- (Anchored after cmdArea/charsArea are created below.)

    local empty = listArea:CreateFontString(nil, "OVERLAY", "GameFontDisable")
    empty:SetPoint("CENTER", listArea, "CENTER", 0, 0)
    empty:SetText("No commands")

    local scroll = CreateFrame("ScrollFrame", nil, listArea, "FauxScrollFrameTemplate")
    -- No header/title area; keep the list tight to the top.
    scroll:SetPoint("TOPLEFT", listArea, "TOPLEFT", 4, -6)
    scroll:SetPoint("BOTTOMRIGHT", listArea, "BOTTOMRIGHT", -4, 4)

    local ROW_H = 18
    local ROWS = 14
    local rows = {}

    local builtinSeedIndex = BuildBuiltinSeedIndex()

    HideFauxScrollBarAndEnableWheel(scroll, ROW_H)

    for i = 1, ROWS do
        local row = CreateFrame("Button", nil, listArea)
        row:SetHeight(ROW_H)
        row:SetPoint("TOPLEFT", listArea, "TOPLEFT", 8, -8 - (i - 1) * ROW_H)
        row:SetPoint("TOPRIGHT", listArea, "TOPRIGHT", -8, -8 - (i - 1) * ROW_H)

        local bg = row:CreateTexture(nil, "BACKGROUND")
        bg:SetAllPoints(row)
        bg:Hide()
        row.bg = bg

        local fs = row:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
        fs:SetPoint("LEFT", row, "LEFT", 0, 0)
        -- Reserve space for: D, E, DB.
        fs:SetPoint("RIGHT", row, "RIGHT", -68, 0)
        fs:SetJustifyH("LEFT")
        fs:SetWordWrap(false)
        row.text = fs

        if fs.GetFont and fs.SetFont then
            local fontPath, fontSize, fontFlags = fs:GetFont()
            if fontPath and fontSize then
                pcall(fs.SetFont, fs, fontPath, fontSize + 1, fontFlags)
            end
        end

        local btnD = CreateFrame("Button", nil, row, "UIPanelButtonTemplate")
        btnD:SetSize(18, ROW_H)
        btnD:SetPoint("RIGHT", row, "RIGHT", 0, 0)
        btnD:SetText("D")
        row.btnD = btnD

        local btnE = CreateFrame("Button", nil, row, "UIPanelButtonTemplate")
        btnE:SetSize(18, ROW_H)
        btnE:SetPoint("RIGHT", btnD, "LEFT", -2, 0)
        btnE:SetText("E")
        row.btnE = btnE

        local btnDB = CreateFrame("Button", nil, row, "UIPanelButtonTemplate")
        btnDB:SetSize(24, ROW_H)
        btnDB:SetPoint("RIGHT", btnE, "LEFT", -2, 0)
        btnDB:SetText("DB")
        if btnDB.EnableMouse then btnDB:EnableMouse(false) end
        row.btnDB = btnDB

        row:Hide()
        rows[i] = row
    end

    -- Left side: command input + 3 equal stacked editor boxes
    local leftArea = CreateFrame("Frame", nil, panel)
    leftArea:SetPoint("TOPLEFT", panel, "TOPLEFT", PAD_L, -TOP_Y)
    leftArea:SetPoint("BOTTOMRIGHT", listArea, "BOTTOMLEFT", -GAP, PAD_B_LEFT)

    -- Restore original editor height: let the left side extend to the bottom of the panel.
    -- (Right list still reserves PAD_B_LIST for Reload UI.)
    leftArea:ClearAllPoints()
    leftArea:SetPoint("TOPLEFT", panel, "TOPLEFT", PAD_L, -TOP_Y)
    leftArea:SetPoint("TOPRIGHT", listArea, "TOPLEFT", -GAP, 0)
    leftArea:SetPoint("BOTTOMLEFT", panel, "BOTTOMLEFT", PAD_L, 0)
    leftArea:SetPoint("BOTTOMRIGHT", listArea, "BOTTOMLEFT", -GAP, 0)

    local status = leftArea:CreateFontString(nil, "OVERLAY", "GameFontDisable")
    status:SetPoint("TOPRIGHT", leftArea, "TOPRIGHT", -2, -2)
    status:SetJustifyH("RIGHT")
    status:SetText("")
    if status.SetWidth then
        status:SetWidth(STATUS_W)
    end

    local cmdArea = CreateFrame("Frame", nil, leftArea)
    cmdArea:SetPoint("TOPLEFT", leftArea, "TOPLEFT", 0, 0)
    cmdArea:SetPoint("TOPRIGHT", leftArea, "TOPRIGHT", 0, 0)
    cmdArea:SetHeight(CMD_H)

    local function NextMode(cur)
        cur = NormalizeMode(cur)
        if cur == "x" then return "m" end
        if cur == "m" then return "c" end
        if cur == "c" then return "d" end
        return "x"
    end

    -- Clickable mode prefix button (text-only; no textures).
    local cmdPrefixBtn = CreateFrame("Button", nil, cmdArea)
    cmdPrefixBtn:EnableMouse(true)
    if cmdPrefixBtn.RegisterForClicks then
        cmdPrefixBtn:RegisterForClicks("AnyUp")
    end
    if cmdPrefixBtn.SetFrameLevel and cmdArea.GetFrameLevel then
        cmdPrefixBtn:SetFrameLevel((cmdArea:GetFrameLevel() or 0) + 30)
    end
    cmdPrefixBtn:SetHeight(CMD_H)

    local cmdPrefixText = cmdPrefixBtn:CreateFontString(nil, "OVERLAY", "GameFontNormalLarge")
    cmdPrefixText:SetPoint("LEFT", cmdPrefixBtn, "LEFT", 4, -1)
    cmdPrefixText:SetText("/fgo " .. tostring(mode))

    local function LayoutCmdPrefixBtn()
        cmdPrefixBtn:ClearAllPoints()
        cmdPrefixBtn:SetPoint("LEFT", cmdArea, "LEFT", 4, 0)

        local w = 50
        if cmdPrefixText.GetStringWidth then
            w = (cmdPrefixText:GetStringWidth() or 0) + 12
        end
        if w < 40 then w = 40 end
        cmdPrefixBtn:SetWidth(w)
    end
    LayoutCmdPrefixBtn()

    cmdPrefixBtn:SetScript("OnClick", function()
        local newMode = NextMode(mode)
        if ns and type(ns.MacroXCMD_SetMode) == "function" then
            ns.MacroXCMD_SetMode(newMode)
        elseif panel and type(panel._MacroXCMDUI_UpdateMode) == "function" then
            panel._MacroXCMDUI_UpdateMode(newMode)
        end
    end)

    cmdPrefixBtn:SetScript("OnEnter", function()
        if not GameTooltip then
            return
        end
        GameTooltip:SetOwner(cmdPrefixBtn, "ANCHOR_TOPLEFT")
        GameTooltip:SetText("Macro CMD Mode")
        GameTooltip:AddLine("Click to cycle: x → m → c → d", 1, 1, 1, true)
        GameTooltip:Show()
    end)
    cmdPrefixBtn:SetScript("OnLeave", function()
        if GameTooltip then
            GameTooltip:Hide()
        end
    end)

    local editCmd = CreateFrame("EditBox", nil, cmdArea)
    editCmd:SetAutoFocus(false)
    editCmd:SetMultiLine(false)
    editCmd:SetFontObject("GameFontNormalLarge")
    editCmd:SetTextInsets(6, 6, 4, 4)
    editCmd:ClearAllPoints()
    editCmd:SetPoint("LEFT", cmdPrefixBtn, "RIGHT", 6, 0)
    editCmd:SetHeight(CMD_H)
    if editCmd.SetMaxLetters then editCmd:SetMaxLetters(20) end
    editCmd:SetScript("OnEscapePressed", function(self) self:ClearFocus() end)
    if editCmd.EnableMouse then editCmd:EnableMouse(true) end
    if editCmd.EnableKeyboard then editCmd:EnableKeyboard(true) end
    editCmd:SetScript("OnMouseDown", function(self)
        if self.SetFocus then
            self:SetFocus()
        end
    end)

    if cmdArea.EnableMouse then cmdArea:EnableMouse(true) end
    cmdArea:SetScript("OnMouseDown", function()
        if editCmd and editCmd.SetFocus then
            editCmd:SetFocus()
        end
    end)

    local cmdGhost = cmdArea:CreateFontString(nil, "OVERLAY", "GameFontDisable")
    -- Align ghost text with where the user-typed text begins (matches editCmd:SetTextInsets).
    cmdGhost:SetPoint("LEFT", editCmd, "LEFT", 6, 0)
    cmdGhost:SetText("enter command name")

    local function UpdateCmdGhost()
        local txt = tostring(editCmd:GetText() or "")
        local show = (txt == "") and not (editCmd.HasFocus and editCmd:HasFocus())
        cmdGhost:SetShown(show)
    end

    local function MakeBox(ghostText)
        local box = CreateFrame("Frame", nil, leftArea, "BackdropTemplate")
        box:SetBackdrop({
            bgFile = "Interface/Tooltips/UI-Tooltip-Background",
            tile = true,
            tileSize = 16,
            insets = { left = 3, right = 3, top = 3, bottom = 3 },
        })
        box:SetBackdropColor(0, 0, 0, 0.25)

        local sf = CreateFrame("ScrollFrame", nil, box, "UIPanelScrollFrameTemplate")
        sf:SetPoint("TOPLEFT", box, "TOPLEFT", 6, -6)
        sf:SetPoint("BOTTOMRIGHT", box, "BOTTOMRIGHT", -6, 6)
        HideScrollBarAndEnableWheel(sf)

        if sf.EnableMouse then sf:EnableMouse(true) end

        local child = CreateFrame("Frame", nil, sf)
        child:SetPoint("TOPLEFT")
        child:SetPoint("TOPRIGHT")
        child:SetHeight(1)
        if child.EnableMouse then child:EnableMouse(true) end

        local display = child:CreateFontString(nil, "ARTWORK", "ChatFontNormal")
        display:SetPoint("TOPLEFT", child, "TOPLEFT", 0, 0)
        display:SetPoint("TOPRIGHT", child, "TOPRIGHT", 0, 0)
        display:SetJustifyH("LEFT")
        display:SetJustifyV("TOP")
        display:SetWordWrap(true)
        display:Hide()

        local eb = CreateFrame("EditBox", nil, child)
        eb:SetMultiLine(true)
        eb:SetAutoFocus(false)
        eb:SetFontObject("ChatFontNormal")
        eb:ClearAllPoints()
        eb:SetAllPoints(child)
        eb:SetWidth(1)
        eb:SetHeight(1)
        eb:SetTextInsets(6, 6, 6, 6)
        eb:SetScript("OnEscapePressed", function(self) self:ClearFocus() end)
        if eb.EnableMouse then eb:EnableMouse(true) end
        if eb.EnableKeyboard then eb:EnableKeyboard(true) end
        eb:SetScript("OnMouseDown", function(self)
            if self.SetFocus then
                self:SetFocus()
            end
        end)
        sf:SetScrollChild(child)

        box._fgoChild = child
        box._fgoDisplay = display
        box._fgoEdit = eb

        -- When the colored display overlay is shown (read-only view), put a transparent
        -- click-catcher on top so clicks always enter edit mode reliably.
        local clickCatcher = CreateFrame("Button", nil, box)
        clickCatcher:ClearAllPoints()
        clickCatcher:SetAllPoints(sf)
        clickCatcher:EnableMouse(true)
        if clickCatcher.RegisterForClicks then
            clickCatcher:RegisterForClicks("AnyUp")
        end
        if clickCatcher.SetFrameLevel and box.GetFrameLevel then
            clickCatcher:SetFrameLevel((box:GetFrameLevel() or 0) + 20)
        end
        clickCatcher:Hide()
        box._fgoClickCatcher = clickCatcher

        -- Ensure the edit box always has a real clickable width.
        local function SizeEB()
            local w = sf.GetWidth and sf:GetWidth() or 0
            if not w or w <= 0 then w = box.GetWidth and box:GetWidth() or 0 end
            if not w or w <= 0 then w = 200 end
            if child.SetWidth then child:SetWidth(w) end
            if eb.SetWidth then eb:SetWidth(w) end
            local h = sf.GetHeight and sf:GetHeight() or 0
            if not h or h <= 0 then h = 120 end
            if eb.SetHeight then eb:SetHeight(h) end
            if child.SetHeight and (child.GetHeight and child:GetHeight() or 0) < h then
                child:SetHeight(h)
            end
        end

        box._fgoSizeEB = SizeEB

        local function FocusEdit()
            if box._fgoSizeEB then
                box._fgoSizeEB()
            end
            if display and display.IsShown and display:IsShown() then
                display:Hide()
                eb:Show()
            end
            if clickCatcher and clickCatcher.IsShown and clickCatcher:IsShown() then
                clickCatcher:Hide()
            end
            if eb and eb.SetFocus then
                eb:SetFocus()
            end
        end

        clickCatcher:SetScript("OnClick", FocusEdit)

        if box.EnableMouse then box:EnableMouse(true) end
        box:SetScript("OnMouseDown", FocusEdit)
        sf:SetScript("OnMouseDown", FocusEdit)
        child:SetScript("OnMouseDown", FocusEdit)
        if box.HookScript then
            box:HookScript("OnShow", function() SizeEB() end)
            box:HookScript("OnSizeChanged", function() SizeEB() end)
        end
        if sf.HookScript then
            sf:HookScript("OnSizeChanged", function() SizeEB() end)
            sf:HookScript("OnShow", function() SizeEB() end)
        end

        -- Ghost title behind the middle of the box (not inside the input area).
        local watermark = box:CreateFontString(nil, "BACKGROUND", "GameFontDisable")
        watermark:SetPoint("CENTER", box, "CENTER", 0, 0)
        watermark:SetJustifyH("CENTER")
        watermark:SetText(tostring(ghostText or ""))
        if watermark.SetAlpha then
            watermark:SetAlpha(0.35)
        end

        box._fgoWatermark = watermark

        return box, eb
    end

    local charsArea, mainsBox = MakeBox("CHARACTERS")
    local mainArea, mainBox = MakeBox("CHARACTERS MACRO")
    local otherArea, otherBox = MakeBox("OTHERS MACRO")

    -- Footer hint: Macro CMD limitations (Retail secure/protected actions)
    local FOOTER_HINT_H = 32
    local footerHint = CreateFrame("Frame", nil, leftArea)
    footerHint:SetPoint("BOTTOMLEFT", leftArea, "BOTTOMLEFT", 6, 6)
    footerHint:SetPoint("BOTTOMRIGHT", leftArea, "BOTTOMRIGHT", -6, 6)
    footerHint:SetHeight(FOOTER_HINT_H)

    local FOOTER_HINT_PREFIX = "Limitation: "
    local footerHintLine1 = footerHint:CreateFontString(nil, "OVERLAY", "GameFontDisableSmall")
    footerHintLine1:SetPoint("TOPLEFT", footerHint, "TOPLEFT", 0, 0)
    footerHintLine1:SetPoint("TOPRIGHT", footerHint, "TOPRIGHT", 0, 0)
    footerHintLine1:SetJustifyH("LEFT")
    footerHintLine1:SetJustifyV("TOP")
    footerHintLine1:SetWordWrap(true)
    footerHintLine1:SetText(
        FOOTER_HINT_PREFIX .. "Protected functions /cancelaura, /cast, /use, /equip, /target, don't work in commands,"
    )

    local measureFS = footerHint:CreateFontString(nil, "OVERLAY", "GameFontDisableSmall")
    measureFS:Hide()
    measureFS:SetText(FOOTER_HINT_PREFIX)
    local prefixW = measureFS.GetStringWidth and measureFS:GetStringWidth() or 0
    if type(prefixW) ~= "number" or prefixW < 0 then
        prefixW = 0
    end

    local footerHintLine2 = footerHint:CreateFontString(nil, "OVERLAY", "GameFontDisableSmall")
    footerHintLine2:SetPoint("TOPLEFT", footerHintLine1, "BOTTOMLEFT", prefixW, -1)
    footerHintLine2:SetPoint("TOPRIGHT", footerHintLine1, "BOTTOMRIGHT", 0, -1)
    footerHintLine2:SetJustifyH("LEFT")
    footerHintLine2:SetJustifyV("TOP")
    footerHintLine2:SetWordWrap(true)
    footerHintLine2:SetText("This is to shorten /run, /script, /console /print commands.")

    footerHint:Show()

    -- Per-character overrides (c-mode): name + command (takes priority over faction-specific).
    local overrideArea = CreateFrame("Frame", nil, leftArea)
    overrideArea:Hide()

    local overrideTitle = overrideArea:CreateFontString(nil, "OVERLAY", "GameFontDisable")
    overrideTitle:SetPoint("TOPLEFT", overrideArea, "TOPLEFT", 6, -4)
    overrideTitle:SetJustifyH("LEFT")
    overrideTitle:SetText("Per-character override (wins over faction)")

    local function MakeInputBox(parent, ghost)
        local box = CreateFrame("Frame", nil, parent, "BackdropTemplate")
        box:SetBackdrop({
            bgFile = "Interface/Tooltips/UI-Tooltip-Background",
            tile = true,
            tileSize = 16,
            insets = { left = 3, right = 3, top = 3, bottom = 3 },
        })
        box:SetBackdropColor(0, 0, 0, 0.25)

        local eb = CreateFrame("EditBox", nil, box)
        eb:SetAutoFocus(false)
        eb:SetMultiLine(false)
        eb:SetFontObject("GameFontNormal")
        eb:SetTextInsets(6, 6, 4, 4)
        eb:SetPoint("TOPLEFT", box, "TOPLEFT", 0, 0)
        eb:SetPoint("BOTTOMRIGHT", box, "BOTTOMRIGHT", 0, 0)
        eb:SetScript("OnEscapePressed", function(self) self:ClearFocus() end)
        if eb.EnableMouse then eb:EnableMouse(true) end
        if eb.EnableKeyboard then eb:EnableKeyboard(true) end
        eb:SetScript("OnMouseDown", function(self)
            if self.SetFocus then
                self:SetFocus()
            end
        end)

        local ghostFS = box:CreateFontString(nil, "OVERLAY", "GameFontDisable")
        ghostFS:SetPoint("LEFT", box, "LEFT", 8, 0)
        ghostFS:SetText(tostring(ghost or ""))

        local function UpdateGhost()
            local txt = tostring(eb:GetText() or "")
            local show = (txt == "") and not (eb.HasFocus and eb:HasFocus())
            ghostFS:SetShown(show)
        end
        eb:HookScript("OnEditFocusGained", UpdateGhost)
        eb:HookScript("OnEditFocusLost", UpdateGhost)
        eb:HookScript("OnTextChanged", UpdateGhost)
        UpdateGhost()

        box._fgoEdit = eb
        box._fgoGhost = ghostFS
        return box, eb
    end

    local charNameArea, charNameBox = MakeInputBox(overrideArea, "character (Name or Name-Realm)")
    charNameArea:SetHeight(24)

    local charCmdArea = CreateFrame("Frame", nil, overrideArea, "BackdropTemplate")
    charCmdArea:SetBackdrop({
        bgFile = "Interface/Tooltips/UI-Tooltip-Background",
        tile = true,
        tileSize = 16,
        insets = { left = 3, right = 3, top = 3, bottom = 3 },
    })
    charCmdArea:SetBackdropColor(0, 0, 0, 0.25)

    local charCmdSF = CreateFrame("ScrollFrame", nil, charCmdArea, "UIPanelScrollFrameTemplate")
    charCmdSF:SetPoint("TOPLEFT", charCmdArea, "TOPLEFT", 6, -6)
    charCmdSF:SetPoint("BOTTOMRIGHT", charCmdArea, "BOTTOMRIGHT", -6, 6)
    HideScrollBarAndEnableWheel(charCmdSF)

    local charCmdChild = CreateFrame("Frame", nil, charCmdSF)
    charCmdChild:SetPoint("TOPLEFT")
    charCmdChild:SetPoint("TOPRIGHT")
    charCmdChild:SetHeight(1)
    charCmdSF:SetScrollChild(charCmdChild)

    local charCmdBox = CreateFrame("EditBox", nil, charCmdChild)
    charCmdBox:SetMultiLine(true)
    charCmdBox:SetAutoFocus(false)
    charCmdBox:SetFontObject("ChatFontNormal")
    charCmdBox:SetAllPoints(charCmdChild)
    charCmdBox:SetTextInsets(6, 6, 6, 6)
    charCmdBox:SetScript("OnEscapePressed", function(self) self:ClearFocus() end)
    if charCmdBox.EnableMouse then charCmdBox:EnableMouse(true) end
    if charCmdBox.EnableKeyboard then charCmdBox:EnableKeyboard(true) end
    charCmdBox:SetScript("OnMouseDown", function(self)
        if self.SetFocus then
            self:SetFocus()
        end
    end)

    local function SizeCharOverrideCmdBox()
        if not (charCmdSF and charCmdChild and charCmdBox) then
            return
        end
        local w = charCmdSF.GetWidth and charCmdSF:GetWidth() or 0
        if not w or w <= 0 then w = charCmdArea.GetWidth and charCmdArea:GetWidth() or 0 end
        if not w or w <= 0 then w = 200 end
        if charCmdChild.SetWidth then charCmdChild:SetWidth(w) end
        if charCmdBox.SetWidth then charCmdBox:SetWidth(w) end

        local h = charCmdSF.GetHeight and charCmdSF:GetHeight() or 0
        if not h or h <= 0 then h = 40 end
        if charCmdChild.SetHeight then charCmdChild:SetHeight(h) end
        if charCmdBox.SetHeight then charCmdBox:SetHeight(h) end
    end

    if charCmdArea.HookScript then
        charCmdArea:HookScript("OnShow", SizeCharOverrideCmdBox)
        charCmdArea:HookScript("OnSizeChanged", SizeCharOverrideCmdBox)
    end
    if charCmdSF.HookScript then
        charCmdSF:HookScript("OnShow", SizeCharOverrideCmdBox)
        charCmdSF:HookScript("OnSizeChanged", SizeCharOverrideCmdBox)
    end

    local charCmdWatermark = charCmdArea:CreateFontString(nil, "BACKGROUND", "GameFontDisable")
    charCmdWatermark:SetPoint("CENTER", charCmdArea, "CENTER", 0, 0)
    charCmdWatermark:SetJustifyH("CENTER")
    charCmdWatermark:SetText("override command")
    if charCmdWatermark.SetAlpha then
        charCmdWatermark:SetAlpha(0.35)
    end

    local function UpdateCharCmdWatermark()
        local txt = tostring(charCmdBox:GetText() or "")
        local show = (txt == "") and not (charCmdBox.HasFocus and charCmdBox:HasFocus())
        charCmdWatermark:SetShown(show)
    end
    charCmdBox:HookScript("OnEditFocusGained", UpdateCharCmdWatermark)
    charCmdBox:HookScript("OnEditFocusLost", UpdateCharCmdWatermark)
    charCmdBox:HookScript("OnTextChanged", UpdateCharCmdWatermark)
    UpdateCharCmdWatermark()

    local btnCharSet = CreateFrame("Button", nil, overrideArea, "UIPanelButtonTemplate")
    btnCharSet:SetSize(48, 20)
    btnCharSet:SetText("Set")

    local btnCharList = CreateFrame("Button", nil, overrideArea, "UIPanelButtonTemplate")
    btnCharList:SetSize(72, 20)
    btnCharList:SetText("Overrides")

    -- Popout list of overrides (character keys) with E/D.
    local overridePop = CreateFrame("Frame", nil, panel, "BackdropTemplate")
    overridePop:SetSize(300, 240)
    overridePop:SetBackdrop({
        bgFile = "Interface/Tooltips/UI-Tooltip-Background",
        tile = true,
        tileSize = 16,
        insets = { left = 3, right = 3, top = 3, bottom = 3 },
    })
    overridePop:SetBackdropColor(0, 0, 0, 0.85)
    overridePop:Hide()

    overridePop:SetPoint("TOPLEFT", leftArea, "TOPLEFT", 12, -92)

    local overridePopTitle = overridePop:CreateFontString(nil, "OVERLAY", "GameFontNormal")
    overridePopTitle:SetPoint("TOPLEFT", overridePop, "TOPLEFT", 8, -8)
    overridePopTitle:SetText("Character Overrides")

    local overridePopHint = overridePop:CreateFontString(nil, "OVERLAY", "GameFontDisableSmall")
    overridePopHint:SetPoint("TOPLEFT", overridePopTitle, "BOTTOMLEFT", 0, -2)
    overridePopHint:SetPoint("TOPRIGHT", overridePop, "TOPRIGHT", -8, -28)
    overridePopHint:SetJustifyH("LEFT")
    overridePopHint:SetWordWrap(true)
    overridePopHint:SetText("E = load into boxes, D = delete")

    local overrideScroll = CreateFrame("ScrollFrame", nil, overridePop, "FauxScrollFrameTemplate")
    overrideScroll:SetPoint("TOPLEFT", overridePop, "TOPLEFT", 4, -46)
    overrideScroll:SetPoint("BOTTOMRIGHT", overridePop, "BOTTOMRIGHT", -4, 6)

    local O_ROW_H = 18
    local O_ROWS = 10
    local oRows = {}
    HideFauxScrollBarAndEnableWheel(overrideScroll, O_ROW_H)

    for i = 1, O_ROWS do
        local row = CreateFrame("Button", nil, overridePop)
        row:SetHeight(O_ROW_H)
        row:SetPoint("TOPLEFT", overridePop, "TOPLEFT", 8, -50 - (i - 1) * O_ROW_H)
        row:SetPoint("TOPRIGHT", overridePop, "TOPRIGHT", -8, -50 - (i - 1) * O_ROW_H)

        local bg = row:CreateTexture(nil, "BACKGROUND")
        bg:SetAllPoints(row)
        bg:Hide()
        row.bg = bg

        local fs = row:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
        fs:SetPoint("LEFT", row, "LEFT", 0, 0)
        fs:SetPoint("RIGHT", row, "RIGHT", -44, 0)
        fs:SetJustifyH("LEFT")
        fs:SetWordWrap(false)
        row.text = fs

        local btnD = CreateFrame("Button", nil, row, "UIPanelButtonTemplate")
        btnD:SetSize(18, O_ROW_H)
        btnD:SetPoint("RIGHT", row, "RIGHT", 0, 0)
        btnD:SetText("D")
        row.btnD = btnD

        local btnE = CreateFrame("Button", nil, row, "UIPanelButtonTemplate")
        btnE:SetSize(18, O_ROW_H)
        btnE:SetPoint("RIGHT", btnD, "LEFT", -2, 0)
        btnE:SetText("E")
        row.btnE = btnE

        row:Hide()
        oRows[i] = row
    end

    local function GetSelectedOverrideEntry()
        local entry = GetSelectedEntry()
        if not (entry and type(entry) == "table") then
            return nil
        end
        if type(entry.charOverrides) ~= "table" then
            entry.charOverrides = {}
        end
        return entry
    end

    local function GetSortedOverrideKeys(entry)
        if not (entry and type(entry.charOverrides) == "table") then
            return {}
        end
        local keys = {}
        for k, v in pairs(entry.charOverrides) do
            if type(k) == "string" and type(v) == "string" and Trim(k) ~= "" then
                keys[#keys + 1] = k
            end
        end
        table.sort(keys, function(a, b) return tostring(a):lower() < tostring(b):lower() end)
        return keys
    end

    local function RefreshOverridePopout()
        if not (overridePop and overridePop.IsShown and overridePop:IsShown()) then
            return
        end
        local entry = GetSelectedOverrideEntry()
        local keys = entry and GetSortedOverrideKeys(entry) or {}

        if FauxScrollFrame_Update then
            FauxScrollFrame_Update(overrideScroll, #keys, O_ROWS, O_ROW_H)
        end

        local offset = 0
        if FauxScrollFrame_GetOffset then
            offset = FauxScrollFrame_GetOffset(overrideScroll)
        end

        for i = 1, O_ROWS do
            local idx = offset + i
            local row = oRows[i]
            local key = keys[idx]
            if not key then
                row:Hide()
            else
                row:Show()
                local zebra = (idx % 2) == 0
                row.bg:SetShown(zebra)
                row.bg:SetColorTexture(1, 1, 1, zebra and 0.05 or 0)
                row.text:SetText(key)

                row:SetScript("OnClick", function()
                    if charNameBox and charNameBox.SetText then
                        charNameBox:SetText(key)
                    end
                    if entry and entry.charOverrides and entry.charOverrides[key] and charCmdBox and charCmdBox.SetText then
                        charCmdBox:SetText(tostring(entry.charOverrides[key] or ""))
                    end
                end)

                if row.btnE then
                    row.btnE:SetScript("OnClick", function()
                        if charNameBox and charNameBox.SetText then
                            charNameBox:SetText(key)
                        end
                        if entry and entry.charOverrides and entry.charOverrides[key] and charCmdBox and charCmdBox.SetText then
                            charCmdBox:SetText(tostring(entry.charOverrides[key] or ""))
                        end
                        if charCmdBox and charCmdBox.SetFocus then
                            charCmdBox:SetFocus()
                        end
                    end)
                end

                if row.btnD then
                    row.btnD:SetScript("OnClick", function()
                        local e = GetSelectedOverrideEntry()
                        if not e then
                            return
                        end
                        e.charOverrides[key] = nil
                        status:SetText("Override deleted")

                        if ns and type(ns.MacroXCMD_ArmClickButton) == "function" and type(e.key) == "string" then
                            pcall(ns.MacroXCMD_ArmClickButton, mode, e.key)
                        end
                        RefreshOverridePopout()
                    end)
                end
            end
        end
    end

    overrideScroll:SetScript("OnVerticalScroll", function(self, offset)
        if FauxScrollFrame_OnVerticalScroll then
            FauxScrollFrame_OnVerticalScroll(self, offset, O_ROW_H, function()
                RefreshOverridePopout()
            end)
        end
    end)

    btnCharList:SetScript("OnClick", function()
        if not (mode == "c") then
            overridePop:Hide()
            return
        end
        if overridePop:IsShown() then
            overridePop:Hide()
        else
            overridePop:Show()
            RefreshOverridePopout()
        end
    end)

    btnCharSet:SetScript("OnClick", function()
        if mode ~= "c" then
            return
        end
        local entry = GetSelectedOverrideEntry()
        if not entry then
            status:SetText("Select a command")
            return
        end

        local k = Trim(charNameBox:GetText() or "")
        if k == "" then
            status:SetText("Enter character")
            return
        end

        local v = tostring(charCmdBox:GetText() or "")
        if Trim(v) == "" then
            entry.charOverrides[k] = nil
            status:SetText("Override cleared")
        else
            entry.charOverrides[k] = v
            status:SetText("Override set")
        end

        if ns and type(ns.MacroXCMD_ArmClickButton) == "function" and type(entry.key) == "string" then
            pcall(ns.MacroXCMD_ArmClickButton, mode, entry.key)
        end

        RefreshOverridePopout()
    end)

    -- Position Add now that we have cmdArea + charsArea.
    -- Important: btnAdd must be above cmdArea, otherwise cmdArea's OnMouseDown
    -- will eat clicks and focus the name box instead of firing the button.
    btnAdd:SetParent(cmdArea)
    if btnAdd.SetFrameLevel and cmdArea.GetFrameLevel then
        btnAdd:SetFrameLevel((cmdArea:GetFrameLevel() or 0) + 10)
    end
    if btnAdd.EnableMouse then btnAdd:EnableMouse(true) end
    if btnAdd.RegisterForClicks then btnAdd:RegisterForClicks("AnyUp") end
    btnAdd:ClearAllPoints()
    btnAdd:SetPoint("TOPRIGHT", cmdArea, "TOPRIGHT", -2, -4)

    -- Keep status messages visible (don't hide them under the Add button).
    status:ClearAllPoints()
    status:SetParent(cmdArea)
    status:SetPoint("RIGHT", btnAdd, "LEFT", -8, 0)
    status:SetJustifyH("RIGHT")
    if status.SetWidth then
        status:SetWidth(STATUS_W)
    end

    -- Make the name input end near the middle (like other tabs): fill up to the status block.
    editCmd:ClearAllPoints()
    editCmd:SetPoint("LEFT", cmdPrefixBtn, "RIGHT", 6, 0)
    editCmd:SetPoint("RIGHT", status, "LEFT", -8, 0)

    local function UpdateMacroBoxValidation(area)
        if not area then
            return
        end
        local eb = area._fgoEdit
        local display = area._fgoDisplay
        local child = area._fgoChild
        if not (eb and display and child) then
            return
        end

        local v = ValidateMacroCmdText(eb:GetText() or "")
        area._fgoValidation = v

        local dot = area._fgoDiagDot
        if dot and dot._fgoTex and dot._fgoTex.SetTexture then
            if v.severity == "error" then
                dot._fgoTex:SetTexture("Interface/Common/Indicator-Red")
                dot:Show()
            elseif v.severity == "warn" then
                dot._fgoTex:SetTexture("Interface/Common/Indicator-Yellow")
                dot:Show()
            else
                dot._fgoTex:SetTexture("Interface/Common/Indicator-Green")
                dot:Show()
            end
        end

        display:ClearAllPoints()
        display:SetPoint("TOPLEFT", child, "TOPLEFT", 6, -6)
        display:SetPoint("TOPRIGHT", child, "TOPRIGHT", -6, -6)
        display:SetText(BuildColoredDisplayText(v))

        local hEdit = eb.GetHeight and eb:GetHeight() or 1
        local hDisp = display.GetStringHeight and display:GetStringHeight() or 1
        local want = math.max(hEdit or 1, (hDisp or 1) + 12)
        if want < 1 then want = 1 end
        if child.SetHeight then
            child:SetHeight(want)
        end
    end

    local function ShowMacroBoxDisplay(area, showDisplay)
        if not area then
            return
        end
        local eb = area._fgoEdit
        local display = area._fgoDisplay
        if not (eb and display) then
            return
        end
        if showDisplay then
            UpdateMacroBoxValidation(area)
            eb:Hide()
            display:Show()
            local click = area._fgoClickCatcher
            if click and click.Show then
                click:Show()
            end
        else
            display:Hide()
            eb:Show()
            local click = area._fgoClickCatcher
            if click and click.Hide then
                click:Hide()
            end
        end
    end

    local function ShowMacroBoxTooltip(area, title, owner)
        if not (GameTooltip and area) then
            return
        end
        UpdateMacroBoxValidation(area)

        GameTooltip:SetOwner(owner or area, "ANCHOR_LEFT")
        GameTooltip:SetText(title or "Macro")

        local v = area._fgoValidation
        if type(v) ~= "table" then
            GameTooltip:AddLine("No validation data.", 1, 1, 1, true)
            GameTooltip:Show()
            return
        end

        if (v.errors or 0) == 0 and (v.warns or 0) == 0 then
            GameTooltip:AddLine("OK", 0.2, 1, 0.2, true)
            GameTooltip:Show()
            return
        end

        if (v.errors or 0) > 0 then
            GameTooltip:AddLine("Errors:", 1, 0.2, 0.2, true)
            for i = 1, #(v.lines or {}) do
                local info = v.perLine and v.perLine[i]
                if info and info.severity == "error" then
                    for _, msg in ipairs(info.messages or {}) do
                        GameTooltip:AddLine("Line " .. tostring(i) .. ": " .. tostring(msg), 1, 0.2, 0.2, true)
                    end
                end
            end
        end

        if (v.warns or 0) > 0 then
            GameTooltip:AddLine("Warnings:", 1, 1, 0.2, true)
            for i = 1, #(v.lines or {}) do
                local info = v.perLine and v.perLine[i]
                if info and info.severity == "warn" then
                    for _, msg in ipairs(info.messages or {}) do
                        GameTooltip:AddLine("Line " .. tostring(i) .. ": " .. tostring(msg), 1, 1, 0.2, true)
                    end
                end
            end
        end

        GameTooltip:Show()
    end

    -- MAIN/OTHER: show colored display when not focused; raw text when editing.
    if mainBox and mainBox.HookScript then
        mainBox:HookScript("OnEditFocusGained", function() ShowMacroBoxDisplay(mainArea, false) end)
        mainBox:HookScript("OnEditFocusLost", function() ShowMacroBoxDisplay(mainArea, true) end)
        mainBox:HookScript("OnTextChanged", function() UpdateMacroBoxValidation(mainArea) end)
    end
    if otherBox and otherBox.HookScript then
        otherBox:HookScript("OnEditFocusGained", function() ShowMacroBoxDisplay(otherArea, false) end)
        otherBox:HookScript("OnEditFocusLost", function() ShowMacroBoxDisplay(otherArea, true) end)
        otherBox:HookScript("OnTextChanged", function() UpdateMacroBoxValidation(otherArea) end)
    end

    local function AddDiagDot(area, title)
        if not area then
            return
        end

        local dot = CreateFrame("Button", nil, area)
        dot:SetSize(12, 12)
        dot:SetPoint("TOPRIGHT", area, "TOPRIGHT", -6, -6)
        dot:EnableMouse(true)
        if dot.SetFrameLevel and area.GetFrameLevel then
            dot:SetFrameLevel((area:GetFrameLevel() or 0) + 25)
        end

        local tex = dot:CreateTexture(nil, "OVERLAY")
        tex:SetAllPoints(dot)
        tex:SetTexture("Interface/Common/Indicator-Green")
        dot._fgoTex = tex

        area._fgoDiagTitle = tostring(title or "Macro")

        dot:SetScript("OnEnter", function()
            local t = area._fgoDiagTitle or title
            ShowMacroBoxTooltip(area, t, dot)
        end)
        dot:SetScript("OnLeave", function()
            if GameTooltip then
                GameTooltip:Hide()
            end
        end)

        area._fgoDiagDot = dot
    end

    if mainArea then
        AddDiagDot(mainArea, "CHARACTERS MACRO")
        ShowMacroBoxDisplay(mainArea, true)
    end
    if otherArea then
        AddDiagDot(otherArea, "OTHERS MACRO")
        ShowMacroBoxDisplay(otherArea, true)
    end

    local function UpdateBoxLabels()
        if mode == "c" then
            if charsArea and charsArea._fgoWatermark then charsArea._fgoWatermark:SetText("SHOW ON ALL") end
            if mainArea and mainArea._fgoWatermark then mainArea._fgoWatermark:SetText("ALLIANCE") end
            if otherArea and otherArea._fgoWatermark then otherArea._fgoWatermark:SetText("HORDE") end

            if mainArea then mainArea._fgoDiagTitle = "ALLIANCE" end
            if otherArea then otherArea._fgoDiagTitle = "HORDE" end
        else
            if charsArea and charsArea._fgoWatermark then charsArea._fgoWatermark:SetText("CHARACTERS") end
            if mainArea and mainArea._fgoWatermark then mainArea._fgoWatermark:SetText("CHARACTERS MACRO") end
            if otherArea and otherArea._fgoWatermark then otherArea._fgoWatermark:SetText("OTHERS MACRO") end

            if mainArea then mainArea._fgoDiagTitle = "CHARACTERS MACRO" end
            if otherArea then otherArea._fgoDiagTitle = "OTHERS MACRO" end
        end
    end

    local function LayoutLeft()
        local h = leftArea.GetHeight and leftArea:GetHeight() or 0
        if not h or h <= 0 then
            return
        end

        if mode == "x" then
            charsArea:Show()
            mainArea:Show()
            otherArea:Show()
            footerHint:Show()
            if overrideArea then overrideArea:Hide() end
            if overridePop then overridePop:Hide() end

            -- cmdArea -> (gap) -> box1 -> (gap) -> box2 -> (gap) -> box3
            local avail = h - CMD_H - (BOX_GAP * 3) - FOOTER_HINT_H
            if avail < 180 then
                avail = 180
            end
            local base = math.floor(avail / 3)
            if base < 60 then
                base = 60
            end
            local rem = avail - (base * 3)
            if rem < 0 then rem = 0 end
            local h1 = base + (rem >= 1 and 1 or 0)
            local h2 = base + (rem >= 2 and 1 or 0)
            local h3 = base

            charsArea:ClearAllPoints()
            charsArea:SetPoint("TOPLEFT", cmdArea, "BOTTOMLEFT", 0, -BOX_GAP)
            charsArea:SetPoint("TOPRIGHT", cmdArea, "BOTTOMRIGHT", 0, -BOX_GAP)
            charsArea:SetHeight(h1)

            mainArea:ClearAllPoints()
            mainArea:SetPoint("TOPLEFT", charsArea, "BOTTOMLEFT", 0, -BOX_GAP)
            mainArea:SetPoint("TOPRIGHT", charsArea, "BOTTOMRIGHT", 0, -BOX_GAP)
            mainArea:SetHeight(h2)

            otherArea:ClearAllPoints()
            otherArea:SetPoint("TOPLEFT", mainArea, "BOTTOMLEFT", 0, -BOX_GAP)
            otherArea:SetPoint("TOPRIGHT", mainArea, "BOTTOMRIGHT", 0, -BOX_GAP)
            otherArea:SetHeight(h3)
        elseif mode == "c" then
            -- Faction mode: 3 macro boxes + per-character overrides.
            charsArea:Show()
            mainArea:Show()
            otherArea:Show()
            footerHint:Show()
            if overrideArea then overrideArea:Show() end

            local avail = h - CMD_H - FOOTER_HINT_H - (BOX_GAP * 4)
            if avail < 260 then
                avail = 260
            end

            local minOverride = 76
            local desiredBox = 64
            local minBox = 48

            local boxH = desiredBox
            if avail < (desiredBox * 3 + minOverride) then
                boxH = math.floor((avail - minOverride) / 3)
            end
            if boxH < minBox then
                boxH = minBox
            end

            local overrideH = avail - (boxH * 3)
            if overrideH < minOverride then
                overrideH = minOverride
            end

            charsArea:ClearAllPoints()
            charsArea:SetPoint("TOPLEFT", cmdArea, "BOTTOMLEFT", 0, -BOX_GAP)
            charsArea:SetPoint("TOPRIGHT", cmdArea, "BOTTOMRIGHT", 0, -BOX_GAP)
            charsArea:SetHeight(boxH)

            mainArea:ClearAllPoints()
            mainArea:SetPoint("TOPLEFT", charsArea, "BOTTOMLEFT", 0, -BOX_GAP)
            mainArea:SetPoint("TOPRIGHT", charsArea, "BOTTOMRIGHT", 0, -BOX_GAP)
            mainArea:SetHeight(boxH)

            otherArea:ClearAllPoints()
            otherArea:SetPoint("TOPLEFT", mainArea, "BOTTOMLEFT", 0, -BOX_GAP)
            otherArea:SetPoint("TOPRIGHT", mainArea, "BOTTOMRIGHT", 0, -BOX_GAP)
            otherArea:SetHeight(boxH)

            if overrideArea then
                overrideArea:ClearAllPoints()
                overrideArea:SetPoint("TOPLEFT", otherArea, "BOTTOMLEFT", 0, -BOX_GAP)
                overrideArea:SetPoint("TOPRIGHT", otherArea, "BOTTOMRIGHT", 0, -BOX_GAP)
                overrideArea:SetHeight(overrideH)

                charNameArea:ClearAllPoints()
                charNameArea:SetPoint("TOPLEFT", overrideArea, "TOPLEFT", 0, -18)
                charNameArea:SetPoint("TOPRIGHT", overrideArea, "TOPRIGHT", 0, -18)

                btnCharSet:ClearAllPoints()
                btnCharSet:SetPoint("TOPRIGHT", charNameArea, "BOTTOMRIGHT", 0, -4)

                btnCharList:ClearAllPoints()
                btnCharList:SetPoint("RIGHT", btnCharSet, "LEFT", -4, 0)

                charCmdArea:ClearAllPoints()
                charCmdArea:SetPoint("TOPLEFT", charNameArea, "BOTTOMLEFT", 0, -4)
                charCmdArea:SetPoint("TOPRIGHT", btnCharList, "TOPLEFT", -6, 0)
                charCmdArea:SetPoint("BOTTOMLEFT", overrideArea, "BOTTOMLEFT", 0, 0)
                charCmdArea:SetPoint("BOTTOMRIGHT", overrideArea, "BOTTOMRIGHT", 0, 0)
            end
        elseif mode == "m" or mode == "d" then
            -- Single-text modes: disable character boxes and use the bottom macro box.
            charsArea:Hide()
            mainArea:Hide()
            otherArea:Show()
            footerHint:Show()
            if overrideArea then overrideArea:Hide() end
            if overridePop then overridePop:Hide() end

            local avail = h - CMD_H - BOX_GAP - FOOTER_HINT_H
            if avail < 90 then
                avail = 90
            end
            otherArea:ClearAllPoints()
            otherArea:SetPoint("TOPLEFT", cmdArea, "BOTTOMLEFT", 0, -BOX_GAP)
            otherArea:SetPoint("TOPRIGHT", cmdArea, "BOTTOMRIGHT", 0, -BOX_GAP)
            otherArea:SetHeight(avail)
        end
    end

    LayoutLeft()
    leftArea:SetScript("OnShow", LayoutLeft)
    leftArea:SetScript("OnSizeChanged", LayoutLeft)

    local function GetSelectedEntry()
        local cmds = EnsureCommandsArray()
        if not selectedIndex then
            return nil
        end
        return cmds[selectedIndex]
    end

    local function FindIndexByModeAndKey(wantMode, wantKey, skipIndex)
        wantMode = NormalizeMode(wantMode)
        wantKey = Trim(wantKey):lower()
        if wantKey == "" then
            return nil
        end
        local cmds = EnsureCommandsArray()
        for i = 1, #cmds do
            if i ~= skipIndex then
                local e = cmds[i]
                if type(e) == "table" and type(e.key) == "string" then
                    local emode = GetEntryMode(e)
                    if emode == wantMode and e.key:lower() == wantKey then
                        return i
                    end
                end
            end
        end
        return nil
    end

    local function LoadFields()
        isLoadingFields = true
        local entry = GetSelectedEntry()

        local defaultMains = EnsureDefaultMainsArray()

        if not entry then
            editCmd:SetText("")
            if mode == "c" then
                mainsBox:SetText("")
                mainBox:SetText("")
                otherBox:SetText("")
                if charNameBox and charNameBox.SetText then charNameBox:SetText("") end
                if charCmdBox and charCmdBox.SetText then charCmdBox:SetText("") end
            else
                mainsBox:SetText(JoinLines(defaultMains))
                mainBox:SetText("")
                otherBox:SetText("")
            end
            status:SetText("")
            UpdateCmdGhost()
            if overridePop and overridePop:IsShown() then
                RefreshOverridePopout()
            end
            isLoadingFields = false
            return
        end

        editCmd:SetText(entry.key and tostring(entry.key) or "")
        if mode == "x" then
            local mainsToShow = defaultMains
            if type(entry.mains) == "table" and #entry.mains > 0 then
                mainsToShow = entry.mains
            end
            mainsBox:SetText(JoinLines(mainsToShow))
            mainBox:SetText(entry.mainText and tostring(entry.mainText) or "")
            otherBox:SetText(entry.otherText and tostring(entry.otherText) or "")
        elseif mode == "c" then
            mainsBox:SetText(entry.bothText and tostring(entry.bothText) or "")
            mainBox:SetText(entry.allianceText and tostring(entry.allianceText) or "")
            otherBox:SetText(entry.hordeText and tostring(entry.hordeText) or "")
            if charNameBox and charNameBox.SetText then charNameBox:SetText("") end
            if charCmdBox and charCmdBox.SetText then charCmdBox:SetText("") end
        else
            mainsBox:SetText(JoinLines(defaultMains))
            -- Single-text modes: place contents into the bottom active box.
            local t = tostring(entry.otherText or "")
            if Trim(t) == "" then
                t = tostring(entry.mainText or "")
            end
            mainBox:SetText("")
            otherBox:SetText(t)
        end
        status:SetText("")

        if mode == "c" then
            if charsArea then ShowMacroBoxDisplay(charsArea, true) end
            if mainArea then ShowMacroBoxDisplay(mainArea, true) end
            if otherArea then ShowMacroBoxDisplay(otherArea, true) end
        else
            if charsArea then ShowMacroBoxDisplay(charsArea, false) end
            if mainArea then ShowMacroBoxDisplay(mainArea, true) end
            if otherArea then ShowMacroBoxDisplay(otherArea, true) end
        end

        UpdateCmdGhost()

        if overridePop and overridePop:IsShown() then
            RefreshOverridePopout()
        end

        isLoadingFields = false
    end

    local saveTimer = nil

    local function SaveDefaultMainsFromUI()
        local defaultMains = EnsureDefaultMainsArray()
        local mains = SplitLines(mainsBox:GetText() or "")
        wipe(defaultMains)
        for i = 1, #mains do
            defaultMains[i] = tostring(mains[i] or "")
        end
        return mains
    end

    local function SaveFields(debounce)
        if isLoadingFields then
            return
        end

        local function doSave()
            saveTimer = nil

            local entry = GetSelectedEntry()
            local mains = nil
            if entry and mode == "x" then
                -- Per-entry Characters list in x-mode.
                mains = SplitLines(mainsBox:GetText() or "")
            elseif mode == "c" then
                -- Faction mode: mainsBox is a macro field, not a characters list.
                mains = nil
            else
                -- Always persist the shared Characters list when not editing an x entry.
                mains = SaveDefaultMainsFromUI()
            end

            if entry then
                entry.mode = entry.mode or mode
                local key = Trim(editCmd:GetText() or "")

                -- Prevent accidental duplicates: do not allow renaming to an existing key in this mode.
                local existingIdx = FindIndexByModeAndKey(mode, key, selectedIndex)
                if existingIdx then
                    status:SetText("Name already exists")
                    UpdateCmdGhost()
                    if panel._MacroCmdUI_RefreshList then
                        panel:_MacroCmdUI_RefreshList()
                    end
                    return
                end

                entry.key = key

                -- Store onto the entry so runtime behavior remains unchanged.
                if mode == "x" then
                    entry.mains = mains
                    entry.mainText = tostring(mainBox:GetText() or "")
                    entry.otherText = tostring(otherBox:GetText() or "")
                elseif mode == "c" then
                    entry.mains = entry.mains
                    entry.mainText = entry.mainText or ""
                    entry.otherText = entry.otherText or ""
                    entry.bothText = tostring(mainsBox:GetText() or "")
                    entry.allianceText = tostring(mainBox:GetText() or "")
                    entry.hordeText = tostring(otherBox:GetText() or "")
                else
                    -- Single-text modes: keep only the bottom box text.
                    entry.mains = mains
                    entry.mainText = ""
                    entry.otherText = tostring(otherBox:GetText() or "")
                end

                -- Macro CMD: keep the secure /click button up to date so the user macro just works.
                if ns and type(ns.MacroXCMD_ArmClickButton) == "function" then
                    pcall(ns.MacroXCMD_ArmClickButton, mode, key)
                end
            end

            UpdateCmdGhost()

            if panel._MacroCmdUI_RefreshList then
                panel:_MacroCmdUI_RefreshList()
            end
        end

        if debounce and C_Timer and C_Timer.NewTimer then
            if saveTimer and saveTimer.Cancel then
                saveTimer:Cancel()
            end
            saveTimer = C_Timer.NewTimer(0.30, doSave)
        else
            doSave()
        end
    end

    editCmd:SetScript("OnEditFocusGained", function() UpdateCmdGhost() end)
    editCmd:SetScript("OnEditFocusLost", function()
        UpdateCmdGhost()
        SaveFields(false)
    end)
    editCmd:SetScript("OnTextChanged", function() SaveFields(true) end)
    mainsBox:SetScript("OnEditFocusLost", function() SaveFields(false) end)
    mainsBox:SetScript("OnTextChanged", function() SaveFields(true) end)
    mainBox:SetScript("OnEditFocusLost", function() SaveFields(false) end)
    mainBox:SetScript("OnTextChanged", function() SaveFields(true) end)
    otherBox:SetScript("OnEditFocusLost", function() SaveFields(false) end)
    otherBox:SetScript("OnTextChanged", function() SaveFields(true) end)

    local function RefreshButtons()
        -- Delete removed by request.
    end

    local RefreshList

    local function DeleteIndex(delIdx)
        local cmds = EnsureCommandsArray()
        if type(delIdx) ~= "number" or delIdx < 1 or delIdx > #cmds then
            return
        end

        -- If a debounced save is pending, cancel it so it can't run
        -- after the entry was removed and confuse UI refresh.
        if saveTimer and saveTimer.Cancel then
            saveTimer:Cancel()
        end
        saveTimer = nil

        table.remove(cmds, delIdx)

        if #cmds == 0 then
            selectedIndex = nil
        else
            if selectedIndex and selectedIndex > delIdx then
                selectedIndex = selectedIndex - 1
            elseif selectedIndex == delIdx then
                if delIdx > #cmds then
                    selectedIndex = #cmds
                end
            end
        end

        RefreshButtons()
        RefreshList()
        LoadFields()
        status:SetText("Deleted")
    end

    RefreshList = function()
        local cmds = EnsureCommandsArray()

        local visible = {}
        for i = 1, #cmds do
            local entry = cmds[i]
            local emode = GetEntryMode(entry)
            if mode == "x" then
                if emode == "x" then
                    visible[#visible + 1] = i
                end
            elseif mode == "d" then
                -- d-mode shows everything not in x/m/c (unknown tags normalize to d)
                if emode == "d" then
                    visible[#visible + 1] = i
                end
            else
                if emode == mode then
                    visible[#visible + 1] = i
                end
            end
        end

        empty:SetShown(#visible == 0)

        if selectedIndex and (selectedIndex < 1 or selectedIndex > #cmds) then
            selectedIndex = nil
        end

        -- If switching modes, clear selection if it isn't visible in this mode.
        if selectedIndex then
            local inView = false
            for _, idx in ipairs(visible) do
                if idx == selectedIndex then
                    inView = true
                    break
                end
            end
            if not inView then
                selectedIndex = nil
            end
        end

        if FauxScrollFrame_Update then
            FauxScrollFrame_Update(scroll, #visible, ROWS, ROW_H)
        end

        local offset = 0
        if FauxScrollFrame_GetOffset then
            offset = FauxScrollFrame_GetOffset(scroll)
        end

        for i = 1, ROWS do
            local visIdx = offset + i
            local row = rows[i]
            local realIdx = visible[visIdx]
            local entry = realIdx and cmds[realIdx] or nil

            if not entry then
                row:Hide()
            else
                row:Show()

                local zebra = (visIdx % 2) == 0
                row.bg:SetShown(zebra or (selectedIndex == realIdx))
                if selectedIndex == realIdx then
                    row.bg:SetColorTexture(0.2, 0.6, 1, 0.18)
                else
                    row.bg:SetColorTexture(1, 1, 1, zebra and 0.05 or 0)
                end

                local keyRaw = entry and entry.key
                local keyTxt = (type(keyRaw) == "string" and keyRaw ~= "") and keyRaw or "<new>"
                row.text:SetText("/fgo " .. tostring(mode) .. " " .. keyTxt)

                if row.btnDB then
                    row.btnDB:SetShown(IsEntryUneditedSeed(entry, builtinSeedIndex) and true or false)
                end

                local capturedIdx = realIdx
                local capturedVis = visIdx
                local function SelectAndLoad()
                    selectedIndex = capturedIdx
                    RefreshButtons()
                    RefreshList()
                    LoadFields()
                end

                local function SelectAndEdit()
                    SelectAndLoad()
                    if editCmd and editCmd.SetFocus then
                        editCmd:SetFocus()
                        if editCmd.HighlightText then
                            editCmd:HighlightText()
                        end
                    end
                end

                row:SetScript("OnClick", SelectAndEdit)

                if row.btnE then
                    row.btnE:SetScript("OnClick", SelectAndEdit)
                end

                if row.btnD then
                    row.btnD:SetScript("OnClick", function()
                        if not (IsShiftKeyDown and IsShiftKeyDown()) then
                            status:SetText("Hold SHIFT to delete")
                            return
                        end
                        -- Ensure we're deleting what was clicked, and flush any edits.
                        selectedIndex = capturedIdx
                        SaveFields(false)
                        DeleteIndex(capturedIdx)
                        RefreshList()
                    end)
                end
            end
        end
    end

    panel._MacroCmdUI_RefreshList = RefreshList

    scroll:SetScript("OnVerticalScroll", function(self, offset)
        if FauxScrollFrame_OnVerticalScroll then
            FauxScrollFrame_OnVerticalScroll(self, offset, ROW_H, function()
                RefreshList()
            end)
        end
    end)

    btnAdd:SetScript("OnClick", function()
        -- If we're editing an existing entry, don't allow Add to duplicate it.
        -- First click switches back to "add" workflow (no selection).
        if selectedIndex then
            selectedIndex = nil
            RefreshButtons()
            RefreshList()
            LoadFields()
            status:SetText("Add mode")
            return
        end

        -- Flush any pending debounced save so UI text is current.
        SaveFields(false)

        local key = Trim(editCmd:GetText() or "")
        if key == "" then
            status:SetText("Enter a name")
            return
        end

        -- Prevent duplicates in this mode: if it already exists, select it.
        local existingIdx = FindIndexByModeAndKey(mode, key, nil)
        if existingIdx then
            selectedIndex = existingIdx
            RefreshButtons()
            RefreshList()
            LoadFields()
            status:SetText("Already exists")
            return
        end

        local keepMains = SplitLines(mainsBox:GetText() or "")
        local keepOtherText = tostring(otherBox:GetText() or "")

        if mode ~= "c" then
            -- "Add" uses the Characters box as a draft template.
            -- Persist it so it stays when no entry is selected.
            local defaultMains = EnsureDefaultMainsArray()
            wipe(defaultMains)
            for i = 1, #keepMains do
                defaultMains[i] = tostring(keepMains[i] or "")
            end
        end

        local cmds = EnsureCommandsArray()
        if mode == "x" then
            local keepMainText = tostring(mainBox:GetText() or "")
            cmds[#cmds + 1] = { mode = "x", key = key, mains = keepMains, mainText = keepMainText, otherText = keepOtherText }
        elseif mode == "c" then
            local keepBothText = tostring(mainsBox:GetText() or "")
            local keepAllianceText = tostring(mainBox:GetText() or "")
            local keepHordeText = tostring(otherBox:GetText() or "")
            cmds[#cmds + 1] = { mode = "c", key = key, bothText = keepBothText, allianceText = keepAllianceText, hordeText = keepHordeText, charOverrides = {} }
        else
            cmds[#cmds + 1] = { mode = tostring(mode), key = key, mains = keepMains, mainText = "", otherText = keepOtherText }
        end

        -- Stay in "add" workflow: keep no selection so the draft Characters list remains visible.
        selectedIndex = nil
        RefreshButtons()
        RefreshList()
        LoadFields()
        status:SetText("Added")
    end)

    panel._MacroXCMDUI_UpdateMode = function(newMode)
        mode = NormalizeMode(newMode)
        local s = GetSettings()
        if s then
            s.macroCmdModeAcc = mode
        end
        cmdPrefixText:SetText("/fgo " .. tostring(mode))
        LayoutCmdPrefixBtn()

        UpdateBoxLabels()

        if overridePop and overridePop.IsShown and overridePop:IsShown() then
            overridePop:Hide()
        end

        LayoutLeft()
        RefreshList()
        LoadFields()
    end

    panel._MacroCmdUI_SelectKey = function(wantMode, wantKey)
        wantMode = NormalizeMode(wantMode)
        wantKey = Trim(wantKey)
        if wantKey == "" then
            return
        end

        if panel and type(panel._MacroXCMDUI_UpdateMode) == "function" then
            panel._MacroXCMDUI_UpdateMode(wantMode)
        end

        local idx = FindIndexByModeAndKey(wantMode, wantKey, nil)
        selectedIndex = idx

        if not idx then
            -- Stay in add workflow but prefill the key.
            editCmd:SetText(wantKey)
        end

        RefreshButtons()
        RefreshList()
        LoadFields()
        status:SetText(idx and "Selected" or "Add mode")
    end

    ns._MacroXCMDUI_Panel = panel

    local function UpdateAll()
        UpdateBoxLabels()
        RefreshButtons()
        RefreshList()
        LoadFields()
    end

    UpdateAll()
    return UpdateAll
end

-- Back-compat: older code referenced MacroCmdUI_Build
ns.MacroCmdUI_Build = ns.MacroXCMDUI_Build
