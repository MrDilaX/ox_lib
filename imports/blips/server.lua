--[[
    https://github.com/overextended/ox_lib
    https://github.com/ItzDabbzz/ox_lib

    This file is licensed under LGPL-3.0 or higher <https://www.gnu.org/licenses/lgpl-3.0.en.html>

    Copyright © 2025 ItzDabbzz <https://github.com/ItzDabbzz>
]]

---@class OxBlipsServer
---@field createCategory fun(categoryId: string, categoryInfo: BlipCategoryCreateData): boolean, string? Create a new blip category
---@field removeCategory fun(categoryId: string): boolean, string? Remove a blip category
---@field addBlip fun(blipInfo: BlipCreateServerData): number?, string? Add a new blip
---@field removeBlip fun(blipId: number): boolean, string? Remove a blip
---@field updateBlip fun(blipId: number, updates: table): boolean, string? Update a blip
---@field getCategories fun(): table<string, BlipCategoryData> Get all categories
---@field getBlips fun(): table<number, BlipServerData> Get all blips
---@field getBlipsByCategory fun(categoryId: string): table<number, BlipServerData> Get blips by category
---@field getBlip fun(blipId: number): BlipServerData? Get blip by ID
---@field getCategory fun(categoryId: string): BlipCategoryData? Get category by ID
---@field setCategoryEnabled fun(categoryId: string, enabled: boolean): boolean, string? Enable/disable a category
---@field setBlipEnabled fun(blipId: number, enabled: boolean): boolean, string? Enable/disable a blip
---@field getStats fun(): BlipSystemStats Get blip statistics
---@field clearAll fun(): boolean Clear all blips and categories
---@field addJobBlip fun(jobName: string, blipInfo: BlipCreateServerData): number?, string? Add job-specific blip
---@field addPublicJobBlip fun(jobName: string, blipInfo: BlipCreateServerData): number?, string? Add public job blip
---@field addJobBlips fun(jobBlips: table<string, BlipCreateServerData[]>): table Bulk add job blips
---@field removeJobBlips fun(jobName: string): number Remove all blips for a job
---@field getJobBlips fun(jobName: string): table<number, BlipServerData> Get all blips for a job
lib.blips = {}

---@class BlipCategoryCreateData
---@field label string Display label for the category
---@field description string? Optional description of the category
---@field restrictions BlipAccessRestrictions? Access restrictions for the category
---@field enabled boolean? Whether the category is enabled (default: true)

---@class BlipCategoryData
---@field id string Unique category identifier
---@field label string Display label for the category
---@field description string Category description
---@field restrictions BlipAccessRestrictions? Access restrictions
---@field enabled boolean Whether the category is enabled
---@field created number Timestamp when created
---@field updated number? Timestamp when last updated
---@field blipCount number Number of blips in this category

---@class BlipCreateServerData
---@field coords vector3 Blip coordinates (required)
---@field sprite number Blip sprite ID (required)
---@field color number Blip color ID (required)
---@field label string Blip display label (required)
---@field scale number? Blip scale (default: 1.0)
---@field shortRange boolean? Whether blip is short range (default: false)
---@field category string? Category ID this blip belongs to
---@field restrictions BlipAccessRestrictions? Access restrictions
---@field enabled boolean? Whether the blip is enabled (default: true)
---@field metadata table? Additional metadata
---@field alpha number? Blip transparency (0-255)
---@field rotation number? Blip rotation in degrees
---@field display number? Blip display type

---@class BlipServerData
---@field id number Unique blip identifier
---@field coords vector3 Blip coordinates
---@field sprite number Blip sprite ID
---@field color number Blip color ID
---@field scale number Blip scale
---@field label string Blip display label
---@field shortRange boolean Whether blip is short range
---@field category string? Category ID this blip belongs to
---@field restrictions BlipAccessRestrictions? Access restrictions
---@field enabled boolean Whether the blip is enabled
---@field created number Timestamp when created
---@field updated number? Timestamp when last updated
---@field metadata table Additional metadata
---@field alpha number? Blip transparency
---@field rotation number? Blip rotation
---@field display number? Blip display type

---@class BlipAccessRestrictions
---@field jobs string[]? List of allowed job names
---@field gangs string[]? List of allowed gang names
---@field minGrade number? Minimum job grade required

---@class PlayerJobInfo
---@field name string Job name
---@field grade number Job grade level
---@field gang string? Gang name (if applicable)

---@class BlipSystemStats
---@field totalCategories number Total number of categories
---@field totalBlips number Total number of blips
---@field enabledCategories number Number of enabled categories
---@field enabledBlips number Number of enabled blips
---@field blipsByCategory table<string, number> Blip count per category
---@field playersTracked number Number of players being tracked
---@field nextBlipId number Next available blip ID
---@field config BlipSystemConfig Current system configuration

---@class BlipSystemConfig
---@field debug boolean Debug logging enabled
---@field syncInterval number Sync interval in milliseconds
---@field maxBlipsPerCategory number Maximum blips per category
---@field maxCategories number Maximum number of categories
---@field useFiveMCategories boolean Use FiveM's category system

---@class BlipInternalData
---@field categories table<string, BlipCategoryData> Category storage
---@field blips table<number, BlipServerData> Blip storage
---@field playerBlips table<number, table<number, boolean>> Player blip visibility tracking
---@field nextBlipId number Next available blip ID

-- Internal storage for blip management
local blipData = {
    categories = {},
    blips = {},
    playerBlips = {}, -- Track which blips each player can see
    nextBlipId = 1
}

-- System configuration loaded from convars
local config = {
    debug = GetConvarBool('ox:blips:debug', false),
    syncInterval = GetConvarInt('ox:blips:syncInterval', 30000), -- 30 seconds
    maxBlipsPerCategory = GetConvarInt('ox:blips:maxPerCategory', 100),
    maxCategories = GetConvarInt('ox:blips:maxCategories', 50),
    useFiveMCategories = GetConvarBool('ox:blips:categories', true)
}

---Debug logging utility with structured data support
---@param message string The debug message to log
---@param data table? Optional structured data to include in verbose logging
---@return nil
local function debugLog(message, data)
    if not config.debug then return end

    lib.print.debug(('[Blips] %s'):format(message))
    if data and lib.print.verbose then
        lib.print.verbose(json.encode(data, { indent = true }))
    end
end

---Validate blip data structure and required fields
---@param blipInfo table The blip data to validate
---@return boolean success Whether validation passed
---@return string? error Error message if validation failed
local function validateBlipData(blipInfo)
    if not lib.assert.type(blipInfo, 'table', 'Blip data') then
        return false, "Blip data must be a table"
    end

    -- Validate required fields
    local required = { 'coords', 'sprite', 'color', 'label' }
    for _, field in ipairs(required) do
        if not blipInfo[field] then
            return false, ('Missing required field: %s'):format(field)
        end
    end

    -- Validate coordinates structure
    if not lib.assert.type(blipInfo.coords, 'table', 'Coordinates') then
        return false, "Invalid coordinates format"
    end

    if not blipInfo.coords.x or not blipInfo.coords.y then
        return false, "Coordinates must have x and y values"
    end

    -- Validate sprite and color are numbers
    if not lib.assert.type(blipInfo.sprite, 'number', 'Sprite') then
        return false, "Sprite must be a number"
    end

    if not lib.assert.type(blipInfo.color, 'number', 'Color') then
        return false, "Color must be a number"
    end

    -- Validate label is non-empty string
    if not lib.assert.type(blipInfo.label, 'string', 'Label') then
        return false, "Label must be a string"
    end

    if lib.string.trim(blipInfo.label) == '' then
        return false, "Label cannot be empty"
    end

    return true
end

---Validate access restrictions structure and data types
---@param restrictions table? The restrictions to validate
---@return boolean success Whether validation passed
---@return string? error Error message if validation failed
local function validateRestrictions(restrictions)
    if not restrictions then return true end

    if not lib.assert.type(restrictions, 'table', 'Restrictions') then
        return false, "Restrictions must be a table"
    end

    -- Validate jobs restriction
    if restrictions.jobs then
        if not lib.assert.type(restrictions.jobs, 'table', 'Jobs restriction') then
            return false, "Jobs restriction must be a table"
        end

        for _, job in ipairs(restrictions.jobs) do
            if not lib.assert.type(job, 'string', 'Job name') then
                return false, "Job names must be strings"
            end
        end
    end

    -- Validate gangs restriction
    if restrictions.gangs then
        if not lib.assert.type(restrictions.gangs, 'table', 'Gangs restriction') then
            return false, "Gangs restriction must be a table"
        end

        for _, gang in ipairs(restrictions.gangs) do
            if not lib.assert.type(gang, 'string', 'Gang name') then
                return false, "Gang names must be strings"
            end
        end
    end

    -- Validate minimum grade
    if restrictions.minGrade and not lib.assert.type(restrictions.minGrade, 'number', 'Minimum grade') then
        return false, "Minimum grade must be a number"
    end

    return true
end

---Get player job information from the active framework
---@param playerId number The player's server ID
---@return PlayerJobInfo? jobInfo Player's job information, or nil if unavailable
local function getPlayerJobInfo(playerId)
    if not lib.framework.isAvailable() then
        debugLog('Framework not available for player job lookup')
        return nil
    end

    local player = exports.qbx_core:GetPlayer(source) --lib.framework.getPlayer(playerId) 
    if not player then
        debugLog('couldnt find palyer by id ', { playerId = playerId })
        return nil
    end

  --  local framework = lib.framework.getName()

  -- if framework == 'esx' then
  --      local job = player.getJob()
  --     return {
  --          name = job.name,
  --         grade = job.grade,
  --          gang = nil -- ESX doesn't have gangs by default
  --      }
  --  elseif framework == 'qb' or framework == 'qbx' then
  --      return {
            name = player.PlayerData.job.name,
            grade = player.PlayerData.job.grade.level,
            gang = player.PlayerData.gang and player.PlayerData.gang.name or nil
  --      }
  --  end

  --  debugLog('Unsupported framework for job lookup', { framework = framework })
  --  return nil
end

---Check if a player can see a blip based on access restrictions
---@param playerId number The player's server ID
---@param restrictions BlipAccessRestrictions? The access restrictions to check
---@return boolean canSee Whether the player can see the blip
local function canPlayerSeeBlip(playerId, restrictions)
    if not restrictions then return true end

    local jobInfo = getPlayerJobInfo(playerId)
    if not jobInfo then return false end

    -- Check job restrictions
    if restrictions.jobs then
        local hasJob = false
        for _, job in ipairs(restrictions.jobs) do
            if jobInfo.name == job then
                hasJob = true
                break
            end
        end
        if not hasJob then return false end
    end

    -- Check gang restrictions
    if restrictions.gangs and jobInfo.gang then
        local hasGang = false
        for _, gang in ipairs(restrictions.gangs) do
            if jobInfo.gang == gang then
                hasGang = true
                break
            end
        end
        if not hasGang then return false end
    end

    -- Check minimum grade requirement
    if restrictions.minGrade and jobInfo.grade < restrictions.minGrade then
        return false
    end

    return true
end

---Synchronize a specific blip to all eligible players
---@param blipId number The unique blip identifier to sync
---@return nil
local function syncBlipToPlayers(blipId)
    local blip = blipData.blips[blipId]
    if not blip or not blip.enabled then return end

    -- Check if the blip's category is enabled
    if blip.category and blipData.categories[blip.category] and not blipData.categories[blip.category].enabled then
        return
    end

    local players = GetPlayers()
    for _, playerId in ipairs(players) do
        local playerIdNum = tonumber(playerId)
        if playerIdNum then
            local canSee = canPlayerSeeBlip(playerIdNum, blip.restrictions)

            -- Initialize player blip tracking if needed
            if not blipData.playerBlips[playerIdNum] then
                blipData.playerBlips[playerIdNum] = {}
            end

            local hadBlip = blipData.playerBlips[playerIdNum][blipId] ~= nil

            if canSee and not hadBlip then
                -- Player can see blip and doesn't have it yet - add it
                blipData.playerBlips[playerIdNum][blipId] = true
                TriggerClientEvent('ox_lib:blips:blipAdded', playerIdNum, blipId, blip)
            elseif canSee and hadBlip then
                -- Player can see blip and already has it - update it
                TriggerClientEvent('ox_lib:blips:blipUpdated', playerIdNum, blipId, blip)
            elseif not canSee and hadBlip then
                -- Player can't see blip but has it - remove it
                blipData.playerBlips[playerIdNum][blipId] = nil
                TriggerClientEvent('ox_lib:blips:blipRemoved', playerIdNum, blipId)
            end
        end
    end
end

---Synchronize all visible blips for a specific player
---@param playerId number The player's server ID
---@return nil
local function syncPlayerBlips(playerId)
    if not blipData.playerBlips[playerId] then
        blipData.playerBlips[playerId] = {}
    end

    local visibleBlips = {}
    local visibleCategories = {}

    -- Collect categories the player can see
    for categoryId, category in pairs(blipData.categories) do
        if category.enabled and canPlayerSeeBlip(playerId, category.restrictions) then
            visibleCategories[categoryId] = category
        end
    end

    -- Collect blips the player can see
    for blipId, blip in pairs(blipData.blips) do
        if blip.enabled then
            local categoryOk = true
            if blip.category then
                categoryOk = visibleCategories[blip.category] ~= nil
            end

            if categoryOk and canPlayerSeeBlip(playerId, blip.restrictions) then
                visibleBlips[blipId] = blip
                blipData.playerBlips[playerId][blipId] = true
            end
        end
    end

    debugLog('Player blips synchronized', {
        playerId = playerId,
        categoriesCount = lib.table.count(visibleCategories),
        blipsCount = lib.table.count(visibleBlips)
    })

    -- Send full synchronization to player
    TriggerClientEvent('ox_lib:blips:fullSync', playerId, visibleCategories, visibleBlips)
end

-- Public API Functions

---Create a new blip category with access restrictions
---@param categoryId string Unique category identifier
---@param categoryInfo BlipCategoryCreateData Category configuration data
---@return boolean success Whether the category was created successfully
---@return string? error Error message if creation failed
function lib.blips.createCategory(categoryId, categoryInfo)
    -- Validate category ID
    if not lib.assert.type(categoryId, 'string', 'Category ID') then
        return false, "Category ID must be a string"
    end

    if lib.string.trim(categoryId) == '' then
        return false, "Category ID cannot be empty"
    end

    -- Validate category information
    if not lib.assert.type(categoryInfo, 'table', 'Category info') then
        return false, "Category info must be a table"
    end

    if not categoryInfo.label or lib.string.trim(categoryInfo.label) == '' then
        return false, "Category must have a label"
    end

    -- Check system limits
    local categoryCount = lib.table.count(blipData.categories)
    if categoryCount >= config.maxCategories then
        return false, ('Maximum categories limit reached (%d)'):format(config.maxCategories)
    end

    -- Check for duplicate category
    if blipData.categories[categoryId] then
        return false, ('Category "%s" already exists'):format(categoryId)
    end

    -- Validate access restrictions
    local isValid, error = validateRestrictions(categoryInfo.restrictions)
    if not isValid then return false, error end

    -- Create category data structure
    blipData.categories[categoryId] = {
        id = categoryId,
        label = lib.string.trim(categoryInfo.label),
        description = categoryInfo.description or "",
        restrictions = categoryInfo.restrictions,
        enabled = categoryInfo.enabled ~= false,
        created = os.time(),
        blipCount = 0
    }

    debugLog('Category created successfully', {
        categoryId = categoryId,
        info = categoryInfo
    })

    -- Synchronize with all players
    TriggerClientEvent('ox_lib:blips:categoryCreated', -1, categoryId, blipData.categories[categoryId])

    return true
end

---Remove a blip category and all its associated blips
---@param categoryId string The category identifier to remove
---@return boolean success Whether the category was removed successfully
---@return string? error Error message if removal failed
function lib.blips.removeCategory(categoryId)
    if not blipData.categories[categoryId] then
        return false, ('Category "%s" does not exist'):format(categoryId)
    end

    -- Remove all blips in this category first
    local blipsToRemove = {}
    for blipId, blip in pairs(blipData.blips) do
        if blip.category == categoryId then
            blipsToRemove[#blipsToRemove + 1] = blipId
        end
    end

    for _, blipId in ipairs(blipsToRemove) do
        lib.blips.removeBlip(blipId)
    end

    -- Remove the category
    blipData.categories[categoryId] = nil

    debugLog('Category removed successfully', {
        categoryId = categoryId,
        removedBlips = #blipsToRemove
    })

    -- Synchronize removal with all players
    TriggerClientEvent('ox_lib:blips:categoryRemoved', -1, categoryId)

    return true
end

---Add a new blip to the system
---@param blipInfo BlipCreateServerData Blip configuration data
---@return number? blipId The created blip ID, or nil if creation failed
---@return string? error Error message if creation failed
function lib.blips.addBlip(blipInfo)
    local isValid, error = validateBlipData(blipInfo)
    if not isValid then return nil, error end

    -- Validate category exists if specified
    if blipInfo.category and not blipData.categories[blipInfo.category] then
        return nil, ('Category "%s" does not exist'):format(blipInfo.category)
    end

    -- Check category blip limit
    if blipInfo.category then
        local categoryBlipCount = 0
        for _, blip in pairs(blipData.blips) do
            if blip.category == blipInfo.category then
                categoryBlipCount = categoryBlipCount + 1
            end
        end

        if categoryBlipCount >= config.maxBlipsPerCategory then
            return nil, ('Category "%s" has reached maximum blips limit (%d)'):format(
                blipInfo.category, config.maxBlipsPerCategory)
        end
    end

    -- Validate access restrictions
    isValid, error = validateRestrictions(blipInfo.restrictions)
    if not isValid then return nil, error end

    -- Generate unique blip ID
    local blipId = blipData.nextBlipId
    blipData.nextBlipId = blipData.nextBlipId + 1

    -- Create blip data structure
    local blip = {
        id = blipId,
        coords = blipInfo.coords,
        sprite = blipInfo.sprite,
        color = blipInfo.color,
        scale = blipInfo.scale or 1.0,
        label = lib.string.trim(blipInfo.label),
        shortRange = blipInfo.shortRange or false,
        category = blipInfo.category,
        restrictions = blipInfo.restrictions,
        enabled = blipInfo.enabled ~= false,
        created = os.time(),
        metadata = blipInfo.metadata or {},
        alpha = blipInfo.alpha,
        rotation = blipInfo.rotation,
        display = blipInfo.display
    }

    blipData.blips[blipId] = blip

    -- Update category blip count
    if blip.category and blipData.categories[blip.category] then
        blipData.categories[blip.category].blipCount = blipData.categories[blip.category].blipCount + 1
    end

    debugLog('Blip added successfully', {
        blipId = blipId,
        blip = blip
    })

    -- Synchronize with eligible players
    syncBlipToPlayers(blipId)

    return blipId
end

---Remove a blip from the system
---@param blipId number The blip identifier to remove
---@return boolean success Whether the blip was removed successfully
---@return string? error Error message if removal failed
function lib.blips.removeBlip(blipId)
    local blip = blipData.blips[blipId]
    if not blip then
        return false, ('Blip %d does not exist'):format(blipId)
    end

    -- Update category blip count
    if blip.category and blipData.categories[blip.category] then
        blipData.categories[blip.category].blipCount = blipData.categories[blip.category].blipCount - 1
    end

    -- Remove from storage
    blipData.blips[blipId] = nil

    -- Remove from player tracking
    for playerId in pairs(blipData.playerBlips) do
        if blipData.playerBlips[playerId][blipId] then
            blipData.playerBlips[playerId][blipId] = nil
        end
    end

    debugLog('Blip removed successfully', { blipId = blipId })

    -- Synchronize removal with all players
    TriggerClientEvent('ox_lib:blips:blipRemoved', -1, blipId)

    return true
end

---Update an existing blip's properties
---@param blipId number The blip identifier to update
---@param updates table Table of properties to update
---@return boolean success Whether the blip was updated successfully
---@return string? error Error message if update failed
function lib.blips.updateBlip(blipId, updates)
    local blip = blipData.blips[blipId]
    if not blip then
        return false, ('Blip %d does not exist'):format(blipId)
    end

    if not lib.assert.type(updates, 'table', 'Updates') then
        return false, "Updates must be a table"
    end

    -- Validate restrictions if being updated
    if updates.restrictions then
        local isValid, error = validateRestrictions(updates.restrictions)
        if not isValid then return false, error end
    end

    -- Apply updates while protecting immutable fields
    for key, value in pairs(updates) do
        if key ~= 'id' and key ~= 'created' then
            blip[key] = value
        end
    end

    blip.updated = os.time()

    debugLog('Blip updated successfully', {
        blipId = blipId,
        updates = updates
    })

    -- Re-synchronize with players (permissions might have changed)
    syncBlipToPlayers(blipId)

    return true
end

---Get all available categories
---@return table<string, BlipCategoryData> categories All category data
function lib.blips.getCategories()
    return blipData.categories
end

---Get all available blips
---@return table<number, BlipServerData> blips All blip data
function lib.blips.getBlips()
    return blipData.blips
end

---Get all blips belonging to a specific category
---@param categoryId string The category identifier to filter by
---@return table<number, BlipServerData> blips Blips in the specified category
function lib.blips.getBlipsByCategory(categoryId)
    if not lib.assert.type(categoryId, 'string', 'Category ID') then
        return {}
    end

    local categoryBlips = {}
    for blipId, blip in pairs(blipData.blips) do
        if blip.category == categoryId then
            categoryBlips[blipId] = blip
        end
    end
    return categoryBlips
end

---Get a specific blip by its ID
---@param blipId number The blip identifier
---@return BlipServerData? blip The blip data, or nil if not found
function lib.blips.getBlip(blipId)
    return blipData.blips[blipId]
end

---Get a specific category by its ID
---@param categoryId string The category identifier
---@return BlipCategoryData? category The category data, or nil if not found
function lib.blips.getCategory(categoryId)
    return blipData.categories[categoryId]
end

---Enable or disable a category and all its blips
---@param categoryId string The category identifier
---@param enabled boolean Whether to enable or disable the category
---@return boolean success Whether the operation was successful
---@return string? error Error message if operation failed
function lib.blips.setCategoryEnabled(categoryId, enabled)
    local category = blipData.categories[categoryId]
    if not category then
        return false, ('Category "%s" does not exist'):format(categoryId)
    end

    category.enabled = enabled
    category.updated = os.time()

    debugLog('Category enabled status changed', {
        categoryId = categoryId,
        enabled = enabled
    })

    -- Re-synchronize all blips in this category
    for blipId, blip in pairs(blipData.blips) do
        if blip.category == categoryId then
            syncBlipToPlayers(blipId)
        end
    end

    return true
end

---Enable or disable a specific blip
---@param blipId number The blip identifier
---@param enabled boolean Whether to enable or disable the blip
---@return boolean success Whether the operation was successful
---@return string? error Error message if operation failed
function lib.blips.setBlipEnabled(blipId, enabled)
    local blip = blipData.blips[blipId]
    if not blip then
        return false, ('Blip %d does not exist'):format(blipId)
    end

    blip.enabled = enabled
    blip.updated = os.time()

    debugLog('Blip enabled status changed', {
        blipId = blipId,
        enabled = enabled
    })

    -- Re-synchronize this blip
    syncBlipToPlayers(blipId)

    return true
end

---Get comprehensive system statistics
---@return BlipSystemStats stats Current system statistics
function lib.blips.getStats()
    local stats = {
        totalCategories = lib.table.count(blipData.categories),
        totalBlips = lib.table.count(blipData.blips),
        enabledCategories = 0,
        enabledBlips = 0,
        blipsByCategory = {},
        playersTracked = lib.table.count(blipData.playerBlips),
        nextBlipId = blipData.nextBlipId,
        config = config
    }

    -- Count enabled categories and blips
    for _, category in pairs(blipData.categories) do
        if category.enabled then
            stats.enabledCategories = stats.enabledCategories + 1
        end
        stats.blipsByCategory[category.id] = category.blipCount
    end

    for _, blip in pairs(blipData.blips) do
        if blip.enabled then
            stats.enabledBlips = stats.enabledBlips + 1
        end
    end

    return stats
end

---Clear all blips and categories from the system
---@return boolean success Always returns true
function lib.blips.clearAll()
    blipData.categories = {}
    blipData.blips = {}
    blipData.playerBlips = {}
    blipData.nextBlipId = 1

    debugLog('All blips and categories cleared')

    -- Synchronize clear with all players
    TriggerClientEvent('ox_lib:blips:fullSync', -1, {}, {})

    return true
end

-- Job-Specific Blip Functions

---Add a job-specific blip with automatic categorization
---@param jobName string The job name for restrictions
---@param blipInfo BlipCreateServerData Blip configuration data
---@return number? blipId The created blip ID, or nil if creation failed
---@return string? error Error message if creation failed
function lib.blips.addJobBlip(jobName, blipInfo)
    if not jobName or not blipInfo then
        return nil, "Job name and blip info are required"
    end

    -- Auto-assign category based on job name
    local categoryMap = {
        police = 'police',
        sheriff = 'police',
        state = 'police',
        ambulance = 'ems',
        doctor = 'ems',
        paramedic = 'ems',
        mechanic = 'mechanic',
        bennys = 'mechanic',
        taxi = 'taxi',
        uber = 'taxi',
        realestate = 'realestate',
        lawyer = 'lawyer',
        judge = 'judge',
        cardealer = 'cardealer',
        banker = 'banker',
        government = 'government',
        mayor = 'government'
    }

    blipInfo.category = categoryMap[jobName:lower()] or 'jobs'

    -- Add job restriction if not specified
    if not blipInfo.restrictions then
        blipInfo.restrictions = {
            jobs = { jobName }
        }
    end

    return lib.blips.addBlip(blipInfo)
end

---Add a public job blip (visible to everyone)
---@param jobName string The job name for categorization
---@param blipInfo BlipCreateServerData Blip configuration data
---@return number? blipId The created blip ID, or nil if creation failed
---@return string? error Error message if creation failed
function lib.blips.addPublicJobBlip(jobName, blipInfo)
    if not jobName or not blipInfo then
        return nil, "Job name and blip info are required"
    end

    -- Auto-assign category but make it public
    local categoryMap = {
        police = 'police',
        sheriff = 'police',
        state = 'police',
        ambulance = 'ems',
        doctor = 'ems',
        paramedic = 'ems',
        mechanic = 'mechanic',
        bennys = 'mechanic',
        taxi = 'taxi',
        uber = 'taxi',
        realestate = 'realestate',
        lawyer = 'lawyer',
        judge = 'judge',
        cardealer = 'cardealer',
        banker = 'banker',
        government = 'government',
        mayor = 'government'
    }

    blipInfo.category = categoryMap[jobName:lower()] or 'jobs'
    blipInfo.restrictions = nil -- No restrictions = public

    return lib.blips.addBlip(blipInfo)
end

---Bulk add job blips from configuration
---@param jobBlips table<string, BlipCreateServerData[]> Job blips configuration
---@return table<string, table> results Results for each job and blip
function lib.blips.addJobBlips(jobBlips)
    local results = {}

    for jobName, blips in pairs(jobBlips) do
        results[jobName] = {}

        for i, blipInfo in ipairs(blips) do
            local blipId, error = lib.blips.addJobBlip(jobName, blipInfo)
            results[jobName][i] = {
                blipId = blipId,
                error = error,
                success = blipId ~= nil
            }
        end
    end

    debugLog('Bulk job blips added', {
        jobCount = lib.table.count(jobBlips),
        results = results
    })

    return results
end

---Remove all blips for a specific job
---@param jobName string The job name to remove blips for
---@return number removedCount Number of blips removed
function lib.blips.removeJobBlips(jobName)
    local removedCount = 0
    local blipsToRemove = {}

    for blipId, blip in pairs(blipData.blips) do
        if blip.restrictions and blip.restrictions.jobs then
            for _, job in ipairs(blip.restrictions.jobs) do
                if job == jobName then
                    blipsToRemove[#blipsToRemove + 1] = blipId
                    break
                end
            end
        end
    end

    for _, blipId in ipairs(blipsToRemove) do
        if lib.blips.removeBlip(blipId) then
            removedCount = removedCount + 1
        end
    end

    debugLog('Removed job blips', {
        jobName = jobName,
        count = removedCount
    })

    return removedCount
end

---Get all blips for a specific job
---@param jobName string The job name to filter by
---@return table<number, BlipServerData> blips All blips for the specified job
function lib.blips.getJobBlips(jobName)
    local jobBlips = {}

    for blipId, blip in pairs(blipData.blips) do
        if blip.restrictions and blip.restrictions.jobs then
            for _, job in ipairs(blip.restrictions.jobs) do
                if job == jobName then
                    jobBlips[blipId] = blip
                    break
                end
            end
        end
    end

    return jobBlips
end

-- Event Handlers

---Handle player requesting synchronization
---@param playerId number The player's server ID
---@return nil
local function onPlayerRequestSync(playerId)
    debugLog('Player requested sync', { playerId = playerId })
    syncPlayerBlips(playerId)
end

---Handle player job change event
---@param playerId number The player's server ID
---@return nil
local function onPlayerJobChanged(playerId)
    debugLog('Player job changed, re-syncing blips', { playerId = playerId })

    -- Clear current player blips
    blipData.playerBlips[playerId] = {}

    -- Re-synchronize with new permissions
    syncPlayerBlips(playerId)
end

---Periodic synchronization for all players
---@return nil
local function periodicSync()
    if config.syncInterval <= 0 then return end

    CreateThread(function()
        while true do
            Wait(config.syncInterval)

            local players = GetPlayers()
            for _, playerId in ipairs(players) do
                local playerIdNum = tonumber(playerId)
                if playerIdNum then
                    syncPlayerBlips(playerIdNum)
                end
            end

            debugLog('Periodic sync completed', { playerCount = #players })
        end
    end)
end

---Initialize default categories for the system
---@return nil
local function initializeDefaultCategories()
    -- Create default categories if none exist
    if lib.table.count(blipData.categories) == 0 then
        lib.blips.createCategory('general', {
            label = 'General',
            description = 'General purpose blips'
        })

        lib.blips.createCategory('jobs', {
            label = 'Jobs',
            description = 'Job-related blips'
        })

        lib.blips.createCategory('shops', {
            label = 'Shops',
            description = 'Shopping locations'
        })

        debugLog('Default categories created')
    end
end

---Initialize job-specific categories
---@return nil
local function initializeJobCategories()
    -- Create main jobs category
    lib.blips.createCategory('jobs', {
        label = 'Jobs',
        description = 'All job-related locations and services',
        enabled = true
    })

    -- Create specific job subcategories
    local jobCategories = {
        { id = 'police',     label = 'Police',      description = 'Law enforcement locations' },
        { id = 'ems',        label = 'EMS',         description = 'Emergency medical services' },
        { id = 'mechanic',   label = 'Mechanic',    description = 'Vehicle repair and services' },
        { id = 'taxi',       label = 'Taxi',        description = 'Transportation services' },
        { id = 'realestate', label = 'Real Estate', description = 'Property management' },
        { id = 'lawyer',     label = 'Lawyer',      description = 'Legal services' },
        { id = 'judge',      label = 'Judge',       description = 'Court services' },
        { id = 'cardealer',  label = 'Car Dealer',  description = 'Vehicle sales' },
        { id = 'banker',     label = 'Banker',      description = 'Banking services' },
        { id = 'gang',       label = 'Gang',        description = 'Gang territories and activities' },
        { id = 'government', label = 'Government',  description = 'Government offices and services' },
        { id = 'business',   label = 'Business',    description = 'Private businesses and services' }
    }

    for _, category in ipairs(jobCategories) do
        lib.blips.createCategory(category.id, {
            label = category.label,
            description = category.description,
            enabled = true
        })
    end

    debugLog('Job categories initialized')
end

-- Event Registration
RegisterNetEvent('ox_lib:blips:requestSync', onPlayerRequestSync)

-- Framework-specific job change events
--if lib.framework.isAvailable() then
----    local framework = lib.framework.getName()
--
--    if framework == 'esx' then
--        RegisterNetEvent('esx:setJob', function(playerId)
--            onPlayerJobChanged(playerId)
--        end)
--    elseif framework == 'qb' or framework == 'qbx' then
        RegisterNetEvent('QBCore:Server:OnJobUpdate', function(playerId)
            onPlayerJobChanged(playerId)
        end)

        RegisterNetEvent('QBCore:Server:OnGangUpdate', function(playerId)
            onPlayerJobChanged(playerId)
        end)
--    end
--end

-- Player disconnect cleanup
AddEventHandler('playerDropped', function()
    local playerId = source
    blipData.playerBlips[playerId] = nil
    debugLog('Player data cleaned up', { playerId = playerId })
end)

-- System Initialization
CreateThread(function()
    Wait(2000) -- Wait for framework to load

    initializeDefaultCategories()
    initializeJobCategories()
    periodicSync()

    lib.print.info('Blips system initialized successfully')
    debugLog('System initialized', {
        categories = lib.table.count(blipData.categories),
        blips = lib.table.count(blipData.blips),
        config = config
    })
end)

-- Callback Registration for External Scripts
lib.callback.register('ox_lib:blips:getCategories', function()
    return blipData.categories
end)

lib.callback.register('ox_lib:blips:getBlips', function()
    return blipData.blips
end)

lib.callback.register('ox_lib:blips:getStats', function()
    return lib.blips.getStats()
end)

lib.callback.register('ox_lib:blips:getJobBlips', function(source, jobName)
    return lib.blips.getJobBlips(jobName)
end)

-- Debug Commands (only available in debug mode)
if config.debug then
    lib.addCommand('blips_stats', {
        help = 'Show blips system statistics',
        restricted = 'group.admin'
    }, function(source)
        local stats = lib.blips.getStats()
        lib.print.info(('Blips Stats: %s'):format(json.encode(stats, { indent = true })))
    end)

    lib.addCommand('blips_sync', {
        help = 'Force sync blips for a player',
        restricted = 'group.admin',
        params = {
            { name = 'playerId', type = 'playerId', help = 'Player ID' }
        }
    }, function(source, args)
        syncPlayerBlips(args.playerId)
        lib.print.info(('Synced blips for player %d'):format(args.playerId))
    end)

    lib.addCommand('blips_clear', {
        help = 'Clear all blips and categories',
        restricted = 'group.admin'
    }, function(source)
        lib.blips.clearAll()
        lib.print.info('All blips and categories cleared')
    end)

    lib.addCommand('blips_reload', {
        help = 'Reload default categories',
        restricted = 'group.admin'
    }, function(source)
        initializeDefaultCategories()
        initializeJobCategories()
        lib.print.info('Default categories reloaded')
    end)
end

-- Export the blips module
return lib.blips
