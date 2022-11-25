local nakama = require("nakama")

local MAX_PLAYERS_PER_MATCH = 4

-- Creats a string out of the table keys and type of the values
local function table_keys(t)
    local ret = {}
    for k,v in pairs(t) do 
        ret[#ret+1] = k..":"..type(v)
    end
    return table.concat(ret, ", ")
end

local worlds = {}

local function new_world(world_id)
    worlds[world_id] = {
        master = false,                 -- user_id of master client
        player_reservations = {},       -- Array of players user_id in the match
        -- player_reservations_count = 0,  -- Counter for player reservations. If is equal to MAX_PLAYERS_PER_MATCH, only lets players in `player_reservations` join
        player_presences = {}           -- Table of user_id:presence
     }
end
local function get_world(world_id)
    return worlds[world_id]
end
local function is_reserved(world_id, user_id)
    for k,v in ipairs(get_world(world_id).player_reservations) do
        if v == user_id then
            return k
        end
    end
    return false
end
local function is_present(world_id, user_id)
    return get_world(world_id).player_presences[user_id] and true
end
local function add_master(world_id, user_id)
    get_world(world_id).master = user_id
end
local function remove_master(world_id)
    get_world(world_id).master = false
end
local function add_reservation(world_id, user_id)
    if not is_reserved(world_id, user_id) then
        local res = get_world(world_id).player_reservations
        res[#res+1] = user_id
    end
end
-- local function remove_reservation(world_id, user_id)
--     local reservation = is_reserved(world_id, user_id)
-- end
local function add_presence(world_id, user_presence)
    local id = user_presence.user_id
    -- nakama.logger_warn(string.format("add_presence: user_presence.user_id = '%s', keys(user_presence) = {%s}", user_presence.user_id, table_keys(user_presence)))
    if not is_present(world_id, id) then
        local world = get_world(world_id)
        local presences = world.player_presences
        -- nakama.logger_warn(string.format("add_presence: type(id) is \"%s\"", type(id)))
        presences[id] = user_presence
    end
end
local function remove_presence(world_id, user_presence)
    local id = user_presence.user_id
    if is_present(world_id, id) then
        get_world(world_id).player_presences[id] = nil
    end
end

local function _get_first_world()
    local matches = nakama.match_list()
    local current_match = matches[1]

    local world_id = ""

    if current_match == nil then 
        -- Creates a match using the "world_control" module as controller
        -- The table is passed to `match_init()` and can be used to pass the "matched users"
        world_id = nakama.match_create("world_control", {})

        -- Creates a new information table for the created match
        new_world(world_id)
    else 
        world_id = current_match.match_id
    end

    return world_id
end

-- [TODO] Lembrar, olhando pra projeto, que parâmetros são passadoa para cá
-- @param context Table storing context data such as user_id of the caller. Possible keys: https://heroiclabs.com/docs/nakama/server-framework/introduction/#runtime-context
-- @param payload String with payload sent by the caller of rpc_async()
-- @ret The world id as String
local function get_world_id(_context, _payload)
    return _get_first_world()
end

local function match_join_maintenance(world_id, presence, metadata)
    -- nakama.logger_warn(string.format("match_join_maintenance: presence = '%s'", presence))
    -- nakama.logger_warn(string.format("match_join_maintenance: presence.user_id = '%s', keys(presence) = {%s}", presence.user_id, table_keys(presence)))
    

    local user_id = presence.user_id

    if metadata and string.lower(metadata.is_master) == "true" then
        add_master(world_id, user_id)
    else
        add_reservation(world_id, user_id)
        add_presence(world_id, presence)
    end
end

local function match_leave_maintenance(world_id, presence)
    -- nakama.logger_warn(string.format("match_leave_maintenance: presence.user_id = '%s'", presence.user_id))
    -- nakama.logger_warn(string.format("match_leave_maintenance: presence.user_id = '%s', keys(presence) = {%s}", presence.user_id, table_keys(presence)))
    local user_id = presence.user_id
    if user_id == get_world(world_id).master then
        remove_master(world_id)
    else
        -- Does not remove the reservation
        remove_presence(world_id, presence)
    end
end

local function join_player(context, payload)
    local decoded = nakama.json_decode(payload)
    match_join_maintenance(decoded.world_id, decoded.presence, decoded.metadata)
end
local function leave_player(context, payload)
    local decoded = nakama.json_decode(payload)
    -- nakama.logger_warn(string.format("leave_player: username = '%s'", decoded.presence.username))
    match_leave_maintenance(decoded.world_id, decoded.presence)
end

-- payload should be the world_id
local function get_presences(_context, payload)
    -- nakama.logger_warn(string.format("get_presences: payload %s", payload))
    local world = get_world(payload)
    local ret = {}
    for k, v in ipairs(world.player_reservations) do
        ret[#ret+1] = {user_id = v, presence = world.player_presences[v] or false}
    end
    return nakama.json_encode(ret)
end

nakama.register_rpc(get_world_id, "get_world_id")
nakama.register_rpc(join_player, "join_player")
nakama.register_rpc(leave_player, "leave_player")
nakama.register_rpc(get_presences, "get_presences")