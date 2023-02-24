local nakama = require("nakama")
local worlds = require("world_maintenance")

local MAX_PLAYERS_PER_MATCH = 4


local world_table = {}

local function _get_first_world()
    local matches = nakama.match_list()
    local current_match = matches[1]

    local world_id = ""

    if current_match == nil then 
        -- Creates a match using the "world_control" module as controller
        -- The table is passed to `match_init()` and can be used to pass the "matched users"
        world_id = nakama.match_create("world_control", {})

        -- Creates a new information table for the created match
        worlds.new_world(world_table, world_id)
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
    -- nakama.logger_warn(string.format("match_join_maintenance: presence.user_id = '%s', keys(presence) = {%s}", presence.user_id, worlds.table_keys(presence)))
    -- nakama.logger_warn(string.format("match_join_maintenance: username = '%s'", presence.username))

    local user_id = presence.user_id
    local username = presence.username

    if metadata and string.lower(metadata.is_master) == "true" then
        worlds.add_master(world_table, world_id, user_id)
    else
        worlds.add_reservation(world_table, world_id, user_id, username)
        worlds.add_presence(world_table, world_id, presence)
    end
end

local function match_leave_maintenance(world_id, presence, keep_reservation)
    -- nakama.logger_warn(string.format("match_leave_maintenance: presence.user_id = '%s'", presence.user_id))
    -- nakama.logger_warn(string.format("match_leave_maintenance: presence.user_id = '%s', keys(presence) = {%s}", presence.user_id, worlds.table_keys(presence)))
    -- nakama.logger_warn(string.format("match_leave_maintenance: username = '%s'", presence.username))

    local user_id = presence.user_id
    if user_id == worlds.get_world(world_table, world_id).master then
        worlds.remove_master(world_table, world_id)
    else
        worlds.remove_presence(world_table, world_id, presence)
        if not keep_reservation then
            worlds.drop_reservation(world_table, world_id, user_id)
        end
    end
end

local function join_player(context, payload)
    local decoded = nakama.json_decode(payload)
    -- nakama.logger_warn(string.format("join_player: username = '%s'", decoded.presence.username))
    match_join_maintenance(decoded.world_id, decoded.presence, decoded.metadata)
end
local function leave_player(context, payload)
    local decoded = nakama.json_decode(payload)
    -- nakama.logger_warn(string.format("leave_player: username = '%s'", decoded.presence.username))
    match_leave_maintenance(decoded.world_id, decoded.presence, true)
end

local function remove_player(context, payload)
    local decoded = nakama.json_decode(payload)
    -- nakama.logger_warn(string.format("leave_player: username = '%s'", decoded.presence.username))
    match_leave_maintenance(decoded.world_id, decoded.presence, false)
end

-- payload should be the world_id
local function get_presences(_context, payload)
    -- nakama.logger_warn(string.format("get_presences: payload %s", payload))
    local world = worlds.get_world(world_table, payload)
    local ret = {}
    local player_presences = {}
    for k, v in ipairs(world.player_reservations) do
        player_presences[#player_presences+1] = {user_id = v.user_id, username = v.username, presence = world.player_presences[v.user_id] or false}
    end
    ret.player_presences = player_presences
    -- nakama.logger_warn(string.format("get_presences: returns array of size %d", #ret.player_presences))
    
    ret.master_id = world.master

    return nakama.json_encode(ret)
end

nakama.register_rpc(get_world_id, "get_world_id")
nakama.register_rpc(join_player, "join_player")
nakama.register_rpc(leave_player, "leave_player")
nakama.register_rpc(remove_player, "remove_player")
nakama.register_rpc(get_presences, "get_presences")