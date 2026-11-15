// Offline checks for Threat Box: loads the addon into fengari (Lua 5.3) against a small stand-in
// for the WoW Forever client and drives nameplates, threat readings (plain and secret), every
// position, the options page and the slash commands.
//
//   node tests/threatboxtest.js
//
// fengari is looked for in FENGARI=<its folder>, then on the normal require path.
//
// Secret values are tables whose metatable throws on comparison, arithmetic, indexing and
// concatenation. A truth test or an == against nil cannot be trapped this way, so those are
// still reasoned about in the source.
'use strict';
const fs = require('fs');
const path = require('path');

const ROOT = path.join(__dirname, '..');
function findFengari() {
  const tries = [];
  if (process.env.FENGARI) tries.push(process.env.FENGARI);
  try { tries.push(path.dirname(require.resolve('fengari/package.json'))); } catch (e) { /* not on the path */ }
  for (const d of tries) if (fs.existsSync(path.join(d, 'src', 'lvm.js'))) return d;
  throw new Error('fengari not found; set FENGARI to its folder');
}
const { lua, lauxlib, lualib, to_luastring, to_jsstring } = require(findFengari());

const STUBS = String.raw`
local SECRET_MT = {}
local function boom(what) return function() error("attempt to perform " .. what .. " on a secret value", 2) end end
SECRET_MT.__eq = boom("comparison"); SECRET_MT.__lt = boom("comparison"); SECRET_MT.__le = boom("comparison")
SECRET_MT.__add = boom("arithmetic"); SECRET_MT.__sub = boom("arithmetic"); SECRET_MT.__mul = boom("arithmetic")
SECRET_MT.__div = boom("arithmetic"); SECRET_MT.__unm = boom("arithmetic"); SECRET_MT.__concat = boom("concatenation")
SECRET_MT.__index = boom("indexing"); SECRET_MT.__tostring = function() return "<secret>" end
function Secret(v) return setmetatable({ hidden = v }, SECRET_MT) end
function issecretvalue(v) return getmetatable(v) == SECRET_MT end
local function reveal(v) if issecretvalue(v) then return rawget(v, "hidden") end return v end
T = { reveal = reveal, printed = {}, frames = {}, timers = {} }

local Frame = {}
Frame.__index = function(self, key)
    local m = rawget(Frame, key)
    if m then return m end
    if type(key) == "string" and key:match("^[A-Z]") then
        -- Any other widget method: accepted, remembered by name.
        return function(f, ...) f.calls[key] = { ... } end
    end
end
local function new(kind, parent)
    local f = setmetatable({ kind = kind, parent = parent, shown = true, points = {}, calls = {}, scripts = {},
        w = 0, h = 0, scale = 1, level = 1, strata = "MEDIUM" }, Frame)
    T.frames[#T.frames + 1] = f
    return f
end
T.new = new
function Frame:Show() self.shown = true if self.scripts.OnShow then self.scripts.OnShow(self) end end
function Frame:Hide() self.shown = false end
function Frame:IsShown() return self.shown end
function Frame:IsVisible() return self.shown end
function Frame:SetShown(v) if v then self:Show() else self:Hide() end end
function Frame:IsForbidden() return self.forbidden or false end
function Frame:SetSize(w, h) self.w, self.h = w, h end
function Frame:GetWidth() return self.w end
function Frame:GetHeight() return self.h end
function Frame:SetWidth(w) self.w = w end
function Frame:SetScale(s) assert(not issecretvalue(s)) self.scale = s end
function Frame:GetEffectiveScale() return self.scale * (self.parent and self.parent:GetEffectiveScale() or 1) end
function Frame:SetFrameLevel(l) self.level = l end
function Frame:GetFrameLevel() return self.level end
function Frame:SetFrameStrata(s) self.strata = s end
function Frame:GetFrameStrata() return self.strata end
function Frame:ClearAllPoints() self.points = {} end
function Frame:SetPoint(point, rel, relPoint, x, y)
    if type(rel) == "number" then rel, relPoint, x, y = self.parent, point, rel, relPoint end
    if rel and rel.refuseAnchors then error("anchor refused") end
    self.points[#self.points + 1] = { point = point, rel = rel, relPoint = relPoint, x = x or 0, y = y or 0 }
end
function Frame:SetAllPoints() end
function Frame:CreateTexture() local t = new("Texture", self) return t end
function Frame:CreateFontString(_, _, font)
    if font == "NoSuchFont" then error("no font") end
    local t = new("FontString", self) t.font = font return t
end
function Frame:SetAtlas(a) self.atlas = a end
function Frame:CreateAnimationGroup() local g = new("AnimGroup", self) self.animGroup = g return g end
function Frame:CreateAnimation(kind) return new("Anim", self) end
function Frame:Play() self.playing = true end
function Frame:SetAlpha(a) self.alpha = a self.alphaFromSecret = false end
function Frame:GetAlpha() return self.alpha or 1 end
function Frame:SetAlphaFromBoolean(v, a, b)
    self.alphaFromSecret = issecretvalue(v)
    if reveal(v) then self.alpha = a else self.alpha = b end
end
function Frame:SetTextColor(r, g, b) self.textColor = { r, g, b } end
function Frame:SetTexCoord(...) self.texCoord = { ... } end
function Frame:SetTexture(t) self.texture = t self.atlas = nil end
function Frame:SetColorTexture(r, g, b, a) self.colorTexture = { r, g, b, a } self.atlas = nil end
function Frame:SetParent(p) self.parent = p end
function Frame:GetParent() return self.parent end
function Frame:GetChildren()
    local out = {}
    for _, f in ipairs(T.frames) do
        if f.parent == self and f.kind ~= "Texture" and f.kind ~= "FontString" then out[#out + 1] = f end
    end
    return table.unpack(out)
end
function Frame:UnregisterAllEvents() self.events = {} end
function Frame:SetVertexColor(r, g, b) self.color = { r, g, b } end
function Frame:SetStatusBarTexture(t) self.fill = t end
function Frame:GetStatusBarTexture() return self.fill end
function Frame:SetStatusBarColor(r, g, b, a) self.color = { r, g, b, a } end
function Frame:SetMinMaxValues(a, b) self.min, self.max = a, b end
function Frame:SetValue(v) self.value = v end
function Frame:SetHeight(h) self.h = h end
function Frame:GetValue() return self.value end
function Frame:SetText(s) self.text = s end
function Frame:GetText() return self.text end
function Frame:GetLeft() return self.rect and self.rect[1] end
function Frame:GetRight() return self.rect and self.rect[2] end
function Frame:GetTop() return self.rect and self.rect[3] end
function Frame:GetBottom() return self.rect and self.rect[4] end
function Frame:SetFormattedText(fmt, ...)
    local args = { ... }
    self.secretText = false
    for i, v in ipairs(args) do if issecretvalue(v) then self.secretText = true args[i] = reveal(v) end end
    self.text = string.format(fmt, table.unpack(args))
end
function Frame:SetTextHeight(h) self.textHeight = h end
function Frame:SetScript(name, fn) self.scripts[name] = fn end
function Frame:RegisterEvent(e) self.events = self.events or {} self.events[e] = true end
function Frame:UnregisterEvent(e) if self.events then self.events[e] = nil end end
function Frame:SetChecked(v) self.checked = v end
function Frame:GetChecked() return self.checked end

function CreateFrame(kind, name, parent, template)
    if template and T.badTemplates and T.badTemplates[template] then error("no template " .. template) end
    local f = new(kind, parent)
    if name then _G[name] = f end
    return f
end
UIParent = new("Frame")
function T.fire(event, ...)
    for _, f in ipairs(T.frames) do
        if f.events and f.events[event] and f.scripts.OnEvent then f.scripts.OnEvent(f, event, ...) end
    end
end
function print(msg) T.printed[#T.printed + 1] = tostring(msg) end
C_Timer = { NewTicker = function(period, fn) T.timers[#T.timers + 1] = fn return {} end }
function T.tick() for _, fn in ipairs(T.timers) do fn() end end
SlashCmdList = {}
C_AddOns = { IsAddOnLoaded = function(name) return T.loaded and T.loaded[name] or false end }
UISpecialFrames = {}
function CreateColor(r, g, b, a) return { r = r, g = g, b = b, a = a } end
-- A stand-in EllesmereUI: records the skin registration and hands over drawing calls on request.
function T.ellesmere()
    EllesmereUI = { _DispatchSkinRegistration = function() end }
    function EllesmereUI.RegisterSkin(addon, fn) T.euiSkinFor, T.euiSkinFn = addon, fn end
    T.euiCalls = {}
    T.euiFacade = setmetatable({
        GetPanelColor = function() return 0.1, 0.2, 0.3, 1 end,
        GetAccentColor = function() return 0.3, 0.6, 0.9 end,
        GetStyle = function() return "eui" end,
        Font = function(fs) T.euiCalls.font = fs end,
        OnLooksChanged = function(fn) T.euiCalls.looks = fn end,
    }, { __index = function(_, k) return function() T.euiCalls[k] = true end end })
end
-- EllesmereUI's own plate on a nameplate: a child keeping .nameplate, .health and a level box.
function T.euiPlate(unit, withLevel)
    local plate = T.plates[unit]
    local eui = T.new("Frame", plate)
    eui.nameplate = plate
    eui.health = T.new("StatusBar", eui)
    eui.health:SetSize(156, 17)
    eui.health.level = 20
    if withLevel then
        eui._fvLevelBox = T.new("Frame", eui)
        eui._fvLevelBox:SetSize(28, 22)
        eui._fvLevelBox.level = 30
    end
    return eui
end
T.cursor = { 0, 0 }
function GetCursorPosition() return T.cursor[1], T.cursor[2] end
T.now = 100
function GetTime() return T.now end
PlayerUtil = { IsPlayerEffectivelyTank = function() return T.tank or false end }
function T.setTank(on) T.tank = on T.now = T.now + 5 end
NamePlateSetupOptions = { levelFontHeight = 10 }

-- Nameplates
T.plates, T.threat, T.units = {}, {}, {}
function T.plate(unit, opts)
    opts = opts or {}
    local plate = new("Frame", UIParent)
    local uf = new("Button", plate) uf.scale = opts.ufScale or 1
    plate.UnitFrame = uf
    uf.HealthBarsContainer = new("Frame", uf)
    uf.HealthBarsContainer.healthBar = new("StatusBar", uf.HealthBarsContainer)
    uf.PlayerLevelDiffFrame = new("Frame", uf)
    uf.PlayerLevelDiffFrame:SetSize(28, 18)
    uf.PlayerLevelDiffFrame.level = 50
    uf.PlayerLevelDiffFrame.strata = "MEDIUM"
    if opts.forbidden then uf.forbidden = true end
    T.plates[unit] = plate
    T.units[unit] = { attackable = opts.attackable ~= false, dead = false }
    T.fire("NAME_PLATE_UNIT_ADDED", unit)
    return plate
end
function T.box(unit)
    local plate = T.plates[unit]
    for _, f in ipairs(T.frames) do
        if f.parent == plate and f ~= plate.UnitFrame and f.steps then return f end
    end
end
C_NamePlate = { GetNamePlateForUnit = function(unit)
    if unit == "target" then unit = T.targetUnit elseif unit == "focus" then unit = T.focusUnit end
    local p = unit and T.plates[unit]
    if p and p.UnitFrame.forbidden and T.hideForbidden then return nil end
    return p
end }
T.targets, T.petThreat = {}, {}
local function tgt(token) local u = token:match("^(.*)target$") return u and T.targets[u] end
function UnitExists(token)
    if token == "pet" then return T.hasPet or false end
    return tgt(token) ~= nil
end
function UnitName(token)
    local t = tgt(token)
    if not t then return nil end
    if t.secret then return Secret(t.name) end
    return t.name, "Surname"
end
function UnitIsUnit(a, b)
    local t = tgt(a)
    if not t then return false end
    local v = (b == "player" and t.isYou) or (b == "pet" and t.isPet) or false
    if t.secret then return Secret(v) end
    return v
end
function UnitIsPlayer(token) local t = tgt(token) return t and t.isPlayer or false end
function UnitClass(token) local t = tgt(token) return "Warrior", t and t.class end
RAID_CLASS_COLORS = { WARRIOR = { r = 0.78, g = 0.61, b = 0.43 } }
function IsInGroup() return T.grouped or false end
function UnitIsTrivial(unit) return T.units[unit] and T.units[unit].trivial or false end
function UnitAffectingCombat() return false end
T.sounds = {}
function PlaySound(kit, channel) T.sounds[#T.sounds + 1] = kit end
SOUNDKIT = { ALARM_CLOCK_WARNING_3 = 12889, RAID_WARNING = 8959 }
function T.combatOn() T.fire("PLAYER_REGEN_DISABLED") end
function T.combatOff() T.fire("PLAYER_REGEN_ENABLED") end
function UnitCanAttack(_, unit) return T.units[unit] and T.units[unit].attackable end
function UnitIsDead(unit) return T.units[unit] and T.units[unit].dead end
function UnitDetailedThreatSituation(who, unit)
    local t = (who == "pet") and T.petThreat[unit] or (who ~= "pet") and T.threat[unit] or nil
    if not t then return end
    if t.secret then return Secret(t.tanking), Secret(t.status), Secret(t.scaled), Secret(t.raw), Secret(0) end
    return t.tanking, t.status, t.scaled, t.raw, 0
end
function UnitThreatPercentageOfLead(who, unit)
    local t = T.threat[unit]
    if not t then return nil end
    if t.secret then return Secret(t.lead) end
    return t.lead
end
function InCombatLockdown() return T.combat or false end
Settings = {
    RegisterCanvasLayoutCategory = function(page, title) T.page = page return { GetID = function() return 7 end } end,
    RegisterAddOnCategory = function() end,
    OpenToCategory = function(id) SettingsPanel.shown = true T.page:Show() end,
}
SettingsPanel = new("Frame") SettingsPanel.shown = false
`;

let passed = 0, failed = 0;
const failures = [];

function makeState(pre) {
  const L = lauxlib.luaL_newstate();
  lualib.luaL_openlibs(L);
  const run = (code, name) => {
    if (lauxlib.luaL_loadbuffer(L, to_luastring(code), null, to_luastring(name || '=chunk')) !== lua.LUA_OK
      || lua.lua_pcall(L, 0, lua.LUA_MULTRET, 0) !== lua.LUA_OK) {
      const msg = to_jsstring(lua.lua_tostring(L, -1));
      lua.lua_pop(L, 1);
      throw new Error(msg);
    }
  };
  run(STUBS, '=stubs');
  // Each addon file is called with (addonName, ns), as the client does.
  run('NS = {}', '=ns');
  if (pre) run(pre, '=pre');
  for (const file of ['ThreatBox.lua', 'Options.lua', 'Styles.lua', 'ThreatBox_Skins.lua']) {
    const src = fs.readFileSync(path.join(ROOT, file), 'utf8');
    if (lauxlib.luaL_loadbuffer(L, to_luastring(src), null, to_luastring('@' + file)) !== lua.LUA_OK) {
      throw new Error(to_jsstring(lua.lua_tostring(L, -1)));
    }
    lua.lua_pushstring(L, to_luastring('ThreatBox'));
    lua.lua_getglobal(L, to_luastring('NS'));
    if (lua.lua_pcall(L, 2, 0, 0) !== lua.LUA_OK) throw new Error(to_jsstring(lua.lua_tostring(L, -1)));
  }
  return run;
}

function scenario(name, body, pre) {
  try {
    const run = makeState(pre);
    run(`
      local checks = 0
      function check(cond, what) checks = checks + 1 if not cond then error("CHECK FAILED: " .. tostring(what), 2) end end
      T.fire("ADDON_LOADED", "ThreatBox")
      local db = ThreatBoxDB
      ${body}
    `, '=' + name);
    passed++;
  } catch (e) {
    failed++;
    failures.push(name + ': ' + e.message);
  }
}

scenario('defaults are saved on load', `
  check(db.position == "below", "position") check(db.scale == 1, "scale")
  check(db.colorBorder == true and db.percentSign == true, "look")
  check(db.number == "pull" and db.colors == "normal", "number and colors")
  check(SlashCmdList.THREATBOX, "slash") check(T.page, "options page registered")
`);

scenario('no threat: the box stays hidden', `
  T.plate("nameplate1")
  local box = T.box("nameplate1")
  check(box, "box made") check(not box.shown, "hidden without threat")
`);

scenario('plain threat, not tanking: percentage and state color', `
  T.plate("nameplate1")
  T.threat.nameplate1 = { tanking = false, status = 1, scaled = 41.3, raw = 45.4, lead = 0 }
  T.fire("UNIT_THREAT_LIST_UPDATE", "nameplate1")
  local box = T.box("nameplate1")
  check(box.shown, "shown") check(box.text.text == "41%", "until you pull " .. tostring(box.text.text))
  SlashCmdList.THREATBOX("raw")
  check(db.number == "raw" and box.text.text == "45%", "raw " .. tostring(box.text.text))
  SlashCmdList.THREATBOX("pull")
  check(box.text.text == "41%", "back to pull")
  check(box.bg.atlas == "ui-hud-nameplates-levelindicator", "level box art")
  check(box.border.atlas == "ui-hud-nameplates-levelindicator-rectangle-selected", "border art")
  check(#box.steps == 3, "three color steps")
  for state, bar in ipairs(box.steps) do
    check(bar.min == state - 1 and bar.max == state, "range " .. state)
    check(bar.value == 1, "state handed to bar " .. state)
    check(bar.fill.atlas == box.border.atlas, "same outline " .. state)
    check(bar.shown, "bar shown")
  end
  check(box.steps[1].color[3] < 0.6, "yellow") check(box.steps[3].color[2] == 0, "red")
`);

scenario('tanking: lead percentage, raw when there is no lead', `
  T.plate("nameplate1")
  T.threat.nameplate1 = { tanking = true, status = 3, scaled = 100, raw = 100, lead = 131.6 }
  T.tick()
  local box = T.box("nameplate1")
  check(box.text.text == "132%", "lead " .. tostring(box.text.text))
  check(box.steps[3].value == 3, "red state")
  T.threat.nameplate1.lead = 0
  T.tick()
  check(box.shown and box.text.text == "100%", "raw fallback " .. tostring(box.text.text))
  T.threat.nameplate1.lead = nil
  T.tick()
  check(box.text.text == "100%", "nil lead")
`);

scenario('zero threat hides, as the game does', `
  T.plate("nameplate1")
  T.threat.nameplate1 = { tanking = false, status = 0, scaled = 0, raw = 0, lead = 0 }
  T.tick()
  check(not T.box("nameplate1").shown, "hidden at 0")
`);

scenario('secret threat: handed to the game untouched', `
  T.plate("nameplate1")
  T.threat.nameplate1 = { secret = true, tanking = true, status = 3, scaled = 100, raw = 100, lead = 250 }
  T.tick()
  local box = T.box("nameplate1")
  check(box.shown, "shown") check(box.text.secretText, "number formatted by the game")
  check(box.text.text == "100%", "raw percentage " .. tostring(box.text.text))
  for state, bar in ipairs(box.steps) do
    check(issecretvalue(bar.value), "secret state reaches bar " .. state)
    check(T.reveal(bar.value) == 3, "state value")
  end
  check(NS.report.secretReads == 1, "counted")
  -- and back to plain values afterwards
  T.threat.nameplate1 = { tanking = false, status = 1, scaled = 20, raw = 20, lead = 0 }
  T.tick()
  check(box.text.text == "20%" and not box.text.secretText, "plain again")
`);

scenario('positions anchor where asked', `
  local plate = T.plate("nameplate1")
  local uf = plate.UnitFrame
  T.threat.nameplate1 = { tanking = false, status = 1, scaled = 50, raw = 50, lead = 0 }
  T.tick()
  local box = T.box("nameplate1")
  local p = box.points[1]
  check(p.point == "TOPLEFT" and p.rel == uf.PlayerLevelDiffFrame and p.relPoint == "BOTTOMLEFT", "below")
  check(p.y < 0 and p.x == 0, "below gap")
  NS.SetPosition("above") p = box.points[1]
  check(#box.points == 1, "one anchor")
  check(p.point == "BOTTOMLEFT" and p.rel == uf.PlayerLevelDiffFrame and p.relPoint == "TOPLEFT" and p.y > 0, "above")
  NS.SetPosition("right") p = box.points[1]
  check(p.point == "LEFT" and p.rel == uf.PlayerLevelDiffFrame and p.relPoint == "RIGHT" and p.x > 0, "right")
  NS.SetPosition("left") p = box.points[1]
  check(p.point == "TOPRIGHT" and p.rel == uf.HealthBarsContainer.healthBar and p.relPoint == "TOPLEFT" and p.x < 0, "left")
  check(not NS.SetPosition("sideways") and db.position == "left", "bad position refused")
  db.offsetX, db.offsetY = 7, -3 NS.Apply() p = box.points[1]
  check(p.x == -5 + 7 and p.y == 3 - 3, "nudge")
`);

scenario('size follows the level box and the options', `
  local plate = T.plate("nameplate1", { ufScale = 0.8 })
  T.threat.nameplate1 = { tanking = false, status = 1, scaled = 50, raw = 50, lead = 0 }
  T.tick()
  local box = T.box("nameplate1")
  check(box.h == 18 and box.w == 36, "wider for the sign: " .. box.w)
  check(math.abs(box.scale - 0.8) < 1e-9, "matches the unit frame scale")
  check(box.level == 50 and box.steps[3].level == 54 and box.gate.level == 51, "frame levels")
  check(box.fill.level == 56 and box.face.level == 57 and box.text.parent == box.face, "meter under the number")
  check(box.text.textHeight == 10, "font height")
  db.percentSign = false NS.Apply()
  check(box.w == 28, "level box width without the sign") check(box.text.text == "50", "no sign")
  db.scale = 1.5 NS.Apply()
  check(math.abs(box.scale - 1.2) < 1e-9, "size option")
  plate.UnitFrame.PlayerLevelDiffFrame:SetSize(35, 23) T.tick()
  check(box.w == 35 and box.h == 23, "follows a nameplate size change")
`);

scenario('border option off', `
  T.plate("nameplate1")
  T.threat.nameplate1 = { tanking = false, status = 2, scaled = 90, raw = 90, lead = 0 }
  db.colorBorder = false NS.Apply()
  local box = T.box("nameplate1")
  check(box.shown and not box.border.shown, "no border")
  for _, bar in ipairs(box.steps) do check(not bar.shown, "no color step") end
  db.colorBorder = true NS.Apply()
  check(box.border.shown and box.steps[2].shown, "border back")
`);

scenario('plates come and go', `
  T.plate("nameplate1")
  T.threat.nameplate1 = { tanking = false, status = 1, scaled = 50, raw = 50, lead = 0 }
  T.tick()
  local box = T.box("nameplate1")
  check(box.shown, "shown")
  T.fire("NAME_PLATE_UNIT_REMOVED", "nameplate1")
  check(not box.shown, "hidden on removal")
  T.tick() check(not box.shown, "stays hidden")
  T.fire("NAME_PLATE_UNIT_ADDED", "nameplate1")
  check(box.shown and T.box("nameplate1") == box, "same box reused")
  T.units.nameplate1.dead = true T.tick()
  check(not box.shown, "dead enemy")
`);

scenario('friendly, hidden and forbidden plates', `
  T.plate("nameplate1", { attackable = false })
  T.threat.nameplate1 = { tanking = false, status = 1, scaled = 50, raw = 50, lead = 0 }
  T.tick()
  check(not T.box("nameplate1").shown, "friendly")
  local plate = T.plate("nameplate2")
  T.threat.nameplate2 = T.threat.nameplate1
  T.tick() check(T.box("nameplate2").shown, "enemy")
  plate.UnitFrame:Hide() T.tick()
  check(not T.box("nameplate2").shown, "unit frame hidden")
  T.hideForbidden = true
  T.plate("nameplate3", { forbidden = true })
  check(T.box("nameplate3") == nil, "forbidden plate untouched")
  T.hideForbidden = false
  T.plate("nameplate4", { forbidden = true })
  T.threat.nameplate4 = T.threat.nameplate1
  T.tick() check(not T.box("nameplate4").shown, "forbidden unit frame")
`);

scenario('a refused anchor falls back to the plate', `
  local plate = T.plate("nameplate1")
  plate.UnitFrame.PlayerLevelDiffFrame.refuseAnchors = true
  T.threat.nameplate1 = { tanking = false, status = 1, scaled = 50, raw = 50, lead = 0 }
  NS.Apply()
  local box = T.box("nameplate1")
  check(box.shown and box.points[1].rel == plate, "anchored to the plate")
  check(NS.report.anchorError, "reported")
`);

scenario('sample mode', `
  T.plate("nameplate1")
  SlashCmdList.THREATBOX("test")
  local box = T.box("nameplate1")
  check(box.shown and box.text.text == "87%", "sample shown") check(box.steps[1].value == 2, "sample orange")
  T.threat.nameplate1 = { tanking = false, status = 1, scaled = 12, raw = 12, lead = 0 }
  T.tick() check(box.text.text == "12%", "real threat wins")
  T.threat.nameplate1 = nil
  SlashCmdList.THREATBOX("test") check(not box.shown, "sample off")
`);

scenario('slash commands', `
  T.plate("nameplate1")
  SlashCmdList.THREATBOX("above") check(db.position == "above", "above")
  SlashCmdList.THREATBOX(" LEFT ") check(db.position == "left", "case and spaces")
  SlashCmdList.THREATBOX("size 150") check(db.scale == 1.5, "size")
  SlashCmdList.THREATBOX("size 900") check(db.scale == 2, "size clamped")
  SlashCmdList.THREATBOX("nudge 4 -6") check(db.offsetX == 4 and db.offsetY == -6, "nudge")
  SlashCmdList.THREATBOX("reset") check(db.position == "below" and db.scale == 1 and db.offsetX == 0, "reset")
  local n = #T.printed
  SlashCmdList.THREATBOX("debug") check(#T.printed > n, "debug prints")
  n = #T.printed
  SlashCmdList.THREATBOX("nonsense") check(#T.printed == n + 3, "help lines")
`);

scenario('melee and ranged takeover: the game scales it, raw shows the difference', `
  T.plate("nameplate1")
  -- At range: 120% of the tank's threat is 92% of the way to pulling (130%).
  T.threat.nameplate1 = { tanking = false, status = 1, scaled = 92.3, raw = 120, lead = 0 }
  T.tick()
  local box = T.box("nameplate1")
  check(box.text.text == "92%", "ranged, scaled " .. tostring(box.text.text))
  db.number = "raw" NS.Apply()
  check(box.text.text == "120%", "ranged, raw")
  T.threat.nameplate1 = { secret = true, tanking = false, status = 1, scaled = 92.3, raw = 120, lead = 0 }
  T.tick() check(box.text.text == "120%" and box.text.secretText, "secret raw")
  db.number = "pull" NS.Apply()
  check(box.text.text == "92%" and box.text.secretText, "secret scaled")
`);

scenario('reversed colors for tanks', `
  T.plate("nameplate1")
  T.threat.nameplate1 = { tanking = true, status = 3, scaled = 100, raw = 100, lead = 150 }
  T.tick()
  local box = T.box("nameplate1")
  check(box.steps[3].color[1] == 1 and box.steps[3].color[2] == 0, "normal: red on you")
  db.colors = "tank" NS.Apply()
  check(box.steps[3].color[2] == 0, "not a tank: still normal") check(not NS.Reversed(), "not reversed")
  T.setTank(true) T.tick()
  check(NS.Reversed(), "tank role reverses")
  check(box.steps[3].color[1] < 0.5 and box.steps[3].color[2] > 0.8, "green while it is on you")
  check(box.border.color[1] == 1 and box.border.color[2] == 0, "red when lost")
  check(box.steps[3].value == 3, "state unchanged")
  -- a tank who lost the enemy: the game's orange override only applies to the normal colors
  T.threat.nameplate1 = { tanking = false, status = 0, scaled = 60, raw = 60, lead = 0 }
  T.tick() check(box.steps[1].value == 0, "reversed: true state")
  db.colors = "normal" NS.Apply()
  check(box.steps[1].value == 2, "normal: tank sees orange")
  check(box.steps[3].color[2] == 0, "normal colors back")
  T.setTank(false) db.colors = "reversed" NS.Apply()
  check(NS.Reversed() and box.steps[3].color[2] > 0.8, "always reversed")
  SlashCmdList.THREATBOX("colors tank") check(db.colors == "tank", "slash")
  -- secret state goes through the same bars
  T.threat.nameplate1 = { secret = true, tanking = true, status = 3, scaled = 100, raw = 100, lead = 0 }
  T.setTank(true) T.tick()
  check(issecretvalue(box.steps[3].value) and box.steps[3].color[2] > 0.8, "secret state, reversed colors")
`);

scenario('options page: tabs and controls', `
  T.plate("nameplate1")
  SlashCmdList.THREATBOX("")
  check(SettingsPanel.shown and T.page.shown, "page opened")
  local O = NS.Options
  local ui, tabs, blocks = O.ui, O.tabs, O.blocks
  check(O.column.h > 300, "scrolling column has a height")

  -- three tabs, one block showing
  check(tabs.threat.text == "Threat box" and tabs.pet.text == "Pet box" and tabs.who.text == "Target box", "tab names")
  check(O.Editing() == "threat" and blocks.threat.shown and not blocks.pet.shown and not blocks.who.shown, "threat tab first")
  check(tabs.threat.selected and not tabs.pet.selected, "selected look")
  tabs.pet.scripts.OnClick(tabs.pet)
  check(O.Editing() == "pet" and blocks.pet.shown and not blocks.threat.shown and tabs.pet.selected and not tabs.threat.selected, "pet tab")
  tabs.who.scripts.OnClick(tabs.who)
  check(blocks.who.shown and not blocks.pet.shown, "target tab")
  check(tabs.threat.points[1].x < tabs.pet.points[1].x and tabs.pet.points[1].x < tabs.who.points[1].x, "tabs left to right")
  -- every control sits in its own tab's block
  for _, key in ipairs({ "position", "offsetX", "offsetY", "scale", "warn", "warnAt", "sound", "number", "percentSign", "fill", "colorBorder", "colors" }) do
    check(ui[key], "threat control " .. key)
    local owner = ui[key].parent
    if owner ~= blocks.threat then owner = owner.parent end
    check(owner == blocks.threat, key .. " on the threat tab")
  end
  for _, key in ipairs({ "pet", "petDetached", "petPosition", "petX", "petY", "petScale" }) do
    local owner = ui[key].parent
    if owner ~= blocks.pet then owner = owner.parent end
    check(owner == blocks.pet, key .. " on the pet tab")
  end
  for _, key in ipairs({ "who", "whoDetached", "whoPosition", "whoX", "whoY", "whoWidth", "whoScale" }) do
    local owner = ui[key].parent
    if owner ~= blocks.who then owner = owner.parent end
    check(owner == blocks.who, key .. " on the target tab")
  end
  for _, key in ipairs({ "groupOnly", "combatOnly", "targetOnly", "skipTrivial", "style", "sample", "reset" }) do
    check(ui[key].parent == O.column, key .. " below the tabs")
  end
  -- a refresh (any setting change) keeps the picked tab
  NS.Options.Refresh() check(O.Editing() == "who" and blocks.who.shown, "tab kept")

  -- threat tab controls
  check(ui.position.text == "Below the level box", "position label")
  ui.position.scripts.OnClick(ui.position, "LeftButton")
  check(db.position == "above" and ui.position.text == "Above the level box", "cycle forward")
  ui.position.scripts.OnClick(ui.position, "RightButton") ui.position.scripts.OnClick(ui.position, "RightButton")
  check(db.position == "left", "cycle back wraps")
  ui.number.scripts.OnClick(ui.number, "LeftButton") check(db.number == "raw" and ui.number.text == "Raw threat", "number cycle")
  ui.colors.scripts.OnClick(ui.colors, "LeftButton") check(db.colors == "tank", "colors cycle")
  ui.offsetX.scripts.OnValueChanged(ui.offsetX, 12.4) check(db.offsetX == 12, "x slider")
  ui.scale.scripts.OnValueChanged(ui.scale, 150) check(db.scale == 1.5 and ui.scale.min == 50 and ui.scale.max == 200, "size slider")
  ui.warnAt.scripts.OnValueChanged(ui.warnAt, 90) check(db.warnAt == 90, "pulse slider")
  ui.percentSign.checked = false ui.percentSign.scripts.OnClick(ui.percentSign) check(db.percentSign == false, "sign check")
  ui.groupOnly.checked = true ui.groupOnly.scripts.OnClick(ui.groupOnly) check(db.groupOnly == true, "group rule")
  check(ui.style.text == "Automatic", "style label")

  -- target tab controls
  ui.who.checked = true ui.who.scripts.OnClick(ui.who) check(db.who == true, "show the target box")
  ui.whoDetached.checked = true ui.whoDetached.scripts.OnClick(ui.whoDetached)
  check(db.whoDetached == true and db.whoPosition == "left", "detach check")
  ui.whoPosition.scripts.OnClick(ui.whoPosition, "LeftButton")
  check(db.whoPosition == "below" and ui.whoPosition.text == "Below the level box", "its position cycles")
  ui.whoX.scripts.OnValueChanged(ui.whoX, -9) ui.whoY.scripts.OnValueChanged(ui.whoY, 4)
  check(db.whoX == -9 and db.whoY == 4, "its own nudge sliders")
  ui.whoWidth.scripts.OnValueChanged(ui.whoWidth, 90) check(db.whoWidth == 90, "width slider")
  ui.whoDetached.checked = false ui.whoDetached.scripts.OnClick(ui.whoDetached)
  check(db.whoDetached == false, "back in the row")
  -- pet tab controls
  ui.petPosition.scripts.OnClick(ui.petPosition, "LeftButton")
  check(db.petDetached == true and db.petPosition == "right", "picking a place detaches")
  ui.petX.scripts.OnValueChanged(ui.petX, 6) check(db.petX == 6, "pet nudge")
  ui.petScale.scripts.OnValueChanged(ui.petScale, 130) check(db.petScale == 1.3, "pet size slider")
  ui.whoScale.scripts.OnValueChanged(ui.whoScale, 80) check(db.whoScale == 0.8, "target size slider")

  ui.reset.scripts.OnClick(ui.reset)
  check(db.position == "below" and db.scale == 1 and db.number == "pull" and db.colors == "normal" and db.percentSign, "reset")
  check(db.groupOnly == false and db.warnAt == 80 and db.who == false and db.fill == true, "reset covers the extras")
  check(db.petDetached == false and db.petPosition == "above" and db.whoWidth == 60, "reset rejoins the pieces")
  check(db.petScale == 1 and db.whoScale == 1, "reset sizes")
  check(ui.position.text == "Below the level box", "controls follow a reset")
  T.combat = true local n = #T.printed
  SlashCmdList.THREATBOX("") check(#T.printed == n + 1, "combat message")
`);

scenario('options preview: clicking a box picks its tab; target box width', `
  T.plate("nameplate1")
  T.threat.nameplate1 = { tanking = false, status = 1, scaled = 50, raw = 50, lead = 0 }
  T.targets.nameplate1 = { name = "Brakka", isPlayer = true, class = "WARRIOR" }
  SlashCmdList.THREATBOX("")
  local O = NS.Options
  local P = O.preview
  db.who, db.pet = true, true NS.Apply()
  P.box.pet.scripts.OnMouseDown(P.box.pet) check(O.Editing() == "pet", "pet box picks the pet tab")
  P.box.who.scripts.OnMouseDown(P.box.who) check(O.Editing() == "who", "target box picks its tab")
  P.box.scripts.OnMouseDown(P.box) check(O.Editing() == "threat", "threat box picks its tab")
  -- the width setting reaches the preview and real nameplates
  local real = T.box("nameplate1")
  check(real.who.w == 60 and P.box.who.w == 60, "default width")
  db.whoWidth = 96 NS.Apply()
  check(real.who.w == 96 and real.who.text.w == 88 and P.box.who.w == 96, "wider")
`);

scenario('options preview: drag, drop areas, wheel, click', `
  local plate = T.plate("nameplate1")
  T.threat.nameplate1 = { tanking = false, status = 1, scaled = 50, raw = 50, lead = 0 }
  SlashCmdList.THREATBOX("")
  local P = NS.Options.preview
  check(P and P.box and P.box.shown, "preview box shown")
  check(P.box.text.text == "87%", "sample number") check(P.box.steps[1].value == 2, "sample state")
  check(P.box.pulse.shown and P.box.pulse.alpha == 1 and P.box.gate.value == 87, "sample pulses past 80")
  check(P.box.fill.shown and P.box.fill.value == 87, "sample fills")
  check(not P.box.who and not P.box.pet, "no plaque or pet box until asked for")
  db.who, db.pet = true, true NS.Apply()
  check(P.box.who.shown and P.box.who.text.text == "Tharandir", "sample name")
  check(P.box.pet.shown and P.box.pet.text.text == "34%", "sample pet")
  db.who, db.pet = false, false NS.Apply()
  check(not P.box.who.shown and not P.box.pet.shown, "and gone again")
  check(P.box.points[1].rel == P.level and P.box.points[1].point == "TOPLEFT", "pinned below the mock level box")
  check(P.box.w == P.level.w + 8 and P.box.h == P.level.h, "sized from the mock level box")
  check(P.box.scripts.OnDragStart and P.box.scripts.OnMouseWheel, "mouse scripts")
  local real = T.box("nameplate1")
  check(not real.scripts.OnDragStart, "real boxes take no mouse")

  -- drag: 10 right, 6 down
  T.cursor = { 500, 300 }
  P.box.scripts.OnMouseDown(P.box) P.box.scripts.OnDragStart(P.box)
  check(P.Dragging() and P.zoneLayer.shown, "areas show while dragging")
  T.cursor = { 510, 294 } P.DragUpdate()
  check(db.offsetX == 10 and db.offsetY == -6, "nudged " .. db.offsetX .. "/" .. db.offsetY)
  check(real.points[1].x == 10, "real nameplate follows live")
  T.cursor = { 9999, 300 } P.DragUpdate() check(db.offsetX == 60, "clamped")
  T.cursor = { 510, 294 }
  P.box.scripts.OnDragStop(P.box)
  check(not P.Dragging() and not P.zoneLayer.shown, "areas hide")
  check(db.position == "below" and db.offsetX == 10 and db.offsetY == -6, "kept where dropped")
  P.box.scripts.OnMouseUp(P.box) check(P.status == 2, "a drag is not a click")

  -- drop on the area left of the health bar
  P.zones.left.rect = { 100, 150, 320, 280 }
  P.box.scripts.OnMouseDown(P.box) P.box.scripts.OnDragStart(P.box)
  T.cursor = { 120, 300 } P.DragUpdate()
  check(db.position == "below", "not pinned until dropped")
  P.box.scripts.OnDragStop(P.box)
  check(db.position == "left" and db.offsetX == 0 and db.offsetY == 0, "pinned left, offsets cleared")
  check(P.box.points[1].rel == P.bar and real.points[1].point == "TOPRIGHT", "preview and real box moved")
  -- dropping on the area it is already pinned to only nudges
  P.box.scripts.OnMouseDown(P.box) P.box.scripts.OnDragStart(P.box)
  T.cursor = { 123, 300 } P.DragUpdate() P.box.scripts.OnDragStop(P.box)
  check(db.position == "left" and db.offsetX == 3, "own area nudges")

  -- wheel
  P.box.scripts.OnMouseWheel(P.box, 1) check(db.scale == 1.05, "wheel up " .. db.scale)
  for i = 1, 40 do P.box.scripts.OnMouseWheel(P.box, 1) end check(db.scale == 2, "wheel max")
  for i = 1, 60 do P.box.scripts.OnMouseWheel(P.box, -1) end check(db.scale == 0.5, "wheel min")
  check(P.box.scale == 0.5, "preview follows")

  -- click steps the sample color
  P.box.scripts.OnMouseDown(P.box) P.box.scripts.OnMouseUp(P.box)
  check(P.status == 3 and P.box.steps[1].value == 3, "next color")
  P.box.scripts.OnMouseDown(P.box) P.box.scripts.OnMouseUp(P.box)
  check(P.status == 0, "wraps")

  -- closing the page mid-drag lets go
  P.box.scripts.OnDragStart(P.box) P.frame.scripts.OnHide(P.frame)
  check(not P.Dragging(), "released on hide")
`);

scenario('blizzard look by default: nothing flattened', `
  T.plate("nameplate1")
  T.threat.nameplate1 = { tanking = false, status = 1, scaled = 50, raw = 50, lead = 0 }
  T.fire("PLAYER_ENTERING_WORLD")
  local box = T.box("nameplate1")
  check(box.shown and not box.flat and not box.panel, "untouched")
  check(box.bg.shown and box.border.atlas, "level box art kept")
  check(NS.Styles.Applied() == nil and db.style == "auto", "automatic comes to Blizzard")
  check(NS.report.skin and NS.report.skin:find("Blizzard"), "reported: " .. tostring(NS.report.skin))
`);

scenario('dark look: flat box, same threat colors', `
  T.plate("nameplate1")
  T.threat.nameplate1 = { tanking = false, status = 1, scaled = 50, raw = 50, lead = 0 }
  T.tick()
  local box = T.box("nameplate1")
  SlashCmdList.THREATBOX("style dark")
  check(db.style == "dark" and NS.Styles.Applied() == "dark", "dark drawn at once")
  check(box.flat and box.panel and not box.bg.shown, "art replaced by a panel")
  check(box.panel.bg.colorTexture and box.panel.bg.colorTexture[1] < 0.2, "dark panel")
  check(box.panel.level < box.fill.level and box.fill.level < box.face.level, "panel, meter, number")
  check(type(box.gate.fill) == "string" and box.gate.points[1].x == -3, "flat pulse, wider than the edge")
  check(box.fill.color[4] == 0.4, "meter in the accent color")
  check(box.text.parent == box.face, "number on the panel")
  check(box.border.texture and not box.border.atlas, "flat edge")
  for state, bar in ipairs(box.steps) do
    check(type(bar.fill) == "string", "flat fill " .. state)
    check(bar.value == 1 and bar.min == state - 1, "state still handed over " .. state)
    check(bar.color and bar.shown, "colored " .. state)
    check(bar.points[1].x == -1 and bar.points[1].y == 1 and #bar.points == 2, "one unit outside")
    check(bar.level < box.panel.level, "behind the panel")
  end
  check(box.steps[1].color[3] < 0.6 and box.steps[3].color[2] == 0, "threat colors kept")
  check(box.shown and box.text.text == "50%", "still showing")
  -- a nameplate that appears later is flat from the start
  T.plate("nameplate2")
  T.threat.nameplate2 = { secret = true, tanking = true, status = 3, scaled = 100, raw = 100, lead = 0 }
  T.tick()
  local late = T.box("nameplate2")
  check(late.flat and late.shown and issecretvalue(late.steps[3].value), "late box flat, secret state passed on")
  check(late.panel.level == late.level + 5, "panel level follows placement")
  -- the options preview follows
  SlashCmdList.THREATBOX("")
  local P = NS.Options.preview
  check(P.box.flat and P.flat, "preview flat")
  -- back to Blizzard needs a reload: the box stays flat, the note says so
  SlashCmdList.THREATBOX("style blizzard")
  check(db.style == "blizzard" and box.flat, "stays until a reload")
  check(NS.Styles.Note():find("reload"), "note asks for a reload")
`);

scenario('saved dark style is drawn at login', `
  T.plate("nameplate1")
  T.fire("PLAYER_ENTERING_WORLD")
  local box = T.box("nameplate1")
  check(NS.Styles.Applied() == "dark" and box.flat, "dark from the saved setting")
`, `ThreatBoxDB = { style = "dark" }`);

scenario('EllesmereUI look through its skin call', `
  check(T.euiSkinFor == "ThreatBox", "registered with EllesmereUI")
  T.plate("nameplate1")
  T.threat.nameplate1 = { tanking = false, status = 2, scaled = 95, raw = 95, lead = 0 }
  T.tick()
  T.euiSkinFn(T.euiFacade)
  local box = T.box("nameplate1")
  check(NS.Styles.Applied() == "eui", "its look in use")
  check(box.flat and box.panel.bg.colorTexture[2] == 0.2, "its panel color")
  check(T.euiCalls.font == box.text, "its font")
  check(box.shown and box.steps[2].value == 2, "threat unchanged")
  check(NS.report.skin:find("EllesmereUI"), "reported")
`, `T.ellesmere()`);

scenario('EllesmereUI running, Blizzard chosen: its skin call changes nothing', `
  T.euiSkinFn(T.euiFacade)
  check(NS.Styles.Applied() == nil, "Blizzard kept")
  T.plate("nameplate1")
  check(not T.box("nameplate1").flat, "not flattened")
`, `T.ellesmere() ThreatBoxDB = { style = "blizzard" }`);

scenario('EllesmereUI nameplates: follows its plate', `
  T.loaded = { EllesmereUINameplates = true }
  local plate = T.plate("nameplate1")
  local eui = T.euiPlate("nameplate1", true)
  T.threat.nameplate1 = { tanking = false, status = 1, scaled = 50, raw = 50, lead = 0 }
  T.tick()
  local box = T.box("nameplate1")
  check(box.shown, "shown")
  check(box.points[1].rel == eui._fvLevelBox and box.points[1].point == "TOPLEFT", "under its level box")
  check(box.h == 22 and box.w == 36 and box.level == 30, "sized and layered from its level box")
  NS.SetPosition("left")
  check(box.points[1].rel == eui.health, "left of its health bar")
  -- the game's own unit frame being hidden does not matter here
  plate.UnitFrame:Hide() T.tick() check(box.shown, "goes by its plate")
  eui:Hide() T.tick()
  check(not box.shown or box.points[1].rel ~= eui.health, "its plate gone: back to the game's")
  check(NS.report.euiPlates, "reported")

  -- a plate of its without a level box: the box takes the level box's place
  T.plate("nameplate2")
  local bare = T.euiPlate("nameplate2", false)
  T.threat.nameplate2 = T.threat.nameplate1
  NS.SetPosition("right") T.tick()
  local b2 = T.box("nameplate2")
  local p = b2.points[1]
  check(b2.shown and p.point == "LEFT" and p.rel == bare.health and p.relPoint == "RIGHT" and p.x == 5, "right of the bar")
  check(b2.h == 22 and b2.w == 36 and b2.level == 25, "sized from the bar")
  NS.SetPosition("below") p = b2.points[1]
  check(p.point == "TOPLEFT" and p.rel == bare.health and p.relPoint == "BOTTOMRIGHT", "below where the level box would be")
  NS.SetPosition("above") p = b2.points[1]
  check(p.point == "BOTTOMLEFT" and p.relPoint == "TOPRIGHT", "above")
`);

scenario('fill meter', `
  T.plate("nameplate1")
  T.threat.nameplate1 = { tanking = false, status = 1, scaled = 50, raw = 62, lead = 0 }
  T.tick()
  local box = T.box("nameplate1")
  check(box.fill.shown and box.fill.value == 50 and box.fill.min == 0 and box.fill.max == 100, "half full")
  db.number = "raw" NS.Apply()
  check(box.fill.value == 62 and box.fill.max == 130, "raw: full at the ranged pull point")
  db.number = "pull"
  T.threat.nameplate1 = { secret = true, tanking = false, status = 1, scaled = 70, raw = 70, lead = 0 }
  T.tick()
  check(issecretvalue(box.fill.value) and box.fill.shown, "a hidden percentage goes straight to the meter")
  SlashCmdList.THREATBOX("fill")
  check(db.fill == false and not box.fill.shown, "off")
`);

scenario('warning pulse', `
  T.plate("nameplate1")
  T.threat.nameplate1 = { tanking = false, status = 1, scaled = 85, raw = 100, lead = 0 }
  T.tick()
  local box = T.box("nameplate1")
  check(box.pulseAnim and box.pulseAnim.playing, "animation runs")
  check(box.pulse.shown and box.pulse.alpha == 1, "pulsing")
  check(box.gate.min == 79.5 and box.gate.max == 80 and box.gate.value == 85, "the game compares with 80")
  T.threat.nameplate1.scaled = 40 T.tick()
  check(box.gate.value == 40 and box.pulse.shown, "below 80 the gate is empty, by its range")
  SlashCmdList.THREATBOX("pulseat 60") check(db.warnAt == 60 and box.gate.max == 60, "threshold setting")
  -- once the enemy is on you the pulse rests
  T.threat.nameplate1 = { tanking = true, status = 3, scaled = 100, raw = 100, lead = 140 }
  T.tick() check(box.pulse.alpha == 0, "resting while it is on you")
  -- hidden values: both comparisons are the game's
  T.threat.nameplate1 = { secret = true, tanking = false, status = 1, scaled = 90, raw = 90, lead = 0 }
  T.tick()
  check(issecretvalue(box.gate.value) and box.pulse.alphaFromSecret and box.pulse.alpha == 1 and box.pulse.shown, "secret, not on you")
  T.threat.nameplate1.tanking = true T.tick()
  check(box.pulse.alphaFromSecret and box.pulse.alpha == 0, "secret, on you")
  -- tanks: any enemy that is not on them
  db.colors = "reversed" NS.Apply()
  check(box.gate.min == 0 and box.gate.value == 1 and box.pulse.alpha == 0, "tank holding it: quiet")
  T.threat.nameplate1 = { tanking = false, status = 0, scaled = 20, raw = 20, lead = 0 }
  T.tick() check(box.pulse.shown and box.pulse.alpha == 1 and box.gate.value == 1, "tank lost it: pulsing whatever the percent")
  SlashCmdList.THREATBOX("pulse") check(db.warn == false and not box.pulse.shown, "off")
`);

scenario('who has it: the name plaque', `
  T.plate("nameplate1")
  T.threat.nameplate1 = { tanking = false, status = 1, scaled = 50, raw = 50, lead = 0 }
  T.targets.nameplate1 = { name = "Brakka", isPlayer = true, class = "WARRIOR" }
  T.tick()
  local box = T.box("nameplate1")
  check(not box.who, "off by default: nothing made")
  SlashCmdList.THREATBOX("who")
  local who = box.who
  check(who and who.shown and who.text.text == "Brakka", "named")
  check(who.textColor == nil and who.text.textColor[1] == 0.78, "class color")
  check(who.w == 60 and who.h == box.h, "as tall as the box")
  check(who.points[1].point == "LEFT" and who.points[1].rel == box and who.points[1].relPoint == "RIGHT" and who.points[1].x == 5, "joined on the right")
  check(#who.bg.parts == 1 and who.bg.parts[1].atlas, "art stretched when its place in the file is unknown")
  NS.SetPosition("left")
  check(who.points[1].point == "RIGHT" and who.points[1].relPoint == "LEFT" and who.points[1].x == -5, "on the left when the box is left of the bar")
  T.targets.nameplate1 = { name = "Me", isYou = true } T.tick()
  check(not who.shown, "hidden when it is you")
  T.targets.nameplate1 = nil T.tick() check(not who.shown, "hidden with no target")
  T.targets.nameplate1 = { name = "Fang", isPet = true } T.tick()
  check(who.shown and who.text.text == "Fang" and who.text.textColor[3] == 1, "your pet, in the pet color")
  -- hidden identity: the name goes straight to the text, the game hides the plaque when it is you
  T.targets.nameplate1 = { name = "Hidden", secret = true } T.tick()
  check(who.shown and issecretvalue(who.text.text) and T.reveal(who.text.text) == "Hidden" and who.alphaFromSecret and who.alpha == 1, "secret: shown by the game")
  check(who.text.textColor[1] == 1 and who.text.textColor[2] == 1, "no color from hidden values")
  T.targets.nameplate1 = { name = "Me", secret = true, isYou = true } T.tick()
  check(who.alphaFromSecret and who.alpha == 0, "secret and it is you: faded out by the game")
  T.threat.nameplate1 = nil T.tick() check(not box.shown, "gone with the box")
`);

scenario('name plaque art in three pieces', `
  T.plate("nameplate1")
  T.threat.nameplate1 = { tanking = false, status = 1, scaled = 50, raw = 50, lead = 0 }
  T.targets.nameplate1 = { name = "Brakka", isPlayer = true, class = "WARRIOR" }
  db.who = true T.tick()
  local who = T.box("nameplate1").who
  check(#who.bg.parts == 3 and #who.ring.parts == 3, "three pieces each")
  local left, mid, right = who.bg.parts[1], who.bg.parts[2], who.bg.parts[3]
  check(left.texture == 777 and not left.atlas, "cut from the art's file")
  check(math.abs(left.texCoord[2] - 0.3) < 1e-9 and math.abs(mid.texCoord[1] - 0.3) < 1e-9 and math.abs(mid.texCoord[2] - 0.6) < 1e-9 and math.abs(right.texCoord[1] - 0.6) < 1e-9, "thirds")
  check(left.w == 18 / 3 and right.w == 18 / 3, "caps keep their shape")
  check(who.ring.parts[1].w == (18 + 7) / 3, "outline caps follow its own height")
  check(mid.points[1].rel == left and mid.points[2].rel == right, "middle stretches between the caps")
  check(who.ring.parts[2].color[1] == 0.69, "grey outline")
`, `C_Texture = { GetAtlasInfo = function(atlas) return { file = 777, leftTexCoord = 0, rightTexCoord = 0.9, topTexCoord = 0.1, bottomTexCoord = 0.5 } end }`);

scenario('pet threat', `
  T.plate("nameplate1")
  T.threat.nameplate1 = { tanking = false, status = 1, scaled = 50, raw = 50, lead = 0 }
  T.petThreat.nameplate1 = { tanking = true, status = 3, scaled = 100, raw = 100, lead = 0 }
  T.hasPet = true
  T.tick()
  local box = T.box("nameplate1")
  check(not box.pet, "off by default")
  SlashCmdList.THREATBOX("pet")
  local pet = box.pet
  check(pet and pet.shown and pet.text.text == "100%", "pet's number")
  check(pet.text.textColor[3] == 1 and pet.text.textColor[1] == 0.6, "in blue")
  check(pet.steps[3].value == 3, "pet's own threat color")
  check(not pet.pulse.shown, "the pet's box never pulses")
  check(pet.w == box.w and pet.h == box.h and pet.level == box.level, "same size and layer")
  check(pet.points[1].point == "LEFT" and pet.points[1].rel == box and pet.points[1].x == 5, "beside the box")
  -- with the name plaque: box, pet, plaque
  T.targets.nameplate1 = { name = "Fang", isPet = true }
  db.who = true NS.Apply()
  check(box.who.shown and box.who.points[1].rel == pet, "plaque after the pet's box")
  -- you are not on the list but your pet is
  T.threat.nameplate1 = nil T.tick()
  check(box.shown and box.text.text == "0%" and pet.shown, "your box reads 0 beside the pet's")
  T.petThreat.nameplate1 = { secret = true, tanking = false, status = 1, scaled = 30, raw = 30, lead = 0 }
  T.tick() check(pet.shown and pet.text.secretText and pet.text.text == "30%", "hidden pet threat passed on")
  T.petThreat.nameplate1 = nil T.tick()
  check(not box.shown, "neither on the list")
  T.petThreat.nameplate1 = { tanking = true, status = 3, scaled = 100, raw = 100, lead = 0 }
  T.hasPet = false T.tick() check(not box.shown, "no pet out")
`);

scenario('show rules', `
  T.plate("nameplate1") T.plate("nameplate2")
  local th = { tanking = false, status = 1, scaled = 50, raw = 50, lead = 0 }
  T.threat.nameplate1, T.threat.nameplate2 = th, th
  T.tick()
  local b1, b2 = T.box("nameplate1"), T.box("nameplate2")
  check(b1.shown and b2.shown, "no rules: both")
  SlashCmdList.THREATBOX("group") check(db.groupOnly and not b1.shown, "alone: hidden")
  T.grouped = true T.fire("GROUP_ROSTER_UPDATE") check(b1.shown, "in a group: shown")
  db.groupOnly = false
  SlashCmdList.THREATBOX("combat") check(db.combatOnly and not b1.shown, "out of combat: hidden")
  T.combatOn() check(b1.shown, "in combat: shown")
  T.combatOff() check(not b1.shown, "after combat: hidden")
  db.combatOnly = false
  SlashCmdList.THREATBOX("targetonly") check(not b1.shown and not b2.shown, "no target: none")
  T.targetUnit = "nameplate2" T.fire("PLAYER_TARGET_CHANGED")
  check(b2.shown and not b1.shown, "target only")
  T.focusUnit = "nameplate1" T.fire("PLAYER_FOCUS_CHANGED")
  check(b1.shown and b2.shown, "focus too")
  db.targetOnly = false
  T.units.nameplate1.trivial = true
  SlashCmdList.THREATBOX("trivial") check(not b1.shown and b2.shown, "trivial enemy skipped")
  -- the sample ignores the rules, so the box can be placed any time
  SlashCmdList.THREATBOX("test") check(b1.shown and b1.text.text == "87%", "sample shows anyway")
`);

scenario('aggro sound', `
  T.plate("nameplate1")
  T.threat.nameplate1 = { tanking = false, status = 1, scaled = 50, raw = 50, lead = 0 }
  T.tick()
  T.threat.nameplate1 = { tanking = true, status = 3, scaled = 100, raw = 100, lead = 120 }
  T.grouped = true T.tick()
  check(#T.sounds == 0, "off by default")
  T.threat.nameplate1.tanking = false T.tick()
  SlashCmdList.THREATBOX("sound")
  T.threat.nameplate1.tanking = true T.now = T.now + 5 T.tick()
  check(#T.sounds == 1 and T.sounds[1] == 12889, "you took it, in a group")
  T.tick() check(#T.sounds == 1, "once per change")
  -- alone, enemies are always on you
  T.grouped = false
  T.threat.nameplate1.tanking = false T.tick() T.threat.nameplate1.tanking = true T.now = T.now + 5 T.tick()
  check(#T.sounds == 1, "silent alone")
  -- hidden values: no change can be told, so nothing plays
  T.grouped = true
  T.threat.nameplate1 = { secret = true, tanking = false, status = 1, scaled = 50, raw = 50, lead = 0 }
  T.tick() T.threat.nameplate1.tanking = true T.now = T.now + 5 T.tick()
  check(#T.sounds == 1, "silent when hidden")
  -- a tank hears a loss, in combat
  T.setTank(true)
  T.threat.nameplate1 = { tanking = true, status = 3, scaled = 100, raw = 100, lead = 120 }
  T.tick() check(#T.sounds == 1, "a tank taking it is not news")
  T.threat.nameplate1.tanking = false T.now = T.now + 5 T.tick()
  check(#T.sounds == 1, "a loss out of combat is quiet")
  T.threat.nameplate1.tanking = true T.tick()
  T.combatOn()
  T.threat.nameplate1.tanking = false T.now = T.now + 5 T.tick()
  check(#T.sounds == 2, "tank lost it")
  -- two changes at once: one sound
  T.plate("nameplate2")
  T.threat.nameplate2 = { tanking = true, status = 3, scaled = 100, raw = 100, lead = 120 }
  T.threat.nameplate1.tanking = true T.tick()
  T.threat.nameplate1.tanking = false T.threat.nameplate2.tanking = false T.now = T.now + 5 T.tick()
  check(#T.sounds == 3, "throttled")
  -- a plate that left and came back does not count as a change
  T.fire("NAME_PLATE_UNIT_REMOVED", "nameplate1")
  T.threat.nameplate1.tanking = true
  T.fire("NAME_PLATE_UNIT_ADDED", "nameplate1") T.now = T.now + 5 T.tick()
  check(#T.sounds == 3, "fresh plate, no sound")
`);

scenario('dark look: plaque and pet box go flat too', `
  T.plate("nameplate1")
  T.threat.nameplate1 = { tanking = false, status = 1, scaled = 50, raw = 50, lead = 0 }
  T.petThreat.nameplate1 = { tanking = true, status = 3, scaled = 100, raw = 100, lead = 0 }
  T.targets.nameplate1 = { name = "Fang", isPet = true }
  T.hasPet = true
  db.who, db.pet = true, true
  T.tick()
  local box = T.box("nameplate1")
  SlashCmdList.THREATBOX("style dark")
  check(box.flat and box.pet.flat and box.who.flat, "all three")
  check(not box.who.bg.parts[1].shown and box.who.flatBg and box.who.edge, "plaque: flat panel and edge")
  check(box.who.flatBg.colorTexture[1] < 0.2 and box.who.edge.colorTexture[1] == 0.69, "plaque colors")
  check(box.pet.panel and box.pet.panel.level == box.pet.level + 5, "pet box panel")
  check(box.who.shown and box.pet.shown and box.who.points[1].rel == box.pet, "still in a row")
  -- made after the style is in use: flat from the start
  T.plate("nameplate2")
  T.threat.nameplate2 = T.threat.nameplate1 T.petThreat.nameplate2 = T.petThreat.nameplate1
  T.targets.nameplate2 = T.targets.nameplate1
  T.tick()
  local late = T.box("nameplate2")
  check(late.who.flat and late.pet.flat, "late ones flat")
`);

scenario('detached pet box and name plaque', `
  local plate = T.plate("nameplate1")
  local uf = plate.UnitFrame
  T.threat.nameplate1 = { tanking = false, status = 1, scaled = 50, raw = 50, lead = 0 }
  T.petThreat.nameplate1 = { tanking = true, status = 3, scaled = 100, raw = 100, lead = 0 }
  T.targets.nameplate1 = { name = "Fang", isPet = true }
  T.hasPet = true
  db.who, db.pet = true, true
  T.tick()
  local box = T.box("nameplate1")
  local pet, who = box.pet, box.who
  check(pet.points[1].rel == box and who.points[1].rel == pet, "in a row to start")

  SlashCmdList.THREATBOX("detach pet above")
  check(db.petDetached and db.petPosition == "above", "pet detached")
  local p = pet.points[1]
  check(#pet.points == 1 and p.point == "BOTTOMLEFT" and p.rel == uf.PlayerLevelDiffFrame and p.relPoint == "TOPLEFT", "pet above the level box, on its own")
  check(who.points[1].rel == box and who.points[1].point == "LEFT", "the plaque closes up to the box")
  check(pet.shown and pet.w == box.w, "still shown and sized")

  SlashCmdList.THREATBOX("detach who left")
  p = who.points[1]
  check(db.whoDetached and p.point == "TOPRIGHT" and p.rel == uf.HealthBarsContainer.healthBar, "plaque left of the health bar")
  db.whoX, db.whoY = 7, -2 NS.Apply() p = who.points[1]
  check(p.x == -5 + 7 and p.y == 3 - 2, "its own nudge")
  -- moving the threat box does not move detached pieces
  NS.SetPosition("right")
  check(box.points[1].point == "LEFT" and pet.points[1].point == "BOTTOMLEFT" and who.points[1].point == "TOPRIGHT", "independent of the box")
  SlashCmdList.THREATBOX("detach name") check(db.whoPosition == "left" and db.whoX == 0, "name is the plaque; re-pinning clears the nudge")

  SlashCmdList.THREATBOX("attach pet")
  check(not db.petDetached and pet.points[1].rel == box and pet.points[1].point == "LEFT", "pet back in the row")
  SlashCmdList.THREATBOX("attach who")
  check(who.points[1].rel == pet, "plaque back after the pet")
  local n = #T.printed
  SlashCmdList.THREATBOX("detach sideways") check(#T.printed == n + 1 and not db.petDetached, "bad piece: usage")
  SlashCmdList.THREATBOX("detach pet nowhere") check(not db.petDetached, "bad place refused")

  -- a nameplate of EllesmereUI's without a level box: detached pieces hang off the bar
  T.loaded = { EllesmereUINameplates = true } NS.euiNameplates = nil
  local eui = T.euiPlate("nameplate1", false)
  SlashCmdList.THREATBOX("detach pet above")
  p = pet.points[1]
  check(p.rel == eui.health and p.point == "BOTTOMLEFT" and p.relPoint == "TOPRIGHT", "pinned to its bar")
`);

scenario('options preview: dragging the pieces', `
  SlashCmdList.THREATBOX("")
  local P = NS.Options.preview
  db.who, db.pet = true, true NS.Apply()
  local pet, who = P.box.pet, P.box.who
  check(pet.scripts.OnDragStart and who.scripts.OnDragStart, "pieces take the mouse in the preview")
  check(pet.points[1].rel == P.box, "in the row")

  -- dragging a piece that is in the row does not move it
  T.cursor = { 500, 300 }
  pet.scripts.OnDragStart(pet)
  check(P.Dragging() and P.zoneLayer.shown, "areas show")
  T.cursor = { 530, 320 } P.DragUpdate()
  check(db.petX == 0 and db.petY == 0 and not db.petDetached, "still in the row")
  pet.scripts.OnDragStop(pet)
  check(not db.petDetached, "dropped nowhere: nothing changes")

  -- dropped on an area: on its own there
  P.zones.above.rect = { 600, 660, 400, 360 }
  pet.scripts.OnDragStart(pet)
  T.cursor = { 620, 380 } P.DragUpdate()
  pet.scripts.OnDragStop(pet)
  check(db.petDetached and db.petPosition == "above" and db.petX == 0, "detached above")
  check(pet.points[1].rel == P.level and who.points[1].rel == P.box, "preview follows; plaque closes up")
  check(db.position == "below" and db.offsetX == 0, "the threat box did not move")

  -- detached: a drag nudges it
  T.cursor = { 620, 380 }
  pet.scripts.OnDragStart(pet)
  T.cursor = { 628, 375 } P.DragUpdate()
  check(db.petX == 8 and db.petY == -5, "nudged " .. db.petX .. "/" .. db.petY)
  pet.scripts.OnDragStop(pet)
  check(db.petDetached and db.petPosition == "above" and db.petX == 8, "kept")

  -- dropped on the threat box: back in the row
  P.box.rect = { 300, 336, 250, 232 }
  pet.scripts.OnDragStart(pet)
  T.cursor = { 310, 240 } P.DragUpdate()
  pet.scripts.OnDragStop(pet)
  check(not db.petDetached and pet.points[1].rel == P.box, "rejoined")
  check(db.petX == 8, "its nudge is kept for next time it is detached by hand")

  -- the plaque, the same way; dragging the threat box onto itself does nothing special
  P.zones.left.rect = { 100, 150, 320, 280 }
  who.scripts.OnDragStart(who)
  T.cursor = { 120, 300 } P.DragUpdate() who.scripts.OnDragStop(who)
  check(db.whoDetached and db.whoPosition == "left", "plaque detached left")
  T.cursor = { 500, 300 }
  P.box.scripts.OnMouseDown(P.box) P.box.scripts.OnDragStart(P.box)
  T.cursor = { 310, 240 } P.DragUpdate() P.box.scripts.OnDragStop(P.box)
  check(db.position == "below" and db.whoDetached, "the box has no row to rejoin")
`);

scenario('each box has its own size', `
  local plate = T.plate("nameplate1", { ufScale = 0.8 })
  T.threat.nameplate1 = { tanking = false, status = 1, scaled = 50, raw = 50, lead = 0 }
  T.petThreat.nameplate1 = { tanking = true, status = 3, scaled = 100, raw = 100, lead = 0 }
  T.targets.nameplate1 = { name = "Fang", isPet = true }
  T.hasPet = true
  db.who, db.pet = true, true
  T.tick()
  local box = T.box("nameplate1")
  local pet, who = box.pet, box.who
  local function near(a, b) return math.abs(a - b) < 1e-9 end
  local base = plate:GetEffectiveScale() * 0.8 -- what 100% comes to on this nameplate
  check(near(box:GetEffectiveScale(), base) and near(pet:GetEffectiveScale(), base) and near(who:GetEffectiveScale(), base), "all 100% to start")

  SlashCmdList.THREATBOX("size 150")
  check(near(box:GetEffectiveScale(), base * 1.5), "threat box bigger")
  check(near(pet:GetEffectiveScale(), base) and near(who:GetEffectiveScale(), base), "the others keep their own size")

  SlashCmdList.THREATBOX("petsize 60")
  check(db.petScale == 0.6 and near(pet:GetEffectiveScale(), base * 0.6), "pet box smaller")
  check(near(box:GetEffectiveScale(), base * 1.5) and near(who:GetEffectiveScale(), base), "only the pet box")
  SlashCmdList.THREATBOX("targetsize 200")
  check(db.whoScale == 2 and near(who:GetEffectiveScale(), base * 2), "target box bigger")
  SlashCmdList.THREATBOX("whosize 900") check(db.whoScale == 2, "clamped")
  check(pet.w == box.w and pet.h == box.h, "same shape at its own scale")

  -- detached, each keeps its size
  SlashCmdList.THREATBOX("detach pet above")
  check(near(pet:GetEffectiveScale(), base * 0.6), "detached pet box keeps its size")
  SlashCmdList.THREATBOX("size 100")
  check(near(pet:GetEffectiveScale(), base * 0.6) and near(who:GetEffectiveScale(), base * 2), "unmoved by the threat box's size")

  -- by mouse wheel in the options preview
  SlashCmdList.THREATBOX("")
  local P = NS.Options.preview
  P.box.pet.scripts.OnMouseWheel(P.box.pet, 1) check(near(db.petScale, 0.65), "wheel on the pet box")
  P.box.who.scripts.OnMouseWheel(P.box.who, -1) check(near(db.whoScale, 1.95), "wheel on the target box")
  P.box.scripts.OnMouseWheel(P.box, 1) check(near(db.scale, 1.05) and near(db.petScale, 0.65), "wheel on the threat box")
  check(near(P.box.pet:GetEffectiveScale() / P.box:GetEffectiveScale(), 0.65 / 1.05), "preview follows")
`);

scenario('saved sizes out of range are repaired', `
  check(db.petScale == 1 and db.whoScale == 1 and db.scale == 1, "repaired")
`, `ThreatBoxDB = { petScale = 9, whoScale = 0.1, scale = 40 }`);

scenario('saved settings are repaired', `
  ThreatBoxDB = nil
`);
{
  // A broken saved table must not stop the load.
  try {
    const run = makeState();
    run(`
      ThreatBoxDB = { position = "nowhere", scale = 40, offsetX = "x", colorBorder = 1 }
      T.fire("ADDON_LOADED", "ThreatBox")
      local db = ThreatBoxDB
      assert(db.position == "below" and db.scale == 1 and db.offsetX == 0 and db.colorBorder == true)
      T.fire("ADDON_LOADED", "SomethingElse")
      T.fire("NAME_PLATE_UNIT_REMOVED", "nameplate9")
    `, '=repair');
    passed++;
  } catch (e) { failed++; failures.push('repair: ' + e.message); }
}

for (const f of failures) console.log('FAIL  ' + f);
console.log(`${passed} passed, ${failed} failed`);
process.exit(failed ? 1 : 0);
