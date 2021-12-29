RotaryOps = {}

trigger.action.outText("ROTARY OPS STARTED", 5)

local function tableHasKey(table,key)
    return table[key] ~= nil
end

local function dispMsg(text)
  trigger.action.outText(text, 5)
  return text
end

local function tableHasKey(table,key)
    return table[key] ~= nil
end

local function getObjectVolume(obj)
  local length = (obj:getDesc().box.max.x + math.abs(obj:getDesc().box.min.x))
  local height = (obj:getDesc().box.max.y + math.abs(obj:getDesc().box.min.y))
  local depth = (obj:getDesc().box.max.z + math.abs(obj:getDesc().box.min.z))
  return length * height * depth
end

function RotaryOps.spawnInfantryOnGrp(grp, src_grp_name, behavior) --allow to spawn on other group units
  trigger.action.outText("attempting to spawn at "..grp:getUnit(1):getTypeName(), 5)
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
      --local id = timer.scheduleFunction(RotaryOps.seekCover, new_grp, timer.getTime() + 1)
      RotaryOps.patrolRadius({grp = new_grp})
    end
    if behavior == AGGRESSIVE then
      RotaryOps.chargeEnemy({grp = new_grp})
    end
  else trigger.action.outText("Infantry failed to spawn. ", 5)  
  end
end

function RotaryOps.chargeEnemy(vars)
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
   trigger.action.outText("group going back to origin", 5)  
   path[1] = mist.ground.buildWP(start_point, '', 5) 
   path[2] = mist.ground.buildWP(vars.spawn_point, '', 5)
   
 end
 world.searchObjects(Object.Category.UNIT, volS, ifFound)
 mist.goRoute(grp, path)
 local id = timer.scheduleFunction(RotaryOps.chargeEnemy, vars, timer.getTime() + math.random(50,70))

end


function RotaryOps.patrolRadius(vars)
 trigger.action.outText("patrol radius: "..mist.utils.tableShow(vars), 5) 
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
    else trigger.action.outText("object not large enough: "..foundItem:getTypeName(), 5) 
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
 local id = timer.scheduleFunction(RotaryOps.patrolRadius, vars, timer.getTime() + math.random(50,70))

end


function RotaryOps.knowEnemy(vars)
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
  if foundItem:getCoalition() == enemy_coal then
    enemy_unit = foundItem
    trigger.action.outText("found enemy! "..foundItem:getTypeName(), 5) 
    
    path[1] = mist.ground.buildWP(start_point, '', 5) 
    path[2] = mist.ground.buildWP(enemy_unit:getPoint(), '', 5) 
    --path[3] = mist.ground.buildWP(vars.spawn_point, '', 5)
    grp:getUnit(1):getController():knowTarget(enemy_unit, true, true)
    
     
  else 

    --trigger.action.outText("object found is not enemy inf in "..search_radius, 5)  
  end
  
 return true
 end
 --default path if no units found
 if false then
   trigger.action.outText("group going back to origin", 5)  
   path[1] = mist.ground.buildWP(start_point, '', 5) 
   path[2] = mist.ground.buildWP(vars.spawn_point, '', 5)
   
 end
 world.searchObjects(Object.Category.UNIT, volS, ifFound)
 --mist.goRoute(grp, path)
 local id = timer.scheduleFunction(RotaryOps.knowEnemy, vars, timer.getTime() + 15)

end


------------------------------------------



RotaryOps.zones = {}
RotaryOps.active_zone = 'ALPHA'

function RotaryOps.sortOutInfantry(mixed_units)
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

function RotaryOps.assessUnitsInZone(var)
   --consider adding other unit types
   local red_ground_units = mist.getUnitsInZones(mist.makeUnitTable({'[red][vehicle]'}), {RotaryOps.active_zone})  --consider adding other unit types
   local red_infantry = RotaryOps.sortOutInfantry(red_ground_units).infantry
   local red_vehicles = RotaryOps.sortOutInfantry(red_ground_units).not_infantry
   local blue_ground_units = mist.getUnitsInZones(mist.makeUnitTable({'[blue][vehicle]'}), {RotaryOps.active_zone})  --consider adding other unit types
   local blue_infantry = RotaryOps.sortOutInfantry(blue_ground_units).infantry
   local blue_vehicles = RotaryOps.sortOutInfantry(blue_ground_units).not_infantry
   
   trigger.action.outText("["..RotaryOps.active_zone .. "] RED: " ..#red_infantry.. " infantry, " .. #red_vehicles .. " vehicles.  BLUE: "..#blue_infantry.. " infantry, " .. #blue_vehicles.." vehicles.", 5, true) 
   local id = timer.scheduleFunction(RotaryOps.assessUnitsInZone, 1, timer.getTime() + 5)
end
local id = timer.scheduleFunction(RotaryOps.assessUnitsInZone, 1, timer.getTime() + 5)


function RotaryOps.drawZones(zones)  --should be drawZones and itterate through all zones, getting the active zone, and incrementing id
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
    local text = zone.outter_zone_name
    if zone.outter_zone_name == RotaryOps.active_zone then
      color = {1, 1, 1, 0.5}
      fill_color = {1, 0, 1, 0.1}
    end
    if previous_point ~= nill then
      trigger.action.lineToAll(coalition, id + 200, point, previous_point, color, line_type)
    end
    previous_point = point
    trigger.action.outText("drawing map circle", 5)  
    trigger.action.circleToAll(coalition, id, point, radius, color, fill_color, line_type)
    trigger.action.textToAll(coalition, id + 100, point, color, text_fill_color, font_size, read_only, text)
  end
  

end




function RotaryOps.addZone(_outter_zone_name, _vars, group_id)  --todo: implement zone group ids 
  group_id = group_id or 1
  table.insert(RotaryOps.zones, {outter_zone_name = _outter_zone_name, vars = _vars})
  RotaryOps.drawZones(RotaryOps.zones)
  ctld.dropOffZones[#ctld.dropOffZones + 1] = { _outter_zone_name, "green", 0 }
  --trigger.action.outText("zones: ".. mist.utils.tableShow(RotaryOps.zones), 5)  
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

