--
-- Created by IntelliJ IDEA.
-- User: srobi
-- Date: 8/13/2016
-- Time: 9:51 PM
--


local _G = getfenv(0)
local LibStub = _G.LibStub

local MAJOR = "LibFeralBleeds-1.0"
_G.assert(LibStub, MAJOR .. " requires LibStub")
local MINOR = 1 --Should be manually increased

local LibFeralBleeds = LibStub:NewLibrary(MAJOR, MINOR)
if not LibFeralBleeds then
    return
end --No upgrade needed

local CreateFrame, UnitBuff, UnitGUID, GetSpecialization, GetSpecializationInfo, GetSpellInfo, GetTalentInfo = CreateFrame, UnitBuff, UnitGUID, GetSpecialization, GetSpecializationInfo, GetSpellInfo, GetTalentInfo
local Frame = CreateFrame("Frame")
local PlayerGUID = UnitGUID("player")
local Events = {}
local Rake = string.lower(GetSpellInfo(155722))
local Moonfire = string.lower(GetSpellInfo(155625))
local Rip = string.lower(GetSpellInfo(1079))
local SavageRoar = string.lower(GetSpellInfo(52610))
local TigersFury = string.lower(GetSpellInfo(5217))
local BloodTalons = string.lower(GetSpellInfo(145152))
local Prowl = string.lower(GetSpellInfo(5215))
local Incarnation = string.lower(GetSpellInfo(102543))
local Thrash = string.lower(GetSpellInfo(106830))
local LibAuraTracker = LibStub("LibAuraTracker-1.0")
local Tracker = LibAuraTracker:New()
local Bleeds = {
    [Rake] = 155722, --Rake
    [Rip] = 1079, --Rip
    [Thrash] = 106830 --Thrash
}

local Buffs = {
    [SavageRoar] = 52610, --Savage Roar
    [TigersFury] = 5217, --Tiger's Fury
    [BloodTalons] = 145152, --Bloodtalons
    [Prowl] = 5215 --Prowl
}
local BuffModifiers = {
    [SavageRoar] = 25, --Savage Roar
    [TigersFury] = 15, --Tiger's Fury
    [BloodTalons] = 40 --Bloodtalons
}
local BleedModifiers = {}
local function GetBleedModifier(bleedName, prowlFlag)
    local modifier = 0
    for buffName, buffModifier in pairs(BuffModifiers) do
        if UnitBuff("player", buffName, nil, "PLAYER HELPFUl") and not (bleedName == Moonfire and buffName == BloodTalons) then
            modifier = modifier + buffModifier
        end
    end
    if bleedName == Rake then
        modifier = (prowlFlag or UnitBuff("player", Prowl) or UnitBuff("player", Incarnation)) and modifier + 100 or modifier
    end

    return modifier
end

setmetatable(BleedModifiers, {
    __index = function(BleedModifiers, spellName)
        if Bleeds[spellName] then
            BleedModifiers[spellName] = GetBleedModifier(spellName)
            return BleedModifiers[spellName]
        end
    end
})

local function CheckSpec()
    PlayerGUID = UnitGUID("player")
    local specIndex = GetSpecializationInfo(GetSpecialization())
    if specIndex == 103 then
        --Incarnation: King of the Jungle
        if select(4, GetTalentInfo(5, 2, 1)) then
            Buffs[Incarnation] = 102543
        end
        -- Lunar Inspiration
        if select(4, GetTalentInfo(1, 3, 1)) then
            Bleeds[Moonfire] = 155625 -- Moonfire
        end
        Tracker:Track(Bleeds, "PLAYER HARMFUL"):Track(Buffs, "PLAYER HELPFUL")
        Frame:RegisterEvent("COMBAT_LOG_EVENT_UNFILTERED");
    else
        Tracker:Wipe()
        Frame:UnregisterEvent("COMBAT_LOG_EVENT_UNFILTERED");
    end
end

function Events:PLAYER_SPECIALIZATION_CHANGED()
    CheckSpec()
end

function Events:PLAYER_ENTERING_WORLD()
    CheckSpec()
end

function Events:COMBAT_LOG_EVENT_UNFILTERED(...)
    local _, combatEventType, _, sourceGUID, _, _, _, destGUID, _, _, _, spellID, spellName = ...

    if sourceGUID == PlayerGUID then
        spellName = string.lower(tostring(spellName))
        if Bleeds[spellName] and (combatEventType == "SPELL_CAST_START" or combatEventType == "SPELL_AURA_APPLIED" or combatEventType == "SPELL_AURA_REFRESH" or (combatEventType == "SPELL_PERIODIC_DAMAGE" and not (Tracker:GetInfo(destGUID, spellID, sourceGUID) or {}).bleedStrength)) then

            if spellName == Rake and spellID ~= Bleeds[Rake] then
                BleedModifiers[Rake] = GetBleedModifier(Rake, true)
            end
            Tracker:SetInfo(destGUID, spellID, { bleedStrength = BleedModifiers[spellName] }, sourceGUID)
        elseif BuffModifiers[spellName] and (combatEventType == "SPELL_AURA_APPLIED" or combatEventType == "SPELL_AURA_REMOVED") then
            for bleedName in pairs(Bleeds) do
                BleedModifiers[bleedName] = GetBleedModifier(bleedName)
            end
        elseif spellID == 102543 and (combatEventType == "SPELL_AURA_APPLIED" or combatEventType == "SPELL_AURA_REMOVED") then
            BleedModifiers[Rake] = GetBleedModifier(Rake)
        end
    end
end

--- Get the current power of a particular bleed on a target if it exists
-- @param unit Unit to check
-- @param bleed Bleed aura name or spell id
function LibFeralBleeds.CurrentBleedPower(unit, bleed)
    local currentPower = Tracker:GetInfo(unit, bleed, PlayerGUID)
    return currentPower and currentPower.bleedStrength or 0
end

--- Get the power that a new bleed would have
-- @param bleed Bleed aura name or spell id
function LibFeralBleeds.NewBleedPower(bleed)
    local bleedName = bleed
    if type(bleed) == "number" then
        bleedName = string.lower(GetSpellInfo(bleed))
    end
    return bleedName and BleedModifiers[bleedName] or 0
end

--- Get the relative power of applying a new bleed vs the current existing one on the specified unit, if any exists.
-- @param unit Unit to check
-- @param bleed Bleed aura name or spell id
-- @usage
-- RipPower = LibFeralBleeds.BleedPower("target", "Rip")
function LibFeralBleeds.BleedPower(unit, bleed)
    return LibFeralBleeds.NewBleedPower(bleed) - LibFeralBleeds.CurrentBleedPower(unit, bleed)
end



Frame:SetScript("OnEvent", function(self, event, ...)
    Events[event](self, ...);
end);

Frame:RegisterEvent("PLAYER_SPECIALIZATION_CHANGED");
Frame:RegisterEvent("PLAYER_ENTERING_WORLD");
