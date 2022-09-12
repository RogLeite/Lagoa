-- world_control is the returned module
local world_control = {}

-- Every function in module "nakama": https://github.com/heroiclabs/nakama/blob/7207ede0052905349e7b2970fb5fec53fd23be4c/server/runtime_lua_nakama.go#L123
local nakama = require("nakama")

local TICK_RATE = 30

-- OpCodes less or equal to zero are reserved for Nakama
local OpCodes = {
    send_script = 1,
    update_pond_state = 2,
    initial_state = 3,
    manual_debug = 99         -- Used when running a non-production debug test
}


-- Command pattern table for boiler plate updates that uses data and state.
local commands = {}
do -- Defines default behaviour for __index 
    -- Metatable with __index metamethod, for undeclared OpCode handlers
    local commands_mt = {
        __index = function(_, idx)
            nakama.logger_warn(string.format("No command found for OpCode %d", idx))
        end
    }
    setmetatable(commands, commands_mt)
end


local pond_match_counter = 0
local function new_match_label()
    pond_match_counter = pond_match_counter + 1
    return string.format("Pond Match %d", pond_match_counter)
end

-- [TODO] Implement a whitelist system to determine which user_id can be MasterClient
local Whitelist = {}
function Whitelist.is_whitelisted (user_id)
    return true
end

-- Initializes a match: The `state` table, the match `label`, and `tick_rate`
-- @param context Table with contextual information such as the caller of the function
-- @param params table with parameters passed in the nakama.match_create() call
-- Source https://heroiclabs.com/docs/nakama/server-framework/lua-runtime/function-reference/match-handler/#match_init
function world_control.match_init(context, params)
    local state = {
        tick_counter = 0, -- [TODO] Remove after testing the client connection
        presence_counter = 0,
        presences = {}, -- Every presence, including the master
        player_presences = {},   -- Every presence excluding the MasterClient
        master = {              -- Information from MasterClient
            user_id = false,             -- String representing the "user_id"
            presence = false        -- Table representing the presence
        }
    }
    local tick_rate = TICK_RATE
    local label = new_match_label()
    return state, tick_rate, label
end

-- @brief match_join_attemp decides if the attempt to join was successful
-- @param context       Table with contextual information such as the caller of the function
-- @param dispatcher    Provides broadcast to clients functionality (broadcast_message, match_kick, match_label_update)
-- @param tick          Current match tick
-- @param state         `state` table
-- @param presence      The presence attempting to join
-- @param metadata      Table received from the client as part of the join request
-- Optionally returns a error message
-- Source https://heroiclabs.com/docs/nakama/server-framework/lua-runtime/function-reference/match-handler/#match_join_attempt
function world_control.match_join_attempt( context, dispatcher, tick, state, presence, metadata )
    -- Presence format:
	-- {
	--   user_id = "user unique ID",
	--   session_id = "session ID of the user's current connection",
	--   username = "user's unique username",
	--   node = "name of the Nakama node the user is connected to"
	-- }

    if state.presences and state.presences[presence.user_id] then
        return state, false, "user_id already has presence on the match"
    end

    -- If the presence wants to be a MasterClient
    if metadata and metadata.is_master then
        -- Rejects if another Master already exists
        if state.master.user_id and state.master.presence then
            return state, false, "Another MasterClient is already in this match"
        end

        -- Check the whitelist if the user_id can be a MasterClient
        if not Whitelist.is_whitelisted(presence.user_id) then
            return state, false, "user_id is not whitelisted to the role of MasterClient"
        end

        -- Since match_join does not have a "metadata" linked to the presence,
        -- it cannot distinguish who wants to be a Master. So register it here.
        state.master.user_id = presence.user_id
        state.master.presence = presence
    end

    return state, true
end

-- @brief Handles players joining the match.
-- @param context       Table with contextual information such as the caller of the function
-- @param dispatcher    Provides broadcast to clients functionality (broadcast_message, match_kick, match_label_update)
-- @param tick          Current match tick
-- @param state         `state` table
-- @param presences     The list of joining players to handle
-- Source https://heroiclabs.com/docs/nakama/server-framework/lua-runtime/function-reference/match-handler/#match_join
function world_control.match_join(context, dispatcher, tick, state, presences)

    -- Registers every new presence in the gamestate
    for _, presence in ipairs(presences) do
        
        state.presences[presence.user_id] = presence

        -- If it's not a MasterClient, store the presence in state.player_presences
        if presence.user_id ~= state.master.user_id  then
            state.player_presences[presence.user_id] = presence
        end
        state.presence_counter = state.presence_counter + 1
    end

    return state
end

-- @brief Handles players leaving the match.
-- @param context       Table with contextual information such as the caller of the function
-- @param dispatcher    Provides broadcast to clients functionality (broadcast_message, match_kick, match_label_update)
-- @param tick          Current match tick
-- @param state         `state` table
-- @param presences     The list of leaving players to handle
-- Source https://heroiclabs.com/docs/nakama/server-framework/lua-runtime/function-reference/match-handler/#match_leave
function world_control.match_leave(context, dispatcher, tick, state, presences)
    -- Removes presences from the state
    
    for _, presence in ipairs(presences) do
        state.presences[presence.user_id] = nil
        if presence.user_id == state.master.user_id then
            state.master.user_id = nil
            state.master.presence = nil
        else
            state.player_presences[presence.user_id] = nil
        end
        state.presence_counter = state.presence_counter - 1
    end

    if state.presence_counter <= 0 then
        return nil
    end

    return state
end

-- @brief Executed every match tick.
-- @param context       Table with contextual information such as the caller of the function
-- @param dispatcher    Provides broadcast to clients functionality (broadcast_message, match_kick, match_label_update)
-- @param tick          Current match tick
-- @param state         `state` table
-- @param messages      List of messages received from users between previous and current tick
-- Source https://heroiclabs.com/docs/nakama/server-framework/lua-runtime/function-reference/match-handler/#match_loop
function world_control.match_loop(context, dispatcher, tick, state, messages)
    
    -- Receive messages
    for _, message in ipairs(messages) do
        local op_code = message.op_code
        local decoded = nakama.json_decode(message.data)
        
        -- Runs the boiler plate codes for state update
        local command = commands[op_code]
        if command then
            command(decoded, state)
        end

        if op_code == OpCodes.send_script then
            if state.master.user_id then
                -- Sends the PlayerClient message (the actual message is in message.data) to the MasterClient
                dispatcher.broadcast_message(op_code, message.data, {state.master.presence}, message.sender)
            else
                nakama.logger_warn("PlayerClients are sending messages with op_code 'send_script' when no MasterClient is connected")
            end
        elseif op_code == OpCodes.update_pond_state then
            -- Broadcasts the message to all PlayerClients
            dispatcher.broadcast_message(op_code, message.data, state.player_presences, message.sender)
        end

    end

    -- -- [TODO] Remove after testing the client connection
    -- if state.tick_counter > 10 then
    --     state.tick_counter = 0
    --     local message = { ["current_tick"] = tick }
    --     dispatcher.broadcast_message(OpCodes.manual_debug, nakama.json_encode(message), nil, nil)
    -- else
    --     state.tick_counter = state.tick_counter + 1
    -- end
    
    return state
end

-- @brief Called when the server begins a graceful shutdown process
-- @param context       Table with contextual information such as the caller of the function
-- @param dispatcher    Provides broadcast to clients functionality (broadcast_message, match_kick, match_label_update)
-- @param tick          Current match tick
-- @param state         `state` table
-- @param grace_seconds The number of seconds provided to complete a graceful termination before a match is forcefully closed.
-- Source https://heroiclabs.com/docs/nakama/server-framework/lua-runtime/function-reference/match-handler/#match_terminate
function world_control.match_terminate(context, dispatcher, tick, state, grace_seconds)
    return state
end

-- @brief Called when the match handler receives a runtime signal.
-- Has several uses, one of them is to receive a "reservation" signal before a Users atempt to join a match
-- @param context       Table with contextual information such as the caller of the function
-- @param dispatcher    Provides broadcast to clients functionality (broadcast_message, match_kick, match_label_update)
-- @param tick          Current match tick
-- @param state         `state` table
-- @param data          An arbitrary input supplied by the runtime caller of the signal.
-- Source https://heroiclabs.com/docs/nakama/server-framework/lua-runtime/function-reference/match-handler/#match_signal
function world_control.match_signal(context, dispatcher, tick, state, data)
    return state, data
end

-- nakama.logger_info("Exited module 'world_control.lua'")

return world_control