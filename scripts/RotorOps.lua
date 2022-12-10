RotorOps = {}
RotorOps.version = "1.3.2"
local debug = true



---[[ROTOROPS OPTIONS]]---
--- Protip: change these options from the mission editor rather than changing the script file itself.  See documentation on github for details.


--RotorOps settings that can be changed dynamically (ideally from the mission editor in DO SCRIPT for portability). You can change these while the script is running, at any time. Be sure of your syntax and test...errors may crash the script.
RotorOps.voice_overs = true
RotorOps.ground_speed = 60 --max speed for ground vehicles moving between zones. Doesn't have much effect since always limited by slowest vehicle in group
RotorOps.zone_status_display = true --constantly show units remaining and zone status on screen 
RotorOps.max_units_left = 0 --allow clearing the zone when a few units are left to prevent frustration with units getting stuck in buildings etc
RotorOps.force_offroad = false  --affects "move_to_zone" tasks only
RotorOps.apcs_spawn_infantry = false  --apcs will unload troops when arriving to a new zone
RotorOps.auto_push = true --should attacking ground units move to the next zone after clearing? 
RotorOps.defending_vehicles_disperse = true

RotorOps.inf_spawns_avail = 0 --this is the number of infantry group spawn events remaining in the active zone
RotorOps.inf_spawn_chance = 25 -- 0-100 the chance of spawning infantry in an active zone spawn zone, per 'assessUnitsInZone' loop (10 seconds) 
RotorOps.inf_spawn_trigger_percent = 70 --infantry has a chance of spawning if the percentage of defenders remaining in zone is less than this value
--RotorOps.inf_spawns_per_zone = 3 --number of infantry groups to spawn per zone
RotorOps.inf_spawn_messages = true --voiceovers and messages for infantry spawns
RotorOps.inf_spawn_blue = {mg=1,at=0,aa=0,inf=4,mortar=0} --can be an integer quantity, or a ctld defined group table
RotorOps.inf_spawn_red = {mg=1,at=0,aa=0,inf=4,mortar=0} --can be an integer quantity, or a ctld defined group table
RotorOps.inf_apc_group = {mg=1,at=0,aa=0,inf=3,mortar=0} --can be an integer quantity, or a ctld defined group table
RotorOps.inf_spawns_total = 0 --number of infantry groups to spawn per game

RotorOps.farp_smoke_color = 2  -- Green=0 Red=1 White=2 Orange=3 Blue=4 NONE= -1


--RotorOps settings that are safe to change only before calling setupConflict()
RotorOps.transports = {'UH-1H', 'Mi-8MT', 'Mi-24P', 'SA342M', 'SA342L', 'SA342Mistral', 'UH-60L'} --players flying these will have ctld transport access 
RotorOps.CTLD_crates = false 
RotorOps.CTLD_sound_effects = true --sound effects for troop pickup/dropoffs
RotorOps.exclude_ai_group_name = "Static"  --include this somewhere in a group name to exclude the group from being tasked in the active zone
RotorOps.pickup_zone_smoke = "blue"
RotorOps.ai_task_by_name = true  --allow tasking all groups that include key strings in their group names eg 'Patrol'
RotorOps.ai_task_by_name_scheduler = true --continually search active groups for key strings and ai tasking
RotorOps.patrol_task_string = 'patrol' --default string to search group names for the patrol task. requires ai_task_by_name
RotorOps.aggressive_task_string = 'aggressive' --default string to search group names for the aggressive task. requires ai_task_by_name
RotorOps.move_to_active_task_string = "activezone" --default string to search group names for the move to active zone task. requires ai_task_by_name
RotorOps.shift_task_string = "shift"
RotorOps.guard_task_string = "guard"
--RotorOps.patrol_task_radius = 100 --patrol search radius
--RotorOps.aggressive_task_radius = 1000 --aggressive search radius  --not implementing for now until more time for testing
RotorOps.defending_vehicles_behavior = "shift"  --available options: 'none', 'patrol', 'shift'
RotorOps.farp_pickups = true --allow ctld troop pickup at FARPs
RotorOps.enable_staging_pickzones = true
RotorOps.persistent_tasking = false --prevent the script from restasking in a loop --might help with odd movement patterns between zones

--RotorOps settings that are safe to change only in the script config option in the scenario config file
RotorOps.draw_conflict_zones = true

---[[END OF OPTIONS]]---




--RotorOps variables that are safe to read only
RotorOps.game_states = {not_started = 0, alpha_active = 1, bravo_active = 2, charlie_active = 3, delta_active = 4, lost = 98, won = 99} --game level user flag will use these values
RotorOps.game_state = 0 
RotorOps.zones = {}
RotorOps.active_zone = "" --name of the active zone
RotorOps.active_zone_index = 0
RotorOps.game_state_flag = 1  --user flag to store the game state
RotorOps.staging_zones = {}
RotorOps.ai_defending_infantry_groups = {} 
RotorOps.ai_attacking_infantry_groups = {} 
RotorOps.ai_defending_vehicle_groups = {} 
RotorOps.ai_attacking_vehicle_groups = {} 
RotorOps.ai_tasks = {} 
RotorOps.defending = false
RotorOps.staged_units_flag = 111  -- shows a percentage of the units found in the staging zone when the game starts. you can also use 'ROPS_ATTACKERS' for readability

--fighter variables
local fighters_by_detected_unitname = {}
RotorOps.fighter_radar_unit_string = 'FIGHTER_DEPLOYMENT'  --any unit capable of detecting aircraft by radar can be used as a detection source to spawn intercept fighters, if this string is in the unit name
RotorOps.fighter_min_detection_alt = 609 --aircraft below this agl altitude (meters) will not be 'detected' by radar units. 
RotorOps.fighter_max_detection_dist = 7000 --default max range from radar to target in order for intercept fighters to spawn (you can also set range for individual radar sources via unit name)
RotorOps.fighter_max_active = 4 --total maximum active deployed fighters, shared between red/blue

trigger.action.outText("ROTOR OPS STARTED: "..RotorOps.version, 5)
env.info("ROTOR OPS STARTED: "..RotorOps.version)

RotorOps.staged_units = {} --table of ground units that started in the staging zone
RotorOps.staged_units_by_zone = {}
RotorOps.eventHandler = {}
local commandDB = {} 
local game_message_buffer = {}
local active_zone_initial_defenders
local initial_stage_units
local apcs = {} --table to keep track of infantry vehicles
local low_units_message_fired = false
local inf_spawn_zones = {}
local cooldown = {
  ["attack_helo_msg"] = 0, 
  ["attack_plane_msg"] = 0,
  ["trans_helo_msg"] = 0,
  ["e_fighters_inbound_msg"] = 0,
}
local zone_defenders_flags = {
  'ROPS_A_DEFENDERS',
  'ROPS_B_DEFENDERS',
  'ROPS_C_DEFENDERS',
  'ROPS_D_DEFENDERS',
}
RotorOps.farp_names = {}


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
  attack_helos = {
    {'ENEMY ATTACK HELICOPTERS INBOUND!', 'enemy_attack_choppers.ogg'},
  },
  attack_planes = {
    {'ENEMY ATTACK PLANES INBOUND!', 'enemy_attack_planes.ogg'},
  },
  attack_helos_prep = {
    {'ENEMY ATTACK HELICOPTERS PREPARING FOR TAKEOFF!', 'e_attack_helicopters_preparing.ogg'},
  },
  attack_planes_prep = {
    {'ENEMY ATTACK PLANES PREPARING FOR TAKEOFF!', 'e_attack_planes_preparing.ogg'},
  },
  infantry_spawned = {
    {'ENEMY CONTACTS IN THE OPEN!', 'e_infantry_spawn1.ogg'},
    {'ENEMY TROOPS LEAVING COVER!', 'e_infantry_spawn2.ogg'},
    {'VISUAL ON ENEMY INFANTRY!', 'e_infantry_spawn3.ogg'},
    {'ENEMY CONTACTS IN THE ACTIVE!', 'e_infantry_spawn4.ogg'},
    {'ENEMY TROOPS IN THE ACTIVE!', 'e_infantry_spawn5.ogg'},
    {'VISUAL ON ENEMY TROOPS!', 'e_infantry_spawn6.ogg'},
  },
  farp_established = {
    {'NEW FARP AVAILABLE!', 'forward_base_established.ogg'},
    {'NEW FARP AT ALPHA!', 'forward_base_established.ogg'},
    {'NEW FARP AT BRAVO!', 'forward_base_established.ogg'},
    {'NEW FARP AT CHARLIE!', 'forward_base_established.ogg'},
    {'NEW FARP AT DELTA!', 'forward_base_established.ogg'},
  },
  transp_helos_toff = {
    {'ENEMY TRANSPORT HELICOPTERS INBOUND!', 'enemy_chopper_inbound.ogg'},
  },
  enemy_fighters_inbound = {
    {'ENEMY FIGHTERS INBOUND!', 'enemy_fighters_inbound.ogg'},
  },
  

}


local sound_effects = {
    ["troop_pickup"] = {'troops_load_ao.ogg', 'troops_load_ready.ogg', 'troops_load_to_action.ogg',},
    ["troop_dropoff"] = {'troops_unload_thanks.ogg', 'troops_unload_everybody_off.ogg', 'troops_unload_get_off.ogg', 'troops_unload_here_we_go.ogg', 'troops_unload_moving_out.ogg',},
}


function RotorOps.getTime()
  return timer.getAbsTime() - timer.getTime0() --time since mission started
end



function RotorOps.eventHandler:onEvent(event)
   ---ENGINE STARTUP EVENTS
   if (world.event.S_EVENT_ENGINE_STARTUP  == event.id) then  --play some sound files when a player starts engines  
     local initiator = event.initiator:getGroup():getID()
    
     if #event.initiator:getGroup():getUnits() == 1 and RotorOps.voice_overs then --if there are no other units in the player flight group (preventing duplicated messages for ai wingman flights)
       if RotorOps.defending then
         trigger.action.outSoundForGroup(initiator , RotorOps.gameMsgs.enemy_pushing[RotorOps.active_zone_index + 1][2])
       else
         trigger.action.outSoundForGroup(initiator , RotorOps.gameMsgs.push[RotorOps.active_zone_index + 1][2])
       end
     end
    
   end
   
   ---TAKEOFF EVENTS
   if (world.event.S_EVENT_TAKEOFF  == event.id) then
     local initiator_name = event.initiator:getGroup():getName()
     
     if (initiator_name == "Enemy Attack Helicopters") then
       --we use flights of two aircraft which triggers two events, but we only want to use one event so we use a cooldown timer
       if ((RotorOps.getTime() - cooldown["attack_helo_msg"]) > 90) then
         RotorOps.gameMsg(RotorOps.gameMsgs.attack_helos)
         cooldown["attack_helo_msg"] = RotorOps.getTime()
       else 
         env.warning("RotorOps attack helo message skipped")
       end
     end
         
     if initiator_name == "Enemy Attack Planes" then
       if ((RotorOps.getTime() - cooldown["attack_plane_msg"]) > 90) then
         RotorOps.gameMsg(RotorOps.gameMsgs.attack_planes)
         cooldown["attack_plane_msg"] = RotorOps.getTime()
       else 
         env.warning("RotorOps attack plane message skipped")
       end
     end
     
     if initiator_name == "Enemy Transport Helicopters" then  --we're using mist clone now so group name will not match
       env.info("Transport helicopter took off")
       
       if ((RotorOps.getTime() - cooldown["trans_helo_msg"]) > 90) then
         timer.scheduleFunction(function()RotorOps.gameMsg(RotorOps.gameMsgs.transp_helos_toff) end, {}, timer.getTime() + 1)
         cooldown["trans_helo_msg"] = RotorOps.getTime()
       else 
         env.warning("RotorOps transport helo message skipped")
       end
     end
     
   end
   
   ---BASE CAPTURE EVENTS  --doesn't work with FARPs..
   if (world.event.S_EVENT_BASE_CAPTURED == event.id) then
     env.info("Base captured")   
     if (event.place:getCoalition() == 2) then
       env.info("Blue forces captured a base via place attribute")
     end
   end
  
   
end



function RotorOps.registerCtldCallbacks(var)
ctld.addCallback(function(_args)
    local action = _args.action
    local unit = _args.unit
    local picked_troops = _args.onboard
    local dropped_troops = _args.unloaded
    --env.info("ctld callback: ".. mist.utils.tableShow(_args)) 
	  
	  
    if action == "load_troops" or action == "extract_troops" then
      trigger.action.outSoundForGroup(unit:getGroup():getID() , sound_effects.troop_pickup[math.random(1, #sound_effects.troop_pickup)])
    elseif action == "unload_troops_zone" or action == "dropped_troops" then
      trigger.action.outSoundForGroup(unit:getGroup():getID() , sound_effects.troop_dropoff[math.random(1, #sound_effects.troop_dropoff)])
      if RotorOps.isUnitInZone(unit, RotorOps.active_zone) then
        local id = timer.scheduleFunction(RotorOps.gameMsgHandler, RotorOps.gameMsgs.friendly_troops_dropped, timer.getTime() + 6)  --allow some extra time so we don't step on the player's troop/unload sound effects

      end
      if dropped_troops.jtac == true then
        local id = timer.scheduleFunction(RotorOps.gameMsgHandler, RotorOps.gameMsgs.jtac, timer.getTime() + 12) --allow some extra time so we don't step on the player's troop/unload sound effects
      end
    end

end)
end

---UTILITY FUNCTIONS---

local function debugMsg(text)
  if(debug) then
    --trigger.action.outText(text, 5)
    env.info("ROTOROPS_DEBUG: "..text)
  end
end


local function debugTable(table)
  --trigger.action.outText("dbg: ".. mist.utils.tableShow(table), 5) 
  env.info("ROTOROPS_DEBUG: ".. mist.utils.tableShow(table))
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
  --local distance = mist.utils.get2DDist(unit:getPoint(), zone.point)
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
    env.info("RotorOps: "..message[1])
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
 if not group_obj then
  return nil
 end
 if group_obj:isExist() ~= true then 
  return nil 
 end
 local first_valid_unit
 for index, unit in pairs(group_obj:getUnits())
 do
   if unit:isExist() == true then
     first_valid_unit = unit
     break
   else --trigger.action.outText("a unit no longer exists", 15) 
   end 
 end
 return first_valid_unit
end

--"static" in this case, is our groups/units that we don't want controlled by conflict zone tasks
local function isStaticUnit(unit)
  local unit_obj
  if type(unit) == 'string' then
    unit_obj = Unit.getByName(unit)
  else
    unit_obj = unit
  end 
  if string.find(unit_obj:getGroup():getName():lower(), RotorOps.exclude_ai_group_name:lower()) then
    return true
  else
    return false
  end	
end

--"static" in this case, is our groups/units that we don't want controlled by conflict zone tasks
local function isStaticGroup(group)
  local group_obj
  if type(group) == 'string' then
    group_obj = Group.getByName(group)
  else
    group_obj = group
  end 
  if string.find(group_obj:getName():lower(), RotorOps.exclude_ai_group_name:lower()) then
    return true
  else
    return false
  end	
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



--Easy way to deploy troops from a vehicle with waypoint action.  Spawns from the first valid unit found in a group
function RotorOps.deployTroops(quantity, target_group, announce)
  local target_group_obj
  if type(target_group) == 'string' then
    target_group_obj = Group.getByName(target_group)
  else
    target_group_obj = target_group
  end 
  debugMsg("DeployTroops on group: "..target_group_obj:getName())
  local valid_unit = RotorOps.getValidUnitFromGroup(target_group_obj)
  if not valid_unit then return end
  local coal = valid_unit:getCoalition()
  local side = "red"
  if coal == 2 then side = "blue" end
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



--see list of tasks in aiExecute. Zone/point is optional for many tasks. Works with group name or object/table
function RotorOps.aiTask(grp, task, zone, point)
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
	 RotorOps.ai_tasks[group_name].point = point
   else 
     local vars = {}
     vars.group_name = group_name
     --vars.last_task = task
     if zone then 
       vars.zone = zone 
     end
	 if point then
	   vars.point = point
	 end
     local timer_id = timer.scheduleFunction(RotorOps.aiExecute, vars, timer.getTime() + 5)
     RotorOps.ai_tasks[group_name] = {['timer_id'] = timer_id, ['ai_task'] = task, ['zone'] = zone, ['point'] = point}
   end
end


--add units to the staged_units table for ai tasking as attackers
function RotorOps.tallyZone(zone_name)  
  local new_units
  if RotorOps.defending then
    new_units = mist.getUnitsInZones(mist.makeUnitTable({'[red][vehicle]'}), {zone_name})
  else
    new_units = mist.getUnitsInZones(mist.makeUnitTable({'[blue][vehicle]'}), {zone_name})
  end
  
  if new_units and #new_units > 0 then
    
    for index, unit in pairs(new_units) do
      if not hasValue(RotorOps.staged_units, unit) then
	    if not isStaticUnit(unit) then
          env.info("RotorOps adding new units to staged_units: "..#new_units)
          table.insert(RotorOps.staged_units, unit)
          RotorOps.aiTask(unit:getGroup(),"move_to_active_zone", RotorOps.zones[RotorOps.active_zone_index].name)
		end
      else
        --env.info("unit already in table")
      end
    end
    
  end

end

--display a text message to all players with a radio sound effect
function RotorOps.radioText(message)
  RotorOps.gameMsg({message, 'radio_effect.ogg'})
end


---AI CORE BEHAVIOR--
--


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
 
  local ifFound = function(foundItem, val)  ---dcs world.searchObjects method
    local enemy_unit
    local path = {} 
    --trigger.action.outText("found item: "..foundItem:getTypeName(), 5)  
   -- if foundItem:hasAttribute("Infantry") == true and foundItem:getCoalition() == enemy_coal then
    if foundItem:getCoalition() == enemy_coal and foundItem:isActive() then
      enemy_unit = foundItem
      --debugMsg("found enemy! "..foundItem:getTypeName()) 
      
      path[1] = mist.ground.buildWP(start_point, '', 5) 
      path[2] = mist.ground.buildWP(enemy_unit:getPoint(), '', 5) 
      mist.goRoute(grp, path)
    else 
  
      --trigger.action.outText("object found is not enemy inf in "..search_radius, 5)  
    end
    
    return true
   end
 

 
   if vars.zone then     ---mist getUnitsInZones method
     local units_in_zone 
     if enemy_coal == 1 then
       units_in_zone = mist.getUnitsInZones(mist.makeUnitTable({'[red][vehicle]'}), {vars.zone}, "spherical")
     elseif enemy_coal == 2 then
       units_in_zone = mist.getUnitsInZones(mist.makeUnitTable({'[blue][vehicle]'}), {vars.zone}, "spherical")
     end
     local closest_dist = 10000
     local closest_unit
     for index, unit in pairs(units_in_zone) do
       if unit:getCoalition() == enemy_coal then
         local dist = mist.utils.get2DDist(start_point, unit:getPoint())
         if dist < closest_dist then
           closest_unit = unit
           closest_dist = dist
         end
       end
     end
     
     if closest_unit ~= nil then
       local path = {} 
       path[1] = mist.ground.buildWP(start_point, '', 5) 
       path[2] = mist.ground.buildWP(closest_unit:getPoint(), '', 5) 
       mist.goRoute(grp, path) 
     end
   
   else    ---dcs world.searchObjects method
     --debugMsg("CHARGE ENEMY in radius: "..search_radius)
     local volS = {
       id = world.VolumeType.SPHERE,
       params = {
         point = first_valid_unit:getPoint(), 
         radius = search_radius
       }
     }
     world.searchObjects(Object.Category.UNIT, volS, ifFound)
   end

end


--function RotorOps.chargeEnemy(vars)
-- --trigger.action.outText("charge enemies: "..mist.utils.tableShow(vars), 5) 
-- local grp = vars.grp
-- local search_radius = vars.radius or 5000
-- ----
-- local first_valid_unit = RotorOps.getValidUnitFromGroup(grp)
-- 
-- if first_valid_unit == nil then return end
-- local start_point = first_valid_unit:getPoint()
-- if not vars.spawn_point then vars.spawn_point = start_point end
--
-- local enemy_coal
-- if grp:getCoalition() == 1 then enemy_coal = 2 end
-- if grp:getCoalition() == 2 then enemy_coal = 1 end
-- 
-- local volS
--   if vars.zone then 
--     --debugMsg("CHARGE ENEMY at zone: "..vars.zone)
--     local sphere = trigger.misc.getZone(vars.zone)
--     volS = {
--       id = world.VolumeType.SPHERE,
--       params = {
--         point = sphere.point, 
--         radius = sphere.radius
--       }
--     }
--   else 
--       --debugMsg("CHARGE ENEMY in radius: "..search_radius)
--       volS = {
--       id = world.VolumeType.SPHERE,
--       params = {
--         point = first_valid_unit:getPoint(), 
--         radius = search_radius
--       }
--     }
--   end
-- 
-- 
-- local enemy_unit
-- local path = {} 
-- local ifFound = function(foundItem, val)
--  --trigger.action.outText("found item: "..foundItem:getTypeName(), 5)  
-- -- if foundItem:hasAttribute("Infantry") == true and foundItem:getCoalition() == enemy_coal then
--  if foundItem:getCoalition() == enemy_coal and foundItem:isActive() then
--    enemy_unit = foundItem
--    --debugMsg("found enemy! "..foundItem:getTypeName()) 
--    
--    path[1] = mist.ground.buildWP(start_point, '', 5) 
--    path[2] = mist.ground.buildWP(enemy_unit:getPoint(), '', 5) 
--    --path[3] = mist.ground.buildWP(vars.spawn_point, '', 5) 
--    mist.goRoute(grp, path)
--  else 
--
--    --trigger.action.outText("object found is not enemy inf in "..search_radius, 5)  
--  end
--  
-- return true
-- end
--
-- world.searchObjects(Object.Category.UNIT, volS, ifFound)
-- 
--
--end


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


function RotorOps.shiftPosition(vars)
 --debugMsg("patrol radius: "..mist.utils.tableShow(vars.grp))  
 local grp = vars.grp
 local search_radius = vars.radius or 100
 local inner_radius = 50 --minimum distance to move for randpointincircle
 local first_valid_unit
 if grp and grp:isExist() ~= true then return end
 local start_point = vars.point
 
 if not start_point then
     --env.info("RotorOps: No point provided, getting current position.")
	 for index, unit in pairs(grp:getUnits()) do
	   if unit:isExist() == true then
		 first_valid_unit = unit
		 break
	   else --trigger.action.outText("a unit no longer exists", 15) 
	   end 
	 end
	 if first_valid_unit == nil then return end
	 start_point = first_valid_unit:getPoint()
 end
	 
 
 local max_waypoints = 2
 
 local urban = RotorOps.pointIsUrban(start_point, 100)
 formation = 'Cone'
 if urban then
   formation = 'On Road'
 end

 local path = {} 
 path[1] = mist.ground.buildWP(start_point, '', 5) 

 for i = #path, max_waypoints, 1 do
   for i = 1, 4, 1 do
    local rand_point = mist.getRandPointInCircle(start_point, search_radius, inner_radius)
	
    if mist.isTerrainValid(rand_point, {'LAND', 'ROAD'}) == true then
        path[#path + 1] = mist.ground.buildWP(rand_point, formation, 5)
    	--env.info("point is valid, adding as waypoint with formation: " .. formation)
    	break
    end
	
   end
 end

 mist.goRoute(grp, path)                                                      
end


function RotorOps.guardPosition(vars)
 --debugMsg("patrol radius: "..mist.utils.tableShow(vars.grp))  
 local grp = vars.grp
 local search_radius = vars.radius or 100
 local first_valid_unit
 if not grp or grp:isExist() ~= true then return end
 local start_point = vars.point
 
 if not start_point then
     --env.info("RotorOps: No point provided, getting current position.")
	 for index, unit in pairs(grp:getUnits()) do
	   if unit:isExist() == true then
		 first_valid_unit = unit
		 break
	   else --trigger.action.outText("a unit no longer exists", 15) 
	   end 
	 end
	 if first_valid_unit == nil then return end
	 start_point = first_valid_unit:getPoint()
 end
 local object_vol_thresh = 0
 local foundUnits = {}

 local volS = {
   id = world.VolumeType.SPHERE,
   params = {
     point = start_point,
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
 if #foundUnits > 0 then
   local path = {} 
   --path[1] = mist.ground.buildWP(RotorOps.getValidUnitFromGroup(grp):getPoint(), '', 2) 
   path[1] = mist.ground.buildWP(RotorOps.getValidUnitFromGroup(grp):getPoint(), '', 2) 
   local rand_index = math.random(1,#foundUnits)
   path[#path + 1] = mist.ground.buildWP(foundUnits[rand_index]:getPoint(), '', 2) 
   mist.goRoute(grp, path)  
 end   
end

--helper function to try to determine a point is near many scenery objects
function RotorOps.pointIsUrban(_point, _radius)
   local volS = {
   id = world.VolumeType.SPHERE,
   params = {
     point = _point,  
     radius = _radius
   }
 }
 local foundUnits = {}
 local ifFound = function(foundItem, val)
      foundUnits[#foundUnits + 1] = foundItem
 end
 
 world.searchObjects(5, volS, ifFound)
 --env.info("Found scenery objects: " .. #foundUnits)
 if #foundUnits > 10 then
   return true
 end
   return false
end



function RotorOps.aiExecute(vars)
  local update_interval = 60
  local last_task = vars.last_task
  local last_zone = vars.last_zone
  local group_name = vars.group_name
  if not vars.group_name or not tableHasKey(RotorOps.ai_tasks, group_name) then
    return
  end  
  local task = RotorOps.ai_tasks[group_name].ai_task
  local zone = RotorOps.ai_tasks[group_name].zone
  local point = RotorOps.ai_tasks[group_name].point

--  if vars.zone then zone = vars.zone end

  
--error after Apache update  
--  if Group.isExist(Group.getByName(group_name)) ~= true or #Group.getByName(group_name):getUnits() < 1 then
--    debugMsg(group_name.." no longer exists")
--    RotorOps.ai_tasks[group_name] = nil
--    return
--  end  

  if Group.getByName(group_name) then
    if Group.isExist(Group.getByName(group_name)) ~= true or #Group.getByName(group_name):getUnits() < 1 then
      debugMsg(group_name.." no longer exists")
      RotorOps.ai_tasks[group_name] = nil
      return
    end
  else
    debugMsg(group_name.." no longer exists")
    RotorOps.ai_tasks[group_name] = nil
  end


  
  local same_zone = false
  if zone ~= nil then
    if zone ~= last_zone then
      same_zone = true
    end
  end
  
  local should_update = true
  
  if RotorOps.persistent_tasking and task == last_task then
   if task == "move_to_active_zone" or task == "move_to_zone" then
     if same_zone then
	   should_update = false
	 end
   end
  end
    
  
 if should_update then  --check to make sure we don't have the same task
   
  debugMsg("tasking: "..group_name.." : "..task) 
 
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
  elseif task == "shift" then
    local vars = {}
    vars.grp = Group.getByName(group_name)
    vars.radius = 250
	vars.point = point
    RotorOps.shiftPosition(vars) --takes a group object, not name
    update_interval = math.random(60,360)
  elseif task == "guard" then
    local vars = {}
    vars.grp = Group.getByName(group_name)
    vars.radius = 100
	vars.point = point
    RotorOps.guardPosition(vars) --takes a group object, not name
    update_interval = math.random(60,120)

  end  
 
 end
  
  vars.last_task = task
  vars.last_zone = zone
   
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
    if group and not isStaticGroup(group) then
      RotorOps.aiTask(group, "patrol")
    end
  end
  
  for index, group in pairs(RotorOps.ai_attacking_infantry_groups) do 
    if group and not isStaticGroup(group) then
      RotorOps.aiTask(group, "clear_zone", RotorOps.active_zone)
    end
  end
  
  for index, group in pairs(RotorOps.ai_attacking_vehicle_groups) do 
    if group and not isStaticGroup(group) then
      RotorOps.aiTask(group, "clear_zone", RotorOps.active_zone)  
    end
  end
  
  for index, group in pairs(RotorOps.ai_defending_vehicle_groups) do 
    if group and not isStaticGroup(group) then
      Group.getByName(group):getController():setOption(AI.Option.Ground.id.DISPERSE_ON_ATTACK , RotorOps.defending_vehicles_disperse)
	  if RotorOps.defending_vehicles_behavior == "patrol" then
	    RotorOps.aiTask(group, "patrol")
	  elseif RotorOps.defending_vehicles_behavior == "shift" then
	    local unit = RotorOps.getValidUnitFromGroup(group)
		if unit then
	      RotorOps.aiTask(group, "shift", nil, unit:getPoint())
		end
	  end
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
	 local total_spawn_zones = 0
     for zone, zoneobj in pairs(mist.DBs.zonesByName) do 
       if string.find(zone, RotorOps.active_zone) and string.find(zone:lower(), "spawn") then --if we find a zone that has the active zone name and the word spawn
         inf_spawn_zones[#inf_spawn_zones + 1] = zone 
         env.info("ROTOR OPS: spawn zone found:"..zone)
       end
	   if string.find(zone:lower(), "spawn") then
	     total_spawn_zones = total_spawn_zones + 1
	   end
     end
     --RotorOps.inf_spawns_avail = RotorOps.inf_spawns_per_zone * RotorOps.inf_spawn_multiplier[RotorOps.active_zone_index]
	 if total_spawn_zones > 0 then
	   RotorOps.inf_spawns_avail = (RotorOps.inf_spawns_total / total_spawn_zones) * #inf_spawn_zones
	 end

     env.info("ROTOR OPS: zone activated: "..RotorOps.active_zone..", inf spawns avail:"..RotorOps.inf_spawns_avail..", spawn zones:"..#inf_spawn_zones)
   end
   
   
   local defenders_status_flag = RotorOps.zones[RotorOps.active_zone_index].defenders_status_flag
   --if #active_zone_initial_defenders == 0 then active_zone_initial_defenders = 1 end --prevent divide by zero
   local defenders_remaining_percent = math.floor((#defending_ground_units / #active_zone_initial_defenders) * 100) 
     
   if #defending_ground_units <= RotorOps.max_units_left then  --if we should declare the zone cleared
     active_zone_initial_defenders = nil
     defenders_remaining_percent = 0
     trigger.action.setUserFlag(defenders_status_flag, 0)  --set the zone's flag to cleared
	 trigger.action.setUserFlag(zone_defenders_flags[RotorOps.active_zone_index], 0)  --set the zone's flag to cleared
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
	 trigger.action.setUserFlag(zone_defenders_flags[RotorOps.active_zone_index], defenders_remaining_percent)
   end
     
   --are all zones clear?
   local all_zones_clear = true
   for key, value in pairs(RotorOps.zones) do 
      local defenders_remaining = trigger.misc.getUserFlag(RotorOps.zones[key].defenders_status_flag)
      if defenders_remaining ~= 0 then
        all_zones_clear = false
      end
   end
   
   --update staged units remaining flag
   local staged_units_remaining = {}
   for index, unit in pairs(RotorOps.staged_units) do 
     if unit:isExist() and unit:getLife() > 0 then
       staged_units_remaining[#staged_units_remaining + 1] = unit
     end
   end
   local percent_staged_remain = 0
   percent_staged_remain = math.floor((#staged_units_remaining / #RotorOps.staged_units) * 100) 
   trigger.action.setUserFlag(RotorOps.staged_units_flag, percent_staged_remain)
   trigger.action.setUserFlag('ROPS_ATTACKERS', percent_staged_remain)
   
   
   --is the game finished?
   if all_zones_clear then
    if RotorOps.defending == true then 
      RotorOps.game_state = RotorOps.game_states.lost
      trigger.action.setUserFlag(RotorOps.game_state_flag, RotorOps.game_states.lost)
	  trigger.action.setUserFlag('ROPS_GAMESTATE', RotorOps.game_states.lost)
    else
      RotorOps.game_state = RotorOps.game_states.won
      trigger.action.setUserFlag(RotorOps.game_state_flag, RotorOps.game_states.won)
	  trigger.action.setUserFlag('ROPS_GAMESTATE', RotorOps.game_states.won)
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
	 trigger.action.setUserFlag('ROPS_GAMESTATE', RotorOps.game_states.won)
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
           env.info(vehicle:getName().." is deploying troops.")
           RotorOps.deployTroops(RotorOps.inf_apc_group, vehicle:getGroup(), false)
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
        ctld.spawnGroupAtTrigger("blue", RotorOps.inf_spawn_blue, zone, 1000)
      else
        ctld.spawnGroupAtTrigger("red", RotorOps.inf_spawn_red, zone, 1000)
        RotorOps.gameMsg(RotorOps.gameMsgs.infantry_spawned, math.random(1, #RotorOps.gameMsgs.infantry_spawned))
      end
      
      RotorOps.inf_spawns_avail = RotorOps.inf_spawns_avail - 1
      env.info("ROTOR OPS: Attempting to spawn infantry. "..RotorOps.inf_spawns_avail.." spawns remaining in "..zone)
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
   -- if RotorOps.defending == true then
     -- header = "[DEFEND "..RotorOps.active_zone .. "]   " 
     -- body = "RED: " ..#attacking_infantry.. " infantry, " .. #attacking_vehicles .. " vehicles.  BLUE: "..#defending_infantry.. " infantry, " .. #defending_vehicles.." vehicles. ["..defenders_remaining_percent.."%]"
   -- else 
     -- header = "[ATTACK "..RotorOps.active_zone .. "]   " 
     -- body = "RED: " ..#defending_infantry.. " infantry, " .. #defending_vehicles .. " vehicles.  BLUE: "..#attacking_infantry.. " infantry, " .. #attacking_vehicles.." vehicles. ["..defenders_remaining_percent.."%]"   
   -- end
   if RotorOps.defending == true then
     header = "[DEFEND "..RotorOps.active_zone .. "]   " 
     body = "BLUE: "..#defending_infantry.. " infantry, " .. #defending_vehicles.." vehicles.  RED CONVOY: " .. #staged_units_remaining .." vehicles. ["..percent_staged_remain.."%]"
   else 
     header = "[ATTACK "..RotorOps.active_zone .. "]   " 
     body = "RED: " ..#defending_infantry.. " infantry, " .. #defending_vehicles .. " vehicles.  BLUE CONVOY: " .. #staged_units_remaining .." vehicles. ["..percent_staged_remain.."%]"   
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
    local coal = -1
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
      --trigger.action.lineToAll(coal, id + 200, point, previous_point, color, line_type)
    end
    previous_point = point
    if RotorOps.draw_conflict_zones == true then
      trigger.action.circleToAll(coal, id, point, radius, color, fill_color, line_type)
      trigger.action.textToAll(coal, id + 100, point, color, text_fill_color, font_size, read_only, text)
    end
  end
  
  for index, cpz in pairs(ctld.pickupZones) do
    env.info("CTLD pickzone name: " .. cpz[1])
    pickup_zone = trigger.misc.getZone(cpz[1])
    if pickup_zone then
     env.info("found a ctld pickup zone")
     local ctld_zone_status = cpz[4]
     local point = pickup_zone.point
     local radius = pickup_zone.radius
     local coal = -1
     local id = index + 150  --this must be UNIQUE!
     local color = {1, 1, 1, 0.5}
     local fill_color = {0, 0.8, 0, 0.1}
     local line_type = 5 --1 Solid  2 Dashed  3 Dotted  4 Dot Dash  5 Long Dash  6 Two Dash
     if ctld_zone_status == 'yes' or ctld_zone_status == 1 then
	  env.info("pickup zone is active, drawing it to the map")
	  trigger.action.circleToAll(coal, id, point, radius, color, fill_color, line_type)
     end
    end  
  end


  -- for index, pickup_zone in pairs(RotorOps.ctld_pickup_zones)
  -- do
    -- for c_index, c_zone in pairs(ctld.pickupZones)
    -- do
      -- if pickup_zone == c_zone[1] then
       -- --debugMsg("found our zone in ctld zones, status: "..c_zone[4])
       -- local ctld_zone_status = c_zone[4]
       -- local point = trigger.misc.getZone(pickup_zone).point
       -- local radius = trigger.misc.getZone(pickup_zone).radius
       -- local coal = -1
       -- local id = index + 150  --this must be UNIQUE!
       -- local color = {1, 1, 1, 0.5}
       -- local fill_color = {0, 0.8, 0, 0.1}
       -- local line_type = 5 --1 Solid  2 Dashed  3 Dotted  4 Dot Dash  5 Long Dash  6 Two Dash
       -- if ctld_zone_status == 'yes' or ctld_zone_status == 1 then
        -- --debugMsg("draw the pickup zone")
        -- trigger.action.circleToAll(coal, id, point, radius, color, fill_color, line_type)
       -- end
      -- end  
    -- end
  -- end

  
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
    
    -- if not RotorOps.defending then
    
      -- if old_index > 0 and RotorOps.apcs_spawn_infantry == false then 
        -- ctld.activatePickupZone(RotorOps.farp_names[old_index])  --make the captured zone a pickup zone
      -- end
      -- ctld.deactivatePickupZone(RotorOps.farp_names[new_index])
    -- end

    RotorOps.game_state = new_index
    trigger.action.setUserFlag(RotorOps.game_state_flag, new_index)
	trigger.action.setUserFlag('ROPS_GAMESTATE', new_index)
    if new_index > old_index then 
      if RotorOps.defending == true then
        RotorOps.gameMsg(RotorOps.gameMsgs.enemy_pushing, new_index)
      else
        RotorOps.gameMsg(RotorOps.gameMsgs.push, new_index)
      end
    end 
    
    local staged_groups = RotorOps.groupsFromUnits(RotorOps.staged_units)
    for index, group in pairs(staged_groups) do
      timer.scheduleFunction(function()RotorOps.aiTask(group,"move_to_active_zone", RotorOps.zones[RotorOps.active_zone_index].name) end, {}, timer.getTime() + index) --add a second between calling aitask
      --RotorOps.aiTask(group,"move_to_active_zone", RotorOps.zones[RotorOps.active_zone_index].name) --send vehicles to next zone; use move_to_active_zone so units don't get stuck if the active zone moves before they arrive
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
  
  --ctld.Debug = false
  ctld.enableCrates = RotorOps.CTLD_crates
  ctld.enabledFOBBuilding = false
  ctld.JTAC_lock = "vehicle"
  ctld.location_DMS = true
  ctld.numberOfTroops = 24 --max loading size
  ctld.maximumSearchDistance = 4000 -- max distance for troops to search for enemy
  ctld.maximumMoveDistance = 0 -- max distance for troops to move from drop point if no enemy is nearby
  ctld.maximumDistanceLogistic = 300
  ctld.minimumHoverHeight = 5.0 -- Lowest allowable height for crate hover
  ctld.maximumHoverHeight = 15.0 -- Highest allowable height for crate hover
  ctld.maxDistanceFromCrate = 7 -- Maximum distance from from crate for hover
  ctld.hoverTime = 5 -- Time to hold hover above a crate for loading in seconds
  
  ctld.unitLoadLimits = {
    -- Remove the -- below to turn on options
     ["SA342Mistral"] = 4,
     ["SA342L"] = 4,
     ["SA342M"] = 4,
     ["UH-1H"] = 10,
     ["Mi-8MT"] = 24,
     ["Mi-24P"] = 8,
     ["UH-60L"] = 11,
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
   
   
   --add to CTLD default pickzone names.  This could be done in a loop but this should be more readable
   --pickupZones = { "Zone name or Ship Unit Name", "smoke color", "limit (-1 unlimited)", "ACTIVE (yes/no)", "side (0 = Both sides / 1 = Red / 2 = Blue )", flag number (optional) }
   ctld.pickupZones[#ctld.pickupZones + 1] = { "STAGING", RotorOps.pickup_zone_smoke, -1, "no", 0 }
   ctld.pickupZones[#ctld.pickupZones + 1] = { "STAGING_BASE", RotorOps.pickup_zone_smoke, -1, "no", 0 }
   ctld.pickupZones[#ctld.pickupZones + 1] = { "ALPHA_FARP", RotorOps.pickup_zone_smoke, -1, "no", 0 }
   ctld.pickupZones[#ctld.pickupZones + 1] = { "BRAVO_FARP", RotorOps.pickup_zone_smoke, -1, "no", 0 }
   ctld.pickupZones[#ctld.pickupZones + 1] = { "CHARLIE_FARP", RotorOps.pickup_zone_smoke, -1, "no", 0 }
   ctld.pickupZones[#ctld.pickupZones + 1] = { "DELTA_FARP", RotorOps.pickup_zone_smoke, -1, "no", 0 }
   ctld.pickupZones[#ctld.pickupZones + 1] = { "HELO_CARRIER", "none", -1, "yes", 0 }
   ctld.pickupZones[#ctld.pickupZones + 1] = { "HELO_CARRIER_1", "none", -1, "yes", 0 }
   ctld.pickupZones[#ctld.pickupZones + 1] = { "troops1", RotorOps.pickup_zone_smoke, -1, "yes", 0 }
   ctld.pickupZones[#ctld.pickupZones + 1] = { "troops2", RotorOps.pickup_zone_smoke, -1, "yes", 0 }
   ctld.pickupZones[#ctld.pickupZones + 1] = { "troops3", RotorOps.pickup_zone_smoke, -1, "yes", 0 }
   ctld.pickupZones[#ctld.pickupZones + 1] = { "troops4", RotorOps.pickup_zone_smoke, -1, "yes", 0 }
   ctld.pickupZones[#ctld.pickupZones + 1] = { "troops5", RotorOps.pickup_zone_smoke, -1, "yes", 0 }
   ctld.pickupZones[#ctld.pickupZones + 1] = { "troops6", RotorOps.pickup_zone_smoke, -1, "yes", 0 }
   ctld.pickupZones[#ctld.pickupZones + 1] = { "troops7", RotorOps.pickup_zone_smoke, -1, "yes", 0 }
   ctld.pickupZones[#ctld.pickupZones + 1] = { "troops8", RotorOps.pickup_zone_smoke, -1, "yes", 0 }
   ctld.pickupZones[#ctld.pickupZones + 1] = { "troops9", RotorOps.pickup_zone_smoke, -1, "yes", 0 }
   ctld.pickupZones[#ctld.pickupZones + 1] = { "troops10", RotorOps.pickup_zone_smoke, -1, "yes", 0 }
    

    
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
  trigger.action.setUserFlag(zone_defenders_flags[1], 101)
  trigger.action.setUserFlag(zone_defenders_flags[2], 101)
  trigger.action.setUserFlag(zone_defenders_flags[3], 101)
  trigger.action.setUserFlag(zone_defenders_flags[4], 101)
  RotorOps.drawZones()
  local farp_name = _name .. "_FARP"
  RotorOps.farp_names[#RotorOps.farp_names + 1] = farp_name
end


function RotorOps.addStagingZone(_name) 
  if trigger.misc.getZone(_name) == nil then
    trigger.action.outText(_name.." trigger zone missing!  Check RotorOps setup!", 60)
    env.warning(_name.." trigger zone missing!  Check RotorOps setup!")
  end
   
  RotorOps.staging_zones[#RotorOps.staging_zones + 1] = _name
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
  trigger.action.setUserFlag('ROPS_GAMESTATE', RotorOps.game_states.not_started)
  trigger.action.outText("ALL TROOPS GET TO TRANSPORT AND PREPARE FOR DEPLOYMENT!" , 10, false)
  if RotorOps.CTLD_sound_effects == true then
    local timer_id = timer.scheduleFunction(RotorOps.registerCtldCallbacks, 1, timer.getTime() + 5) 
  end
end


function RotorOps.addPickupZone(zone_name, smoke, limit, active, side)  --depreciated, don't use
  ctld.pickupZones[#ctld.pickupZones + 1] = {zone_name, smoke, limit, active, side}
end

 

function RotorOps.startConflict()
  --if RotorOps.game_state ~= RotorOps.game_states.not_started then return end 

  --make some changes to the radio menu
  --local conflict_zones_menu = commandDB['conflict_zones_menu']
  --missionCommands.removeItem(commandDB['start_conflict']) 
  --commandDB['clear_zone'] = missionCommands.addCommand( "[CHEAT] Force Clear Zone"  , conflict_zones_menu , RotorOps.clearActiveZone)
  
  local units_found = mist.getUnitsInZones(mist.makeUnitTable({'[all][vehicle]'}), RotorOps.staging_zones)
  
  --filter out 'static' units
  for index, unit in pairs(units_found) do
    if not isStaticUnit(unit) then
      RotorOps.staged_units[#RotorOps.staged_units + 1] = unit
    end
  end
  
  
  if RotorOps.staged_units[1] == nil then
    trigger.action.outText("RotorOps failed: You must place ground units in the staging and conflict zones!" , 60, false)
    env.warning("No units in staging zone!  Check RotorOps setup!")
    return
  end
  
  if RotorOps.staged_units[1]:getCoalition() == 1 then  --check the coalition in the staging zone to see if we're defending
    --DEFENSE
    trigger.action.setUserFlag('ROPS_DEFENDING', 1)
    RotorOps.defending = true
    RotorOps.gameMsg(RotorOps.gameMsgs.start_defense)
	ctld.activatePickupZone(RotorOps.farp_names[#RotorOps.farp_names])  --make the last zone a pickup zone for defenders
    
  else
    --OFFENSE
    RotorOps.gameMsg(RotorOps.gameMsgs.start)
	if RotorOps.enable_staging_pickzones then
    if trigger.misc.getZone("STAGING_BASE") then 
	  ctld.activatePickupZone("STAGING_BASE")
    else
	  ctld.activatePickupZone("STAGING")
	end
  end
	
  end
  

  

  
  RotorOps.setActiveZone(1)
  
  if RotorOps.ai_task_by_name then
	RotorOps.taskByName()
  end
  
  local id = timer.scheduleFunction(RotorOps.assessUnitsInZone, 1, timer.getTime() + 5)
  world.addEventHandler(RotorOps.eventHandler)
end


function RotorOps.triggerSpawn(groupName, msg, resume_task)
  local group = Group.getByName(groupName)
  if not group then
    env.warning("RotorOps tried to spawn "..groupName.." but it doesn't exist.")
    return nil
  end
  if group and group:isExist() == true and #group:getUnits() > 0 and group:getUnits()[1]:getLife() > 1 and group:getUnits()[1]:isActive() then
    env.info("RotorOps tried to respawn "..groupName.." but it's already active.")
    return nil
  else
    local new_group = mist.respawnGroup(groupName, resume_task)
    if new_group then
      if msg ~= nil then
        RotorOps.gameMsg(msg)
      end
      env.info("RotorOps spawned "..groupName)
      return new_group
    end
  end

end

---Search for group names containing key strings to assign AI tasks
function RotorOps.taskByName()
  env.info("RotorOps searching for groups to taskByName")
  for group_name, data in pairs(mist.DBs.groupsByName) do
	if string.find(group_name:lower(), RotorOps.patrol_task_string:lower()) then
	  RotorOps.aiTask(group_name, "patrol")
	  env.info("Tasking " .. group_name .. " as patrol.")
	elseif string.find(group_name:lower(), RotorOps.aggressive_task_string:lower()) then
	  RotorOps.aiTask(group_name, "aggressive")
	  env.info("Tasking " .. group_name .. " as aggressive.")
	elseif string.find(group_name:lower(), RotorOps.move_to_active_task_string:lower()) then
	  RotorOps.aiTask(group_name, "move_to_active_zone")
	  env.info("Tasking " .. group_name .. " to move to active zone.")
	elseif string.find(group_name:lower(), RotorOps.shift_task_string:lower()) then
	  RotorOps.aiTask(group_name, "shift")
	  env.info("Tasking " .. group_name .. " to shift positions.")
	elseif string.find(group_name:lower(), RotorOps.guard_task_string:lower()) then
	  RotorOps.aiTask(group_name, "guard")
	  env.info("Tasking " .. group_name .. " to guard positions.")
	end
  end
  if RotorOps.ai_task_by_name_scheduler then
    local timer_id = timer.scheduleFunction(RotorOps.taskByName, nil, timer.getTime() + 500)
  end
end


function RotorOps.spawnAttackHelos()
  RotorOps.triggerSpawn("Enemy Attack Helicopters", RotorOps.gameMsgs.attack_helos_prep, true)
end


function RotorOps.spawnAttackPlanes()
  RotorOps.triggerSpawn("Enemy Attack Planes", RotorOps.gameMsgs.attack_planes_prep, true)
end



function RotorOps.farpEstablished(index, trigger_zone)
  env.info("RotorOps FARP established at "..RotorOps.zones[index].name)
  if trigger_zone then
	if RotorOps.farp_pickups then
      ctld.activatePickupZone(trigger_zone)
	end
    if RotorOps.farp_smoke_color >= 0 and RotorOps.pickup_zone_smoke == 'none' then
	  trigger.action.smoke(trigger.misc.getZone(trigger_zone).point , RotorOps.farp_smoke_color)
	end
  end
  timer.scheduleFunction(function()RotorOps.gameMsg(RotorOps.gameMsgs.farp_established, index) end, {}, timer.getTime() + 15)
end


function RotorOps.getEnemyZones()
  local enemy_zones = {}
  
  if RotorOps.defending then
  
    for index, zone in pairs(RotorOps.zones) do
      if index <= RotorOps.active_zone_index then
        enemy_zones[#enemy_zones + 1] = zone.name
      end
    end
    
  else --not defending
  
    for index, zone in pairs(RotorOps.zones) do
      if index >= RotorOps.active_zone_index then
        enemy_zones[#enemy_zones + 1] = zone.name
      end
    end
  
  end 
  debugMsg("Got enemy zones:")
  debugTable(enemy_zones)
  return enemy_zones 
end


function RotorOps.spawnTranspHelos(troops, max_drops)
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
  
  local dropTroops = {
    id = 'WrappedAction',
    params = {
      action = {
        id = 'Script',
        params = {
          command = 'RotorOps.deployTroops('..troops..', ...)',  

        },
      },
    },
  }
  
  local group = Group.getByName("Enemy Transport Helicopters")
  local initial_point = group:getUnits()[1]:getPoint()
  local gp = mist.getGroupData("Enemy Transport Helicopters")
  --debugTable(gp)
  
  local drop_zones = RotorOps.getEnemyZones()
  if RotorOps.defending then
    drop_zones = {RotorOps.active_zone}
  end
  gp.route = {points = {}}
  gp.route.points[1] = mist.heli.buildWP(initial_point, initial, 'flyover', 0, 0, 'agl')
  gp.route.points[2] = mist.heli.buildWP(initial_point, initial, 'flyover', 100, 100, 'agl')
  gp.route.points[2].task = setOptions
   
  
  local failsafe = 100
  local drop_qty = 0
  while drop_qty < max_drops do
  
    for i = 1, 10 do  --pick some random points to evaluate
      local zone_name = drop_zones[math.random(#drop_zones)]
      local zone_point = trigger.misc.getZone(zone_name).point
      local drop_point = mist.getRandomPointInZone(zone_name, 300)     
       
      if mist.isTerrainValid(drop_point, {'LAND', 'ROAD'}) == true then  --if the point looks like a good drop point
        gp.route.points[#gp.route.points + 1] = mist.heli.buildWP(zone_point, 'flyover', 100, 400, 'agl') 
        gp.route.points[#gp.route.points + 1] = mist.heli.buildWP(zone_point, 'flyover', 20, 200, 'agl') 
        gp.route.points[#gp.route.points + 1] = mist.heli.buildWP(drop_point, 'turning point', 10, 70, 'agl') 
        gp.route.points[#gp.route.points].task = dropTroops  
        drop_qty = drop_qty + 1    
        break
      end
      
    end
    
    failsafe = failsafe - 1
    if failsafe < 1 then 
      env.error("ROTOROPS: FINDING DROP POINTS TOOK TOO LONG")
      break
    end

  end
  gp.route.points[#gp.route.points + 1] = mist.heli.buildWP(initial_point, 'flyover', 100, 400, 'agl') 
  gp.clone = true
  local new_group_data = mist.dynAdd(gp) --returns a mist group data table
  --debugTable(new_group_data)
--  local new_group = Group.getByName(new_group_data.groupName)
--  local grp_controller = new_group:getController() --controller for aircraft can be group or unit level
--  grp_controller:setOption(AI.Option.Air.id.REACTION_ON_THREAT , AI.Option.Air.val.REACTION_ON_THREAT.EVADE_FIRE) 
--  grp_controller:setOption(AI.Option.Air.id.FLARE_USING , AI.Option.Air.val.FLARE_USING.WHEN_FLYING_NEAR_ENEMIES) 
  
  env.info("ROTOROPS: TRANSPORT HELICOPTER DEPARTING WITH "..drop_qty.." PLANNED TROOP DROPS.")
  
  
end

function RotorOps.spawnCapToZone(_target_zone, _spawn_zone, coal)
  local target_zone = _target_zone
  if not target_zone then
    target_zone = RotorOps.getEnemyZones()[math.random(1, #RotorOps.getEnemyZones())]
  end
  local zone_point = trigger.misc.getZone(target_zone).point
  RotorOps.spawnCap(zone_point, _spawn_zone, coal)
end

RotorOps.fighter_red_source_string = "RED CAP"
RotorOps.fighter_blue_source_string = "BLUE CAP"
RotorOps.fighter_engagement_dist = 20

function RotorOps.spawnCap(destination_point, _spawn_zone, coal)
  local red_zone_string = "RED_CAP_SPAWN"
  local blue_zone_string = "BLUE_CAP_SPAWN"
  
  local coal_zone_string = nil
  if not coal or coal == 0 then
    return
  end
  if coal == 1 then 
    coal_zone_string = red_zone_string
	source_group_string = RotorOps.fighter_red_source_string
  end
  if coal == 2 then 
    coal_zone_string = blue_zone_string
	source_group_string = RotorOps.fighter_blue_source_string
  end
  
  local spawn_zone = _spawn_zone
  if not _spawn_zone then
	  local spawn_zones = {}
	  for zone, zoneobj in pairs(mist.DBs.zonesByName) do 
		if string.find(zone, coal_zone_string) then
		  spawn_zones[#spawn_zones + 1] = zone
		  --env.info("found cap spawn zone: " .. zone)
		end
	  end
	  if #spawn_zones < 1 then 
	    return 
	  end
	  spawn_zone = spawn_zones[math.random(1, #spawn_zones)]
  end
  
  local spawn_point = mist.getRandomPointInZone(spawn_zone)
  
  
  local altitude = math.random(2000,6000)
  local speed = 300
  
  
  --pick a template group at random for the source
  fighter_groups = {} --stores group names of template groups
  for uName, uData in pairs(mist.DBs.groupsByName) do
    if string.find(uName, source_group_string) then
	  fighter_groups[#fighter_groups + 1] = uName
	end
  end
  
  if #fighter_groups < 1 then 
	return 
  end
  
  fighter_group_name = fighter_groups[math.random(1, #fighter_groups)]
  local group = Group.getByName(fighter_group_name)
  
  if not group then
    return
  end

  local gp = mist.getGroupData(fighter_group_name)
  --debugTable(gp)
  
  gp.units[1].alt = altitude
  gp.units[1].speed = speed
  gp.units[1].x = spawn_point.x
  gp.units[1].y = spawn_point.y
  gp.units[1].heading = mist.utils.getHeadingPoints(spawn_point, destination_point)
  

  
  local engage = {
      id = 'EngageTargets',
      params = {
        maxDist = RotorOps.fighter_engagement_dist,
        maxDistEnabled = true,
        targetTypes = { [1] = "Air" },
      }
    }
  
  local orbit = { 
	  id = 'Orbit', 
	  params = { 
		pattern = 'Race-Track',
	  } 
  }
  
  
  gp.route = {points = {}}
  -- gp.route[1] = mist.fixedWing.buildWP(random_airbase:getPoint())
  -- gp.route[1].type = "TakeOffParking"
  -- gp.route[1].action = "From Parking Area"
  -- gp.route[1].airdromeId = airbase_id
  
  gp.route.points[1] = mist.fixedWing.buildWP(spawn_point, 'turning point', speed, altitude, 'baro')
 
  gp.route.points[1].task = {}
  gp.route.points[1].task.id = 'ComboTask'
  gp.route.points[1].task.params = {}
  gp.route.points[1].task.params.tasks = {}
  gp.route.points[1].task.params.tasks[1] = {number = 1, id = 'ControlledTask', enabled = true, params = {task = engage}}
  gp.route.points[1].task.params.tasks[2] = {number = 2, id = 'ControlledTask', enabled = true, params = {task = orbit}}
  
  gp.route.points[2] = mist.fixedWing.buildWP(destination_point, 'turning point', speed, altitude, 'baro')
  
  gp.clone = true
  local new_group_data = mist.dynAdd(gp) --returns a mist group data table
  --debugTable(new_group_data)
  local new_group = Group.getByName(new_group_data.name)
  if new_group then 
    env.info("RotorOps spawned CAP: "..new_group_data.name)
  else
    env.error("RotorOps tried to spawn CAP but something went wrong.")
	return
  end
  
  local grp_controller = new_group:getController() --controller for aircraft can be group or unit level
  grp_controller:setOption(AI.Option.Air.id.REACTION_ON_THREAT , AI.Option.Air.val.REACTION_ON_THREAT.EVADE_FIRE) 
  grp_controller:setOption(AI.Option.Air.id.FLARE_USING , AI.Option.Air.val.FLARE_USING.WHEN_FLYING_NEAR_ENEMIES) 
  grp_controller:setOption(AI.Option.Air.id.ROE , AI.Option.Air.val.ROE.OPEN_FIRE_WEAPON_FREE)
  grp_controller:setOption(AI.Option.Air.id.RADAR_USING, AI.Option.Air.val.RADAR_USING.FOR_SEARCH_IF_REQUIRED)
  
  return new_group_data.name
  
end



function RotorOps.deployFighters()
  local function spawn(dest_point, target_unit, coal)
    fighter = RotorOps.spawnCap(dest_point, nil, coal)
	
	if fighter and #fighters_by_detected_unitname < RotorOps.fighter_max_active then
	  _spawn_time = RotorOps.getTime()
	  fighters_by_detected_unitname[target_unit] = {
	    name = fighter, 
		spawn_time = _spawn_time,
		rtb_time = math.random(_spawn_time + (15 * 60), _spawn_time + (25 * 60)),
		respawn_time = math.random(_spawn_time + (5 * 60), _spawn_time + (15 * 60)),
	  }
	  if ((RotorOps.getTime() - cooldown["e_fighters_inbound_msg"]) > 90) then
	    RotorOps.gameMsg(RotorOps.gameMsgs.enemy_fighters_inbound)
		cooldown["e_fighters_inbound_msg"] = RotorOps.getTime()
	  end
	  --debugTable(fighters_by_detected_unitname)
	  env.info(target_unit .. " was detected and we spawned a new fighter group: " .. fighter)
	end
  end
  
  local function rtb(group_name)
    
    local grp = Group.getByName(group_name)
	if grp then
	  local coal_airbases = coalition.getAirbases(grp:getCoalition())
	  --debugTable(coal_airbases)
	  random_airbase = coal_airbases[math.random(1, #coal_airbases)]
	  
	  local airbase_pos = mist.utils.makeVec2(random_airbase:getPoint())
      local airbase_id = random_airbase:getID()
      local rtb = {
        id = 'Mission',
        params = {
          route = {
            points = {
              [1] = {
                alt = 2000,
                alt_type = "RADIO",
                speed = 300,
                x = airbase_pos.x,
                y = airbase_pos.y,
                aerodromeId = airbase_id,
                type = "Land",
                action = "Landing",
              }
            }
          }
        }
      }
	  
	  grp:getController():setTask(rtb)
	  env.info(group_name .. " is RTB to ".. random_airbase:getName())
	end
  end
  
  
  --fighter respawning and rtb
  for target_name, fighter_group_data in pairs(fighters_by_detected_unitname) do
	local group = Group.getByName(fighter_group_data.name)
	if group then --if group alive
	  if fighter_group_data.rtb_time < RotorOps.getTime() then
	    env.info(fighter_group_data.name .. " is RTB. Removing from table.")
		rtb(fighter_group_data.name)
		fighters_by_detected_unitname[target_name] = nil
	  end
	else --if group dead
	  if fighter_group_data.respawn_time < RotorOps.getTime() then
	    env.info(fighter_group_data.name .. " has hit respawn_time limit. Removing from table to allow another group to spawn.")
	    fighters_by_detected_unitname[target_name] = nil
	  end
	end
  end
  

  
  
  for uName, uData in pairs(mist.DBs.unitsByName) do
    local str_index = string.find(uName, RotorOps.fighter_radar_unit_string)
    if str_index then
	  --trigger.action.outText("Found radar unit: " .. uData.unitName, 2)
      local radar_unit = Unit.getByName(uData.unitName)
	  local max_distance = RotorOps.fighter_max_detection_dist
	  local dist_str = string.sub(uName, str_index + #RotorOps.fighter_radar_unit_string + 1)
	  if #dist_str > 3 then
	    --env.info("RotorOps: Radar unit name has the max detection distance property:".. dist_str)
		local dist = tonumber(dist_str)
		if dist and dist > 0 then
		  max_distance = dist
		end
	  end
	  
	  if radar_unit and radar_unit:getLife() > 0 then
	    --trigger.action.outText(uData.unitName .. " is searching for targets. life=" .. radar_unit:getLife(), 2)
	    
		raw_detected_units = radar_unit:getController():getDetectedTargets(Controller.Detection.RADAR)
		if raw_detected_units then
			for i, target in pairs(raw_detected_units) do
			  --debugTable(target)
			  if target.object then
				  local detected_unitname = target.object:getName()
				  local target_pos = target.object:getPosition().p
				  local target_distance = mist.utils.get2DDist(radar_unit:getPosition().p, target_pos)
				  local terrain_height = land.getHeight({x = target_pos.x, y = target_pos.z})
				  local target_agl = target_pos.y - terrain_height
				  
				  env.info(uData.unitName .. "detected " .. detected_unitname .. " at " .. target_distance .. " agl:" .. target_agl)
				  
				  if target_distance <= max_distance and target_agl >= RotorOps.fighter_min_detection_alt then
					env.info('RotorOps: ' .. uData.unitName .. " has detected "..detected_unitname .. "at agl=" .. target_agl .. " distance=" .. target_distance)
					
					if tableHasKey(fighters_by_detected_unitname, detected_unitname) then
					  --trigger.action.outText(detected_unitname .. " already in table with " .. fighters_by_detected_unitname[detected_unitname], 2)

					else
					  spawn(target_pos, detected_unitname, radar_unit:getCoalition())
					end
					
				  end
			  end --end if target.object
			end --end of raw_detected targets loop
		end
	  
	  end --end of radar_unit
	end 
  end --end of all units by name loop		  
		
end

--- USEFUL PUBLIC 'LUA PREDICATE' FUNCTIONS FOR MISSION EDITOR TRIGGERS (don't forget that DCS lua predicate functions should 'return' these function calls)

--determine if any human players are above a defined ceiling above ground level. If 'above' parameter is false, function will return true if no players above ceiling
function RotorOps.predPlayerMaxAGL(max_agl, above) 
  local players_above_ceiling = 0
  
  for uName, uData in pairs(mist.DBs.humansByName) do
    local player_unit = Unit.getByName(uData.unitName)
    if player_unit then
      local player_pos = player_unit:getPosition().p
      local terrain_height = land.getHeight({x = player_pos.x, y = player_pos.z})
      local player_agl = player_pos.y - terrain_height
      if player_agl > max_agl then
        players_above_ceiling = players_above_ceiling + 1
      end
    end
  end
  
  if players_above_ceiling > 0 then
    return above
  else 
    return not above
  end
  
end

--determine if any human players are in a zone
function RotorOps.predPlayerInZone(zone_name)
  local players_in_zone = 0
  for uName, uData in pairs(mist.DBs.humansByName) do
    local player_unit = Unit.getByName(uData.unitName)
    if player_unit and RotorOps.isUnitInZone(player_unit, zone_name) then
      players_in_zone = players_in_zone + 1
    end
  end
  if players_in_zone > 0 then
    return true
  else
    return false
  end
end

--determine if enemy CAP is needed
function RotorOps.predSpawnRedCap()
  return true
end

