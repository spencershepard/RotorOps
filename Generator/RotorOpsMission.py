from tokenize import String

import dcs
import os
import random

import RotorOpsGroups
import RotorOpsUnits
import time
from MissionGenerator import logger



class RotorOpsMission:

    def __init__(self):
        self.m = dcs.mission.Mission()
        os.chdir("../")
        self.home_dir = os.getcwd()
        self.scenarios_dir = self.home_dir + "\Generator\Scenarios"
        self.forces_dir = self.home_dir + "\Generator\Forces"
        self.script_directory = self.home_dir
        self.sound_directory = self.home_dir + "\sound\embedded"
        self.output_dir = self.home_dir + "\Generator\Output"
        self.assets_dir = self.home_dir + "\Generator/assets"

        self.conflict_zones = {}
        self.staging_zones = {}
        self.spawn_zones = {}
        self.scripts = {}
        self.res_map = {}

    class RotorOpsZone:
        def __init__(self, name: str, flag: int, position: dcs.point, size: int):
            self.name = name
            self.flag = flag
            self.position = position
            self.size = size

    def getMission(self):
        return self.m

    def addZone(self, zone_dict, zone: RotorOpsZone):
        zone_dict[zone.name] = zone

    def addResources(self, sound_directory, script_directory):
        # add all of our required sounds
        os.chdir(sound_directory)
        path = os.getcwd()
        dir_list = os.listdir(path)
        # print("Files and directories in '", path, "' :")
        # print(dir_list)

        for filename in dir_list:
            if filename.endswith(".ogg"):
                #print(filename)
                key = self.m.map_resource.add_resource_file(filename)
                self.res_map[filename] = key


        #add all of our lua scripts
        os.chdir(script_directory)
        path = os.getcwd()
        dir_list = os.listdir(path)
        # print("Files and directories in '", path, "' :")
        # print(dir_list)

        for filename in dir_list:
            if filename.endswith(".lua"):
                logger.info("Adding script to mission: " + filename)
                self.scripts[filename] = self.m.map_resource.add_resource_file(filename)

    def getUnitsFromMiz(self, filename, side):

        forces = {}
        vehicles = []
        attack_helos = []
        transport_helos = []
        attack_planes = []
        fighter_planes = []

        os.chdir(self.home_dir)
        os.chdir(self.forces_dir + "/" + side)
        logger.info("Looking for " + side + " Forces files in '" + os.getcwd())
        source_mission = dcs.mission.Mission()

        try:
            source_mission.load_file(filename)

            for country_name in source_mission.coalition.get(side).countries:
                country_obj = source_mission.coalition.get(side).countries[country_name]
                for vehicle_group in country_obj.vehicle_group:
                    vehicles.append(vehicle_group)
                for helicopter_group in country_obj.helicopter_group:
                    if helicopter_group.task == 'CAS':
                        attack_helos.append(helicopter_group)
                    elif helicopter_group.task == 'Transport':
                        transport_helos.append(helicopter_group)
                for plane_group in country_obj.plane_group:
                    if plane_group.task == 'CAS':
                        attack_planes.append(plane_group)
                    elif plane_group.task == 'CAP':
                        fighter_planes.append(plane_group)

            forces["vehicles"] = vehicles
            forces["attack_helos"] = attack_helos
            forces["transport_helos"] = transport_helos
            forces["attack_planes"] = attack_planes
            forces["fighter_planes"] = fighter_planes

            return forces

        except:
            logger.error("Failed to load units from " + filename)

    def generateMission(self, options):
        os.chdir(self.scenarios_dir)
        logger.info("Looking for mission files in " + os.getcwd())

        self.m.load_file(options["scenario_filename"])

        if not self.m.country("Combined Joint Task Forces Red") or not self.m.country("Combined Joint Task Forces Blue"):
            failure_msg = "You must include a CombinedJointTaskForcesBlue and CombinedJointTaskForcesRed unit in the scenario template.  See the instructions in " + self.scenarios_dir
            return {"success": False, "failure_msg": failure_msg}

        red_forces = self.getUnitsFromMiz(options["red_forces_filename"], "red")
        blue_forces = self.getUnitsFromMiz(options["blue_forces_filename"], "blue")

        # Add coalitions (we may be able to add CJTF here instead of requiring templates to have objects of those coalitions)
        self.m.coalition.get("red").add_country(dcs.countries.Russia())
        self.m.coalition.get("blue").add_country(dcs.countries.USA())

        self.m.add_picture_blue(self.assets_dir + '/briefing1.png')
        self.m.add_picture_blue(self.assets_dir + '/briefing2.png')



        # add zones to target mission
        zone_names = ["ALPHA", "BRAVO", "CHARLIE", "DELTA"]
        zone_flag = 101
        for zone_name in zone_names:
            for zone in self.m.triggers.zones():
                if zone.name == zone_name:
                    self.addZone(self.conflict_zones, self.RotorOpsZone(zone_name, zone_flag, zone.position, zone.radius))
                    zone_flag = zone_flag + 1


        for zone in self.m.triggers.zones():
            if zone.name.rfind("STAGING") >= 0:
                self.addZone(self.staging_zones, self.RotorOpsZone(zone.name, None, zone.position, zone.radius))
            elif zone.name.rfind("SPAWN") >= 0:
                self.addZone(self.spawn_zones, self.RotorOpsZone(zone.name, None, zone.position, zone.radius))


        blue_zones = self.staging_zones
        red_zones = self.conflict_zones
        if options["defending"]:
            blue_zones = self.conflict_zones
            red_zones = self.staging_zones
            #swap airport sides
            self.swapSides(options)



        #Populate Red zones with ground units
        for zone_name in red_zones:
            if red_forces["vehicles"]:
                    self.addGroundGroups(red_zones[zone_name], self.m.country('Combined Joint Task Forces Red'), red_forces["vehicles"], options["red_quantity"])

            #Add red FARPS
            if options["zone_farps"] != "farp_never" and not options["defending"]:
                RotorOpsGroups.VehicleTemplate.CombinedJointTaskForcesBlue.zone_farp(self.m, self.m.country('Combined Joint Task Forces Blue'),
                                                             self.m.country('Combined Joint Task Forces Blue'),
                                                              red_zones[zone_name].position,
                                                              180, zone_name + " FARP", late_activation=True)

            if options["zone_protect_sams"]:
                self.m.vehicle_group(
                    self.m.country('Combined Joint Task Forces Red'),
                    "Static " + zone_name + " Protection SAM",
                    random.choice(RotorOpsUnits.e_zone_sams),
                    red_zones[zone_name].position,
                    heading=random.randint(0, 359),
                    group_size=6,
                    formation=dcs.unitgroup.VehicleGroup.Formation.Star
                )



        #Populate Blue zones with ground units
        for zone_name in blue_zones:
            if blue_forces["vehicles"]:
                self.addGroundGroups(blue_zones[zone_name], self.m.country('Combined Joint Task Forces Blue'), blue_forces["vehicles"],
                                     options["blue_quantity"])
            #Add blue FARPS
            if options["zone_farps"] != "farp_never" and options["defending"]:
                RotorOpsGroups.VehicleTemplate.CombinedJointTaskForcesBlue.zone_farp(self.m, self.m.country('Combined Joint Task Forces Blue'),
                                                             self.m.country('Combined Joint Task Forces Blue'),
                                                              blue_zones[zone_name].position,
                                                              180, zone_name + " FARP", late_activation=False)

            #add logistics sites
            if options["crates"] and zone_name in self.staging_zones:
                RotorOpsGroups.VehicleTemplate.CombinedJointTaskForcesBlue.logistics_site(self.m, self.m.country('Combined Joint Task Forces Blue'),
                                                              blue_zones[zone_name].position,
                                                              180, zone_name)





            if options["zone_protect_sams"] and options["defending"]:
                vg = self.m.vehicle_group(
                    self.m.country('Combined Joint Task Forces Blue'),
                    "Static " + zone_name + " Protection SAM",
                    random.choice(RotorOpsUnits.e_zone_sams),
                    blue_zones[zone_name].position,
                    heading=random.randint(0, 359),
                    group_size=6,
                    formation=dcs.unitgroup.VehicleGroup.Formation.Star
                )


        #Add player slots
        self.addPlayerHelos(options)

        #Add AI Flights
        self.addFlights(options, red_forces, blue_forces)

        #Set the Editor Map View
        self.m.map.position = self.conflict_zones["ALPHA"].position
        self.m.map.zoom = 100000

        #add files and triggers necessary for RotorOps.lua script
        self.addResources(self.sound_directory, self.script_directory)
        self.scriptTriggerSetup(options)

        #Save the mission file
        os.chdir(self.output_dir)
        output_filename = options["scenario_filename"].removesuffix('.miz') + " " + time.strftime('%a%H%M%S') + '.miz'
        success = self.m.save(output_filename)
        return {"success": success, "filename": output_filename, "directory": self.output_dir} #let the UI know the result

    def addGroundGroups(self, zone, _country, groups, quantity):
        for a in range(0, quantity):

            group = random.choice(groups)
            unit_types = []
            for unit in group.units:
                if dcs.vehicles.vehicle_map[unit.type]:
                    unit_types.append(dcs.vehicles.vehicle_map[unit.type])
            country = self.m.country(_country.name)
            self.m.vehicle_group_platoon(
                country,
                zone.name + '-GND ' + str(a+1),
                unit_types,
                zone.position.random_point_within(zone.size / 1.2, 100),
                heading=random.randint(0, 359),
                formation=dcs.unitgroup.VehicleGroup.Formation.Scattered,
            )


    def getCoalitionAirports(self, side: str):
        coalition_airports = []
        primary_airport = None
        shortest_dist = 1000000
        for airport_name in self.m.terrain.airports:
            airportobj = self.m.terrain.airports[airport_name]
            if airportobj.coalition == str.upper(side):

                coalition_airports.append(airportobj)

                start = self.staging_zones[list(self.staging_zones)[0]]
                dist_from_start = dcs.mapping._distance(airportobj.position.x, airportobj.position.y, start.position.x, start.position.y)

                if dist_from_start < shortest_dist:
                    primary_airport = airportobj
                    shortest_dist = dist_from_start

        return coalition_airports, primary_airport

    def getParking(self, airport, aircraft, alt_airports=None, group_size=1):

        if len(airport.free_parking_slots(aircraft)) >= group_size:
            if not (aircraft.id in dcs.planes.plane_map and len(airport.runways) == 0):
                return airport
        for airport in alt_airports:
            if len(airport.free_parking_slots(aircraft)) >= group_size:
                if not (aircraft.id in dcs.planes.plane_map and len(airport.runways) == 0):
                    return airport

        logger.warn("No parking available for " + aircraft.id)
        return None

    #Find parking spots on FARPs and carriers
    def getUnitParking(self, aircraft):
        return


    def swapSides(self, options):

        #Swap airports

        blue_airports, primary_blue = self.getCoalitionAirports("blue")
        red_airports, primary_red = self.getCoalitionAirports("red")

        for airport in blue_airports:
            self.m.terrain.airports[airport.name].set_red()
        for airport in red_airports:
            self.m.terrain.airports[airport.name].set_blue()

        combinedJointTaskForcesBlue = self.m.country("Combined Joint Task Forces Blue")
        combinedJointTaskForcesRed = self.m.country("Combined Joint Task Forces Red")


        #Swap ships

        blue_ships = combinedJointTaskForcesBlue.ship_group.copy()
        red_ships = combinedJointTaskForcesRed.ship_group.copy()

        for group in blue_ships:
            group.points[0].tasks.append(dcs.task.OptROE(dcs.task.OptROE.Values.ReturnFire))
            combinedJointTaskForcesRed.add_ship_group(group)
            combinedJointTaskForcesBlue.ship_group.remove(group)


        for group in red_ships:
            combinedJointTaskForcesBlue.add_ship_group(group)
            combinedJointTaskForcesRed.ship_group.remove(group)



        #Swap statics

        blue_statics = combinedJointTaskForcesBlue.static_group.copy()
        red_statics = combinedJointTaskForcesRed.static_group.copy()

        for group in blue_statics:
            combinedJointTaskForcesBlue.static_group.remove(group)
            combinedJointTaskForcesRed.add_static_group(group)

        for group in red_statics:
            combinedJointTaskForcesRed.static_group.remove(group)
            combinedJointTaskForcesBlue.add_static_group(group)


        #Swap vehicles

        blue_vehicles = combinedJointTaskForcesBlue.vehicle_group.copy()
        red_vehicles = combinedJointTaskForcesRed.vehicle_group.copy()

        for group in blue_vehicles:
            combinedJointTaskForcesBlue.vehicle_group.remove(group)
            combinedJointTaskForcesRed.add_vehicle_group(group)

        for group in red_vehicles:
            combinedJointTaskForcesRed.vehicle_group.remove(group)
            combinedJointTaskForcesBlue.add_vehicle_group(group)


        #Swap planes

        blue_planes = combinedJointTaskForcesBlue.plane_group.copy()
        red_planes = combinedJointTaskForcesRed.plane_group.copy()

        for group in blue_planes:
            combinedJointTaskForcesBlue.plane_group.remove(group)
            combinedJointTaskForcesRed.add_plane_group(group)

        for group in red_planes:
            combinedJointTaskForcesRed.plane_group.remove(group)
            combinedJointTaskForcesBlue.add_plane_group(group)


        # Swap helicopters

        blue_helos = combinedJointTaskForcesBlue.helicopter_group.copy()
        red_helos = combinedJointTaskForcesRed.helicopter_group.copy()

        for group in blue_helos:
            combinedJointTaskForcesBlue.helicopter_group.remove(group)
            combinedJointTaskForcesRed.add_helicopter_group(group)

        for group in red_helos:
            combinedJointTaskForcesRed.helicopter_group.remove(group)
            combinedJointTaskForcesBlue.add_helicopter_group(group)


    def addPlayerHelos(self, options):
        client_helos = RotorOpsUnits.client_helos
        for helicopter in dcs.helicopters.helicopter_map:
            if helicopter == options["slots"]:
                client_helos = [dcs.helicopters.helicopter_map[helicopter]]

        #find friendly carriers and farps
        carrier = self.m.country("Combined Joint Task Forces Blue").find_ship_group(name="HELO_CARRIER")
        if not carrier:
            carrier = self.m.country("Combined Joint Task Forces Blue").find_ship_group(name="HELO_CARRIER_1")

        farp = self.m.country("Combined Joint Task Forces Blue").find_static_group("HELO_FARP")
        if not farp:
            farp = self.m.country("Combined Joint Task Forces Blue").find_static_group("HELO_FARP_1")

        friendly_airports, primary_f_airport = self.getCoalitionAirports("blue")

        heading = 0
        group_size = 1
        if len(client_helos) == 1:
            group_size = 2  #add a wingman if singleplayer

        for helotype in client_helos:
            if carrier:
                fg = self.m.flight_group_from_unit(self.m.country('Combined Joint Task Forces Blue'), "CARRIER " + helotype.id, helotype, carrier,
                                                   dcs.task.CAS, group_size=group_size)
            elif farp:
                fg = self.m.flight_group_from_unit(self.m.country('Combined Joint Task Forces Blue'), "FARP " + helotype.id, helotype, farp,
                                                   dcs.task.CAS, group_size=group_size)

                #invisible farps need manual unit placement for multiple units
                if farp.units[0].type == 'Invisible FARP':
                    fg.points[0].action = dcs.point.PointAction.FromGroundArea
                    fg.points[0].type = "TakeOffGround"
                    fg.units[0].position = fg.units[0].position.point_from_heading(heading, 30)
                    heading += 90
            else:
                fg = self.m.flight_group_from_airport(self.m.country('Combined Joint Task Forces Blue'), primary_f_airport.name + " " + helotype.id, helotype,
                                                          self.getParking(primary_f_airport, helotype), group_size=group_size)
            fg.units[0].set_client()
            fg.load_task_default_loadout(dcs.task.CAS)

            #setup wingman for single player
            if len(fg.units) == 2:
                fg.units[1].skill = dcs.unit.Skill.High


    class TrainingScenario():
        @staticmethod
        def random_orbit(rect: dcs.mapping.Rectangle):
            x1 = random.randrange(int(rect.bottom), int(rect.top))
            sy = rect.left
            y1 = random.randrange(int(sy), int(rect.right))
            heading = 90 if y1 < (sy + (rect.right - sy) / 2) else 270
            heading = random.randrange(heading - 20, heading + 20)
            race_dist = random.randrange(80 * 1000, 120 * 1000)
            return dcs.mapping.Point(x1, y1), heading, race_dist

        @staticmethod
        def perpRacetrack(enemy_heading, friendly_pt):
            heading = enemy_heading + random.randrange(70,110)
            race_dist = random.randrange(40 * 1000, 80 * 1000)
            center_pt = dcs.mapping.point_from_heading(friendly_pt.x, friendly_pt.y, enemy_heading - random.randrange(140, 220), 10000)
            pt1 = dcs.mapping.point_from_heading(center_pt[0], center_pt[1], enemy_heading - 90, random.randrange(20 * 1000, 40 * 1000))
            return dcs.mapping.Point(pt1[0], pt1[1]), heading, race_dist

    def addFlights(self, options, red_forces, blue_forces):
        combinedJointTaskForcesBlue = self.m.country(dcs.countries.CombinedJointTaskForcesBlue.name)
        combinedJointTaskForcesRed = self.m.country(dcs.countries.CombinedJointTaskForcesRed.name)
        friendly_airports, primary_f_airport = self.getCoalitionAirports("blue")
        enemy_airports, primary_e_airport = self.getCoalitionAirports("red")

        #find enemy carriers and farps
        carrier = self.m.country("Combined Joint Task Forces Red").find_ship_group(name="HELO_CARRIER")
        if not carrier:
            carrier = self.m.country("Combined Joint Task Forces Red").find_ship_group(name="HELO_CARRIER_1")

        farp = self.m.country("Combined Joint Task Forces Red").find_static_group("HELO_FARP")
        if not farp:
            farp = self.m.country("Combined Joint Task Forces Red").find_static_group("HELO_FARP_1")

        e_airport_heading = dcs.mapping.heading_between_points(
            friendly_airports[0].position.x, friendly_airports[0].position.y, enemy_airports[0].position.x, primary_e_airport.position.y
        )

        e_airport_distance = dcs.mapping._distance(
            primary_f_airport.position.x, primary_f_airport.position.y, primary_f_airport.position.x, primary_f_airport.position.y
        )


        if options["f_awacs"]:
            awacs_name = "AWACS"
            awacs_freq = 266
            #pos, heading, race_dist = self.TrainingScenario.random_orbit(orbit_rect)
            pos, heading, race_dist = self.TrainingScenario.perpRacetrack(e_airport_heading, primary_f_airport.position)
            awacs = self.m.awacs_flight(
                combinedJointTaskForcesBlue,
                awacs_name,
                plane_type=dcs.planes.E_3A,
                airport=self.getParking(primary_f_airport, dcs.planes.E_3A, friendly_airports),
                position=pos,
                race_distance=race_dist, heading=heading,
                altitude=random.randrange(4000, 5500, 100), frequency=awacs_freq)

            # AWACS Escort flight
            source_plane = None
            if blue_forces["fighter_planes"]:
                source_group = random.choice(blue_forces["fighter_planes"])
                source_plane = source_group.units[0]
                plane_type = source_plane.unit_type
            else:
                plane_type = dcs.countries.CombinedJointTaskForcesBlue.Plane.F_15C

            awacs_escort = self.m.escort_flight(
                combinedJointTaskForcesBlue, "AWACS Escort",
                plane_type,
                airport=self.getParking(primary_f_airport, plane_type, friendly_airports),
                group_to_escort=awacs,
                group_size=2)

            awacs_escort.points[0].tasks.append(dcs.task.OptROE(dcs.task.OptROE.Values.WeaponFree))

            if source_plane:
                for unit in awacs_escort.units:
                    unit.pylons = source_plane.pylons
                    unit.livery_id = source_plane.livery_id


            #add text to mission briefing with radio freq
            briefing = self.m.description_text() + "\n\n" + awacs_name + "  " + str(awacs_freq) + ".00 " + "\n"
            self.m.set_description_text(briefing)

        if options["f_tankers"]:
            t1_name = "Tanker KC_130 Basket"
            t1_freq = 253
            t1_tac = "61Y"
            t2_name = "Tanker KC_135 Boom"
            t2_freq = 256
            t2_tac = "101Y"
            #pos, heading, race_dist = self.TrainingScenario.random_orbit(orbit_rect)
            pos, heading, race_dist = self.TrainingScenario.perpRacetrack(e_airport_heading, primary_f_airport.position)
            refuel_net = self.m.refuel_flight(
                combinedJointTaskForcesBlue,
                t1_name,
                dcs.planes.KC130,
                airport=self.getParking(primary_f_airport, dcs.planes.KC130, friendly_airports),
                position=pos,
                race_distance=race_dist,
                heading=heading,
                altitude=random.randrange(4000, 5500, 100),
                start_type=dcs.mission.StartType.Warm,
                speed=750,
                frequency=t1_freq,
                tacanchannel=t1_tac)

            #pos, heading, race_dist = self.TrainingScenario.random_orbit(orbit_rect)
            pos, heading, race_dist = self.TrainingScenario.perpRacetrack(e_airport_heading, primary_f_airport.position)
            refuel_rod = self.m.refuel_flight(
                combinedJointTaskForcesBlue,
                t2_name,
                dcs.planes.KC_135,
                airport=self.getParking(primary_f_airport, dcs.planes.KC_135, friendly_airports),
                position=pos,
                race_distance=race_dist, heading=heading,
                altitude=random.randrange(4000, 5500, 100),
                start_type=dcs.mission.StartType.Warm,
                frequency=t2_freq,
                tacanchannel=t2_tac)

            #add text to mission briefing
            briefing = self.m.description_text() + "\n\n" + t1_name + "  " + str(t1_freq) + ".00  " + t1_tac + "\n" + t2_name + "  " + str(t2_freq) + ".00  " + t2_tac + "\n"
            self.m.set_description_text(briefing)

        def zone_attack(fg, airport):
            fg.set_skill(dcs.unit.Skill.High)
            fg.late_activation = True

            if options["defending"]:
                for zone_name in self.conflict_zones:
                    fg.add_waypoint(self.conflict_zones[zone_name].position, 1000)
            else:
                for zone_name in reversed(self.conflict_zones):
                    fg.add_waypoint(self.conflict_zones[zone_name].position, 1000)
            if hasattr(airport, 'runways'):
                fg.add_runway_waypoint(airport)
            if airport:
                fg.land_at(airport)
            fg.points[0].tasks.append(dcs.task.OptReactOnThreat(dcs.task.OptReactOnThreat.Values.EvadeFire))
            fg.points[0].tasks.append(dcs.task.OptROE(dcs.task.OptROE.Values.OpenFire))




        if options["e_attack_helos"]:
            source_helo = None
            if red_forces["attack_helos"]:
                source_group = random.choice(red_forces["attack_helos"])
                source_helo = source_group.units[0]
                helo_type = source_helo.unit_type
                group_size = len(source_group.units)
                if group_size > 2:
                    group_size = 2

            else:
                group_size = 2
                helo_type = random.choice(RotorOpsUnits.e_attack_helos)

            airport = self.getParking(primary_e_airport, helo_type, enemy_airports, group_size)

            if carrier:
                afg = self.m.flight_group_from_unit(
                    combinedJointTaskForcesRed,
                    "Enemy Attack Helicopters",
                    helo_type,
                    carrier,
                    maintask=dcs.task.CAS,
                    start_type=dcs.mission.StartType.Cold,
                    group_size=group_size)
                zone_attack(afg, carrier)

            elif farp:
                afg = self.m.flight_group_from_unit(
                    combinedJointTaskForcesRed,
                    "Enemy Attack Helicopters",
                    helo_type,
                    farp,
                    maintask=dcs.task.CAS,
                    start_type=dcs.mission.StartType.Cold,
                    group_size=group_size)
                zone_attack(afg, farp)

            elif airport:
                afg = self.m.flight_group_from_airport(
                    combinedJointTaskForcesRed,
                    "Enemy Attack Helicopters",
                    helo_type,
                    airport=airport,
                    maintask=dcs.task.CAS,
                    start_type=dcs.mission.StartType.Cold,
                    group_size=group_size)
                zone_attack(afg, airport)

            else:
                return

            if source_helo:
                for unit in afg.units:
                    unit.pylons = source_helo.pylons
                    unit.livery_id = source_helo.livery_id



        if options["e_attack_planes"]:
            source_plane = None
            if red_forces["attack_planes"]:
                source_group = random.choice(red_forces["attack_planes"])
                source_plane = source_group.units[0]
                plane_type = source_plane.unit_type
                group_size = len(source_group.units)
                if group_size > 2:
                    group_size = 2
            else:
                group_size = 2
                plane_type = random.choice(RotorOpsUnits.e_attack_planes)

            airport = self.getParking(primary_e_airport, plane_type, enemy_airports, group_size)
            if airport:
                afg = self.m.flight_group_from_airport(
                    combinedJointTaskForcesRed, "Enemy Attack Planes", plane_type,
                    airport=airport,
                    maintask=dcs.task.CAS,
                    start_type=dcs.mission.StartType.Cold,
                    group_size=group_size)
                zone_attack(afg, airport)

            if source_plane:
                for unit in afg.units:
                    unit.pylons = source_plane.pylons
                    unit.livery_id = source_plane.livery_id

        if options["e_transport_helos"]:
            source_helo = None
            if red_forces["transport_helos"]:
                source_group = random.choice(red_forces["transport_helos"])
                source_helo = source_group.units[0]
                helo_type = source_helo.unit_type
                group_size = len(source_group.units)
                if group_size > 2:
                    group_size = 2
            else:
                group_size = 1
                helo_type = random.choice(RotorOpsUnits.e_transport_helos)

            airport = self.getParking(primary_e_airport, helo_type, enemy_airports, group_size)
            if airport:
                afg = self.m.flight_group_from_airport(
                    combinedJointTaskForcesRed, "Enemy Transport Helicopters", helo_type,
                    airport=airport,
                    maintask=dcs.task.Transport,
                    start_type=dcs.mission.StartType.Cold,
                    group_size=group_size)
                afg.late_activation = True
                afg.units[0].skill = dcs.unit.Skill.Excellent

            if source_helo:
                for unit in afg.units:
                    unit.pylons = source_helo.pylons
                    unit.livery_id = source_helo.livery_id

    def scriptTriggerSetup(self, options):

        #get the boolean value from ui option and convert to lua string
        def lb(var):
            return str(options[var]).lower()

        game_flag = 100
        #Add the first trigger
        trig = dcs.triggers.TriggerOnce(comment="RotorOps Setup Scripts")
        trig.rules.append(dcs.condition.TimeAfter(1))
        trig.actions.append(dcs.action.DoScriptFile(self.scripts["mist_4_4_90.lua"]))
        trig.actions.append(dcs.action.DoScriptFile(self.scripts["Splash_Damage_2_0.lua"]))
        trig.actions.append(dcs.action.DoScriptFile(self.scripts["CTLD.lua"]))
        trig.actions.append(dcs.action.DoScriptFile(self.scripts["RotorOps.lua"]))
        script = ""
        script = ("--OPTIONS HERE!\n\n" +
            "RotorOps.CTLD_crates = " + lb("crates") + "\n\n" +
            "RotorOps.CTLD_sound_effects = true\n\n" +
            "RotorOps.force_offroad = " + lb("force_offroad") + "\n\n" +
            "RotorOps.voice_overs = " + lb("voiceovers") + "\n\n" +
            "RotorOps.zone_status_display = " + lb("game_display") + "\n\n" +
            "RotorOps.inf_spawn_messages = " + lb("inf_spawn_msgs") + "\n\n" +
            "RotorOps.inf_spawns_per_zone = " + lb("inf_spawn_qty") + "\n\n" +
            "RotorOps.apcs_spawn_infantry = " + lb("apc_spawns_inf") + " \n\n")
        if not options["smoke_pickup_zones"]:
            script = script + 'RotorOps.pickup_zone_smoke = "none"\n\n'
        trig.actions.append(dcs.action.DoScript(dcs.action.String((script))))
        self.m.triggerrules.triggers.append(trig)

        #Add the second trigger
        trig = dcs.triggers.TriggerOnce(comment="RotorOps Setup Zones")
        trig.rules.append(dcs.condition.TimeAfter(2))
        for s_zone in self.staging_zones:
            trig.actions.append(dcs.action.DoScript(dcs.action.String("RotorOps.stagingZone('" + s_zone + "')")))
        for c_zone in self.conflict_zones:
            zone_flag = self.conflict_zones[c_zone].flag
            trig.actions.append(dcs.action.DoScript(dcs.action.String("RotorOps.addZone('" + c_zone + "'," + str(zone_flag) + ")")))

        trig.actions.append(dcs.action.DoScript(dcs.action.String("RotorOps.setupConflict('" + str(game_flag) + "')")))

        self.m.triggerrules.triggers.append(trig)

        #Add the third trigger
        trig = dcs.triggers.TriggerOnce(comment="RotorOps Conflict Start")
        trig.rules.append(dcs.condition.TimeAfter(10))
        trig.actions.append(dcs.action.DoScript(dcs.action.String("RotorOps.startConflict(100)")))
        self.m.triggerrules.triggers.append(trig)

        #Add generic zone-based triggers
        for index, zone_name in enumerate(self.conflict_zones):
            z_active_trig = dcs.triggers.TriggerOnce(comment= zone_name + " Active")
            z_active_trig.rules.append(dcs.condition.FlagEquals(game_flag, index + 1))
            z_active_trig.actions.append(dcs.action.DoScript(dcs.action.String("--Add any action you want here!")))
            self.m.triggerrules.triggers.append(z_active_trig)

        #Zone protection SAMs
        if options["zone_protect_sams"]:
            for index, zone_name in enumerate(self.conflict_zones):
                z_sams_trig = dcs.triggers.TriggerOnce(comment="Deactivate " + zone_name + " SAMs")
                z_sams_trig.actions.append(dcs.action.DoScript(dcs.action.String("Group.destroy(Group.getByName('" + zone_name + " Protection SAM'))")))
                self.m.triggerrules.triggers.append(z_sams_trig)

        #Zone FARPS always
        if options["zone_farps"] == "farp_always" and not options["defending"]:
            for index, zone_name in enumerate(self.conflict_zones):
                if index > 0:
                    previous_zone = list(self.conflict_zones)[index - 1]
                    if not self.m.country("Combined Joint Task Forces Blue").find_group(previous_zone + " FARP Static"):
                        continue
                    z_farps_trig = dcs.triggers.TriggerOnce(comment="Activate " + previous_zone + " FARP")
                    z_farps_trig.rules.append(dcs.condition.FlagEquals(game_flag, index + 1))
                    z_farps_trig.actions.append(dcs.action.ActivateGroup(self.m.country("Combined Joint Task Forces Blue").find_group(previous_zone + " FARP Static").id))
                    #z_farps_trig.actions.append(dcs.action.SoundToAll(str(self.res_map['forward_base_established.ogg'])))
                    z_farps_trig.actions.append(dcs.action.DoScript(dcs.action.String(
                        "RotorOps.farpEstablished(" + str(index) + ")")))
                    self.m.triggerrules.triggers.append(z_farps_trig)


        #Zone FARPS conditional on staged units remaining
        if options["zone_farps"] == "farp_gunits" and not options["defending"]:
            for index, zone_name in enumerate(self.conflict_zones):
                if index > 0:
                    previous_zone = list(self.conflict_zones)[index - 1]
                    if not self.m.country("Combined Joint Task Forces Blue").find_group(previous_zone + " FARP Static"):
                        continue
                    z_farps_trig = dcs.triggers.TriggerOnce(comment= "Activate " + previous_zone + " FARP")
                    z_farps_trig.rules.append(dcs.condition.FlagEquals(game_flag, index + 1))
                    z_farps_trig.rules.append(dcs.condition.FlagIsMore(111, 20))
                    z_farps_trig.actions.append(dcs.action.DoScript(dcs.action.String("--The 100 flag indicates which zone is active.  The 111 flag value is the percentage of staged units remaining")))
                    z_farps_trig.actions.append(
                        dcs.action.ActivateGroup(self.m.country("Combined Joint Task Forces Blue").find_group(previous_zone + " FARP Static").id))
                    #z_farps_trig.actions.append(dcs.action.SoundToAll(str(self.res_map['forward_base_established.ogg'])))
                    z_farps_trig.actions.append(dcs.action.DoScript(dcs.action.String(
                        "RotorOps.farpEstablished(" + str(index) + ")")))
                    self.m.triggerrules.triggers.append(z_farps_trig)



        #Add attack helos triggers
        for index in range(options["e_attack_helos"]):
            random_zone_obj = random.choice(list(self.conflict_zones.items()))
            zone = random_zone_obj[1]
            z_weak_trig = dcs.triggers.TriggerOnce(comment=zone.name + " Attack Helo")
            z_weak_trig.rules.append(dcs.condition.FlagIsMore(zone.flag, 1))
            z_weak_trig.rules.append(dcs.condition.FlagIsLess(zone.flag, random.randrange(20, 90)))
            z_weak_trig.actions.append(dcs.action.DoScript(dcs.action.String("---Flag " + str(zone.flag) + " value represents the percentage of defending ground units remaining in zone. ")))
            z_weak_trig.actions.append(dcs.action.DoScript(dcs.action.String("RotorOps.spawnAttackHelos()")))
            self.m.triggerrules.triggers.append(z_weak_trig)

        #Add attack plane triggers
        for index in range(options["e_attack_planes"]):
            random_zone_obj = random.choice(list(self.conflict_zones.items()))
            zone = random_zone_obj[1]
            z_weak_trig = dcs.triggers.TriggerOnce(comment=zone.name + " Attack Plane")
            z_weak_trig.rules.append(dcs.condition.FlagIsMore(zone.flag, 1))
            z_weak_trig.rules.append(dcs.condition.FlagIsLess(zone.flag, random.randrange(20, 90)))
            z_weak_trig.actions.append(dcs.action.DoScript(dcs.action.String("---Flag " + str(zone.flag) + " value represents the percentage of defending ground units remaining in zone. ")))
            z_weak_trig.actions.append(dcs.action.DoScript(dcs.action.String("RotorOps.spawnAttackPlanes()")))
            self.m.triggerrules.triggers.append(z_weak_trig)

        #Add transport helos triggers
        for index in range(options["e_transport_helos"]):
            random_zone_index = random.randrange(1, len(self.conflict_zones))
            random_zone_obj = list(self.conflict_zones.items())[random_zone_index]
            zone = random_zone_obj[1]
            z_weak_trig = dcs.triggers.TriggerOnce(comment=zone.name + " Transport Helo")
            z_weak_trig.rules.append(dcs.condition.FlagEquals(game_flag, random_zone_index + 1))
            z_weak_trig.rules.append(dcs.condition.FlagIsLess(zone.flag, random.randrange(20, 100)))
            z_weak_trig.actions.append(dcs.action.DoScript(dcs.action.String(
                "---Flag " + str(game_flag) + " value represents the index of the active zone. ")))
            z_weak_trig.actions.append(dcs.action.DoScript(dcs.action.String("---Flag " + str(zone.flag) + " value represents the percentage of defending ground units remaining in zone. ")))
            z_weak_trig.actions.append(dcs.action.DoScript(dcs.action.String("RotorOps.spawnTranspHelos(8," + str(options["transport_drop_qty"]) + ")")))
            self.m.triggerrules.triggers.append(z_weak_trig)

        #Add game won/lost triggers
        trig = dcs.triggers.TriggerOnce(comment="RotorOps Conflict WON")
        trig.rules.append(dcs.condition.FlagEquals(game_flag, 99))
        trig.actions.append(dcs.action.DoScript(dcs.action.String("---Add an action you want to happen when the game is WON")))
        self.m.triggerrules.triggers.append(trig)

        trig = dcs.triggers.TriggerOnce(comment="RotorOps Conflict LOST")
        trig.rules.append(dcs.condition.FlagEquals(game_flag, 98))
        trig.actions.append(dcs.action.DoScript(dcs.action.String("---Add an action you want to happen when the game is LOST")))
        self.m.triggerrules.triggers.append(trig)


