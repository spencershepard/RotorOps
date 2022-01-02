RotorOps = {}
RotorOps.transports = {'UH-1H', 'Mi-8MT', 'Mi-24P'}
RotorOps.zone_states = {not_started = 0, active = 1, cleared = 2, started = 3}
RotorOps.game_states = {not_started = 0, in_progress = 1, won = 2, lost = 3}
RotorOps.game_state = 0
RotorOps.ground_speed = 10
RotorOps.auto_push = true
local last_message_time
local game_message_buffer = {}
RotorOps.zone_status_display = true
RotorOps.max_units_left = 0 --allow clearing the zone when a few units are left to prevent frustration with units getting stuck in buildings etc


RotorOps.zones = {}
RotorOps.active_zone = ""
RotorOps.active_zone_index = 1
RotorOps.active_zone_flag = 1

RotorOps.staging_zone = ""

RotorOps.ctld_pickup_zones = {}

trigger.action.outText("ROTOR OPS STARTED", 5)
env.info("ROTOR OPS STARTED")

local staged_units
local commandDB = {}

local gameMsgs = {
  push = {
    {'ALL GROUND UNITS, PUSH TO THE ACTIVE ZONE!', '.wav'},
    {'ALL GROUND UNITS, PUSH TO ALPHA!', '.wav'},
    {'ALL GROUND UNITS, PUSH TO BRAVO!', '.wav'},
    {'ALL GROUND UNITS, PUSH TO CHARLIE!', '.wav'},
  },
  fallback = {
    {'ALL GROUND UNITS, FALL BACK!', '.wav'},
    {'ALL GROUND UNITS, FALL BACK TO ALPHA!', '.wav'},
    {'ALL GROUND UNITS, FALL BACK TO BRAVO!', '.wav'},
    {'ALL GROUND UNITS, FALL BACK TO CHARLIE!', '.wav'},
  },
  cleared = {
    {'ZONE CLEARED!', '.wav'},
    {'ALPHA CLEARED!', '.wav'},
    {'BRAVO CLEARED!', '.wav'},
    {'CHARLIE CLEARED!', '.wav'},
  },
  success = {
    {'GROUND MISSION SUCCESS!', '.wav'},
  },
  
    
}

--[[ UTILITY FUNCTIONS ]]--

local function debugMsg(text)
  trigger.action.outText(text, 5)
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

function RotorOps.groupsFromUnits(units)
  --debugTable(units)
  local groups = {}
  --local groupIndex = {}
  for i = 1, #units do 
   if hasValue(groups, units[i]:getGroup():getName()) == false then 
       --debugMsg("added: "..units[i]:getGroup():getName())
       --groups[units[i]:getGroup():getName()] = true
       --groupIndex[#groupIndex + 1] = groups[units[i]:getGroup():getName()]
       groups[#groups + 1] = units[i]:getGroup():getName()
   else --debugMsg(units[i]:getGroup():getName().." was already in the table")
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
    --play the sound file message[2]
  end
  local id = timer.scheduleFunction(processMsgBuffer, 1, timer.getTime() + 5)
end




function RotorOps.spawnInfantryOnGrp(grp, src_grp_name, behavior) --allow to spawn on other group units
  debugMsg("attempting to spawn at "..grp:getUnit(1):getTypeName())
  local vars = {} 
  vars.gpName = src_grp_name
  vars.action = 'clone' 
  vars.point = grp:getUnit(1):getPoint() 
  vars.radius = 5
  vars.disperse = 'disp'
  vars.maxDisp = 5
  local new_grp_table = mist.teleportToPoint(vars) 
  
  if new_grp_table then
    local new_grp = Group.getByName(new_grp_table.name)
    local PATROL = 1
    local AGGRESSIVE = 2
    if behavior == PATROL then
      --trigger.action.outText("new group: "..mist.utils.tableShow(new_grp_table), 5)
      --local id = timer.scheduleFunction(RotorOps.seekCover, new_grp, timer.getTime() + 1)
      RotorOps.patrolRadius({grp = new_grp})
    end
    if behavior == AGGRESSIVE then
      RotorOps.chargeEnemy({grp = new_grp})
    end
  else debugMsg("Infantry failed to spawn. ")  
  end
end

function RotorOps.chargeEnemy(vars)
 --trigger.action.outText("charge enemies: "..mist.utils.tableShow(vars), 5) 
 local grp = vars.grp
 local search_radius = vars.radius or 5000
 ----
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
 ----
 
 if first_valid_unit == nil then return end
 local start_point = first_valid_unit:getPoint()
 if not vars.spawn_point then vars.spawn_point = start_point end

 local enemy_coal
 if grp:getCoalition() == 1 then enemy_coal = 2 end
 if grp:getCoalition() == 2 then enemy_coal = 1 end

 --local sphere = trigger.misc.getZone('town')
 local volS = {
   id = world.VolumeType.SPHERE,
   params = {
     point = grp:getUnit(1):getPoint(),  --check if exists, maybe itterate through grp
     radius = search_radius
   }
 }
 local enemy_unit
 local path = {} 
 local ifFound = function(foundItem, val)
  --trigger.action.outText("found item: "..foundItem:getTypeName(), 5)  
  if foundItem:hasAttribute("Infantry") == true and foundItem:getCoalition() == enemy_coal then
    enemy_unit = foundItem
    --trigger.action.outText("found enemy! "..foundItem:getTypeName(), 5) 
    
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
   debugMsg("group going back to origin")  
   path[1] = mist.ground.buildWP(start_point, '', 5) 
   path[2] = mist.ground.buildWP(vars.spawn_point, '', 5)
   
 end
 world.searchObjects(Object.Category.UNIT, volS, ifFound)
 mist.goRoute(grp, path)
 local id = timer.scheduleFunction(RotorOps.chargeEnemy, vars, timer.getTime() + math.random(50,70))

end


function RotorOps.patrolRadius(vars)
 debugMsg("patrol radius: "..mist.utils.tableShow(vars)) 
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
 --local timing = mist.getPathLength(path) / 5
 local id = timer.scheduleFunction(RotorOps.patrolRadius, vars, timer.getTime() + math.random(50,70))

end





------------------------------------------






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



function RotorOps.assessUnitsInZone(var)
   if RotorOps.game_state ~= RotorOps.game_states.in_progress then return end
   --find and sort units found in the active zone
   local red_ground_units = mist.getUnitsInZones(mist.makeUnitTable({'[red][vehicle]'}), {RotorOps.active_zone})  --consider adding other unit types
   local red_infantry = RotorOps.sortOutInfantry(red_ground_units).infantry
   local red_vehicles = RotorOps.sortOutInfantry(red_ground_units).not_infantry
   local blue_ground_units = mist.getUnitsInZones(mist.makeUnitTable({'[blue][vehicle]'}), {RotorOps.active_zone})  --consider adding other unit types
   local blue_infantry = RotorOps.sortOutInfantry(blue_ground_units).infantry
   local blue_vehicles = RotorOps.sortOutInfantry(blue_ground_units).not_infantry
   
   
   --is the active zone cleared?
     local active_zone_status_flag = RotorOps.zones[RotorOps.active_zone_index].zone_status_flag
     local active_zone_status = trigger.misc.getUserFlag(active_zone_status_flag)
     
     
     if #red_ground_units <= RotorOps.max_units_left then
       RotorOps.clearActiveZone()
     end

   
   --are all zones clear?
   local all_zones_clear = true
   for key, value in pairs(RotorOps.zones) do 
      local zone_status = trigger.misc.getUserFlag(RotorOps.zones[key].zone_status_flag)
      if zone_status ~= RotorOps.zone_states.cleared then
        all_zones_clear = false
      end
   end
   
   if all_zones_clear then
     RotorOps.gameWon()
   end
   
   
   
   local message = ""
   local header = ""
   local body = ""
   if active_zone_status == RotorOps.zone_states.cleared then
     header = "["..RotorOps.active_zone .. " CLEARED!]   " 
   else
     header = "[BATTLE FOR "..RotorOps.active_zone .. "]   " 
   end
   body = "RED: " ..#red_infantry.. " infantry, " .. #red_vehicles .. " vehicles.  BLUE: "..#blue_infantry.. " infantry, " .. #blue_vehicles.." vehicles." 

   message = header .. body
   if RotorOps.zone_status_display then 
     --trigger.action.outText(message , 5, true) 
     game_message_buffer[#game_message_buffer + 1] = {message, ""} --don't load the buffer faster than it's cleared.
   end
   local id = timer.scheduleFunction(RotorOps.assessUnitsInZone, 1, timer.getTime() + 10)
end



function RotorOps.drawZones()  
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
      fill_color = {1, 0, 0, 0.03}
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


function RotorOps.sendUnitsToZone(units_table, zone, _formation, _final_heading, _speed, _force_offroad)
  local formation = _formation or 'cone'
  local final_heading = _final_heading or nil
  local speed = _speed or RotorOps.ground_speed
  local force_offroad = _force_offroad or false
  local groups = RotorOps.groupsFromUnits(units_table)
  for index, group in pairs(groups) do
    --debugMsg("sending to zone: "..zone.." grp: "..group)
    mist.groupToPoint(group, zone, formation, final_heading, speed, force_offroad)
  end
end

function RotorOps.clearActiveZone()
  local active_zone_status_flag = RotorOps.zones[RotorOps.active_zone_index].zone_status_flag
  trigger.action.setUserFlag(active_zone_status_flag, RotorOps.zone_states.cleared)  --set the zone's flag to cleared
  gameMsg(gameMsgs.cleared, RotorOps.active_zone_index)
  if RotorOps.auto_push then
    RotorOps.pushZone()
  end
end

function RotorOps.pushZone()
  RotorOps.setActiveZone(RotorOps.active_zone_index + 1)
  RotorOps.sendUnitsToZone(staged_units, RotorOps.zones[RotorOps.active_zone_index].name)
end

function RotorOps.fallBack()
  RotorOps.setActiveZone(RotorOps.active_zone_index - 1)
  RotorOps.sendUnitsToZone(staged_units, RotorOps.zones[RotorOps.active_zone_index].name)
end

function RotorOps.startConflict()
  if RotorOps.game_state == RotorOps.game_states.in_progress then return end 
  RotorOps.game_state = RotorOps.game_states.in_progress
  
  --make some changes to the radio menu
  local conflict_zones_menu = commandDB['conflict_zones_menu']
  missionCommands.removeItem(commandDB['start_conflict']) 
  commandDB['push_zone'] = missionCommands.addCommand( "Push to next zone", conflict_zones_menu , RotorOps.pushZone)
  commandDB['fall_back'] = missionCommands.addCommand( "Fall back to prev zone"  , conflict_zones_menu , RotorOps.fallBack)
  
  staged_units = mist.getUnitsInZones(mist.makeUnitTable({'[all][vehicle]'}), {RotorOps.staging_zone})
  --local helicopters = mist.getUnitsInZones(mist.makeUnitTable({'[all][helicopter]'}), {RotorOps.zones[1].name})
  --RotorOps.sendUnitsToZone(helicopters, RotorOps.zones[2].name, nil, nil, 90)
  RotorOps.sendUnitsToZone(staged_units, RotorOps.zones[1].name)
  RotorOps.setActiveZone(1)
  gameMsg(gameMsgs.push, 1)
  processMsgBuffer()
  local id = timer.scheduleFunction(RotorOps.assessUnitsInZone, 1, timer.getTime() + 5)
end

function RotorOps.gameWon()
  RotorOps.game_state = RotorOps.game_states.won
  gameMsg(gameMsgs.success)
end


function RotorOps.setActiveZone(new_index) 
  local old_index = RotorOps.active_zone_index
  if new_index > #RotorOps.zones then 
    new_index = #RotorOps.zones 
  end
  if new_index < 1 then 
    new_index = 1 
  end
  
  if new_index ~= old_index then  --the active zone is changing
    
    ctld.activatePickupZone(RotorOps.zones[old_index].name)
    ctld.deactivatePickupZone(RotorOps.zones[new_index].name)
    RotorOps.active_zone_index = new_index
    trigger.action.setUserFlag(RotorOps.zones[new_index].zone_status_flag, RotorOps.zone_states.active)
    if new_index < old_index then gameMsg(gameMsgs.fallback, new_index) end
    if new_index > old_index then gameMsg(gameMsgs.push, new_index) end
    
    
  end
  
  
  RotorOps.active_zone = RotorOps.zones[new_index].name
  --debugMsg("active zone: "..RotorOps.active_zone.."  old zone: "..RotorOps.zones[old_index].name)  
  trigger.action.setUserFlag(RotorOps.active_zone_flag, RotorOps.active_zone_index)
  RotorOps.drawZones()
end



function RotorOps.setupCTLD()
  ctld.enableCrates = false
  ctld.enabledFOBBuilding = false
  ctld.JTAC_lock = "vehicle"
  ctld.location_DMS = true
  ctld.numberOfTroops = 24 --max loading size
  
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
   -- {name = "Mortar Squad Red", inf = 2, mortar = 5, side =1 }, --would make a group loadable by RED only
    {name = "Standard Group (10)", inf = 6, mg = 2, at = 2 }, -- will make a loadable group with 6 infantry, 2 MGs and 2 anti-tank for both coalitions
    {name = "Anti Air (5)", inf = 2, aa = 3  },
    {name = "Anti Tank (8)", inf = 2, at = 6  },
    {name = "Mortar Squad (6)", mortar = 6 },
    {name = "Small Standard Group (4)", inf = 2, mg = 1, at = 1 },
    {name = "JTAC Group (5)", inf = 4, jtac = 1 }, -- will make a loadable group with 4 infantry and a JTAC soldier for both coalitions
    {name = "Single JTAC (1)", jtac = 1 },
    {name = "Platoon (24)", inf = 12, mg = 4, at = 3, aa = 1 },
    
}
end



function RotorOps.debugAction()
  --trigger.action.outText("zones: ".. mist.utils.tableShow(RotorOps.zones), 5)
  RotorOps.clearActiveZone()

end


function RotorOps.setupRadioMenu()
  commandDB['conflict_zones_menu'] = missionCommands.addSubMenu( "ROTOR OPS")
  local conflict_zones_menu = commandDB['conflict_zones_menu']


  commandDB['start_conflict'] = missionCommands.addCommand( "Start conflict"  , conflict_zones_menu , RotorOps.startConflict)
  commandDB['debug_action'] = missionCommands.addCommand( "Debug action"  , conflict_zones_menu , RotorOps.debugAction)
end


function RotorOps.spawnInfantryAtZone(vars)
  local side = vars.side
  local inf = vars.inf
  local zone = vars.zone
  local radius = vars.radius
  ctld.spawnGroupAtTrigger(side, inf, zone, radius)
end


function RotorOps.addZone(_name, _zone_status_flag) 
  table.insert(RotorOps.zones, {name = _name, zone_status_flag = _zone_status_flag})
  trigger.action.setUserFlag(_zone_status_flag, RotorOps.zone_states.not_started)
  RotorOps.drawZones()
  --ctld.dropOffZones[#ctld.dropOffZones + 1] = { _name, "green", 0 }
  RotorOps.addPickupZone(_name, "green", -1, "no", 0)
  --ctld.dropOffZones[#ctld.dropOffZones + 1] = { _name, "none", 1 }
  --trigger.action.outText("zones: ".. mist.utils.tableShow(RotorOps.zones), 5)  
end

function RotorOps.stagingZone(_name)
  RotorOps.addPickupZone(_name, "blue", -1, "yes", 0)
  RotorOps.staging_zone = _name
end

function RotorOps.setupConflict(_active_zone_flag)
  RotorOps.addPilots(1)
  RotorOps.setupCTLD()
  RotorOps.setupRadioMenu()
  RotorOps.active_zone_flag = _active_zone_flag
  RotorOps.game_state = RotorOps.game_states.not_started
  trigger.action.outText("ALL TROOPS GET TO TRANSPORT AND PREPARE FOR DEPLOYMENT!" , 10, false)
  
end


function RotorOps.addPickupZone(zone_name, smoke, limit, active, side)
  RotorOps.ctld_pickup_zones[#RotorOps.ctld_pickup_zones + 1] = zone_name
  ctld.pickupZones[#ctld.pickupZones + 1] = {zone_name, smoke, limit, active, side}
end


