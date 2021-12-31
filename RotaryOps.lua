RotorOps = {}
RotorOps.transports = {'UH-1H', 'Mi-8MT', 'Mi-24P'}
RotorOps.conflict_started = false
RotorOps.zone_states = {not_started = 0, active = 1, cleared = 2}
RotorOps.ground_speed = 10
RotorOps.std_phonetic_names = true
trigger.action.outText("ROTOR OPS STARTED", 5)
env.info("ROTOR OPS STARTED")

local staged_units
local commandDB = {}

local gameMsgs = {
  push = {
    {'ALL UNITS, PUSH TO FIRST ZONE!', '.wav'},
    {'ALL UNITS, PUSH TO ALPHA!', '.wav'},
    {'ALL UNITS, PUSH TO BRAVO!', '.wav'},
    {'ALL UNITS, PUSH TO CHARLIE!', '.wav'},
  },
  fallback = {
    {'ALL UNITS, FALL BACK!', '.wav'},
    {'ALL UNITS, FALL BACK TO ALPHA!', '.wav'},
    {'ALL UNITS, FALL BACK TO BRAVO!', '.wav'},
    {'ALL UNITS, FALL BACK TO CHARLIE!', '.wav'},
  },
  cleared = {
    {'ZONE CLEARED!', '.wav'},
    {'ALPHA CLEARED!', '.wav'},
    {'BRAVO CLEARED!', '.wav'},
    {'CHARLIE CLEARED!', '.wav'},
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
  debugTable(event)
  local index = 1
  if _index ~= nill then
    index = _index  
  end
  if tableHasKey(event, index) then
    trigger.action.outText(event[index][1], 5, true)
  else env.info("ROTOR OPS could not find entry for "..key)
  end
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



RotorOps.zones = {}
RotorOps.active_zone = ""
RotorOps.active_zone_index = 1
RotorOps.active_zone_flag = 1


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
   --find and sort units found in the active zone
   local red_ground_units = mist.getUnitsInZones(mist.makeUnitTable({'[red][vehicle]'}), {RotorOps.active_zone})  --consider adding other unit types
   local red_infantry = RotorOps.sortOutInfantry(red_ground_units).infantry
   local red_vehicles = RotorOps.sortOutInfantry(red_ground_units).not_infantry
   local blue_ground_units = mist.getUnitsInZones(mist.makeUnitTable({'[blue][vehicle]'}), {RotorOps.active_zone})  --consider adding other unit types
   local blue_infantry = RotorOps.sortOutInfantry(blue_ground_units).infantry
   local blue_vehicles = RotorOps.sortOutInfantry(blue_ground_units).not_infantry
   
   --is the zone cleared?
   local max_units_left = 3 --allow clearing the zone when a few units are left to prevent frustration with units getting stuck in buildings etc
   if #blue_ground_units > #red_ground_units and #red_ground_units <= max_units_left then
     RotorOps.zones[RotorOps.active_zone_index].zone_status_flag = RotorOps.zone_states.cleared  --set the zone's flag to cleared
     gameMsg(gameMsgs.cleared, RotorOps.active_zone_index)
   end
   
   if RotorOps.conflict_started then
     trigger.action.outText("[BATTLE FOR "..RotorOps.active_zone .. "]   RED: " ..#red_infantry.. " infantry, " .. #red_vehicles .. " vehicles.  BLUE: "..#blue_infantry.. " infantry, " .. #blue_vehicles.." vehicles.", 5, true) 
   else trigger.outText("ALL TROOPS GET TO TRANSPORT AND PREPARE FOR DEPLOYMENT!")
   end
   local id = timer.scheduleFunction(RotorOps.assessUnitsInZone, 1, timer.getTime() + 5)
end
local id = timer.scheduleFunction(RotorOps.assessUnitsInZone, 1, timer.getTime() + 5)


function RotorOps.drawZones(zones)  
  local previous_point
  for index, zone in pairs(zones)
  do
    local point = trigger.misc.getZone(zone.outter_zone_name).point
    local radius = trigger.misc.getZone(zone.outter_zone_name).radius
    local coalition = -1
    local id = index  --this must be UNIQUE!
    local color = {1, 1, 1, 0.5}
    local fill_color = {1, 1, 1, 0.1}
    local text_fill_color = {0, 0, 0, 0}
    local line_type = 5 --1 Solid  2 Dashed  3 Dotted  4 Dot Dash  5 Long Dash  6 Two Dash
    local font_size = 20
    local read_only = false
    local text = index..". "..zone.outter_zone_name
    if zone.outter_zone_name == RotorOps.active_zone then
      color = {1, 1, 1, 0.5}
      fill_color = {1, 0, 1, 0.1}
    end
    if previous_point ~= nill then
      trigger.action.lineToAll(coalition, id + 200, point, previous_point, color, line_type)
    end
    previous_point = point
    trigger.action.circleToAll(coalition, id, point, radius, color, fill_color, line_type)
    trigger.action.textToAll(coalition, id + 100, point, color, text_fill_color, font_size, read_only, text)
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
RotorOps.addPilots(1)

function RotorOps.sendUnitsToZone(units_table, zone)
  local groups = RotorOps.groupsFromUnits(units_table)
  for index, group in pairs(groups) do
    --debugMsg("sending to zone: "..zone.." grp: "..group)
    mist.groupToPoint(group, zone, 'cone', nil, nil, false)
  end
end



function RotorOps.pushZone()
  RotorOps.setActiveZone(1)
  RotorOps.sendUnitsToZone(staged_units, RotorOps.zones[RotorOps.active_zone_index].outter_zone_name)
end

function RotorOps.fallBack()
  RotorOps.setActiveZone(-1)
  RotorOps.sendUnitsToZone(staged_units, RotorOps.zones[RotorOps.active_zone_index].outter_zone_name)
end

function RotorOps.startConflict()
  if RotorOps.conflict_started then return end 
  RotorOps.conflict_started = true
  
  --make some changes to the radio menu
  local conflict_zones_menu = commandDB['conflict_zones_menu']
  missionCommands.removeItem(commandDB['start_conflict']) 
  commandDB['push_zone'] = missionCommands.addCommand( "Push to next zone", conflict_zones_menu , RotorOps.pushZone)
  commandDB['fall_back'] = missionCommands.addCommand( "Fall back to prev zone"  , conflict_zones_menu , RotorOps.fallBack)
  
  gameMsg(gameMsgs.push, 2)
  staged_units = mist.getUnitsInZones(mist.makeUnitTable({'[all][vehicle]'}), {RotorOps.zones[1].outter_zone_name})
  RotorOps.sendUnitsToZone(staged_units, RotorOps.zones[2].outter_zone_name)
end



function RotorOps.setActiveZone(value)  --this should accept the zone index so that we can set active value to any zone and set up zones appropriately
  local old_index = RotorOps.active_zone_index
  local new_index = RotorOps.active_zone_index + value
  if new_index > #RotorOps.zones then 
    new_index = #RotorOps.zones 
  end
  if new_index < 1 then 
    new_index = 1 
  end
  
  if new_index ~= old_index then  --the active zone is changing
    
    ctld.activatePickupZone(RotorOps.zones[old_index].outter_zone_name)
    ctld.deactivatePickupZone(RotorOps.zones[new_index].outter_zone_name)
    RotorOps.active_zone_index = new_index
    trigger.action.setUserFlag(RotorOps.zones[new_index].zone_status_flag, RotorOps.zone_states.active)
    --trigger.action.setUserFlag(RotorOps.zones[new_index].zone_status_flag, RotorOps.zone_states.)  --set another type of zone flag here
    
    
  end
  
  if new_index < old_index then gameMsg(gameMsgs.fallback, new_index) end
  if new_index > old_index then gameMsg(gameMsgs.push, new_index) end
  RotorOps.active_zone = RotorOps.zones[new_index].outter_zone_name
  debugMsg("active zone: "..RotorOps.active_zone.."  old zone: "..RotorOps.zones[old_index].outter_zone_name)  
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
RotorOps.setupCTLD()


function RotorOps.logSomething()
  --trigger.action.outText("zones: ".. mist.utils.tableShow(RotorOps.zones), 5)
  for key, value in pairs(RotorOps.zones) do 
    trigger.action.outText("zone: ".. RotorOps.zones[key].outter_zone_name, 5)
  end
end


function RotorOps.setupRadioMenu()
  commandDB['conflict_zones_menu'] = missionCommands.addSubMenu( "ROTOR OPS")
  local conflict_zones_menu = commandDB['conflict_zones_menu']


  commandDB['start_conflict'] = missionCommands.addCommand( "Start conflict"  , conflict_zones_menu , RotorOps.startConflict)
  --commandDB['log_something'] = missionCommands.addCommand( "Log something"  , conflict_zones_menu , RotorOps.logSomething)
end
RotorOps.setupRadioMenu()

function RotorOps.spawnInfantryAtZone(vars)
  local side = vars.side
  local inf = vars.inf
  local zone = vars.zone
  local radius = vars.radius
  ctld.spawnGroupAtTrigger(side, inf, zone, radius)
end


function RotorOps.addZone(_outter_zone_name, _zone_status_flag) 
  table.insert(RotorOps.zones, {outter_zone_name = _outter_zone_name, zone_status_flag = _zone_status_flag})
  trigger.action.setUserFlag(_zone_status_flag, RotorOps.zone_states.not_started)
  RotorOps.drawZones(RotorOps.zones)
  --ctld.dropOffZones[#ctld.dropOffZones + 1] = { _outter_zone_name, "green", 0 }
  ctld.pickupZones[#ctld.pickupZones + 1] = { _outter_zone_name, "blue", -1, "yes", 0 }  --can we dynamically change sides?
  ctld.dropOffZones[#ctld.dropOffZones + 1] = { _outter_zone_name, "none", 1 }
  --trigger.action.outText("zones: ".. mist.utils.tableShow(RotorOps.zones), 5)  
  
  
  
  if infantry_grps ~= nil then 
    local vars = {
      side = "red",
      inf = infantry_grps,
      zone = _outter_zone_name,
      radius = 1000,
    }
    local id = timer.scheduleFunction(RotorOps.spawnInfantryAtZone, vars, timer.getTime() + 5)
  end
end

function RotorOps.setupConflict(_active_zone_flag)
  
  RotorOps.active_zone_flag = _active_zone_flag
  RotorOps.setActiveZone(0)
end




--[[
vars = {
inner_zone = '',
infantry_spawn = 10,
infantry_respawn = 50,
infantry_spawn_zone = ''
defender_coal = 'red'
}
]]

