RotorOps = {}

--RotorOps settings that are safe to change dynamically (ideally from the mission editor in DO SCRIPT for ease of use)
RotorOps.voice_overs = true
RotorOps.ground_speed = 60 --max speed for ground vehicles moving between zones
RotorOps.zone_status_display = true --constantly show units remaining and zone status on screen 
RotorOps.max_units_left = 0 --allow clearing the zone when a few units are left to prevent frustration with units getting stuck in buildings etc
RotorOps.force_offroad = false  --affects "move_to_zone" tasks only


--RotorOps settings that are proabably safe to change
RotorOps.transports = {'UH-1H', 'Mi-8MT', 'Mi-24P', 'SA342M', 'SA342L', 'SA342Mistral'} --players flying these will have ctld transport access
RotorOps.auto_push = true --should attacking ground units move to the next zone after clearing?
RotorOps.CTLD_crates = false 


--RotorOps variables that are safe to read only
RotorOps.game_states = {not_started = 0, alpha_active = 1, bravo_active = 2, charlie_active = 3, delta_active = 4, won = 99} --game level user flag will use these values
RotorOps.game_state = 0 
RotorOps.zones = {}
RotorOps.active_zone = "" --name of the active zone
RotorOps.active_zone_index = 0
RotorOps.game_state_flag = 1  --user flag to store the game state
RotorOps.staging_zone = ""
RotorOps.ctld_pickup_zones = {} --keep track of ctld zones we've added, mainly for map markup
RotorOps.ai_red_infantry_groups = {} 
RotorOps.ai_blue_infantry_groups = {} 
RotorOps.ai_red_vehicle_groups = {} 
RotorOps.ai_blue_vehicle_groups = {} 
RotorOps.ai_tasks = {} 

trigger.action.outText("ROTOR OPS STARTED", 5)
env.info("ROTOR OPS STARTED")

local staged_units --table of ground units that started in the staging zone
local commandDB = {} 
local game_message_buffer = {}
local active_zone_initial_enemy_units


local gameMsgs = {
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
  
    
}

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
    return table[key] ~= nil
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

local function isUnitInZone(unit, zone_name)
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


local function gameMsg(event, _index)  
  local index = 1 
  if _index ~= nill then
    index = _index + 1 
  end
  if tableHasKey(event, index) then
    game_message_buffer[#game_message_buffer + 1] = {event[index][1], event[index][2]}
  else env.info("ROTOR OPS could not find entry for "..key)
  end
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
function RotorOps.spawnInfantryOnGrp(grp, src_grp_name, ai_task) --allow to spawn on other group units
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
      RotorOps.aiTask({grp = new_grp, ai_task=ai_task})
  else debugMsg("Infantry failed to spawn. ")  
  end
end


--Easy way to deploy troops from a vehicle with waypoint action.  Spawns from the first valid unit found in a group
function RotorOps.deployTroops(quantity, target_group)
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
    if isUnitInZone(valid_unit, zone.name) then 
      if side == "red" then
        gameMsg(gameMsgs.troops_dropped, index)
      else
        gameMsg(gameMsgs.friendly_troops_dropped, index)
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
  local zone = vars.zone

  if vars.zone then zone = vars.zone end
  --debugMsg("tasking: "..group_name.." : "..task .." zone:"..zone) 
  
  if Group.isExist(Group.getByName(group_name)) ~= true or #Group.getByName(group_name):getUnits() < 1 then
    debugMsg("group no longer exists")
    RotorOps.ai_tasks[group_name] = nil
    return
  end  
  
 --if Group.getByName(group_name):getController():hasTask() == false then   --our implementation of hasTask does not seem to be working for vehicles
  
  if task == "patrol" then
    local vars = {}
    vars.grp = Group.getByName(group_name)
    vars.radius = 500
    RotorOps.patrolRadius(vars) --takes a group object, not name
    update_interval = math.random(40,70)
  elseif task == "aggressive" then 
    local vars = {}
    vars.grp = Group.getByName(group_name)
    vars.radius = 5000 
    update_interval = math.random(20,40)
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
   
   --find and sort units found in the active zone
   local red_ground_units = mist.getUnitsInZones(mist.makeUnitTable({'[red][vehicle]'}), {RotorOps.active_zone})  
   local red_infantry = RotorOps.sortOutInfantry(red_ground_units).infantry
   local red_vehicles = RotorOps.sortOutInfantry(red_ground_units).not_infantry
   local blue_ground_units = mist.getUnitsInZones(mist.makeUnitTable({'[blue][vehicle]'}), {RotorOps.active_zone})
   local blue_infantry = RotorOps.sortOutInfantry(blue_ground_units).infantry
   local blue_vehicles = RotorOps.sortOutInfantry(blue_ground_units).not_infantry
   
--ground unit ai stuff
   RotorOps.ai_red_infantry_groups = RotorOps.groupsFromUnits(red_infantry)
   RotorOps.ai_blue_infantry_groups = RotorOps.groupsFromUnits(blue_infantry)
   RotorOps.ai_red_vehicle_groups = RotorOps.groupsFromUnits(red_vehicles)
   RotorOps.ai_blue_vehicle_groups = RotorOps.groupsFromUnits(blue_vehicles)
   
  for index, group in pairs(RotorOps.ai_red_infantry_groups) do 
    if group then
      RotorOps.aiTask(group, "patrol")
    end
  end
  
  for index, group in pairs(RotorOps.ai_blue_infantry_groups) do 
    if group then
      RotorOps.aiTask(group, "clear_zone", RotorOps.active_zone)
    end
  end
  
  for index, group in pairs(RotorOps.ai_blue_vehicle_groups) do 
    if group then
      RotorOps.aiTask(group, "clear_zone", RotorOps.active_zone)  
    end
  end
  

   --let's compare the defending units in zone vs their initial numbers and set a game flag
   if not active_zone_initial_enemy_units then
     --debugMsg("taking stock of the active zone")
     active_zone_initial_enemy_units = red_ground_units
   end
   
   local defenders_status_flag = RotorOps.zones[RotorOps.active_zone_index].defenders_status_flag
   if #active_zone_initial_enemy_units == 0 then active_zone_initial_enemy_units = 1 end --prevent divide by zero
   local defenders_remaining_percent = math.floor((#red_ground_units / #active_zone_initial_enemy_units) * 100) 
     
     if #red_ground_units <= RotorOps.max_units_left then  --if we should declare the zone cleared
       active_zone_initial_enemy_units = nil
       defenders_remaining_percent = 0
       trigger.action.setUserFlag(defenders_status_flag, 0)  --set the zone's flag to cleared
       gameMsg(gameMsgs.cleared, RotorOps.active_zone_index)
       
       if RotorOps.auto_push then                                 --push units to the next zone
         RotorOps.setActiveZone(RotorOps.active_zone_index + 1)
         local staged_groups = RotorOps.groupsFromUnits(staged_units)
         for index, group in pairs(staged_groups) do
           RotorOps.aiTask(group,"move_to_active_zone", RotorOps.zones[RotorOps.active_zone_index].name) --send vehicles to next zone
         end
       end  
       
     else 
       trigger.action.setUserFlag(defenders_status_flag, defenders_remaining_percent)  --set the zones flage to indicate the status of remaining enemies
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
    changeGameState(RotorOps.game_states.won)
    gameMsg(gameMsgs.success)
    return --we won't reset our timer to fire this function again
   end
   


   --zone status display
   local message = ""
   local header = ""
   local body = ""
   if defenders_remaining_percent == 0 then
     header = "["..RotorOps.active_zone .. " CLEARED!]   " 
   else
     header = "[BATTLE FOR "..RotorOps.active_zone .. "]   " 
   end
   body = "RED: " ..#red_infantry.. " infantry, " .. #red_vehicles .. " vehicles.  BLUE: "..#blue_infantry.. " infantry, " .. #blue_vehicles.." vehicles. ["..defenders_remaining_percent.."%]"

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



local function changeGameState(new_state)
  RotorOps.game_state = new_state
  trigger.action.setUserFlag(RotorOps.game_state_flag, new_state)
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
    if old_index > 0 then 
      ctld.activatePickupZone(RotorOps.zones[old_index].name)
    end
    ctld.deactivatePickupZone(RotorOps.zones[new_index].name)
    changeGameState(new_index)
    if new_index < old_index then gameMsg(gameMsgs.fallback, new_index) end
    if new_index > old_index then gameMsg(gameMsgs.get_troops_to_zone, new_index) end 
  end
  

  --debugMsg("active zone: "..RotorOps.active_zone.."  old zone: "..RotorOps.zones[old_index].name)  
  
  RotorOps.drawZones()
end


--make some changes to the CTLD script/settings
function RotorOps.setupCTLD()
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
    {name = "Standard Group (8)", inf = 4, mg = 2, at = 2 }, -- will make a loadable group with 6 infantry, 2 MGs and 2 anti-tank for both coalitions
    {name = "Anti Air (5)", inf = 2, aa = 3  },
    {name = "Anti Tank (8)", inf = 2, at = 6  },
    {name = "Mortar Squad (6)", mortar = 6 },
    {name = "Small Standard Group (4)", inf = 2, mg = 1, at = 1 },
    {name = "JTAC Group (5)", inf = 4, jtac = 1 },
    {name = "Single JTAC (1)", jtac = 1 },
    {name = "Small Platoon (16)", inf = 10, mg = 3, at = 3 },
    {name = "Platoon (24)", inf = 12, mg = 4, at = 3, aa = 1 },
    
}
end


function RotorOps.setupRadioMenu()
  commandDB['conflict_zones_menu'] = missionCommands.addSubMenu( "ROTOR OPS")
  local conflict_zones_menu = commandDB['conflict_zones_menu']
  commandDB['start_conflict'] = missionCommands.addCommand( "Start conflict"  , conflict_zones_menu , RotorOps.startConflict)

end



function RotorOps.addZone(_name, _zone_defenders_flag) 
  table.insert(RotorOps.zones, {name = _name, defenders_status_flag = _zone_defenders_flag})
  trigger.action.setUserFlag(_zone_defenders_flag, 101)
  RotorOps.drawZones()
  RotorOps.addPickupZone(_name, "blue", -1, "no", 0)
end

function RotorOps.stagingZone(_name)
  RotorOps.addPickupZone(_name, "blue", -1, "yes", 0)
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
  changeGameState(RotorOps.game_states.not_started)
  trigger.action.outText("ALL TROOPS GET TO TRANSPORT AND PREPARE FOR DEPLOYMENT!" , 10, false)
  
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
  
  RotorOps.setActiveZone(1)
  gameMsg(gameMsgs.start)
  gameMsg(gameMsgs.push, 1)
  processMsgBuffer()
  
  staged_units = mist.getUnitsInZones(mist.makeUnitTable({'[all][vehicle]'}), {RotorOps.staging_zone})
  local staged_groups = RotorOps.groupsFromUnits(staged_units)
  for index, group in pairs(staged_groups) do
    RotorOps.aiTask(group,"move_to_active_zone")
  end

  
  local id = timer.scheduleFunction(RotorOps.assessUnitsInZone, 1, timer.getTime() + 5)
end



