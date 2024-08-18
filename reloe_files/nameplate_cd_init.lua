aura_env.spells = {}
aura_env.nameplates = {}
aura_env.guids = {}
aura_env.temp = {}
aura_env.units = {}
aura_env.progtime = {}
aura_env.proglast = {}
aura_env.last = {}

for _, v in ipairs(aura_env.config.spells) do -- converting spells from custom options
    if v.spellID ~= 0 then
        if v.active then
            aura_env.spells[v.spellID] = {active= v.active, icon = select(3, GetSpellInfo(v.spellID)), duration = v.duration, intduration = v.intduration, onstart = v.casttype == 1, onsuccess = v.casttype == 2, tank = v.tank, heal = v.heal, mdps = v.mdps, rdps = v.rdps, hide = v.hideafter, overwrite = v.overwrite, npcID = v.npcID, oncombat = v.oncombat, combattimer = v.combattimer, loop = v.loop, progressive = v.progressive, repeating = v.repeating, other = 0, npcIDoffset = v.npcIDoffset, offsetnum = v.offsetnum, offset = 0, desynch = v.desynch}
            if v.npcIDoffset ~= "" and v.offsetnum ~= "" then
                aura_env.spells[v.spellID].offset = {}
                local nilcheck, i = true, 1
                while nilcheck do
                    local timer = select(i, strsplit(" ", v.offsetnum))
                    timer = tonumber(timer)
                    local npcID = select(i, strsplit(" ", v.npcIDoffset))
                    if npcID then
                        aura_env.spells[v.spellID].offset[npcID] = timer
                        if not aura_env.spells[v.spellID].offset[npcID] then
                            nilcheck = false
                            aura_env.spells[v.spellID].offset[npcID] = nil
                        end
                    else
                        nilcheck = false
                    end
                    i = i+1
                end
            end
            if v.spelltrigger ~= "0" and v.spelltrigger ~= "" then
                aura_env.spells[v.spellID].other = {}
                local nilcheck, i = true, 1
                while nilcheck do
                    local timer = select(i, strsplit(" ", v.spelltimer))
                    timer = tonumber(timer)
                    local sid = select(i, strsplit(" ", v.spelltrigger)) or 0
                    sid = tonumber(sid)
                    aura_env.spells[v.spellID].other[sid] = timer
                    if not aura_env.spells[v.spellID].other[sid] then
                        nilcheck = false
                        aura_env.spells[v.spellID].other[sid] = nil
                    end
                    i = i+1
                end
            end
            if v.progressive ~= "0" and v.progressive ~= "" then
                aura_env.spells[v.spellID].progressive = {}
                local nilcheck, i = true, 1
                while nilcheck do
                    local timer = select(i, strsplit(" ", v.progressive))
                    timer = tonumber(timer)
                    aura_env.spells[v.spellID].progressive[i] = timer
                    if not aura_env.spells[v.spellID].progressive[i] then
                        nilcheck = false
                        aura_env.spells[v.spellID].progressive[i] = nil
                    end
                    i=i+1
                end
            end
        end
    end
end





-- checking for role
aura_env.rolecheck = function(spell)
    local spec, role, pos = WeakAuras.SpecRolePositionForUnit("player")
    return (role ~= "TANK" and spell.mdps and (pos == "MELEE" or spec == 105)) or (pos == "RANGED" and spell.rdps) or (role == "TANK" and spell.tank) or (role == "HEALER" and spell.heal)
end


aura_env.bossunit = function(GUID)
    for i=1, 10 do
        if not UnitExists("boss"..i) then break end
        if GUID == UnitGUID("boss"..i) then
            return true
        end
    end
    return false
end


-- spell_interrupt
aura_env.oninterrupt = function(spellID, GUID)
    local spell, key = aura_env.spells[spellID], GUID..spellID
    if spell
    and spell.intduration > 0
    and aura_env.rolecheck(spell)
    and ((not aura_env.last[key]) or GetTime() > aura_env.last[key]+0.1) then 
        aura_env.last[key] = GetTime()
        WeakAuras.ScanEvents("RELOE_SPELLCD_STATE_UPDATE", spell, GUID, spellID, spell.intduration, false, false, 0, GUID..spellID)
    end
end

-- spell_cast_start / unit_spellcast_start
aura_env.onstart = function(spellID, GUID, name)
    local spell, key = aura_env.spells[spellID], GUID..spellID
    local npcID = select(6, strsplit("-", GUID))
    if spell
    and spell.onstart 
    and ((not aura_env.last[key]) or GetTime() > aura_env.last[key]+0.1) then
        aura_env.last[key] = GetTime()
        local count, duration = -1, aura_env.rolecheck(spell) and spell.duration
        if type(spell.other) == "table" then
            for k, v in pairs(spell.other) do
                local spello = aura_env.spells[k] or spell
                local active = aura_env.spells[k] and aura_env.spells[k].active
                if active then
                    WeakAuras.ScanEvents("RELOE_SPELLCD_STATE_UPDATE", spello, GUID, k, v, false, false, 0, GUID..k)
                end
            end
        end
        if type(spell.progressive) == "table" then
            duration, count = aura_env.getprogressivetimer(spell, spellID, GUID, duration, key)
        end
        if duration then
            duration = type(spell.offset) == "table" and spell.offset[npcID] or duration
            WeakAuras.ScanEvents("RELOE_SPELLCD_STATE_UPDATE", spell, GUID, spellID, duration, false, false, count+1, key)
        end
        if spell.desynch ~= 0 then
            WeakAuras.ScanEvents("RELOE_SPELLCD_DESYNCH", spell, spellID, GUID, spell.desynch)
        end
    end
end

-- spell_cast_success / unit_spellcast_succeeded
aura_env.onsuccess = function(spellID, GUID, name, CLEU)
    local spell, key = aura_env.spells[spellID], GUID..spellID
    local npcID = select(6, strsplit("-", GUID))
    if spell
    and spell.onsuccess 
    and ((not aura_env.last[key]) or GetTime() > aura_env.last[key]+0.1)
    then 
        aura_env.last[key] = GetTime()
        local count, duration = -1, aura_env.rolecheck(spell) and aura_env.spells[spellID].duration
        if type(spell.other) == "table" then
            for k, v in pairs(spell.other) do
                local spello = aura_env.spells[k] or spell
                local active = aura_env.spells[k] and aura_env.spells[k].active
                if active then
                    WeakAuras.ScanEvents("RELOE_SPELLCD_STATE_UPDATE", spello, GUID, k, v, false, false, 0, GUID..k)
                end
            end
        end
        if duration and type(spell.progressive) == "table" then
            duration, count = aura_env.getprogressivetimer(spell, spellID, GUID, duration, key)
        end
        if duration then
            duration = type(spell.offset) == "table" and spell.offset[npcID] or duration
            WeakAuras.ScanEvents("RELOE_SPELLCD_STATE_UPDATE", spell, GUID, spellID, duration, false, true, count+1, key)
        end
    end
end


aura_env.oncombat = function(spellID, GUID)
    local spell = aura_env.spells[spellID]
    if spell
    and spell.oncombat 
    and aura_env.rolecheck(spell) then
        WeakAuras.ScanEvents("RELOE_SPELLCD_STATE_UPDATE", spell, GUID, spellID, spell.combattimer, true, spell.onsuccess, 0, GUID..spellID)
    end
end


aura_env.getprogressivetimer = function(spell, spellID, GUID, duration, key)
    if not aura_env.progtime[key] then
        aura_env.progtime[key] = 1
    else
        aura_env.progtime[key] = aura_env.progtime[key]+1
    end
    local timer = -1
    if aura_env.progtime[key] > #spell.progressive  then
        if spell.repeating then
            aura_env.progtime[key] = 1
            timer = spell.progressive[1]
        else
            for i=1, #spell.progressive do
                timer = (spell.progressive[i] and (spell.progressive[i] < timer or timer == 0) and spell.progressive[i])  or timer
            end
        end
    else
        timer = spell.progressive[aura_env.progtime[key]]
    end
    if timer and timer ~= -1 then
        return tonumber(timer), aura_env.progtime[key]
    else
        return duration, -1
    end
end







