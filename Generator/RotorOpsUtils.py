import math
import dcs
from MissionGenerator import logger


def getDistance(point1=dcs.Point, point2=dcs.Point):
    x1 = point1.x
    y1 = point1.y
    x2 = point2.x
    y2 = point2.y
    dX = abs(x1-x2)
    dY = abs(y1-y2)
    distance = math.sqrt(dX*dX + dY*dY)
    return distance

def convertMeterToNM(meters=int):
    nm = meters / 1852
    return nm




class ImportObjects:

    def __init__(self, mizfile, source_point=None, source_heading=0):
        logger.info("Importing objects from " + mizfile)
        self.source_mission = dcs.mission.Mission()
        self.source_mission.load_file(mizfile)
        self.source_heading = source_heading
        if source_point:
            self.source_point = source_point
        else:
            self.source_point = dcs.Point(self.source_mission.terrain.bullseye_blue["x"], self.source_mission.terrain.bullseye_blue["y"])


    def anchorByGroupName(self, group_name):
        group = self.source_mission.find_group(group_name)
        if group:
            self.source_point = group.units[0].position
            self.source_heading = group.units[0].heading
        else:
            logger.warning("Unable to find group for anchor.")


    def copyTo(self, mission, dest_name, dest_point=None, dest_heading=0):
        logger.info("Copying objects as " + dest_name)
        if not dest_point:
            dest_point = dcs.Point(mission.terrain.bullseye_blue["x"], mission.terrain.bullseye_blue["y"])

        for side in "red", "blue":
            coalition = self.source_mission.coalition.get(side)
            for country_name in coalition.countries:

                group_types = [coalition.countries[country_name].static_group, coalition.countries[country_name].vehicle_group, coalition.countries[country_name].helicopter_group, coalition.countries[country_name].plane_group,
                               coalition.countries[country_name].ship_group]

                for index, group_type in enumerate(group_types):
                    for group in group_type:
                        self.groupToPoint(group, self.source_point, dest_point, self.source_heading, dest_heading)


                        if index == 0: # Statics
                            type_name = group.units[0].type
                            type_maps = [dcs.statics.cargo_map, dcs.statics.warehouse_map, dcs.statics.groundobject_map, dcs.statics.fortification_map]
                            classed = False
                            for type_map in type_maps:
                                if type_name in type_map:
                                    classed = True
                                    unit_type = type_map[type_name]
                                    ng = mission.static_group(mission.country(country_name),
                                                              group.name,
                                                              unit_type,
                                                              group.units[0].position,
                                                              group.units[0].heading,
                                                              hidden=False)
                            if not classed:
                                print("No pydcs class for " + type_name)


                                class temp(dcs.unittype.StaticType):
                                    id = group.units[0].type
                                    name = group.units[0].name
                                    shape_name = group.units[0].shape_name
                                    rate = group.units[0].rate


                                ng = mission.static_group(mission.country(country_name),
                                                          group.name,
                                                          temp,
                                                          group.units[0].position,
                                                          group.units[0].heading,
                                                          hidden=False)

                        elif index == 1:  # Vehicles

                            for i, unit in enumerate(group.units):
                                if i == 0:
                                    ng = mission.vehicle_group(mission.country(country_name),
                                                              group.name,
                                                              dcs.vehicles.vehicle_map[group.units[0].type],
                                                              group.units[0].position,
                                                              group.units[0].heading)


                                else:

                                        u = mission.vehicle(group.units[i].name, dcs.vehicles.vehicle_map[group.units[i].type])
                                        u.position = group.units[i].position
                                        u.heading = group.units[i].heading
                                        ng.add_unit(u)

                            mission.country(country_name).add_vehicle_group(ng)


                        elif index == 2: # Helicopters

                            if group.units[0].skill == dcs.unit.Skill.Client or group.units[0].skill == dcs.unit.Skill.Player:

                                farp = mission.farp(mission.country(country_name), dest_name + " " + group.name + " Pad", group.units[0].position, hidden=True, dead=False,
                                             farp_type=dcs.unit.InvisibleFARP)

                                ng = mission.flight_group_from_unit(mission.country(country_name),
                                                                   dest_name + " " + group.name,
                                                                   dcs.helicopters.helicopter_map[group.units[0].type],
                                                                   farp,
                                                                   group_size=1)

                                ng.points[0].action = dcs.point.PointAction.FromGroundArea
                                ng.points[0].type = "TakeOffGround"
                                ng.units[0].heading = group.units[0].heading
                                ng.units[0].skill = group.units[0].skill
                                ng.units[0].livery_id = group.units[0].livery_id
                                ng.units[0].pylons = group.units[0].pylons

                        elif index == 3:
                            #mission.country(country).add_plane_group(group)
                            print("not yet avail")
                        elif index == 4:
                            #mission.country(country).add_ship_group(group)
                            print("not yet avail")


    @staticmethod
    def groupToPoint(group, src_point, dest_point, src_heading=0, dest_heading=0):
        for unit in group.units:
            heading_to_unit = dcs.mapping.heading_between_points(src_point.x, src_point.y, unit.position.x,
                                                                 unit.position.y)
            new_heading_to_unit = dest_heading + heading_to_unit
            unit_distance = src_point.distance_to_point(unit.position)
            unit.position = dest_point.point_from_heading(new_heading_to_unit, unit_distance)
            unit.heading = unit.heading + dest_heading
        return group