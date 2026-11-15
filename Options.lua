-- Threat Box options: a canvas page under Options > AddOns, with a nameplate preview across the
-- top where the box is moved by mouse (drag to nudge, drop on a highlighted area to pin it
-- there, wheel to resize), and every setting as a control in a scrolling area underneath: a
-- tab each for the threat box, the pet box and the target box, then what they share.
--
-- A canvas page only. Proxy settings (Settings.RegisterProxySetting) tainted Blizzard's nameplates
-- on this client, so every control here is our own and writes straight to the saved table.
local ADDON, ns = ...

local O = {}
ns.Options = O

local TITLE = ns.TITLE
local refreshers = {}
local settingsPage, settingsCategory, content

local font = {
    text = _G.GameFontHighlightMedium and "GameFontHighlightMedium" or "GameFontHighlight",
    head = _G.GameFontNormalLarge and "GameFontNormalLarge" or "GameFontNormal",
    note = "GameFontDisable",
}

local PREVIEW_H = 190
local COL_W = 290
local TAB_W, TAB_H = 110, 28
local ZONE_DEPTH, ZONE_REACH = 34, 8 -- how far out a drop area reaches, and past the ends

local function TryCreate(kind, name, parent, templates)
    for _, template in ipairs(templates) do
        local ok, made = pcall(CreateFrame, kind, name, parent, template)
        if ok and made then return made, template end
    end
    return CreateFrame(kind, name, parent), "bare"
end

local function HasAtlas(name)
    return not (C_Texture and C_Texture.GetAtlasInfo) or C_Texture.GetAtlasInfo(name) ~= nil
end

local function Refresh()
    for _, refresh in ipairs(refreshers) do refresh() end
end
O.Refresh = Refresh

------------------------------------------------------------------------
-- Controls
------------------------------------------------------------------------
local function Heading(parent, text, x, y)
    local h = parent:CreateFontString(nil, "OVERLAY", font.head)
    h:SetPoint("TOPLEFT", x, y)
    h:SetText(text)
    return h
end

local function Note(parent, text, x, y, width)
    local n = parent:CreateFontString(nil, "OVERLAY", font.note)
    n:SetPoint("TOPLEFT", x, y)
    n:SetWidth(width)
    n:SetJustifyH("LEFT")
    n:SetText(text)
    return n
end

local function Check(parent, label, x, y, get, set)
    local cb = TryCreate("CheckButton", nil, parent, { "UICheckButtonTemplate", "ChatConfigCheckButtonTemplate" })
    cb:SetSize(24, 24)
    cb:SetPoint("TOPLEFT", x, y)
    cb.label = cb:CreateFontString(nil, "OVERLAY", font.text)
    cb.label:SetPoint("LEFT", cb, "RIGHT", 2, 0)
    cb.label:SetText(label)
    cb:SetScript("OnClick", function(self)
        set(self:GetChecked() and true or false)
        Refresh()
    end)
    refreshers[#refreshers + 1] = function() cb:SetChecked(get() and true or false) end
    return cb
end

-- A button that steps through choices: left-click forward, right-click back.
local function Cycle(parent, label, x, y, values, labels, get, set)
    local cap = parent:CreateFontString(nil, "OVERLAY", font.text)
    cap:SetPoint("TOPLEFT", x, y - 4)
    cap:SetText(label)
    local b = TryCreate("Button", nil, parent, { "UIPanelButtonTemplate" })
    b:SetSize(170, 22)
    b:SetPoint("TOPLEFT", parent, "TOPLEFT", math.floor(x / (COL_W + 30)) * (COL_W + 30) + COL_W - 190, y)
    b:RegisterForClicks("LeftButtonUp", "RightButtonUp")
    b:SetScript("OnClick", function(_, button)
        local idx = 1
        for i, v in ipairs(values) do if v == get() then idx = i end end
        idx = (button == "RightButton") and ((idx - 2) % #values + 1) or (idx % #values + 1)
        set(values[idx])
        Refresh()
    end)
    refreshers[#refreshers + 1] = function() b:SetText(labels[get()] or labels[values[1]]) end
    return b
end

local sliderCount = 0
-- A slider whose value is also a box you can type in (negative numbers too); Enter applies it.
local function Slider(parent, label, x, y, minV, maxV, step, get, set)
    sliderCount = sliderCount + 1
    local name = "ThreatBoxOptionsSlider" .. sliderCount
    local width = COL_W - 20
    local holder = CreateFrame("Frame", nil, parent)
    holder:SetPoint("TOPLEFT", x, y)
    holder:SetSize(width, 40)
    local caption = holder:CreateFontString(nil, "ARTWORK", font.text)
    caption:SetPoint("TOPLEFT", 0, 0)
    caption:SetText(label)

    local value = TryCreate("EditBox", name .. "Value", holder, { "InputBoxTemplate" })
    value:SetSize(44, 18)
    value:SetPoint("TOPRIGHT", -2, 2)
    value:SetAutoFocus(false)
    value:SetMaxLetters(4)
    value:SetJustifyH("CENTER")
    if not value:GetFontObject() then value:SetFontObject(ChatFontNormal) end

    local slider = TryCreate("Slider", name, holder, { "MinimalSliderTemplate", "UISliderTemplate", "OptionsSliderTemplate" })
    for _, suffix in ipairs({ "Low", "High", "Text" }) do
        local extra = _G[name .. suffix]
        if extra then extra:SetText("") extra:Hide() end
    end
    if slider.SetOrientation then slider:SetOrientation("HORIZONTAL") end
    slider:SetPoint("TOPLEFT", 2, -18)
    slider:SetSize(width - 6, 18)
    slider:SetMinMaxValues(minV, maxV)
    if slider.SetValueStep then slider:SetValueStep(step) end
    if slider.SetObeyStepOnDrag then pcall(slider.SetObeyStepOnDrag, slider, true) end

    slider:SetScript("OnValueChanged", function(self, v)
        v = math.floor(v / step + 0.5) * step
        value:SetText(v)
        if self.syncing then return end
        set(v)
    end)
    local committing = false
    local function Commit(self)
        if committing then return end
        committing = true
        local v = tonumber(self:GetText())
        if v then
            v = math.max(minV, math.min(maxV, math.floor(v / step + 0.5) * step))
            set(v)
            slider.syncing = true
            slider:SetValue(v)
            slider.syncing = false
        end
        self:SetText(get())
        self:ClearFocus()
        committing = false
    end
    value:SetScript("OnEnterPressed", Commit)
    value:SetScript("OnEditFocusLost", Commit)
    value:SetScript("OnEscapePressed", function(self)
        committing = true
        self:SetText(get())
        self:ClearFocus()
        committing = false
    end)
    refreshers[#refreshers + 1] = function()
        slider.syncing = true
        slider:SetValue(get())
        slider.syncing = false
        if not value:HasFocus() then value:SetText(get()) end
    end
    return slider
end

------------------------------------------------------------------------
-- The nameplate preview
------------------------------------------------------------------------
-- A mock of the game's nameplate (Blizzard_NamePlates on WoW Forever): the Cooldown Manager bar
-- art as the health bar, its "Bar-BG" plate as the frame, the level box 5 to the right. The
-- threat box on it is made and placed by the same code as on real nameplates.
local function BuildPreview(c)
    local db = ns.db
    local P = {}
    O.preview = P

    local preview = CreateFrame("Frame", nil, c)
    preview:SetPoint("TOPLEFT", c, "TOPLEFT", 0, 0)
    preview:SetPoint("RIGHT", c, "RIGHT", 0, 0)
    preview:SetHeight(PREVIEW_H)
    if preview.SetClipsChildren then preview:SetClipsChildren(true) end
    local bg = preview:CreateTexture(nil, "BACKGROUND")
    bg:SetAllPoints()
    bg:SetColorTexture(0.12, 0.1, 0.08, 0.6)
    local label = preview:CreateFontString(nil, "OVERLAY", "GameFontDisableSmall")
    label:SetPoint("TOPLEFT", 8, -6)
    label:SetText("Nameplate preview")
    local help = preview:CreateFontString(nil, "OVERLAY", "GameFontNormal")
    help:SetPoint("TOPRIGHT", preview, "TOPRIGHT", -10, -6)
    help:SetJustifyH("RIGHT")
    help:SetText("Drag the threat box to move it. Mouse wheel to resize.")
    local help2 = preview:CreateFontString(nil, "OVERLAY", "GameFontDisableSmall")
    help2:SetPoint("TOPRIGHT", help, "BOTTOMRIGHT", 0, -3)
    help2:SetJustifyH("RIGHT")
    help2:SetText("Drop it on a highlighted area to pin it there. Click it to see each threat color.\nThe pet box and the target box drag off the same way; drop one on the threat box to rejoin it.")

    local plate = CreateFrame("Frame", nil, preview)
    plate:SetAllPoints()
    local bar = plate:CreateTexture(nil, "ARTWORK")
    bar:SetPoint("CENTER", preview, "CENTER", -14, -6)
    if HasAtlas("UI-HUD-CoolDownManager-Bar") then bar:SetAtlas("UI-HUD-CoolDownManager-Bar") else bar:SetColorTexture(1, 1, 1, 1) end
    bar:SetVertexColor(0.9, 0.15, 0.1)
    local frameArt = plate:CreateTexture(nil, "BACKGROUND")
    if HasAtlas("UI-HUD-CoolDownManager-Bar-BG") then frameArt:SetAtlas("UI-HUD-CoolDownManager-Bar-BG") else frameArt:SetColorTexture(0, 0, 0, 0.9) end
    frameArt:SetPoint("TOPLEFT", bar, "TOPLEFT", -2, 3)
    frameArt:SetPoint("BOTTOMRIGHT", bar, "BOTTOMRIGHT", 6, -6)
    local name = plate:CreateFontString(nil, "OVERLAY", _G.SystemFont_NamePlate and "SystemFont_NamePlate" or "GameFontHighlightSmall")
    name:SetPoint("BOTTOM", bar, "TOP", 0, 2)
    name:SetText("Blind Screecher")
    -- The level box is a frame, as on a real nameplate, so the threat box sizes itself from it.
    local level = CreateFrame("Frame", nil, plate)
    level:SetPoint("LEFT", bar, "RIGHT", 5, 0.5)
    local levelBg = level:CreateTexture(nil, "BACKGROUND")
    levelBg:SetAllPoints()
    if HasAtlas("ui-hud-nameplates-levelindicator") then levelBg:SetAtlas("ui-hud-nameplates-levelindicator") else levelBg:SetColorTexture(0, 0, 0, 0.7) end
    local levelText = level:CreateFontString(nil, "OVERLAY", _G.SystemFont_NamePlateLevel and "SystemFont_NamePlateLevel" or "GameFontHighlightSmall")
    levelText:SetPoint("CENTER", level, "CENTER", 0, 0)
    levelText:SetText("|cff40c04042|r")

    local box = ns.MakeBox(plate, false)
    P.frame, P.plate, P.bar, P.level, P.box = preview, plate, bar, level, box
    P.status = ns.PREVIEW_STATUS

    -- The drop areas: one per position, around the level box and left of the health bar.
    local zoneLayer = CreateFrame("Frame", nil, plate)
    zoneLayer:SetAllPoints()
    zoneLayer:SetFrameLevel(plate:GetFrameLevel() + 60)
    zoneLayer:Hide()
    local zones = {}
    for _, side in ipairs(ns.POSITION_ORDER) do
        zones[side] = zoneLayer:CreateTexture(nil, "OVERLAY")
    end
    zones.below:SetPoint("TOPLEFT", level, "BOTTOMLEFT", -ZONE_REACH, 0)
    zones.below:SetPoint("BOTTOMRIGHT", level, "BOTTOMRIGHT", ZONE_REACH, -ZONE_DEPTH)
    zones.above:SetPoint("BOTTOMLEFT", level, "TOPLEFT", -ZONE_REACH, 0)
    zones.above:SetPoint("TOPRIGHT", level, "TOPRIGHT", ZONE_REACH, ZONE_DEPTH)
    zones.right:SetPoint("TOPLEFT", level, "TOPRIGHT", 0, ZONE_REACH)
    zones.right:SetPoint("BOTTOMRIGHT", level, "BOTTOMRIGHT", ZONE_DEPTH + 16, -ZONE_REACH)
    zones.left:SetPoint("TOPRIGHT", bar, "TOPLEFT", 0, ZONE_REACH)
    zones.left:SetPoint("BOTTOMLEFT", bar, "BOTTOMLEFT", -(ZONE_DEPTH + 16), -ZONE_REACH)
    P.zones, P.zoneLayer = zones, zoneLayer

    -- The mock at the sizes the game's nameplates have right now (its own layout numbers, read
    -- only), then the threat box on it.
    local function Draw()
        local opts = type(NamePlateSetupOptions) == "table" and NamePlateSetupOptions or {}
        local h = type(opts.horizontalScale) == "number" and opts.horizontalScale or 1
        local v = type(opts.verticalScale) == "number" and opts.verticalScale or 1
        local barH = type(opts.healthBarHeight) == "number" and opts.healthBarHeight or 13 * v
        bar:SetSize(130 * h, barH)
        local levelW = type(opts.playerLevelDiffWidth) == "number" and opts.playerLevelDiffWidth or 28 * h
        level:SetSize(levelW, barH + 5)
        if name.SetTextHeight then name:SetTextHeight(type(opts.healthBarFontHeight) == "number" and opts.healthBarFontHeight or 14 * v) end
        if levelText.SetTextHeight then levelText:SetTextHeight(type(opts.levelFontHeight) == "number" and opts.levelFontHeight or 10 * v) end
        box.layoutKey = nil
        ns.Place(box, level, bar, 1)
        box.chainKey = nil
        ns.ShowSample(box, P.status) -- with the pet's box and the name plaque, when they are on
        if P.HookPieces then P.HookPieces() end
    end
    P.Draw = Draw
    -- In the Dark and EllesmereUI looks the mock's level box goes flat too, like the threat box.
    local function Flatten()
        local S = ns.Styles and ns.Styles.S
        if not S or P.flat then return end
        P.flat = true
        local r, g, b = S.GetPanelColor()
        levelBg:SetColorTexture(r or 0.07, g or 0.07, b or 0.08, 0.92)
        Draw()
    end
    O.Flatten = Flatten
    Flatten()
    O.RefreshPreview = function() if preview:IsVisible() then Draw() end end

    -- Which drop area the cursor is in (screen pixels, as GetCursorPosition gives them).
    local function ZoneAt()
        local es = plate:GetEffectiveScale() or 1
        local x, y = GetCursorPosition()
        for _, side in ipairs(ns.POSITION_ORDER) do
            local z = zones[side]
            local l, r, t, b = z:GetLeft(), z:GetRight(), z:GetTop(), z:GetBottom()
            if l and r and t and b and x >= l * es and x <= r * es and y >= b * es and y <= t * es then
                return side
            end
        end
    end

    -- Every area shows while dragging: the one the box is pinned to tinted, the one under the
    -- cursor gold.
    local function ShowZones(current, hot)
        for side, z in pairs(zones) do
            if side == hot then
                z:SetColorTexture(1, 0.82, 0, 0.45)
            elseif side == current then
                z:SetColorTexture(1, 0.82, 0, 0.16)
            else
                z:SetColorTexture(1, 1, 1, 0.12)
            end
        end
        zoneLayer:Show()
    end

    -- One drag at a time. spec: frame (what is dragged; its scale is the unit of its nudge),
    -- side() -> the area it is pinned to (nil for a piece still in the row), get() -> x, y,
    -- set(x, y), drop(side) for a drop on another area, and for the pet box and the name plaque
    -- rejoin() for a drop on the threat box.
    local drag
    local driver = CreateFrame("Frame", nil, preview)
    driver:Hide()

    -- Is the cursor over the threat box? (Where a detached piece is dropped to rejoin the row.)
    local function OverBox()
        local es = box:GetEffectiveScale() or 1
        local x, y = GetCursorPosition()
        local l, r, t, b = box:GetLeft(), box:GetRight(), box:GetTop(), box:GetBottom()
        return (l and r and t and b and x >= l * es and x <= r * es and y >= b * es and y <= t * es) and true or false
    end

    local function DragUpdate()
        local d = drag
        if not d then return end
        local cx, cy = GetCursorPosition()
        local scale = d.frame:GetEffectiveScale() or 1
        if scale <= 0 then scale = 1 end
        local limit = ns.OFFSET_LIMIT
        d.set(math.floor(math.max(-limit, math.min(limit, d.x0 + (cx - d.cx) / scale)) + 0.5),
            math.floor(math.max(-limit, math.min(limit, d.y0 + (cy - d.cy) / scale)) + 0.5))
        d.home = d.rejoin ~= nil and OverBox()
        local hot = (not d.home) and ZoneAt() or nil
        d.hot = (hot ~= d.side) and hot or nil
        ShowZones(d.side, d.hot)
        ns.Apply() -- real nameplates follow along, and the preview redraws
    end
    driver:SetScript("OnUpdate", DragUpdate)
    P.DragUpdate = DragUpdate

    local function StartDrag(spec)
        drag = spec
        spec.side = spec.where()
        spec.x0, spec.y0 = spec.get()
        spec.cx, spec.cy = GetCursorPosition()
        spec.hot, spec.home = nil, nil
        P.dragged = true
        ShowZones(spec.side, nil)
        driver:Show()
    end
    local function StopDrag()
        local d = drag
        if not d then return end
        DragUpdate() -- where it was let go
        drag = nil
        driver:Hide()
        zoneLayer:Hide()
        if d.home then
            d.set(d.x0, d.y0)
            d.rejoin()
        elseif d.hot then
            -- Dropped on another area: pinned there, at that area's own place.
            d.drop(d.hot)
        end
        Refresh()
    end
    P.Dragging = function() return drag ~= nil end

    local boxSpec = {
        frame = box,
        where = function() return db.position end,
        get = function() return db.offsetX, db.offsetY end,
        set = function(x, y) db.offsetX, db.offsetY = x, y end,
        drop = function(side)
            db.offsetX, db.offsetY = 0, 0
            ns.SetPosition(side)
        end,
    }
    P.StartDrag = function() StartDrag(boxSpec) end
    P.StopDrag = StopDrag

    -- The pet's box and the name plaque: in the row they do not move, but dropped on an area
    -- they leave the row and are pinned there on their own. Once detached they nudge and re-pin
    -- like the threat box, and a drop on the threat box puts them back in the row.
    local hooked = {}
    local function HookPiece(piece, frame)
        if not frame or hooked[frame] then return end
        hooked[frame] = true
        local set = ns.PIECES[piece]
        local spec = {
            frame = frame,
            where = function() return db[set.detached] and db[set.position] or nil end,
            get = function() return db[set.x], db[set.y] end,
            set = function(x, y)
                if db[set.detached] then db[set.x], db[set.y] = x, y end
            end,
            drop = function(side) ns.SetPiece(piece, side) end,
            rejoin = function() ns.SetPiece(piece, nil) end,
        }
        frame:EnableMouse(true)
        frame:RegisterForDrag("LeftButton")
        frame:SetScript("OnDragStart", function() StartDrag(spec) end)
        frame:SetScript("OnDragStop", StopDrag)
        frame:SetScript("OnMouseDown", function() if O.EditTab then O.EditTab(piece) end end)
        frame:EnableMouseWheel(true)
        frame:SetScript("OnMouseWheel", function(_, delta)
            local pct = math.floor(db[set.scale] * 100 + 0.5) + delta * 5
            db[set.scale] = math.max(ns.SCALE_MIN * 100, math.min(ns.SCALE_MAX * 100, pct)) / 100
            ns.Apply()
            Refresh()
        end)
        frame:SetScript("OnEnter", function(self)
            if drag or not GameTooltip then return end
            GameTooltip:SetOwner(self, "ANCHOR_TOP")
            GameTooltip:SetText(set.name, 1, 1, 1)
            GameTooltip:AddLine(db[set.detached]
                and "On its own. Drag to move, drop on a highlighted area to pin it there, or drop it on the threat box to put it back in the row. Mouse wheel to resize."
                or "In the row with the threat box. Drag it onto a highlighted area to put it there on its own. Mouse wheel to resize.", 0.7, 0.7, 0.7, true)
            GameTooltip:Show()
        end)
        frame:SetScript("OnLeave", function() if GameTooltip then GameTooltip:Hide() end end)
    end
    P.HookPieces = function()
        HookPiece("pet", box.pet)
        HookPiece("who", box.who)
    end
    P.HookPieces()

    box:EnableMouse(true)
    box:RegisterForDrag("LeftButton")
    box:SetScript("OnDragStart", P.StartDrag)
    box:SetScript("OnDragStop", StopDrag)
    box:SetScript("OnMouseDown", function()
        P.dragged = false
        if O.EditTab then O.EditTab("threat") end
    end)
    box:SetScript("OnMouseUp", function()
        if P.dragged or drag then return end
        P.status = (P.status + 1) % 4 -- a plain click steps through the four threat colors
        Draw()
    end)
    box:EnableMouseWheel(true)
    box:SetScript("OnMouseWheel", function(_, delta)
        local pct = math.floor(db.scale * 100 + 0.5) + delta * 5
        db.scale = math.max(ns.SCALE_MIN * 100, math.min(ns.SCALE_MAX * 100, pct)) / 100
        ns.Apply()
        Refresh()
    end)
    box:SetScript("OnEnter", function(self)
        if drag or not GameTooltip then return end
        GameTooltip:SetOwner(self, "ANCHOR_TOP")
        GameTooltip:SetText("Threat box", 1, 1, 1)
        GameTooltip:AddLine("Drag to move. Drop on a highlighted area to pin it there. Mouse wheel to resize. Click for the next threat color.", 0.7, 0.7, 0.7, true)
        GameTooltip:Show()
    end)
    box:SetScript("OnLeave", function() if GameTooltip then GameTooltip:Hide() end end)
    -- The page can close mid-drag: let go then.
    preview:SetScript("OnHide", StopDrag)

    refreshers[#refreshers + 1] = Draw
    return preview
end

------------------------------------------------------------------------
-- The page
------------------------------------------------------------------------
local function BuildContent(page)
    local c = CreateFrame("Frame", nil, page)
    c:SetPoint("TOPLEFT", 16, -44)
    c:SetPoint("BOTTOMRIGHT", -16, 8)
    local db = ns.db

    BuildPreview(c)

    -- The controls scroll under the preview.
    local scroll, template = TryCreate("ScrollFrame", "ThreatBoxOptionsScroll", c, { "ScrollFrameTemplate", "UIPanelScrollFrameTemplate" })
    scroll:SetPoint("TOPLEFT", c, "TOPLEFT", 0, -PREVIEW_H - 10)
    scroll:SetPoint("BOTTOMRIGHT", c, "BOTTOMRIGHT", -24, 0)
    if template == "bare" then
        scroll:EnableMouseWheel(true)
        scroll:SetScript("OnMouseWheel", function(self, delta)
            local range = self:GetVerticalScrollRange() or 0
            self:SetVerticalScroll(math.max(0, math.min(range, (self:GetVerticalScroll() or 0) - delta * 40)))
        end)
    end
    local WIDTH = COL_W * 2 + 30
    local column = CreateFrame("Frame", nil, scroll)
    column:SetSize(WIDTH + 16, 1)
    scroll:SetScrollChild(column)
    O.scroll, O.column = scroll, column

    local limit = ns.OFFSET_LIMIT
    local ui = {}   -- every control by name, for the tests
    O.ui = ui
    local col = column -- what the controls below are built into: the column, or a tab's block
    local x, y = 0, 0
    local RIGHT = COL_W + 30

    -- A tick box for one on/off setting.
    local function Toggle(key, label)
        ui[key] = Check(col, label or ns.TOGGLE_LABELS[key], x, y,
            function() return db[key] end,
            function(on) db[key] = on ns.Apply() end)
        y = y - 28
    end
    local function Head(text)
        Heading(col, text, x, y)
        y = y - 26
    end
    local function Text(text, indent, height)
        Note(col, text, x + (indent or 0), y + 2, COL_W - 10 - (indent or 0))
        y = y - (height or 30)
    end

    -- ---- the three boxes, a tab each -------------------------------------------------------
    local function ThreatControls()
        x, y = 0, 0
        Head("Place")
        ui.position = Cycle(col, "Position", x, y, ns.POSITION_ORDER, ns.POSITION_LABELS,
            function() return db.position end,
            function(v) ns.SetPosition(v) end)
        y = y - 34
        ui.offsetX = Slider(col, "Left / right", x, y, -limit, limit, 1,
            function() return db.offsetX end,
            function(v) db.offsetX = v ns.Apply() end)
        y = y - 46
        ui.offsetY = Slider(col, "Up / down", x, y, -limit, limit, 1,
            function() return db.offsetY end,
            function(v) db.offsetY = v ns.Apply() end)
        y = y - 46
        ui.scale = Slider(col, "Size (%)", x, y, ns.SCALE_MIN * 100, ns.SCALE_MAX * 100, 5,
            function() return math.floor(db.scale * 100 + 0.5) end,
            function(v) db.scale = v / 100 ns.Apply() end)
        y = y - 50

        Head("Warnings")
        Toggle("warn")
        y = y - 4
        ui.warnAt = Slider(col, "Pulse from (%)", x, y, 50, 100, 5,
            function() return db.warnAt end,
            function(v) db.warnAt = v ns.Apply() end)
        y = y - 44
        local warnNote = Note(col, "", x, y, COL_W - 10)
        refreshers[#refreshers + 1] = function()
            warnNote:SetText(ns.Reversed()
                and "As a tank, the box pulses on every enemy that is not on you."
                or "The box pulses once your threat reaches this, until the enemy is on you.")
        end
        y = y - 32
        Toggle("sound")
        Text("A sound when an enemy turns to you in a group, or as a tank when you lose one. Silent whenever the game hides that from addons.", 26, 44)
        local leftBottom = y

        x, y = RIGHT, 0
        Head("Number")
        ui.number = Cycle(col, "Shows", x, y, ns.NUMBER_ORDER, ns.NUMBER_LABELS,
            function() return db.number end,
            function(v) db.number = v ns.Apply() end)
        y = y - 26
        local numberNote = Note(col, "", x, y, COL_W - 10)
        refreshers[#refreshers + 1] = function()
            numberNote:SetText(db.number == "pull"
                and "100% is the point you take the enemy, worked out by the game for where you stand: melee range or farther away."
                or "As /console threatShowNumeric 1 shows it: you take the enemy at 110% in melee range, 130% from farther away.")
        end
        y = y - 44
        Toggle("percentSign", "Show the % sign")
        Toggle("fill")
        y = y - 8

        Head("Border")
        Toggle("colorBorder", "Color the border by threat")
        y = y - 2
        ui.colors = Cycle(col, "Colors", x, y, ns.COLOR_ORDER, ns.COLOR_LABELS,
            function() return db.colors end,
            function(v) db.colors = v ns.Apply() end)
        y = y - 26
        local colorNote = Note(col, "", x, y, COL_W - 10)
        refreshers[#refreshers + 1] = function()
            colorNote:SetText(ns.Reversed()
                and "Reversed: green while the enemy is safely on you, yellow when it is slipping, orange and red when you have lost it."
                or "Grey on the list, yellow catching up, orange about to change hands, red on you.")
        end
        y = y - 44
        y = math.min(y, leftBottom)
    end

    -- The pet box and the target box: on or off, in the row with the threat box or on its own,
    -- and where it is pinned then.
    local function PieceControls(piece, about, more)
        local set = ns.PIECES[piece]
        x, y = 0, 0
        Head(set.name)
        Toggle(piece)
        Text(about, 26, 44)
        ui[set.detached] = Check(col, "On its own, away from the threat box", x, y,
            function() return db[set.detached] end,
            function(on) ns.SetPiece(piece, on and db[set.position] or nil) end)
        y = y - 28
        Text("In the row it sits beside the threat box and moves with it. On its own it is pinned to the nameplate by the settings on the right.", 26, 58)
        ui[set.scale] = Slider(col, "Size (%)", x, y, ns.SCALE_MIN * 100, ns.SCALE_MAX * 100, 5,
            function() return math.floor(db[set.scale] * 100 + 0.5) end,
            function(v) db[set.scale] = v / 100 ns.Apply() end)
        y = y - 46
        if more then more() end
        local leftBottom = y

        x, y = RIGHT, 0
        Head("On its own")
        ui[set.position] = Cycle(col, "Pinned", x, y, ns.POSITION_ORDER, ns.POSITION_LABELS,
            function() return db[set.position] end,
            function(v) ns.SetPiece(piece, v) end)
        y = y - 34
        ui[set.x] = Slider(col, "Left / right", x, y, -limit, limit, 1,
            function() return db[set.x] end,
            function(v) db[set.x] = v ns.Apply() end)
        y = y - 46
        ui[set.y] = Slider(col, "Up / down", x, y, -limit, limit, 1,
            function() return db[set.y] end,
            function(v) db[set.y] = v ns.Apply() end)
        y = y - 50
        Text("Or drag it in the preview: onto a highlighted area to pin it there, onto the threat box to put it back in the row.", 0, 44)
        y = math.min(y, leftBottom)
    end

    local TABS = { "threat", "pet", "who" }
    local TAB_TEXT = { threat = "Threat box", pet = "Pet box", who = "Target box" }
    local editing = "threat"
    local tabs, blocks = {}, {}
    O.tabs, O.blocks = tabs, blocks

    -- The game's own top tabs, on the top edge of an inset that holds the picked box's controls.
    -- Their selected look is drawn here: the game's own way disables the tab.
    local function TabLook(tab, selected)
        local function Shown(region, on) if type(region) == "table" and region.SetShown then region:SetShown(on) end end
        if tab.isBare then
            if selected then tab:LockHighlight() else tab:UnlockHighlight() end
        else
            Shown(tab.Left, not selected) Shown(tab.Middle, not selected) Shown(tab.Right, not selected)
            Shown(tab.LeftActive, selected) Shown(tab.MiddleActive, selected) Shown(tab.RightActive, selected)
            local text = tab.Text or (tab.GetFontString and tab:GetFontString())
            if type(text) == "table" and text.SetPoint then
                text:ClearAllPoints()
                text:SetPoint("CENTER", tab, "CENTER", 0, selected and -4 or -8)
            end
        end
        if tab.SetNormalFontObject and GameFontHighlightSmall then
            tab:SetNormalFontObject(selected and GameFontHighlightSmall or GameFontNormalSmall)
        end
        tab.selected = selected
    end
    local function ShowEditing()
        for _, which in ipairs(TABS) do
            blocks[which]:SetShown(which == editing)
            TabLook(tabs[which], which == editing)
        end
    end
    O.EditTab = function(which)
        if not blocks[which] or editing == which then return end
        editing = which
        ShowEditing()
    end
    O.Editing = function() return editing end

    local insetTop = -TAB_H - 2
    local inset, insetTemplate = TryCreate("Frame", nil, column, { "InsetFrameTemplate" })
    inset:SetPoint("TOPLEFT", column, "TOPLEFT", 0, insetTop)
    inset:SetWidth(WIDTH + 16)
    if insetTemplate == "bare" then
        local bg = inset:CreateTexture(nil, "BACKGROUND")
        bg:SetAllPoints()
        bg:SetColorTexture(0, 0, 0, 0.3)
    end
    -- The tabs' holder carries the sizes the game's tab code reads when a tab is shown.
    local tabHolder = CreateFrame("Frame", nil, column)
    tabHolder:SetPoint("BOTTOMLEFT", inset, "TOPLEFT")
    tabHolder:SetSize(WIDTH, TAB_H)
    tabHolder.tabPadding, tabHolder.minTabWidth, tabHolder.maxTabWidth = 0, TAB_W, TAB_W
    for i, which in ipairs(TABS) do
        local tab, tmpl = TryCreate("Button", "ThreatBoxOptionsTab" .. i, tabHolder, { "PanelTopTabButtonTemplate", "UIPanelButtonTemplate" })
        tab.isBare = tmpl ~= "PanelTopTabButtonTemplate"
        if tab.isBare then tab:SetHeight(22) end
        tab:SetText(TAB_TEXT[which])
        if PanelTemplates_TabResize and not tab.isBare then
            pcall(PanelTemplates_TabResize, tab, 0, TAB_W)
        else
            tab:SetWidth(TAB_W)
        end
        tab:SetPoint("BOTTOMLEFT", inset, "TOPLEFT", 6 + (i - 1) * (TAB_W + 3), -2)
        tab:SetScript("OnClick", function() O.EditTab(which) end)
        tabs[which] = tab
    end
    -- The blocks start at the same place inside the inset; only the picked one shows.
    local blockH = 0
    for _, which in ipairs(TABS) do
        local block = CreateFrame("Frame", nil, inset)
        block:SetPoint("TOPLEFT", inset, "TOPLEFT", 8, -10)
        block:SetWidth(WIDTH)
        col = block
        if which == "threat" then
            ThreatControls()
        elseif which == "pet" then
            PieceControls("pet", "A second box, with a blue number, showing your pet's threat on that enemy. It takes the threat box's colors and size.")
        else
            PieceControls("who", "Names who the enemy is on when it is not you: a player in their class color, your pet in blue.", function()
                ui.whoWidth = Slider(col, "Width", x, y, 40, 140, 2,
                    function() return db.whoWidth end,
                    function(v) db.whoWidth = v ns.Apply() end)
                y = y - 46
            end)
        end
        block:SetHeight(-y)
        blockH = math.max(blockH, -y)
        blocks[which] = block
    end
    inset:SetHeight(blockH + 16)
    col = column
    ShowEditing()
    refreshers[#refreshers + 1] = ShowEditing

    -- ---- what every box shares -------------------------------------------------------------
    local top = insetTop - (blockH + 16) - 14
    x, y = 8, top
    Head("When to show")
    Toggle("groupOnly")
    Toggle("combatOnly")
    Toggle("targetOnly")
    Toggle("skipTrivial")
    local leftBottom = y

    x, y = RIGHT + 8, top
    -- Window style: Automatic (EllesmereUI's look when it is running), Blizzard or Dark.
    local Styles = ns.Styles
    if Styles then
        Head("Look")
        ui.style = Cycle(col, "Window style", x, y, { "auto", "blizzard", "dark" },
            { auto = Styles.Name("auto"), blizzard = Styles.Name("blizzard"), dark = Styles.Name("dark") },
            function() return db.style end,
            function(v) Styles.Set(v) end)
        ui.style:SetScript("OnEnter", function(self)
            if not GameTooltip then return end
            GameTooltip:SetOwner(self, "ANCHOR_RIGHT")
            GameTooltip:SetText("Window style", 1, 1, 1)
            for _, line in ipairs(Styles.HELP or {}) do GameTooltip:AddLine(line, 0.7, 0.7, 0.7, true) end
            GameTooltip:Show()
        end)
        ui.style:SetScript("OnLeave", function() if GameTooltip then GameTooltip:Hide() end end)
        y = y - 26
        local styleNote = Note(col, "", x, y, COL_W - 10)
        refreshers[#refreshers + 1] = function() styleNote:SetText(Styles.Note()) end
        y = y - 40
    end
    ui.sample = Check(col, "Show a sample on every nameplate", x, y,
        function() return ns.preview end,
        function(on) ns.preview = on ns.UpdateAll() end)
    y = y - 34
    local reset = TryCreate("Button", nil, col, { "UIPanelButtonTemplate" })
    reset:SetSize(150, 22)
    reset:SetPoint("TOPLEFT", x, y)
    reset:SetText("Reset to defaults")
    reset:SetScript("OnClick", function()
        ns.Reset()
        Refresh()
    end)
    ui.reset = reset
    y = y - 30

    column:SetHeight(math.max(-leftBottom, -y) + 16)
    return c
end

local function PageOpen()
    return settingsPage ~= nil and SettingsPanel ~= nil and SettingsPanel:IsShown() and settingsPage:IsVisible()
end

function O.Open()
    if not settingsCategory or not (Settings and Settings.OpenToCategory) then
        ns.print("The options page is not available. Use /threatbox below, above, right or left.")
        return
    end
    if InCombatLockdown and InCombatLockdown() then
        ns.print("The game's options can't be opened in combat. /threatbox below, above, right and left still work.")
        return
    end
    local id = settingsCategory.GetID and settingsCategory:GetID() or settingsCategory.ID or settingsCategory
    pcall(Settings.OpenToCategory, id)
end
O.PageOpen = PageOpen

function O.RegisterPage()
    if not (Settings and Settings.RegisterCanvasLayoutCategory and Settings.RegisterAddOnCategory) then return end
    local page = CreateFrame("Frame")
    -- Hidden until the game's panel shows it, so OnShow runs on the first visit.
    page:Hide()
    local title = page:CreateFontString(nil, "OVERLAY", "GameFontNormalLarge")
    title:SetPoint("TOPLEFT", 16, -16)
    title:SetText(TITLE)
    page:SetScript("OnShow", function(self)
        if not content and ns.db then content = BuildContent(self) end
        Refresh()
    end)
    local ok, category = pcall(Settings.RegisterCanvasLayoutCategory, page, TITLE)
    if ok and category then
        pcall(Settings.RegisterAddOnCategory, category)
        settingsPage, settingsCategory = page, category
    end
end
