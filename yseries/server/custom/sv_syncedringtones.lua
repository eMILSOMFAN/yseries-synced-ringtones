local activeCalls = {}

RegisterServerEvent('yseries:server:syncRingtone', function(coords, ped, callId)
    local src = source
    activeCalls[callId] = {
        sources = {},
    }

    local src = source
    local imei = exports.yseries:GetPhoneImeiBySourceId(src)
    local phoneData = MySQL.Sync.fetchAll('SELECT volume, sound, ringtone, do_not_disturb FROM yphone_settings WHERE phone_imei = ? ', {imei})

    if not phoneData[1].do_not_disturb then
        if phoneData[1].sound == 'sound' then
            -- ringtone
            TriggerClientEvent('yseries:client:syncRingtone', -1, callId, phoneData[1].ringtone, coords,  ped, phoneData[1].volume)
        elseif phoneData[1].sound == 'vibration' then
            -- vibration tone
            TriggerClientEvent('yseries:client:syncRingtone', -1, callId,'BasicCallVibration', coords,  ped, 5)
        end
    end

end)

RegisterServerEvent('yseries:server:addToSyncedRingtone', function(callId)
    local src = source
    activeCalls[callId].sources[#activeCalls[callId].sources+1] = src
end)



RegisterServerEvent('yseries:server:cancel-synced-call', function(callId, forced)
    if forced then
        if not activeCalls[callId] then return end
        for k, v in pairs(activeCalls[callId].sources) do
            TriggerClientEvent('yseries:client:stop-synced-ringtone', v, callId)
        end
    end
end)

RegisterServerEvent('yseries:server:send-synced-notification', function(sound, phoneNr, coords)
    local src = source
    
    local imei = exports.yseries:GetPhoneImeiByPhoneNumber(phoneNr)

    -- Return if phone is on do not disturb
    local do_not_disturb = MySQL.Sync.fetchScalar('SELECT do_not_disturb FROM yphone_settings WHERE phone_imei = ? ', {imei})
    if do_not_disturb or not phoneNr or not coords then return end

    -- Get phone sound and volume
    local data = MySQL.Sync.fetchAll('SELECT sound, volume, notification FROM yphone_settings WHERE phone_imei = ? ', {imei})
    TriggerClientEvent('yseries:client:syncNotification', -1, data[1].sound, data[1].volume, data[1].notification, coords)
end)



AddEventHandler('yseries:server:answer-call', function(table)
    local src = source
    for k, v in pairs(activeCalls[table.TargetData.number].sources) do
        TriggerClientEvent('yseries:client:stop-synced-ringtone', v, table.TargetData.number)
    end
end)

AddEventHandler('yseries:server:cancel-call', function(number)
    if not activeCalls[number] then return end
    for k, v in pairs(activeCalls[number].sources) do
        TriggerClientEvent('yseries:client:stop-synced-ringtone', v, number)
    end
end)



