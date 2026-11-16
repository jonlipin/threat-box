-- Threat Box's pieces in the window styles. Styles.lua does the choosing and the drawing
-- (Blizzard, Dark, or EllesmereUI's look); this file says what Threat Box restyles.
--
-- The box: in Dark and EllesmereUI it goes flat, the way EllesmereUI draws its own nameplate
-- level box. The level box art becomes a flat dark panel, and the outline art becomes a thin
-- flat edge one screen pixel wide. The edge keeps its threat colors and the way they are picked:
-- the same three status bars, now filled with a plain color behind the panel instead of the
-- outline art over it, so it still works on hidden threat values. The warning pulse becomes a
-- flat glow a little wider than the edge, the fill meter takes the style's accent color, and the
-- name plaque and the pet's box go flat the same way. The style's font is used.
-- The options live on the game's own Options > AddOns page, which keeps the game's look; only
-- the threat box in the preview follows the style, like the ones on nameplates.

local ADDON, ns = ...
local Styles = ns.Styles
local Try = Styles.Try
local FLAT = "Interface\\Buttons\\WHITE8X8"
local EDGE_GREY = 0.69

local function S() return Styles.S end

local function PanelColor()
    local r, g, b = S().GetPanelColor()
    return r or 0.07, g or 0.07, b or 0.08, 0.92
end

local function PaintPanel(box)
    box.panel.bg:SetColorTexture(PanelColor())
end

local function PaintWho(who)
    who.flatBg:SetColorTexture(PanelColor())
end

local function Outset(piece, owner, out)
    piece:ClearAllPoints()
    piece:SetPoint("TOPLEFT", owner, "TOPLEFT", -out, out)
    piece:SetPoint("BOTTOMRIGHT", owner, "BOTTOMRIGHT", out, -out)
end

-- One screen pixel in the box's own units, so the edge stays crisp at any nameplate size. A
-- nameplate's scale is not final when its box is first placed, so this is asked again as the box
-- updates, and the edge never gets thicker than a sixth of the box.
local function Pixel(frame)
    local px = 1
    if PixelUtil and PixelUtil.GetNearestPixelSize then
        local ok, got = pcall(PixelUtil.GetNearestPixelSize, 1, frame:GetEffectiveScale(), 1)
        if ok and type(got) == "number" and got > 0 then px = got end
    end
    local h = frame:GetHeight() or 18
    if h > 0 and px > h / 6 then px = h / 6 end
    return px
end

function ns.SizeBoxEdge(box)
    -- The pet box and the target box have sizes of their own, so each asks for itself.
    if box.pet and box.pet.flat then ns.SizeBoxEdge(box.pet) end
    local who = box.who
    if who and who.edge then
        local wpx = Pixel(who)
        if not who.edgePx or math.abs(who.edgePx - wpx) >= wpx * 0.05 then
            who.edgePx = wpx
            Outset(who.edge, who, wpx)
        end
    end
    local px = Pixel(box)
    if box.edgePx and math.abs(box.edgePx - px) < px * 0.05 then return end
    box.edgePx = px
    Outset(box.border, box, px)
    for _, step in ipairs(box.steps) do Outset(step, box, px) end
    Outset(box.gate, box, px * 3) -- the pulse glows two pixels past the edge
end

function ns.SkinBox(box)
    if not S() or box.flat then return end
    box.flat = true
    Try("threat box", function()
        box.bg:Hide()
        -- The panel sits above the edge's color steps, under the fill meter and the number.
        local panel = CreateFrame("Frame", nil, box)
        panel:SetAllPoints(box)
        panel:SetFrameLevel((box.frameLevel or box:GetFrameLevel() or 1) + ns.LEVELS.panel)
        panel.bg = panel:CreateTexture(nil, "BACKGROUND")
        panel.bg:SetAllPoints(panel)
        box.panel = panel
        PaintPanel(box)

        box.border:SetTexture(FLAT)
        if box.border.SetTexCoord then box.border:SetTexCoord(0, 1, 0, 1) end
        for _, step in ipairs(box.steps) do step:SetStatusBarTexture(FLAT) end
        box.gate:SetStatusBarTexture(FLAT)
        box.gate:SetStatusBarColor(1, 0.25, 0.1)
        local r, g, b = S().GetAccentColor()
        box.fill:ClearAllPoints()
        box.fill:SetAllPoints(box)
        box.fill:SetStatusBarColor(r or 1, g or 0.6, b or 0.2, 0.4)
        -- The background colors cover the whole flat panel, inside the edge.
        for _, tint in ipairs(box.tints) do
            tint:ClearAllPoints()
            tint:SetAllPoints(box)
        end

        box.colors = nil     -- the colors are painted again on the new fills
        box.layoutKey = nil  -- and the box is placed again, with the panel's frame level
        ns.SizeBoxEdge(box)
        -- The style's font may bring its own color: the number goes back to its plain color
        -- first, and its threat colors are painted again on the next update.
        local plain = box.inkColors and box.plainColor
        if plain then box.text:SetTextColor(plain[1], plain[2], plain[3]) end
        box.inkColors, box.plainColor = nil, nil
        for _, ink in ipairs(box.inks) do S().Font(ink.text) end
        S().Font(box.text)
    end)
end

-- The name plaque: the three-piece level box art gives way to a flat panel with a grey edge.
function ns.SkinWho(who)
    if not S() or who.flat then return end
    who.flat = true
    Try("name plaque", function()
        for _, set in ipairs({ who.bg, who.ring }) do
            for _, part in ipairs(set.parts) do part:Hide() end
        end
        who.edge = who:CreateTexture(nil, "BACKGROUND", nil, -1)
        who.edge:SetColorTexture(EDGE_GREY, EDGE_GREY, EDGE_GREY, 1)
        Outset(who.edge, who, 1)
        who.flatBg = who:CreateTexture(nil, "BACKGROUND", nil, 0)
        who.flatBg:SetAllPoints(who)
        PaintWho(who)
        S().Font(who.text)
    end)
end

local function SkinAll(skin)
    for box in pairs(ns.allBoxes) do ns.SkinBox(box) end
    for who in pairs(ns.allWho) do ns.SkinWho(who) end
    if ns.Options and ns.Options.Flatten then Try("preview", ns.Options.Flatten) end
    if ns.db then Try("apply", ns.Apply) end
    skin.OnLooksChanged(function()
        for box in pairs(ns.allBoxes) do
            if box.panel then Try("panel color", PaintPanel, box) end
        end
        for who in pairs(ns.allWho) do
            if who.flatBg then Try("plaque color", PaintWho, who) end
        end
    end)
end

Styles.Setup({
    addon = ADDON,
    title = "Threat Box",
    db = function() return ns.DB and ns.DB() end,
    report = ns.report,
    accent = { 1, 0.6, 0.2 }, -- the orange of a threat warning
    skin = SkinAll,
})
