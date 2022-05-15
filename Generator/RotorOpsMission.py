from tokenize import String

import dcs
import dcs.cloud_presets
import os
import random

import RotorOpsGroups
import RotorOpsUnits
import RotorOpsUtils
import RotorOpsConflict
import aircraftMods
from RotorOpsImport import ImportObjects
import time
from MissionGenerator import logger
from MissionGenerator import directories

jtf_red = "Combined Joint Task Forces Red"
jtf_blue = "Combined Joint Task Forces Blue"


class RotorOpsMission:

    def __init__(self):
        self.m = dcs.mission.Mission()

        self.conflict_zones = {}
        self.staging_zones = {}
        self.spawn_zones = {}
        self.all_zones = {}
        self.scripts = {}
        self.res_map = {}
        self.config = None  # not used
        self.imports = None

    class RotorOpsZone:
        def __init__(self, name: str, flag: int, position: dcs.point, size: int):
            self.name = name
            self.flag = flag
            self.position = position
            self.size = size

            self.player_helo_spawns = []
            self.base_position = position

    def getMission(self):
        return self.m

    def setConfig(self, config):
        self.config = config

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
                # print(filename)
                key = self.m.map_resource.add_resource_file(filename)
                self.res_map[filename] = key

        # add all of our lua scripts
        os.chdir(script_directory)
        path = os.getcwd()
        dir_list = os.listdir(path)
        # print("Files and directories in '", path, "' :")
        # print(dir_list)

        for filename in dir_list:
            if filename.endswith(".lua"):
                logger.info("Adding script to mission: " + filename)
                self.scripts[filename] = self.m.map_resource.add_resource_file(filename)

    def getUnitsFromMiz(self, file, side='both'):

        forces = {}
        vehicles = []
        attack_helos = []
        transport_helos = []
        attack_planes = []
        fighter_planes = []
        helicopters = []

        source_mission = dcs.mission.Mission()

        try:
            source_mission.load_file(file)
            if side == 'both':
                sides = ['red', 'blue']
            else:
                sides = [side]
            for side in sides:
                for country_name in source_mission.coalition.get(side).countries:
                    country_obj = source_mission.coalition.get(side).countries[country_name]
                    for vehicle_group in country_obj.vehicle_group:
                        vehicles.append(vehicle_group)
                    for helicopter_group in country_obj.helicopter_group:
                        helicopters.append(helicopter_group)
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
            forces["helicopters"] = helicopters

            return forces

        except:
            logger.error("Failed to load units from " + file)

    def generateMission(self, window, options):

        os.chdir(directories.scenarios)
        logger.info("Looking for mission files in " + os.getcwd())

        window.statusBar().showMessage("Loading scenario mission", 10000)

        # self.m.load_file(options["scenario_file"])

        # Bypass trig, triggrules, and triggers.  Then load triggers
        # manually.  We want to get our zones from the template mission, but leave the existing trigger actions and
        # conditions the same, since pydcs cannot yet handle some of them well.

        self.m.load_file(options["scenario_file"], True)
        self.m.triggers.load_from_dict(self.m.bypassed_triggers)

        # Create some 'empty' triggerrules so that we can maintain indexing when we merge dictionaries on save
        for rule in self.m.bypassed_trigrules:
            trig = dcs.triggers.TriggerOnce(comment="Empty " + str(rule))
            trig.rules.append(dcs.condition.TimeAfter(1))
            trig.actions.append(dcs.action.DoScript(dcs.action.String("Filler " + str(rule))))
            self.m.triggerrules.triggers.append(trig)

        # Add countries if they're missing
        if not self.m.country(jtf_red):
            self.m.coalition.get("red").add_country(dcs.countries.CombinedJointTaskForcesRed())
        if not self.m.country(jtf_blue):
            self.m.coalition.get("blue").add_country(dcs.countries.CombinedJointTaskForcesBlue())
        if not self.m.country(
                dcs.countries.UnitedNationsPeacekeepers.name):
            self.m.coalition.get("neutrals").add_country(dcs.countries.UnitedNationsPeacekeepers())
        if not self.m.country("Russia"):
            self.m.coalition.get("red").add_country(dcs.countries.Russia())
        if not self.m.country("USA"):
            self.m.coalition.get("blue").add_country(dcs.countries.USA())

        self.addMods()
        self.importObjects(options)

        red_forces = self.getUnitsFromMiz(options["red_forces_path"], "both")
        blue_forces = self.getUnitsFromMiz(options["blue_forces_path"], "both")

        # add images to briefing
        self.m.add_picture_blue(directories.assets + '/briefing1.png')
        self.m.add_picture_blue(directories.assets + '/briefing2.png')

        # get import objects for generic farps etc
        self.imports = options["objects"]["imports"]

        activated_farp = None
        defensive_farp = None
        logistics_farp = None
        logistics_base = None
        zone_protect = None

        for i in self.imports:
            if i.filename == ("FARP_ACTIVATED_ZONE.miz"):
                activated_farp = i.path
            if i.filename == ("FARP_DEFENSIVE_ZONE.miz"):
                defensive_farp = i.path
            if i.filename == ("FARP_LOGISTICS_ZONE.miz"):
                logistics_farp = i.path
            if i.filename == ("STAGING_LOGISTICS_BASE.miz"):
                logistics_base = i.path
            if i.filename == ("ZONE_ACTIVATED_DEFENSE.miz"):
                zone_protect = i.path

            # it's possible to have import templates with the same filename, but we will let the latest override others
        # todo: verify we have the required templates

        # add zones to target mission
        zone_names = ["ALPHA", "BRAVO", "CHARLIE", "DELTA"]
        zone_flag = 101
        for zone_name in zone_names:
            for zone in self.m.triggers.zones():
                if zone.name == zone_name:
                    self.addZone(self.conflict_zones,
                                 self.RotorOpsZone(zone_name, zone_flag, zone.position, zone.radius))
                    zone_flag = zone_flag + 1

        for zone in self.m.triggers.zones():
            self.addZone(self.all_zones, self.RotorOpsZone(zone.name, None, zone.position, zone.radius))
            if zone_name == "STAGING":
                self.addZone(self.staging_zones, self.RotorOpsZone(zone.name, None, zone.position, zone.radius))
                continue
            if zone.name.rfind("STAGING") >= 0:  # find additional staging zones
                self.addZone(self.staging_zones, self.RotorOpsZone(zone.name, None, zone.position, zone.radius))
            elif zone.name.rfind("SPAWN") >= 0:
                self.addZone(self.spawn_zones, self.RotorOpsZone(zone.name, None, zone.position, zone.radius))

        blue_zones = self.staging_zones
        red_zones = self.conflict_zones
        if options["defending"]:
            blue_zones = self.conflict_zones
            red_zones = self.staging_zones
            # swap airport sides
            self.swapSides(options)

        # Populate Red zones with ground units
        window.statusBar().showMessage("Populating units into mission...", 10000)
        start_type = dcs.mission.StartType.Cold
        if options["player_hotstart"]:
            start_type = dcs.mission.StartType.Warm

        # Adds vehicles as a single group (for easy late activation), and helicopters if enabled in settings
        # def addZoneFARP(_zone_name, country, file):
        #
        #     farp_flag = self.m.find_group(_zone_name)
        #
        #     if farp_flag:
        #         farp_position = farp_flag.units[0].position
        #         farp_heading = farp_flag.units[0].heading
        #     else:
        #         farp_position = self.all_zones[_zone_name].position
        #         farp_heading = 0
        #
        #     # Add the basic invisible farp object
        #     farp = self.m.farp(self.m.country(country), _zone_name + " FARP", farp_position,
        #                        hidden=False, dead=False,
        #                        farp_type=dcs.unit.InvisibleFARP)
        #
        #     # Use alternate template file if it has been defined in scenario config
        #     if options["zone_farp_file"]:
        #
        #         for i in imports:
        #             if i.filename.removesuffix('.miz') == options["zone_farp_file"]:
        #                 file = i.path
        #                 # if multiple files found, we want the latest file to override the first
        #
        #     i = ImportObjects(file)
        #     i.anchorByGroupName("ANCHOR")
        #     farp_group = i.copyVehiclesAsGroup(self.m, country, _zone_name + " FARP Static", farp_position,
        #                                        farp_heading)
        #     # Add client helicopters
        #     if options["farp_spawns"]:
        #         helicopter_groups = i.copyHelicopters(self.m, jtf_blue, "ZONE " + _zone_name + " EMPTY ", farp_position, farp_heading)
        #         for group in helicopter_groups:
        #             self.all_zones[_zone_name].player_helo_spawns.append(group)
        #
        #     return farp_group

        # # Adds statics, vehicles, and helicopters. Late activation is not possible
        # def addLogisticsZone(_zone_name, country, file, config_name, helicopters=False):
        #     flag = self.m.find_group(_zone_name)
        #     if flag:
        #         position = flag.units[0].position
        #         heading = flag.units[0].heading
        #     else:
        #         position = self.all_zones[_zone_name].position
        #         heading = 0
        #
        #     # Use alternate template file if it has been defined in scenario config
        #     if options[config_name]:
        #
        #         for i in imports:
        #             if i.filename.removesuffix('.miz') == options[config_name]:
        #                 file = i.path
        #                 # if multiple files found, we want the latest file to override the first
        #
        #     # Import statics and vehicles
        #     i = ImportObjects(file)
        #     i.anchorByGroupName("ANCHOR")
        #     i.copyStatics(self.m, country, _zone_name + " Logistics Zone",
        #                   position, heading)
        #     i.copyVehicles(self.m, country, _zone_name + " Logistics Zone",
        #                    position, heading)
        #
        #     # Add client helicopters
        #     if helicopters:
        #         helicopter_groups = i.copyHelicopters(self.m, jtf_blue, "ZONE " + _zone_name + " EMPTY ", position,
        #                                               heading)
        #         for group in helicopter_groups:
        #             self.all_zones[_zone_name].player_helo_spawns.append(group)

        # Adds statics, vehicles, and helicopters (if enabled).  Late activation is not possible.
        # def addDefensiveFARP(_zone_name, country, file):
        #
        #     farp_flag = self.m.find_group(_zone_name)
        #
        #     if farp_flag:
        #         farp_position = farp_flag.units[0].position
        #         farp_heading = farp_flag.units[0].heading
        #     else:
        #         farp_position = self.all_zones[_zone_name].position
        #         farp_heading = 0
        #
        #     # Add the basic invisible farp object
        #     farp = self.m.farp(self.m.country(country), _zone_name + " FARP", farp_position,
        #                        hidden=False, dead=False,
        #                        farp_type=dcs.unit.InvisibleFARP)
        #
        #     # Use alternate template file if it has been defined in scenario config
        #     if options["defensive_farp_file"]:
        #
        #         for i in imports:
        #             if i.filename.removesuffix('.miz') == options["defensive_farp_file"]:
        #                 file = i.path
        #                 # if multiple files found, we want the latest file to override the first
        #
        #     # Import statics and vehicles
        #     i = ImportObjects(file)
        #     i.anchorByGroupName("ANCHOR")
        #     i.copyStatics(self.m, country, _zone_name + " Logistics Zone",
        #                   farp_position, farp_heading)
        #     i.copyVehicles(self.m, country, _zone_name + " Logistics Zone",
        #                    farp_position, farp_heading)
        #
        #     # Import player helicopters
        #     if options["farp_spawns"]:
        #         helicopter_groups = i.copyHelicopters(self.m, jtf_blue, "ZONE " + _zone_name + " EMPTY ", farp_position,
        #                                               farp_heading)
        #         for group in helicopter_groups:
        #             self.all_zones[_zone_name].player_helo_spawns.append(group)

        for zone_name in red_zones:
            if red_forces["vehicles"]:
                self.addGroundGroups(red_zones[zone_name], self.m.country(jtf_red), red_forces["vehicles"],
                                     options["red_quantity"])

            if options["zone_farps"] != "farp_never" and not options["defending"]:
                helicopters = False
                if options["farp_spawns"]:
                    helicopters = True

                # Add red zone FARPS

                vehicle_group = self.addZoneBase(options, zone_name, jtf_blue,
                                                 file=activated_farp,
                                                 config_name="zone_farp_file",
                                                 copy_helicopters=helicopters,
                                                 helicopters_name="ZONE " + zone_name + " EMPTY",
                                                 heli_start_type=dcs.mission.StartType.Cold,
                                                 copy_vehicles=True,
                                                 vehicles_name=zone_name + " FARP Static",
                                                 copy_statics=False,
                                                 statics_names="",
                                                 vehicles_single_group=True,
                                                 trigger_name=zone_name + "_FARP",
                                                 trigger_radius=110
                                                 )
                vehicle_group.late_activation = True

            # For SAMs: Add vehicles as a single group (for easy late activation)
            if options["zone_protect_sams"]:
                sam_group = self.addZoneBase(options, zone_name, jtf_red,
                                             file=zone_protect,
                                             config_name="zone_protect_file",
                                             copy_vehicles=True,
                                             vehicles_name=zone_name + " Protect Static",
                                             vehicles_single_group=True
                                             )
                # farp_flag = self.m.find_group(zone_name)
                #
                # if farp_flag:
                #     farp_position = farp_flag.units[0].position
                #     farp_heading = farp_flag.units[0].heading
                # else:
                #     farp_position = self.all_zones[zone_name].position
                #     farp_heading = 0
                #
                # i = ImportObjects(zone_protect)
                # i.anchorByGroupName("ANCHOR")
                # farp_group = i.copyVehiclesAsGroup(self.m, jtf_red, "Static " + zone_name + " Protection SAM",
                #                                    farp_position,
                #                                    farp_heading)

        # Populate Blue zones with ground units
        for i, zone_name in enumerate(blue_zones):
            if blue_forces["vehicles"]:
                self.addGroundGroups(blue_zones[zone_name], self.m.country(jtf_blue), blue_forces["vehicles"],
                                     options["blue_quantity"])

            # Add blue zone FARPS (not late activated) for defensive mode
            if options["zone_farps"] != "farp_never" and options["defending"]:

                helicopters = False
                if options["farp_spawns"]:
                    helicopters = True

                if options["crates"] and i == len(blue_zones) - 1:
                    # add a logistics zone to the last conflict zone
                    # addLogisticsZone(zone_name, jtf_blue, logistics_farp, "logistics_farp_file", helicopters)
                    self.addZoneBase(options, zone_name, jtf_blue,
                                     file=logistics_farp,
                                     config_name="logistics_farp_file",
                                     copy_helicopters=helicopters,
                                     helicopters_name="ZONE " + zone_name + " LOGISTICS",
                                     heli_start_type=start_type,
                                     copy_vehicles=True,
                                     vehicles_name=zone_name + " Logistics FARP",
                                     copy_statics=True,
                                     statics_names=zone_name + " Logistics FARP",
                                     vehicles_single_group=False,
                                     trigger_name=zone_name + "_FARP",
                                     trigger_radius=110
                                     )
                else:
                    # addDefensiveFARP(zone_name, jtf_blue, defensive_farp)
                    self.addZoneBase(options, zone_name, jtf_blue,
                                     file=defensive_farp,
                                     config_name="defensive_farp_file",
                                     copy_helicopters=helicopters,
                                     helicopters_name="ZONE " + zone_name + " EMPTY",
                                     heli_start_type=dcs.mission.StartType.Cold,
                                     copy_vehicles=True,
                                     vehicles_name=zone_name + " Defensive FARP",
                                     copy_statics=True,
                                     statics_names=zone_name + " Defensive FARP",
                                     vehicles_single_group=False,
                                     trigger_name=zone_name + "_FARP",
                                     trigger_radius=110
                                     )

            # add main logistics base
            if options["crates"] and zone_name == "STAGING":
                # addLogisticsZone(zone_name, jtf_blue, logistics_base, "staging_logistics_file", helicopters=True)
                self.addZoneBase(options, zone_name, jtf_blue,
                                 file=logistics_base,
                                 config_name="staging_logistics_file",
                                 copy_helicopters=True,
                                 helicopters_name="ZONE " + zone_name + " LOGISTICS",
                                 heli_start_type=start_type,
                                 copy_vehicles=True,
                                 vehicles_name=zone_name + " Logistics Base",
                                 copy_statics=True,
                                 statics_names=zone_name + " Logistics Base",
                                 vehicles_single_group=False,
                                 trigger_name="STAGING_BASE",
                                 trigger_radius=170
                                 )

        # Add player slots
        window.statusBar().showMessage("Adding flights to mission...", 10000)
        if options["slots"] != "Locked to Scenario" and options["slots"] != "None":
            self.addPlayerHelos(options)

        # Add AI Flights
        self.addFlights(options, red_forces, blue_forces)

        # Set the Editor Map View
        self.m.map.position = self.conflict_zones["ALPHA"].position
        self.m.map.zoom = 100000

        # add files and triggers necessary for RotorOps.lua script

        window.statusBar().showMessage("Adding resources to mission...", 10000)
        self.addResources(directories.sound, directories.scripts)
        RotorOpsConflict.triggerSetup(self, options)

        # finalize the mission briefing
        briefing = self.m.description_text() + '## RotorOps Credits ##\n\n' + options["credits"]
        briefing = briefing + "\nFor more info on RotorOps, visit:  DCS-HELICOPTERS.COM"
        self.m.set_description_text(briefing)

        # set the weather and time

        if options["random_weather"]:
            # self.m.random_weather = True
            max = len(dcs.cloud_presets.CLOUD_PRESETS) - 1
            preset_name = list(dcs.cloud_presets.CLOUD_PRESETS)[random.randint(0, max)]
            cloud_preset = dcs.weather.CloudPreset.by_name(preset_name)
            self.m.weather.clouds_base = random.randrange(cloud_preset.min_base, cloud_preset.max_base)
            self.m.weather.clouds_preset = cloud_preset
            wind_dir = random.randrange(0, 359) + 180
            wind_speed = random.randrange(5, 10)
            self.m.weather.wind_at_ground.direction = (wind_dir + random.randrange(-90, 90) - 180) % 360
            self.m.weather.wind_at_ground.speed = wind_speed + random.randrange(-4, -1)
            self.m.weather.wind_at_2000.direction = (wind_dir + random.randrange(-90, 90) - 180) % 360
            self.m.weather.wind_at_2000.speed = wind_speed + random.randrange(-2, 2)
            self.m.weather.wind_at_8000.direction = (wind_dir + random.randrange(-90, 90) - 180) % 360
            self.m.weather.wind_at_8000.speed = wind_speed + random.randrange(-1, 10)

            logger.info("Cloud preset = " + cloud_preset.ui_name + ", ground windspeed = " + str(
                self.m.weather.wind_at_ground.speed))

        if options["time"] != "Default Time":
            self.m.random_daytime(options["time"].lower())

        # Save the mission file
        window.statusBar().showMessage("Saving mission...", 10000)
        if window.user_output_dir:
            output_dir = window.user_output_dir  # if user has set output dir
        else:
            output_dir = directories.output  # default dir
        os.chdir(output_dir)
        output_filename = options["scenario_name"] + " " + time.strftime('%a%H%M%S') + '.miz'

        # dcs.mission.save will use the bypassed trig, trigrules, and triggers.  Our goal is to leave the trigrules and
        # trig from the source mission untouched. See comments in self.m.load_file above

        #merge dictionaries
        self.m.bypassed_trig = self.m.triggerrules.trig() | self.m.bypassed_trig
        self.m.bypassed_trigrules = self.m.triggerrules.trigrules() | self.m.bypassed_trigrules

        self.m.bypassed_triggers = self.m.triggers.dict()

        success = self.m.save(output_filename)
        return {"success": success, "filename": output_filename, "directory": output_dir}  # let the UI know the result

    # Use the ImportObjects class to place farps and bases
    def addZoneBase(self, options, _zone_name, country, file, config_name=None, copy_helicopters=False,
                    helicopters_name="", heli_start_type=dcs.mission.StartType.Cold,
                    copy_vehicles=False, vehicles_name="", copy_statics=False, statics_names="",
                    vehicles_single_group=False, trigger_name=None, trigger_radius=110, farp=True):

        # look for a marker object to position the base at a position other than zone center
        flag = self.m.find_group(_zone_name)
        if flag:
            position = flag.units[0].position
            heading = flag.units[0].heading
            self.all_zones[_zone_name].base_position = position
        else:
            position = self.all_zones[_zone_name].position
            heading = 0

        if farp:
            farp = self.m.farp(self.m.country(country), _zone_name + " FARP",
                                position, hidden=True, dead=False, farp_type=dcs.unit.InvisibleFARP)

        # Add a trigger zone
        if trigger_name:
            self.m.triggers.add_triggerzone(position, trigger_radius, False, trigger_name)

        # Use alternate template file if it has been defined in scenario config
        if config_name and options[config_name]:

            for i in self.imports:
                if i.filename.removesuffix('.miz') == options[config_name]:
                    file = i.path
                    # if multiple files found, we want the latest file to override the first

        # Import statics and vehicles
        i = ImportObjects(file)
        i.anchorByGroupName("ANCHOR")

        if copy_statics:
            i.copyStatics(self.m, country, statics_names,
                          position, heading)
        vehicle_group = None
        if copy_vehicles:
            if vehicles_single_group:
                vehicle_group = i.copyVehiclesAsGroup(self.m, country, vehicles_name, position,
                                                      heading)
            else:
                i.copyVehicles(self.m, country, vehicles_name,
                               position, heading)

        # Add client helicopters and farp objects
        if copy_helicopters:
            helicopter_groups = i.copyHelicopters(self.m, jtf_blue, helicopters_name, position,
                                                  heading, heli_start_type)
            for group in helicopter_groups:
                self.all_zones[_zone_name].player_helo_spawns.append(group)

        return vehicle_group  # for setting properties such as late activation

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
                zone.name + '-GND ' + str(a + 1),
                unit_types,
                zone.position.random_point_within(zone.size / 1.3, 100),
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
                dist_from_start = dcs.mapping._distance(airportobj.position.x, airportobj.position.y, start.position.x,
                                                        start.position.y)

                if dist_from_start < shortest_dist:
                    primary_airport = airportobj
                    shortest_dist = dist_from_start

        return coalition_airports, primary_airport

    def getParking(self, airport, aircraft, alt_airports=None, group_size=1):

        if len(airport.free_parking_slots(aircraft)) >= group_size:
            if not (aircraft.id in dcs.planes.plane_map and (
                    len(airport.runways) == 0 or airport.runways[0].ils is None)):
                return airport

        if alt_airports:
            for airport in alt_airports:
                if len(airport.free_parking_slots(aircraft)) >= group_size:
                    if not (aircraft.id in dcs.planes.plane_map and len(airport.runways) == 0):
                        return airport

        logger.warn("No parking available for " + aircraft.id)
        return None

    # Find parking spots on FARPs and carriers
    def getUnitParking(self, aircraft):
        return

    def swapSides(self, options):

        # Swap airports

        blue_airports, primary_blue = self.getCoalitionAirports("blue")
        red_airports, primary_red = self.getCoalitionAirports("red")

        for airport in blue_airports:
            self.m.terrain.airports[airport.name].set_red()
        for airport in red_airports:
            self.m.terrain.airports[airport.name].set_blue()

        combinedJointTaskForcesBlue = self.m.country(jtf_blue)
        combinedJointTaskForcesRed = self.m.country(jtf_red)

        # Swap ships

        blue_ships = combinedJointTaskForcesBlue.ship_group.copy()
        red_ships = combinedJointTaskForcesRed.ship_group.copy()

        for group in blue_ships:
            group.points[0].tasks.append(dcs.task.OptROE(dcs.task.OptROE.Values.ReturnFire))
            combinedJointTaskForcesRed.add_ship_group(group)
            combinedJointTaskForcesBlue.ship_group.remove(group)

        for group in red_ships:
            combinedJointTaskForcesBlue.add_ship_group(group)
            combinedJointTaskForcesRed.ship_group.remove(group)

        # Swap statics

        blue_statics = combinedJointTaskForcesBlue.static_group.copy()
        red_statics = combinedJointTaskForcesRed.static_group.copy()

        for group in blue_statics:
            combinedJointTaskForcesBlue.static_group.remove(group)
            combinedJointTaskForcesRed.add_static_group(group)

        for group in red_statics:
            combinedJointTaskForcesRed.static_group.remove(group)
            combinedJointTaskForcesBlue.add_static_group(group)

        # Swap vehicles

        blue_vehicles = combinedJointTaskForcesBlue.vehicle_group.copy()
        red_vehicles = combinedJointTaskForcesRed.vehicle_group.copy()

        for group in blue_vehicles:
            combinedJointTaskForcesBlue.vehicle_group.remove(group)
            combinedJointTaskForcesRed.add_vehicle_group(group)

        for group in red_vehicles:
            combinedJointTaskForcesRed.vehicle_group.remove(group)
            combinedJointTaskForcesBlue.add_vehicle_group(group)

        # Swap planes

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
        unslotted_count = 0
        slotted_count = 0

        for helicopter in dcs.helicopters.helicopter_map:
            if helicopter == options["slots"]:
                client_helos = [dcs.helicopters.helicopter_map[
                                    helicopter]]  # if out ui slot option matches a specific helicopter type name

        # get loadouts from miz file and put into a simple dict
        default_loadouts = {}
        default_unit_groups = self.getUnitsFromMiz(directories.home_dir + "\\config\\blue_player_loadouts.miz", "blue")
        for helicopter_group in default_unit_groups["helicopters"]:
            default_loadouts[helicopter_group.units[0].unit_type.id] = {}
            default_loadouts[helicopter_group.units[0].unit_type.id]["pylons"] = helicopter_group.units[0].pylons
            default_loadouts[helicopter_group.units[0].unit_type.id]["livery_id"] = helicopter_group.units[0].livery_id
            default_loadouts[helicopter_group.units[0].unit_type.id]["fuel"] = helicopter_group.units[0].fuel

        # find friendly carriers and farps
        carrier = self.m.country(jtf_blue).find_ship_group(name="HELO_CARRIER")
        if not carrier:
            carrier = self.m.country(jtf_blue).find_ship_group(name="HELO_CARRIER_1")

        farp = self.m.country(jtf_blue).find_static_group("HELO_FARP")
        if not farp:
            farp = self.m.country(jtf_blue).find_static_group("HELO_FARP_1")
            heading = 0
        if farp:
            farp_heading = farp.units[0].heading
            heading = farp_heading

        friendly_airports, primary_f_airport = self.getCoalitionAirports("blue")


        group_size = 1
        player_helicopters = []
        if options["slots"] == "Multiple Slots":
            player_helicopters = options["player_slots"]
        else:
            player_helicopters.append(options["slots"])  # single helicopter type

        if len(client_helos) == 1:
            group_size = 2  # add a wingman if singleplayer

        # Hot/Cold start options
        start_type = dcs.mission.StartType.Cold
        start_type_string = ""
        start_type_point_type = "TakeOffGround"
        start_type_action = dcs.point.PointAction.FromGroundArea
        if options["player_hotstart"]:
            start_type = dcs.mission.StartType.Warm
            start_type_string = "HOT "
            start_type_point_type = "TakeOffGroundHot"
            start_type_action = dcs.point.PointAction.FromGroundAreaHot

        farp_helicopter_count = 1
        for helicopter_id in player_helicopters:
            fg = None
            helotype = None
            if helicopter_id in dcs.helicopters.helicopter_map:
                helotype = dcs.helicopters.helicopter_map[helicopter_id]
            else:
                continue
            if carrier:
                fg = self.m.flight_group_from_unit(self.m.country(jtf_blue),
                                                   "CARRIER " + start_type_string + helotype.id, helotype,
                                                   carrier,
                                                   dcs.task.CAS, group_size=group_size, start_type=start_type)

            elif farp and farp_helicopter_count <= 4:


                #old ugly FARPs, or single player groups with wingman require fg from unit
                if farp.units[0].type != 'Invisible FARP':
                    print("making flight group from unit")
                    fg = self.m.flight_group_from_unit(self.m.country(jtf_blue),
                                                       "FARP " + start_type_string + helotype.id, helotype, farp,
                                                       dcs.task.CAS, group_size=group_size, start_type=start_type)

                # invisible farps need manual unit placement for multiple units
                elif farp.units[0].type == 'Invisible FARP':
                    print("making standard flight group")
                    pos = farp.units[0].position.point_from_heading(heading, 20)
                    farp_helicopter_count = farp_helicopter_count + 1

                    fg = self.m.flight_group(self.m.country(jtf_blue), "FARP " + start_type_string + helotype.id,
                                         helotype, airport=None, position=pos, maintask=dcs.task.CAS, group_size=group_size, start_type=start_type)

                    fg.units[0].heading = farp_heading

                    if group_size > 1:
                        # move wingman if present
                        fg.units[1].position = farp.units[0].position.point_from_heading(180, 20)
                        fg.units[1].heading = farp_heading

                    # change heading for next helicopter placement
                    heading += 90

                # hot or cold start
                fg.points[0].action = start_type_action
                fg.points[0].type = start_type_point_type
            else:
                parking = self.getParking(primary_f_airport, helotype, friendly_airports,
                                          group_size=group_size)
                if parking:
                    fg = self.m.flight_group_from_airport(self.m.country(jtf_blue),
                                                          primary_f_airport.name + " " + start_type_string + helotype.id,
                                                          helotype,
                                                          parking, group_size=group_size, start_type=start_type)

            # if we were able to find a slot and create a flight group
            if fg:
                slotted_count = slotted_count + 1
                fg.units[0].set_client()
                # fg.load_task_default_loadout(dcs.task.CAS)
                if helotype.id in default_loadouts:
                    fg.units[0].pylons = default_loadouts[helotype.id]["pylons"]
                    fg.units[0].livery_id = default_loadouts[helotype.id]["livery_id"]
                    fg.units[0].fuel = default_loadouts[helotype.id]["fuel"]

                # setup wingman for single player
                if len(fg.units) == 2:
                    fg.units[1].skill = dcs.unit.Skill.High
                    fg.units[1].pylons = fg.units[0].pylons
                    fg.units[1].livery_id = fg.units[0].livery_id
                    fg.units[1].fuel = fg.units[0].fuel
            else:
                logger.warn("No parking available for " + helotype.id)
                unslotted_count = unslotted_count + 1

        if unslotted_count > 0:
            raise Exception("Player slots error: Unable to find parking for " + str(
                unslotted_count) + " players. Maximum parking slots found was " + str(slotted_count))

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
        def perpRacetrack(enemy_heading, friendly_pt, terrain):
            heading = enemy_heading + random.randrange(70, 110)
            race_dist = random.randrange(40 * 1000, 80 * 1000)
            center_pt = dcs.mapping.point_from_heading(friendly_pt.x, friendly_pt.y,
                                                       enemy_heading - random.randrange(140, 220), 10000)
            pt1 = dcs.mapping.point_from_heading(center_pt[0], center_pt[1], enemy_heading - 90,
                                                 random.randrange(20 * 1000, 40 * 1000))
            return dcs.mapping.Point(pt1[0], pt1[1], terrain), heading, race_dist

    def addFlights(self, options, red_forces, blue_forces):
        combinedJointTaskForcesBlue = self.m.country(dcs.countries.CombinedJointTaskForcesBlue.name)
        combinedJointTaskForcesRed = self.m.country(dcs.countries.CombinedJointTaskForcesRed.name)
        friendly_airports, primary_f_airport = self.getCoalitionAirports("blue")
        enemy_airports, primary_e_airport = self.getCoalitionAirports("red")

        # find enemy carriers and farps
        carrier = self.m.country(jtf_red).find_ship_group(name="HELO_CARRIER")
        if not carrier:
            carrier = self.m.country(jtf_red).find_ship_group(name="HELO_CARRIER_1")

        farp = self.m.country(jtf_red).find_static_group("HELO_FARP")
        if not farp:
            farp = self.m.country(jtf_red).find_static_group("HELO_FARP_1")

        e_airport_heading = dcs.mapping.heading_between_points(
            friendly_airports[0].position.x, friendly_airports[0].position.y, enemy_airports[0].position.x,
            primary_e_airport.position.y
        )

        e_airport_distance = dcs.mapping._distance(
            primary_f_airport.position.x, primary_f_airport.position.y, primary_f_airport.position.x,
            primary_f_airport.position.y
        )

        if options["f_awacs"]:
            awacs_name = "AWACS"
            awacs_freq = 266
            # pos, heading, race_dist = self.TrainingScenario.random_orbit(orbit_rect)
            pos, heading, race_dist = self.TrainingScenario.perpRacetrack(e_airport_heading, primary_f_airport.position,
                                                                          self.m.terrain)
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
                airport=self.getParking(primary_f_airport, plane_type, friendly_airports, group_size=2),
                group_to_escort=awacs,
                group_size=2)

            awacs_escort.points[0].tasks.append(dcs.task.OptROE(dcs.task.OptROE.Values.WeaponFree))

            if source_plane:
                for unit in awacs_escort.units:
                    unit.pylons = source_plane.pylons
                    unit.livery_id = source_plane.livery_id

            # add text to mission briefing with radio freq
            briefing = self.m.description_text() + "\n\n" + awacs_name + "  " + str(awacs_freq) + ".00 " + "\n"
            self.m.set_description_text(briefing)

        if options["f_tankers"]:
            t1_name = "Tanker KC_130 Basket"
            t1_freq = 253
            t1_tac = "61Y"
            t2_name = "Tanker KC_135 Boom"
            t2_freq = 256
            t2_tac = "101Y"
            # pos, heading, race_dist = self.TrainingScenario.random_orbit(orbit_rect)
            pos, heading, race_dist = self.TrainingScenario.perpRacetrack(e_airport_heading, primary_f_airport.position,
                                                                          self.m.terrain)
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

            # pos, heading, race_dist = self.TrainingScenario.random_orbit(orbit_rect)
            pos, heading, race_dist = self.TrainingScenario.perpRacetrack(e_airport_heading, primary_f_airport.position,
                                                                          self.m.terrain)
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

            # add text to mission briefing
            briefing = self.m.description_text() + "\n\n" + t1_name + "  " + str(
                t1_freq) + ".00  " + t1_tac + "\n" + t2_name + "  " + str(t2_freq) + ".00  " + t2_tac + "\n\n"
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
                    group_size=1)  # more than one spawn on top of each other, setting group size to one for now
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

            if source_helo and afg:
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

    def importObjects(self, data):

        imports = data["objects"]["imports"]

        for side in "red", "blue", "neutrals":
            coalition = self.m.coalition.get(side)
            for country_name in coalition.countries:
                for group in self.m.country(country_name).static_group:
                    prefix = "IMPORT-"
                    if group.name.find(prefix) == 0:
                        if group.units[0].name.find('IMPORT-') == 0:
                            logger.error(
                                group.units[
                                    0].name + " IMPORT group's unit name cannot start with 'IMPORT'.  Check the scenario template.")
                            raise Exception("Scenario file error: " + group.units[
                                0].name + " IMPORT group's unit name cannot start with 'IMPORT'")

                        # trim the groupname to our filename convention
                        filename = group.name.removeprefix(prefix)
                        i = filename.find('-')
                        if i > 8:
                            filename = filename[0:i]
                            print(filename)

                        for imp in imports:
                            if imp.filename == (filename + ".miz"):
                                i = ImportObjects(imp.path)
                                i.anchorByGroupName("ANCHOR")
                                new_statics, new_vehicles, new_helicopters = i.copyAll(self.m, country_name,
                                                                                       group.units[0].name,
                                                                                       group.units[0].position,
                                                                                       group.units[0].heading)

                                break

    def addMods(self):
        dcs.helicopters.helicopter_map["UH-60L"] = aircraftMods.UH_60L
        self.m.country(jtf_blue).helicopters.append(aircraftMods.UH_60L)
