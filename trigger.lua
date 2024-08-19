function(allstates, ...)
    local event = select(1, ...)
    local subEvent = select(3, ...)

    if event == "FRAME_UPDATE"  then
        local newStates = aura_env.handleFrameUpdate()
        for guid_spellId, state in pairs(newStates) do
            allstates[guid_spellId] = state 
        end
        return true
    end

    if subEvent == "SPELL_CAST_START"  then
        local sourceGuid = select(5, ...) 
        local spellId = select(13, ...)
        local newState = aura_env.handleSpellCastStart(...)
        if sourceGuid and newState then
            allstates[sourceGuid..spellId] = newState
            return true
        end
    end

    if event == "UNIT_SPELLCAST_SUCCEEDED"  then
        local unit = select(2, ...)
        local guid = UnitGUID(unit)
        local spellId = select(4, ...)
        local newState = aura_env.handleUnitSpellcastSucceeded(...)
        if guid and newState then
            allstates[guid..spellId] = newState
            return true
        end
    end

    if subEvent == "UNIT_DIED" then
        local sourceGuid = select(9, ...)
        local pattern = sourceGuid:gsub("%-", "%%-")
        for guid_spellId, _ in pairs(allstates) do
            if string.find(guid_spellId, pattern) then
                allstates[guid_spellId] = {changed=true, show=false}
                aura_env.activeBars[guid_spellId] = nil
            end
        end
        return true
    end
    
    if event == "CHALLENGE_MODE_START" then
        aura_env.activeBars = {}
    end

    if event == "RAID_TARGET_UPDATE" then
        for _, state in pairs(allstates) do
            local unit = UnitTokenFromGUID(state.guid)
            if unit then
                local mark = GetRaidTargetIndex(unit)
                state.mark = mark and ICON_LIST[mark].."16|t" or ""
                state.changed = true
            end
        end
        return true
    end
end