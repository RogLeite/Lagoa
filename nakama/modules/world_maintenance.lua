local nakama = require("nakama")
local M = {}

-- Creats a string out of the table keys and type of the values
function M.table_keys(t)
    local ret = {}
    for k,v in pairs(t) do 
        ret[#ret+1] = k..":"..type(v)
    end
    return table.concat(ret, ", ")
end

function M.new_world(worlds, world_id)
    worlds[world_id] = {
        master = false,                 -- user_id of master client
        player_reservations = {},       -- Array of players user_id in the match
        -- player_reservations_count = 0,  -- Counter for player reservations. If is equal to MAX_PLAYERS_PER_MATCH, only lets players in `player_reservations` join
        player_presences = {}           -- Table of user_id:presence
     }
end
function M.get_world(worlds, world_id)
    return worlds[world_id]
end
function M.is_reserved(worlds, world_id, user_id)
    for k,v in ipairs(M.get_world(worlds, world_id).player_reservations) do
        if v.user_id == user_id then
            return k
        end
    end
    return false
end
function M.is_present(worlds, world_id, user_id)
    return M.get_world(worlds, world_id).player_presences[user_id] and true
end
function M.add_master(worlds, world_id, user_id)
    M.get_world(worlds, world_id).master = user_id
end
function M.remove_master(worlds, world_id)
    M.get_world(worlds, world_id).master = false
end

local function find_nil(array)
    local index = 1
    while array[index] ~= nil do index = index + 1 end
    return index
end

local function find_reservation(array, user_id)
    for index, value in ipairs(array) do
        if value.user_id == user_id then
            return index
        end
    end
    return false
end

function M.add_reservation(worlds, world_id, user_id, username)
    if not M.is_reserved(worlds, world_id, user_id) then
        -- nakama.logger_warn(string.format("add_reservation: username = '%s'", username))
        local reservations = M.get_world(worlds, world_id).player_reservations
        local index = find_nil(reservations)
        reservations[index] = {user_id = user_id, username = username}
    end
end

function M.remove_reservation(worlds, world_id, user_id)
    if not M.is_reserved(worlds, world_id, user_id) then
        return
    end
    local reservations = M.get_world(worlds, world_id).player_reservations
    local index = find_reservation(reservations, user_id)
    if not index then
        return
    end
    reservations[index] = nil
end

function M.add_presence(worlds, world_id, user_presence)
    local user_id = user_presence.user_id
    -- nakama.logger_warn(string.format("add_presence: user_presence.user_id = '%s', keys(user_presence) = {%s}", user_presence.user_id, M.table_keys(user_presence)))
    -- nakama.logger_warn(string.format("add_presence: username = '%s'", user_presence.username))
    if not M.is_present(worlds, world_id, user_id) then
        local world = M.get_world(worlds, world_id)
        world.player_presences[user_id] = user_presence
        -- nakama.logger_warn(string.format("add_presence: type(id) is \"%s\"", type(id)))
    end
end
function M.remove_presence(worlds, world_id, user_presence)
    local user_id = user_presence.user_id
    -- nakama.logger_warn(string.format("remove_presence: username = '%s'", user_presence.username))
    if M.is_present(worlds, world_id, user_id) then
        M.get_world(worlds, world_id).player_presences[user_id] = nil
    end
end

return M