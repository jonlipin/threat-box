-- Threat Box: your threat on each enemy, as a percentage, in a box drawn with the same art as the
-- level box on the game's nameplates.
--
-- The number follows the game's own numeric threat display (/console threatShowNumeric 1,
-- UnitFrame_UpdateThreatIndicator), with one choice: by default it is the game's scaled
-- percentage, where 100% is the point you take the enemy whether you stand in melee range (110%
-- of the tank's threat) or at range (130%); "raw" is the unscaled number the game's own display
-- uses. While the enemy is on you it is how far ahead of the next player you are, when that can
-- be read. The box border takes the game's threat color, or the reverse for tanks.
--
-- Rules this file keeps on WoW Forever:
--   * Nothing is ever written onto a Blizzard nameplate frame. Boxes are kept in our own tables
--     and only anchored to the game's frames.
--   * Threat values can arrive as secret values. They are asked about with issecretvalue before
--     anything else and, when secret, handed straight to the game without a comparison or
--     arithmetic: SetFormattedText writes the number, and the border color comes from three
--     status bars (see MakeBox) that the game fills from the threat state. The fill meter and
--     the warning pulse are status bars too, and "is it on me" answers go to SetAlphaFromBoolean.
local ADDON, ns = ...

local TITLE = "Threat Box"
ns.TITLE = TITLE
ns.VERSION = "0.1.1"

local DEFAULTS = {
    position = "below",   -- below | above | right (of the level box) | left (of the health bar)
    offsetX = 0,
    offsetY = 0,
    scale = 1,
    colorBorder = true,
    colorText = false,    -- the number takes the threat color
    colorBg = false,      -- the box's background takes the threat color
    number = "pull",     -- pull: 100% = you take the enemy (melee and ranged alike) | raw
    colors = "normal",    -- normal | tank (reversed while your role is tank) | reversed
    style = "auto",       -- window style: auto | blizzard | dark (see Styles.lua)
    darkAlpha = 0.92,
    percentSign = true,
    lead = true,          -- while the enemy is on you: your lead over the next player, above 100%
    fill = true,          -- the box fills left to right as threat rises
    warn = true,          -- the box pulses from warnAt percent (for tanks: on an enemy they have lost)
    warnAt = 80,
    sound = false,        -- a sound when you take an enemy (for tanks: when you lose one)
    who = false,          -- a plaque naming who the enemy is on, when it is not you
    pet = false,          -- a second box with your pet's threat
    -- The pet's box and the name plaque sit in a row with the threat box, or, detached, each
    -- pinned on its own: one of the four positions plus its own nudge.
    petDetached = false,
    petPosition = "above",
    petX = 0,
    petY = 0,
    petScale = 1,         -- each box has its own size
    whoDetached = false,
    whoPosition = "left",
    whoX = 0,
    whoY = 0,
    whoWidth = 60,        -- the name plaque's width
    whoScale = 1,
    targetFrame = false,  -- a threat box on the game's target frame
    focusFrame = false,   -- and on its focus frame
    frameScale = 1.2,     -- their size, and a nudge from where the game puts its own threat number
    frameX = 80,          -- over the portrait
    frameY = 0,
    -- The boxes on those frames have their own copy of the threat box's settings.
    frameColorBorder = true,
    frameColorText = false,
    frameColorBg = false,
    frameNumber = "pull",
    frameColors = "normal",
    framePercentSign = true,
    frameFill = true,
    frameLead = true,
    frameWarn = true,
    frameWarnAt = 80,
    groupOnly = false,    -- show rules
    combatOnly = false,
    targetOnly = false,
    skipTrivial = false,
}
ns.DEFAULTS = DEFAULTS

ns.POSITION_ORDER = { "below", "above", "right", "left" }
ns.POSITION_LABELS = {
    below = "Below the level box",
    above = "Above the level box",
    right = "Right of the level box",
    left = "Left of the health bar",
}

-- Slash words for the on/off settings, and what each is called.
ns.TOGGLES = { fill = "fill", lead = "lead", pulse = "warn", sound = "sound", who = "who", pet = "pet",
    border = "colorBorder", text = "colorText", background = "colorBg",
    targetframe = "targetFrame", focusframe = "focusFrame",
    group = "groupOnly", combat = "combatOnly", targetonly = "targetOnly", trivial = "skipTrivial" }
ns.TOGGLE_LABELS = {
    fill = "Fill the box as threat rises",
    lead = "Show your lead above 100%",
    warn = "Pulse near the pull point",
    sound = "Sound when an enemy changes hands",
    who = "Show the target box",
    pet = "Show the pet box",
    targetFrame = "Show on the target frame",
    focusFrame = "Show on the focus frame",
    colorBorder = "Color the border by threat",
    colorText = "Color the number by threat",
    colorBg = "Color the background by threat",
    groupOnly = "Only in a group",
    combatOnly = "Only in combat",
    targetOnly = "Only on your target and focus",
    skipTrivial = "Skip trivial enemies",
}

-- The two extra pieces and the settings that place each when detached.
ns.PIECES = {
    pet = { name = "Pet box", detached = "petDetached", position = "petPosition", x = "petX", y = "petY", scale = "petScale" },
    who = { name = "Target box", detached = "whoDetached", position = "whoPosition", x = "whoX", y = "whoY", scale = "whoScale" },
}

ns.NUMBER_ORDER = { "pull", "raw" }
ns.NUMBER_LABELS = { pull = "Until you pull", raw = "Raw threat" }
ns.COLOR_ORDER = { "normal", "tank", "reversed" }
ns.COLOR_LABELS = { normal = "Normal", tank = "Reversed as a tank", reversed = "Always reversed" }

local BG_ATLAS = "ui-hud-nameplates-levelindicator"
local BORDER_ATLAS = "ui-hud-nameplates-levelindicator-rectangle-selected"
local GAP = 6            -- room for the two border outlines between our box and the level box
local SIGN_ROOM = 8      -- extra width so "100%" fits where the level box holds two digits
local TICK = 0.25
local CHAIN_GAP = 5      -- between the threat box, the pet's box and the name plaque
local WHO_WIDTH = 60
local PULSE_COLOR = { 1, 0.25, 0.1 }
local PET_TEXT = { 0.6, 0.9, 1 }
local FLAT = "Interface\\Buttons\\WHITE8X8"
local TINT_SHADE = 0.6   -- the background takes a darker shade of the threat color, so the number reads
ns.WHO_WIDTH = WHO_WIDTH

-- The game's threat colors, by threat state (the values GetThreatStatusColor returns).
local STATUS_COLORS = {
    [0] = { 0.69, 0.69, 0.69 },
    [1] = { 1, 1, 0.47 },
    [2] = { 1, 0.6, 0 },
    [3] = { 1, 0, 0 },
}
-- For tanks: holding the enemy is good news, losing it is not.
local TANK_COLORS = {
    [0] = { 1, 0, 0 },
    [1] = { 1, 0.6, 0 },
    [2] = { 1, 1, 0.47 },
    [3] = { 0.2, 0.9, 0.2 },
}
local PREVIEW_VALUE, PREVIEW_STATUS = 87, 2
local PREVIEW_PET, PREVIEW_PET_STATUS, PREVIEW_WHO = 34, 1, "Tharandir"
ns.PREVIEW_VALUE, ns.PREVIEW_STATUS = PREVIEW_VALUE, PREVIEW_STATUS
ns.OFFSET_LIMIT = 150        -- nudges on nameplates
ns.FRAME_OFFSET_LIMIT = 300  -- and on the target and focus frames, which are far bigger
ns.SCALE_MIN, ns.SCALE_MAX = 0.5, 2

local db
local boxes = {}     -- nameplate frame -> our box
local allBoxes = setmetatable({}, { __mode = "k" }) -- every box made, the options preview's too
ns.allBoxes = allBoxes
local allWho = setmetatable({}, { __mode = "k" })   -- every name plaque made
ns.allWho = allWho
local inCombat = false
local active = {}    -- unit token -> our box
local report = { secretReads = 0, anchorError = nil, plates = 0 }
ns.report = report
ns.preview = false

local function Print(msg)
    print("|cffff9933" .. TITLE .. "|r: " .. tostring(msg))
end
ns.print = Print

local function IsSecret(v)
    if issecretvalue == nil then return false end
    return issecretvalue(v) and true or false
end

-- Is the player a tank, as the game's own threat colors ask it? Asked at most once a second.
local tankAt, tankNow = -10, false
local function IsTank()
    local now = GetTime and GetTime() or 0
    if now - tankAt < 1 and now >= tankAt then return tankNow end
    tankAt, tankNow = now, false
    if PlayerUtil and PlayerUtil.IsPlayerEffectivelyTank then
        local ok, isTank = pcall(PlayerUtil.IsPlayerEffectivelyTank)
        if ok and not IsSecret(isTank) and isTank then tankNow = true end
    end
    return tankNow
end
ns.IsTank = IsTank

-- A box on the target or focus frame reads its own copy of these settings.
local FRAME_KEYS = { colorBorder = "frameColorBorder", colorText = "frameColorText", colorBg = "frameColorBg",
    number = "frameNumber", colors = "frameColors", percentSign = "framePercentSign", fill = "frameFill", lead = "frameLead",
    warn = "frameWarn", warnAt = "frameWarnAt" }
ns.FRAME_KEYS = FRAME_KEYS
local function Opt(box, key)
    if box and box.onFrame then return db[FRAME_KEYS[key]] end
    return db[key]
end

-- box nil asks for the nameplate boxes.
local function Reversed(box)
    local colors = Opt(box, "colors")
    return colors == "reversed" or (colors == "tank" and IsTank())
end
ns.Reversed = Reversed

------------------------------------------------------------------------
-- The box
------------------------------------------------------------------------
-- A box's frames, bottom to top (frame levels above the box's own):
--   +0 the box: the level box art and the grey outline
--   +1 the warning pulse
--   +2..4 the outline's three color steps
--   +5 the flat panel (Dark and EllesmereUI looks only)
--   +6..8 the background's three color steps
--   +9 the fill meter
--   +10 the face: the number
--   +11..13 the number again, once in each higher threat color
local LEVELS = { pulse = 1, steps = 1, panel = 5, tint = 5, fill = 9, face = 10, ink = 10 }

local function NewNumber(parent, box)
    local ok, text = pcall(parent.CreateFontString, parent, nil, "OVERLAY", "SystemFont_NamePlateLevel")
    if not ok or not text then
        text = parent:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
    end
    text:SetPoint("CENTER", box, "CENTER", 0, 0)
    if text.SetWordWrap then text:SetWordWrap(false) end
    return text
end

-- kept = false makes a box that is not tracked as a nameplate's (the options preview's, and
-- the pet's box, which hangs off its nameplate's box).
local function MakeBox(parent, kept)
    local box = CreateFrame("Frame", nil, parent)
    box:SetSize(28, 18)
    box:Hide()

    box.bg = box:CreateTexture(nil, "BACKGROUND")
    box.bg:SetAllPoints(box)
    box.bg:SetAtlas(BG_ATLAS)

    -- The border. Underneath, the outline in the "on the list, no danger" grey. Over it, one
    -- status bar per higher threat state (1 yellow, 2 orange, 3 red), each drawing the same outline
    -- in its color with a range of (state - 1, state). Given the threat state as its value, a bar
    -- is full when the state has reached it and empty below, so the topmost full bar is the color
    -- shown. The game does that comparison, which is what lets it work on a secret state.
    box.border = box:CreateTexture(nil, "OVERLAY")
    box.border:SetPoint("TOPLEFT", box, "TOPLEFT", -3, 3)
    box.border:SetPoint("BOTTOMRIGHT", box, "BOTTOMRIGHT", 3, -4)
    box.border:SetAtlas(BORDER_ATLAS)
    box.steps = {}
    for state = 1, 3 do
        local bar = CreateFrame("StatusBar", nil, box)
        bar:SetPoint("TOPLEFT", box, "TOPLEFT", -3, 3)
        bar:SetPoint("BOTTOMRIGHT", box, "BOTTOMRIGHT", 3, -4)
        local fill = bar:CreateTexture(nil, "OVERLAY")
        fill:SetAtlas(BORDER_ATLAS)
        bar:SetStatusBarTexture(fill)
        bar:SetMinMaxValues(state - 1, state)
        bar:SetValue(state - 1)
        box.steps[state] = bar
    end

    -- The warning pulse: a wider outline that glows and fades behind the border. Its status bar
    -- (the gate) has a range just under the warning percentage, so the game shows it from that
    -- percentage up; its holder's alpha is set from "is the enemy on you", so it rests then.
    local holder = CreateFrame("Frame", nil, box)
    holder:SetAllPoints(box)
    local gate = CreateFrame("StatusBar", nil, holder)
    gate:SetPoint("TOPLEFT", box, "TOPLEFT", -6, 6)
    gate:SetPoint("BOTTOMRIGHT", box, "BOTTOMRIGHT", 6, -7)
    local glow = gate:CreateTexture(nil, "ARTWORK")
    glow:SetAtlas(BORDER_ATLAS)
    if glow.SetBlendMode then glow:SetBlendMode("ADD") end
    gate:SetStatusBarTexture(glow)
    gate:SetStatusBarColor(PULSE_COLOR[1], PULSE_COLOR[2], PULSE_COLOR[3])
    gate:SetMinMaxValues(0, 1)
    gate:SetValue(0)
    if gate.CreateAnimationGroup then
        local group = gate:CreateAnimationGroup()
        if group and group.CreateAnimation then
            group:SetLooping("REPEAT")
            local out = group:CreateAnimation("Alpha")
            out:SetFromAlpha(1) out:SetToAlpha(0.2) out:SetDuration(0.45) out:SetOrder(1)
            local back = group:CreateAnimation("Alpha")
            back:SetFromAlpha(0.2) back:SetToAlpha(1) back:SetDuration(0.45) back:SetOrder(2)
            group:Play()
            box.pulseAnim = group
        end
    end
    holder:Hide()
    box.pulse, box.gate = holder, gate

    -- The fill meter: a soft fill behind the number, from empty at 0% to full at the pull point.
    local meter = CreateFrame("StatusBar", nil, box)
    meter:SetPoint("TOPLEFT", box, "TOPLEFT", 2, -2)
    meter:SetPoint("BOTTOMRIGHT", box, "BOTTOMRIGHT", -2, 2)
    meter:SetStatusBarTexture(FLAT)
    meter:SetStatusBarColor(1, 1, 1, 0.22)
    meter:SetMinMaxValues(0, 100)
    meter:SetValue(0)
    meter:Hide()
    box.fill = meter

    -- The background in the threat color: as with the border, one status bar per higher threat
    -- state, each a solid darker shade of its color, the lowest state's shade underneath. The
    -- topmost full bar is the color shown.
    box.tints = {}
    for state = 1, 3 do
        local bar = CreateFrame("StatusBar", nil, box)
        bar:SetPoint("TOPLEFT", box, "TOPLEFT", 2, -2)
        bar:SetPoint("BOTTOMRIGHT", box, "BOTTOMRIGHT", -2, 2)
        bar:SetStatusBarTexture(FLAT)
        bar:SetMinMaxValues(state - 1, state)
        bar:SetValue(state - 1)
        bar:Hide()
        box.tints[state] = bar
    end
    box.tintBase = box.tints[1]:CreateTexture(nil, "BACKGROUND")
    box.tintBase:SetAllPoints(box.tints[1])

    local face = CreateFrame("Frame", nil, box)
    face:SetAllPoints(box)
    box.face = face
    box.text = NewNumber(face, box)

    -- The number in the threat color. A font string cannot be a status bar's fill, so each higher
    -- threat state gets a copy of the number in its color inside a frame that clips what it holds
    -- and ends at the right edge of an unseen status bar's fill. The bar is full once the state
    -- has reached it, which uncovers that copy over the ones below; empty, the frame is a sliver
    -- to the left of the box and the copy is cut away. The game does the comparison again.
    box.inks = {}
    for state = 1, 3 do
        local bar = CreateFrame("StatusBar", nil, box)
        bar:SetPoint("TOPLEFT", box, "TOPLEFT", -4, 4)
        bar:SetPoint("BOTTOMRIGHT", box, "BOTTOMRIGHT", 4, -4)
        local fill = bar:CreateTexture(nil, "ARTWORK")
        fill:SetColorTexture(1, 1, 1, 0)
        bar:SetStatusBarTexture(fill)
        bar:SetMinMaxValues(state - 1, state)
        bar:SetValue(state - 1)
        local clip = CreateFrame("Frame", nil, bar)
        clip:SetPoint("TOPLEFT", bar, "TOPLEFT", -1, 0)
        clip:SetPoint("BOTTOMRIGHT", fill, "BOTTOMRIGHT", 0, 0)
        if clip.SetClipsChildren then clip:SetClipsChildren(true) end
        bar.clip = clip
        bar.text = NewNumber(clip, box)
        bar:Hide()
        box.inks[state] = bar
    end

    box.plate = parent
    if kept ~= false then boxes[parent] = box end
    allBoxes[box] = true
    if ns.SkinBox then ns.SkinBox(box) end -- Dark or EllesmereUI look, when one is in use
    return box
end

-- The frame levels of a box's layers, from the level of the box itself.
local function SetLevels(box, frameLevel)
    box:SetFrameLevel(frameLevel)
    box.pulse:SetFrameLevel(frameLevel + LEVELS.pulse)
    box.gate:SetFrameLevel(frameLevel + LEVELS.pulse)
    for state, step in ipairs(box.steps) do step:SetFrameLevel(frameLevel + LEVELS.steps + state) end
    if box.panel then box.panel:SetFrameLevel(frameLevel + LEVELS.panel) end
    for state, tint in ipairs(box.tints) do tint:SetFrameLevel(frameLevel + LEVELS.tint + state) end
    box.fill:SetFrameLevel(frameLevel + LEVELS.fill)
    box.face:SetFrameLevel(frameLevel + LEVELS.face)
    for state, ink in ipairs(box.inks) do
        ink:SetFrameLevel(frameLevel + LEVELS.ink + state)
        ink.clip:SetFrameLevel(frameLevel + LEVELS.ink + state)
    end
    box.frameLevel = frameLevel
end

-- The number's font height, on the number and on its colored copies.
local function NumberHeight(box, height)
    box.text:SetTextHeight(height)
    for _, ink in ipairs(box.inks) do ink.text:SetTextHeight(height) end
end
ns.SetLevels = SetLevels
ns.LEVELS = LEVELS

-- Blizzard's level box art is a small square that the game stretches. For something wider it is
-- drawn in three pieces instead: the left and right thirds keep their shape as end caps and only
-- the middle third stretches, so the corners look as they do on the level box. Returns the
-- pieces (one stretched piece when the art's place in its file cannot be read).
local function Slice3(frame, atlas, layer, outLeft, outTop, outRight, outBottom)
    local set = { parts = {}, outTop = outTop, outBottom = outBottom }
    local info = C_Texture and C_Texture.GetAtlasInfo and C_Texture.GetAtlasInfo(atlas)
    if not (type(info) == "table" and info.file and info.leftTexCoord and info.rightTexCoord) then
        local whole = frame:CreateTexture(nil, layer)
        whole:SetPoint("TOPLEFT", frame, "TOPLEFT", -outLeft, outTop)
        whole:SetPoint("BOTTOMRIGHT", frame, "BOTTOMRIGHT", outRight, -outBottom)
        whole:SetAtlas(atlas)
        set.parts[1] = whole
        return set
    end
    local l, r, t, b = info.leftTexCoord, info.rightTexCoord, info.topTexCoord, info.bottomTexCoord
    local third = (r - l) / 3
    local left = frame:CreateTexture(nil, layer)
    left:SetTexture(info.file)
    left:SetTexCoord(l, l + third, t, b)
    left:SetPoint("TOPLEFT", frame, "TOPLEFT", -outLeft, outTop)
    left:SetPoint("BOTTOMLEFT", frame, "BOTTOMLEFT", -outLeft, -outBottom)
    local right = frame:CreateTexture(nil, layer)
    right:SetTexture(info.file)
    right:SetTexCoord(r - third, r, t, b)
    right:SetPoint("TOPRIGHT", frame, "TOPRIGHT", outRight, outTop)
    right:SetPoint("BOTTOMRIGHT", frame, "BOTTOMRIGHT", outRight, -outBottom)
    local mid = frame:CreateTexture(nil, layer)
    mid:SetTexture(info.file)
    mid:SetTexCoord(l + third, r - third, t, b)
    mid:SetPoint("TOPLEFT", left, "TOPRIGHT", 0, 0)
    mid:SetPoint("BOTTOMRIGHT", right, "BOTTOMLEFT", 0, 0)
    set.parts = { left, mid, right }
    set.left, set.right = left, right
    return set
end
ns.Slice3 = Slice3

-- The end caps are a third of the art, so a third as wide as the art is tall on screen.
local function SizeSlices(set, height)
    if not set.left then return end
    local cap = (height + set.outTop + set.outBottom) / 3
    set.left:SetWidth(cap)
    set.right:SetWidth(cap)
end

-- The name plaque: who the enemy is on. The level box's art and outline, drawn wide.
local function MakeWho(box)
    local who = CreateFrame("Frame", nil, box)
    who:SetSize(WHO_WIDTH, 18)
    who:Hide()
    who.bg = Slice3(who, BG_ATLAS, "BACKGROUND", 0, 0, 0, 0)
    who.ring = Slice3(who, BORDER_ATLAS, "ARTWORK", 3, 3, 3, 4)
    for _, part in ipairs(who.ring.parts) do
        part:SetVertexColor(STATUS_COLORS[0][1], STATUS_COLORS[0][2], STATUS_COLORS[0][3])
    end
    local ok, text = pcall(who.CreateFontString, who, nil, "OVERLAY", "SystemFont_NamePlateLevel")
    if not ok or not text then text = who:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall") end
    text:SetPoint("CENTER", who, "CENTER", 0, 0)
    text:SetWidth(WHO_WIDTH - 8)
    if text.SetWordWrap then text:SetWordWrap(false) end
    who.text = text
    box.who = who
    allWho[who] = true
    if ns.SkinWho then ns.SkinWho(who) end
    return who
end

local function MakePet(box)
    local pet = MakeBox(box, false)
    pet.isPet = true
    pet.text:SetTextColor(PET_TEXT[1], PET_TEXT[2], PET_TEXT[3])
    box.pet = pet
    return pet
end
ns.MakeBox = MakeBox

-- EllesmereUI's Nameplates module draws its own plate over the game's and parks the game's
-- health bar off screen. Its plate is a child of the game's nameplate frame that keeps that frame
-- in .nameplate, its health bar in .health and, in its Blizzard variant, a level box in
-- ._fvLevelBox. Read only; nothing of it is changed and none of its functions are called.
local function EuiPlate(plate)
    if ns.euiNameplates == nil then
        ns.euiNameplates = C_AddOns and C_AddOns.IsAddOnLoaded
            and C_AddOns.IsAddOnLoaded("EllesmereUINameplates") and true or false
    end
    if not ns.euiNameplates then return nil end
    local ok, found = pcall(function()
        for _, child in ipairs({ plate:GetChildren() }) do
            if rawget(child, "nameplate") == plate and type(rawget(child, "health")) == "table" and child:IsShown() then
                return child
            end
        end
    end)
    if ok then return found end
end
ns.EuiPlate = EuiPlate

-- The pieces of the nameplate we anchor to: what must be showing, the level box (nil when the
-- plate has none) and the health bar. Returns nil when the plate has none we may use.
local function PlateParts(plate)
    local eui = EuiPlate(plate)
    if eui then
        report.euiPlates = true
        local level = rawget(eui, "_fvLevelBox")
        if type(level) ~= "table" or not level:IsShown() then level = nil end
        return eui, level, eui.health
    end
    local uf = plate.UnitFrame
    if not uf then return nil end
    if uf.IsForbidden and uf:IsForbidden() then return nil end
    local level = uf.PlayerLevelDiffFrame
    local container = uf.HealthBarsContainer
    local bar = container and container.healthBar
    if not level or not bar then return nil end
    return uf, level, bar
end

-- Pins a frame at one of the four positions: beside `level` (the level box), or left of `bar`
-- (the health bar). A plate with no level box gets it where one would be, off the right end of
-- the health bar. A refused anchor falls back to the nameplate itself.
local function Pin(frame, plate, level, bar, position, ox, oy)
    frame:ClearAllPoints()
    local ok, err
    if position == "left" then
        -- Mirrors how the game hangs the level box off the right end of the health bar.
        ok, err = pcall(frame.SetPoint, frame, "TOPRIGHT", bar, "TOPLEFT", -5 + ox, 3 + oy)
    elseif level then
        if position == "above" then
            ok, err = pcall(frame.SetPoint, frame, "BOTTOMLEFT", level, "TOPLEFT", ox, GAP + oy)
        elseif position == "right" then
            ok, err = pcall(frame.SetPoint, frame, "LEFT", level, "RIGHT", GAP + ox, oy)
        else
            ok, err = pcall(frame.SetPoint, frame, "TOPLEFT", level, "BOTTOMLEFT", ox, -GAP + oy)
        end
    elseif position == "above" then
        ok, err = pcall(frame.SetPoint, frame, "BOTTOMLEFT", bar, "TOPRIGHT", 5 + ox, GAP + oy)
    elseif position == "right" then
        ok, err = pcall(frame.SetPoint, frame, "LEFT", bar, "RIGHT", 5 + ox, 0.5 + oy)
    else
        ok, err = pcall(frame.SetPoint, frame, "TOPLEFT", bar, "BOTTOMRIGHT", 5 + ox, -GAP + oy)
    end
    if not ok then
        report.anchorError = tostring(err)
        frame:ClearAllPoints()
        frame:SetPoint("LEFT", plate, "RIGHT", ox, oy)
    end
end

-- Sizes the box like `level` (the level box) and pins it where the settings say: beside the
-- level box, or left of `bar` (the health bar). A plate with no level box gets the box where one
-- would be, off the right end of the health bar. `rel` is the scale the level box is drawn at,
-- relative to the box's parent. Used for real nameplates and for the options preview alike.
local function Place(box, level, bar, rel)
    local plate = box.plate
    local lw, lh
    if level then
        lw, lh = level:GetWidth(), level:GetHeight()
    else
        local barH = bar:GetHeight()
        if barH and not IsSecret(barH) and barH > 0 then lh = barH + 5 end
    end
    if not lw or IsSecret(lw) or lw <= 0 then lw = 28 end
    if not lh or IsSecret(lh) or lh <= 0 then lh = 18 end

    local scale = (rel or 1) * db.scale

    local width = lw + (db.percentSign and SIGN_ROOM or 0)
    local fontHeight = 10
    if type(NamePlateSetupOptions) == "table" and type(NamePlateSetupOptions.levelFontHeight) == "number" then
        fontHeight = NamePlateSetupOptions.levelFontHeight
    end

    local key = table.concat({ db.position, width, lh, scale, db.offsetX, db.offsetY, fontHeight }, "|")
    if box.layoutKey == key and box.levelFrame == level and box.barFrame == bar then return true end

    box:SetScale(scale)
    box:SetSize(width, lh)
    local frameLevel
    if level then
        box:SetFrameStrata(level:GetFrameStrata())
        frameLevel = level:GetFrameLevel()
    else
        box:SetFrameStrata(bar:GetFrameStrata())
        frameLevel = bar:GetFrameLevel() + 5
    end
    SetLevels(box, frameLevel)
    if fontHeight > 0 then NumberHeight(box, fontHeight) end
    box.fontHeight = fontHeight
    box.chainKey = nil -- the pet's box and the name plaque are laid out again

    Pin(box, plate, level, bar, db.position, db.offsetX, db.offsetY)

    box.layoutKey = key
    box.levelFrame, box.barFrame = level, bar
    return true
end
ns.Place = Place

-- Returns whether the box could be placed, and the frame that must be showing for it to show.
local function Layout(box)
    local plate = box.plate
    local host, level, bar = PlateParts(plate)
    if not host then return false end
    local rel = 1
    local ref = level or bar
    local refScale, plateScale = ref:GetEffectiveScale(), plate:GetEffectiveScale()
    if refScale and plateScale and plateScale > 0 then rel = refScale / plateScale end
    return Place(box, level, bar, rel), host
end

------------------------------------------------------------------------
-- Threat
------------------------------------------------------------------------
-- Returns "hide", or "plain", display, status, isTanking, or "secret", percentage, status,
-- isTanking. The percentage is the game's scaled one (100% = you take the enemy, from melee or
-- from range) or the raw one, as chosen. In the secret case nothing may be compared, so the lead
-- while the enemy is on you is not used and a box cannot be hidden for reading 0%.
local function ReadThreat(unit, who, box)
    who = who or "player"
    if not UnitDetailedThreatSituation then return "hide" end
    local canAttack = UnitCanAttack("player", unit)
    if not IsSecret(canAttack) and not canAttack then return "hide" end
    local dead = UnitIsDead(unit)
    if not IsSecret(dead) and dead then return "hide" end

    local ok, isTanking, status, scaled, raw = pcall(UnitDetailedThreatSituation, who, unit)
    if not ok then return "hide" end
    local percent = raw
    if Opt(box, "number") == "pull" then percent = scaled end

    if IsSecret(isTanking) or IsSecret(status) or IsSecret(percent) then
        report.secretReads = report.secretReads + 1
        return "secret", percent, status, isTanking
    end
    if status == nil then return "hide" end -- not on this enemy's threat list

    local display = percent
    if isTanking and Opt(box, "lead") then
        local okLead, lead = pcall(UnitThreatPercentageOfLead, who, unit)
        if okLead and lead and not IsSecret(lead) and lead ~= 0 then
            display = lead
        end
    elseif not isTanking and who == "player" and not Reversed(box) and IsTank() then
        -- As the game does with its own colors: a tank who has lost the enemy sees orange.
        status = 2
    end
    if not display or display == 0 then return "hide" end
    return "plain", display, status, isTanking and true or false
end
ns.ReadThreat = ReadThreat

-- Shows the border in the color of a threat state, which may be secret.
local function ShowBorder(box, status)
    if not Opt(box, "colorBorder") then
        box.border:Hide()
        for _, bar in ipairs(box.steps) do bar:Hide() end
        return
    end
    local colors = Reversed(box) and TANK_COLORS or STATUS_COLORS
    if box.colors ~= colors then
        box.colors = colors
        box.border:SetVertexColor(colors[0][1], colors[0][2], colors[0][3])
        for state, bar in ipairs(box.steps) do
            bar:SetStatusBarColor(colors[state][1], colors[state][2], colors[state][3])
        end
    end
    box.border:Show()
    for _, bar in ipairs(box.steps) do
        if pcall(bar.SetValue, bar, status) then bar:Show() else bar:Hide() end
    end
end

-- The background in a darker shade of the threat state's color. The state may be secret.
local function ShowTint(box, status)
    if not Opt(box, "colorBg") then
        for _, bar in ipairs(box.tints) do bar:Hide() end
        return
    end
    local colors = Reversed(box) and TANK_COLORS or STATUS_COLORS
    if box.tintColors ~= colors then
        box.tintColors = colors
        local base = colors[0]
        box.tintBase:SetColorTexture(base[1] * TINT_SHADE, base[2] * TINT_SHADE, base[3] * TINT_SHADE, 1)
        for state, bar in ipairs(box.tints) do
            local c = colors[state]
            bar:SetStatusBarColor(c[1] * TINT_SHADE, c[2] * TINT_SHADE, c[3] * TINT_SHADE, 1)
        end
    end
    for _, bar in ipairs(box.tints) do
        if pcall(bar.SetValue, bar, status) then bar:Show() else bar:Hide() end
    end
end

-- The number in the threat state's color: the number itself takes the lowest state's color and
-- each copy above it is written the same text and uncovered by the game when the state reaches
-- it. The pet's number keeps its own blue, which is what tells the two boxes apart.
local function ShowInk(box, status, fmt, value)
    if not Opt(box, "colorText") or box.isPet then
        if box.inkColors then
            box.inkColors = nil
            local plain = box.plainColor
            box.text:SetTextColor(plain and plain[1] or 1, plain and plain[2] or 1, plain and plain[3] or 1)
        end
        for _, bar in ipairs(box.inks) do bar:Hide() end
        return
    end
    local colors = Reversed(box) and TANK_COLORS or STATUS_COLORS
    if box.inkColors ~= colors then
        if not box.inkColors and not box.plainColor and box.text.GetTextColor then
            local r, g, b = box.text:GetTextColor()
            if type(r) == "number" then box.plainColor = { r, g, b } end
        end
        box.inkColors = colors
        box.text:SetTextColor(colors[0][1], colors[0][2], colors[0][3])
        for state, bar in ipairs(box.inks) do
            bar.text:SetTextColor(colors[state][1], colors[state][2], colors[state][3])
        end
    end
    for _, bar in ipairs(box.inks) do
        if pcall(bar.text.SetFormattedText, bar.text, fmt, value) and pcall(bar.SetValue, bar, status) then
            bar:Show()
        else
            bar:Hide()
        end
    end
end

-- The fill meter: empty at 0, full at the pull point (100% scaled, 130% raw from range).
local function ShowFill(box, value)
    if not Opt(box, "fill") then box.fill:Hide() return end
    box.fill:SetMinMaxValues(0, Opt(box, "number") == "raw" and 130 or 100)
    if pcall(box.fill.SetValue, box.fill, value) then box.fill:Show() else box.fill:Hide() end
end

-- The warning pulse. Not a tank: from the warning percentage up, on an enemy that is not on you
-- yet. A tank (reversed colors): on any enemy on your list that is not on you. The game makes
-- both comparisons: the gate's range does the percentage, the holder's alpha does "on you".
-- isTanking nil (the options preview) counts as not on you.
local function ShowPulse(box, value, isTanking)
    if not Opt(box, "warn") or box.isPet then box.pulse:Hide() return end
    local gate = box.gate
    if Reversed(box) then
        gate:SetMinMaxValues(0, 1)
        gate:SetValue(1)
    else
        gate:SetMinMaxValues(Opt(box, "warnAt") - 0.5, Opt(box, "warnAt"))
        if not pcall(gate.SetValue, gate, value) then box.pulse:Hide() return end
    end
    local holder = box.pulse
    if isTanking == nil then
        holder:SetAlpha(1)
    elseif not (holder.SetAlphaFromBoolean and pcall(holder.SetAlphaFromBoolean, holder, isTanking, 0, 1)) then
        if IsSecret(isTanking) then holder:Hide() return end
        holder:SetAlpha(isTanking and 0 or 1)
    end
    holder:Show()
end

-- One path for plain and secret values: the game formats the number, fills the border and the
-- meter, and decides the pulse.
function ns.ShowValue(box, value, status, isTanking)
    local fmt = Opt(box, "percentSign") and "%1.0f%%" or "%1.0f"
    if not pcall(box.text.SetFormattedText, box.text, fmt, value) then
        box.text:SetText("?")
    end
    ShowBorder(box, status)
    ShowTint(box, status)
    ShowInk(box, status, fmt, value)
    ShowFill(box, value)
    ShowPulse(box, value, isTanking)
    box:Show()
end

-- Who the enemy is on, on the plaque. Hidden when that is you (the box's own color says so) or
-- nobody. token nil shows the sample name.
local function ShowWho(box, unit)
    if not db.who then
        if box.who then box.who:Hide() end
        return false
    end
    local who = box.who or MakeWho(box)
    local text = who.text
    if not unit then
        text:SetText(PREVIEW_WHO)
        text:SetTextColor(1, 1, 1)
        who:SetAlpha(1)
        who:Show()
        return true
    end
    local token = unit .. "target"
    local exists = UnitExists(token)
    if not IsSecret(exists) and not exists then who:Hide() return false end
    local isYou = UnitIsUnit(token, "player")
    if IsSecret(isYou) then
        -- The game hides the plaque when it is you.
        if not (who.SetAlphaFromBoolean and pcall(who.SetAlphaFromBoolean, who, isYou, 0, 1)) then
            who:Hide()
            return false
        end
    else
        if isYou then who:Hide() return false end
        who:SetAlpha(1)
    end
    local name = UnitName(token)
    if not pcall(text.SetText, text, name) then who:Hide() return false end
    -- A color when it can be told: your pet in the pet box's blue, a player in their class color.
    local r, g, b = 1, 1, 1
    local isPet = UnitIsUnit(token, "pet")
    if not IsSecret(isPet) and isPet then
        r, g, b = PET_TEXT[1], PET_TEXT[2], PET_TEXT[3]
    else
        local isPlayer = UnitIsPlayer(token)
        if not IsSecret(isPlayer) and isPlayer and RAID_CLASS_COLORS then
            local _, class = UnitClass(token)
            local c = (not IsSecret(class)) and class and RAID_CLASS_COLORS[class]
            if c then r, g, b = c.r, c.g, c.b end
        end
    end
    text:SetTextColor(r, g, b)
    who:Show()
    return true
end

-- Your pet's threat in its own box. unit nil shows the sample.
local function ShowPet(box, unit)
    if not db.pet then
        if box.pet then box.pet:Hide() end
        return false
    end
    if not unit then
        local pet = box.pet or MakePet(box)
        ns.ShowValue(pet, PREVIEW_PET, PREVIEW_PET_STATUS, false)
        return true
    end
    if not UnitExists("pet") then
        if box.pet then box.pet:Hide() end
        return false
    end
    local mode, value, status, isTanking = ReadThreat(unit, "pet")
    if mode == "hide" then
        if box.pet then box.pet:Hide() end
        return false
    end
    local pet = box.pet or MakePet(box)
    ns.ShowValue(pet, value, status, isTanking)
    return true
end

-- The pet's box and the name plaque sit in a row with the threat box, away from the health
-- bar: to the right, or to the left when the box is left of the health bar. A detached piece
-- leaves the row and is pinned to the nameplate on its own, like the threat box.
local function LayoutChain(box, petShown, whoShown)
    local key = table.concat({ db.position, petShown and "p" or "-", whoShown and "w" or "-",
        db.petDetached and (db.petPosition .. db.petX .. "," .. db.petY) or "row",
        db.whoDetached and (db.whoPosition .. db.whoX .. "," .. db.whoY) or "row", db.whoWidth,
        db.scale, db.petScale, db.whoScale }, "|")
    if box.chainKey == key then return end
    box.chainKey = key
    local left = db.position == "left"
    local w, h = box:GetWidth(), box:GetHeight()
    local level = box.frameLevel or box:GetFrameLevel() or 1
    local last = box
    local function Hang(frame, piece)
        local set = ns.PIECES[piece]
        -- The pieces are children of the threat box, so its size is taken back out of theirs:
        -- each box's size setting is then its own, whatever the threat box's is.
        frame:SetScale(db[set.scale] / db.scale)
        if db[set.detached] and box.barFrame then
            -- The pieces are children of the box, so the plate behind it is the box's parent.
            Pin(frame, box.plate, box.levelFrame, box.barFrame, db[set.position], db[set.x], db[set.y])
            return
        end
        frame:ClearAllPoints()
        if left then
            frame:SetPoint("RIGHT", last, "LEFT", -CHAIN_GAP, 0)
        else
            frame:SetPoint("LEFT", last, "RIGHT", CHAIN_GAP, 0)
        end
        last = frame
    end
    if petShown and box.pet then
        local pet = box.pet
        pet:SetSize(w, h)
        SetLevels(pet, level)
        if box.fontHeight and box.fontHeight > 0 then NumberHeight(pet, box.fontHeight) end
        Hang(pet, "pet")
    end
    if whoShown and box.who then
        local who = box.who
        who:SetSize(db.whoWidth, h)
        who.text:SetWidth(db.whoWidth - 8)
        who:SetFrameLevel(level)
        SizeSlices(who.bg, h)
        SizeSlices(who.ring, h)
        if box.fontHeight and box.fontHeight > 0 then who.text:SetTextHeight(box.fontHeight) end
        Hang(who, "who")
    end
end

-- Detaches a piece and pins it at a position, or puts it back in the row (position nil).
function ns.SetPiece(piece, position)
    local set = ns.PIECES[piece]
    if not set then return false end
    if position == nil then
        db[set.detached] = false
    elseif ns.POSITION_LABELS[position] then
        db[set.detached], db[set.position], db[set.x], db[set.y] = true, position, 0, 0
    else
        return false
    end
    ns.Apply()
    return true
end

-- The sample: on real nameplates out of combat, and in the options preview.
function ns.ShowSample(box, status)
    ns.ShowValue(box, PREVIEW_VALUE, status or PREVIEW_STATUS, nil)
    LayoutChain(box, ShowPet(box, nil), ShowWho(box, nil))
end

-- Is this nameplate the one for `token` ("target" or "focus")? Comparing nameplate frames
-- needs no unit comparison, which the game can hide.
local function IsPlateOf(plate, token)
    if not (C_NamePlate and C_NamePlate.GetNamePlateForUnit) then return false end
    local ok, tokenPlate = pcall(C_NamePlate.GetNamePlateForUnit, token)
    return ok and tokenPlate ~= nil and tokenPlate == plate
end

-- The show rules: does this nameplate get a box at all right now?
local function Allowed(box, unit)
    if db.groupOnly and not (IsInGroup and IsInGroup()) then return false end
    if db.combatOnly and not inCombat then return false end
    if db.targetOnly and box and not (IsPlateOf(box.plate, "target") or IsPlateOf(box.plate, "focus")) then return false end
    if db.skipTrivial and UnitIsTrivial then
        local trivial = UnitIsTrivial(unit)
        if not IsSecret(trivial) and trivial then return false end
    end
    return true
end
ns.Allowed = Allowed

-- The aggro sound. Not a tank: when an enemy turns to you, in a group (alone, they always do).
-- A tank: when you lose one. Only when the game lets that be read; never guessed.
local lastSound = -10
local function AggroSound()
    local now = GetTime and GetTime() or 0
    if now - lastSound < 2 and now >= lastSound then return end
    lastSound = now
    report.sounds = (report.sounds or 0) + 1
    if not PlaySound then return end
    local kit = SOUNDKIT and (SOUNDKIT.ALARM_CLOCK_WARNING_3 or SOUNDKIT.RAID_WARNING) or 8959
    pcall(PlaySound, kit, "Master")
end

-- One enemy's "on you" answer changed, as far as it could be read.
local function NoteTanking(box, mode, isTanking)
    if mode ~= "plain" then
        if mode == "secret" then box.wasTanking = nil end -- unknown: no change can be told from it
        return
    end
    local was = box.wasTanking
    box.wasTanking = isTanking
    if not db.sound or was == nil or was == isTanking then return end
    if Reversed() or IsTank() then
        if was and not isTanking and inCombat then AggroSound() end
    elseif isTanking and IsInGroup and IsInGroup() then
        AggroSound()
    end
end

local function HideBox(box)
    box:Hide()
end

local function Update(unit)
    local box = active[unit]
    if not box then return end
    local placed, host = Layout(box)
    if not placed then HideBox(box) return end
    local hostShown = host:IsShown()
    if not IsSecret(hostShown) and not hostShown then HideBox(box) return end
    if box.flat and ns.SizeBoxEdge then ns.SizeBoxEdge(box) end

    local allowed = Allowed(box, unit)
    local mode, value, status, isTanking = "hide"
    if allowed then
        -- The game answers more fully for "target" and "focus" than for a nameplate's own unit
        -- (seen in game: the lead above 100% came through for the target frame only), so the
        -- nameplate of your target or focus is read by that name, and by its own otherwise.
        local alias = (IsPlateOf(box.plate, "target") and "target") or (IsPlateOf(box.plate, "focus") and "focus") or nil
        if alias then mode, value, status, isTanking = ReadThreat(alias) end
        if mode == "hide" then mode, value, status, isTanking = ReadThreat(unit) end
        NoteTanking(box, mode, isTanking)
    end
    local petShown = allowed and ShowPet(box, unit) or false
    if not allowed and box.pet then box.pet:Hide() end

    if mode == "hide" and not petShown then
        if ns.preview then ns.ShowSample(box) else HideBox(box) end
        return
    end
    if mode == "hide" then
        -- Your pet is on the list and you are not: your own box reads 0 beside the pet's.
        mode, value, status, isTanking = "plain", 0, 0, false
    end
    ns.ShowValue(box, value, status, isTanking)
    LayoutChain(box, petShown, ShowWho(box, unit))
end

------------------------------------------------------------------------
-- The target frame and the focus frame
------------------------------------------------------------------------
-- The same box, as a child of the game's target or focus frame, so it shows, hides, moves and
-- scales with that frame. It sits where the game puts its own numeric threat: centered above
-- the name strip. Nothing is written on the game's frame; the box is only anchored to it.
local FRAME_UNITS = {
    target = { frame = "TargetFrame", key = "targetFrame" },
    focus = { frame = "FocusFrame", key = "focusFrame" },
}
local FRAME_ORDER = { "target", "focus" }
local FRAME_GAP = 4       -- room for the box's outline above the name strip
local FRAME_LEVELS = 10   -- above the frame's own layers
local frameBoxes = {}     -- "target" / "focus" -> its box
ns.frameBoxes = frameBoxes

local function NameStrip(host)
    local content = host.TargetFrameContent
    local main = type(content) == "table" and content.TargetFrameContentMain
    local strip = type(main) == "table" and main.ReputationColor
    if type(strip) == "table" and strip.GetObjectType then return strip end
    return nil
end

local function PlaceOnFrame(box, host)
    local width = 28 + (db.framePercentSign and SIGN_ROOM or 0)
    local key = table.concat({ width, db.frameScale, db.frameX, db.frameY }, "|")
    if box.layoutKey == key then return true end
    box:SetScale(db.frameScale)
    box:SetSize(width, 18)
    SetLevels(box, (host:GetFrameLevel() or 1) + FRAME_LEVELS)
    NumberHeight(box, 10)
    box:ClearAllPoints()
    local strip = NameStrip(host)
    local ok = strip and pcall(box.SetPoint, box, "BOTTOM", strip, "TOP", db.frameX, db.frameY + FRAME_GAP)
    if not ok then
        -- No name strip to be found (another addon's frame, or a change in the game's): the
        -- top of the frame itself.
        box:ClearAllPoints()
        local err
        ok, err = pcall(box.SetPoint, box, "BOTTOM", host, "TOP", db.frameX, db.frameY - 20)
        if not ok then report.anchorError = tostring(err) return false end
    end
    box.layoutKey = key
    return true
end

local function UpdateFrameBox(unit)
    local set = FRAME_UNITS[unit]
    local box = frameBoxes[unit]
    if not db[set.key] then
        if box then box:Hide() end
        return
    end
    local host = _G[set.frame]
    if type(host) ~= "table" or not host.GetFrameLevel then return end
    if not box then
        local ok, made = pcall(MakeBox, host, false)
        if not ok then report.frameError = tostring(made) return end
        box = made
        box.onFrame = true
        frameBoxes[unit] = box
    end
    if not PlaceOnFrame(box, host) then box:Hide() return end
    if box.flat and ns.SizeBoxEdge then ns.SizeBoxEdge(box) end
    local mode, value, status, isTanking = "hide"
    if Allowed(nil, unit) then mode, value, status, isTanking = ReadThreat(unit, nil, box) end
    if mode == "hide" then
        if ns.preview then ns.ShowValue(box, PREVIEW_VALUE, PREVIEW_STATUS, nil) else box:Hide() end
        return
    end
    ns.ShowValue(box, value, status, isTanking)
end

local function UpdateAll()
    for unit in pairs(active) do Update(unit) end
    for _, unit in ipairs(FRAME_ORDER) do UpdateFrameBox(unit) end
end
ns.UpdateAll = UpdateAll

-- Called after any setting changes.
function ns.Apply()
    for _, box in pairs(boxes) do box.layoutKey, box.chainKey = nil, nil end
    for _, box in pairs(frameBoxes) do box.layoutKey = nil end
    UpdateAll()
    if ns.Options and ns.Options.RefreshPreview then ns.Options.RefreshPreview() end
end

local function Added(unit)
    if not (C_NamePlate and C_NamePlate.GetNamePlateForUnit) then return end
    local plate = C_NamePlate.GetNamePlateForUnit(unit)
    if not plate then return end -- a forbidden plate: not ours to touch
    local box = boxes[plate] or MakeBox(plate)
    box.layoutKey = nil
    active[unit] = box
    Update(unit)
end

local function Removed(unit)
    local box = active[unit]
    if box then
        box:Hide()
        box.wasTanking = nil
    end
    active[unit] = nil
end

------------------------------------------------------------------------
-- Settings
------------------------------------------------------------------------
function ns.SetPosition(position)
    if not ns.POSITION_LABELS[position] then return false end
    db.position = position
    ns.Apply()
    return true
end

function ns.Reset()
    for k, v in pairs(DEFAULTS) do db[k] = v end
    ns.Apply()
    if ns.Styles then ns.Styles.Changed() end
end

local function LoadDB()
    if type(ThreatBoxDB) ~= "table" then ThreatBoxDB = {} end
    db = ThreatBoxDB
    for k, v in pairs(DEFAULTS) do
        if type(db[k]) ~= type(v) then db[k] = v end
    end
    if not ns.POSITION_LABELS[db.position] then db.position = DEFAULTS.position end
    if not ns.NUMBER_LABELS[db.number] then db.number = DEFAULTS.number end
    for _, set in pairs(ns.PIECES) do
        if not ns.POSITION_LABELS[db[set.position]] then db[set.position] = DEFAULTS[set.position] end
    end
    if not ns.COLOR_LABELS[db.colors] then db.colors = DEFAULTS.colors end
    if not ns.NUMBER_LABELS[db.frameNumber] then db.frameNumber = DEFAULTS.frameNumber end
    if not ns.COLOR_LABELS[db.frameColors] then db.frameColors = DEFAULTS.frameColors end
    if db.frameWarnAt < 50 or db.frameWarnAt > 100 then db.frameWarnAt = DEFAULTS.frameWarnAt end
    if db.scale < 0.5 or db.scale > 2 then db.scale = 1 end
    if db.warnAt < 50 or db.warnAt > 100 then db.warnAt = DEFAULTS.warnAt end
    if db.whoWidth < 40 or db.whoWidth > 140 then db.whoWidth = DEFAULTS.whoWidth end
    for _, set in pairs(ns.PIECES) do
        if db[set.scale] < ns.SCALE_MIN or db[set.scale] > ns.SCALE_MAX then db[set.scale] = 1 end
    end
    if db.frameScale < ns.SCALE_MIN or db.frameScale > ns.SCALE_MAX then db.frameScale = DEFAULTS.frameScale end
    if db.style ~= "blizzard" and db.style ~= "dark" then db.style = "auto" end
    ns.db = db
end

-- The settings, for Styles.lua: EllesmereUI can ask before ADDON_LOADED has filled `db`.
function ns.DB()
    return db or (type(ThreatBoxDB) == "table" and ThreatBoxDB) or nil
end

------------------------------------------------------------------------
-- Events
------------------------------------------------------------------------
local events = CreateFrame("Frame")
events:RegisterEvent("ADDON_LOADED")
events:SetScript("OnEvent", function(self, event, arg1)
    if event == "ADDON_LOADED" then
        if arg1 ~= ADDON then return end
        self:UnregisterEvent("ADDON_LOADED")
        LoadDB()
        self:RegisterEvent("NAME_PLATE_UNIT_ADDED")
        self:RegisterEvent("NAME_PLATE_UNIT_REMOVED")
        self:RegisterEvent("UNIT_THREAT_LIST_UPDATE")
        self:RegisterEvent("UNIT_THREAT_SITUATION_UPDATE")
        self:RegisterEvent("PLAYER_REGEN_ENABLED")
        self:RegisterEvent("PLAYER_REGEN_DISABLED")
        self:RegisterEvent("PLAYER_ENTERING_WORLD")
        self:RegisterEvent("PLAYER_TARGET_CHANGED")
        self:RegisterEvent("GROUP_ROSTER_UPDATE")
        self:RegisterEvent("UNIT_PET")
        pcall(self.RegisterEvent, self, "PLAYER_FOCUS_CHANGED")
        inCombat = UnitAffectingCombat and UnitAffectingCombat("player") and true or false
        if ns.Options and ns.Options.RegisterPage then ns.Options.RegisterPage() end
        if C_Timer and C_Timer.NewTicker then
            -- Threat events do not fire for every change in the number, so the shown plates are
            -- also re-read a few times a second.
            ns.ticker = C_Timer.NewTicker(TICK, UpdateAll)
        end
    elseif not db then
        return
    elseif event == "NAME_PLATE_UNIT_ADDED" then
        Added(arg1)
    elseif event == "NAME_PLATE_UNIT_REMOVED" then
        Removed(arg1)
    elseif event == "PLAYER_REGEN_DISABLED" or event == "PLAYER_REGEN_ENABLED" then
        -- Tracked from the events: InCombatLockdown is still false while the first one is handled.
        inCombat = event == "PLAYER_REGEN_DISABLED"
        UpdateAll()
    elseif event == "UNIT_PET" and arg1 ~= "player" then
        return
    else
        UpdateAll()
    end
end)

------------------------------------------------------------------------
-- Slash commands
------------------------------------------------------------------------
local function Debug()
    local count = 0
    for _ in pairs(active) do count = count + 1 end
    Print("version " .. ns.VERSION .. ", position " .. db.position
        .. ", nudge " .. db.offsetX .. "/" .. db.offsetY .. ", size " .. math.floor(db.scale * 100 + 0.5) .. "%"
        .. ", pet " .. math.floor(db.petScale * 100 + 0.5) .. "%, target " .. math.floor(db.whoScale * 100 + 0.5) .. "%")
    Print("number: " .. db.number .. ", colors: " .. db.colors .. (Reversed() and " (reversed now)" or "")
        .. ", tank: " .. (IsTank() and "yes" or "no"))
    local on = {}
    for _, key in ipairs({ "fill", "warn", "sound", "who", "pet", "targetFrame", "focusFrame", "colorText", "colorBg", "groupOnly", "combatOnly", "targetOnly", "skipTrivial" }) do
        if db[key] then on[#on + 1] = key end
    end
    Print("on: " .. (#on > 0 and table.concat(on, ", ") or "none") .. ", pulse from " .. db.warnAt
        .. "%, sounds played: " .. (report.sounds or 0) .. ", in combat: " .. (inCombat and "yes" or "no"))
    Print("nameplates tracked: " .. count .. ", secret threat reads: " .. report.secretReads
        .. ", sample: " .. (ns.preview and "on" or "off"))
    Print("threat API: " .. (UnitDetailedThreatSituation and "yes" or "NO")
        .. ", lead API: " .. (UnitThreatPercentageOfLead and "yes" or "NO")
        .. ", issecretvalue: " .. (issecretvalue and "yes" or "no"))
    local atlasOK = "unknown"
    if C_Texture and C_Texture.GetAtlasInfo then
        atlasOK = (C_Texture.GetAtlasInfo(BG_ATLAS) and "box yes" or "box NO")
            .. ", " .. (C_Texture.GetAtlasInfo(BORDER_ATLAS) and "border yes" or "border NO")
    end
    Print("window style: " .. tostring(report.skin or "Blizzard")
        .. ", EllesmereUI nameplates: " .. (ns.euiNameplates and (report.euiPlates and "followed" or "loaded, none seen yet") or "no"))
    for k, v in pairs(report) do
        if type(k) == "string" and k:find("^skin error") then Print(k .. ": " .. tostring(v)) end
    end
    -- What the game hands over for your target, asked by "target" and by its nameplate's unit.
    local function Describe(unit)
        local mode, value = ReadThreat(unit)
        if mode ~= "plain" then return unit .. " " .. mode end
        local okLead, lead = pcall(UnitThreatPercentageOfLead, "player", unit)
        local leadText = (not okLead and "error") or (IsSecret(lead) and "secret") or tostring(lead)
        return unit .. " plain " .. string.format("%.0f", value) .. " (lead " .. leadText .. ")"
    end
    local line = "your target: " .. Describe("target")
    for unit, box in pairs(active) do
        if IsPlateOf(box.plate, "target") then line = line .. ", " .. Describe(unit) end
    end
    Print(line)
    Print("art: " .. atlasOK .. ", anchor error: " .. (report.anchorError or "none")
        .. ", unit frames: " .. (report.frameError or ((frameBoxes.target and "target " or "") .. (frameBoxes.focus and "focus " or "") .. "ok")))
end

SLASH_THREATBOX1 = "/threatbox"
SLASH_THREATBOX2 = "/tbox"
SlashCmdList["THREATBOX"] = function(msg)
    local cmd, rest = (msg or ""):lower():match("^%s*(%S*)%s*(.-)%s*$")
    if cmd == "" or cmd == "options" or cmd == "config" then
        if ns.Options and ns.Options.Open then ns.Options.Open() end
    elseif ns.POSITION_LABELS[cmd] then
        ns.SetPosition(cmd)
        Print(ns.POSITION_LABELS[cmd] .. ".")
    elseif cmd == "test" or cmd == "sample" then
        ns.preview = not ns.preview
        UpdateAll()
        Print(ns.preview and "Showing a sample on every nameplate. /threatbox test again to stop." or "Sample off.")
    elseif cmd == "size" and tonumber(rest) then
        db.scale = math.max(0.5, math.min(2, tonumber(rest) / 100))
        ns.Apply()
        Print("Size " .. math.floor(db.scale * 100 + 0.5) .. "%.")
    elseif (cmd == "petsize" or cmd == "whosize" or cmd == "targetsize") and tonumber(rest) then
        local set = ns.PIECES[cmd == "petsize" and "pet" or "who"]
        db[set.scale] = math.max(ns.SCALE_MIN, math.min(ns.SCALE_MAX, tonumber(rest) / 100))
        ns.Apply()
        Print(set.name .. " size " .. math.floor(db[set.scale] * 100 + 0.5) .. "%.")
    elseif cmd == "framesize" and tonumber(rest) then
        db.frameScale = math.max(ns.SCALE_MIN, math.min(ns.SCALE_MAX, tonumber(rest) / 100))
        ns.Apply()
        Print("Target and focus frame box size " .. math.floor(db.frameScale * 100 + 0.5) .. "%.")
    elseif cmd == "nudge" then
        local x, y = rest:match("^(-?%d+)%s+(-?%d+)$")
        if x then
            db.offsetX, db.offsetY = tonumber(x), tonumber(y)
            ns.Apply()
            Print("Nudged " .. x .. " across, " .. y .. " up.")
        else
            Print("Usage: /threatbox nudge <across> <up>, for example /threatbox nudge 0 -4")
        end
    elseif cmd == "pull" or cmd == "raw" then
        db.number = cmd
        ns.Apply()
        Print(cmd == "pull" and "The number is how close you are to taking the enemy: 100% pulls, from melee or from range."
            or "The number is your raw threat: 110% pulls in melee range, 130% from range.")
    elseif cmd == "colors" then
        if ns.COLOR_LABELS[rest] then
            db.colors = rest
            ns.Apply()
            Print("Colors: " .. ns.COLOR_LABELS[rest] .. ".")
        else
            Print("Usage: /threatbox colors normal | tank | reversed")
        end
    elseif cmd == "style" then
        local Styles = ns.Styles
        if not Styles then
            Print("Window styles are not available.")
        else
            if rest == "auto" or rest == "automatic" then Styles.Set("auto")
            elseif rest == "blizzard" or rest == "dark" then Styles.Set(rest)
            elseif rest == "" then Styles.Cycle(1) end
            Print("Window style: " .. Styles.Name(db.style) .. ". " .. Styles.Note())
        end
    elseif ns.TOGGLES[cmd] then
        local key = ns.TOGGLES[cmd]
        db[key] = not db[key]
        ns.Apply()
        Print(ns.TOGGLE_LABELS[key] .. ": " .. (db[key] and "on" or "off") .. ".")
    elseif cmd == "detach" or cmd == "attach" then
        -- /threatbox detach pet above, /threatbox detach who, /threatbox attach pet
        local piece, where = rest:match("^(%S*)%s*(%S*)$")
        if piece == "name" then piece = "who" end
        local set = ns.PIECES[piece]
        if not set then
            Print("Usage: /threatbox detach pet | who [below | above | right | left], /threatbox attach pet | who")
        elseif cmd == "attach" then
            ns.SetPiece(piece, nil)
            Print(set.name .. ": back in the row with the threat box.")
        else
            if where == "" then where = db[set.position] end
            if ns.SetPiece(piece, where) then
                Print(set.name .. ": on its own, " .. ns.POSITION_LABELS[where]:lower() .. ".")
            else
                Print("Positions: below, above, right, left.")
            end
        end
    elseif cmd == "pulseat" and tonumber(rest) then
        db.warnAt = math.max(50, math.min(100, math.floor(tonumber(rest) + 0.5)))
        ns.Apply()
        Print("The box pulses from " .. db.warnAt .. "%.")
    elseif cmd == "reset" then
        ns.Reset()
        Print("Settings reset.")
    elseif cmd == "debug" then
        Debug()
    else
        Print("/threatbox (options), /threatbox below | above | right | left, /threatbox test, "
            .. "/threatbox pull | raw, /threatbox colors normal | tank | reversed, /threatbox size <50-200>, "
            .. "/threatbox nudge <across> <up>, /threatbox style auto | blizzard | dark, /threatbox reset, /threatbox debug")
        Print("On or off: /threatbox border, text, background, fill, lead, pulse, sound, who, pet, group, combat, targetonly, trivial. /threatbox pulseat <50-100>.")
        Print("/threatbox detach pet | who [below | above | right | left] puts that piece on its own; /threatbox attach pet | who puts it back. /threatbox petsize | whosize <50-200>.")
        Print("/threatbox targetframe and /threatbox focusframe put a threat box on those frames; /threatbox framesize <50-200>.")
    end
    if ns.Options and ns.Options.Refresh then ns.Options.Refresh() end
end
