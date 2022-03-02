import math
import dcs
from MissionGenerator import logger


class ImportObjects:

    def __init__(self, mizfile, source_point=None, source_heading=0):
        self.pad_unit = True #todo: use this to hold a unit for helicopter placement on ships ie flight_group_from_unit
        logger.info("Importing objects from " + mizfile)
        self.source_mission = dcs.mission.Mission()
        self.source_mission.load_file(mizfile)
        self.source_heading = source_heading
        if source_point:
            self.source_point = source_point
        else:
            self.source_point = dcs.Point(self.source_mission.terrain.bullseye_blue["x"], self.source_mission.terrain.bullseye_blue["y"])
        self.statics = []
        self.vehicles = []
        self.helicopters = []

        self.extractUnits()

    def getStatics(self):
        return self.statics

    def getVehicles(self):
        return self.vehicles

    def getHelicopters(self):
        return self.helicopters

    def copyAll(self, mission, dest_country_name, dest_name, dest_point=None, dest_heading=0):
        return self.copyStatics(mission, dest_country_name, dest_name, dest_point, dest_heading), \
               self.copyVehicles(mission, dest_country_name, dest_name, dest_point, dest_heading), \
               self.copyHelicopters(mission, dest_country_name, dest_name, dest_point, dest_heading)


    def anchorByGroupName(self, group_name):
        group = self.source_mission.find_group(group_name)
        if group:
            self.source_point = group.units[0].position
            self.source_heading = group.units[0].heading
        else:
            logger.warning("Unable to find group for anchor.")
            raise Exception(
                "Import template file error: " + self.mizfile + " does not contain a group called " + group_name)

    def extractUnits(self):

        for side in "red", "blue", "neutrals":
            coalition = self.source_mission.coalition.get(side)
            for country_name in coalition.countries:

                group_types = [coalition.countries[country_name].static_group, coalition.countries[country_name].vehicle_group, coalition.countries[country_name].helicopter_group, coalition.countries[country_name].plane_group,
                               coalition.countries[country_name].ship_group]

                for index, group_type in enumerate(group_types):
                    for group in group_type:

                        if index == 0: # Statics
                            self.statics.append(group)
                        elif index == 1:  # Vehicles
                            self.vehicles.append(group)
                        elif index == 2: # Helicopters
                            self.helicopters.append(group)
                        elif index == 3:
                            logger.warn(group.name + ": Planes not available for import")
                        elif index == 4:
                            logger.warn(group.name + ": Ships not available for import")


    def copyStatics(self, mission, dest_country_name, dest_name, dest_point=None, dest_heading=0):
        logger.info("Copying " + str(len(self.statics)) + " static objects as " + dest_name)
        new_groups = []

        if not dest_point:
            dest_point = dcs.Point(mission.terrain.bullseye_blue["x"], mission.terrain.bullseye_blue["y"])

        #Statics
        statics_copy = self.statics.copy()
        for group in statics_copy:

            self.groupToPoint(group, self.source_point, dest_point, self.source_heading, dest_heading)


            class temp(dcs.unittype.StaticType):
                id = group.units[0].type
                name = group.units[0].name
                shape_name = group.units[0].shape_name
                rate = group.units[0].rate
                can_cargo = group.units[0].can_cargo
                mass = group.units[0].mass


            ng = mission.static_group(mission.country(dest_country_name),
                                      dest_name + " " + group.name,
                                      temp,
                                      group.units[0].position,
                                      group.units[0].heading,
                                      hidden=False)
            ng.units[0].name = group.units[0].name
            new_groups.append(ng)

            # if ng.units[0].type == "Invisible FARP":
            #     self.pad_unit = ng

        return new_groups




    def copyVehicles(self, mission, dest_country_name, dest_name, dest_point=None, dest_heading=0):
        logger.info("Copying " + str(len(self.vehicles)) + " vehicle groups as " + dest_name)
        new_groups = []

        if not dest_point:
            dest_point = dcs.Point(mission.terrain.bullseye_blue["x"], mission.terrain.bullseye_blue["y"])

        vehicles_copy = self.vehicles
        for group in vehicles_copy:

            self.groupToPoint(group, self.source_point, dest_point, self.source_heading, dest_heading)

            for i, unit in enumerate(group.units):
                if i == 0:
                    ng = mission.vehicle_group(mission.country(dest_country_name),
                                              dest_name + " " + group.name,
                                              dcs.vehicles.vehicle_map[group.units[0].type],
                                              group.units[0].position,
                                              group.units[0].heading)

                    new_groups.append(ng) # will this hold units we add later?

                else:

                        u = mission.vehicle(dest_name + " " + group.units[i].name, dcs.vehicles.vehicle_map[group.units[i].type])
                        u.position = group.units[i].position
                        u.heading = group.units[i].heading
                        ng.add_unit(u)

        return new_groups


    def copyHelicopters(self, mission, dest_country_name, dest_name, dest_point=None, dest_heading=0):
        logger.info("Copying " + str(len(self.helicopters)) + " helicopters as " + dest_name)
        new_groups = []

        if not dest_point:
            dest_point = dcs.Point(mission.terrain.bullseye_blue["x"], mission.terrain.bullseye_blue["y"])

        helicopters_copy = self.helicopters.copy()
        for group in helicopters_copy:

            self.groupToPoint(group, self.source_point, dest_point, self.source_heading, dest_heading)

            if self.pad_unit:
                if group.units[0].skill == dcs.unit.Skill.Client or group.units[0].skill == dcs.unit.Skill.Player:

                    # we'll create a new FARP for each helicopter.  we've tried adding the flight group to an existing FARP, but they stack on top of each other
                    # trying to move the units into position after adding the flight group moves the 2D graphic of the helicopter, but the unit marker remains stacked on top
                    # of the unit marker in ME
                    # farp = mission.country(country_name).find_group(self.pad_unit.name)

                    farp = mission.farp(mission.country(dest_country_name), dest_name + " " + group.name + " Pad", group.units[0].position, hidden=True, dead=False,
                                farp_type=dcs.unit.InvisibleFARP)



                    ng = mission.flight_group_from_unit(mission.country(dest_country_name),
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

                    new_groups.append(ng)
            else:
                logger.warn("No pad unit (ie FARP, carrier) found, so can't add helicopters.")

        return new_groups


    def copyVehiclesAsGroup(self, mission, dest_country_name, dest_name, dest_point=None, dest_heading=0):
        logger.info("Copying " + str(len(self.vehicles)) + " vehicle groups as single group name: " + dest_name)
        new_group = None

        if not dest_point:
            dest_point = dcs.Point(mission.terrain.bullseye_blue["x"], mission.terrain.bullseye_blue["y"])

        unit_count = 0
        vehicles_copy = self.vehicles.copy()
        for group in vehicles_copy:
            self.groupToPoint(group, self.source_point, dest_point, self.source_heading, dest_heading)
            for i, unit in enumerate(group.units):

                if unit_count == 0:
                    print("Group:" + group.name)
                    new_group = mission.vehicle_group(mission.country(dest_country_name),
                                                      dest_name,
                                                      dcs.vehicles.vehicle_map[group.units[0].type],
                                                      group.units[0].position,
                                                      group.units[0].heading)
                    unit_count = unit_count + 1

                else:

                    print("Unit:" + group.units[i].name)
                    u = mission.vehicle(dest_name + " " + group.units[i].name, dcs.vehicles.vehicle_map[group.units[i].type])
                    u.position = group.units[i].position
                    u.heading = group.units[i].heading
                    new_group.add_unit(u)

                    unit_count = unit_count + 1
        print("Made a group with units: " + str(unit_count))
        print("group actually has units: " + str(len(new_group.units)))

        return new_group


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