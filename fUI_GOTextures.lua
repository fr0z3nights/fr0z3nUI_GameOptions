---@diagnostic disable: undefined-global

local addonName, ns = ...
if type(ns) ~= "table" then ns = {} end

ns.Textures = ns.Textures or {}

local PREFIX = "|cff00ccff[FGO]|r "

local function Print(msg)
    if ns and type(ns._Print) == "function" then
        ns._Print(msg)
        return
    end
    print(PREFIX .. tostring(msg))
end

local function InitSV()
    if ns and type(ns._InitSV) == "function" then
        ns._InitSV()
    end
end

local function EnsureDB()
    InitSV()
    AutoGossip_UI = AutoGossip_UI or {}
    AutoGossip_UI.textures = AutoGossip_UI.textures or {}
    local db = AutoGossip_UI.textures
    db.overrides = db.overrides or {}
    db.widgets = db.widgets or {}
    db.seen = db.seen or {}
    if db.debug == nil then db.debug = false end
    return db
end

local function IsEmptyTable(t)
    if type(t) ~= "table" then return true end
    return next(t) == nil
end

local function DeepCopy(src, seen)
    if type(src) ~= "table" then return src end
    seen = seen or {}
    if seen[src] then return seen[src] end

    local out = {}
    seen[src] = out
    for k, v in pairs(src) do
        out[DeepCopy(k, seen)] = DeepCopy(v, seen)
    end
    return out
end

local function NextAvailableWidgetKey(destWidgets, baseKey)
    baseKey = tostring(baseKey or "")
    if baseKey == "" then baseKey = "Imported" end
    if not destWidgets[baseKey] then return baseKey end

    local k = baseKey .. "_AL"
    if not destWidgets[k] then return k end

    local i = 2
    while true do
        k = string.format("%s_AL%d", baseKey, i)
        if not destWidgets[k] then return k end
        i = i + 1
        if i > 9999 then return baseKey .. "_AL9999" end
    end
end

-- One-time (per session) migration info/warnings so users can tell why the import string didn't appear.
local _fgoTexturesMigrationNotified = false

local function TryMigrateFromArtLayer()
    local db = EnsureDB()
    if db and db.migratedFromArtLayer then
        if not _fgoTexturesMigrationNotified then
            _fgoTexturesMigrationNotified = true
            local wCount, oCount = 0, 0
            for _ in pairs((db.widgets or {})) do wCount = wCount + 1 end
            for _ in pairs((db.overrides or {})) do oCount = oCount + 1 end
            Print(string.format("Textures: ArtLayer migration already completed (widgets=%d overrides=%d).", wCount, oCount))
        end
        return false
    end

    local src = (type(_G) == "table") and rawget(_G, "fr0z3nUI_ArtLayerDB") or nil
    if type(src) ~= "table" then
        if not _fgoTexturesMigrationNotified then
            _fgoTexturesMigrationNotified = true
            Print("Textures: ArtLayer DB not loaded; enable fr0z3nUI_ArtLayer once and /reload to import.")
        end
        return false
    end
    if type(src.widgets) ~= "table" then
        if not _fgoTexturesMigrationNotified then
            _fgoTexturesMigrationNotified = true
            Print("Textures: ArtLayer DB loaded but has no widgets table to import.")
        end
        return false
    end

    local destWidgets = db.widgets or {}
    db.widgets = destWidgets
    db.seen = db.seen or {}

    local wasEmptyBeforeImport = IsEmptyTable(destWidgets)

    db.overrides = db.overrides or {}

    local imported = 0
    local renamed = 0
    local importedOverrides = 0

    for key, widget in pairs(src.widgets) do
        if type(widget) == "table" then
            local destKey = tostring(key or "")
            if destKey == "" then destKey = "Imported" end

            if destWidgets[destKey] then
                destKey = NextAvailableWidgetKey(destWidgets, destKey)
                renamed = renamed + 1
            end

            destWidgets[destKey] = DeepCopy(widget)
            imported = imported + 1
        end
    end

    if type(src.overrides) == "table" then
        for frameName, ov in pairs(src.overrides) do
            if type(frameName) == "string" and frameName ~= "" and type(ov) == "table" then
                if type(db.overrides[frameName]) ~= "table" then
                    db.overrides[frameName] = DeepCopy(ov)
                    importedOverrides = importedOverrides + 1
                else
                    -- Merge without clobbering any overrides already set in FGO.
                    for k, v in pairs(ov) do
                        if db.overrides[frameName][k] == nil then
                            db.overrides[frameName][k] = DeepCopy(v)
                        end
                    end
                    importedOverrides = importedOverrides + 1
                end
            end
        end
    end

    if type(src.seen) == "table" then
        for k, v in pairs(src.seen) do
            if db.seen[k] == nil then
                db.seen[k] = v
            end
        end
    end

    -- If FGO textures DB was fresh (no widgets yet), inherit ArtLayer's debug flag.
    if imported > 0 and wasEmptyBeforeImport and src.debug ~= nil then
        db.debug = src.debug and true or false
    end

    if imported > 0 or importedOverrides > 0 then
        db.migratedFromArtLayer = true
        db.migratedFromArtLayerAt = time and time() or 0
        local extra = {}
        if renamed > 0 then extra[#extra + 1] = string.format("%d renamed", renamed) end
        if importedOverrides > 0 then extra[#extra + 1] = string.format("%d overrides", importedOverrides) end
        local extraText = (#extra > 0) and (" (" .. table.concat(extra, ", ") .. ")") or ""
        Print(string.format("Imported %d ArtLayer widget(s) into FGO Textures%s. You can disable ArtLayer now.", imported, extraText))
        return true
    end

    if not _fgoTexturesMigrationNotified then
        _fgoTexturesMigrationNotified = true
        Print("Textures: ArtLayer DB was found, but there was nothing to import.")
    end

    return false
end

local function DebugPrint(msg)
    local db = EnsureDB()
    if not (db and db.debug) then
        return
    end
    Print("|cffbbbbbbDBG:|r " .. tostring(msg))
end

local function SafeCall(obj, method, ...)
    if not obj then return false end
    local fn = obj[method]
    if type(fn) ~= "function" then return false end
    local ok = pcall(fn, obj, ...)
    return ok
end

-- -----------------------------------------------------------------------------
-- Overrides / inspector (ported from ArtLayer)
-- -----------------------------------------------------------------------------

local function GetFramePath(frame, maxDepth)
    maxDepth = maxDepth or 8
    if not frame then return "<nil>" end
    local out = {}
    local cur = frame
    for _ = 1, maxDepth do
        if not cur then break end
        local n = cur.GetName and cur:GetName()
        out[#out + 1] = n or ("<" .. tostring(cur) .. ">")
        cur = cur.GetParent and cur:GetParent() or nil
    end
    return table.concat(out, " <- ")
end

local function DescribeFrame(frame)
    if not frame then
        Print("No frame")
        return
    end

    local name = frame.GetName and frame:GetName() or nil
    local strata = frame.GetFrameStrata and frame:GetFrameStrata() or "?"
    local level = frame.GetFrameLevel and frame:GetFrameLevel() or "?"
    local shown = frame.IsShown and frame:IsShown() and "shown" or "hidden"

    Print(string.format("Frame: %s (%s) strata=%s level=%s", name or tostring(frame), shown, tostring(strata), tostring(level)))
    Print("Path: " .. GetFramePath(frame))

    if frame.GetRegions then
        local regions = { frame:GetRegions() }
        local count = 0
        for i = 1, #regions do
            local r = regions[i]
            if r and r.GetObjectType then
                local typ = r:GetObjectType()
                local rname = r.GetName and r:GetName() or ""
                if r.GetDrawLayer then
                    local layer, sub = r:GetDrawLayer()
                    Print(string.format("  Region %d: %s %s layer=%s sub=%s", i, typ, rname, tostring(layer), tostring(sub)))
                else
                    Print(string.format("  Region %d: %s %s", i, typ, rname))
                end
                count = count + 1
                if count >= 12 then
                    Print("  ...")
                    break
                end
            end
        end
    end
end

local function ApplyOverrides()
    local db = EnsureDB()
    for frameName, ov in pairs(db.overrides or {}) do
        local f = _G and _G[frameName] or nil
        if f and type(ov) == "table" then
            if ov.strata then
                SafeCall(f, "SetFrameStrata", ov.strata)
            end
            if ov.level then
                SafeCall(f, "SetFrameLevel", ov.level)
            end
        end
    end
end

local function GetFocusFrame()
    if GetMouseFocus then
        local f = GetMouseFocus()
        if f then return f end
    end
    return nil
end

local function SetOverrideOnFocus(kind, value)
    local f = GetFocusFrame()
    if not f then
        Print("No mouse focus frame")
        return
    end
    local name = f.GetName and f:GetName()
    if not name then
        Print("Focused frame has no name; cannot persist override")
        return
    end

    local db = EnsureDB()
    db.overrides = db.overrides or {}
    db.overrides[name] = db.overrides[name] or {}
    db.overrides[name][kind] = value
    ApplyOverrides()
    DescribeFrame(f)
end

local function ClearOverrideOnFocus()
    local f = GetFocusFrame()
    if not f then
        Print("No mouse focus frame")
        return
    end
    local name = f.GetName and f:GetName()
    if not name then
        Print("Focused frame has no name")
        return
    end

    local db = EnsureDB()
    if db.overrides and db.overrides[name] then
        db.overrides[name] = nil
        Print("Cleared override for " .. name)
        ApplyOverrides()
    else
        Print("No override for " .. name)
    end
end

local function Clamp(v, minV, maxV)
    v = tonumber(v)
    if not v then return minV end
    if minV and v < minV then return minV end
    if maxV and v > maxV then return maxV end
    return v
end

local function NormalizeTexturePath(tex)
    tex = tostring(tex or "")
    tex = tex:gsub("/", "\\")
    tex = tex:gsub("\\+", "\\")
    tex = tex:gsub("%.tga$", ""):gsub("%.blp$", "")
    tex = tex:gsub("^Interface\\Addons\\", "Interface\\AddOns\\")

    if tex:match("^[Aa]dd[Oo]ns\\") then
        tex = "Interface\\" .. tex
    end

    -- Back-compat with ArtLayer paths.
    -- ArtLayer has been merged into FGO; resolve its old addon-relative paths into FGO textures.
    if tex:match("^[Ff][Rr]0[zZ]3[nN][Uu][Ii]_[Aa]rt[Ll]ayer\\") then
        tex = "Interface\\AddOns\\fr0z3nUI_GameOptions\\textures\\" .. tex:gsub("^[Ff][Rr]0[zZ]3[nN][Uu][Ii]_[Aa]rt[Ll]ayer\\", "")
    end

    if tex:match("^Interface\\AddOns\\fr0z3nUI_ArtLayer\\media\\") then
        tex = tex:gsub("^Interface\\AddOns\\fr0z3nUI_ArtLayer\\media\\", "Interface\\AddOns\\fr0z3nUI_GameOptions\\textures\\")
    end

    if tex == "" then return "" end
    if tex:find("^Interface\\") then
        return tex
    end

    -- Accept bare filenames or Textures\foo.tga or textures\foo.tga
    tex = tex:gsub("^[Tt]extures\\", "")
    return "Interface\\AddOns\\fr0z3nUI_GameOptions\\textures\\" .. tex
end

-- -----------------------------------------------------------------------------
-- Widgets: texture/model overlays with simple conditions
-- -----------------------------------------------------------------------------

local WIDGET_ROOT
local widgetFrames = {}

local function EnsureRoot()
    if WIDGET_ROOT then return end
    WIDGET_ROOT = CreateFrame("Frame", "FGO_Textures_Root", UIParent)
    WIDGET_ROOT:SetAllPoints(UIParent)
    WIDGET_ROOT:Hide()
end

local function PlayerFaction()
    if UnitFactionGroup then
        local f = UnitFactionGroup("player")
        return f
    end
    return nil
end

local function NormalizeRealmForKey(realm)
    realm = tostring(realm or "")
    -- Normalize like Blizzard realms (strip spaces/punct so "Area 52" matches "Area52").
    realm = realm:gsub("[^%w]", "")
    return realm
end

local function GetPlayerKey()
    if not UnitName then return nil end
    local name, realm
    if UnitFullName then
        name, realm = UnitFullName("player")
    end

    if (not name or name == "") and UnitName then
        name = UnitName("player")
    end
    if not name or name == "" then return nil end
    realm = realm and realm ~= "" and realm or (GetNormalizedRealmName and GetNormalizedRealmName()) or (GetRealmName and GetRealmName() or "")
    realm = NormalizeRealmForKey(realm)
    return name .. "-" .. realm
end

local function RecordSeen()
    local db = EnsureDB()
    local key = GetPlayerKey()
    if not key then return end
    db.seen[key] = time and time() or 0
end

local function HasMail()
    if HasNewMail then
        return HasNewMail() and true or false
    end
    return false
end

local function SplitCSV(s)
    s = tostring(s or "")
    local out = {}
    for part in s:gmatch("[^,]+") do
        part = part:gsub("^%s+", ""):gsub("%s+$", "")
        if part ~= "" then out[#out + 1] = part end
    end
    return out
end

local function IsInCombat()
    if InCombatLockdown then
        return InCombatLockdown() and true or false
    end
    if UnitAffectingCombat then
        return UnitAffectingCombat("player") and true or false
    end
    return false
end

local function ConditionSeen(db, cond)
    local list = cond.list or {}
    local ignoreRealm = cond.ignoreRealm and true or false

    for _, who in ipairs(list) do
        who = tostring(who or "")
        if who ~= "" then
            if ignoreRealm then
                for key in pairs(db.seen) do
                    local n = key:match("^([^-]+)") or key
                    if n:lower() == who:lower() then
                        return true
                    end
                end
            else
                for key in pairs(db.seen) do
                    if key:lower() == who:lower() then
                        return true
                    end
                end
                for key in pairs(db.seen) do
                    local n = key:match("^([^-]+)") or key
                    if n:lower() == who:lower() then
                        return true
                    end
                end
            end
        end
    end
    return false
end

local function ConditionPlayer(cond)
    local key = GetPlayerKey()
    if not key then return false end

    local playerName = key:match("^([^-]+)") or key
    local playerRealm = key:match("-([^-]+)$") or ""
    local playerRealmNorm = NormalizeRealmForKey(playerRealm)

    local list = cond and cond.list
    if type(list) == "string" then
        list = SplitCSV(list)
    end
    if type(list) ~= "table" then return false end

    local ignoreRealm = (cond and cond.ignoreRealm) and true or false
    if ignoreRealm then
        local nameOnly = playerName
        for _, who in ipairs(list) do
            who = tostring(who or "")
            who = who:gsub("^%s+", ""):gsub("%s+$", "")
            if who ~= "" and nameOnly:lower() == who:lower() then
                return true
            end
        end
        return false
    end

    for _, who in ipairs(list) do
        who = tostring(who or "")
        who = who:gsub("^%s+", ""):gsub("%s+$", "")
        if who ~= "" then
            -- Accept exact normalized key match
            if key:lower() == who:lower() then
                return true
            end

            -- Accept Name-Realm even if realm formatting differs (spaces/apostrophes/etc).
            do
                local n, r = who:match("^([^-]+)%-(.+)$")
                if n and r then
                    local rn = NormalizeRealmForKey(r)
                    if n:lower() == playerName:lower() and rn ~= "" and rn:lower() == playerRealmNorm:lower() then
                        return true
                    end
                end
            end

            -- Convenience: also accept name-only in the list, even when ignoreRealm=false.
            local nameOnly = playerName
            if nameOnly:lower() == who:lower() then
                return true
            end
        end
    end
    return false
end

local function IsQuestCompleted(questID)
    questID = tonumber(questID)
    if not questID then return false end
    if C_QuestLog and C_QuestLog.IsQuestFlaggedCompleted then
        return C_QuestLog.IsQuestFlaggedCompleted(questID) and true or false
    end
    if IsQuestFlaggedCompleted then
        return IsQuestFlaggedCompleted(questID) and true or false
    end
    return false
end

local function EvaluateWidget(db, widget)
    if widget.enabled == false then return false, "disabled" end
    local conds = widget.conds
    if type(conds) ~= "table" then return true, nil end

    for _, c in ipairs(conds) do
        if c.type == "faction" then
            local want = tostring(c.value or "")
            local have = PlayerFaction() or ""
            if want ~= "" and have ~= want then return false, "faction" end
        elseif c.type == "seen" then
            if not ConditionSeen(db, c) then return false, "seen" end
        elseif c.type == "mail" then
            if not HasMail() then return false, "mail" end
        elseif c.type == "combat" then
            local want = tostring(c.value or "in")
            local inCombat = IsInCombat()
            if want == "in" and not inCombat then return false, "combat(in)" end
            if want == "out" and inCombat then return false, "combat(out)" end
        elseif c.type == "player" then
            if not ConditionPlayer(c) then return false, "player" end
        elseif c.type == "questCompleteHide" then
            if IsQuestCompleted(c.id) then return false, "questComplete" end
        end
    end

    return true, nil
end

local function ApplyWidgetFrameProps(frame, widget)
    if not (frame and widget) then return end

    local scale = Clamp(tonumber(widget.scale) or 1, 0.05, 10)
    if frame.SetScale then
        frame:SetScale(scale)
    end

    local clickthrough = (widget.clickthrough ~= nil) and (widget.clickthrough and true or false) or true
    if frame.EnableMouse then
        if frame._fgoForceShow then
            frame:EnableMouse(true)
        else
            frame:EnableMouse(not clickthrough)
        end
    end

    local w = Clamp(tonumber(widget.w) or 128, 1, 4096)
    local h = Clamp(tonumber(widget.h) or 128, 1, 4096)
    frame:SetSize(w, h)

    frame:ClearAllPoints()
    local p = widget.point or "CENTER"
    local x = tonumber(widget.x) or 0
    local y = tonumber(widget.y) or 0
    frame:SetPoint(p, UIParent, p, x, y)

    if frame.SetFrameStrata and widget.strata then
        SafeCall(frame, "SetFrameStrata", widget.strata)
    end
    if frame.SetFrameLevel and widget.level then
        SafeCall(frame, "SetFrameLevel", tonumber(widget.level) or 1)
    end

    local a = Clamp(tonumber(widget.alpha) or 1, 0, 1)
    if widget.type == "model" then
        if frame.model and frame.model.SetAlpha then
            frame.model:SetAlpha(a)
        end
    else
        if frame.tex then
            if frame.tex.SetAlpha then frame.tex:SetAlpha(a) end
            if frame.tex.SetBlendMode then
                SafeCall(frame.tex, "SetBlendMode", widget.blend or "BLEND")
            end
            if widget.layer and frame.tex.SetDrawLayer then
                SafeCall(frame.tex, "SetDrawLayer", widget.layer, tonumber(widget.sub) or 0)
            end
        end
    end

    DebugPrint(string.format("Props %s: size=%dx%d alpha=%.2f scale=%.2f point=%s x=%.1f y=%.1f",
        tostring(widget.key or "?"), tonumber(w) or 0, tonumber(h) or 0, tonumber(a) or 0, tonumber(scale) or 0, tostring(p), tonumber(x) or 0, tonumber(y) or 0))
end

local function ModelSetRotation(modelFrame, rotation)
    if not modelFrame then return end
    rotation = tonumber(rotation) or 0
    if modelFrame.SetFacing then
        modelFrame:SetFacing(rotation)
        return
    end
    if modelFrame.SetRotation then
        modelFrame:SetRotation(rotation)
    end
end

local function ModelApplyZoom(modelFrame, zoom)
    if not modelFrame then return end
    zoom = tonumber(zoom)
    if zoom == nil then return end
    if modelFrame.SetCamDistanceScale then
        modelFrame:SetCamDistanceScale(zoom)
        return
    end
    if modelFrame.SetPortraitZoom then
        modelFrame:SetPortraitZoom(zoom)
        return
    end
    if modelFrame.SetModelScale then
        modelFrame:SetModelScale(zoom)
    end
end

local function ModelApplyAnimation(modelFrame, anim)
    if not modelFrame then return end
    anim = tonumber(anim)
    if anim == nil then return end
    if modelFrame.SetAnimation then
        modelFrame:SetAnimation(anim)
    end
end

local function ApplyModelSpec(modelFrame, spec)
    if not (modelFrame and spec) then return end
    if modelFrame.ClearModel then modelFrame:ClearModel() end

    local kind = tostring(spec.kind or "player"):lower()
    local id = spec.id

    if kind == "player" then
        if modelFrame.SetUnit then
            modelFrame:SetUnit("player")
        end
    elseif kind == "npc" or kind == "creature" then
        local npcID = tonumber(id)
        if npcID and modelFrame.SetCreature then
            modelFrame:SetCreature(npcID)
        end
    elseif kind == "display" then
        local displayID = tonumber(id)
        if displayID and modelFrame.SetDisplayInfo then
            modelFrame:SetDisplayInfo(displayID)
        end
    elseif kind == "file" then
        local fileID = tonumber(id)
        if fileID and modelFrame.SetModelByFileID then
            modelFrame:SetModelByFileID(fileID)
        end
    end

    if spec.rotation ~= nil then ModelSetRotation(modelFrame, spec.rotation) end
    if spec.zoom ~= nil then ModelApplyZoom(modelFrame, spec.zoom) end
    if spec.anim ~= nil then ModelApplyAnimation(modelFrame, spec.anim) end
end

local function CreateWidgetFrame(key, widget)
    EnsureRoot()
    local f
    if widget and widget.type == "model" then
        f = CreateFrame("Frame", nil, WIDGET_ROOT)
        local m = CreateFrame("DressUpModel", nil, f)
        m:SetAllPoints(f)
        if m.EnableMouse then m:EnableMouse(false) end
        f.model = m
    else
        f = CreateFrame("Frame", nil, WIDGET_ROOT)
        local t = f:CreateTexture(nil, "ARTWORK")
        t:SetAllPoints(f)
        f.tex = t
    end
    widgetFrames[key] = f
    return f
end

local function GetOrCreateWidgetFrame(key, widget)
    local f = widgetFrames[key]
    if not f then
        f = CreateWidgetFrame(key, widget)
    else
        -- If a widget's type changes (or was imported differently), recreate the backing frame.
        if widget and widget.type == "model" and not f.model then
            RemoveWidgetFrame(key)
            f = CreateWidgetFrame(key, widget)
        elseif widget and widget.type ~= "model" and not f.tex then
            RemoveWidgetFrame(key)
            f = CreateWidgetFrame(key, widget)
        end
    end
    return f
end

local function RemoveWidgetFrame(key)
    key = tostring(key or "")
    local f = widgetFrames and widgetFrames[key] or nil
    if not f then return end
    if f.tex and f.tex.SetTexture then
        pcall(f.tex.SetTexture, f.tex, nil)
    end
    if f.model and f.model.ClearModel then
        pcall(f.model.ClearModel, f.model)
    end
    if f.Hide then f:Hide() end
    widgetFrames[key] = nil
end

local function ApplyWidget(key)
    local db = EnsureDB()
    local w = db.widgets[key]
    if type(w) ~= "table" then return end

    w.key = key
    w.type = w.type or "texture"
    if w.enabled == nil then w.enabled = true end
    if w.scale == nil then w.scale = 1 end
    if w.clickthrough == nil then w.clickthrough = true end
    if w.type ~= "model" and w.blend == nil then w.blend = "BLEND" end

    if w.type == "model" then
        w.model = w.model or {}
        w.model.kind = tostring(w.model.kind or "player"):lower()
        if w.model.kind == "player" then
            w.model.id = nil
        else
            w.model.id = tonumber(w.model.id)
        end
        if w.model.zoom == nil then w.model.zoom = 1.0 end
        if w.model.rotation == nil then w.model.rotation = 0 end
    end

    local frame = GetOrCreateWidgetFrame(key, w)
    ApplyWidgetFrameProps(frame, w)

    if w.type == "model" then
        if frame.model then
            local ok, err = pcall(ApplyModelSpec, frame.model, w.model or {})
            if not ok then
                DebugPrint(string.format("ApplyModelSpec failed for %s: %s", tostring(key), tostring(err)))
            end
        end
    else
        local texPath = NormalizeTexturePath(w.texture)
        if frame.tex and texPath and texPath ~= "" then
            local ok, err = pcall(frame.tex.SetTexture, frame.tex, texPath)
            if not ok then
                DebugPrint(string.format("SetTexture failed for %s: %s", tostring(key), tostring(err)))
            else
                DebugPrint(string.format("Texture %s -> %s", tostring(key), tostring(texPath)))
            end
        else
            DebugPrint(string.format("Texture %s has empty path (raw=%s)", tostring(key), tostring(w.texture)))
        end
    end

    local show, reason = EvaluateWidget(db, w)
    if frame._fgoForceShow then
        show = true
    end
    if show then
        frame:Show()
        if WIDGET_ROOT and not WIDGET_ROOT:IsShown() then WIDGET_ROOT:Show() end
        DebugPrint(string.format("Widget %s shown", tostring(key)))
    else
        frame:Hide()
        DebugPrint(string.format("Widget %s hidden (%s)", tostring(key), tostring(reason or "conditions")))
    end
end

local function ApplyAllWidgets()
    local db = EnsureDB()
    local anyShown = false

    for key in pairs(db.widgets) do
        ApplyWidget(key)
        local f = widgetFrames[key]
        if f and f.IsShown and f:IsShown() then anyShown = true end
    end

    for key, f in pairs(widgetFrames) do
        if not (db.widgets and db.widgets[key]) then
            if f and f.Hide then f:Hide() end
        end
    end

    if WIDGET_ROOT then
        if anyShown then WIDGET_ROOT:Show() else WIDGET_ROOT:Hide() end
    end
end

-- Public API for UI
ns.Textures.Print = Print
ns.Textures.InitSV = InitSV
ns.Textures.EnsureDB = EnsureDB
ns.Textures.NormalizeTexturePath = NormalizeTexturePath
ns.Textures.ApplyWidget = ApplyWidget
ns.Textures.ApplyAllWidgets = ApplyAllWidgets
ns.Textures.GetWidgetFrame = function(key)
    return widgetFrames and widgetFrames[key] or nil
end
ns.Textures.RemoveWidgetFrame = RemoveWidgetFrame
ns.Textures.RecordSeen = RecordSeen
ns.Textures.ApplyOverrides = ApplyOverrides
ns.Textures.DescribeFrame = DescribeFrame

-- -----------------------------------------------------------------------------
-- Event re-evaluation
-- -----------------------------------------------------------------------------

local ev = CreateFrame("Frame")
ev:RegisterEvent("PLAYER_LOGIN")
ev:RegisterEvent("PLAYER_ENTERING_WORLD")
ev:RegisterEvent("PLAYER_REGEN_DISABLED")
ev:RegisterEvent("PLAYER_REGEN_ENABLED")
ev:RegisterEvent("UPDATE_PENDING_MAIL")
ev:RegisterEvent("QUEST_TURNED_IN")
ev:RegisterEvent("QUEST_LOG_UPDATE")
ev:SetScript("OnEvent", function(_, event)
    if event == "PLAYER_LOGIN" then
        EnsureDB()
        TryMigrateFromArtLayer()
        RecordSeen()
        ApplyOverrides()
        ApplyAllWidgets()
        return
    end

    ApplyAllWidgets()
end)

-- -----------------------------------------------------------------------------
-- Slash command surface (ported from ArtLayer) under: /fgo textures ...
-- -----------------------------------------------------------------------------

local function Status()
    local db = EnsureDB()
    local wCount = 0
    for _ in pairs(db.widgets or {}) do wCount = wCount + 1 end
    local oCount = 0
    for _ in pairs(db.overrides or {}) do oCount = oCount + 1 end
    Print(string.format("Textures status: widgets=%d overrides=%d debug=%s", wCount, oCount, db.debug and "on" or "off"))
    if WIDGET_ROOT and WIDGET_ROOT.IsShown then
        Print("Root: " .. (WIDGET_ROOT:IsShown() and "shown" or "hidden"))
    else
        Print("Root: <not created yet>")
    end
end

local function WipeWidgets()
    local db = EnsureDB()
    db.widgets = {}
    for key in pairs(widgetFrames) do
        RemoveWidgetFrame(key)
    end
    widgetFrames = {}
    if WIDGET_ROOT and WIDGET_ROOT.Hide then
        WIDGET_ROOT:Hide()
    end
    Print("Wiped all texture/model widgets")
end

local function WipeAll()
    local db = EnsureDB()
    WipeWidgets()
    db.overrides = {}
    db.seen = {}
    Print("Wiped widgets + overrides + seen list")
end

local function AddWidgetTexture(key, tex)
    local db = EnsureDB()
    key = tostring(key or "")
    if key == "" then
        Print("Usage: /fgo textures widgets add texture <key> <file.tga|textures\\file.tga|Interface\\...>")
        return
    end
    db.widgets[key] = db.widgets[key] or {}
    local w = db.widgets[key]
    w.type = "texture"
    w.enabled = true
    w.texture = tex
    w.w = w.w or 128
    w.h = w.h or 128
    w.point = w.point or "CENTER"
    w.x = w.x or 0
    w.y = w.y or 0
    w.alpha = w.alpha or 1
    w.scale = w.scale or 1
    if w.clickthrough == nil then w.clickthrough = true end
    w.layer = w.layer or "ARTWORK"
    w.sub = w.sub or 0
    w.blend = w.blend or "BLEND"
    w.conds = w.conds or {}
    ApplyWidget(key)
    Print("Added texture widget: " .. key)
end

local function AddWidgetModel(key, kind, id)
    local db = EnsureDB()
    key = tostring(key or "")
    if key == "" then
        Print("Usage: /fgo textures widgets add model <key> <player|npc|display|file> [id]")
        return
    end
    db.widgets[key] = db.widgets[key] or {}
    local w = db.widgets[key]
    w.type = "model"
    w.enabled = true
    w.w = w.w or 160
    w.h = w.h or 160
    w.point = w.point or "CENTER"
    w.x = w.x or 0
    w.y = w.y or 0
    w.alpha = w.alpha or 1
    w.scale = w.scale or 1
    if w.clickthrough == nil then w.clickthrough = true end
    w.conds = w.conds or {}
    w.model = w.model or {}
    w.model.kind = tostring(kind or "player"):lower()
    w.model.id = (w.model.kind == "player") and nil or tonumber(id)
    w.model.zoom = w.model.zoom or 1.0
    w.model.rotation = w.model.rotation or 0
    ApplyWidget(key)
    Print("Added model widget: " .. key)
end

local function SetWidgetSize(key, w, h)
    local db = EnsureDB()
    local wd = db.widgets[key]
    if type(wd) ~= "table" then Print("Unknown widget: " .. tostring(key)) return end
    wd.w = tonumber(w) or wd.w
    wd.h = tonumber(h) or wd.h
    ApplyWidget(key)
end

local function SetWidgetPos(key, point, x, y)
    local db = EnsureDB()
    local wd = db.widgets[key]
    if type(wd) ~= "table" then Print("Unknown widget: " .. tostring(key)) return end
    wd.point = tostring(point or "CENTER")
    wd.x = tonumber(x) or 0
    wd.y = tonumber(y) or 0
    ApplyWidget(key)
end

local function SetWidgetAlpha(key, a)
    local db = EnsureDB()
    local wd = db.widgets[key]
    if type(wd) ~= "table" then Print("Unknown widget: " .. tostring(key)) return end
    wd.alpha = Clamp(a, 0, 1)
    ApplyWidget(key)
end

local function SetWidgetStrata(key, strata)
    local db = EnsureDB()
    local wd = db.widgets[key]
    if type(wd) ~= "table" then Print("Unknown widget: " .. tostring(key)) return end
    wd.strata = tostring(strata or ""):upper()
    ApplyWidget(key)
end

local function SetWidgetLevel(key, level)
    local db = EnsureDB()
    local wd = db.widgets[key]
    if type(wd) ~= "table" then Print("Unknown widget: " .. tostring(key)) return end
    wd.level = tonumber(level) or wd.level
    ApplyWidget(key)
end

local function SetWidgetLayer(key, layer, sub)
    local db = EnsureDB()
    local wd = db.widgets[key]
    if type(wd) ~= "table" then Print("Unknown widget: " .. tostring(key)) return end
    wd.layer = tostring(layer or "ARTWORK"):upper()
    wd.sub = tonumber(sub) or 0
    ApplyWidget(key)
end

local function ToggleWidget(key)
    local db = EnsureDB()
    local wd = db.widgets[key]
    if type(wd) ~= "table" then Print("Unknown widget: " .. tostring(key)) return end
    wd.enabled = not (wd.enabled == false)
    ApplyWidget(key)
    Print(string.format("Widget %s: %s", key, wd.enabled and "enabled" or "disabled"))
end

local function WidgetCondClear(key)
    local db = EnsureDB()
    local wd = db.widgets[key]
    if type(wd) ~= "table" then Print("Unknown widget: " .. tostring(key)) return end
    wd.conds = {}
    ApplyWidget(key)
    Print("Cleared conditions for " .. key)
end

local function WidgetCondAddFaction(key, faction)
    local db = EnsureDB()
    local wd = db.widgets[key]
    if type(wd) ~= "table" then Print("Unknown widget: " .. tostring(key)) return end
    wd.conds = wd.conds or {}
    table.insert(wd.conds, { type = "faction", value = tostring(faction or "") })
    ApplyWidget(key)
    Print("Added faction condition to " .. key)
end

local function WidgetCondAddSeen(key, csv, ignoreRealm)
    local db = EnsureDB()
    local wd = db.widgets[key]
    if type(wd) ~= "table" then Print("Unknown widget: " .. tostring(key)) return end
    wd.conds = wd.conds or {}
    table.insert(wd.conds, { type = "seen", list = SplitCSV(csv), ignoreRealm = ignoreRealm and true or false })
    ApplyWidget(key)
    Print("Added seen condition to " .. key)
end

local function WidgetCondAddMail(key)
    local db = EnsureDB()
    local wd = db.widgets[key]
    if type(wd) ~= "table" then Print("Unknown widget: " .. tostring(key)) return end
    wd.conds = wd.conds or {}
    table.insert(wd.conds, { type = "mail" })
    ApplyWidget(key)
    Print("Added mail condition to " .. key)
end

local function WidgetCondAddCombat(key, mode)
    local db = EnsureDB()
    local wd = db.widgets[key]
    if type(wd) ~= "table" then Print("Unknown widget: " .. tostring(key)) return end
    wd.conds = wd.conds or {}
    mode = tostring(mode or "in"):lower()
    if mode ~= "in" and mode ~= "out" then mode = "in" end
    table.insert(wd.conds, { type = "combat", value = mode })
    ApplyWidget(key)
    Print("Added combat condition to " .. key)
end

local function ListWidgets()
    local db = EnsureDB()
    Print("Textures widgets:")
    local n = 0
    for key, w in pairs(db.widgets or {}) do
        n = n + 1
        local f = widgetFrames[key]
        local vis = (f and f.IsShown and f:IsShown()) and "shown" or "hidden"
        Print(string.format("- %s (%s) %s", key, tostring((type(w) == "table" and w.type) or "?"), vis))
    end
    if n == 0 then Print("(none)") end
end

local function SeenList()
    local db = EnsureDB()
    Print("Seen characters:")
    local n = 0
    for key, t in pairs(db.seen or {}) do
        n = n + 1
        Print(string.format("- %s (%s)", key, tostring(t)))
    end
    if n == 0 then Print("(none)") end
end

local function SeenClear()
    local db = EnsureDB()
    db.seen = {}
    Print("Cleared seen list")
    ApplyAllWidgets()
end

local function PrintHelp()
    Print("/fgo textures                - (no longer routed; use /fgo to open the UI)")
    Print("/fgo textures migrate reset  - clears migration flag and re-imports from ArtLayer (if enabled)")
    Print("/fgo textures migrate replace - wipes current widgets, then re-imports from ArtLayer (if enabled)")
    Print("/fgo textures inspect        - prints info about the frame under your cursor")
    Print("/fgo textures strata <STRATA> - sets strata override on focused frame")
    Print("/fgo textures level <NUM>    - sets level override on focused frame")
    Print("/fgo textures clear          - clears saved override for focused frame")
    Print("/fgo textures widgets list")
    Print("/fgo textures widgets add texture <key> <file.tga|textures\\file.tga|Interface\\...>")
    Print("/fgo textures widgets add model <key> <player|npc|display|file> [id]")
    Print("/fgo textures widgets toggle <key>")
    Print("/fgo textures widgets set <key> size <w> <h>")
    Print("/fgo textures widgets set <key> pos <point> <x> <y>")
    Print("/fgo textures widgets set <key> alpha <0-1>")
    Print("/fgo textures widgets set <key> strata <strata>")
    Print("/fgo textures widgets set <key> level <number>")
    Print("/fgo textures widgets set <key> layer <ARTWORK|OVERLAY|BACKGROUND|BORDER> [sub]")
    Print("/fgo textures widgets cond <key> clear")
    Print("/fgo textures widgets cond <key> add faction <Alliance|Horde>")
    Print("/fgo textures widgets cond <key> add seen <Name1,Name2,...> [norealm]")
    Print("/fgo textures widgets cond <key> add mail")
    Print("/fgo textures widgets cond <key> add combat <in|out>")
    Print("/fgo textures seen list")
    Print("/fgo textures seen clear")
    Print("/fgo textures status")
    Print("/fgo textures debug          - toggles Textures debug logging")
    Print("/fgo textures wipe widgets   - deletes all texture/model widgets")
    Print("/fgo textures wipe all       - deletes widgets + overrides + seen")
end

function ns.Textures.HandleSlash(msg)
    EnsureDB()
    msg = tostring(msg or "")
    msg = msg:gsub("^%s+", ""):gsub("%s+$", "")

    if msg == "" then
        PrintHelp()
        return
    end

    local cmd, rest = msg:match("^(%S+)%s*(.-)$")
    cmd = (cmd and cmd:lower()) or ""

    if cmd == "help" or cmd == "?" then
        PrintHelp()
        return
    end

    if cmd == "status" then
        Status()
        return
    end

    if cmd == "debug" then
        local db = EnsureDB()
        db.debug = not (db.debug and true or false)
        Print("Textures debug: " .. (db.debug and "ON" or "OFF"))
        Status()
        return
    end

    if cmd == "migrate" or cmd == "migration" then
        local sub = tostring(rest or ""):match("^(%S+)")
        sub = (sub and sub:lower()) or ""
        if sub == "reset" or sub == "redo" or sub == "reimport" then
            local db = EnsureDB()
            db.migratedFromArtLayer = nil
            db.migratedFromArtLayerAt = nil
            _fgoTexturesMigrationNotified = false
            Print("Textures: migration flag cleared; attempting ArtLayer import now...")
            TryMigrateFromArtLayer()
            ApplyAllWidgets()
            Status()
            return
        end
        if sub == "replace" or sub == "wipe" or sub == "fresh" then
            local db = EnsureDB()
            db.migratedFromArtLayer = nil
            db.migratedFromArtLayerAt = nil
            _fgoTexturesMigrationNotified = false
            Print("Textures: wiping current widgets, then attempting ArtLayer import...")
            WipeWidgets()
            TryMigrateFromArtLayer()
            ApplyAllWidgets()
            Status()
            return
        end
        Print("Usage: /fgo textures migrate reset")
        return
    end

    if cmd == "wipe" or cmd == "reset" then
        local what = tostring(rest or ""):lower()
        if what == "widgets" or what == "widget" then
            WipeWidgets()
            return
        end
        if what == "all" or what == "db" or what == "database" then
            WipeAll()
            return
        end
        Print("Usage: /fgo textures wipe widgets|all")
        return
    end

    if cmd == "inspect" then
        DescribeFrame(GetFocusFrame())
        return
    end

    if cmd == "strata" then
        local v = tostring(rest or ""):upper()
        if v == "" then
            Print("Usage: /fgo textures strata <STRATA>")
            return
        end
        SetOverrideOnFocus("strata", v)
        return
    end

    if cmd == "level" then
        local n = tonumber(rest)
        if not n then
            Print("Usage: /fgo textures level <number>")
            return
        end
        SetOverrideOnFocus("level", math.floor(n))
        return
    end

    if cmd == "clear" then
        ClearOverrideOnFocus()
        return
    end

    -- UI opening is intentionally not handled here. Use /fgo to open the options window.

    if cmd == "seen" then
        local sub = tostring(rest or ""):match("^(%S+)")
        sub = (sub and sub:lower()) or ""
        if sub == "list" then
            SeenList()
            return
        elseif sub == "clear" then
            SeenClear()
            return
        end
        Print("Usage: /fgo textures seen list|clear")
        return
    end

    if cmd == "widgets" or cmd == "widget" then
        local sub, rest2 = tostring(rest or ""):match("^(%S+)%s*(.-)$")
        sub = (sub and sub:lower()) or ""

        if sub == "list" then
            ListWidgets()
            return
        end

        if sub == "add" then
            local typ, rest3 = tostring(rest2 or ""):match("^(%S+)%s*(.-)$")
            typ = (typ and typ:lower()) or ""
            if typ == "texture" then
                local key, tex = tostring(rest3 or ""):match("^(%S+)%s*(.-)$")
                AddWidgetTexture(key, tex)
                return
            elseif typ == "model" then
                local key, kind, id = tostring(rest3 or ""):match("^(%S+)%s*(%S+)%s*(.-)$")
                AddWidgetModel(key, kind, id)
                return
            end
            Print("Usage: /fgo textures widgets add texture <key> <file.tga> OR /fgo textures widgets add model <key> <kind> [id]")
            return
        end

        if sub == "toggle" then
            ToggleWidget(tostring(rest2 or ""))
            return
        end

        if sub == "set" then
            local key, field, a, b = tostring(rest2 or ""):match("^(%S+)%s*(%S+)%s*(%S*)%s*(.-)$")
            field = tostring(field or ""):lower()
            if field == "size" then
                SetWidgetSize(key, a, b)
                return
            elseif field == "pos" then
                local point, x, y = tostring(rest2 or ""):match("^%S+%s+pos%s+(%S+)%s+([%-%d%.]+)%s+([%-%d%.]+)%s*$")
                if not point then
                    Print("Usage: /fgo textures widgets set <key> pos <point> <x> <y>")
                    return
                end
                SetWidgetPos(key, point, tonumber(x) or 0, tonumber(y) or 0)
                return
            elseif field == "alpha" then
                SetWidgetAlpha(key, a)
                return
            elseif field == "strata" then
                SetWidgetStrata(key, a)
                return
            elseif field == "level" then
                SetWidgetLevel(key, a)
                return
            elseif field == "layer" then
                SetWidgetLayer(key, a, tonumber(b))
                return
            end
            Print("Usage: /fgo textures widgets set <key> size|pos|alpha|strata|level|layer ...")
            return
        end

        if sub == "cond" then
            local key, rest3 = tostring(rest2 or ""):match("^(%S+)%s*(.-)$")
            local op, rest4 = tostring(rest3 or ""):match("^(%S+)%s*(.-)$")
            op = (op and op:lower()) or ""
            if op == "clear" then
                WidgetCondClear(key)
                return
            end
            if op == "add" then
                local ctype, rest5 = tostring(rest4 or ""):match("^(%S+)%s*(.-)$")
                ctype = (ctype and ctype:lower()) or ""
                if ctype == "faction" then
                    WidgetCondAddFaction(key, rest5)
                    return
                elseif ctype == "seen" then
                    local list, flag = tostring(rest5 or ""):match("^(.-)%s*(%S*)$")
                    WidgetCondAddSeen(key, list, flag and flag:lower() == "norealm")
                    return
                elseif ctype == "mail" then
                    WidgetCondAddMail(key)
                    return
                elseif ctype == "combat" then
                    WidgetCondAddCombat(key, rest5)
                    return
                end
                Print("Usage: /fgo textures widgets cond <key> add faction|seen|mail|combat ...")
                return
            end
            Print("Usage: /fgo textures widgets cond <key> clear|add ...")
            return
        end

        Print("Unknown widgets command. Try /fgo textures help")
        return
    end

    Print("Unknown textures command. Try /fgo textures help")
end
