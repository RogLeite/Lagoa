local nakama = require("nakama")

local function _get_first_world()
    local matches = nakama.match_list()
    local current_match = matches[1]

    if current_match == nil then 
        -- Creates a match using the "world_control" module as controller
        -- The table is passed to `match_init()` and can be used to pass the "matched users"
        return nakama.match_create("world_control", {})
    else 
        return current_match.match_id
    end
end

-- [TODO] Lembrar, olhando pra projeto, que parâmetros são passadoa para cá
-- @param context Table storing context data such as user_id of the caller. Possible keys: https://heroiclabs.com/docs/nakama/server-framework/introduction/#runtime-context
-- @param payload String with payload sent by the caller of rpc_async()
-- @ret The world id as String
local function get_world_id(_context, _payload)
    return _get_first_world()
end

nakama.register_rpc(get_world_id, "get_world_id")