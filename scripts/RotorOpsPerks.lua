RotorOpsPerks = {}
RotorOpsPerks.version = "1.0"
trigger.action.outText('RotorOpsPerks started: '..RotorOpsPerks.version, 5)

RotorOpsPerks.players = {} --by group name
RotorOpsPerks.troops_blue = {} --by group name

RotorOpsPerks.points = {
    player_default=40,
    cas_bonus=5, --you were in proximity of your troops killing something
    dropped_troops_kill_inf=5, --your troops killed infantry
    dropped_troops_kill=10, --your troops killed something
    rearm=10, --ctld rearm/repair of ground units
    unpack=10, --ctld unpack of ground units
}


RotorOpsPerks.perks = {}

--Fat Cow FARP requires static farp objects to work (they are teleported to the landing zone), and a late activated helicopter called 'FAT COW'.  See a generated RotorOps mission for reference
RotorOpsPerks.perks["fatcow"] = {
    perk_name='fatcow',
    display_name='FatCow FARP',
    cost=100,
    cooldown=30,
    max_per_player=1,
    max_per_mission=2,
    last_used=0,
    used=0,
}

RotorOpsPerks.perks["strike"] = {
    perk_name='strike',
    display_name='Instant Strike',
    cost=50,
    cooldown=10,
    max_per_player=5,
    max_per_mission=3,
    last_used=0,
    used=0,
}

function RotorOpsPerks.spendPoints(player_group_name, points)
    if RotorOpsPerks.players[player_group_name] then
        if RotorOpsPerks.players[player_group_name].points >= points then
            RotorOpsPerks.players[player_group_name].points = RotorOpsPerks.players[player_group_name].points - points
            return true
        end
    end
end

function RotorOpsPerks.scorePoints(player_group_name, points, message)
    if RotorOpsPerks.players[player_group_name] then
        RotorOpsPerks.players[player_group_name].points = RotorOpsPerks.players[player_group_name].points + points
        if message then
            message = message .. ' +' .. points .. ' points'
            trigger.action.outTextForGroup(RotorOpsPerks.players[player_group_name].groupId, message, 10)
        end
    end
end

function RotorOpsPerks.checkPoints(player_group_name)
    if RotorOpsPerks.players[player_group_name] then
        trigger.action.outTextForGroup(RotorOpsPerks.players[player_group_name].groupId, 'You have ' .. RotorOpsPerks.players[player_group_name].points .. ' points.', 10)
    end
end


function RotorOpsPerks.addPlayers()

    local function addPerkCommand(groupId, groupName, perk_name, path, vars)
        local perk = RotorOpsPerks.perks[perk_name]
        missionCommands.addCommandForGroup(groupId, 'Request '.. perk.display_name .. ' at ' .. vars.target, path , RotorOpsPerks.requestPerk, {player_group_name=groupName, perk_name=perk_name, target=vars.target})
    end

    for uName, uData in pairs(mist.DBs.humansByName) do
        env.info('Player ' .. uName .. ' found')
        --env.info(mist.utils.tableShow(uData, 'uData'))
        player_group = Group.getByName(uData.groupName)
        if player_group and RotorOpsPerks.players[uData.unitName] == nil then
            RotorOpsPerks.players[uData.groupName] = {
                points = RotorOpsPerks.points.player_default,
                groupId = uData.groupId,
                groupName = uData.groupName,
                menu = {}
            }
            local menu = RotorOpsPerks.players[uData.groupName]['menu']
            menu["root"] = missionCommands.addSubMenuForGroup(uData.groupId, 'ROTOROPS PERKS')
            missionCommands.addCommandForGroup(uData.groupId, 'Check points balance', menu["root"] , RotorOpsPerks.checkPoints, uData.groupName)
            addPerkCommand(uData.groupId, uData.groupName, 'fatcow', menu["root"], {target='position'})
            addPerkCommand(uData.groupId, uData.groupName, 'fatcow', menu["root"], {target='mark'})
            addPerkCommand(uData.groupId, uData.groupName, 'strike', menu["root"], {target='mark'})
        end
        local player_unit = Unit.getByName(uData.unitName)
        if player_unit then

        end
    end
end


function teleportStatic(source_name, dest_point)
    local vars = {} 
    vars.gpName = source_name
    vars.action = 'teleport' 
    vars.point = mist.utils.makeVec3(dest_point)
    mist.teleportToPoint(vars)
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

    --get the perk object
    local perk = RotorOpsPerks.perks[args.perk_name]

    --find the intended point
    local target_point = nil
    if args.target == 'position' then
        target_point = player_pos

    elseif args.target == 'mark' then
        local temp_mark = nil

        for _, mark in pairs(mist.DBs.markList) do
            env.info('mark: ' .. mist.utils.tableShow(mark, 'mark'))
            env.info('player group' .. mist.utils.tableShow(player_group, 'player_group'))
            env.info('player' .. mist.utils.tableShow(player_unit, 'player_unit'))
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

    -- check if the max used limit has been reached
    if perk.max_used ~= nil then
        if perk.used >= perk.max_used then
            env.info(args.player_group_name.. ' requested ' .. args.perk_name .. ' but max used reached')
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
            trigger.action.outTextForGroup(player_group:getID(), 'NEGATIVE. You have ' .. RotorOpsPerks.players[args.player_group_name].points .. ' points. (cost '.. perk.cost .. ')', 10)
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
    --env.info(mist.utils.tableShow(e, 'all events'))
    
    --if enemy unit destroyed
    if e.id == world.event.S_EVENT_KILL then
        if e.initiator and e.target then
            if e.initiator:getCoalition() ~= e.target:getCoalition() then
                env.info('initiator groupname: ' .. e.initiator:getGroup():getName())
                --env.info('enemy unit destroyed')
                local initiator_group_name = e.initiator:getGroup():getName()

                -- if a player's dropped troops killed enemy unit
                local dropped_troops = RotorOpsPerks.troops_blue[e.initiator:getGroup():getName()]
                if dropped_troops then
                    if e.target:getDesc().category == Unit.Category.GROUND_UNIT == true then
                        if e.target:hasAttribute("Infantry") then
                            RotorOpsPerks.scorePoints(dropped_troops.player_group, RotorOpsPerks.points.dropped_troops_kill_inf, 'Your troops killed infantry!')
                        else
                            RotorOpsPerks.scorePoints(dropped_troops.player_group, RotorOpsPerks.points.dropped_troops_kill, 'Your troops killed vehicles!')
                        end
                    end
                    
                end

                -- if the initiator is ground unit/infantry, we'll look for nearby players for a CAS bonus
                if e.initiator:getDesc().category == Unit.Category.GROUND_UNIT then
                    local units_in_proximity = RotorOpsPerks.findUnitsInVolume({
                        volume_type = world.VolumeType.SPHERE,
                        point = e.initiator:getPoint(),
                        radius = 1852
                    })
                    for _, unit in pairs(units_in_proximity) do
                        env.info('unit in proximity'.. mist.utils.tableShow(unit, 'unit'))
                        local unit_group = unit:getGroup()
                        if unit_group then
                            env.info('unit group'.. mist.utils.tableShow(unit_group, 'Unit_group'))
                            local unit_group_name = unit_group:getName()
                            local player_group = RotorOpsPerks.players[unit_group_name]
                            if player_group then
                                RotorOpsPerks.scorePoints(unit_group_name, RotorOpsPerks.points.cas_bonus, '[Proximity Bonus]')
                            end
                        end
                    end
                end

            end
        end
    end
end
world.addEventHandler(handle)

function RotorOpsPerks.registerCtldCallbacks()
    if not ctld then
        trigger.action.outText("ERROR: CTLD Not Loaded!!", 90)
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



RotorOpsPerks.addPlayers()
RotorOpsPerks.registerCtldCallbacks()

