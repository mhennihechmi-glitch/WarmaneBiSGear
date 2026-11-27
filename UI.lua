-- Warmane BiS Gear: the window. Gear tab (paper doll with your own character
-- wearing the set), Talents tab (all three trees), Glyphs tab and Stats tab (end of file).

local W = WarmaneBiSGear

-- Laid out like the game's own character window: armour down both sides,
-- weapons and the relic / wand slot in a row under the character.
local LEFT_SLOTS   = { "Head", "Neck", "Shoulder", "Back", "Chest", "Shirt", "Tabard", "Wrist" }
local RIGHT_SLOTS  = { "Hands", "Waist", "Legs", "Feet", "Finger0", "Finger1", "Trinket0", "Trinket1" }
local CENTER_SLOTS = { "MainHand", "SecondaryHand", "Ranged" }
local ROW_H, ICON = 48, 38
local FRAME_W, FRAME_H = 880, 650

local BACKDROP = {
    bgFile = "Interface\\ChatFrame\\ChatFrameBackground",
    edgeFile = "Interface\\Tooltips\\UI-Tooltip-Border", edgeSize = 14,
    insets = { left = 3, right = 3, top = 3, bottom = 3 },
}

local function qualityHex(q)
    local c = ITEM_QUALITY_COLORS and ITEM_QUALITY_COLORS[q]
    return (c and c.hex) or (q == 5 and "|cffff8000" or "|cffa335ee")
end

local function font(parent, size, template)
    local fs = parent:CreateFontString(nil, "OVERLAY", template or "GameFontNormal")
    if size then fs:SetFont(STANDARD_TEXT_FONT, size, "") end
    return fs
end

local function slotTexture(slot)
    local _, tex = GetInventorySlotInfo(slot .. "Slot")
    return tex
end

-- With the BiS enchant id when known, so the tooltip shows the enchant and the
-- dressing room shows a weapon enchant's glow. Gems are not put in the link:
-- a link carries gem ENCHANT ids, which this client has no table for.
local function itemString(id, ench) return "item:" .. id .. ":" .. (ench or 0) .. ":0:0:0:0:0:0" end
local GEM = 14

-- Shift-click on an item, gem or enchant item: with the Auction House open on
-- the Browse tab it searches for it there; otherwise it links it in chat.
-- The AH search uses the stored name, so it works before the item is cached.
local function linkOrSearch(id, name)
    if BrowseName and BrowseName:IsVisible() and AuctionFrame and AuctionFrame:IsShown() then
        BrowseName:SetText(name or GetItemInfo(id) or "")
        if AuctionFrameBrowse_Search then AuctionFrameBrowse_Search() end
        return
    end
    local _, link = GetItemInfo(id)
    if link then ChatEdit_InsertLink(link)
    else print("|cff00ccffWarmane BiS Gear:|r item not cached yet, hover it once and try again.") end
end

----------------------------------------------------------------------------
-- Gear tab
----------------------------------------------------------------------------
local function makeSlotRow(parent, slot, side)
    local row = CreateFrame("Button", nil, parent)
    row:SetHeight(side == "CENTER" and 112 or (ROW_H - 6)); row:SetWidth(side == "CENTER" and 200 or 290)
    row:RegisterForClicks("LeftButtonUp")
    row.slot = slot

    local iconBg = row:CreateTexture(nil, "BACKGROUND")
    iconBg:SetWidth(ICON + 2); iconBg:SetHeight(ICON + 2)
    iconBg:SetTexture(0, 0, 0, 1)
    local icon = row:CreateTexture(nil, "ARTWORK")
    icon:SetWidth(ICON); icon:SetHeight(ICON)
    icon:SetTexCoord(0.07, 0.93, 0.07, 0.93)
    row.icon = icon

    local name = font(row, 13)
    local ench = font(row, 11)
    local src = font(row, 10)
    ench:SetTextColor(0.1, 1, 0.1)
    src:SetTextColor(0.55, 0.75, 1)
    -- Fixed width and height keep each line on one row; a long text is cut with "...".
    name:SetWidth(240); ench:SetWidth(240); src:SetWidth(240)
    name:SetHeight(14); ench:SetHeight(12); src:SetHeight(11)
    if side == "CENTER" then
        -- icon on top, the three lines centred under it
        icon:SetPoint("TOP", row, "TOP", 0, 0)
        name:SetPoint("TOP", icon, "BOTTOM", 0, -4); name:SetJustifyH("CENTER")
        ench:SetPoint("TOP", name, "BOTTOM", 0, -1); ench:SetJustifyH("CENTER")
        src:SetPoint("TOP", ench, "BOTTOM", 0, -1); src:SetJustifyH("CENTER")
        -- narrow, so the three sit close together; a long weapon name wraps
        -- onto a second line instead of being cut off
        name:SetWidth(196); name:SetHeight(28); name:SetWordWrap(true); name:SetJustifyV("TOP")
        name:SetFont(STANDARD_TEXT_FONT, 12, "")
        ench:SetWidth(196); src:SetWidth(196)
        ench:SetFont(STANDARD_TEXT_FONT, 10, "")
    elseif side == "LEFT" then
        icon:SetPoint("LEFT", row, "LEFT", 0, 0)
        name:SetPoint("TOPLEFT", icon, "TOPRIGHT", 8, 1); name:SetJustifyH("LEFT")
        ench:SetPoint("TOPLEFT", name, "BOTTOMLEFT", 0, -1); ench:SetJustifyH("LEFT")
        src:SetPoint("TOPLEFT", ench, "BOTTOMLEFT", 0, -1); src:SetJustifyH("LEFT")
    else
        icon:SetPoint("RIGHT", row, "RIGHT", 0, 0)
        name:SetPoint("TOPRIGHT", icon, "TOPLEFT", -8, 1); name:SetJustifyH("RIGHT")
        ench:SetPoint("TOPRIGHT", name, "BOTTOMRIGHT", 0, -1); ench:SetJustifyH("RIGHT")
        src:SetPoint("TOPRIGHT", ench, "BOTTOMRIGHT", 0, -1); src:SetJustifyH("RIGHT")
    end
    iconBg:SetPoint("CENTER", icon, "CENTER")
    row.name, row.ench, row.src = name, ench, src
    row.side = side
    row.textW = (side == "CENTER") and 196 or 240

    -- On the enchant line: the enchant's item (scroll, arcanum, leg armor ...)
    -- when one exists, then up to four gem icons, each with its own tooltip.
    row.gems = {}
    for i = 1, 5 do
        local g = CreateFrame("Button", nil, row)
        g:SetWidth(GEM - 2); g:SetHeight(GEM - 2)
        g.tex = g:CreateTexture(nil, "ARTWORK"); g.tex:SetAllPoints()
        g.tex:SetTexCoord(0.07, 0.93, 0.07, 0.93)
        g:SetScript("OnEnter", function(self)
            if not self.gemId then return end
            GameTooltip:SetOwner(self, side == "LEFT" and "ANCHOR_RIGHT" or (side == "CENTER" and "ANCHOR_TOP" or "ANCHOR_LEFT"))
            GameTooltip:SetHyperlink("item:" .. self.gemId .. ":0:0:0:0:0:0:0")
            if self.isEnchant then GameTooltip:AddLine("BiS enchant item", 0.1, 1, 0.1) end
            GameTooltip:AddLine("Shift-click: link in chat, or search it when the Auction House is open.", 0.6, 0.6, 0.6, true)
            GameTooltip:Show()
        end)
        g:SetScript("OnLeave", function() GameTooltip:Hide() end)
        g:SetScript("OnClick", function(self)
            if self.gemId and IsModifiedClick("CHATLINK") then linkOrSearch(self.gemId, self.gemName) end
        end)
        g:Hide()
        row.gems[i] = g
    end

    row:SetScript("OnEnter", function(self)
        if not self.itemId then return end
        GameTooltip:SetOwner(self, side == "LEFT" and "ANCHOR_RIGHT" or (side == "CENTER" and "ANCHOR_TOP" or "ANCHOR_LEFT"))
        GameTooltip:SetHyperlink(itemString(self.itemId, self.enchantId))
        if self.enchant then GameTooltip:AddLine("BiS enchant: " .. self.enchant, 0.1, 1, 0.1, true) end
        if self.enchItem then GameTooltip:AddLine("Enchant item: " .. self.enchItem, 0.1, 1, 0.1, true) end
        if self.gemNames then GameTooltip:AddLine("BiS gems: " .. self.gemNames, 0.9, 0.6, 1, true) end
        if self.source then GameTooltip:AddLine("Source: " .. self.source, 0.55, 0.75, 1, true) end
        GameTooltip:AddLine("Shift-click: link in chat (or search the Auction House when it is open). Ctrl-click: dressing room.", 0.6, 0.6, 0.6, true)
        GameTooltip:Show()
    end)
    row:SetScript("OnLeave", function() GameTooltip:Hide() end)
    row:SetScript("OnClick", function(self)
        if not self.itemId then return end
        if IsModifiedClick("CHATLINK") then
            linkOrSearch(self.itemId, self.itemName)
        elseif IsModifiedClick("DRESSUP") then
            DressUpItemLink(itemString(self.itemId, self.enchantId))
        end
    end)
    return row
end

local function setRow(row, it)
    if it then
        row.itemId, row.enchant, row.source = it[1], it[3], it[6] or it[5]
        row.itemName = it[2]
        row.icon:SetTexture(GetItemIcon(it[1]) or slotTexture(row.slot))
        -- The client's own quality wins once the item is cached; the stored one covers the rest.
        local q = select(3, GetItemInfo(it[1])) or it[4]
        row.name:SetText(qualityHex(q) .. it[2] .. "|r")
        row.ench:SetText(it[3] or "|cff8f8f8fNo enchant|r")
        row.src:SetText(it[5] or "")
        row.enchantId = it[7]
        -- chips on the enchant line: the enchant item first, then the gems
        local gems = {}
        local ei = it[9]
        if ei then gems[1] = { ei[1], ei[2], true } end
        for _, gem in ipairs(it[8] or {}) do gems[#gems + 1] = gem end
        row.enchItem = ei and ei[2] or nil
        local names = {}
        -- the enchant text gives up room for the gems, so nothing overlaps;
        -- in the centre row the gems get their own line instead
        local centre = (row.side == "CENTER")
        row.ench:SetWidth(centre and row.textW or (row.textW - #gems * GEM))
        local w = math.min(row.ench:GetStringWidth() or 0, row.textW - #gems * GEM)
        if centre then
            row.src:ClearAllPoints()
            row.src:SetPoint("TOP", row.ench, "BOTTOM", 0, #gems > 0 and -(GEM + 3) or -1)
        end
        for i, g in ipairs(row.gems) do
            local gem = gems[i]
            g:ClearAllPoints()
            if gem then
                g.gemId, g.gemName, g.isEnchant = gem[1], gem[2], gem[3]
                g.tex:SetTexture(GetItemIcon(gem[1]) or (gem[3] and "Interface\\Icons\\INV_Scroll_03" or "Interface\\Icons\\INV_Misc_Gem_01"))
                if centre then g:SetPoint("TOPLEFT", row.ench, "BOTTOM", -(#gems * GEM) / 2 + (i - 1) * GEM, -2)
                elseif row.side == "LEFT" then g:SetPoint("LEFT", row.ench, "LEFT", w + 4 + (i - 1) * GEM, 0)
                else g:SetPoint("RIGHT", row.ench, "RIGHT", -(w + 4 + (i - 1) * GEM), 0) end
                g:Show()
                if not gem[3] then names[#names + 1] = gem[2] end
            else
                g.gemId = nil; g:Hide()
            end
        end
        row.gemNames = #names > 0 and table.concat(names, ", ") or nil
    else
        row.itemId, row.enchant, row.source = nil, nil, nil
        row.enchantId, row.gemNames, row.itemName, row.enchItem = nil, nil, nil, nil
        for _, g in ipairs(row.gems) do g.gemId = nil; g:Hide() end
        row.ench:SetWidth(row.textW)
        row.icon:SetTexture(slotTexture(row.slot))
        row.name:SetText("|cff8f8f8f" .. W.SLOT_LABEL[row.slot] .. "|r")
        row.ench:SetText("")
        row.src:SetText("")
    end
end

local function buildGear(panel)
    panel.rows = {}
    for i, slot in ipairs(LEFT_SLOTS) do
        local r = makeSlotRow(panel, slot, "LEFT")
        r:SetPoint("TOPLEFT", panel, "TOPLEFT", 18, -8 - (i - 1) * ROW_H)
        panel.rows[slot] = r
    end
    for i, slot in ipairs(RIGHT_SLOTS) do
        local r = makeSlotRow(panel, slot, "RIGHT")
        r:SetPoint("TOPRIGHT", panel, "TOPRIGHT", -18, -8 - (i - 1) * ROW_H)
        panel.rows[slot] = r
    end
    -- main hand, off hand, ranged / relic: one row under the character
    for i, slot in ipairs(CENTER_SLOTS) do
        local r = makeSlotRow(panel, slot, "CENTER")
        r:SetPoint("TOP", panel, "TOP", (i - 2) * 205, -8 - #LEFT_SLOTS * ROW_H - 6)
        panel.rows[slot] = r
    end

    local model = CreateFrame("DressUpModel", nil, panel)
    model:SetWidth(250); model:SetHeight(#LEFT_SLOTS * ROW_H - 26)
    model:SetPoint("TOP", panel, "TOP", 0, -10)
    model:EnableMouse(true); model:EnableMouseWheel(true)
    model.facing, model.zoom = 0, 0
    model:SetScript("OnMouseDown", function(self) self.dragX = GetCursorPosition() end)
    model:SetScript("OnMouseUp", function(self) self.dragX = nil end)
    model:SetScript("OnUpdate", function(self)
        if not self.dragX then return end
        local x = GetCursorPosition()
        self.facing = self.facing + (x - self.dragX) / 90
        self.dragX = x
        self:SetFacing(self.facing)
    end)
    model:SetScript("OnMouseWheel", function(self, delta)
        self.zoom = math.max(0, math.min(2, self.zoom + delta * 0.25))
        self:SetPosition(self.zoom, 0, 0)
    end)
    panel.model = model

    local hint = font(panel, 10, "GameFontDisable")
    hint:SetPoint("TOP", model, "BOTTOM", 0, -2)
    hint:SetText("Drag to turn, wheel to zoom")
end

local function dress(model, spec)
    if not model:IsVisible() then return end
    model:SetUnit("player")
    model:Undress()
    -- Main hand before off hand so a 1H + 1H set lands in the right hands.
    local order = { "Head", "Shoulder", "Back", "Chest", "Wrist", "Hands", "Waist", "Legs", "Feet", "Ranged", "MainHand", "SecondaryHand" }
    for _, slot in ipairs(order) do
        local it = spec.gear[slot]
        if it then model:TryOn(itemString(it[1], it[7])) end
    end
    model:SetFacing(model.facing or 0)
    model:SetPosition(model.zoom or 0, 0, 0)
end

local function showGear(panel, spec)
    for slot, row in pairs(panel.rows) do setRow(row, spec.gear[slot]) end
    dress(panel.model, spec)
end

----------------------------------------------------------------------------
-- Talents tab
----------------------------------------------------------------------------
local TREE_W, TREE_H, COL_W, ROW_T, TI = 272, 512, 58, 42, 32

local function btnPos(tier, col) return 30 + (col - 1) * COL_W, -40 - (tier - 1) * ROW_T end

local function line(tree, x1, y1, x2, y2, lit)
    local t = tree:CreateTexture(nil, "BORDER")
    if lit then t:SetTexture(1, 0.82, 0, 0.9) else t:SetTexture(0.5, 0.5, 0.5, 0.8) end
    local left, right = math.min(x1, x2), math.max(x1, x2)
    local top, bottom = math.max(y1, y2), math.min(y1, y2)
    t:SetPoint("TOPLEFT", tree, "TOPLEFT", left - 1.5, top + 1.5)
    t:SetWidth(right - left + 3); t:SetHeight(top - bottom + 3)
    table.insert(tree.lines, t)
end

local function buildTree(panel, i)
    local tree = CreateFrame("Frame", nil, panel)
    tree:SetWidth(TREE_W); tree:SetHeight(TREE_H)
    tree:SetPoint("TOPLEFT", panel, "TOPLEFT", 14 + (i - 1) * (TREE_W + 12), -4)
    tree:SetBackdrop(BACKDROP)
    tree:SetBackdropColor(0, 0, 0, 1); tree:SetBackdropBorderColor(0.3, 0.3, 0.3, 1)

    -- The client's own talent background is four pieces, 320x384 together.
    tree.bg = {}
    local pieces = { { "TopLeft", 256, 256, 0, 0 }, { "TopRight", 64, 256, 256, 0 },
                     { "BottomLeft", 256, 128, 0, 256 }, { "BottomRight", 64, 128, 256, 256 } }
    local sx, sy = (TREE_W - 8) / 320, (TREE_H - 34) / 384
    for _, p in ipairs(pieces) do
        local t = tree:CreateTexture(nil, "BACKGROUND")
        t:SetWidth(p[2] * sx); t:SetHeight(p[3] * sy)
        t:SetPoint("TOPLEFT", tree, "TOPLEFT", 4 + p[4] * sx, -30 - p[5] * sy)
        t:SetAlpha(0.55)
        t.suffix = p[1]
        table.insert(tree.bg, t)
    end

    local head = tree:CreateTexture(nil, "ARTWORK")
    head:SetWidth(22); head:SetHeight(22); head:SetPoint("TOPLEFT", 8, -5)
    tree.headIcon = head
    tree.title = font(tree, 14, "GameFontHighlight")
    tree.title:SetPoint("TOP", tree, "TOP", 0, -9)
    tree.pts = font(tree, 13)
    tree.pts:SetPoint("TOPRIGHT", tree, "TOPRIGHT", -10, -9)
    tree.lines, tree.btns = {}, {}
    return tree
end

local function talentButton(tree, n)
    local b = tree.btns[n]
    if b then return b end
    b = CreateFrame("Button", nil, tree)
    b:SetWidth(TI); b:SetHeight(TI)
    b.border = b:CreateTexture(nil, "BACKGROUND")
    b.border:SetWidth(TI + 4); b.border:SetHeight(TI + 4); b.border:SetPoint("CENTER")
    b.icon = b:CreateTexture(nil, "ARTWORK")
    b.icon:SetAllPoints(b); b.icon:SetTexCoord(0.07, 0.93, 0.07, 0.93)
    b.rankBg = b:CreateTexture(nil, "OVERLAY")
    b.rankBg:SetTexture(0, 0, 0, 0.85)
    b.rankBg:SetPoint("BOTTOMRIGHT", b, "BOTTOMRIGHT", 8, -6); b.rankBg:SetWidth(24); b.rankBg:SetHeight(13)
    b.rank = b:CreateFontString(nil, "OVERLAY")
    b.rank:SetFont(STANDARD_TEXT_FONT, 10, "OUTLINE")
    b.rank:SetPoint("CENTER", b.rankBg, "CENTER", 0, 0)
    b:SetScript("OnEnter", function(self)
        GameTooltip:SetOwner(self, "ANCHOR_RIGHT")
        local spell = self.spells[math.max(1, self.points)]
        GameTooltip:SetHyperlink("spell:" .. spell)
        GameTooltip:AddLine(" ")
        GameTooltip:AddLine(("BiS rank: %d / %d"):format(self.points, self.max), 1, 0.82, 0)
        GameTooltip:Show()
    end)
    b:SetScript("OnLeave", function() GameTooltip:Hide() end)
    tree.btns[n] = b
    return b
end

local function showTree(tree, data, ranks)
    for _, t in ipairs(tree.bg) do t:SetTexture("Interface\\TalentFrame\\" .. data.bg .. "-" .. t.suffix) end
    tree.headIcon:SetTexture(data.icon)
    tree.title:SetText(data.name)
    for _, l in ipairs(tree.lines) do l:Hide() end
    tree.lines = {}
    for _, b in pairs(tree.btns) do b:Hide() end

    local total = 0
    for n, t in ipairs(data.t) do
        local pts = tonumber(ranks:sub(n, n)) or 0
        total = total + pts
        local b = talentButton(tree, n)
        local x, y = btnPos(t[1], t[2])
        b:ClearAllPoints(); b:SetPoint("TOPLEFT", tree, "TOPLEFT", x, y)
        b.icon:SetTexture(t[5])
        b.icon:SetDesaturated(pts == 0)
        b.icon:SetVertexColor(pts == 0 and 0.55 or 1, pts == 0 and 0.55 or 1, pts == 0 and 0.55 or 1)
        if pts == t[3] then b.border:SetTexture(1, 0.82, 0, 1)
        elseif pts > 0 then b.border:SetTexture(0.1, 1, 0.1, 1)
        else b.border:SetTexture(0.25, 0.25, 0.25, 1) end
        b.rank:SetText(pts > 0 and (pts .. "/" .. t[3]) or "")
        if pts > 0 then
            b.rank:SetTextColor(pts == t[3] and 1 or 0.1, pts == t[3] and 0.82 or 1, pts == t[3] and 0 or 0.1)
            b.rankBg:Show()
        else b.rankBg:Hide() end
        b.points, b.max, b.spells = pts, t[3], t[6]
        b:Show()

        local pre = t[7] > 0 and data.t[t[7]]
        if pre then
            local px, py = btnPos(pre[1], pre[2])
            local lit = pts > 0
            local h = TI / 2
            if pre[2] == t[2] then
                line(tree, px + h, py - TI, x + h, y, lit)
            elseif pre[1] == t[1] then
                local from = pre[2] < t[2] and px + TI or px
                local to = pre[2] < t[2] and x or x + TI
                line(tree, from, py - h, to, y - h, lit)
            else
                local from = pre[2] < t[2] and px + TI or px
                line(tree, from, py - h, x + h, py - h, lit)
                line(tree, x + h, py - h, x + h, y, lit)
            end
        end
    end
    tree.pts:SetText(total)
    return total
end

local function buildTalents(panel)
    panel.trees = {}
    for i = 1, 3 do panel.trees[i] = buildTree(panel, i) end
    panel.summary = font(panel, 13, "GameFontHighlight")
    panel.summary:SetPoint("BOTTOMLEFT", panel, "BOTTOMLEFT", 18, 8)
end

local function showTalents(panel, cls, spec)
    local trees = WarmaneBiSGear_Talents[cls]
    local pts = {}
    for i = 1, 3 do pts[i] = showTree(panel.trees[i], trees[i], spec.talents[i] or "") end
    panel.summary:SetText(("Points: %d / %d / %d    Required level: 80"):format(pts[1], pts[2], pts[3]))
end

----------------------------------------------------------------------------
-- Glyphs tab
----------------------------------------------------------------------------
local function glyphRow(parent)
    local r = CreateFrame("Button", nil, parent)
    r:SetWidth(330); r:SetHeight(44)
    r:RegisterForClicks("LeftButtonUp")
    r.icon = r:CreateTexture(nil, "ARTWORK")
    r.icon:SetWidth(36); r.icon:SetHeight(36); r.icon:SetPoint("LEFT")
    r.icon:SetTexCoord(0.07, 0.93, 0.07, 0.93)
    r.text = font(r, 14, "GameFontHighlight")
    r.text:SetPoint("LEFT", r.icon, "RIGHT", 10, 0)
    r:SetScript("OnEnter", function(self)
        if not self.itemId then return end
        GameTooltip:SetOwner(self, "ANCHOR_RIGHT")
        GameTooltip:SetHyperlink(itemString(self.itemId))
        GameTooltip:Show()
    end)
    r:SetScript("OnLeave", function() GameTooltip:Hide() end)
    r:SetScript("OnClick", function(self)
        if self.itemId and IsModifiedClick("CHATLINK") then
            local _, link = GetItemInfo(self.itemId)
            if link then ChatEdit_InsertLink(link) end
        end
    end)
    return r
end

local function buildGlyphs(panel)
    panel.groups = {}
    for gi, kind in ipairs({ "major", "minor" }) do
        local head = font(panel, 15)
        head:SetPoint("TOPLEFT", panel, "TOPLEFT", 60 + (gi - 1) * 400, -24)
        head:SetText(kind == "major" and "MAJOR GLYPHS" or "MINOR GLYPHS")
        local rows = {}
        for i = 1, 3 do
            local r = glyphRow(panel)
            r:SetPoint("TOPLEFT", head, "BOTTOMLEFT", 0, -14 - (i - 1) * 52)
            rows[i] = r
        end
        panel.groups[kind] = rows
    end
    local note = font(panel, 11, "GameFontDisable")
    note:SetPoint("BOTTOMLEFT", panel, "BOTTOMLEFT", 18, 8)
    note:SetText("Shift-click a glyph to link it in chat.")
end

local function showGlyphs(panel, spec)
    for kind, rows in pairs(panel.groups) do
        local list = spec.glyphs[kind] or {}
        for i, r in ipairs(rows) do
            local g = list[i]
            if g then
                r.itemId = g[1]
                r.icon:SetTexture(GetItemIcon(g[1]) or "Interface\\Icons\\INV_Glyph_MajorPaladin")
                r.text:SetText(g[2])
            else
                r.itemId = nil
                r.icon:SetTexture("Interface\\Icons\\INV_Misc_QuestionMark")
                r.text:SetText("|cff8f8f8fNo glyph listed|r")
            end
        end
    end
end

----------------------------------------------------------------------------
-- Window
----------------------------------------------------------------------------
local function tabButton(parent, label)
    local b = CreateFrame("Button", nil, parent)
    b:SetHeight(26)
    b.text = font(b, 13)
    b.text:SetPoint("CENTER")
    b.text:SetText(label)
    b:SetWidth(b.text:GetStringWidth() + 30)
    b.bar = b:CreateTexture(nil, "OVERLAY")
    b.bar:SetTexture(0.2, 0.6, 1, 1); b.bar:SetHeight(2)
    b.bar:SetPoint("BOTTOMLEFT"); b.bar:SetPoint("BOTTOMRIGHT")
    b:SetScript("OnEnter", function(self) self.text:SetTextColor(1, 1, 1) end)
    b:SetScript("OnLeave", function(self) if not self.active then self.text:SetTextColor(0.75, 0.75, 0.75) end end)
    return b
end

local function setActive(b, on)
    b.active = on
    if on then b.text:SetTextColor(0.3, 0.7, 1); b.bar:Show() else b.text:SetTextColor(0.75, 0.75, 0.75); b.bar:Hide() end
end

-- The banner on top of the window. Second encoded copy of the origin text
-- (see Core.lua), decoded a different way; both must agree.
do
    local E = { 92, 99, 208, 208, 61, 237, 72, 237, 85, 180, 99, 236, 110, 237, 72, 237, 15, 236, 15, 180, 43, 229, 57, 237, 72, 237, 208, 236, 71, 180, 43, 254, 237, 163, 57, 236, 201, 208, 43, 226, 83, 89, 229, 243, 208, 226, 103, 215, 96, 85, 114, 86, 222, 222, 79, 201, 43, 22, 194, 50, 236, 201, 86, 86, 163, 50, 29, 57, 57, 229, 237, 163, 201, 43, 22, 194, 50, 236, 233, 83, 201, 1, 236, 64, 254, 237, 208, 43, 22, 194, 201, 43, 180, 5, 237, 240, 71, 61, 237, 15, 78, 22, 43, 194, 208, 194, 12, 237, 208, 194, 15, 180, 236, 1, 1, 212, 237, 191, 15, 22, 236, 57, 50, 180, 219, 177 }
    local t = {}
    for i = #E, 1, -1 do t[#t + 1] = string.char(((E[i] - 13) * 183) % 256) end
    local plain = table.concat(t)
    W._originUI = (W._sum and W._sum(plain) == W._SUM) and plain or nil
end

local function makeBanner(f)
    local lines = W:Origin() or {}
    local b = CreateFrame("Button", nil, f)
    b:SetHeight(40); b:SetWidth(470)
    b:SetPoint("BOTTOM", f, "TOP", 0, -3)
    b:SetFrameLevel(f:GetFrameLevel() + 20)
    b:SetBackdrop(BACKDROP)
    b:SetBackdropColor(0.10, 0.07, 0.03, 0.97); b:SetBackdropBorderColor(0.85, 0.65, 0.2, 1)
    local l1 = font(b, 13, "GameFontNormal")
    l1:SetPoint("TOP", b, "TOP", 0, -7); l1:SetTextColor(1, 0.82, 0.25)
    local l2 = font(b, 10, "GameFontHighlightSmall")
    l2:SetPoint("TOP", l1, "BOTTOM", 0, -2)
    local want1 = lines[1] or ""
    local want2 = (lines[2] or "") .. "    " .. (lines[3] or "")
    local function paint()
        l1:SetText(want1); l2:SetText(want2)
        b:SetAlpha(1); b:Show(); l1:Show(); l2:Show()
    end
    paint()
    -- Something hid it or wrote over it: put it back, every half second.
    local t = 0
    b:SetScript("OnUpdate", function(self, d)
        t = t + (d or 0)
        if t < 0.5 then return end
        t = 0
        if l1:GetText() ~= want1 or l2:GetText() ~= want2 or self:GetAlpha() < 1 or not l1:IsShown() then paint() end
    end)
    -- run from the window's own OnUpdate (set further down), so it also
    -- catches the banner itself being hidden, when its OnUpdate stops
    f.bannerGuard = function()
        if not b:IsShown() or b:GetParent() ~= f then b:SetParent(f); b:ClearAllPoints(); b:SetPoint("BOTTOM", f, "TOP", 0, -3); paint() end
    end
    -- WoW cannot open a link, so a click hands you one to copy.
    local box = CreateFrame("EditBox", nil, b)
    box:SetAutoFocus(false); box:SetFontObject(ChatFontNormal)
    box:SetWidth(300); box:SetHeight(20); box:SetPoint("TOP", b, "BOTTOM", 0, -2)
    box:SetBackdrop(BACKDROP); box:SetBackdropColor(0, 0, 0, 0.95)
    box:SetTextInsets(6, 6, 0, 0)
    box:Hide()
    local url = (lines[2] or ""):match("(https?://%S+)") or ""
    box:SetScript("OnEscapePressed", function(s) s:ClearFocus(); s:Hide() end)
    box:SetScript("OnEditFocusLost", function(s) s:Hide() end)
    box:SetScript("OnTextChanged", function(s) if s:GetText() ~= url then s:SetText(url); s:HighlightText() end end)
    b:SetScript("OnClick", function()
        box:SetText(url); box:Show(); box:SetFocus(); box:HighlightText()
    end)
    b:SetScript("OnEnter", function(self)
        GameTooltip:SetOwner(self, "ANCHOR_TOP")
        GameTooltip:AddLine(want1, 1, 0.82, 0.25)
        GameTooltip:AddLine("Click for the Discord link, then Ctrl+C.", 1, 1, 1)
        GameTooltip:Show()
    end)
    b:SetScript("OnLeave", function() GameTooltip:Hide() end)
    f.banner = b

    -- and faintly behind the paper doll
    local wm = f:CreateFontString(nil, "BACKGROUND", "GameFontNormalHuge")
    wm:SetPoint("CENTER", f, "CENTER", 0, -40)
    wm:SetText(lines[1] and lines[1]:match("^(<[^>]+>)") or "")
    wm:SetTextColor(1, 1, 1, 0.05)
    f.wm = wm
end

function W:CreateUI()
    local f = CreateFrame("Frame", "WarmaneBiSGearFrame", UIParent)
    f:SetWidth(FRAME_W); f:SetHeight(FRAME_H)
    f:SetPoint("CENTER")
    f:SetFrameStrata("HIGH")
    f:SetBackdrop(BACKDROP)
    f:SetBackdropColor(0.07, 0.07, 0.09, 0.97); f:SetBackdropBorderColor(0.4, 0.4, 0.45, 1)
    f:EnableMouse(true); f:SetMovable(true); f:SetClampedToScreen(true)
    f:RegisterForDrag("LeftButton")
    f:SetScript("OnDragStart", f.StartMoving)
    f:SetScript("OnDragStop", f.StopMovingOrSizing)
    f:Hide()
    table.insert(UISpecialFrames, "WarmaneBiSGearFrame")
    self.frame = f

    local close = CreateFrame("Button", nil, f, "UIPanelCloseButton")
    close:SetPoint("TOPRIGHT", f, "TOPRIGHT", -2, -2)

    local title = font(f, 16)
    title:SetPoint("TOPLEFT", f, "TOPLEFT", 16, -12)
    title:SetText("Warmane BiS Gear")
    local sub = font(f, 11, "GameFontDisable")
    sub:SetPoint("LEFT", title, "RIGHT", 10, -1)
    sub:SetText("latest phase, updated " .. (WarmaneBiSGear_Data.updated or "?"))

    -- Class picker: the ten class icons, the ones without a list greyed out.
    f.classBtns = {}
    for i, cls in ipairs(self.CLASS_ORDER) do
        local b = CreateFrame("Button", nil, f)
        b:SetWidth(30); b:SetHeight(30)
        b:SetPoint("TOPLEFT", f, "TOPLEFT", 16 + (i - 1) * 36, -38)
        local t = b:CreateTexture(nil, "ARTWORK")
        t:SetAllPoints(b)
        t:SetTexture("Interface\\Glues\\CharacterCreate\\UI-CharacterCreate-Classes")
        local c = CLASS_ICON_TCOORDS and CLASS_ICON_TCOORDS[cls]
        if c then t:SetTexCoord(c[1], c[2], c[3], c[4]) end
        b.tex = t
        b.sel = b:CreateTexture(nil, "OVERLAY")
        b.sel:SetTexture("Interface\\Buttons\\CheckButtonHilight"); b.sel:SetBlendMode("ADD")
        b.sel:SetAllPoints(b)
        local has = WarmaneBiSGear_Data.specs[cls] ~= nil
        t:SetDesaturated(not has); if not has then t:SetAlpha(0.35) end
        b:SetScript("OnClick", function() if has then W:Select(cls, 1) end end)
        b:SetScript("OnEnter", function(self)
            GameTooltip:SetOwner(self, "ANCHOR_BOTTOM")
            GameTooltip:AddLine(W.classColor(cls) .. W:ClassName(cls) .. "|r")
            if not has then GameTooltip:AddLine("No list yet", 0.6, 0.6, 0.6) end
            GameTooltip:Show()
        end)
        b:SetScript("OnLeave", function() GameTooltip:Hide() end)
        f.classBtns[cls] = b
    end

    f.specBtns = {}
    f.heading = font(f, 15, "GameFontHighlight")
    f.heading:SetPoint("TOPLEFT", f, "TOPLEFT", 16, -80)

    f.tabs, f.panels = {}, {}
    local names = { "Gear", "Talents", "Glyphs", "Stats" }
    for i, n in ipairs(names) do
        local tb = tabButton(f, n:upper())
        if i == 1 then tb:SetPoint("TOPLEFT", f, "TOPLEFT", FRAME_W - 370, -76)
        else tb:SetPoint("LEFT", f.tabs[i - 1], "RIGHT", 4, 0) end
        tb:SetScript("OnClick", function() W:ShowTab(i) end)
        f.tabs[i] = tb
        local p = CreateFrame("Frame", nil, f)
        p:SetPoint("TOPLEFT", f, "TOPLEFT", 0, -112)
        p:SetPoint("BOTTOMRIGHT", f, "BOTTOMRIGHT", 0, 0)
        p:Hide()
        f.panels[i] = p
    end
    local sep = f:CreateTexture(nil, "ARTWORK")
    sep:SetTexture(0.3, 0.3, 0.35, 1); sep:SetHeight(1)
    sep:SetPoint("TOPLEFT", f, "TOPLEFT", 12, -106); sep:SetPoint("TOPRIGHT", f, "TOPRIGHT", -12, -106)

    buildGear(f.panels[1]); buildTalents(f.panels[2]); buildGlyphs(f.panels[3])
    if W.BuildStats and WarmaneBiSGear_Stats then W:BuildStats(f.panels[4]) end
    makeBanner(f)

    -- Resize grip, bottom right. It scales the whole window instead of
    -- stretching it, so the paper doll and the talent grid keep their layout.
    -- The top-left corner stays where it is while dragging. Right-click resets.
    local MIN_SCALE, MAX_SCALE = 0.6, 1.6
    local function applyScale(s)
        s = math.max(MIN_SCALE, math.min(MAX_SCALE, s))
        local eff = f:GetEffectiveScale()
        local left, top = f:GetLeft(), f:GetTop()
        f:SetScale(s)
        if left and top then
            local k = eff / f:GetEffectiveScale()
            f:ClearAllPoints()
            f:SetPoint("TOPLEFT", UIParent, "BOTTOMLEFT", left * k, top * k)
        end
        if W.db then W.db.scale = s end
    end
    W.ApplyScale = function(_, s) applyScale(s) end
    local grip = CreateFrame("Button", nil, f)
    grip:SetWidth(16); grip:SetHeight(16)
    grip:SetPoint("BOTTOMRIGHT", f, "BOTTOMRIGHT", -4, 4)
    grip:SetFrameLevel(f:GetFrameLevel() + 10)
    grip:SetNormalTexture("Interface\\ChatFrame\\UI-ChatIM-SizeGrabber-Up")
    grip:SetPushedTexture("Interface\\ChatFrame\\UI-ChatIM-SizeGrabber-Down")
    grip:SetHighlightTexture("Interface\\ChatFrame\\UI-ChatIM-SizeGrabber-Highlight")
    grip:RegisterForClicks("RightButtonUp")
    grip:SetScript("OnMouseDown", function(self, button)
        if button ~= "LeftButton" then return end
        self.startX = GetCursorPosition()
        self.startScale = f:GetScale()
        self.startW = FRAME_W * f:GetEffectiveScale()
    end)
    grip:SetScript("OnMouseUp", function(self) self.startX = nil end)
    grip:SetScript("OnUpdate", function(self)
        if not self.startX then return end
        local x = GetCursorPosition()
        applyScale(self.startScale * (self.startW + (x - self.startX)) / self.startW)
    end)
    grip:SetScript("OnClick", function() applyScale(1) end)
    grip:SetScript("OnEnter", function(self)
        GameTooltip:SetOwner(self, "ANCHOR_RIGHT")
        GameTooltip:AddLine("Drag to resize")
        GameTooltip:AddLine("Right-click to reset", 0.6, 0.6, 0.6)
        GameTooltip:Show()
    end)
    grip:SetScript("OnLeave", function() GameTooltip:Hide() end)
    f.grip = grip
    if W.db and W.db.scale then f:SetScale(math.max(MIN_SCALE, math.min(MAX_SCALE, W.db.scale))) end

    -- Items the client has not seen yet come back from the server a moment
    -- later; dress the model again once they have had time to arrive.
    f.redress = 0
    f:SetScript("OnUpdate", function(self, elapsed)
        if self.bannerGuard then self.bannerGuard() end
        if self.redress <= 0 then return end
        self.redress = self.redress - elapsed
        if self.redress <= 0 and W.spec and self.tab == 1 then dress(self.panels[1].model, W.spec) end
    end)
    f:SetScript("OnShow", function()
        if not W.cls then
            local cls, idx = W:DefaultSelection()
            local last = W.db and W.db.last
            if last and WarmaneBiSGear_Data.specs[last.cls] and WarmaneBiSGear_Data.specs[last.cls][last.idx] then
                cls, idx = last.cls, last.idx
            end
            W:Select(cls, idx)
        else
            W:ShowTab(f.tab or 1)
        end
    end)
end

function W:ShowTab(i)
    local f = self.frame
    f.tab = i
    for n, p in ipairs(f.panels) do
        if n == i then p:Show() else p:Hide() end
        setActive(f.tabs[n], n == i)
    end
    if not self.spec then return end
    if i == 1 then showGear(f.panels[1], self.spec); f.redress = 1.5
    elseif i == 2 then showTalents(f.panels[2], self.cls, self.spec)
    elseif i == 3 then showGlyphs(f.panels[3], self.spec)
    elseif W.ShowStats and f.panels[4].rows then W:ShowStats(f.panels[4]) end
end

function W:Select(cls, idx)
    local specs = WarmaneBiSGear_Data.specs[cls]
    if not specs then return end
    idx = specs[idx] and idx or 1
    self.cls, self.idx, self.spec = cls, idx, specs[idx]
    if self.db then self.db.last = { cls = cls, idx = idx } end
    local f = self.frame

    for c, b in pairs(f.classBtns) do if c == cls then b.sel:Show() else b.sel:Hide() end end
    for _, b in ipairs(f.specBtns) do b:Hide() end
    for i, spec in ipairs(specs) do
        local b = f.specBtns[i]
        if not b then
            b = tabButton(f, "")
            f.specBtns[i] = b
        end
        b.text:SetText(spec.name)
        b:SetWidth(b.text:GetStringWidth() + 24)
        b:ClearAllPoints()
        if i == 1 then b:SetPoint("TOPLEFT", f, "TOPLEFT", 400, -40)
        else b:SetPoint("LEFT", f.specBtns[i - 1], "RIGHT", 2, 0) end
        b:SetScript("OnClick", function() W:Select(cls, i) end)
        setActive(b, i == idx)
        b:Show()
    end

    local pts = {}
    for i = 1, 3 do
        local n = 0
        for d in (self.spec.talents[i] or ""):gmatch("%d") do n = n + tonumber(d) end
        pts[i] = n
    end
    f.heading:SetText(self.classColor(cls) .. self.spec.name .. " " .. self:ClassName(cls) .. "|r  |cff8f8f8f"
        .. pts[1] .. "/" .. pts[2] .. "/" .. pts[3] .. "|r")
    self:PrimeItems(self.spec)
    self:ShowTab(f.tab or 1)
end

----------------------------------------------------------------------------
-- Stats tab: hit / expertise / defense / armor pen caps worked out from
-- talents and race, the stats the BiS set ends up with (sixtyupgrades exports,
-- no raid buffs, data at the end of Data/BiS.lua), and your own character.
-- Kept in this file on purpose: WoW only reads a .toc's file list when the game
-- starts, so a new file would not load after a /reload.
----------------------------------------------------------------------------
do

-- Level 80 rating conversions (3.3.5a).
local HIT_MELEE  = 32.78998   -- rating per 1% melee / ranged hit
local HIT_SPELL  = 26.231998  -- rating per 1% spell hit
local EXP_RATING = 8.1974973  -- rating per 1 expertise (4 expertise = 1%)
local DEF_RATING = 4.918498   -- rating per 1 defense skill
local ARP_CAP    = 1400       -- rating for 100% armor penetration

local CR = {
    hitM = CR_HIT_MELEE or 6, hitR = CR_HIT_RANGED or 7, hitS = CR_HIT_SPELL or 8,
    critM = CR_CRIT_MELEE or 9, critR = CR_CRIT_RANGED or 10, critS = CR_CRIT_SPELL or 11,
    hasteM = CR_HASTE_MELEE or 18, hasteR = CR_HASTE_RANGED or 19, hasteS = CR_HASTE_SPELL or 20,
    exp = CR_EXPERTISE or 24, arp = CR_ARMOR_PENETRATION or 25,
}

-- Talents that give hit, per class: { talent name, kind, % per rank, note }
-- kind: melee, ranged, spell, or debuff (a raid debuff the talent puts on the boss).
-- A 5th field limits a school-only talent to the spec that casts that school.
local HIT_TALENTS = {
    WARRIOR     = { { "Precision", "melee", 1 } },
    ROGUE       = { { "Precision", "melee", 1 }, { "Precision", "ranged", 1 } },
    DEATHKNIGHT = { { "Nerves of Cold Steel", "melee", 1, "one-hand weapons only" } },
    SHAMAN      = { { "Dual Wield Specialization", "melee", 2, "while dual wielding" },
                    { "Elemental Precision", "spell", 1, "Fire, Frost and Nature spells" } },
    HUNTER      = { { "Focused Aim", "ranged", 1 } },
    MAGE        = { { "Precision", "spell", 1 }, { "Arcane Focus", "spell", 1, "Arcane spells only", "arcane" } },
    WARLOCK     = { { "Suppression", "spell", 1 } },
    PRIEST      = { { "Shadow Focus", "spell", 1, "Shadow spells", "shadow" }, { "Misery", "debuff", 1 } },
    DRUID       = { { "Balance of Power", "spell", 2 }, { "Improved Faerie Fire", "debuff", 1 } },
}

local LABEL = {
    hitM = "Hit (melee)", hitR = "Hit (ranged)", hitS = "Hit (spells)", exp = "Expertise", def = "Defense",
    arp = "Armor Pen", sp = "Spell Power", haste = "Haste rating", crit = "Crit rating", int = "Intellect",
    spi = "Spirit", mp5 = "MP5", str = "Strength", agi = "Agility", sta = "Stamina", ap = "Attack Power",
    rap = "Ranged AP", health = "Health", armor = "Armor", dodge = "Dodge %", parry = "Parry %",
}
-- these include buffs on your character sheet; the BiS numbers do not
local BUFFED = { sp = true, int = true, spi = true, str = true, agi = true, sta = true, ap = true, rap = true,
                 health = true, armor = true, dodge = true, parry = true }
local CAP = { hitM = true, hitR = true, hitS = true, exp = true, def = true, arp = true }

local HELP = {
    hitM = "Chance to hit a raid boss (3 levels above you) with melee attacks and specials. 8% is the cap; past it, hit does nothing.",
    hitR = "Chance to hit a raid boss with ranged attacks. 8% is the cap; past it, hit does nothing.",
    hitS = "Chance for spells not to be resisted by a raid boss. 17% is the cap; past it, hit does nothing.",
    exp = "Stops the boss dodging your attacks. 26 expertise (6.5%) removes dodge. Attacking from behind, parry does not matter; tanks in front also want 56 to remove parry.",
    def = "540 defense makes you uncrittable by raid bosses (unless a talent or Survival of the Fittest already does it).",
    arp = "Armor penetration is capped at 100% (1400 rating). Procs like Deathbringer's Will or Mjolnir Runestone push you over, so many stop a bit below.",
}

local function font(parent, size, template)
    local fs = parent:CreateFontString(nil, "OVERLAY", template or "GameFontHighlight")
    if size then fs:SetFont(STANDARD_TEXT_FONT, size, "") end
    return fs
end

local function fmt(v)
    if v == nil then return "|cff7f7f7f-|r" end
    if v ~= math.floor(v) then return ("%.2f"):format(v) end
    return tostring(v)
end

-- ---------- talents and race ----------
local function rankFromStrings(cls, strings, name)
    local trees = WarmaneBiSGear_Talents and WarmaneBiSGear_Talents[cls]
    if not trees or not strings then return 0, 0 end
    for ti, tree in ipairs(trees) do
        local s = strings[ti] or ""
        for i, t in ipairs(tree.t) do
            if t[4] == name then return tonumber(s:sub(i, i)) or 0, t[3] end
        end
    end
    return 0, 0
end

-- Is this you, in this spec? Then your own talents count, otherwise the BiS build's.
function W:StatsIsLive(cls, spec)
    local _, mine = UnitClass("player")
    if mine ~= cls then return false end
    local best, bestPts = 1, -1
    for tab = 1, 3 do
        local _, _, pts = GetTalentTabInfo(tab)
        if (pts or 0) > bestPts then best, bestPts = tab, pts or 0 end
    end
    return best == spec.tree
end

-- Hit the spec gets without rating: { melee, ranged, spell, debuff } in %, plus lines for the tooltip.
function W:StatsHitFromTalents(cls, spec, live)
    local strings = spec.talents
    if live and self.MyTalents then
        local _, d = self.MyTalents()
        if d then strings = d end
    end
    local out, lines = { melee = 0, ranged = 0, spell = 0, debuff = 0 }, {}
    for _, h in ipairs(HIT_TALENTS[cls] or {}) do
        local r, max = rankFromStrings(cls, strings, h[1])
        if h[5] and h[5] ~= spec.key then r = 0 end
        if r > 0 then
            out[h[2]] = out[h[2]] + r * h[3]
            lines[#lines + 1] = { kind = h[2], text = ("%s %d/%d: %d%%%s"):format(h[1], r, max, r * h[3],
                h[4] and (" (" .. h[4] .. ")") or "") }
        end
    end
    return out, lines
end

-- Your own race when it is your class, otherwise the race of the export's character.
local function selfDraenei(cls, d)
    if select(2, UnitClass("player")) == cls then
        local _, race = UnitRace("player")
        return race == "Draenei"
    end
    return d.race == "DRAENEI"
end

-- Specs whose BiS set goes past the cap on purpose.
local PAST_CAP = {
    ["ROGUE.assa"] = "Rogues keep hit past 8%: off-hand white hits miss up to 27% and poisons use spell hit (17%).",
    ["ROGUE.combat"] = "Rogues keep hit past 8%: off-hand white hits miss up to 27% and poisons use spell hit (17%).",
    ["ROGUE.combat_rupture"] = "Rogues keep hit past 8%: off-hand white hits miss up to 27% and poisons use spell hit (17%).",
    ["SHAMAN.enh"] = "Enhancement keeps hit past 8%: Lightning Bolt and shocks use spell hit (17%) and white hits miss more.",
    ["SHAMAN.spellhancer"] = "Enhancement keeps hit past 8%: Lightning Bolt and shocks use spell hit (17%) and white hits miss more.",
    ["DEATHKNIGHT.frost"] = "Frost keeps some hit past 8% for Howling Blast and Icy Touch, which use spell hit (17%).",
}
W.STATS_PAST_CAP = PAST_CAP

-- ---------- caps ----------
-- Returns { need = rating needed (0 = capped by talents alone), pct = what the
-- rating has to cover, lines = breakdown for the tooltip }.
function W:StatsCap(id, cls, key, spec, live)
    local d = WarmaneBiSGear_Stats[cls][key]
    local raid = not (self.db and self.db.statsRaid == false)
    local tal, tlines = self:StatsHitFromTalents(cls, spec, live)
    local dra = selfDraenei(cls, d)
    local lines = {}
    if id == "hitM" or id == "hitR" or id == "hitS" then
        local base = (id == "hitS") and 17 or 8
        local kind = (id == "hitM" and "melee") or (id == "hitR" and "ranged") or "spell"
        local pct = base
        lines[#lines + 1] = ("Cap: %d%% against a raid boss"):format(base)
        for _, l in ipairs(tlines) do
            if l.kind == kind then lines[#lines + 1] = "- " .. l.text end
        end
        pct = pct - tal[kind]
        if dra then pct = pct - 1; lines[#lines + 1] = "- Heroic Presence (you are a Draenei): 1%"
        elseif raid then pct = pct - 1; lines[#lines + 1] = "- a Draenei in your group: 1%" end
        if id == "hitS" then
            local deb = tal.debuff
            if raid and deb < 3 then deb = 3 end
            if deb > 0 then
                pct = pct - deb
                lines[#lines + 1] = ("- Misery or Improved Faerie Fire on the boss: %d%%"):format(deb)
            end
        end
        if pct < 0 then pct = 0 end
        local per = (id == "hitS") and HIT_SPELL or HIT_MELEE
        local need = math.ceil(pct * per - 0.02)   -- 13% = 341.02 -> 341, 8% = 262.3 -> 263
        lines[#lines + 1] = ("Left for gear: %.2f%% = %d rating"):format(pct, need)
        return { need = need, lines = lines }
    elseif id == "exp" then
        local non = d.exp0
        if live and GetExpertise then
            local e = GetExpertise() or 0
            local fromRating = (GetCombatRatingBonus and GetCombatRatingBonus(CR.exp)) or 0
            non = math.floor(e - fromRating + 0.5)
        end
        lines[#lines + 1] = "Cap: 26 expertise (removes dodge)"
        if non > 0 then lines[#lines + 1] = ("- from talents and race: %d"):format(non) end
        if d.sovGlyph then
            local sealOn = live and UnitBuff and (UnitBuff("player", "Seal of Vengeance") or UnitBuff("player", "Seal of Corruption"))
            if not sealOn then non = non + 10 end
            lines[#lines + 1] = "- Glyph of Seal of Vengeance: 10 (only while the seal is on)"
        end
        local left = math.max(0, 26 - non)
        local need = math.ceil(left * EXP_RATING - 0.02)
        lines[#lines + 1] = ("Left for gear: %d expertise = %d rating"):format(left, need)
        if d.role == "tank" then
            lines[#lines + 1] = ("Tanks: 56 removes parry too = %d rating"):format(math.ceil(math.max(0, 56 - non) * EXP_RATING - 0.02))
        end
        return { need = need, lines = lines }
    elseif id == "def" then
        lines[#lines + 1] = "Cap: 540 defense skill = 689 defense rating on top of your 400"
        return { need = 540, lines = lines }
    elseif id == "arp" then
        lines[#lines + 1] = "Cap: 100% armor penetration = 1400 rating"
        return { need = ARP_CAP, lines = lines }
    end
end

-- ---------- your own numbers ----------
local function stat(i) local _, v = UnitStat("player", i); return v end
function W:StatsMine(id, role)
    local hasteCR = (role == "hunter" and CR.hasteR) or ((role == "caster" or role == "healer") and CR.hasteS) or CR.hasteM
    local critCR = (role == "hunter" and CR.critR) or ((role == "caster" or role == "healer") and CR.critS) or CR.critM
    if id == "hitM" then return GetCombatRating(CR.hitM)
    elseif id == "hitR" then return GetCombatRating(CR.hitR)
    elseif id == "hitS" then return GetCombatRating(CR.hitS)
    elseif id == "exp" then return GetCombatRating(CR.exp)
    elseif id == "arp" then return GetCombatRating(CR.arp)
    elseif id == "haste" then return GetCombatRating(hasteCR)
    elseif id == "crit" then return GetCombatRating(critCR)
    elseif id == "def" then local b, m = UnitDefense("player"); return (b or 0) + (m or 0)
    elseif id == "sp" then
        if role == "healer" then return GetSpellBonusHealing() end
        local best = 0
        for school = 2, 7 do best = math.max(best, GetSpellBonusDamage(school) or 0) end
        return best
    elseif id == "str" then return stat(1)
    elseif id == "agi" then return stat(2)
    elseif id == "sta" then return stat(3)
    elseif id == "int" then return stat(4)
    elseif id == "spi" then return stat(5)
    elseif id == "ap" then local b, p, n = UnitAttackPower("player"); return (b or 0) + (p or 0) + (n or 0)
    elseif id == "rap" then local b, p, n = UnitRangedAttackPower("player"); return (b or 0) + (p or 0) + (n or 0)
    elseif id == "health" then return UnitHealthMax("player")
    elseif id == "armor" then local _, a = UnitArmor("player"); return a
    elseif id == "dodge" then return math.floor(GetDodgeChance() * 100 + 0.5) / 100
    elseif id == "parry" then return math.floor(GetParryChance() * 100 + 0.5) / 100
    end
    return nil   -- mp5: the client has no gear-only number for it
end

-- One row's text: target, BiS, yours, status. Exposed for the tests.
function W:StatsRow(cls, key, spec, id, bis, live, mine)
    local r = { id = id, label = LABEL[id] or id, bis = bis, mine = mine }
    if CAP[id] then
        local c = self:StatsCap(id, cls, key, spec, live)
        r.cap, r.lines = c.need, c.lines
        local why = PAST_CAP[cls .. "." .. key]
        if why and id == "hitM" and bis and bis > c.need + 15 then
            r.lines[#r.lines + 1] = why
        end
        if mine then
            local diff = mine - c.need
            if id == "def" then
                if diff >= 0 then r.status = "|cff40ff40uncrittable|r"
                else r.status = ("|cffff5050%d defense short|r"):format(-diff) end
            elseif id == "arp" then
                if diff > 0 then r.status = ("|cffffb000%d over the cap|r"):format(diff)
                elseif diff == 0 then r.status = "|cff40ff40capped|r"
                else r.status = ("|cffffd100%d below the cap|r"):format(-diff) end
            elseif c.need == 0 then
                r.status = mine > 0 and ("|cffffb000capped by talents, %d wasted|r"):format(mine) or "|cff40ff40capped by talents|r"
            elseif diff >= 0 and diff <= 15 then r.status = "|cff40ff40capped|r"
            elseif diff > 15 and bis and bis > c.need + 15 then
                r.status = ("|cff40ff40capped|r, BiS goes on to %d"):format(bis)
            elseif diff > 15 then r.status = ("|cffffb000%d over, swap some for other stats|r"):format(diff)
            else r.status = ("|cffff5050need %d more|r"):format(-diff) end
        end
    else
        r.cap = nil
        if mine and bis and bis > 0 then
            local p = math.floor(mine / bis * 100 + 0.5)
            local col = (p >= 100 and "|cff40ff40") or (p >= 85 and "|cffffd100") or "|cffff8040"
            r.status = col .. p .. "% of BiS|r"
        end
    end
    return r
end

-- ---------- the panel ----------
local COLS = { 24, 214, 330, 446, 556 }
local ROWS = 12

function W:BuildStats(panel)
    local heads = { "STAT", "CAP", "BiS SET", "YOU", "" }
    for i, h in ipairs(heads) do
        local fs = font(panel, 12, "GameFontNormal")
        fs:SetPoint("TOPLEFT", panel, "TOPLEFT", COLS[i], -16)
        fs:SetText(h)
    end
    panel.rows = {}
    for i = 1, ROWS do
        local r = CreateFrame("Frame", nil, panel)
        r:SetHeight(28); r:SetWidth(840)
        r:SetPoint("TOPLEFT", panel, "TOPLEFT", 12, -38 - (i - 1) * 30)
        r:EnableMouse(true)
        r.bg = r:CreateTexture(nil, "BACKGROUND")
        r.bg:SetAllPoints(r); r.bg:SetTexture(1, 1, 1, (i % 2 == 0) and 0.03 or 0.06)
        r.cells = {}
        for c = 1, 5 do
            local fs = font(r, 14)
            fs:SetPoint("LEFT", r, "LEFT", COLS[c] - 12 + 6, 0)
            r.cells[c] = fs
        end
        r:SetScript("OnEnter", function(self)
            if not self.data then return end
            GameTooltip:SetOwner(self, "ANCHOR_RIGHT")
            GameTooltip:AddLine(self.data.label)
            if HELP[self.data.id] then GameTooltip:AddLine(HELP[self.data.id], 1, 1, 1, true) end
            for _, l in ipairs(self.data.lines or {}) do GameTooltip:AddLine(l, 0.6, 0.85, 1, true) end
            if not CAP[self.data.id] then
                GameTooltip:AddLine("BiS SET is what the full BiS set ends up with (gear, gems, enchants, talents, no raid buffs). Use it as the number to aim for.", 0.8, 0.8, 0.8, true)
            end
            if BUFFED[self.data.id] then
                GameTooltip:AddLine("Your number includes the buffs on you right now. Compare it unbuffed.", 1, 0.6, 0.3, true)
            end
            GameTooltip:Show()
        end)
        r:SetScript("OnLeave", function() GameTooltip:Hide() end)
        panel.rows[i] = r
    end

    local cb = CreateFrame("CheckButton", "WarmaneBiSGearStatsRaid", panel, "UICheckButtonTemplate")
    cb:SetWidth(24); cb:SetHeight(24)
    cb:SetPoint("BOTTOMLEFT", panel, "BOTTOMLEFT", 16, 52)
    cb.text = font(panel, 12)
    cb.text:SetPoint("LEFT", cb, "RIGHT", 4, 1)
    cb.text:SetText("Count raid hit: a Draenei in the group (+1% hit) and Misery or Improved Faerie Fire (+3% spell hit)")
    cb:SetScript("OnClick", function(self)
        W.db.statsRaid = self:GetChecked() and true or false
        if W.spec then W:ShowStats(panel) end
    end)
    panel.raid = cb

    panel.who = font(panel, 12, "GameFontNormal")
    panel.who:SetPoint("BOTTOMLEFT", panel, "BOTTOMLEFT", 18, 32)
    panel.note = font(panel, 11, "GameFontDisable")
    panel.note:SetPoint("BOTTOMLEFT", panel, "BOTTOMLEFT", 18, 12)
    panel.note:SetText("BiS SET numbers come from the sixtyupgrades export of this set, without raid buffs. Hover a row for how it is worked out.")

    -- keep "YOU" current while the tab is open
    local dirty, t = false, 0
    local ev = CreateFrame("Frame", nil, panel)
    for _, e in ipairs({ "UNIT_INVENTORY_CHANGED", "COMBAT_RATING_UPDATE", "PLAYER_TALENT_UPDATE",
                         "CHARACTER_POINTS_CHANGED", "UNIT_AURA", "PLAYER_EQUIPMENT_CHANGED" }) do
        pcall(ev.RegisterEvent, ev, e)
    end
    ev:SetScript("OnEvent", function(_, e, unit)
        if (e == "UNIT_AURA" or e == "UNIT_INVENTORY_CHANGED") and unit ~= "player" then return end
        dirty = true
    end)
    ev:SetScript("OnUpdate", function(_, el)
        t = t + (el or 0)
        if t < 0.5 then return end
        t = 0
        if dirty and panel:IsVisible() and W.spec then dirty = false; W:ShowStats(panel) end
    end)
end

function W:ShowStats(panel)
    local cls, spec = self.cls, self.spec
    local d = WarmaneBiSGear_Stats and WarmaneBiSGear_Stats[cls] and WarmaneBiSGear_Stats[cls][spec.key]
    panel.raid:SetChecked(not (self.db and self.db.statsRaid == false))
    if not d then
        for _, r in ipairs(panel.rows) do r:Hide() end
        panel.who:SetText("No stats for this spec yet.")
        return
    end
    local _, myCls = UnitClass("player")
    local live = self:StatsIsLive(cls, spec)
    local same = (myCls == cls)
    for i, r in ipairs(panel.rows) do
        local row = d.rows[i]
        if row then
            local id, bis = row[1], row[2]
            local mine = same and self:StatsMine(id, d.role) or nil
            local x = self:StatsRow(cls, spec.key, spec, id, bis, live, mine)
            r.data = x
            r.cells[1]:SetText(x.label .. (BUFFED[id] and same and " |cffff9933*|r" or ""))
            r.cells[2]:SetText(x.cap and ("|cff66ccff" .. fmt(x.cap) .. "|r") or "|cff7f7f7f-|r")
            r.cells[3]:SetText(fmt(bis))
            r.cells[4]:SetText(same and fmt(mine) or "|cff7f7f7f-|r")
            r.cells[5]:SetText(x.status or "")
            r:Show()
        else
            r.data = nil
            r:Hide()
        end
    end
    if same and live then
        panel.who:SetText("YOU = your character now, caps use your own talents.  |cffff9933*|r includes your current buffs.")
    elseif same then
        panel.who:SetText("YOU = your character now. You are not in this spec, so caps use the BiS talents.")
    else
        panel.who:SetText("Not your class: caps use the BiS talents, YOU is empty.")
    end
end
end
