local RingtoneMaxDistance = 50      -- How many units away from the player the ringtone can be heard, the sound is still dynamic though but it won't trigger on client further away than this distance to improve performance
local volumeModifier = 100          -- How much the volume is reduced by distance, Higher number = less volume at a distance

local syncedRingtones = {}

RegisterNetEvent('yseries:client:get-called', function(callId)
    local xPlayerCoords = GetEntityCoords(PlayerPedId())
    local ped = NetworkGetNetworkIdFromEntity(PlayerPedId())
    TriggerServerEvent('yseries:server:syncRingtone', xPlayerCoords, ped, callId)
end)


RegisterNetEvent('yseries:client:stop-synced-ringtone', function(callId)
    SendNUIMessage({
        transactionType = "stopSound",
        transactionCallId = callId
    })
    syncedRingtones[callId] = false
end)


RegisterNetEvent('yseries:client:add-new-synced-ringtone', function(callId)
    syncedRingtones[callId] = true
end)


local function getPlayerSpatialPos(xPlayer, pedCoords)
    local playerCoords = GetEntityCoords(xPlayer)
    local playerHeading = GetEntityHeading(xPlayer)
    
    -- Convert world coordinates to relative coordinates based on player direction
    local angle = math.rad(playerHeading)
    local sinAngle = math.sin(angle)
    local cosAngle = math.cos(angle)
    
    local relX = pedCoords.x - playerCoords.x
    local relY = pedCoords.y - playerCoords.y
    
    -- Rotate coordinates based on player direction
    local rotatedX = relX * cosAngle + relY * sinAngle
    local rotatedY = -relX * sinAngle + relY * cosAngle

    return rotatedX, rotatedY
end

local timerActive = false
RegisterNetEvent('yseries:client:syncRingtone', function(callId, ringtone, coords, ped, volume)

    TriggerEvent('yseries:client:stop-synced-ringtone', callId)
    Wait(100)
    TriggerEvent('yseries:client:add-new-synced-ringtone', callId)
    timerActive = true

    local xPlayer = PlayerPedId()
    if xPlayer == NetworkGetEntityFromNetworkId(ped) then return end
    if volume == nil then volume = 50 end
    
    local xDist = #(coords - GetEntityCoords(xPlayer))
    if xDist > RingtoneMaxDistance then return end
    
    -- Convert coordinates to relative coordinates from listener's perspective
    local rotatedX, rotatedY = getPlayerSpatialPos(xPlayer, coords)
    
    TriggerServerEvent('yseries:server:addToSyncedRingtone', callId)
    SendNUIMessage({
        transactionType = "playSound",
        transactionFile = ringtone,
        transactionVolume = volume / volumeModifier / xDist,
        transactionCallId = callId,
        position = {
            x = rotatedX,
            y = rotatedY,
            z = coords.z - GetEntityCoords(xPlayer).z
        }
    })

    while syncedRingtones[callId] do

        Wait(500)
        local pedCoords = GetEntityCoords(NetworkGetEntityFromNetworkId(ped)) --coords
        local xPlayer = PlayerPedId()
        
        xDist = #(pedCoords - GetEntityCoords(xPlayer))
        if xDist < 1.0 then xDist = 1.0 end
        
        soundVolume = volume / volumeModifier / xDist
        if soundVolume > 1 then soundVolume = 1 end
        if soundVolume <= 0.01 then soundVolume = 0 end
        
        -- Update rotated coordinates based on new pedCoords and player's new orientation
        local rotatedX, rotatedY = getPlayerSpatialPos(xPlayer, pedCoords)
        
        SendNUIMessage({
            transactionType = "updateSound",
            transactionVolume = soundVolume,
            transactionCallId = callId,
            position = {
                x = rotatedX,
                y = rotatedY,
                z = pedCoords.z - GetEntityCoords(xPlayer).z
            }
        })
    end
end)

RegisterNetEvent('yseries:client:syncNotification', function(sound, volume, notification, coords)
    local playerCoords = GetEntityCoords(PlayerPedId())
    local xDist = #(coords - playerCoords)
    if xDist > RingtoneMaxDistance then return end

    local ringtone = notification

    if sound == 'vibration' then
        volume = 50
        ringtone = 'BasicNotificationVibration'
    end

    local rotatedX, rotatedY = getPlayerSpatialPos(PlayerPedId(), coords)
        
    SendNUIMessage({
        transactionType = "playSound",
        transactionFile = ringtone,
        transactionVolume = volume / volumeModifier / xDist,
        transactionCallId = 'notification',
        position = {
            x = rotatedX,
            y = rotatedY,
            z = coords.z - playerCoords.z
        }
    })
end)

AddEventHandler('yseries:client:send-notification', function(message)
    local sound = message.sound
    local phoneNr = message.data.targetPhoneNumber
    local coords = GetEntityCoords(PlayerPedId())
    TriggerServerEvent('yseries:server:send-synced-notification', sound, phoneNr, coords)
end)

AddEventHandler('yseries:client:add-recent-call', function(_, callId)
    TriggerServerEvent('yseries:server:cancel-synced-call', callId, true)
end)

