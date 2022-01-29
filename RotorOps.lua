RotorOps = {}
RotorOps.version = "1.2.2"


---[[ROTOROPS OPTIONS]]---
--- Protip: change these options from the mission editor rather than changing the script file itself.  See documentation on github for details.


--RotorOps settings that are safe to change dynamically (ideally from the mission editor in DO SCRIPT for portability). You can change these while the script is running, at any time.
RotorOps.voice_overs = true
RotorOps.ground_speed = 60 --max speed for ground vehicles moving between zones. Doesn't have much effect since always limited by slowest vehicle in group
RotorOps.zone_status_display = true --constantly show units remaining and zone status on screen 
RotorOps.max_units_left = 0 --allow clearing the zone when a few units are left to prevent frustration with units getting stuck in buildings etc
RotorOps.force_offroad = false  --affects "move_to_zone" tasks only
RotorOps.apcs_spawn_infantry = false  --apcs will unload troops when arriving to a new zone
RotorOps.auto_push = true --should attacking ground units move to the next zone after clearing? 

RotorOps.inf_spawns_avail = 0 --this is the number of infantry group spawn events remaining in the active zone
RotorOps.inf_spawn_chance = 25 -- 0-100 the chance of spawning infantry in an active zone spawn zone, per 'assessUnitsInZone' loop (10 seconds) 
RotorOps.inf_spawn_trigger_percent = 70 --infantry has a chance of spawning if the percentage of defenders remaining in zone is less than this value
RotorOps.inf_spawns_per_zone = 3 --number of infantry groups to spawn per zone


--RotorOps settings that are safe to change only before calling setupConflict()
RotorOps.transports = {'UH-1H', 'Mi-8MT', 'Mi-24P', 'SA342M', 'SA342L', 'SA342Mistral'} --players flying these will have ctld transport access 
RotorOps.CTLD_crates = false 
RotorOps.CTLD_sound_effects = true --sound effects for troop pickup/dropoffs
RotorOps.exclude_ai_group_name = "noai"  --include this somewhere in a group name to exclude the group from being tasked in the active zone


---[[END OF OPTIONS]]---




--RotorOps variables that are safe to read only
RotorOps.game_states = {not_started = 0, alpha_active = 1, bravo_active = 2, charlie_active = 3, delta_active = 4, lost = 98, won = 99} --game level user flag will use these values
RotorOps.game_state = 0 
RotorOps.zones = {}
RotorOps.active_zone = "" --name of the active zone
RotorOps.active_zone_index = 0
RotorOps.game_state_flag = 1  --user flag to store the game state
RotorOps.staging_zone = ""
RotorOps.ctld_pickup_zones = {} --keep track of ctld zones we've added, mainly for map markup
RotorOps.ai_defending_infantry_groups = {} 
RotorOps.ai_attacking_infantry_groups = {} 
RotorOps.ai_defending_vehicle_groups = {} 
RotorOps.ai_attacking_vehicle_groups = {} 
RotorOps.ai_tasks = {} 
RotorOps.defending = false

trigger.action.outText("ROTOR OPS STARTED: "..RotorOps.version, 5)
env.info("ROTOR OPS STARTED: "..RotorOps.version)

RotorOps.staged_units = {} --table of ground units that started in the staging zone
RotorOps.eventHandler = {}
local commandDB = {} 
local game_message_buffer = {}
local active_zone_initial_defenders
local apcs = {} --table to keep track of infantry vehicles
local low_units_message_fired = false
local inf_spawn_zones = {}



RotorOps.gameMsgs = {
  push = {
    {'ALL GROUND UNITS, PUSH TO THE ACTIVE ZONE!', 'push_next_zone.ogg'},
    {'ALL GROUND UNITS, PUSH TO ALPHA!', 'push_alpha.ogg'},
    {'ALL GROUND UNITS, PUSH TO BRAVO!', 'push_bravo.ogg'},
    {'ALL GROUND UNITS, PUSH TO CHARLIE!', 'push_charlie.ogg'},
    {'ALL GROUND UNITS, PUSH TO DELTA!', 'push_delta.ogg'},
  },
  cleared = {
    {'ZONE CLEARED!', 'cleared_active.ogg'},
    {'ALPHA CLEARED!', 'cleared_alpha.ogg'},
    {'BRAVO CLEARED!', 'cleared_bravo.ogg'},
    {'CHARLIE CLEARED!', 'cleared_charlie.ogg'},
    {'DELTA CLEARED!', 'cleared_delta.ogg'},
  },
  success = {
    {'GROUND MISSION SUCCESS!', 'mission_success.ogg'},
  },
  start = {
    {'SUPPORT THE WAR ON THE GROUND!', 'support_troops.ogg'},
  },
  troops_dropped = {
    {'TROOPS DROPPED INTO ZONE!', 'troops_dropped_active.ogg'},
    {'TROOPS DROPPED INTO ALPHA!', 'troops_dropped_alpha.ogg'},
    {'TROOPS DROPPED INTO BRAVO!', 'troops_dropped_bravo.ogg'},
    {'TROOPS DROPPED INTO CHARLIE!', 'troops_dropped_charlie.ogg'},
    {'TROOPS DROPPED INTO DELTA!', 'troops_dropped_delta.ogg'},
  },
  get_troops_to_zone = {
    {'GET OUR TROOPS TO THE NEXT ZONE!', 'get_troops_next_zone.ogg'},
    {'GET OUR TROOPS TO ALPHA!', 'get_troops_alpha.ogg'},
    {'GET OUR TROOPS TO BRAVO!', 'get_troops_bravo.ogg'},
    {'GET OUR TROOPS TO CHARLIE!', 'get_troops_charlie.ogg'},
    {'GET OUR TROOPS TO DELTA!', 'get_troops_delta.ogg'},
  },
  jtac = {
    {'JTAC DROPPED!', 'jtac_dropped.ogg'},
  },
  enemy_almost_cleared = {
    {'ENEMY HAS NEARLY CAPTURED THE ZONE!', 'enemy_almost_cleared.ogg'},
    {'ENEMY HAS NEARLY CAPTURED THE ZONE!', 'enemy_decimating_forces.ogg'},
    {'ENEMY HAS NEARLY CAPTURED THE ZONE!', 'enemy_destroying_ground.ogg'},
  },
  almost_cleared = {
    {'WE HAVE NEARLY CLEARED THE ZONE!', 'almost_cleared.ogg'},
    {'WE HAVE NEARLY CLEARED THE ZONE!', 'theyre_weak.ogg'},
    {'WE HAVE NEARLY CLEARED THE ZONE!', 'tearing_them_up.ogg'},
  },
  enemy_pushing = {
    {'ENEMY PUSHING TO THE NEXT ZONE!', 'enemy_pushing_zone.ogg'},
    {'ENEMY PUSHING TO ALPHA!', 'enemy_pushing_alpha.ogg'},
    {'ENEMY PUSHING TO BRAVO!', 'enemy_pushing_bravo.ogg'},
    {'ENEMY PUSHING TO CHARLIE!', 'enemy_pushing_charlie.ogg'},
    {'ENEMY PUSHING TO DELTA!', 'enemy_pushing_delta.ogg'},
  },
  start_defense = {
    {'SUPPORT THE WAR ON THE GROUND!  PUSH BACK AGAINST THE ENEMY!', 'push_back.ogg'},
  },
  failure = {
    {'GROUND MISSION FAILED!', 'mission_failure.ogg'},
  },
  friendly_troops_dropped = {
    {'FRIENDLY TROOPS DROPPED INTO ZONE!', 'friendly_troops_dropped_active.ogg'},
  },
  hold_ground = {
    {'HOLD GROUND TO WIN!', 'hold_our_ground.ogg'},
  },
  enemy_cleared_zone = {
    {'ENEMY TOOK THE ACTIVE ZONE!', 'enemy_destroying_us.ogg'},
    {'ENEMY TOOK ALPHA!', 'enemy_destroying_us.ogg'},
    {'ENEMY TOOK BRAVO!', 'enemy_destroying_us.ogg'},
    {'ENEMY TOOK CHARLIE!', 'enemy_destroying_us.ogg'},
    {'ENEMY TOOK DELTA!', 'enemy_destroying_us.ogg'},
  },

}


local sound_effects = {
    ["troop_pickup"] = {'troops_load_ao.ogg', 'troops_load_ready.ogg', 'troops_load_to_action.ogg',force_offroad = true},
    ["troop_dropoff"] = {'troops_unload_thanks.ogg', 'troops_unload_everybody_off.ogg', 'troops_unload_get_off.ogg', 'troops_unload_here_we_go.ogg', 'troops_unload_moving_out.ogg',},
}

function RotorOps.eventHandler:onEvent(event)
   if (world.event.S_EVENT_ENGINE_STARTUP  == event.id) then  --play some sound files when a player starts engines
    local initaitor = event.initiator:getGroup():getID()
    if RotorOps.defending then
      trigger.action.outSoundForGroup(initaitor , RotorOps.gameMsgs.enemy_pushing[RotorOps.active_zone_index + 1][2])
    else
      trigger.action.outSoundForGroup(initaitor , RotorOps.gameMsgs.push[RotorOps.active_zone_index + 1][2])
    end
   end
end



function RotorOps.registerCtldCallbacks(var)
ctld.addCallback(function(_args)
    local action = _args.action
    local unit = _args.unit
    local picked_troops = _args.onboard
    local dropped_troops = _args.unloaded
    --trigger.action.outText("dbg: ".. mist.utils.tableShow(_args), 5) 
    if action == "load_troops" or action == "extract_troops" then
      trigger.action.outSoundForGroup(unit:getGroup():getID() , sound_effects.troop_pickup[math.random(1, #sound_effects.troop_pickup)])
    elseif action == "unload_troops_zone" or action == "dropped_troops" then
      trigger.action.outSoundForGroup(unit:getGroup():getID() , sound_effects.troop_dropoff[math.random(1, #sound_effects.troop_dropoff)])
      if RotorOps.isUnitInZone(unit, RotorOps.active_zone) then
        local id = timer.scheduleFunction(RotorOps.gameMsgHandler, RotorOps.gameMsgs.friendly_troops_dropped, timer.getTime() + 6)  --allow some extra time so we don't step on the player's troop/unload sound effects
      end
      if dropped_troops.jtac == true then
        local id = timer.scheduleFunction(RotorOps.gameMsgHandler, RotorOps.gameMsgs.jtac, timer.getTime() + 6) --allow some extra time so we don't step on the player's troop/unload sound effects
      end
    end

end)
end

---UTILITY FUNCTIONS---

local function debugMsg(text)
  trigger.action.outText(text, 5)
  env.info("ROTOROPS_DEBUG: "..text)
end


local function debugTable(table)
  trigger.action.outText("dbg: ".. mist.utils.tableShow(table), 5) 
end


local function dispMsg(text)
  trigger.action.outText(text, 5)
  return text
end


local function tableHasKey(table,key)
  if table then
    return table[key] ~= nil
  else 
    env.warning("table parameter not provided")
    return nil
  end
end


local function hasValue (tab, val)
    for index, value in ipairs(tab) do
        if value == val then
            return true
        end
    end
    return false
end

local function getObjectVolume(obj)
  local length = (obj:getDesc().box.max.x + math.abs(obj:getDesc().box.min.x))
  local height = (obj:getDesc().box.max.y + math.abs(obj:getDesc().box.min.y))
  local depth = (obj:getDesc().box.max.z + math.abs(obj:getDesc().box.min.z))
  return length * height * depth
end

local function getDistance(point1, point2)
  local x1 = point1.x
  local y1 = point1.y
  local z1 = point1.z
  local x2 = point2.x
  local y2 = point2.y
  local z2 = point2.z
  local dX = math.abs(x1-x2)
  local dZ = math.abs(z1-z2)
  local distance = math.sqrt(dX*dX + dZ*dZ)
  return distance
end

function RotorOps.isUnitInZone(unit, zone_name)
  local zone = trigger.misc.getZone(zone_name)
  local distance = getDistance(unit:getPoint(), zone.point)
  if distance <= zone.radius then
    return true
  else
    return false
  end
end


function RotorOps.groupsFromUnits(units, table)  
  local groups = {}
  for i = 1, #units do 
   if units[i]:isExist() then
     if hasValue(groups, units[i]:getGroup():getName()) == false then 
         groups[#groups + 1] = units[i]:getGroup():getName()
     else 
     end
   end
  end
  return groups
end


function RotorOps.gameMsg(event, _index)
  if not event then 
    env.warning("event parameter is nil")
    return 
  end  
  local index = 1 
  if _index ~= nil then
    index = _index + 1 
  end
  if tableHasKey(event, index) then
    game_message_buffer[#game_message_buffer + 1] = {event[index][1], event[index][2]}
  else env.warning("ROTOR OPS could not find sound file entry")
  end
end

function RotorOps.gameMsgHandler(event)  --for use with scheduled functions
  RotorOps.gameMsg(event)
end



local function processMsgBuffer(vars)
  if #game_message_buffer > 0 then
    local message = table.remove(game_message_buffer, 1)
    trigger.action.outText(message[1], 10, true)
    if RotorOps.voice_overs then
      trigger.action.outSound(message[2])
    end
  end
  local id = timer.scheduleFunction(processMsgBuffer, 1, timer.getTime() + 5)
end


function RotorOps.sortOutInfantry(mixed_units)
  local _infantry = {}
  local _not_infantry = {}
  for index, unit in pairs(mixed_units)
  do
    if unit:hasAttribute("Infantry") then
      _infantry[#_infantry + 1] = unit
    else _not_infantry[#_not_infantry + 1] = unit
    end
  end
  return {infantry = _infantry, not_infantry = _not_infantry} 
end


function RotorOps.getValidUnitFromGroup(grp)
 local group_obj
 if type(grp) == 'string' then
   group_obj = Group.getByName(grp)
 else
  group_obj = grp
 end 
 if grp:isExist() ~= true then return nil end
 local first_valid_unit
 for index, unit in pairs(grp:getUnits())
 do
   if unit:isExist() == true then
     first_valid_unit = unit
     break
   else --trigger.action.outText("a unit no longer exists", 15) 
   end 
 end
 return first_valid_unit
end



----USEFUL PUBLIC FUNCTIONS FOR THE MISSION EDITOR---

--Spawn/clone a group onto the location of one unit in the group. This is similar to deployTroops, but it does not use CTLD. You must provide a source group to copy.
function RotorOps.spawnGroupOnGroup(grp, src_grp_name, ai_task) --allow to spawn on other group units
  local valid_unit = RotorOps.getValidUnitFromGroup(grp)
  if not valid_unit then return end
  local vars = {} 
  vars.gpName = src_grp_name
  vars.action = 'clone' 
  vars.point = valid_unit:getPoint() 
  vars.radius = 5
  vars.disperse = 'disp'
  vars.maxDisp = 5
  local new_grp_table = mist.teleportToPoint(vars) 
  
  if new_grp_table then
      RotorOps.aiTask(new_grp_table, ai_task)
  else debugMsg("Infantry failed to spawn. ")  
  end
end

--Spawn infantry in a trigger zone. Uses CTLD but may use another method in the future. Side is "red" or "blue"
--function RotorOps.spawnInfantryInZone(vars)
--    --local group = {mg=1,at=0,aa=0,inf=4,mortar=0}
--
--    local _triggerName = vars.zone
--    local _groupSide = vars.side
--    local _number = vars.qty
--    local _searchRadius = 500
--  
--    local _spawnTrigger = trigger.misc.getZone(_triggerName) -- trigger to use as reference position
--
--    if _spawnTrigger == nil then
--        env.warning("ERROR: Cant find zone called " .. _triggerName)
--        return
--    end
--
--    local _country
--    if _groupSide == "red" then
--        _groupSide = 1
--        _country = 0
--    else
--        _groupSide = 2
--        _country = 2
--    end
--
--    if _searchRadius < 0 then
--        _searchRadius = 0
--    end
--
--    local _pos2 = { x = _spawnTrigger.point.x, y = _spawnTrigger.point.z }
--    local _alt = land.getHeight(_pos2)
--    local _pos3 = { x = _pos2.x, y = _alt, z = _pos2.y }
--
--    local _groupDetails = ctld.generateTroopTypes(_groupSide, _number, _country)
--
--    local _droppedTroops = ctld.spawnDroppedGroup(_pos3, _groupDetails, false, _searchRadius);
--    --debugMsg(_groupDetails.groupName)
--    return _groupDetails.groupName  --_ { units = _troops, groupId = _groupId, groupName = string.format("%s %i", _groupName, _groupId), side = _side, country = _country, weight = _weight, jtac = _hasJTAC }
--end

--Easy way to deploy troops from a vehicle with waypoint action.  Spawns from the first valid unit found in a group
function RotorOps.deployTroops(quantity, target_group, announce)
  local target_group_obj
  if type(target_group) == 'string' then
    target_group_obj = Group.getByName(target_group)
  else
    target_group_obj = target_group
  end 
  local valid_unit = RotorOps.getValidUnitFromGroup(target_group_obj)
  if not valid_unit then return end
  local coalition = valid_unit:getCoalition()
  local side = "red"
  if coalition == 2 then side = "blue" end
  local point = valid_unit:getPoint() 
  ctld.spawnGroupAtPoint(side, quantity, point, 1000)
  
  -- voiceover trigger stuff
  for index, zone in pairs(RotorOps.zones)
  do
    if RotorOps.isUnitInZone(valid_unit, zone.name) and announce == true then 
      if side == "red" then
        RotorOps.gameMsg(RotorOps.gameMsgs.troops_dropped, index)
      else
        RotorOps.gameMsg(RotorOps.gameMsgs.friendly_troops_dropped)
      end
    end
  end
end



--see list of tasks in aiExecute. Zone is optional for many tasks
function RotorOps.aiTask(grp, task, zone)
   local group_name
   if type(grp) == 'string' then
    group_name = grp
   else
    group_name = Group.getName(grp)
   end 
   if string.find(group_name:lower(), RotorOps.exclude_ai_group_name:lower()) then  --exclude groups that the user specifies with a special group name
     return
   end
   if tableHasKey(RotorOps.ai_tasks, group_name) == true then  --if we already have this group in our list to manage
     --debugMsg("timer already exists, updating task for "..group_name.." : ".. RotorOps.ai_tasks[group_name].ai_task.." to "..task)
     RotorOps.ai_tasks[group_name].ai_task = task
     RotorOps.ai_tasks[group_name].zone = zone
   else 
     local vars = {}
     vars.group_name = group_name
     --vars.last_task = task
     if zone then 
       vars.zone = zone 
     end
     local timer_id = timer.scheduleFunction(RotorOps.aiExecute, vars, timer.getTime() + 5)
     RotorOps.ai_tasks[group_name] = {['timer_id'] = timer_id, ['ai_task'] = task, ['zone'] = zone}
   end
end




---AI CORE BEHAVIOR--


function RotorOps.chargeEnemy(vars)
 --trigger.action.outText("charge enemies: "..mist.utils.tableShow(vars), 5) 
 local grp = vars.grp
 local search_radius = vars.radius or 5000
 ----
 local first_valid_unit = RotorOps.getValidUnitFromGroup(grp)
 
 if first_valid_unit == nil then return end
 local start_point = first_valid_unit:getPoint()
 if not vars.spawn_point then vars.spawn_point = start_point end

 local enemy_coal
 if grp:getCoalition() == 1 then enemy_coal = 2 end
 if grp:getCoalition() == 2 then enemy_coal = 1 end
 
 local volS
   if vars.zone then 
     --debugMsg("CHARGE ENEMY at zone: "..vars.zone)
     local sphere = trigger.misc.getZone(vars.zone)
     volS = {
       id = world.VolumeType.SPHERE,
       params = {
         point = sphere.point, 
         radius = sphere.radius
       }
     }
   else 
       --debugMsg("CHARGE ENEMY in radius: "..search_radius)
       volS = {
       id = world.VolumeType.SPHERE,
       params = {
         point = first_valid_unit:getPoint(), 
         radius = search_radius
       }
     }
   end
 
 
 local enemy_unit
 local path = {} 
 local ifFound = function(foundItem, val)
  --trigger.action.outText("found item: "..foundItem:getTypeName(), 5)  
 -- if foundItem:hasAttribute("Infantry") == true and foundItem:getCoalition() == enemy_coal then
  if foundItem:getCoalition() == enemy_coal and foundItem:isActive() then
    enemy_unit = foundItem
    --debugMsg("found enemy! "..foundItem:getTypeName()) 
    
    path[1] = mist.ground.buildWP(start_point, '', 5) 
    path[2] = mist.ground.buildWP(enemy_unit:getPoint(), '', 5) 
    --path[3] = mist.ground.buildWP(vars.spawn_point, '', 5) 
  else 

    --trigger.action.outText("object found is not enemy inf in "..search_radius, 5)  
  end
  
 return true
 end
 --default path if no units found
 if false then
   --debugMsg("group going back to origin")  
   path[1] = mist.ground.buildWP(start_point, '', 5) 
   path[2] = mist.ground.buildWP(vars.spawn_point, '', 5)
   
 end
 world.searchObjects(Object.Category.UNIT, volS, ifFound)
 mist.goRoute(grp, path)

end


function RotorOps.patrolRadius(vars)
 --debugMsg("patrol radius: "..mist.utils.tableShow(vars.grp))  
 local grp = vars.grp
 local search_radius = vars.radius or 100
 local first_valid_unit
 if grp:isExist() ~= true then return end
 for index, unit in pairs(grp:getUnits())
 do
   if unit:isExist() == true then
     first_valid_unit = unit
     break
   else --trigger.action.outText("a unit no longer exists", 15) 
   end 
 end
 if first_valid_unit == nil then return end
 local start_point = first_valid_unit:getPoint()
 local object_vol_thresh = 0
 local max_waypoints = 5
 local foundUnits = {}
 --local sphere = trigger.misc.getZone('town')
 local volS = {
   id = world.VolumeType.SPHERE,
   params = {
     point = grp:getUnit(1):getPoint(),  --check if exists, maybe itterate through grp
     radius = search_radius
   }
 }
 
 local ifFound = function(foundItem, val)
  --trigger.action.outText("found item: "..foundItem:getTypeName(), 5)  
  if foundItem:hasAttribute("Infantry") ~= true then  --disregard infantry...we only want objects that might provide cover
    if getObjectVolume(foundItem) > object_vol_thresh then
      foundUnits[#foundUnits + 1] = foundItem
      --trigger.action.outText("valid cover item: "..foundItem:getTypeName(), 5) 
    else --debugMsg("object not large enough: "..foundItem:getTypeName()) 
    end
  else --trigger.action.outText("object not the right type", 5)  
  end
 return true
 end
 
 world.searchObjects(1, volS, ifFound)
 world.searchObjects(3, volS, ifFound)
 world.searchObjects(5, volS, ifFound)
 --world.searchObjects(Object.Category.BASE, volS, ifFound)
 local path = {} 
 path[1] = mist.ground.buildWP(start_point, '', 5) 
 local m = math.min(#foundUnits, max_waypoints)
 for i = 1, m, 1
   do
     local rand_index = math.random(1,#foundUnits)
     path[i + 1] = mist.ground.buildWP(foundUnits[rand_index]:getPoint(), '', 5) 
     --trigger.action.outText("waypoint to: "..foundUnits[rand_index]:getTypeName(), 5) 
   end
 if #path <= 3 then
   for i = #path, max_waypoints, 1
   do
     path[#path + 1] = mist.ground.buildWP(mist.getRandPointInCircle(start_point, search_radius), '', 5)
   end
 end
 --trigger.action.outText("new waypoints created: "..(#path - 1), 5) 
 mist.goRoute(grp, path)                                                      
end



function RotorOps.aiExecute(vars)
  local update_interval = 60
  local last_task = vars.last_task
  local group_name = vars.group_name
  local task = RotorOps.ai_tasks[group_name].ai_task
  local zone = RotorOps.ai_tasks[group_name].zone

--  if vars.zone then zone = vars.zone end
  --debugMsg("tasking: "..group_name.." : "..task .." zone:"..zone) 
  
  if Group.isExist(Group.getByName(group_name)) ~= true or #Group.getByName(group_name):getUnits() < 1 then
    --debugMsg("group no longer exists")
    RotorOps.ai_tasks[group_name] = nil
    return
  end  
  
 --if Group.getByName(group_name):getController():hasTask() == false then   --our implementation of hasTask does not seem to be working for vehicles
  
  if task == "patrol" then
    local vars = {}
    vars.grp = Group.getByName(group_name)
    vars.radius = 300
    RotorOps.patrolRadius(vars) --takes a group object, not name
    update_interval = math.random(150,200)
  elseif task == "aggressive" then 
    local vars = {}
    vars.grp = Group.getByName(group_name)
    vars.radius = 5000 
    update_interval = math.random(60,90)
    RotorOps.chargeEnemy(vars) --takes a group object, not name
  elseif task == "clear_zone" then 
    local vars = {}
    vars.grp = Group.getByName(group_name)
    vars.zone = zone
    update_interval = math.random(50,70)
    RotorOps.chargeEnemy(vars) --takes a group object, not name
  elseif task == "move_to_zone" then  
    update_interval = math.random(90,120)
    local formation = 'cone'
    local final_heading = nil
    local speed = RotorOps.ground_speed
    local force_offroad = RotorOps.force_offroad
    mist.groupToPoint(group_name, zone, formation, final_heading, speed, force_offroad)
  elseif task == "move_to_active_zone" then  
    update_interval = math.random(90,120)
    local formation = 'cone'
    local final_heading = nil
    local speed = RotorOps.ground_speed
    local force_offroad = RotorOps.force_offroad
    mist.groupToPoint(group_name, RotorOps.active_zone, formation, final_heading, speed, force_offroad)
  end  
  
  vars.last_task = task
   
  local timer_id = timer.scheduleFunction(RotorOps.aiExecute, vars, timer.getTime() + update_interval)
end





---CONFLICT ZONES GAME FUNCTIONS---

--take stock of the blue/red forces in zone and apply some logic to determine game/zone states
function RotorOps.assessUnitsInZone(var)
   if RotorOps.game_state == RotorOps.game_states.not_started then return end
   
  
   local defending_ground_units
   local defending_infantry
   local defending_vehicles
   local attacking_ground_units
   local attacking_infantry
   local attacking_vehicles
   


    --find and sort units found in the active zone  
   if RotorOps.defending then 
     defending_ground_units = mist.getUnitsInZones(mist.makeUnitTable({'[blue][vehicle]'}), {RotorOps.active_zone})  
     defending_infantry = RotorOps.sortOutInfantry(defending_ground_units).infantry
     defending_vehicles = RotorOps.sortOutInfantry(defending_ground_units).not_infantry
     attacking_ground_units = mist.getUnitsInZones(mist.makeUnitTable({'[red][vehicle]'}), {RotorOps.active_zone})
     attacking_infantry = RotorOps.sortOutInfantry(attacking_ground_units).infantry
     attacking_vehicles = RotorOps.sortOutInfantry(attacking_ground_units).not_infantry
   else  --attacking
     defending_ground_units = mist.getUnitsInZones(mist.makeUnitTable({'[red][vehicle]'}), {RotorOps.active_zone})  
     defending_infantry = RotorOps.sortOutInfantry(defending_ground_units).infantry
     defending_vehicles = RotorOps.sortOutInfantry(defending_ground_units).not_infantry
     attacking_ground_units = mist.getUnitsInZones(mist.makeUnitTable({'[blue][vehicle]'}), {RotorOps.active_zone})
     attacking_infantry = RotorOps.sortOutInfantry(attacking_ground_units).infantry
     attacking_vehicles = RotorOps.sortOutInfantry(attacking_ground_units).not_infantry
   end
   
   
   --ground unit ai stuff
     RotorOps.ai_defending_infantry_groups = RotorOps.groupsFromUnits(defending_infantry)
     RotorOps.ai_defending_vehicle_groups = RotorOps.groupsFromUnits(defending_vehicles)
     RotorOps.ai_attacking_infantry_groups = RotorOps.groupsFromUnits(attacking_infantry)
     RotorOps.ai_attacking_vehicle_groups = RotorOps.groupsFromUnits(attacking_vehicles)
   
  for index, group in pairs(RotorOps.ai_defending_infantry_groups) do 
    if group then
      RotorOps.aiTask(group, "patrol")
    end
  end
  
  for index, group in pairs(RotorOps.ai_attacking_infantry_groups) do 
    if group then
      RotorOps.aiTask(group, "clear_zone", RotorOps.active_zone)
    end
  end
  
  for index, group in pairs(RotorOps.ai_attacking_vehicle_groups) do 
    if group then
      RotorOps.aiTask(group, "clear_zone", RotorOps.active_zone)  
    end
  end

  
   --FIRES ONCE PER ZONE ACTIVATION
   --let's compare the defending units in zone vs their initial numbers and set a game flag
   if not active_zone_initial_defenders then
     --debugMsg("taking stock of the active zone")
     active_zone_initial_defenders = defending_ground_units
     low_units_message_fired = false
     
     --sort infantry spawn zones and spawn quantity
     inf_spawn_zones = {}
     for zone, zoneobj in pairs(mist.DBs.zonesByName) do 
       if string.find(zone, RotorOps.active_zone) and string.find(zone:lower(), "spawn") then --if we find a zone that has the active zone name and the word spawn
         inf_spawn_zones[#inf_spawn_zones + 1] = zone 
         env.info("ROTOR OPS: spawn zone found:"..zone)
       end
     end
     RotorOps.inf_spawns_avail = RotorOps.inf_spawns_per_zone * #inf_spawn_zones

     env.info("ROTOR OPS: zone activated: "..RotorOps.active_zone..", inf spawns avail:"..RotorOps.inf_spawns_avail..", spawn zones:"..#inf_spawn_zones)
   end
   
   
   local defenders_status_flag = RotorOps.zones[RotorOps.active_zone_index].defenders_status_flag
   --if #active_zone_initial_defenders == 0 then active_zone_initial_defenders = 1 end --prevent divide by zero
   local defenders_remaining_percent = math.floor((#defending_ground_units / #active_zone_initial_defenders) * 100) 
     
   if #defending_ground_units <= RotorOps.max_units_left then  --if we should declare the zone cleared
     active_zone_initial_defenders = nil
     defenders_remaining_percent = 0
     trigger.action.setUserFlag(defenders_status_flag, 0)  --set the zone's flag to cleared
     if RotorOps.defending == true then
       RotorOps.gameMsg(RotorOps.gameMsgs.enemy_cleared_zone, RotorOps.active_zone_index)
     else
       RotorOps.gameMsg(RotorOps.gameMsgs.cleared, RotorOps.active_zone_index)
     end
     if RotorOps.auto_push then                                 --push units to the next zone
       RotorOps.setActiveZone(RotorOps.active_zone_index + 1)
     end  
       
   else 
     trigger.action.setUserFlag(defenders_status_flag, defenders_remaining_percent)  --set the zones flag to indicate the status of remaining defenders
   end
     
   --are all zones clear?
   local all_zones_clear = true
   for key, value in pairs(RotorOps.zones) do 
      local defenders_remaining = trigger.misc.getUserFlag(RotorOps.zones[key].defenders_status_flag)
      if defenders_remaining ~= 0 then
        all_zones_clear = false
      end
   end
   
   --is the game finished?
   if all_zones_clear then
    if RotorOps.defending == true then 
      RotorOps.game_state = RotorOps.game_states.lost
      trigger.action.setUserFlag(RotorOps.game_state_flag, RotorOps.game_states.lost)
      RotorOps.gameMsg(RotorOps.gameMsgs.failure)
    else
      RotorOps.game_state = RotorOps.game_states.won
      trigger.action.setUserFlag(RotorOps.game_state_flag, RotorOps.game_states.won)
      RotorOps.gameMsg(RotorOps.gameMsgs.success)
    end
    return --we won't reset our timer to fire this function again
   end
   
   --is the defending game finished?
   local defending_game_won = true
   for key, staged_unit in pairs(RotorOps.staged_units) do  
     if staged_unit:isExist() then --check if the enemy has staged units left
       defending_game_won = false
     end
   end
   if RotorOps.defending and defending_game_won then
     RotorOps.game_state = RotorOps.game_states.won
     trigger.action.setUserFlag(RotorOps.game_state_flag, RotorOps.game_states.won)
     RotorOps.gameMsg(RotorOps.gameMsgs.success)
     return  --we won't reset our timer to fire this function again
   end 
  
  --APCs unload
  local function unloadAPCs()
    local units_table = attacking_vehicles
    
    for index, vehicle in pairs(units_table) do
      local should_deploy = false
      if vehicle:hasAttribute("Infantry carriers") and RotorOps.isUnitInZone(vehicle, RotorOps.active_zone) then --if a vehicle is an APC and in zone
          local apc_name = vehicle:getName()
          
          if tableHasKey(apcs, apc_name) == true then  --if we have this apc in our table already 
            
            for key, apc_details in pairs(apcs[apc_name]) do   
              if hasValue(apc_details, RotorOps.active_zone) then     --if our apc table has the current zone

              else                                       --our apc table does not have the current zone
                apcs[apc_name].deployed_zones = {RotorOps.active_zone,}
                should_deploy = true
              end
            end
            
          else                                          --we don't have the apc in our table
            should_deploy = true
            apcs[apc_name] = {['deployed_zones'] = {RotorOps.active_zone,}}
          end
          
      end
      
      if should_deploy then
       local function timedDeploy()
         if vehicle:isExist() then
           RotorOps.deployTroops(4, vehicle:getGroup(), false)
         end
       end
        
       local id = timer.scheduleFunction(timedDeploy, nil, timer.getTime() + math.random(90, 180))
      end
    
    end
    
  end
  
  if RotorOps.apcs_spawn_infantry then
   unloadAPCs()  --this should really be an aitask
  end
  
  --spawn infantry in infantry spawn zones
  local function spawnInfantry()
   if math.random(0, 100) <= RotorOps.inf_spawn_chance then
      local rand_index = math.random(1, #inf_spawn_zones)
      local zone = inf_spawn_zones[rand_index]

      if RotorOps.defending then
        ctld.spawnGroupAtTrigger("blue", 5, zone, 1000)
      else
        ctld.spawnGroupAtTrigger("red", 5, zone, 1000)
      end

      RotorOps.inf_spawns_avail = RotorOps.inf_spawns_avail - 1
      env.info("ROTOR OPS: Spawned infantry. "..RotorOps.inf_spawns_avail.." spawns remaining in "..zone)
    end
  end
  
  if RotorOps.inf_spawns_avail > 0 and defenders_remaining_percent <= RotorOps.inf_spawn_trigger_percent then
    spawnInfantry()
  end
  
  --voiceovers based on remaining defenders
  if not low_units_message_fired then
    if defenders_remaining_percent <= 40 then
      low_units_message_fired = true
      env.info("ROTOR OPS: low units remaining in zone")
      if RotorOps.defending then
        RotorOps.gameMsg(RotorOps.gameMsgs.enemy_almost_cleared, math.random(1, #RotorOps.gameMsgs.enemy_almost_cleared))
      else
        RotorOps.gameMsg(RotorOps.gameMsgs.almost_cleared, math.random(1, #RotorOps.gameMsgs.almost_cleared))
      end
    end  
  end
   
  

   --zone status display
   local message = ""
   local header = ""
   local body = ""
   if RotorOps.defending == true then
     header = "[DEFEND "..RotorOps.active_zone .. "]   " 
     body = "RED: " ..#attacking_infantry.. " infantry, " .. #attacking_vehicles .. " vehicles.  BLUE: "..#defending_infantry.. " infantry, " .. #defending_vehicles.." vehicles. ["..defenders_remaining_percent.."%]"
   else 
     header = "[ATTACK "..RotorOps.active_zone .. "]   " 
     body = "RED: " ..#defending_infantry.. " infantry, " .. #defending_vehicles .. " vehicles.  BLUE: "..#attacking_infantry.. " infantry, " .. #attacking_vehicles.." vehicles. ["..defenders_remaining_percent.."%]"   
   end

   message = header .. body
   if RotorOps.zone_status_display then 
     game_message_buffer[#game_message_buffer + 1] = {message, ""} --don't load the buffer faster than it's cleared.
   end
   local id = timer.scheduleFunction(RotorOps.assessUnitsInZone, 1, timer.getTime() + 10)
end




function RotorOps.drawZones()  --this could use a lot of work, we should use trigger.action.removeMark and some way of managing ids created
  local zones = RotorOps.zones
  local previous_point

  
  for index, zone in pairs(zones)
  do
    local point = trigger.misc.getZone(zone.name).point
    local radius = trigger.misc.getZone(zone.name).radius
    local coalition = -1
    local id = index  --this must be UNIQUE!
    local color = {1, 1, 1, 0.5}
    local fill_color = {1, 1, 1, 0.1}
    local text_fill_color = {0, 0, 0, 0}
    local line_type = 5 --1 Solid  2 Dashed  3 Dotted  4 Dot Dash  5 Long Dash  6 Two Dash
    local font_size = 20
    local read_only = false
    local text = index..". "..zone.name
    if zone.name == RotorOps.active_zone then
      id = id + 300
      color = {1, 1, 1, 0.2}
      fill_color = {1, 0, 0, 0.05}
    end
    if previous_point ~= nill then
      --trigger.action.lineToAll(coalition, id + 200, point, previous_point, color, line_type)
    end
    previous_point = point
    trigger.action.circleToAll(coalition, id, point, radius, color, fill_color, line_type)
    trigger.action.textToAll(coalition, id + 100, point, color, text_fill_color, font_size, read_only, text)
  end
  

  for index, pickup_zone in pairs(RotorOps.ctld_pickup_zones)
  do
    for c_index, c_zone in pairs(ctld.pickupZones)
    do
      if pickup_zone == c_zone[1] then
       --debugMsg("found our zone in ctld zones, status: "..c_zone[4])
       local ctld_zone_status = c_zone[4]
       local point = trigger.misc.getZone(pickup_zone).point
       local radius = trigger.misc.getZone(pickup_zone).radius
       local coalition = -1
       local id = index + 150  --this must be UNIQUE!
       local color = {1, 1, 1, 0.5}
       local fill_color = {0, 0.8, 0, 0.1}
       local line_type = 5 --1 Solid  2 Dashed  3 Dotted  4 Dot Dash  5 Long Dash  6 Two Dash
       if ctld_zone_status == 'yes' or ctld_zone_status == 1 then
        --debugMsg("draw the pickup zone")
        trigger.action.circleToAll(coalition, id, point, radius, color, fill_color, line_type)
       end
      end  
    end
  end

  
end



function RotorOps.setActiveZone(new_index) 
  local old_index = RotorOps.active_zone_index
  if new_index > #RotorOps.zones then 
    new_index = #RotorOps.zones 
  end
  if new_index < 1 then 
    new_index = 1 
  end
  
  RotorOps.active_zone_index = new_index
  RotorOps.active_zone = RotorOps.zones[new_index].name
  
  if new_index ~= old_index then  --the active zone is changing
    
    if not RotorOps.defending then
    
      if old_index > 0 then 
        ctld.activatePickupZone(RotorOps.zones[old_index].name)  --make the captured zone a pickup zone
      end
      ctld.deactivatePickupZone(RotorOps.zones[new_index].name)
    end

    RotorOps.game_state = new_index
    trigger.action.setUserFlag(RotorOps.game_state_flag, new_index)
    
    if new_index > old_index then 
      if RotorOps.defending == true then
        RotorOps.gameMsg(RotorOps.gameMsgs.enemy_pushing, new_index)
      else
        RotorOps.gameMsg(RotorOps.gameMsgs.push, new_index)
        RotorOps.gameMsg(RotorOps.gameMsgs.get_troops_to_zone, new_index) 
      end
    end 
    
    local staged_groups = RotorOps.groupsFromUnits(RotorOps.staged_units)
    for index, group in pairs(staged_groups) do
      RotorOps.aiTask(group,"move_to_active_zone", RotorOps.zones[RotorOps.active_zone_index].name) --send vehicles to next zone; use move_to_active_zone so units don't get stuck if the active zone moves before they arrive
    end
    

  end
  

  --debugMsg("active zone: "..RotorOps.active_zone.."  old zone: "..RotorOps.zones[old_index].name)  
  
  RotorOps.drawZones()
end


--make some changes to the CTLD script/settings
function RotorOps.setupCTLD()
  if type(ctld.pickupZones[1][2]) == "number" then --ctld converts its string table to integer on load, so we'll see if that's happened already
    trigger.action.outText("ERROR: CTLD Loaded Too Soon!!", 90)
    return
  end
  
  ctld.enableCrates = RotorOps.CTLD_crates
  ctld.enabledFOBBuilding = false
  ctld.JTAC_lock = "vehicle"
  ctld.location_DMS = true
  ctld.numberOfTroops = 24 --max loading size
  ctld.maximumSearchDistance = 4000 -- max distance for troops to search for enemy
  ctld.maximumMoveDistance = 0 -- max distance for troops to move from drop point if no enemy is nearby
  
  ctld.unitLoadLimits = {
    -- Remove the -- below to turn on options
     ["SA342Mistral"] = 4,
     ["SA342L"] = 4,
     ["SA342M"] = 4,
     ["UH-1H"] = 10,
     ["Mi-8MT"] = 24,
     ["Mi-24P"] = 8,
   }
   
   ctld.loadableGroups = {  
    {name = "Small Standard Group (4)", inf = 2, mg = 1, at = 1 },
    {name = "Standard Group (8)", inf = 4, mg = 2, at = 2 }, -- will make a loadable group with 6 infantry, 2 MGs and 2 anti-tank for both coalitions
    {name = "Anti Air (5)", inf = 2, aa = 3  },
    {name = "Anti Tank (8)", inf = 2, at = 6  },
    {name = "Mortar Squad (6)", mortar = 6 },
    {name = "JTAC Group (4)", inf = 3, jtac = 1 },
    {name = "Small Platoon (16)", inf = 9, mg = 3, at = 3, aa = 1 },
    {name = "Platoon (24)", inf = 10, mg = 5, at = 6, aa = 3 },
    
}
end


function RotorOps.setupRadioMenu()
  commandDB['conflict_zones_menu'] = missionCommands.addSubMenu( "ROTOR OPS")
  local conflict_zones_menu = commandDB['conflict_zones_menu']
  commandDB['start_conflict'] = missionCommands.addCommand( "Start conflict"  , conflict_zones_menu , RotorOps.startConflict)

end



function RotorOps.addZone(_name, _zone_defenders_flag) 
  if trigger.misc.getZone(_name) == nil then
    trigger.action.outText(_name.." trigger zone missing!  Check RotorOps setup!", 60)
    env.warning(_name.." trigger zone missing!  Check RotorOps setup!")
  end
  table.insert(RotorOps.zones, {name = _name, defenders_status_flag = _zone_defenders_flag})
  trigger.action.setUserFlag(_zone_defenders_flag, 101)
  RotorOps.drawZones()
  RotorOps.addPickupZone(_name, "blue", -1, "no", 0)
end

function RotorOps.stagingZone(_name)
  if trigger.misc.getZone(_name) == nil then
    trigger.action.outText(_name.." trigger zone missing!  Check RotorOps setup!", 60)
    env.warning(_name.." trigger zone missing!  Check RotorOps setup!")
  end
  RotorOps.addPickupZone(_name, "blue", -1, "no", 0)
  RotorOps.staging_zone = _name
end



--function to automatically add transport craft to ctld, rather than having to define each in the mission editor
function RotorOps.addPilots(var)
   for uName, uData in pairs(mist.DBs.humansByName) do
     if hasValue(RotorOps.transports, uData.type) then
       if hasValue(ctld.transportPilotNames, uData.unitName) ~= true then
         ctld.transportPilotNames [#ctld.transportPilotNames + 1] = uData.unitName
       --else trigger.action.outText("player already in pilot table", 5)
       end
     end
   end
 local id = timer.scheduleFunction(RotorOps.addPilots, 1, timer.getTime() + 15)
end


function RotorOps.setupConflict(_game_state_flag)
  RotorOps.addPilots(1)
  RotorOps.setupCTLD()
  --RotorOps.setupRadioMenu()
  RotorOps.game_state_flag = _game_state_flag
  RotorOps.game_state = RotorOps.game_states.not_started
  processMsgBuffer()
  trigger.action.setUserFlag(RotorOps.game_state_flag, RotorOps.game_states.not_started)
  trigger.action.outText("ALL TROOPS GET TO TRANSPORT AND PREPARE FOR DEPLOYMENT!" , 10, false)
  if RotorOps.CTLD_sound_effects == true then
    local timer_id = timer.scheduleFunction(RotorOps.registerCtldCallbacks, 1, timer.getTime() + 5) 
  end
end


function RotorOps.addPickupZone(zone_name, smoke, limit, active, side)
  RotorOps.ctld_pickup_zones[#RotorOps.ctld_pickup_zones + 1] = zone_name
  ctld.pickupZones[#ctld.pickupZones + 1] = {zone_name, smoke, limit, active, side}
end
 

function RotorOps.startConflict()
  if RotorOps.game_state ~= RotorOps.game_states.not_started then return end 

  --make some changes to the radio menu
  --local conflict_zones_menu = commandDB['conflict_zones_menu']
  --missionCommands.removeItem(commandDB['start_conflict']) 
  --commandDB['clear_zone'] = missionCommands.addCommand( "[CHEAT] Force Clear Zone"  , conflict_zones_menu , RotorOps.clearActiveZone)

  RotorOps.staged_units = mist.getUnitsInZones(mist.makeUnitTable({'[all][vehicle]'}), {RotorOps.staging_zone})
  
  if RotorOps.staged_units[1] == nil then
    trigger.action.outText("RotorOps failed: You must place ground units in the staging and conflict zones!" , 60, false)
    env.warning("No units in staging zone!  Check RotorOps setup!")
    return
  end
  
  if RotorOps.staged_units[1]:getCoalition() == 1 then  --check the coalition in the staging zone to see if we're defending
    RotorOps.defending = true
    RotorOps.gameMsg(RotorOps.gameMsgs.start_defense)
    ctld.activatePickupZone(RotorOps.zones[#RotorOps.zones].name)  --make the last zone a pickup zone for defenders
    ctld.deactivatePickupZone(RotorOps.staging_zone) 
  else
    RotorOps.gameMsg(RotorOps.gameMsgs.start)
    ctld.activatePickupZone(RotorOps.staging_zone)
  end
  
  RotorOps.setActiveZone(1)
  
  local id = timer.scheduleFunction(RotorOps.assessUnitsInZone, 1, timer.getTime() + 5)
  world.addEventHandler(RotorOps.eventHandler)
end






