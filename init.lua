local targetSpellId = tonumber(aura_env.config.targetSpellId)
local targetCdFromCombatStart = tonumber(aura_env.config.targetCdFromCombatStart)
local targetCdAfterCast = tonumber(aura_env.config.targetCdAfterCast)
local targetNpcId = aura_env.config.targetNpcId
local customBarText = aura_env.config.customBarText
local spellName, _ ,iconFileId = GetSpellInfo(tostring(targetSpellId))



aura_env.activeBars = {}
aura_env.lastUpdate = 0

aura_env.addBar = function(duration, guid, ...)
    aura_env.activeBars[guid] = true
    local unit = UnitTokenFromGUID(guid)
    local mark = unit and GetRaidTargetIndex(unit) or nil

    local newState = {
        show = true,
        changed = true,
        autoHide = true,
        progressType = "timed",
        duration = duration,
        expirationTime = GetTime() + duration,
        name = customBarText and customBarText or spellName,
        mark = (mark and ICON_LIST[mark].."16|t") or "",
        icon = iconFileId
    }

    return newState

end

aura_env.handleSpellCastStart = function(...)
    local spellId = select(13, ...)
    local sourceGuid = select(5, ...)
    if spellId == targetSpellId then
        local newStates = aura_env.addBar(targetCdAfterCast, sourceGuid)
        return newStates
    end
    return nil
end

aura_env.handleUnitSpellcastSucceeded = function(...)
    local unit = select(2, ...)
    local spellId = select(4, ...)
    local guid = UnitGUID(unit)
    if spellId == targetSpellId then
        local newState = aura_env.addBar(targetCdAfterCast, guid)
        return newState
    end
    return nil
end

aura_env.handleFrameUpdate = function()
    local currentTime = GetTime()
    if (currentTime - aura_env.lastUpdate) > 0.5 then
        aura_env.last_update = currentTime
        local guid, newState = aura_env.updateFromNameplates()
        if guid and newState then
            return guid, newState
        end
    end
    return nil, nil
end
aura_env.updateFromNameplates = function()
    for _, plate in pairs(C_NamePlate.GetNamePlates()) do
        local unit = plate.namePlateUnitToken
        local guid = UnitGUID(unit)
        local npcId = select(6, strsplit("-", guid))
        local isInCombat = UnitAffectingCombat(unit)
        local barDoesNOTExist = aura_env.activeBars[guid] == nil
        local npcIdIsInTargetIds = aura_env.getNpcIdMatchBool(npcId, aura_env.config.targetNpcId)

        if guid and npcId and npcIdIsInTargetIds and isInCombat and barDoesNOTExist then
            local newState = aura_env.addBar(targetCdFromCombatStart, guid)
            return guid, newState
        end
    end
    return nil
end

aura_env.getNpcIdMatchBool = function(idToMatch, targetNpcId)
    local ids = aura_env.getNpcIdTableFromString(targetNpcId)

    for _, id in pairs(ids) do
        if id == idToMatch then
            return true
        end
    end
    return false
end

aura_env.getNpcIdTableFromString = function(idConfigString)
    local ids = {}
    for id in string.gmatch(idConfigString, "%d+") do
        table.insert(ids, id)
    end
    return ids
end

aura_env.printEvents =  function(...)
    local args = {...}  -- Put all variable arguments into a table
    for i = 1, select('#', ...) do
        args[i] = '"' .. tostring(args[i]) .. '"'  -- Convert each argument to a string
    end

    local argsString = table.concat(args, " ")  -- Concatenate all elements with a comma and space as separator
    print(argsString)
end
