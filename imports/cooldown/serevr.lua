GlobalState.cooldowns = {}

local function addGlobalCooldown(type, id)
    local cooldowns = GlobalState.cooldowns
    if not cooldowns then cooldowns = {} end
    if not cooldowns[type] then cooldowns[type] = {} end
    if not cooldowns[type][id] then cooldowns[type][id] = {} end
    cooldowns[type][id] = true
    GlobalState.cooldowns = cooldowns
end

local function removeGlobalCooldown(type, id, duration, timer)
    local cooldowns = GlobalState.cooldowns
    if not cooldowns then return end
    if not cooldowns[type] then return end
    if not cooldowns[type][id] then return end
    cooldowns[type][id] = nil
    GlobalState.cooldowns = cooldowns
end

lib.callback.register('ox_lib:cooldowns:Add', function(type, id, duration, cb, overide, source)
    return lib.cooldowns.add(type, id, duration, cb, false, true, overide, source)
end)

lib.callback.register('ox_lib:cooldowns:IsActive', function(type, id)
    return lib.cooldows.isActive(type, id)
end)

Cooldowns = {
    timers = {},
    isActive = function(type, id)
        if not type or not id then return false end
        local cooldown = Cooldowns.get(type, id)
        if not cooldown then return false end
        return cooldown.running or false
    end,
    create = function(type, id, duration, cb, global, client)
        local data =
        {
            type = type,
            id = id,
            timer = duration,
            duration = duration or 30,
            running = false,
            callback = cb,
            started = nil,
            stopped = nil,
            run = function()
                Cooldowns.run(type, id, duration, cb, global, client)
            end,
            global = global,
            client = client
        }
        return data
    end,
    add = function(type, id, duration, cb, global, overide)
        if not id or not type then return false end
        if Cooldowns.isActive(type, id) and not overide then return false end
        local cooldown = Cooldowns.create(type, id, duration, cb)    
        if Cooldowns.isActive(type, id) then
            Cooldowns.remove(type, id)
        end
        Cooldowns.timers[type][id] = cooldown
        return cooldown.run(type, id, duration, cb)
    end,
    replace = function(type, id, table)
        if not id or not type then return end
        Cooldowns.timers[type][id] = table
    end,
    remove = function(type, id)
        if not id or not type then return end
        Cooldowns.timers[type][id] = nil
    end,
    get = function(type, id)
        if not id or not type then return false end
        if not Cooldowns.isActive(type, id) then return false end
        if not Cooldowns.timers[type] then return false end
        if Cooldowns.timers[type] and not id then return Cooldowns.timers[type][id] end
        if Cooldowns.timers[type][id] and id then return Cooldowns.timers[type][id] end
    end,
    set = function(type, id, key, value)
        if not value then return end
        if not type or not id then return end
        if not Cooldowns.timers[type] then Cooldowns.timers[type] = {} end
        if not Cooldowns.timers[type][id] then Cooldowns.timers[type][id] = {} end
        if key == nil and type(value) == 'table' then 
            Cooldowns.timers[type][id] = value
        else 
            Cooldowns.timers[type][id][key] = value 
        end
        return value
    end,   
    run = function(type, id, duration, cb, global)
        local cooldown = Cooldowns.get(type, id)
        if not cooldown then return false end
        CreateThread(function()
            local started = os.time()
            cooldown.started = started
            cooldown.running = true
            if global then addGlobalCooldown(type, id) end
            cooldown = Cooldowns.set(type, id, nil, cooldown)
            while true do
                Wait(1000)
                cooldown = Cooldowns.get(type, id)
                if (cooldown and cooldown.started == started) and not cooldown then break end
                cooldown.timer = cooldown.timer - 1
                if cooldown.timer <= 0 then
                    cooldown.timer = 0
                    cooldown.running = false
                    cooldown.stopped = os.time()
                    cooldown = Cooldown.set(type, id, nil, cooldown)
                    local callback = cooldown.callback
                    if callback and cooldown.client == false then callback()
                    elseif callback and cooldown.client == true then
                        TriggerClientEvent('ox_lib:cooldowns:finished', -1, type, id, duration, callback)
                    end
                    break
                end
                Cooldowns.set(type, id, 'timer', cooldown.timer)
            end
        end)
    end,
}

lib.cooldowns = {
    add = function(type, id, duration, cb, global, overide)
        return Cooldowns.add(type, id, duration, cb, global, nil, overide)
    end,
    get = function(type, id)
        return Cooldowns.get(type, id)
    end,
    remove = function(type, id)
        if not Cooldowns.isActive(type, id) then return false end
        return Cooldowns.remove(type, id)
    end,
    isActive = function(type, id)
        return Cooldown.isActive(type, id)
    end,
}

return lib.cooldowns