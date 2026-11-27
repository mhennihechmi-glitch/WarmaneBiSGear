-- Warmane BiS Gear: core, saved settings, item tooltips, slash command, minimap button.
-- Not progressive: one list per spec, always the latest phase.

local ADDON = ...
local W = {}
WarmaneBiSGear = W

W.CLASS_ORDER = { "WARRIOR", "PALADIN", "HUNTER", "ROGUE", "PRIEST", "DEATHKNIGHT", "SHAMAN", "MAGE", "WARLOCK", "DRUID" }
W.SLOT_LABEL = {
    Head = "Head", Neck = "Neck", Shoulder = "Shoulder", Back = "Back", Chest = "Chest",
    Shirt = "Shirt", Tabard = "Tabard", Wrist = "Wrist", MainHand = "Main Hand",
    SecondaryHand = "Off Hand", Hands = "Hands", Waist = "Waist", Legs = "Legs", Feet = "Feet",
    Finger0 = "Ring", Finger1 = "Ring", Trinket0 = "Trinket", Trinket1 = "Trinket", Ranged = "Ranged / Relic",
}

local function classColor(cls)
    local c = RAID_CLASS_COLORS and RAID_CLASS_COLORS[cls]
    if not c then return "|cffffffff" end
    return string.format("|cff%02x%02x%02x", math.floor(c.r * 255 + 0.5), math.floor(c.g * 255 + 0.5), math.floor(c.b * 255 + 0.5))
end
W.classColor = classColor

-- ---------- origin ----------
-- Who made this and where to find them. Kept encoded (twice: here and in
-- UI.lua, two different ways) with a checksum, so it is not one search and
-- replace away. If the copies stop agreeing the addon will not open.
do
    local K = { 83, 17, 201, 9, 144, 61, 230, 5, 118 }
    local E = { 143, 83, 42, 124, 4, 166, 85, 115, 180, 115, 82, 53, 117, 249, 158, 84, 104, 219, 115, 90, 44, 110, 243, 175, 85, 124, 228, 115, 97, 63, 78, 176, 133, 71, 119, 218, 182, 128, 59, 110, 176, 132, 91, 110, 226, 183, 27, 13, 114, 3, 160, 85, 119, 218, 141, 49, 49, 125, 4, 173, 89, 63, 165, 130, 117, 50, 124, 243, 172, 88, 105, 164, 186, 120, 248, 60, 8, 146, 76, 91, 185, 184, 123, 49, 93, 154, 128, 88, 106, 218, 188, 133, 3, 41, 215, 175, 71, 123, 223, 184, 49, 246, 41, 4, 165, 88, 102, 228, 188, 127, 233, 54, 176, 148, 79, 127, 215, 203, 49, 246, 41, 224, 162, 75, 127, 239 }
    local function sum(s)
        local x = 7
        for i = 1, #s do x = (x * 31 + s:byte(i)) % 2147483647 end
        return x
    end
    local t = {}
    for i = 1, #E do t[i] = string.char((E[i] - K[(i - 1) % #K + 1]) % 256) end
    local plain = table.concat(t)
    W._sum = sum
    W._origin = (sum(plain) == 1199689054) and plain or nil
    W._SUM = 1199689054
end
function W:Origin()
    if not self._origin then return nil end
    local lines = {}
    for l in self._origin:gmatch("[^\n]+") do lines[#lines + 1] = l end
    return lines
end
function W:Intact() return self._origin ~= nil and self._originUI == self._origin end
function W:Refuse()
    print("|cffff5050Warmane BiS Gear:|r this copy was modified and is switched off. Get the original from <Bastion> (Icecrown): https://discord.gg/3xUfVCejhT")
end

function W:ClassName(cls)
    return (LOCALIZED_CLASS_NAMES_MALE and LOCALIZED_CLASS_NAMES_MALE[cls]) or cls
end

-- Which specs list an item, by exact item id and by item name (so the
-- normal-mode copy of a heroic BiS item still says something useful).
function W:BuildIndex()
    self.byId, self.byName = {}, {}
    for cls, specs in pairs(WarmaneBiSGear_Data.specs) do
        for _, spec in ipairs(specs) do
            for slot, it in pairs(spec.gear) do
                local e = { cls = cls, spec = spec.name, slot = slot, source = it[6] or it[5] }
                self.byId[it[1]] = self.byId[it[1]] or {}
                table.insert(self.byId[it[1]], e)
                self.byName[it[2]] = self.byName[it[2]] or {}
                table.insert(self.byName[it[2]], e)
            end
        end
    end
end

local function joinSpecs(list)
    local seen, out = {}, {}
    for _, e in ipairs(list) do
        local label = classColor(e.cls) .. e.spec .. " " .. W:ClassName(e.cls) .. "|r"
        if not seen[label] then seen[label] = true; table.insert(out, label) end
    end
    table.sort(out)
    return table.concat(out, ", ")
end

local function addTooltipLines(tt)
    if not W.db or not W.db.tooltip or tt.__wbgDone or not W:Intact() then return end
    local name, link = tt:GetItem()
    if not link then return end
    local id = tonumber(link:match("item:(%d+)"))
    if not id then return end
    tt.__wbgDone = true
    local exact = W.byId[id]
    if exact then
        tt:AddLine("|cff00ccffWarmane BiS:|r " .. joinSpecs(exact), 1, 1, 1, true)
        if exact[1].source then tt:AddLine("|cff8cbfffSource:|r " .. exact[1].source, 1, 1, 1, true) end
    elseif name and W.byName[name] then
        tt:AddLine("|cff7f7f7fWarmane BiS (heroic version):|r " .. joinSpecs(W.byName[name]), 1, 1, 1, true)
        local src = W.byName[name][1].source
        if src then tt:AddLine("|cff8cbfffHeroic version from:|r " .. src, 1, 1, 1, true) end
    else
        return
    end
    tt:Show()
end

function W:HookTooltips()
    for _, tt in ipairs({ GameTooltip, ItemRefTooltip, ShoppingTooltip1, ShoppingTooltip2 }) do
        if tt then
            tt:HookScript("OnTooltipSetItem", addTooltipLines)
            tt:HookScript("OnTooltipCleared", function(self) self.__wbgDone = nil end)
        end
    end
end

-- Hidden tooltip used only to ask the server about items the client has not cached yet.
function W:PrimeItems(spec)
    if not self.scan then
        self.scan = CreateFrame("GameTooltip", "WarmaneBiSGearScanTip", UIParent, "GameTooltipTemplate")
        self.scan:SetOwner(UIParent, "ANCHOR_NONE")
    end
    for _, it in pairs(spec.gear) do
        if not GetItemInfo(it[1]) then
            self.scan:SetOwner(UIParent, "ANCHOR_NONE")
            self.scan:SetHyperlink("item:" .. it[1] .. ":0:0:0:0:0:0:0")
        end
    end
    for _, it in pairs(spec.gear) do
        local list = {}
        for _, g in ipairs(it[8] or {}) do list[#list + 1] = g end
        if it[9] then list[#list + 1] = it[9] end   -- the enchant item (scroll, arcanum ...)
        for _, g in ipairs(list) do
            if not GetItemInfo(g[1]) then
                self.scan:SetOwner(UIParent, "ANCHOR_NONE")
                self.scan:SetHyperlink("item:" .. g[1] .. ":0:0:0:0:0:0:0")
            end
        end
    end
    for _, kind in ipairs({ "major", "minor" }) do
        for _, g in ipairs(spec.glyphs[kind]) do
            if not GetItemInfo(g[1]) then
                self.scan:SetOwner(UIParent, "ANCHOR_NONE")
                self.scan:SetHyperlink("item:" .. g[1] .. ":0:0:0:0:0:0:0")
            end
        end
    end
end

-- Pick the player's own class and the spec whose main tree matches the one
-- they have the most points in.
function W:DefaultSelection()
    local _, cls = UnitClass("player")
    local specs = WarmaneBiSGear_Data.specs[cls]
    if not specs then
        for _, c in ipairs(self.CLASS_ORDER) do
            if WarmaneBiSGear_Data.specs[c] then cls = c; specs = WarmaneBiSGear_Data.specs[c]; break end
        end
        return cls, 1
    end
    local best, bestPts = 1, -1
    for tab = 1, 3 do
        local _, _, pts = GetTalentTabInfo(tab)
        if (pts or 0) > bestPts then best, bestPts = tab, pts or 0 end
    end
    for i, spec in ipairs(specs) do
        if spec.tree == best then return cls, i end
    end
    return cls, 1
end

local function makeMinimapButton()
    local b = CreateFrame("Button", "WarmaneBiSGearMinimapButton", Minimap)
    b:SetWidth(31); b:SetHeight(31); b:SetFrameStrata("MEDIUM"); b:SetFrameLevel(8)
    b:SetHighlightTexture("Interface\\Minimap\\UI-Minimap-ZoomButton-Highlight")
    local icon = b:CreateTexture(nil, "BACKGROUND")
    icon:SetTexture("Interface\\Icons\\INV_Chest_Plate_26")
    icon:SetWidth(20); icon:SetHeight(20); icon:SetPoint("TOPLEFT", 7, -5)
    icon:SetTexCoord(0.08, 0.92, 0.08, 0.92)
    local border = b:CreateTexture(nil, "OVERLAY")
    border:SetTexture("Interface\\Minimap\\MiniMap-TrackingBorder")
    border:SetWidth(53); border:SetHeight(53); border:SetPoint("TOPLEFT")
    local function place()
        local a = math.rad(W.db.minimapAngle or 200)
        b:ClearAllPoints()
        b:SetPoint("CENTER", Minimap, "CENTER", 80 * math.cos(a), 80 * math.sin(a))
    end
    b:RegisterForClicks("LeftButtonUp", "RightButtonUp")
    b:RegisterForDrag("LeftButton")
    b:SetScript("OnDragStart", function(self)
        self:SetScript("OnUpdate", function()
            local mx, my = Minimap:GetCenter()
            local cx, cy = GetCursorPosition()
            local s = Minimap:GetEffectiveScale()
            W.db.minimapAngle = math.deg(math.atan2(cy / s - my, cx / s - mx))
            place()
        end)
    end)
    b:SetScript("OnDragStop", function(self) self:SetScript("OnUpdate", nil) end)
    b:SetScript("OnClick", function() W:Toggle() end)
    b:SetScript("OnEnter", function(self)
        GameTooltip:SetOwner(self, "ANCHOR_LEFT")
        GameTooltip:AddLine("Warmane BiS Gear")
        GameTooltip:AddLine("Click to open. Drag to move.", 1, 1, 1)
        GameTooltip:Show()
    end)
    b:SetScript("OnLeave", function() GameTooltip:Hide() end)
    place()
    if W.db.hideMinimap then b:Hide() end
    W.minimapButton = b
end

function W:Toggle()
    if not self:Intact() then self:Refuse() return end
    if not self.frame then self:CreateUI() end
    if self.frame:IsShown() then self.frame:Hide() else self.frame:Show() end
end

local function findClass(word)
    word = word:lower():gsub("%s", "")
    for _, cls in ipairs(W.CLASS_ORDER) do
        local loc = W:ClassName(cls):lower():gsub("%s", "")
        if cls:lower() == word or loc == word or (word == "dk" and cls == "DEATHKNIGHT") then return cls end
    end
end

SLASH_WARMANEBISGEAR1 = "/bis"
SLASH_WARMANEBISGEAR2 = "/wbis"
SlashCmdList.WARMANEBISGEAR = function(msg)
    msg = (msg or ""):gsub("^%s+", ""):gsub("%s+$", "")
    local lower = msg:lower()
    if lower == "tooltip" then
        W.db.tooltip = not W.db.tooltip
        print("|cff00ccffWarmane BiS Gear:|r item tooltip lines " .. (W.db.tooltip and "on" or "off"))
        return
    elseif lower == "minimap" then
        W.db.hideMinimap = not W.db.hideMinimap
        if W.minimapButton then if W.db.hideMinimap then W.minimapButton:Hide() else W.minimapButton:Show() end end
        return
    elseif lower == "stats" then
        if not W:Intact() then W:Refuse() return end
        if not W.frame then W:CreateUI() end
        W.frame:Show(); W:ShowTab(4)
        return
    elseif lower == "help" then
        print("|cff00ccffWarmane BiS Gear:|r /bis opens the window. /bis stats opens your hit / expertise caps and the stats to aim for. /bis <class> jumps to a class. /bis tooltip toggles the BiS line on item tooltips. /bis minimap toggles the minimap button.")
        return
    end
    if lower == "discord" or lower == "credits" then
        local o = W:Origin()
        if o then for _, l in ipairs(o) do print("|cff00ccffWarmane BiS Gear:|r " .. l) end else W:Refuse() end
        return
    end
    if not W:Intact() then W:Refuse() return end
    if not W.frame then W:CreateUI() end
    if msg ~= "" then
        local cls = findClass(msg)
        if cls and WarmaneBiSGear_Data.specs[cls] then
            W.frame:Show(); W:Select(cls, 1); return
        end
        print("|cff00ccffWarmane BiS Gear:|r no list for '" .. msg .. "' yet.")
        return
    end
    W:Toggle()
end

-- ---------- your talents and glyphs, for Raids Logs Report ----------
-- Raids Logs Report's Talents Check compares raiders' talents with the BiS
-- builds. It can inspect talents itself, but 3.3.5a cannot inspect glyphs, so
-- this addon says your own: talents in the BiS trees' order and glyph spells,
-- on the "WBGT" addon prefix, to your raid or party. Nothing else is sent.
local REPORT = "WBGT"
local function myTalents()
    local _, cls = UnitClass("player")
    local trees = WarmaneBiSGear_Talents and WarmaneBiSGear_Talents[cls]
    if not trees then return nil end
    local group = GetActiveTalentGroup and GetActiveTalentGroup() or 1
    local ranks = {}
    for tab = 1, (GetNumTalentTabs() or 0) do
        for i = 1, (GetNumTalents(tab) or 0) do
            local n, _, _, _, r = GetTalentInfo(tab, i, false, false, group)
            if n then ranks[n] = r or 0 end
        end
    end
    local out = {}
    for ti, tree in ipairs(trees) do
        local d = {}
        for i, t in ipairs(tree.t) do d[i] = tostring(math.min(9, ranks[t[4]] or 0)) end
        out[ti] = table.concat(d)
    end
    return cls, out
end
W.MyTalents = function() return myTalents() end

function W:SendReport()
    if not self:Intact() then return end
    local chan = (GetNumRaidMembers() > 0 and "RAID") or (GetNumPartyMembers() > 0 and "PARTY") or nil
    if not chan then return end
    local cls, d = myTalents()
    if not cls then return end
    SendAddonMessage(REPORT, ("T:%s:%s.%s.%s"):format(cls, d[1] or "", d[2] or "", d[3] or ""), chan)
    local ids = {}
    for i = 1, 6 do
        local enabled, _, spellId = GetGlyphSocketInfo(i)
        if enabled and spellId then ids[#ids + 1] = tostring(spellId) end
    end
    SendAddonMessage(REPORT, "G:" .. table.concat(ids, ","), chan)
    self.reportedAt = GetTime()
end

-- Sent a little after a change, never more than once every 10 seconds, and
-- after a random 0-3s when asked, so a raid does not answer all at once.
do
    local rep = CreateFrame("Frame")
    rep:Hide()
    local due = nil
    local function schedule(delay)
        local at = GetTime() + delay
        if W.reportedAt and at < W.reportedAt + 10 then at = W.reportedAt + 10 end
        if not due or at < due then due = at end
        rep:Show()
    end
    rep:SetScript("OnUpdate", function(self)
        if due and GetTime() >= due then due = nil; self:Hide(); W:SendReport() end
    end)
    local wasGrouped = false
    rep:SetScript("OnEvent", function(_, event, prefix, msg)
        if event == "CHAT_MSG_ADDON" then
            if prefix == REPORT and msg == "?" then schedule(math.random() * 3) end
        elseif event == "RAID_ROSTER_UPDATE" or event == "PARTY_MEMBERS_CHANGED" then
            local g = GetNumRaidMembers() > 0 or GetNumPartyMembers() > 0
            if g and not wasGrouped then schedule(3) end
            wasGrouped = g
        else
            schedule(3)
        end
    end)
    for _, e in ipairs({ "CHAT_MSG_ADDON", "RAID_ROSTER_UPDATE", "PARTY_MEMBERS_CHANGED", "PLAYER_ENTERING_WORLD",
                         "PLAYER_TALENT_UPDATE", "CHARACTER_POINTS_CHANGED", "ACTIVE_TALENT_GROUP_CHANGED",
                         "GLYPH_ADDED", "GLYPH_REMOVED", "GLYPH_UPDATED" }) do
        pcall(rep.RegisterEvent, rep, e)
    end
    W._reportFrame = rep
end

local ev = CreateFrame("Frame")
ev:RegisterEvent("ADDON_LOADED")
ev:SetScript("OnEvent", function(self, event, name)
    if name ~= ADDON then return end
    WarmaneBiSGearDB = WarmaneBiSGearDB or {}
    W.db = WarmaneBiSGearDB
    if W.db.tooltip == nil then W.db.tooltip = true end
    W:BuildIndex()
    W:HookTooltips()
    makeMinimapButton()
    self:UnregisterEvent("ADDON_LOADED")
end)
