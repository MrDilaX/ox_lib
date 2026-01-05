local globalCooldowns = GlobalState.cooldowns

RegisterNetEvent('ox_lib:cooldowns:finished', function(type, id, duration, callback)
    if callback then
        callback(type, id, duration)
    end
end)

lib.cooldowns = {
    add = function(type, cid, duration, cb, overide)
        return lib.callback.await('ox_lib:cooldowns:Add', type, cid, duration, cb, overide, GetPlayerServerId(cache.playerId))
    end,
    isActive = function(type, cid)
        return lib.callback.await('ox_lib:cooldowns:IsActive', type, cid)
    end,
}

return lib.cooldowns