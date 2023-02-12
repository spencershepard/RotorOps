--ROTOROPS PERKS by GRIMM  
--Points and rewards system
--Check out RotorOps at dcs-helicopters.com
--Full documentation on Github (see the Wiki: RotorOps PERKS)

--How to use: load the script in do script trigger after the mission begins. Requires MIST, but CTLD is optional.  Load scripts in this order: 1) MIST 2) CTLD 3) RotorOpsPerks
--This script will add a new menu to the F10 menu called "RotorOps Perks".  This menu will allow you to select a perk to use.
--You can define the points earner per action, and the perk options below.

-- Issues:
-- - You will not get points for your troops' kills if you leave your group (ie switch aircraft)
-- - Currently requires a modified version of MIST (see rotorops repo /scripts)

--Todo:
 

RotorOpsPerks = {}
RotorOpsPerks.version = "1.5.2"
env.warning('ROTOROPS PERKS STARTED: '..RotorOpsPerks.version)
trigger.action.outText('ROTOROPS PERKS STARTED: '..RotorOpsPerks.version, 10)
RotorOpsPerks.perks = {}
RotorOpsPerks.players = {} 
RotorOpsPerks.players_temp = {} 
RotorOpsPerks.troops = {} --by group name
RotorOpsPerks.fat_cow_farps = {}

---- OPTIONS ----

RotorOpsPerks.silent_points = false --set to true to disable text on points scoring
RotorOpsPerks.player_update_messages = true --set to false to disable messages when players are added/updated to score keeping
RotorOpsPerks.debug = false

RotorOpsPerks.points = {
    player_default=0, --how many points each player will start with
    kill=10,
    kill_inf=5,
    kill_heli=20,
    kill_plane=20,
    kill_armor=15,
    kill_ship=15,
    cas_bonus=5, --you killed something in proximity of friendly troops
    dropped_troops_kill_inf=10, --your troops killed infantry
    dropped_troops_kill=20, --your troops killed a vehicle
    dropped_troops_kill_armor=30, --your troops killed armor
    rearm=15, --ctld rearm/repair of ground units
    unpack=15, --ctld unpack of ground units
}

RotorOpsPerks.player_fatcow_types = {
    "UH-60L",
    "Mi-8MT",
}

---- END OPTIONS ----
local function log(msg)
    env.info("ROTOROPS PERKS: " .. msg)
end


local function debugMsg(msg)
    if RotorOpsPerks.debug then
        log("ROTOROPS PERKS:")
        if msg then
            log(msg)
        end
    end
end


---- FATCOW PERK ----
--Fat Cow FARP requires static farp objects to work (they are teleported to the landing zone), and a late activated helicopter called 'FAT COW'.  See the wiki for more details.

RotorOpsPerks.perks["fatcow"] = {
    perk_name='fatcow',
    display_name='FatCow FARP',
    cost=150,
    cooldown=60,
    max_per_player=4,
    max_per_mission=4,
    at_mark=true,
    at_position=true,
    enabled=true,
    sides={0,1,2},
}

RotorOpsPerks.perks.fatcow["menu_condition"] = function(group_name)
    local player_unit = Group.getByName(group_name):getUnit(1)
    -- if player IS a fatcow, return false
    for _, unit_type in pairs(RotorOpsPerks.player_fatcow_types) do
        if player_unit:getDesc().typeName == unit_type then
            return false
        end
    end
    return true
end

RotorOpsPerks.perks.fatcow["action_condition"] = function(args)
    if #RotorOpsPerks.fat_cow_farps < 1 then
        return {msg="No FARP resources available!", valid=false}
    end

    --rearming/refueling doesn't work if enemies are nearby (within 1.1nm)
    --this is a DCS feature/limitation so we won't deploy the farp to avoid confusing the players
    local units_in_proximity = RotorOpsPerks.findUnitsInVolume({
        volume_type = world.VolumeType.SPHERE,
        point = args.target_point,
        radius = 2050
    })

    log("units_in_proximity: "..#units_in_proximity)

    local enemy_coal = 1
    if args.player_coalition == 1 then
        enemy_coal = 2
    end

    for _, unit in pairs(units_in_proximity) do
        if unit:getCoalition() == enemy_coal then
            return {msg="Too close to enemy!", valid=false}
        end
    end

    return {valid=true}
end

RotorOpsPerks.perks.fatcow["action_function"] = function(args)
    local index = RotorOpsPerks.perks.fatcow.used + 1
    local farp = table.remove(RotorOpsPerks.fat_cow_farps, 1) --get the first farp from the list
    if farp == nil then
        env.error("No FARP resources available!")
        return
    end
    RotorOpsPerks.spawnFatCow(args.target_point, farp)
    return true
end

---- End of FATCOW PERK ----



---- INSTANT STRIKE PERK ----
-- Here's a very simple example of how to create a Perk!

RotorOpsPerks.perks["strike"] = {
    perk_name='strike',
    display_name='Instant Strike',
    cost=150,
    cooldown=60,
    max_per_player=3,
    max_per_mission=10,
    at_mark=true,
    at_position=false,
    enabled=true,
    sides={0,1,2},
}

RotorOpsPerks.perks.strike["action_function"] = function(args)
    --explosion at dest_point after 10 seconds
    timer.scheduleFunction(function()
        trigger.action.explosion(args.target_point, 1000)
    end, nil, timer.getTime() + 10)
    return true
end

---- End of INSTANT STRIKE PERK ----


---- JTAC DRONE PERK ----

RotorOpsPerks.perks["drone"] = {
    perk_name='drone',
    display_name='JTAC Drone',
    cost=75,
    cooldown=60,
    max_per_player=3,
    max_per_mission=6,
    at_mark=true,
    at_position=false,
    enabled=true, 
    sides={0,1,2},
}


RotorOpsPerks.perks.drone["action_function"] = function(args)
    local player_country = Unit.getByName(args.player_unit_name):getCountry()

    --set a timer for one minute
    timer.scheduleFunction(function()
        local code = table.remove(ctld.jtacGeneratedLaserCodes, 1)
        RotorOpsPerks.spawnJtacDrone(args.target_point, player_country, code)
        table.insert(ctld.jtacGeneratedLaserCodes, code)
    end, nil, timer.getTime() + 60)
    return true
end

function RotorOpsPerks.spawnJtacDrone(dest_point, country, laser_code)
    
    local drone = {
        x = dest_point.x+1500,
        y = dest_point.z,
        type = "RQ-1A Predator",
        speed = 70,
        heading = 0,
        altitude = 5000,
        country = player_country,
        skill = "High",
        category = "plane",
        livery_id = "USAF Standard",
        payload = {
            ["pylons"] = {},
            ["fuel"] = 200,
            ["flare"] = 0,
            ["chaff"] = 0,
            ["gun"] = 0,
        },
    }

    local drone_route = {
        [1] = {
            ["alt"] = 5000,
            ["x"] = dest_point.x,
            ["action"] = "Turning Point",
            ["alt_type"] = "BARO",
            ["speed"] = 70,
            ["form"] = "Turning Point",
            ["type"] = "Turning Point",
            ["y"] = dest_point.z+1000,
        },
    }

    local drone_group = {
        units = {drone,},
        country = country,
        category = "airplane",
        route = drone_route,
    }

    local orbit = {
        id = 'Orbit', 
          params = { 
            pattern = 'Circle',
            point = {x = dest_point.x, y = dest_point.z},
            speed = 70,
            altitude = 5000,
        } 
    }


    local new_group = mist.dynAdd(drone_group)
    if new_group == nil then
        return
    end
    trigger.action.outText('JTAC DRONE IS ON STATION!', 10)

    --set a timer for one minute
    timer.scheduleFunction(function()
        Group.getByName(new_group.name):getController():setTask(orbit)
        Group.getByName(new_group.name):getController():setOption(AI.Option.Air.id.REACTION_ON_THREAT, AI.Option.Air.val.REACTION_ON_THREAT.NO_REACTION)
        local _code = table.remove(ctld.jtacGeneratedLaserCodes, 1)
        ctld.JTACAutoLase(new_group.name, table.remove(ctld.jtacGeneratedLaserCodes, 1), true, "vehicle")
        table.insert(ctld.jtacGeneratedLaserCodes, _code)
    end, nil, timer.getTime() + 60)

end


---- End of JTAC DRONE PERK ----


---- PLAYER FAT COW ----

RotorOpsPerks.perks["player_fatcow"] = {
    perk_name='player_fatcow',
    display_name='Player Fat Cow',
    cost=0,
    cooldown=0,
    at_mark=false,
    at_position=true,
    enabled=true,
    sides={0,1,2},
    active = {}, --holds a list of active fat cows
}

RotorOpsPerks.perks.player_fatcow["menu_condition"] = function(group_name)
    local player_unit = Group.getByName(group_name):getUnit(1)
    -- check if player unit is in list of our fat cow heli types
    for _, unit_type in pairs(RotorOpsPerks.player_fatcow_types) do
        if player_unit:getDesc().typeName == unit_type then
            return true
        end
    end
end

RotorOpsPerks.perks.player_fatcow["action_condition"] = function(args)
    local player_unit = Group.getByName(args.player_group_name):getUnit(1)
    local agl_altitude = player_unit:getPosition().p.y - land.getHeight(player_unit:getPosition().p)

    if RotorOpsPerks.perks.player_fatcow.active[args.player_group_name] then
        return {msg="FARP already deployed at your position!", valid=false}
    end

    if #RotorOpsPerks.fat_cow_farps < 1 then
        return {msg="No FARP resources available!", valid=false}
    end

    if agl_altitude > 100 then
        return {msg="You must be on the ground! "..agl_altitude.." AGL", valid=false}
    end

    --rearming/refueling doesn't work if enemies are nearby (within 1.1nm)
    --this is a DCS feature/limitation so we won't deploy the farp to avoid confusing the players
    local units_in_proximity = RotorOpsPerks.findUnitsInVolume({
        volume_type = world.VolumeType.SPHERE,
        point = args.target_point,
        radius = 2050
    })

    log("units_in_proximity: "..#units_in_proximity)

    local enemy_coal = 1
    if args.player_coalition == 1 then
        enemy_coal = 2
    end

    for _, unit in pairs(units_in_proximity) do
        if unit:getCoalition() == enemy_coal then
            return {msg="Too close to enemy!", valid=false}
        end
    end
        
    
    return {msg="Stay on the ground.", valid=true}
end

RotorOpsPerks.perks.player_fatcow["action_function"] = function(args)
    local farp = table.remove(RotorOpsPerks.fat_cow_farps)
    if farp == nil then
        env.error("No FARP resources available!")
        return
    end
    RotorOpsPerks.teleportStatic('FAT COW FARP ' .. farp.index, {x=args.target_point.x, y=args.target_point.z}) 
    RotorOpsPerks.spawnFatCowFarpObjects(args.target_point.x, args.target_point.z, farp.index, 15)
    args.farp = farp
    RotorOpsPerks.perks.player_fatcow.active[args.player_group_name] = true
    RotorOpsPerks.perks.player_fatcow.monitor_player(args)
    return true
end

RotorOpsPerks.perks.player_fatcow["monitor_player"] = function(args)
    local despawn_farp = false
    if Group.getByName(args.player_group_name) then

        local player_unit = Group.getByName(args.player_group_name):getUnit(1)
        local agl_altitude = player_unit:getPosition().p.y - land.getHeight(player_unit:getPosition().p)
        if agl_altitude > 100 or not player_unit:isExist() then
            despawn_farp = true
            log("Player is no longer on the ground, despawning FARP!")
        end
        if math.abs(player_unit:getPosition().p.x - args.target_point.x) > 50 or math.abs(player_unit:getPosition().p.z - args.target_point.z) > 50 then
            log("Player has moved from target position, despawning FARP!")
            despawn_farp = true
        end
    else
        despawn_farp = true
    end

    if despawn_farp then
        RotorOpsPerks.despawnFatCowFarp(args.farp)
        RotorOpsPerks.perks.player_fatcow.active[args.player_group_name] = nil
        if Group.getByName(args.player_group_name) then
            trigger.action.outTextForGroup(Group.getByName(args.player_group_name):getID(), "FARP despawned.", 10)
        end
    else
        timer.scheduleFunction(RotorOpsPerks.perks.player_fatcow.monitor_player, args, timer.getTime() + 2)
    end
end


function RotorOpsPerks.despawnFatCowFarp(farp)
    RotorOpsPerks.teleportStatic('FAT COW FARP '..farp.index, {x=farp.farp_p.x, y=farp.farp_p.z}) 
    RotorOpsPerks.teleportStatic('FAT COW TENT '..farp.index, {x=farp.tent_p.x, y=farp.tent_p.z}) 
    RotorOpsPerks.teleportStatic('FAT COW AMMO '..farp.index, {x=farp.ammo_p.x, y=farp.ammo_p.z}) 
    RotorOpsPerks.teleportStatic('FAT COW FUEL '..farp.index, {x=farp.fuel_p.x, y=farp.fuel_p.z}) 
    table.insert(RotorOpsPerks.fat_cow_farps, 1, farp) --put back in list at the begining to be reused
end


---- End of PLAYER FAT COW ----

---- FLARE PERK ----

RotorOpsPerks.perks["flare"] = {
    perk_name='flare',
    display_name='Illumination Flare',
    cost=15,
    cooldown=0,
    at_mark=true,
    at_position=false,
    enabled=true,
    sides={0,1,2},
}

RotorOpsPerks.perks.flare["action_function"] = function(args)
    args.target_point.y = args.target_point.y + 600
    trigger.action.illuminationBomb(args.target_point, 1000000)
    return true
end

---- End of FLARE PERK ----


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


function RotorOpsPerks.spendPoints(player_group_name, points, deduct_points)
    local players = RotorOpsPerks.playersByGroupName(player_group_name)
    local total_points = RotorOpsPerks.getPlayerGroupSum(player_group_name, "points")
    --if players have enough combined points
    if total_points < points then
        --there was insufficient points
        return false
    end

    --this function can be called to check points and/or deduct points
    if deduct_points then
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
    end
    --there was sufficient points
    return true
end

function RotorOpsPerks.scorePoints(player_group_name, points, message)
    --score points for all players in the group
    local players = RotorOpsPerks.playersByGroupName(player_group_name)
    if players then
        for _, player in pairs(players) do
            player.points = player.points + points
        end
        if message and not RotorOpsPerks.silent_points then
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

    log("Checking points for "..player_group_name.."...")
    log(mist.utils.tableShow(players, "players"))

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

function RotorOpsPerks.buildPlayer(identifier, groupName, name, slot, temp_id)
    -- if we're missing any of the required attributes, add to temp table until we collect all attributes
    if not groupName or not name or not slot then
        --create the temp player object if doesn't exist yet
        if not RotorOpsPerks.players_temp[temp_id] then
            RotorOpsPerks.players_temp[temp_id] = {
                identifier=identifier,
                name=name,
                slot=slot,
                groupName = groupName,
            }
        end
        --store individual attributes if available
        RotorOpsPerks.players_temp[temp_id].identifier = identifier or RotorOpsPerks.players_temp[temp_id].identifier
        RotorOpsPerks.players_temp[temp_id].name = name or RotorOpsPerks.players_temp[temp_id].name
        RotorOpsPerks.players_temp[temp_id].slot = slot or RotorOpsPerks.players_temp[temp_id].slot
        RotorOpsPerks.players_temp[temp_id].groupName = groupName or RotorOpsPerks.players_temp[temp_id].groupName
        --reassign the function args
        identifier = RotorOpsPerks.players_temp[temp_id].identifier
        name = RotorOpsPerks.players_temp[temp_id].name
        slot = RotorOpsPerks.players_temp[temp_id].slot
        groupName = RotorOpsPerks.players_temp[temp_id].groupName
        --if we're still missing attributes, return
        if not groupName or not name or not slot or not identifier then
            -- env.warning('MISSING ATTRIBUTES FOR ' .. temp_id)
            debugMsg(mist.utils.tableShow(RotorOpsPerks.players_temp[temp_id]))
            return
        end

        --we have all we need, so add to the players table
        debugMsg('BUILDPLAYER: Now adding ' .. temp_id .. ' to players table as ' .. identifier)
        RotorOpsPerks.updatePlayer(identifier, groupName, name, slot)

    end
end


function RotorOpsPerks.updatePlayer(identifier, groupName, name, slot)
    if not Group.getByName(groupName) then
        env.warning('GROUP ' .. groupName .. ' DOES NOT EXIST')
        return
    end

    local groupId = Group.getByName(groupName):getID()
    local side = Group.getByName(groupName):getCoalition()

    
    --add a new player
    if not RotorOpsPerks.players[identifier] then
        RotorOpsPerks.players[identifier] = {
            name=name,
            slot=slot,
            points = RotorOpsPerks.points.player_default,
            groupId = groupId,
            groupName = groupName,
            side = side,
            menu = {},
            perks_used = {},
        }
        env.warning('ADDED ' .. identifier .. ' TO PLAYERS TABLE')
        log(mist.utils.tableShow(RotorOpsPerks.players[identifier]))
        missionCommands.removeItemForGroup(groupId, {[1] = 'ROTOROPS PERKS'})
        RotorOpsPerks.addRadioMenuForGroup(groupName)
        if RotorOpsPerks.player_update_messages then
            trigger.action.outText('PERKS: Added ' .. name .. ' to '.. groupName, 10)
        end
    
    --update an existing player
    elseif RotorOpsPerks.players[identifier].groupId ~= groupId then
        env.warning('UPDATING ' .. identifier .. ' TO GROUP NAME: ' .. groupName)
        log(mist.utils.tableShow(RotorOpsPerks.players[identifier]))
        if RotorOpsPerks.player_update_messages then
            trigger.action.outText('PERKS: ' .. name .. ' moved to '.. groupName, 10)
        end
        
        --update player
        RotorOpsPerks.players[identifier].groupId = groupId
        RotorOpsPerks.players[identifier].groupName = groupName
        RotorOpsPerks.players[identifier].side = side
        RotorOpsPerks.players[identifier].slot = slot
        RotorOpsPerks.players[identifier].name = name


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
    local group_side = Group.getByName(groupName):getCoalition()

    local menu_root = missionCommands.addSubMenuForGroup(groupId, 'ROTOROPS PERKS')
    missionCommands.addCommandForGroup(groupId, 'Check points balance', menu_root, RotorOpsPerks.checkPoints, groupName)

    for perk_name, perk in pairs(RotorOpsPerks.perks) do

        local avail_for_side = false
        local avail_for_group = true
        if perk.menu_condition ~= nil then
            avail_for_group = perk.menu_condition(groupName)
        end
        for _, side in pairs(perk.sides) do
            if group_side == side then
                avail_for_side = true
            end
        end


        if perk.enabled and avail_for_side and avail_for_group then 
            if perk.at_mark then
                --addPerkCommand(groupId, groupName, perk, menu_root, {target='mark'})
                missionCommands.addCommandForGroup(groupId, perk.display_name .. ' at mark (' .. perk.perk_name ..')', menu_root , RotorOpsPerks.requestPerk, {player_group_name=groupName, perk_name=perk.perk_name, target='mark'})
            end
            if perk.at_position then
                --addPerkCommand(groupId, groupName, perk, menu_root, {target='position'})
                missionCommands.addCommandForGroup(groupId, perk.display_name .. ' on me', menu_root , RotorOpsPerks.requestPerk, {player_group_name=groupName, perk_name=perk.perk_name, target='position'})
            end
        end
    end

end

---- FATCOW FARP SUPPORTING FUNCTIONS ----

function RotorOpsPerks.monitorFarps()
    --log(mist.utils.tableShow(RotorOpsPerks.fat_cow_farps))

    local function farpExists(i)
        local farp = StaticObject.getByName('FAT COW FARP ' .. i)
        local tent = StaticObject.getByName('FAT COW TENT ' .. i)
        local ammo = StaticObject.getByName('FAT COW AMMO ' .. i)
        local fuel = StaticObject.getByName('FAT COW FUEL ' .. i)
        if farp:isExist() and tent:isExist() and ammo:isExist() and fuel:isExist() then
            return true
        else
            return false
        end
    end

    --schedule the function
    timer.scheduleFunction(RotorOpsPerks.monitorFarps, nil, timer.getTime() + 11)
    --loop over RotorOpsPerks.fat_cow_farps
    for i, farp in pairs(RotorOpsPerks.fat_cow_farps) do
        --check if farp is damaged/destroyed
        if not farpExists(i) then
            trigger.action.outText('Some FARP resources have been destroyed', 30)
            env.warning('FAT COW FARP ' .. i .. ' RESOURCES DESTROYED')
            RotorOpsPerks.fat_cow_farps[i] = nil
        end
    end
end

function RotorOpsPerks.buildFatCowFarpTable()
    local farp_found=true
    local i = 1
    while(farp_found) do
        --find static invisible farps that start with name 'FAT COW FARP'
        local farp = StaticObject.getByName('FAT COW FARP ' .. i)
        local tent = StaticObject.getByName('FAT COW TENT ' .. i)
        local ammo = StaticObject.getByName('FAT COW AMMO ' .. i)
        local fuel = StaticObject.getByName('FAT COW FUEL ' .. i)
        if farp and tent and ammo and fuel then
            log("FAT COW FARP " .. i .. " FOUND")
            RotorOpsPerks.fat_cow_farps[i] = {
                index = i,
                farp = farp,
                farp_p = farp:getPosition().p,
                tent = tent,
                tent_p = tent:getPosition().p,
                ammo = ammo,
                ammo_p = ammo:getPosition().p,
                fuel = fuel,
                fuel_p = fuel:getPosition().p,
            }
            i = i + 1
        else
            farp_found = false
        end
    end
end


    



function RotorOpsPerks.teleportStatic(source_name, dest_point)
    debugMsg('RotorOpsPerks.teleportStatic: ' .. source_name)
    local source = StaticObject.getByName(source_name)
    if not source then
        log('RotorOpsPerks.teleportStatic: source not found: ' .. source_name)
        return
    end
    local vars = {} 
    vars.gpName = source_name
    vars.action = 'teleport' 
    vars.point = mist.utils.makeVec3(dest_point)
    local res = mist.teleportToPoint(vars)
    if res then
        log('RotorOpsPerks.teleportStatic: ' .. source_name .. ' success')
    else
        log('RotorOpsPerks.teleportStatic: ' .. source_name .. ' failed')
    end
end

function RotorOpsPerks.spawnFatCowFarpObjects(pt_x, pt_y, index, delay)
    log('spawnFatCowFarpObjects called. Looking for static group names ending in ' .. index)
    local dest_point = mist.utils.makeVec3GL({x = pt_x, y = pt_y})
    trigger.action.smoke(dest_point, 2)

    trigger.action.outText('Fat Cow FARP will deploy in ' ..delay .. ' seconds.', 20)
    timer.scheduleFunction(function()
        local fuel_point = {x = dest_point.x + 35, y = dest_point.y, z = dest_point.z}
        RotorOpsPerks.teleportStatic('FAT COW FUEL ' .. index, fuel_point)
        RotorOpsPerks.teleportStatic('FAT COW TENT ' .. index, fuel_point)
        
        local ammo_point = {x = dest_point.x - 35, y = dest_point.y, z = dest_point.z}
        RotorOpsPerks.teleportStatic('FAT COW AMMO ' .. index, ammo_point)
        
    end, nil, timer.getTime() + delay)
end


function RotorOpsPerks.spawnFatCow(dest_point, farp)
    local index = farp.index
    local fatcow_name = 'FAT COW'
    local source_farp_name = 'FAT COW FARP ' .. index
    
    log('spawnFatCow called with ' .. source_farp_name)

    --set a timer to return the farp static resources to be reused
    timer.scheduleFunction(function()
        table.insert(RotorOpsPerks.fat_cow_farps, farp) --put it back at the end of the list
        log('FatCow FARP timer expired, making the farp available to be used again.')
    end, nil, timer.getTime() + 1800)

    dest_point = mist.utils.makeVec2(dest_point)
    local approach_point = mist.getRandPointInCircle(dest_point, 1000, 900)
    trigger.action.smoke(mist.utils.makeVec3GL(dest_point), 2)
    
    
    local fatcow_group = Group.getByName(fatcow_name)
    if not fatcow_group then
        env.warning('FatCow group not found')
        return
    end

    RotorOpsPerks.teleportStatic(source_farp_name, dest_point)

    local airbasefarp = Airbase.getByName(source_farp_name)
    if not airbasefarp then
        env.warning('FatCow FARP not found: ' .. source_farp_name)
        return
    end

    local airbase_pos = mist.utils.makeVec2(airbasefarp:getPoint())



    local script =  [[
        RotorOpsPerks.spawnFatCowFarpObjects(]] .. dest_point.x ..[[,]] .. dest_point.y .. [[,]] .. index .. [[, 235)
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

function RotorOpsPerks.requestPerk(args)
    log('requestPerk called for ' .. args.perk_name)
    --log(mist.utils.tableShow(args, 'args'))
    local player_group = Group.getByName(args.player_group_name)
    local player_unit = player_group:getUnits()[1]
    local player_unit_name = player_unit:getName()
    local player_pos = player_unit:getPoint()
    local players = RotorOpsPerks.playersByGroupName(args.player_group_name)
    if not players then
        env.warning('No players found in group ' .. args.player_group_name)
        return
    end

    --get the perk object
    local perk = RotorOpsPerks.perks[args.perk_name]

    --init some essential variables
    if not perk.used then
        perk.used = 0
    end
    if not perk.last_used then
        perk.last_used = 0
    end

    --find the intended point
    local target_point = nil
    if args.target == 'position' then
        target_point = player_pos

    elseif args.target == 'mark' then
        local temp_mark = nil

        for _, mark in pairs(mist.DBs.markList) do
            debugMsg('mark: ' .. mist.utils.tableShow(mark, 'mark'))
            local perk_name_matches = false

            --determine if mark name matches the perk name
            local mark_name = mark.text
            --remove new line from mark name
            mark_name = mark_name:gsub("\n", "")
            if mark_name == args.perk_name then
                perk_name_matches = true
                log("mark name matches perk name")
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
        -- log(mist.utils.tableShow(mist.DBs.markList, 'markList'))
        -- log('player group' .. mist.utils.tableShow(player_group, 'player_group'))
        -- log('player' .. mist.utils.tableShow(player_unit, 'player_unit'))
        if temp_mark then
            target_point = temp_mark.pos
        end

    end


    local perk_used_count = RotorOpsPerks.getPlayerGroupSum(args.player_group_name, args.perk_name, "perks_used")
    if perk.max_per_player ~= nil and perk_used_count >= (perk.max_per_player*#players) then --multiply by number of players in group
        if #players > 1 then
            trigger.action.outTextForGroup(player_group:getID(), 'UNABLE. You already used this perk ' .. perk_used_count .. ' times.', 10)
        else
            trigger.action.outTextForGroup(player_group:getID(), 'UNABLE. Your group already used this perk ' .. perk_used_count .. ' times.', 10)
        end
        debugMsg('max_per_group reached for ' .. args.perk_name)
        return
    end

    -- check if the max per mission has been reached
    if perk.max_per_mission ~= nil then
        if perk.used >= perk.max_per_mission then
            debugMsg(args.player_group_name.. ' requested ' .. args.perk_name .. ' but max per mission reached')
            trigger.action.outTextForGroup(player_group:getID(), 'UNABLE. Used too many times in the mission.', 10)
            return
        end
    end

    --check if position requirements for action are met    
    if args.target == "mark" then
        if not target_point then
            debugMsg(args.player_group_name.. ' requested ' .. args.perk_name .. ' but no target was found')
            trigger.action.outTextForGroup(player_group:getID(), 'UNABLE. Add a mark called "' .. args.perk_name .. '" to the F10 map first', 10)
            return
        end
    end


    --check if cooldown is over in perks object
    if perk.cooldown and perk.cooldown > 0 then
        if perk.last_used + perk.cooldown > timer.getTime() then
            local time_remaining = perk.last_used + perk.cooldown - timer.getTime()
            --round time_remaining
            time_remaining = math.floor(time_remaining + 0.5)
            debugMsg(args.player_group_name.. ' tried to use ' .. args.perk_name .. ' but cooldown was not over')
            trigger.action.outTextForGroup(player_group:getID(), 'UNABLE. Wait for '.. time_remaining .. ' seconds.', 10)
            return
        end
    end

    --add some useful data to pass to perk condition and action functions
    args.target_point = target_point
    args.player_group = player_group
    args.player_unit = player_unit
    args.player_unit_name = player_unit_name
    args.player_coalition = player_group:getCoalition()

    --show all variables available to perk actions and conditions
    --log('args: ' .. mist.utils.tableShow(args, 'args'))


    --check the perk's unique prerequisite conditions
    if perk.action_condition then
        local r = perk.action_condition(args)

        if r and not r.valid then
            local message = r.msg or "UNABLE. Requirements not met."
            debugMsg(args.player_group_name.. ' tried to use ' .. args.perk_name .. ' but prereq failed with message: ' .. message)
            trigger.action.outTextForGroup(player_group:getID(), message, 10)
            return
        end

        if r and r.valid and r.msg then
            trigger.action.outTextForGroup(player_group:getID(), r.msg, 10)
        end
    end


    --check points
    if RotorOpsPerks.spendPoints(args.player_group_name, perk.cost, false) then
            log(args.player_group_name.. ' has sufficient (' .. perk.cost .. ') points for ' .. args.perk_name)
    else
        log(args.player_group_name.. ' tried to spend ' .. perk.cost .. ' points for ' .. args.perk_name .. ' but did not have enough points')
        if #players == 1 then
            trigger.action.outTextForGroup(player_group:getID(), 'NEGATIVE. You have ' .. RotorOpsPerks.getPlayerGroupSum(args.player_group_name, "points") .. ' points. (cost '.. perk.cost .. ')', 10)
        else
            trigger.action.outTextForGroup(player_group:getID(), 'NEGATIVE. Your group has ' .. RotorOpsPerks.getPlayerGroupSum(args.player_group_name, "total points") .. ' points. (cost '.. perk.cost .. ')', 10)
        end
        return
    end


    --call perk action and deduct points if successful
    if perk.action_function(args) then
        RotorOpsPerks.spendPoints(args.player_group_name, perk.cost, true)
    end

    --update last_used
    perk.last_used = timer.getTime()
    perk.used = perk.used or 0 + 1

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
        --get unit object from id
        local _player_unit = Unit.getByName(_player_name)
        if _player_unit and _player_unit:isExist() then
            local player_position = _player_unit:getPosition().p
            local position_string = ' at ' .. RotorOpsPerks.BRString(target_point, player_position)
            if _player.groupName == args.player_group_name then --if the player is the one who requested the perk
                if args.target == 'position' then
                    position_string = ' at your position'
                end
                -- send affirmative message to the the requesting player
                trigger.action.outTextForGroup(_player.groupId, 'AFFIRM. ' .. RotorOpsPerks.perks[args.perk_name].display_name .. position_string, 10)
            else
                -- send messages to all other players
                log(player_unit:getPlayerName() .. ' requested ' .. RotorOpsPerks.perks[args.perk_name].display_name .. position_string)
                trigger.action.outTextForGroup(_player.groupId, player_unit:getPlayerName() .. ' requested ' .. RotorOpsPerks.perks[args.perk_name].display_name .. position_string, 10)
            end
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
   
    --if enemy unit destroyed
    if e.id == world.event.S_EVENT_KILL then
        if e.initiator and e.target then
            if not Unit.getGroup(e.initiator) then
                env.warning('KILL: initiator is not a unit')
                return
            end
            if e.initiator:getCoalition() ~= e.target:getCoalition() then
                debugMsg('KILL: initiator groupname: ' .. e.initiator:getGroup():getName())

                local initiator_group_name = e.initiator:getGroup():getName()

                -- if initiator is a player's dropped troops
                local dropped_troops = RotorOpsPerks.troops[e.initiator:getGroup():getName()]
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

    --if ctld.callbacks does not exist yet, loop until it does
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
		--log("ctld callback: ".. mist.utils.tableShow(_args)) 
        
        if dropped_troops then
            --log('dropped troops: ' .. mist.utils.tableShow(dropped_troops))
            --log('dropped troops group name: ' .. dropped_troops:getName())
            RotorOpsPerks.troops[dropped_troops:getName()] = {dropped_troops=dropped_troops:getName(), player_group=unit:getGroup():getName(), player_name=unit:getPlayerName(), player_unit=unit:getName(), side=unit:getGroup():getCoalition() , qty=#dropped_troops:getUnits()}

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
    --This function, along with buildPlayer and updatePlayer, have been crafted through much trial and error in order to work with the 'nuances' of the DCS APIs in single player and multiplayer environments.
    --If it's not broke, don't fix it.  If it's broke... ED probably changed the behaviour of coalition.getPlayers, net.get_player_list, or net.get_player_info

    timer.scheduleFunction(RotorOpsPerks.monitorPlayers, nil, timer.getTime() + 2)

    -- GET PILOTS
    local pilots = coalition.getPlayers(coalition.side.BLUE)
    local red_pilots = coalition.getPlayers(coalition.side.RED)
    -- add red pilots to pilots
    for _, red_pilot in pairs(red_pilots) do
        table.insert(pilots, red_pilot)
    end

    debugMsg('PILOTS: '.. mist.utils.tableShow(pilots))

    for _, player in pairs(pilots) do

        local player_group_name = player:getGroup():getName()
        debugMsg('GET PILOTS Player group: ' .. player:getGroup():getName())
        debugMsg('GET PILOTS PLAYER: ' .. mist.utils.tableShow(player))

        --player info works in single player
        local player_info = net.get_player_info(player)
        if player_info then
            debugMsg('GET PILOTS player info: '.. mist.utils.tableShow(player_info))
            RotorOpsPerks.updatePlayer(player_info.ucid, player_group_name, player_info.name, player_info.slot)

        else --player_info is nil in multiplayer, so we'll have to compile the data we need in multiple steps
            --env.warning('GET PILOTS player_info for coalition.getPlayers is nil.  Setting attributes to nil to be picked up by GET CREW METHODs')
            RotorOpsPerks.buildPlayer(nil, player_group_name, nil, nil, player:getPlayerName())  --we don't have all the data we need to add to players yet
        end

    end


    
    --GET CREW

    local players = net.get_player_list()  --empty in single player
    debugMsg('GET CREW ALL PLAYERS: '.. mist.utils.tableShow(players))

    for _, player in pairs(players) do
        local player_info = net.get_player_info(player)  --works with multicrew, but we need to find the group name
        debugMsg('GET CREW player info:')
        debugMsg(mist.utils.tableShow(player_info))

        --find the group from slot relationship to pilots with the base slot
        
        --client slot patterns are like 6_1, 6_2, etc where 6 is the host slot
        --if the player slot is like 6_1, 6_2, etc then find the player with slot 6 and use that player's group name
        if string.find(player_info.slot, '_') then  --found a multicrew slot
            local base_slot = string.sub(player_info.slot, 1, string.find(player_info.slot, '_')-1)
            debugMsg('GET CREW found multicrew with base slot: '.. base_slot)
            for _i, pilot in pairs(RotorOpsPerks.players) do
                if pilot.slot == base_slot then
                    local player_group_name = pilot.groupName
                    debugMsg('GET CREW player group name: '.. player_group_name)
                    RotorOpsPerks.updatePlayer(player_info.ucid, player_group_name, player_info.name, player_info.slot)
                end
            end
        else --we can't get the group name from here, so we'll have to compile the data we need in multiple steps
            RotorOpsPerks.buildPlayer(player_info.ucid, nil, player_info.name, player_info.slot, player_info.name)  --we don't have all the data we need to add to players yet
        end
        
    end


end

if mist.grimm_version then
    log("GRIMM's version of MIST is loaded")
else
    env.warning("ERROR: ROTOROPS PERKS REQUIRES A MODIFIED VERSION OF MIST TO WORK PROPERLY. PLEASE SEE THE SCRIPTS FOLDER IN THE ROTOROPS GITHUB REPO")
    trigger.action.outText("ERROR: ROTOROPS PERKS REQUIRES A MODIFIED VERSION OF MIST TO WORK PROPERLY.", 30)
end

RotorOpsPerks.buildFatCowFarpTable()
log("Found " .. #RotorOpsPerks.fat_cow_farps .. " Fat Cow FARPs")
if #RotorOpsPerks.fat_cow_farps > 0 then
    RotorOpsPerks.monitorFarps()
else 
    env.warning("NO FAT COW FARPS FOUND.  PLEASE SEE THE ROTOROPS WIKI FOR INSTRUCTIONS ON HOW TO SET UP FAT COW FARPS")
    trigger.action.outText("WARNING: NO FAT COW FARPS FOUND.", 30)
end
if not Group.getByName('FAT COW') then
    env.warning("NO AI FAT COW HELICOPTER FOUND.  PLEASE SEE THE ROTOROPS WIKI FOR INSTRUCTIONS ON HOW TO SET UP FAT COW FARPS")
    trigger.action.outText("WARNING: NO AI FAT COW HELICOPTER FOUND.", 30)
end
RotorOpsPerks.registerCtldCallbacks()
-- start a 5 second timer to monitor players, to allow other scripts to load
timer.scheduleFunction(RotorOpsPerks.monitorPlayers, nil, timer.getTime() + 5)

