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

    def __init__(self, mizfile, ref_point=None, ref_heading=0):
        self.source_mission = dcs.mission.Mission()
        self.source_mission.load_file(mizfile)
        self.ref_heading = ref_heading
        if ref_point:
            self.ref_point = ref_point
        else:
            self.ref_point = dcs.Point(self.source_mission.terrain.bullseye_blue["x"], self.source_mission.terrain.bullseye_blue["y"])


    def anchorByGroupName(self, group_name):
        group = self.source_mission.find_group(group_name)
        if group:
            self.ref_point = group.units[0].position
            self.ref_heading = group.units[0].heading
        else:
            logger.warning("Unable to find group for anchor.")


    def copyTo(self, mission, dest_point=None, dest_heading=0):
        if not dest_point:
            dest_point = dcs.Point(mission.terrain.bullseye_blue["x"], mission.terrain.bullseye_blue["y"])

        #iterate over group types first?
        for side in "red", "blue":
            coalition = self.source_mission.coalition.get(side)
            for country in coalition.countries:

                group_types = [coalition.countries[country].static_group, coalition.countries[country].vehicle_group, coalition.countries[country].helicopter_group, coalition.countries[country].plane_group,
                               coalition.countries[country].ship_group]

                for index, group_type in enumerate(group_types):
                    for group in group_type:
                        self.groupToPoint(group, self.ref_point, dest_point, self.ref_heading, dest_heading)
                        if index == 0:
                            mission.country(country).add_static_group(group)
                        elif index == 1:
                            mission.country(country).add_vehicle_group(group)
                        elif index == 2:
                            #mission.country(country).add_helicopter_group(group)
                            print("helicopter groups not available for import")
                        elif index == 3:
                            #mission.country(country).add_plane_group(group)
                            print("plane groups not available for import")
                        elif index == 4:
                            mission.country(country).add_ship_group(group)




    @staticmethod
    def groupToPoint(group, ref_point, dest_point, ref_heading=0, dest_heading=0):
        for unit in group.units:
            heading_to_unit = dcs.mapping.heading_between_points(ref_point.x, ref_point.y, unit.position.x,
                                                                 unit.position.y)
            new_heading_to_unit = dest_heading + heading_to_unit
            unit_distance = ref_point.distance_to_point(unit.position)
            unit.position = dest_point.point_from_heading(new_heading_to_unit, unit_distance)
        return group



# class extractUnits:
#
#     @staticmethod
#     def toPoint(filename, group_type, dest_point, dest_heading=0, side="blue"):
#         print("Attempting to extract units from " + filename + " relative to 'HELO_FARP' initial point.")
#
#         source_mission = dcs.mission.Mission()
#         source_mission.load_file(filename)
#
#
#         # country = source_mission.country('Combined Joint Task Forces Blue')
#         # country.find
#
#         #group_types = []
#
#         groups = []
#
#         for country in source_mission.coalition.get(side).countries:
#
#             ref_point = country.find_static_group("HELO_FARP").position  #units position instead of group?
#             ref_heading = country.find_static_group("HELO_FARP").heading
#             group_types = [country.static_group, country.vehicle_group, country.helicopter_group, country.plane_group, country.ship_group]
#
#             for group_type in group_types:
#                 for group in group_type:
#                     for unit in group.units:
#                         x_rel = ref_point.x - unit.position.x
#                         y_rel = ref_point.y - unit.position.y
#                         #heading_rel = ref_heading - unit.heading # heading of unit relative to heading of the reference object
#                         heading_to_unit = dcs.mapping.heading_between_points(ref_point.x, ref_point.y, unit.position.x, unit.position.y)
#                         new_heading_to_unit = dest_heading + heading_to_unit
#                         unit_distance = ref_point.distance_to_point(unit.position)
#                         unit.position = dest_point.point_from_heading(new_heading_to_unit, unit_distance)
#
#                         # unit.position.x = x - x_rel
#                         # unit.position.y = y - y_rel
#
#                 groups.append(group)
#         return groups

