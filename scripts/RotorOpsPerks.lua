--need to remove dead/left players from players table (else functions utilizing playersByGroupName will be bugged such as scorePoints)
--mark.initiator.id_ == player_unit.id_  we find marks and position based on the first player in a group...maybe this is not what we want to do
--perks objects should have a reference to the function to call and pass args

RotorOpsPerks = {}
RotorOpsPerks.version = "1.0"
trigger.action.outText('RotorOpsPerks started: '..RotorOpsPerks.version, 5)

RotorOpsPerks.players = {} --by group name
RotorOpsPerks.troops_blue = {} --by group name

RotorOpsPerks.points = {
    player_default=4000,
    kill=10,
    kill_inf=5,
    kill_heli=20,
    kill_plane=20,
    kill_armor=15,
    kill_ship=15,
    cas_bonus=5, --you were in proximity of your troops killing something
    dropped_troops_kill_inf=5, --your troops killed infantry
    dropped_troops_kill=10, --your troops killed something
    dropped_troops_kill_armor=15, --your troops killed armor
    rearm=10, --ctld rearm/repair of ground units
    unpack=10, --ctld unpack of ground units
}


RotorOpsPerks.perks = {}

--Fat Cow FARP requires static farp objects to work (they are teleported to the landing zone), and a late activated helicopter called 'FAT COW'.  See a generated RotorOps mission for reference
RotorOpsPerks.perks["fatcow"] = {
    perk_name='fatcow',
    display_name='FatCow FARP',
    cost=100,
    cooldown=0,
    max_per_player=1,
    max_per_mission=4,
    last_used=0,
    used=0,
}

RotorOpsPerks.perks["strike"] = {
    perk_name='strike',
    display_name='Instant Strike',
    cost=50,
    cooldown=0,
    max_per_player=5,
    max_per_mission=3,
    last_used=0,
    used=0,
}



function RotorOpsPerks.getPlayerGroupSum(player_group_name, player_attribute, table_name)
    --loop through RotorOpsPerks.playersByGroupName
    local players = RotorOpsPerks.playersByGroupName(player_group_name)
    if not players then
        return false
    end

    local total = 0
    for _, player in pairs(players) do
        if table_name then
            total = total + (player[table_name][player_attribute] or 0)
        else
            total = total + (player[player_attribute] or 0)
        end
    end
    return total

end

-- function RotorOpsPerks.getGroupPoints(player_group_name)
--     --loop through RotorOpsPerks.playersByGroupName
--     local players = RotorOpsPerks.playersByGroupName(player_group_name)
--     if not players then
--         return false
--     end
    

--     local total_points = 0
--     for _, player in pairs(players) do
--         total_points = total_points + player.points
--     end
--     return total_points

-- end

function RotorOpsPerks.spendPoints(player_group_name, points)
    local players = RotorOpsPerks.playersByGroupName(player_group_name)
    local total_points = RotorOpsPerks.getPlayerGroupSum(player_group_name, "points")
    --if players have enough combined points
    if total_points < points then
        return false
    end

    --divide points by the number of players to get an integer
    local points_per_player = math.floor(points/#players)

    --subtract points from each player equally. If a player doesn't have enough points, subtract the remainder from the next player
    local remainder = 0
    for _, player in pairs(players) do
        local points_to_subtract = points_per_player + remainder
        if player.points < points_to_subtract then
            remainder = points_to_subtract - player.points
            player.points = 0
        else
            player.points = player.points - points_to_subtract
            remainder = 0
        end
    end

    return true
end

function RotorOpsPerks.scorePoints(player_group_name, points, message)
    --score points for all players in the group
    local players = RotorOpsPerks.playersByGroupName(player_group_name)
    if players then
        for _, player in pairs(players) do
            player.points = player.points + points
        end
        if message then
            local total = RotorOpsPerks.getPlayerGroupSum(player_group_name, "points")
            if #players > 1 then
                message = message.." +"..points.." points (" .. total .. " group total)"
            else
                message = message.." +"..points.." points (" .. total .. ")"
            end
            trigger.action.outTextForGroup(Group.getByName(player_group_name):getID(), message, 10)
        end
    end
    
end

function RotorOpsPerks.checkPoints(player_group_name)
    local groupId = Group.getByName(player_group_name):getID()
    local players = RotorOpsPerks.playersByGroupName(player_group_name)
    if not players then
        return false
    end

    --get combined points from all Players
    local total_points = 0
    for _, player in pairs(players) do
        total_points = total_points + player.points
    end
    if #players == 1 then
        trigger.action.outTextForGroup(groupId, 'You have ' .. total_points .. ' points.', 10)
    else 
       trigger.action.outTextForGroup(groupId, 'Your group has ' .. total_points .. ' total points.', 10)
    end
end


function RotorOpsPerks.updatePlayer(identifier, groupName)
    local groupId = Group.getByName(groupName):getID()

    
    --add a new player
    if not RotorOpsPerks.players[identifier] then
        RotorOpsPerks.players[identifier] = {
            points = RotorOpsPerks.points.player_default,
            groupId = groupId,
            groupName = groupName,
            menu = {},
            perks_used = {},
        }
        env.warning('ADDED ' .. identifier .. ' TO PLAYERS TABLE')
        missionCommands.removeItemForGroup(groupId, {[1] = 'ROTOROPS PERKS'})
        RotorOpsPerks.addRadioMenuForGroup(groupName)
    
    --update an existing player
    elseif RotorOpsPerks.players[identifier].groupId ~= groupId then
        env.warning('UPDATING ' .. identifier .. ' TO GROUP NAME: ' .. groupName)
        
        RotorOpsPerks.players[identifier].groupId = groupId
        RotorOpsPerks.players[identifier].groupName = groupName

        --REMOVE RADIO ITEMS FOR GROUP (since another player may have been in the group previously)
        -- missionCommands.removeItemForGroup(groupId, RotorOpsPerks.players[identifier].menu.root)
        missionCommands.removeItemForGroup(groupId, {[1] = 'ROTOROPS PERKS'})
        RotorOpsPerks.addRadioMenuForGroup(groupName)
    end
end

--returns a table of players matching the group name
function RotorOpsPerks.playersByGroupName(group_name)
    local players = {}
    for identifier, player in pairs(RotorOpsPerks.players) do
        if player.groupName == group_name then
            players[#players + 1] = player
        end
    end
    return players
end


function RotorOpsPerks.addRadioMenuForGroup(groupName)
    local groupId = Group.getByName(groupName):getID()

    local function addPerkCommand(groupId, groupName, perk_name, path, vars)
        local perk = RotorOpsPerks.perks[perk_name]
        missionCommands.addCommandForGroup(groupId, 'Request '.. perk.display_name .. ' at ' .. vars.target, path , RotorOpsPerks.requestPerk, {player_group_name=groupName, perk_name=perk_name, target=vars.target})
    end

    -- local menu = RotorOpsPerks.players[identifier]['menu']
    -- menu["root"] = missionCommands.addSubMenuForGroup(groupId, 'ROTOROPS PERKS')
    -- env.info(mist.utils.tableShow(menu.root, 'menu root'))
    local menu_root = missionCommands.addSubMenuForGroup(groupId, 'ROTOROPS PERKS')
    -- missionCommands.addCommandForGroup(groupId, 'Check points balance', menu["root"] , RotorOpsPerks.checkPoints, groupName)
    missionCommands.addCommandForGroup(groupId, 'Check points balance', menu_root, RotorOpsPerks.checkPoints, groupName)
    addPerkCommand(groupId, groupName, 'fatcow', menu_root, {target='position'})
    addPerkCommand(groupId, groupName, 'fatcow', menu_root, {target='mark'})
    addPerkCommand(groupId, groupName, 'strike', menu_root, {target='mark'})
    -- addPerkCommand(groupId, groupName, 'fatcow', menu["root"], {target='position'})
    -- addPerkCommand(groupId, groupName, 'fatcow', menu["root"], {target='mark'})
    -- addPerkCommand(groupId, groupName, 'strike', menu["root"], {target='mark'})

end


-- onplayerchangeslot, add player to RotorOpsPerks.players
function RotorOpsPerks.onPlayerChangeSlot(id)
    local msg = {}
    msg.command = 'onPlayerChangeSlot'
    msg.id = id
    msg.ucid = net.get_player_info(id, 'ucid')
    msg.name = net.get_player_info(id, 'name')
    msg.side = net.get_player_info(id, 'side')
    msg.unit_type, msg.slot, msg.sub_slot = utils.getMulticrewAllParameters(id)
    msg.unit_name = DCS.getUnitProperty(msg.slot, DCS.UNIT_NAME)
    msg.group_name = DCS.getUnitProperty(msg.slot, DCS.UNIT_GROUPNAME)
    msg.group_id = DCS.getUnitProperty(msg.slot, DCS.UNIT_GROUP_MISSION_ID)
    msg.unit_callsign = DCS.getUnitProperty(msg.slot, DCS.UNIT_CALLSIGN)
    msg.active = true
    env.info(mist.utils.tableShow(msg, 'onPlayerChangeSlot'))
end




function teleportStatic(source_name, dest_point)
    env.info('teleportStatic: ' .. source_name)
    local source = StaticObject.getByName(source_name)
    if not source then
        env.info('teleportStatic: source not found: ' .. source_name)
        return
    end
    local vars = {} 
    vars.gpName = source_name
    vars.action = 'teleport' 
    vars.point = mist.utils.makeVec3(dest_point)
    local res = mist.teleportToPoint(vars)
    if res then
        env.info('teleportStatic: ' .. source_name .. ' success')
    else
        env.info('teleportStatic: ' .. source_name .. ' failed')
    end
end

function spawnFatCowFarpObjects(pt_x, pt_y, index)
    env.info('spawnFatCowFarpObjects called. Looking for static group names ending in ' .. index)
    local dest_point = mist.utils.makeVec3GL({x = pt_x, y = pt_y})
    trigger.action.smoke(dest_point, 2)

    trigger.action.outText('FatCow FARP deploying...get clear of the landing zone!', 20)
    timer.scheduleFunction(function()
        local fuel_point = {x = dest_point.x + 35, y = dest_point.y, z = dest_point.z}
        teleportStatic('FAT COW FUEL ' .. index, fuel_point)
        teleportStatic('FAT COW TENT ' .. index, fuel_point)
        
        local ammo_point = {x = dest_point.x - 35, y = dest_point.y, z = dest_point.z}
        teleportStatic('FAT COW AMMO ' .. index, ammo_point)
        
    end, nil, timer.getTime() + 235)
end


function spawnFatCow(dest_point, index)
    local fatcow_name = 'FAT COW'
    local source_farp_name = 'FAT COW FARP ' .. index
    
    env.info('spawnFatCow called with ' .. source_farp_name)
    dest_point = mist.utils.makeVec2(dest_point)
    local approach_point = mist.getRandPointInCircle(dest_point, 1000, 900)
    --trigger.action.smoke(mist.utils.makeVec3GL(approach_point), 1)
    trigger.action.smoke(mist.utils.makeVec3GL(dest_point), 2)
    
    
    local fatcow_group = Group.getByName(fatcow_name)
    if not fatcow_group then
        env.warning('FatCow group not found')
        return
    end

    teleportStatic(source_farp_name, dest_point)

    local airbasefarp = Airbase.getByName(source_farp_name)
    if not airbasefarp then
        env.warning('FatCow FARP not found: ' .. source_farp_name)
        return
    end

    local airbase_pos = mist.utils.makeVec2(airbasefarp:getPoint())


    local script =  [[
        spawnFatCowFarpObjects(]] .. dest_point.x ..[[,]] .. dest_point.y .. [[,]] .. index .. [[)
        env.info('FatCow FARP deployment scheduled')
    ]]   


    local myscriptaction = {
        id = 'WrappedAction',
        params = {
          action = {
            id = 'Script',
            params = {
              command = script,  
    
            },
          },
        },
      }
    
    local script_string = [[local this_grp = ...
    this_grp:getController():setOption(AI.Option.Air.id.REACTION_ON_THREAT , AI.Option.Air.val.REACTION_ON_THREAT.EVADE_FIRE)
    this_grp:getController():setOption(AI.Option.Air.id.FLARE_USING , AI.Option.Air.val.FLARE_USING.WHEN_FLYING_NEAR_ENEMIES)]]

    local setOptions = {
    id = 'WrappedAction',
    params = {
        action = {
        id = 'Script',
        params = {
            command = script_string,

        },
        },
    },
    }


    local group = Group.getByName(fatcow_name)
    local initial_point = group:getUnits()[1]:getPoint()
    local gp = mist.getGroupData(fatcow_name)
    --debugTable(gp)


    gp.route = {points = {}}
    gp.route.points[1] = mist.heli.buildWP(initial_point, initial, 'flyover', 0, 0, 'agl')
    gp.route.points[2] = mist.heli.buildWP(initial_point, initial, 'flyover', 150, 100, 'agl')
    gp.route.points[2].task = setOptions

    gp.route.points[3] = mist.heli.buildWP(approach_point, 'flyover', 150, 400, 'agl') 
    gp.route.points[4] = mist.heli.buildWP(approach_point, 'flyover', 20, 200, 'agl') 
    gp.route.points[5] = mist.heli.buildWP(dest_point, 'turning point', 10, 70, 'agl') 
    gp.route.points[5].task = myscriptaction
    gp.route.points[6] = {
        alt = 70,
        alt_type = "RADIO",
        speed = 10,
        x = airbase_pos.x,
        y = airbase_pos.y,
        helipadId = airbasefarp:getID(), 
        aerodromeId = airbasefarp:getID(),
        type = "Land",
        action = "Landing",
    } 


    gp.clone = true
    local new_group_data = mist.dynAdd(gp)
end

function RotorOpsPerks.requestStrike(args, dest_point)
    --explosion at dest_point after 10 seconds
    timer.scheduleFunction(function()
        trigger.action.explosion(dest_point, 1000)
    end, nil, timer.getTime() + 10)
end
    

function RotorOpsPerks.requestFatCow(args, dest_point)
    local player_group = Group.getByName(args.player_group_name)
    local index = RotorOpsPerks.perks.fatcow.used + 1
    spawnFatCow(dest_point, index)
end

function RotorOpsPerks.requestPerk(args)
    env.info('requestPerk called for ' .. args.perk_name)
    --env.info(mist.utils.tableShow(args, 'args'))
    local player_group = Group.getByName(args.player_group_name)
    local player_unit = player_group:getUnits()[1]
    local player_pos = player_unit:getPoint()
    local players = RotorOpsPerks.playersByGroupName(args.player_group_name)
    if not players then
        env.warning('No players found in group ' .. args.player_group_name)
        return
    end

    --get the perk object
    local perk = RotorOpsPerks.perks[args.perk_name]

    --find the intended point
    local target_point = nil
    if args.target == 'position' then
        target_point = player_pos

    elseif args.target == 'mark' then
        local temp_mark = nil

        for _, mark in pairs(mist.DBs.markList) do
            --env.info('mark: ' .. mist.utils.tableShow(mark, 'mark'))
            --env.info('player group' .. mist.utils.tableShow(player_group, 'player_group'))
            --env.info('player' .. mist.utils.tableShow(player_unit, 'player_unit'))
            local perk_name_matches = false

            --determine if mark name matches the perk name
            local mark_name = mark.text
            --remove whitespace and new line from mark name
            mark_name = mark_name:gsub("%s+", "")
            mark_name = mark_name:gsub("%n+", "")
            if mark_name == args.perk_name then
                perk_name_matches = true
            end
            
            if perk_name_matches then
                --if MULTIPLAYER (initiator property missing in single player)
                if mark.initiator then
                    --if mark is from player's group
                    if mark.initiator.id_ == player_unit.id_ then
                        target_point = mark.pos
                        if temp_mark then
                            --if there is already a mark from the player's group, use the most recent one
                            if mark.time > temp_mark.time then
                                temp_mark = mark
                            end
                        else
                            temp_mark = mark
                        end
                    end
                
                else --we assume single player
                    if temp_mark then
                        --if there is already a mark from the player's group, use the most recent one
                        if mark.time > temp_mark.time then
                            temp_mark = mark
                        end
                    else
                        temp_mark = mark
                    end
                end

            end
        end
        --env.info(mist.utils.tableShow(mist.DBs.markList, 'markList'))
        if temp_mark then
            target_point = temp_mark.pos
        end

    end

    -- check if max_per_player is reached
    -- if RotorOpsPerks.players[args.identifier].perks_used[args.perk_name] and RotorOpsPerks.players[args.identifier].perks_used[args.perk_name] >= perk.max_per_player then
    --     trigger.action.outTextForGroup(player_group:getID(), 'UNABLE. You already used this perk ' .. perk.max_per_player .. ' times.', 10)
    --     env.info('max_per_player reached for ' .. args.perk_name)
    --     return
    -- end

    local perk_used_count = RotorOpsPerks.getPlayerGroupSum(args.player_group_name, args.perk_name, "perks_used")
    if perk_used_count >= (perk.max_per_player*#players) then --multiply by number of players in group
        if #players > 1 then
            trigger.action.outTextForGroup(player_group:getID(), 'UNABLE. You already used this perk ' .. perk_used_count .. ' times.', 10)
        else
            trigger.action.outTextForGroup(player_group:getID(), 'UNABLE. Your group already used this perk ' .. perk_used_count .. ' times.', 10)
        end
        env.info('max_per_group reached for ' .. args.perk_name)
        return
    end

    -- check if the max per mission has been reached
    if perk.max_per_mission ~= nil then
        if perk.used >= perk.max_per_mission then
            env.info(args.player_group_name.. ' requested ' .. args.perk_name .. ' but max per mission reached')
            trigger.action.outTextForGroup(player_group:getID(), 'UNABLE. Used too many times in the mission.', 10)
            return
        end
    end

    --check if position requirements for action are met    
    if args.target == "mark" then
        if not target_point then
            env.info(args.player_group_name.. ' requested ' .. args.perk_name .. ' but no target was found')
            trigger.action.outTextForGroup(player_group:getID(), 'UNABLE. Add a mark called "' .. args.perk_name .. '" to the F10 map first', 10)
            return
        end
    end


    --check if cooldown is over in perks object
    if perk.cooldown > 0 then
        if perk.last_used + perk.cooldown > timer.getTime() then
            local time_remaining = perk.last_used + perk.cooldown - timer.getTime()
            --round time_remaining
            time_remaining = math.floor(time_remaining + 0.5)
            env.info(args.player_group_name.. ' tried to use ' .. args.perk_name .. ' but cooldown was not over')
            trigger.action.outTextForGroup(player_group:getID(), 'UNABLE. Wait for '.. time_remaining .. ' seconds.', 10)
            return
        end
    end



    --spend points
    if RotorOpsPerks.spendPoints(args.player_group_name, perk.cost)
        then
            env.info(args.player_group_name.. ' spent ' .. perk.cost .. ' points for ' .. args.perk_name)
        else
            env.info(args.player_group_name.. ' tried to spend ' .. perk.cost .. ' points for ' .. args.perk_name .. ' but did not have enough points')
            if #players == 1 then
                trigger.action.outTextForGroup(player_group:getID(), 'NEGATIVE. You have ' .. RotorOpsPerks.getPlayerGroupSum(args.player_group_name, "points") .. ' points. (cost '.. perk.cost .. ')', 10)
            else
                trigger.action.outTextForGroup(player_group:getID(), 'NEGATIVE. Your group has ' .. RotorOpsPerks.getPlayerGroupSum(args.player_group_name, "total points") .. ' points. (cost '.. perk.cost .. ')', 10)
            end
            return
    end

    --perform the action
    if args.perk_name == RotorOpsPerks.perks.fatcow.perk_name then
        RotorOpsPerks.requestFatCow(args, target_point)
    elseif args.perk_name == RotorOpsPerks.perks.strike.perk_name then
        RotorOpsPerks.requestStrike(args, target_point)
    end

    --update last_used
    perk.last_used = timer.getTime()
    perk.used = perk.used + 1

    --increment player used for perk type, and initialize if it doesn't exist.
    local perk_user_per_player = 1/(#players or 1)
    --round perk_user_per_player to one decimal place
    perk_user_per_player = math.floor(perk_user_per_player*10 + 0.5)/10
    --loop through players
    for _, player in pairs(players) do
        if player.perks_used[args.perk_name] then
            player.perks_used[args.perk_name] = player.perks_used[args.perk_name] + perk_user_per_player
        else
            player.perks_used[args.perk_name] = perk_user_per_player
        end
    end

    --message players with humansByName DB
    for _player_name, _player in pairs(mist.DBs.humansByName) do
        local position_string = ' at ' .. RotorOpsPerks.BRString(target_point, _player.point)
        if _player.groupName == args.player_group_name then --if the player is the one who requested the perk
            if args.target == 'position' then
                position_string = ' at your position'
            end
            -- send affirmative message to the the requesting player
            trigger.action.outTextForGroup(_player.groupId, 'AFFIRM. ' .. RotorOpsPerks.perks[args.perk_name].display_name .. position_string, 10)
        else
            -- send messages to all other players
            env.info(player_unit:getPlayerName() .. ' requested ' .. RotorOpsPerks.perks[args.perk_name].display_name .. position_string)
            trigger.action.outTextForGroup(_player.groupId, player_unit:getPlayerName() .. ' requested ' .. RotorOpsPerks.perks[args.perk_name].display_name .. position_string, 10)
        end
    end
    
end

function RotorOpsPerks.BRString(point_a, point_b)
    point_a = mist.utils.makeVec3(point_a, 0)
    point_b = mist.utils.makeVec3(point_b, 0)
    local vec = {x = point_a.x - point_b.x, y = point_a.y - point_b.y, z = point_a.z - point_b.z}
    local dir = mist.utils.getDir(vec, point_b)
    local dist = mist.utils.get2DDist(point_a, point_b)
    local bearing = mist.utils.round(mist.utils.toDegree(dir), 0)
    local range_nm = mist.utils.round(mist.utils.metersToNM(dist), 0)
    local range_ft = mist.utils.round(mist.utils.metersToFeet(dist), 0)
    local br_string = ''
    if range_nm > 0 then
        br_string = bearing .. '° ' .. range_nm .. 'nm'
    else
        br_string = bearing .. '° ' .. range_ft .. 'ft'
    end
    return br_string
end

function RotorOpsPerks.findUnitsInVolume(args)
    local foundUnits = {}
    local volS = {
     id = args.volume_type,
     params = {
       point = args.point,
       radius = args.radius
     }
    }
   
    local ifFound = function(foundObject, val)
        foundUnits[#foundUnits + 1] = foundObject    
    end
    world.searchObjects(Object.Category.UNIT, volS, ifFound)
    return foundUnits
end


local handle = {}
function handle:onEvent(e)
    --env.info('event id: ' .. e.id)
    -- env.info(mist.utils.tableShow(e, 'all events'))

   
    --if enemy unit destroyed
    if e.id == world.event.S_EVENT_KILL then
        if e.initiator and e.target then
            if e.initiator:getCoalition() ~= e.target:getCoalition() then
                env.info('KILL: initiator groupname: ' .. e.initiator:getGroup():getName())

                local initiator_group_name = e.initiator:getGroup():getName()

                -- if initiator is a player's dropped troops
                local dropped_troops = RotorOpsPerks.troops_blue[e.initiator:getGroup():getName()]
                if dropped_troops then
                    if e.target:getDesc().category == Unit.Category.GROUND_UNIT == true then
                        if e.target:hasAttribute("Infantry") then
                            RotorOpsPerks.scorePoints(dropped_troops.player_group, RotorOpsPerks.points.dropped_troops_kill_inf, 'Your troops killed infantry!')
                        --else if target is armor
                        elseif e.target:hasAttribute("Tanks") then
                            RotorOpsPerks.scorePoints(dropped_troops.player_group, RotorOpsPerks.points.dropped_troops_kill_armor, 'Your troops killed armor!')
                        else
                            RotorOpsPerks.scorePoints(dropped_troops.player_group, RotorOpsPerks.points.dropped_troops_kill, 'Your troops killed a vehicle!')
                        end
                    end
                    
                end

                --if the initiator is a player
                if e.initiator:getPlayerName() then

                    --if target is a ground unit
                    if e.target:getDesc().category == Unit.Category.GROUND_UNIT == true then
                        if e.target:hasAttribute("Infantry") then
                            RotorOpsPerks.scorePoints(initiator_group_name, RotorOpsPerks.points.kill_inf, 'Killed infantry!')
                        elseif e.target:hasAttribute("Tanks") then
                            RotorOpsPerks.scorePoints(initiator_group_name, RotorOpsPerks.points.kill_armor, 'Killed armor!')
                        else
                            RotorOpsPerks.scorePoints(initiator_group_name, RotorOpsPerks.points.kill, 'Killed a vehicle!')
                        end
                    end

                    --if target is a helicopter
                    if e.target:getDesc().category == Unit.Category.HELICOPTER == true then
                        RotorOpsPerks.scorePoints(initiator_group_name, RotorOpsPerks.points.kill_heli, 'Killed a helicopter!')
                    end

                    --if target is a plane
                    if e.target:getDesc().category == Unit.Category.AIRPLANE == true then
                        RotorOpsPerks.scorePoints(initiator_group_name, RotorOpsPerks.points.kill_plane, 'Killed a plane!')
                    end

                    --if target is a ship
                    if e.target:getDesc().category == Unit.Category.SHIP == true then
                        RotorOpsPerks.scorePoints(initiator_group_name, RotorOpsPerks.points.kill_ship, 'Killed a ship!')
                    end



                    --CAS BONUS---

                    --we'll look for ground units in proximity to the player to apply a CAS bonus
                    local units_in_proximity = RotorOpsPerks.findUnitsInVolume({
                        volume_type = world.VolumeType.SPHERE,
                        point = e.initiator:getPoint(),
                        radius = 1852
                    })

                    local cas_bonus = false

                    for _, unit in pairs(units_in_proximity) do

                        --if we found friendly grund units near the player
                        if unit:getDesc().category == Unit.Category.GROUND_UNIT then                      
                            if unit:getCoalition() == e.initiator:getCoalition() then
                                cas_bonus = true
                            end
                        end
                    end

                    if cas_bonus then
                        RotorOpsPerks.scorePoints(e.initiator:getGroup():getName(), RotorOpsPerks.points.cas_bonus, '[CAS Bonus]')
                    end

                    --END CAS BONUS---
                end

                --end if the initiator is a player


                -- -- if the initiator is ground unit/infantry, we'll look for nearby players for a CAS bonus
                -- if e.initiator:getDesc().category == Unit.Category.GROUND_UNIT then
                --     local units_in_proximity = RotorOpsPerks.findUnitsInVolume({
                --         volume_type = world.VolumeType.SPHERE,
                --         point = e.initiator:getPoint(),
                --         radius = 1852
                --     })
                --     for _, unit in pairs(units_in_proximity) do
                --         --env.info('unit in proximity'.. mist.utils.tableShow(unit, 'unit'))
                --         local unit_group = unit:getGroup()
                --         if unit_group then
                --             --env.info('unit group'.. mist.utils.tableShow(unit_group, 'Unit_group'))
                --             local unit_group_name = unit_group:getName()
                --             local player_group = RotorOpsPerks.players[unit_group_name]
                --             --if the player found in proximity is the same coalition as the attacker                         
                --             if player_group and Group.getByName(unit_group_name):getCoalition() == e.initiator:getCoalition() then
                --                 RotorOpsPerks.scorePoints(unit_group_name, RotorOpsPerks.points.cas_bonus, '[Proximity Bonus]')
                --             end
                --         end
                --     end
                -- end

            end
        end
    end
end
world.addEventHandler(handle)

function RotorOpsPerks.registerCtldCallbacks()
    if not ctld then
        trigger.action.outText("CTLD Not Found", 10)
        return
    end

    --if ctld.callbacks does not exist yet, loop for 2 seconds until it does
    if not ctld.callbacks then
        timer.scheduleFunction(RotorOpsPerks.registerCtldCallbacks, nil, timer.getTime() + 1)
        env.warning('CTLD callbacks not loaded yet, trying again in 1 second')
        return
    end

	ctld.addCallback(function(_args)
		local action = _args.action
		local unit = _args.unit
		local picked_troops = _args.onboard
		local dropped_troops = _args.unloaded
		--env.info("ctld callback: ".. mist.utils.tableShow(_args)) 
        
        if dropped_troops then
            --env.info('dropped troops: ' .. mist.utils.tableShow(dropped_troops))
            --env.info('dropped troops group name: ' .. dropped_troops:getName())
            -- add dropped troops group to RotorOpsPerks.blue_troops
            RotorOpsPerks.troops_blue[dropped_troops:getName()] = {dropped_troops=dropped_troops:getName(), player_group=unit:getGroup():getName(), player_name=unit:getPlayerName(), player_unit=unit:getName(), qty=#dropped_troops:getUnits()}

        end

		  
		local playername = unit:getPlayerName()
		if playername then
			if action == "unload_troops_zone" or action == "dropped_troops" then

			elseif action == "rearm" or action == "repair" then
				RotorOpsPerks.scorePoints(unit:getGroup():getName(), RotorOpsPerks.points.rearm, 'Rearm/repair!')

			elseif action == "unpack" then
				RotorOpsPerks.scorePoints(unit:getGroup():getName(), RotorOpsPerks.points.unpack, 'Crates unpacked!')

			end
		end
	end)
end

function RotorOpsPerks.monitorPlayers()
    local player_names_str = ''
    for _unit_name, _player in pairs(mist.DBs.humansByName) do
        
        --env.info(mist.utils.tableShow(_player, 'player_unit: '.._unit_name))
        local player_unit = Unit.getByName(_player.unitName)
        if player_unit then
            local player_name = player_unit:getPlayerName() 
            --in multiplayer, humansByName includes all client aircraft, so we'll check if the unit has a playername 
            if player_name then
                RotorOpsPerks.updatePlayer(player_name, _player.groupName)
                player_names_str = player_names_str .. player_name .. ', '
            end
        end
        
    end
    --env.info('players: '..player_names_str)
    timer.scheduleFunction(RotorOpsPerks.monitorPlayers, nil, timer.getTime() + 2)
end

RotorOpsPerks.monitorPlayers()



RotorOpsPerks.registerCtldCallbacks()

