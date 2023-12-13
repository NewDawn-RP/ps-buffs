local playerBuffs = {}
local next = next

--- Adds a buff to player
--- @param identifier string - Player identifier
--- @param buffName string - Name of the buff
--- @param time number | nil - Optional time to add or how long you want buff to be
--- @return bool
local function AddBuff(sourceID, identifier, buffName, time)
    local buffData = Config.Buffs[buffName]
    -- Check if we were given a correct buff name
    if buffData == nil then
        return false
    end

    if not sourceID then 
        return false 
    end

    -- If the player had no buffs at all then add them to the table
    if not playerBuffs[identifier] then
        playerBuffs[identifier] = {}
    end

    local maxTime = buffData.maxTime

    -- If the player didnt already have the buff requested set it to time or maxTime
    if not playerBuffs[identifier][buffName] then
        local buffTime = maxTime
        if time then
            buffTime = time
        end
        
        playerBuffs[identifier][buffName] = buffTime
        
        -- Since the player didnt already have this buff tell the front end to show it
        if buffData.type == 'buff' then
            -- Call client event to send nui to front end to start showing buff
            TriggerClientEvent('hud:client:BuffEffect', sourceID, {
                buffName = buffName,
                display = true,
                iconName = buffData.iconName,
                iconColor = buffData.iconColor,
                progressColor = buffData.progressColor,
                progressValue = (buffTime * 100) / buffData.maxTime,
            })
        else
            -- Call client event to send nui to front end to start showing enhancement
            TriggerClientEvent('hud:client:EnhancementEffect', sourceID, {
                display = true,    
                enhancementName = buffName,
                iconColor = buffData.iconColor
            })
        end

    else
        -- Since the player already had a buff increase the buff time, but not higher than max buff time
        local newTime = playerBuffs[identifier][buffName] + time
        
        if newTime > maxTime then
            newTime = maxTime
        end
        
        playerBuffs[identifier][buffName] = newTime
    end

    return true
end 
exports('AddBuff', AddBuff)

--- Removes a buff from provided player
--- @param identifier string - Player identifier
--- @param buffName string - Name of the buff
--- @return bool - Success of removing the player buff
local function RemoveBuff(identifier, buffName)
    local buffData = Config.Buffs[buffName]
    if playerBuffs[identifier] and playerBuffs[identifier][buffName] then
        
        playerBuffs[identifier][buffName] = nil

        local xPlayer = ESX.GetPlayerFromIdentifier(identifier)

        if not xPlayer then return end

        -- Check if player is online
        if sourceID then
            -- Send a nui call to front end to stop showing icon
            if buffData.type == 'buff' then
                -- Call client event to send nui to front end to stop showing buff
                TriggerClientEvent('hud:client:BuffEffect', xPlayer.source, {
                    display = false,
                    buffName = buffName,
                })
            else
                -- Call client event to send nui to front end to stop showing enhancement
                TriggerClientEvent('hud:client:EnhancementEffect', xPlayer.source, {
                    display = false,    
                    enhancementName = buffName,
                })
            end
        end

        -- Check to see if that was the player's last buff
        -- If so, then remove the player from the table to ensure we dont loop them
        if next(playerBuffs[identifier]) == nil then
            playerBuffs[identifier] = nil
        end

        return true
    end

    return false
end 
exports('RemoveBuff', RemoveBuff)

--- Method to fetch if player has buff with name and is not nil
--- @param identifier string - Player identifier
--- @param buffName string - Name of the buff
--- @return bool
local function HasBuff(identifier, buffName)
    if playerBuffs[identifier] then
        return playerBuffs[identifier][buffName] ~= nil
    end

    return false
end
exports('HasBuff', HasBuff)

lib.callback.register('buffs:server:fetchBuffs', function(source)
    local xPlayer = ESX.GetPlayerFromId(source)
    local identifier = xPlayer.identifier
    return playerBuffs[identifier]
end)

lib.callback.register('buffs:server:addBuff', function(source, buffName, time)
    local xPlayer = ESX.GetPlayerFromId(source)
    local identifier = xPlayer.identifier
    return AddBuff(xPlayer.source, identifier, buffName, time)
end)

CreateThread(function()
    local function DecrementBuff(sourceID, identifier, buffName, currentTime)
        local buffData = Config.Buffs[buffName]
        local updatedTime = currentTime - Config.TickTime

        -- Buff ran out of time we need to remove it from the player
        if updatedTime <= 0 then
            -- Only need to update buffs since they show progress on client
            if buffData.type == 'buff' then
                -- Check if player is online
                if sourceID then
                    -- Call client event to send nui to front end, progress at 0
                    TriggerClientEvent('hud:client:BuffEffect', sourceID, {
                        buffName = buffName,
                        progressValue = 0,
                    })
                end
            end
            RemoveBuff(identifier, buffName)
        else
            playerBuffs[identifier][buffName] = updatedTime
            -- Only need to update buffs since they show progress on client
            if buffData.type == 'buff' then
                -- Check if player is online
                if sourceID then
                    -- Call client event to send nui to front end
                    TriggerClientEvent('hud:client:BuffEffect', sourceID, {
                        buffName = buffName,
                        -- Progress value needs to be from 0 - 100
                        progressValue = (updatedTime * 100) / buffData.maxTime,
                    })
                end
            end
        end
    end

    -- Not proud but need to loop through all timers but decrement it
    -- Loop is good as long as we only loop players that have buffs
    -- We ensure that when removing any buff, we check to see if it was the player's last buff
    -- Then we remove that player from our table to ensure we dont loop them
    while true do
        for identifier, buffTable in pairs(playerBuffs) do
            local xPlayer = ESX.GetPlayerFromIdentifier(identifier)
            local sourceID = nil
            
            if xPlayer then
                sourceID = xPlayer.source
            end
            
            for buffName, currentTime in pairs(buffTable) do
                DecrementBuff(sourceID, identifier, buffName, currentTime)
            end
        end

        Wait(Config.TickTime)
    end
end)
