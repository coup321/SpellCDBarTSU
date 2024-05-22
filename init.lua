local EntryInfo = {}
EntryInfo.__index = EntryInfo
function EntryInfo:new(active, npcIdTable, spellId, cdFromCombatStart, cdAfterCast, spellEventType, iconOverrideBool, iconOverride, customBarTextBool, customBarText, tank, healer, melee, ranged)
    local instance = setmetatable({}, EntryInfo)
    instance.active = active
    instance.npcIdTable = npcIdTable
    instance.spellId = spellId
    instance.cdFromCombatStart = cdFromCombatStart
    instance.cdAfterCast = cdAfterCast
    instance.spellEventType = spellEventType
    instance.iconOverrideBool = iconOverrideBool
    instance.iconOverride = iconOverride
    instance.customBarBool = customBarTextBool
    instance.customBarText = customBarText
    instance.tank = tank
    instance.healer = healer
    instance.melee = melee
    instance.ranged = ranged
    return instance
end

function EntryInfo:fromConfigEntry(configEntry)
    local newSpellCdObjects = {}
    local spellIds = string.gmatch(configEntry.spellIds, "%d+")
    local npcIds = string.gmatch(configEntry.npcIds, "%d+")

    for _, spellId in pairs(spellIds) do
        local newSpellCd = SpellCD:new(
            configEntry.active,
            npcIds,
            tonumber(spellId),
            configEntry.cdFromCombatStart,
            configEntry.cdAfterCast,
            configEntry.spellEventType,
            configEntry.iconOverrideBool,
            configEntry.iconOverrideSpellId,
            configEntry.customBarTextBool,
            configEntry.customBarText,
            configEntry.tank,
            configEntry.healer,
            configEntry.ranged,
            configEntry.melee
            
        )
        table.insert(newSpellCdObjects, newSpellCd)
    end
    return newSpellCdObjects
end


aura_env.getSpellCdList = function()
    local spellCdList = {}
    for _, spellConfig in pairs(aura_env.config.spell) do
        local newSpellCdObjects = EntryInfo:fromConfigEntry(spellConfig)
        for _, spellCdObject in newSpellCdObjects do
            local spellId = spellConfig.spellId
            table.insert(aura_env.spellCdList, spellId, spellCdObject)
        end
    end
    return spellCdList
end

aura_env.trackedSpells = aura_env.getSpellCdList()
aura_env.activeBars = {}
aura_env.lastUpdate = 0

-- Spell CD Object


aura_env.addBar = function(spellCd, duration, guid, ...)
    aura_env.activeBars[guid] = true
    local unit = UnitTokenFromGUID(guid)
    local mark = unit and GetRaidTargetIndex(unit) or nil
    local spellName = GetSpellInfo(spellCd.spellId)

    local newState = {
        show = true,
        changed = true,
        autoHide = true,
        progressType = "timed",
        duration = duration,
        expirationTime = GetTime() + duration,
        name = spellCd.customBarTextBool and spellCd.customBarText or spellName,
        mark = (mark and ICON_LIST[mark].."16|t") or "",
        icon = iconFileId
    }

    return newState

end

aura_env.handleSpellCastStart = function(...)
    local spellId = select(13, ...)
    local sourceGuid = select(5, ...)
    if aura_env.trackedSpells[spellId] then
        local spellCd = aura_env.trackedSpells[spellId]
        local duration = spellCd.cdAfterCast
        local newStates = aura_env.addBar(spellCd, duration, sourceGuid)
        return newStates
    end
    return nil
end

aura_env.handleUnitSpellcastSucceeded = function(...)
    local unit = select(2, ...)
    local spellId = select(4, ...)
    local sourceGuid = UnitGUID(unit)
    if aura_env.trackedSpells[spellId] then
        local spellCd = aura_env.trackedSpells[spellId]
        local duration = spellCd.cdAfterCast
        local newStates = aura_env.addBar(spellCd, duration, sourceGuid)
        return newStates
    end
    return nil
end

aura_env.handleFrameUpdate = function()
    local currentTime = GetTime()
    local newStates = {}
    if (currentTime - aura_env.lastUpdate) > 0.5 then
        aura_env.last_update = currentTime
        for _, spellCd in pairs(aura_env.trackedSpells) do
            local guid, newState = aura_env.updateFromNameplates(spellCd)
                if guid and newState then
                    newStates[guid] = newState
                end
        end
    end
    return newStates
end
aura_env.updateFromNameplates = function(spellCd)
    for _, plate in pairs(C_NamePlate.GetNamePlates()) do
        local unit = plate.namePlateUnitToken
        local guid = UnitGUID(unit)
        local npcId = select(6, strsplit("-", guid))
        local isInCombat = UnitAffectingCombat(unit)
        local barDoesNOTExist = aura_env.activeBars[guid] == nil
        local npcIdIsInTargetIds = aura_env.getNpcIdMatchBool(npcId, spellCd)

        if guid and npcId and npcIdIsInTargetIds and isInCombat and barDoesNOTExist then
            local newState = aura_env.addBar(targetCdFromCombatStart, guid)
            return guid, newState
        end
    end
    return nil
end

aura_env.getNpcIdMatchBool = function(idToMatch, spellCd)
    local ids = spellCds.npcIdTable
    for _, id in pairs(ids) do
        if id == idToMatch then
            return true
        end
    end
    return false
end


aura_env.printEvents =  function(...)
    local args = {...}  -- Put all variable arguments into a table
    for i = 1, select('#', ...) do
        args[i] = '"' .. tostring(args[i]) .. '"'  -- Convert each argument to a string
    end

    local argsString = table.concat(args, " ")  -- Concatenate all elements with a comma and space as separator
    print(argsString)
end
