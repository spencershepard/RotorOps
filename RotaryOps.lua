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

function RotaryOps.spawn(grp)
  local vars = {} 
  vars.gpName = 'RED_Infantry' 
  vars.action = 'clone' 
  vars.point = grp:getUnit(1):getPoint() 
  vars.radius = 5
  vars.disperse = 'disp'
  vars.maxDisp = 5
  local new_grp_table = mist.teleportToPoint(vars) 
  
  if new_grp_table then
    local new_grp = Group.getByName(new_grp_table.name)
    trigger.action.outText("new group: "..mist.utils.tableShow(new_grp_table), 5)
    if 1 then
    trigger.action.outText("new group: "..mist.utils.tableShow(new_grp_table), 5)
      local id = timer.scheduleFunction(RotaryOps.seekCover, new_grp, timer.getTime() + 1)
    end
  else trigger.action.outText("failed to spawn? ", 5)  
  end
end

function RotaryOps.seekCover(grp)
 trigger.action.outText("seek cover: "..mist.utils.tableShow(grp), 5) 
 local object_vol_thresh = 0
 local foundUnits = {}
 --local sphere = trigger.misc.getZone('town')
 local volS = {
   id = world.VolumeType.SPHERE,
   params = {
     point = grp:getUnit(1):getPoint(),
     radius = 400
   }
 }
 
 local ifFound = function(foundItem, val)
  trigger.action.outText("found item: "..foundItem:getTypeName(), 5)  
  if foundItem:hasAttribute("Infantry") ~= true then  --disregard infantry...we only want objects that might provide cover
    if getObjectVolume(foundItem) > object_vol_thresh then
      foundUnits[#foundUnits + 1] = foundItem
      --trigger.action.outText("valid cover item: "..foundItem:getTypeName(), 5) 
    end
  else trigger.action.outText("object not the right type", 5)  
  end
 return true
 end
 
 --world.searchObjects(Object.Category.UNIT, volS, ifFound)
 --world.searchObjects(Object.Category.STATIC, volS, ifFound)
 world.searchObjects(Object.Category.SCENERY, volS, ifFound)
 --world.searchObjects(Object.Category.BASE, volS, ifFound)
 local path = {} 
 path[1] = mist.ground.buildWP(grp:getUnit(1):getPoint(), '', 5) 
 for i = 1, #foundUnits , 1
   do
     local rand_index = math.random(1,#foundUnits)
     path[i + 1] = mist.ground.buildWP(foundUnits[rand_index]:getPoint(), '', 5) 
     trigger.action.outText("waypoint to: "..foundUnits[i]:getTypeName(), 5) 
   end
 mist.goRoute(grp, path)

end


