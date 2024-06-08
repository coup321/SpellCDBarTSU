local EntryInfo = {}
EntryInfo.__index = EntryInfo
function EntryInfo:new(config)
    local instance = setmetatable({}, EntryInfo)
    instance.config = config
    return instance
end

function EntryInfo:isActive()
    return self.config.active
end

function EntryInfo:containsNpc(npcIdToCheck)
    local npcIds = string.gmatch(self.config.npcIds, "%d+")
    for id in npcIds do
        if id == tostring(npcIdToCheck) then
            return true
        end
    end
    return false
end

function EntryInfo:spellInfo()
    local info = {}
    info["spellId"] = tonumber(self.config.spellId)
    info["cdFromCombatStart"] = tonumber(self.config.cdFromCombatStart)
    info["cdAfterCast"] = tonumber(self.config.cdAfterCast)
    info["spellEventType"] = self.config.spellEventType
    return info
end


function EntryInfo:spellId()
    return self.config.spellId
end

function EntryInfo:barInfo()
    local iconSpellId = self.config.iconOverrideBool and tonumber(self.config.iconOverrideSpellId) or tonumber(self.config.spellId)
    local spellName, _, _ = GetSpellInfo(self.config.spellId)
    local _, _, icon = GetSpellInfo(iconSpellId)
    local info = {}
    info["icon"] = icon
    info["text"] = self.config.customBarTextBool and self.config.customBarText or spellName
    info["category"] = self.config.category
    return info
end

function EntryInfo:roleInfo()
    local info = {}
    info["tank"] = self.config.tank
    info["healer"] = self.config.healer
    info["ranged"] = self.config.ranged
    info["melee"] = self.config.melee
    return info
end


function EntryInfo:allowCdFromStartOfCombat()
    return self.config.allowCdFromStartOfCombat
end


function EntryInfo:useSpellCastStart()
    return self.config.spellEventType == 1 -- "SPELL_CAST_START"

end

function EntryInfo:useUnitSpellcastSucceeded()
    return self.config.spellEventType == 2 -- UNIT_SPELLCAST_SUCCEEDED
end


function EntryInfo:roleOptions()
    return {
        ["TANK"] = self.config.tank,
        ["HEALER"] = self.config.healer,
        ["MELEE"] = self.config.melee,
        ["RANGED"] = self.config.ranged,
    }
end

function EntryInfo:showBarForPlayerRole()
    local roleOptions = self:roleOptions()
    local _, playerRole = WeakAuras.SpecRolePositionForUnit("player")
    return roleOptions[playerRole]
end

local function parseEntries()
    local entries = {}
    for _, entryConfig in pairs(aura_env.config.spells) do
        local spellId = entryConfig.spellId
        if #spellId > 0 then
            entries[tonumber(spellId)] = EntryInfo:new(entryConfig)
        end
    end  
    return entries
end

aura_env.entries = parseEntries()
aura_env.activeBars = {}
aura_env.lastUpdate = 0


aura_env.addBar = function(barInfo, spellId, duration, guid, isActive, entry)
    if not isActive or not entry:showBarForPlayerRole() then
        return {}
    end

    aura_env.activeBars[guid..spellId] = true
    local unit = UnitTokenFromGUID(guid)
    local mark = unit and GetRaidTargetIndex(unit) or nil

    local newState = {
        show = true,
        changed = true,
        autoHide = true,
        progressType = "timed",
        duration = duration,
        expirationTime = GetTime() + duration,
        name = barInfo.text,
        icon = barInfo.icon,
        mark = (mark and ICON_LIST[mark].."16|t") or "",
        category = barInfo.category,
        guid = guid
    }

    return newState

end

aura_env.handleSpellCastStart = function(...)
    local spellId = select(13, ...)
    local sourceGuid = select(5, ...)
    if aura_env.entries[spellId] then
        local entry = aura_env.entries[spellId]

        if not entry:useSpellCastStart() then
            return nil
        end

        local isActive = entry:isActive()
        local spellInfo = entry:spellInfo()
        local barInfo = entry:barInfo()
        local duration = spellInfo.cdAfterCast
        local newState = aura_env.addBar(barInfo, spellId, duration, sourceGuid, isActive, entry)
        return newState
    end
    return nil
end

aura_env.handleUnitSpellcastSucceeded = function(...)
    local unit = select(2, ...)
    local spellId = select(4, ...)
    local sourceGuid = UnitGUID(unit)
    if aura_env.entries[spellId] then
        local entry = aura_env.entries[spellId]

        if not entry:useUnitSpellcastSucceeded() then
            return nil
        end

        local isActive = entry:isActive()
        local spellInfo = entry:spellInfo()
        local barInfo = entry:barInfo()
        local duration = spellInfo.cdAfterCast
        local newState = aura_env.addBar(barInfo, spellId, duration, sourceGuid, isActive, entry)
        return newState
    end
    return nil
end

aura_env.handleFrameUpdate = function()
    local currentTime = GetTime()
    local newStates = {}
    if (currentTime - aura_env.lastUpdate) > 0.5 then
        aura_env.last_update = currentTime
        for spellId, entry in pairs(aura_env.entries) do
            local guid, newState = aura_env.updateFromNameplates(entry, spellId)
            if guid and newState and entry:allowCdFromStartOfCombat() then
                newStates[guid..spellId] = newState
            end
        end
    end
    return newStates
end
aura_env.updateFromNameplates = function(entry, spellId)
    for _, nameplate in pairs(C_NamePlate.GetNamePlates()) do
        local unit = nameplate.namePlateUnitToken
        local guid = UnitGUID(unit)
        local npcId = select(6, strsplit("-", guid))
        local isInCombat = UnitAffectingCombat(unit)
        local barDoesNOTExist = aura_env.activeBars[guid..spellId] == nil
        local npcIdIsInTargetIds = entry:containsNpc(npcId) 

        if guid and npcId and npcIdIsInTargetIds and isInCombat and barDoesNOTExist then
            local barInfo = entry:barInfo()
            local spellInfo = entry:spellInfo()
            local duration = spellInfo.cdFromCombatStart
            local isActive = entry:isActive()
            local newState = aura_env.addBar(barInfo, spellId, duration, guid, isActive, entry)
            return guid, newState
        end
    end
    return nil
end

aura_env.printEvents =  function(...)
    local args = {...}  -- Put all variable arguments into a table
    for i = 1, select('#', ...) do
        args[i] = '"' .. tostring(args[i]) .. '"'  -- Convert each argument to a string
    end

    local argsString = table.concat(args, " ")  -- Concatenate all elements with a comma and space as separator
    print(argsString)
end
