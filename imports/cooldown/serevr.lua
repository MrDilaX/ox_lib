---
    local player_cooldowns = {}
    local global_cooldowns = {}
    local resource_cooldowns = {}

    --- Adds a cooldown for a player or globally.
    --- @param source number: Server ID or unique identifier.
    --- @param cooldown_type string: Type of cooldown (e.g., "begging").
    --- @param duration number: Duration in seconds.
    --- @param is_global boolean: Whether its global or per-player.
        function lib.add(source, cooldown_type, duration, is_global)
        local expires = os.time() + duration
        local resource = GetInvokingResource() or "unknown"
        local info = { end_time = expires, resource = resource }

        if is_global then
            global_cooldowns[cooldown_type] = info
        else
            player_cooldowns[source] = player_cooldowns[source] or {}
            player_cooldowns[source][cooldown_type] = info
        end

        resource_cooldowns[resource] = resource_cooldowns[resource] or {}
        table.insert(resource_cooldowns[resource], { source = source, cooldown_type = cooldown_type, is_global = is_global })
    end

    --- Checks if a cooldown is active.
    --- @param source number: Player/server ID.
    --- @param cooldown_type string: Type of cooldown.
    --- @param is_global boolean: Whether to check globally.
    --- @return boolean
    function lib.check(source, cooldown_type, is_global)
        local now = os.time()
        if is_global then
            return global_cooldowns[cooldown_type] and now < global_cooldowns[cooldown_type].end_time
        end
        return player_cooldowns[source] and player_cooldowns[source][cooldown_type] and now < player_cooldowns[source][cooldown_type].end_time
    end

    --- Clears a specific cooldown.
    --- @param source number: Player/server ID.
    --- @param cooldown_type string: Type of cooldown.
    --- @param is_global boolean: Whether to clear globally.
    function lib.clear(source, cooldown_type, is_global)
        if is_global then
            global_cooldowns[cooldown_type] = nil
            GlobalState["cooldown_" .. cooldown_type] = nil
        elseif player_cooldowns[source] then
            player_cooldowns[source][cooldown_type] = nil
        end
    end

    --- Clears all expired m.
    function lib.clear_all()
        local now = os.time()

        for id, cd in pairs(player_cooldowns) do
            for action, info in pairs(cd) do
                if now >= info.end_time then
                    cd[action] = nil
                end
            end
            if not next(cd) then player_cooldowns[id] = nil end
        end

        for action, info in pairs(global_cooldowns) do
            if now >= info.end_time then
                global_cooldowns[action] = nil
                GlobalState["cooldown_" .. action] = nil
            end
        end
    end

    --- Clears all cooldowns for a given resource.
    --- @param resource string: Resource name.
    function lib.clear_resource(resource)
        local list = resource_cooldowns[resource]
        if not list then return end

        for _, entry in ipairs(list) do
            if entry.is_global then
                global_cooldowns[entry.cooldown_type] = nil
            elseif player_cooldowns[entry.source] then
                player_cooldowns[entry.source][entry.cooldown_type] = nil
            end
        end

        resource_cooldowns[resource] = nil
    end
