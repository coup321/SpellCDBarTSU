function(allstates, ...)
    local event = select(1, ...)
    local subEvent = select(3, ...)

    if event == "FRAME_UPDATE" and aura_env.config.allowCdFromStartOfCombat then
        local guid, newState = aura_env.handleFrameUpdate()
        if guid and newState then
            allstates[guid] = newState
            return true
        end
    end

    if subEvent == "SPELL_CAST_START" and aura_env.config.useSpellCastStart then
        local sourceGuid = select(5, ...) 
        local newState = aura_env.handleSpellCastStart(...)
        allstates[sourceGuid] = newState
        return true
    end
    if event == "UNIT_SPELLCAST_SUCCEEDED" and aura_env.config.useUnitSpellcastSucceeded then
        local unit = select(2, ...)
        local guid = UnitGUID(unit)
        local newState = aura_env.handleUnitSpellcastSucceeded(...)
        if guid and newState then
            allstates[guid] = newState
            return true
        end
    end

    if subEvent == "UNIT_DIED" then
        local sourceGuid = select(9, ...)
        allstates[sourceGuid] = {changed=true, show=false}
        aura_env.activeBars[sourceGuid] = nil
        return true
    end
    
    if event == "CHALLENGE_MODE_START" then
        aura_env.activeBars = {}
    end

    if event == "RAID_TARGET_UPDATE" then
        for guid, state in pairs(allstates) do
            local unit = UnitTokenFromGUID(guid)
            if unit then
                local mark = GetRaidTargetIndex(unit)
                state.mark = (mark and ICON_LIST[mark].."16|t") or ""
                state.changed = true
            end
        end
        return true
    end
end