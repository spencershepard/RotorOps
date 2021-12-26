RotaryOps = {}

trigger.action.outText("ROTARY OPS STARTED", 5)

local function tableHasKey(table,key)
    return table[key] ~= nil
end

local function dispMsg(text)
  trigger.action.outText(text, 5)
  return text
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
 local id = timer.scheduleFunction(RotaryOps.chargeEnemy, vars, timer.getTime() + 60)

end


function RotaryOps.patrolRadius(vars)
 --trigger.action.outText("patrol radius: "..mist.utils.tableShow(vars), 5) 
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
 local id = timer.scheduleFunction(RotaryOps.patrolRadius, vars, timer.getTime() + 60)

end



