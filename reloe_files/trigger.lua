function(allstates, event, ...)
    if event == "FRAME_UPDATE" then
        --blizzard pls add better events for proximity pulled mobs
        if not aura_env.last or aura_env.last < GetTime() - 0.5 then
            aura_env.last = GetTime()
            for guid, state in pairs(allstates) do
                if (state.expirationTime < aura_env.last)
                and (state.expirationTime < aura_env.last - 3) then
                    if aura_env.timer[guid] then
                        aura_env.timer[guid]:Cancel()
                        aura_env.timer[guid] = nil
                    end
                    state.show = false
                    state.changed = true
                    return true
                end
            end
            for _, plate in pairs(C_NamePlate.GetNamePlates()) do
                local unit = plate.namePlateUnitToken
                local guid = UnitGUID(unit)
                if guid then
                    local npcID = select(6, strsplit("-", guid))
                    if npcID
                    and npcID == "196576"
                    and UnitAffectingCombat(unit)
                    and not (aura_env.timer[guid] ~= nil or allstates[guid]) then
                        local mark = GetRaidTargetIndex(unit)
                        allstates[guid] = {
                            show = true,
                            changed = true,
                            progressType = "timed",
                            duration = 3.7,
                            expirationTime = 3.7 + GetTime(),
                            timer_refreshed = false,
                            mark = (mark and ICON_LIST[mark].."16|t") or "",
                        }
                        aura_env.timer[guid] = false
                        return true
                    end
                end
            end
        end
    elseif event == "COMBAT_LOG_EVENT_UNFILTERED" then
        local timestamp, subEvent, hideCaster, sourceGUID, sourceName, sourceFlags, sourceRaidFlags, destGUID, destName, destFlags, destRaidFlags, spellID = ...
        if subEvent == "SPELL_CAST_START" and spellID == 396812 then
            aura_env.timer[sourceGUID] = C_Timer.NewTimer(0, function() WeakAuras.ScanEvents("CAUSESE_TIMER", sourceGUID, spellID) end)
            local state = allstates[sourceGUID]
            if state then
                state.show = false
                state.changed = true
                return true
            end
        elseif subEvent == "UNIT_DIED" then
            if aura_env.timer[destGUID] then
                aura_env.timer[destGUID]:Cancel()
                aura_env.timer[destGUID] = nil
            end
            local state = allstates[destGUID]
            if state then
                state.show = false
                state.changed = true
                return true
            end
        end
    elseif event == "CAUSESE_TIMER" and ... then
        local guid, spellID = ...
        if spellID == 396812 then
            local unit = UnitTokenFromGUID(guid)
            if unit and UnitAffectingCombat(unit) then
                local mark = GetRaidTargetIndex(unit)
                allstates[guid] = {
                    show = true,
                    changed = true,
                    progressType = "timed",
                    duration = 23,
                    expirationTime = 23 + GetTime(),
                    timer_refreshed = true,
                    mark = (mark and ICON_LIST[mark].."16|t") or "",
                    autoHide = true,
                }
                return true
            end
        end
    elseif event == "CHALLENGE_MODE_START" then
        aura_env.timer = {}
    elseif event == "RAID_TARGET_UPDATE" then
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

