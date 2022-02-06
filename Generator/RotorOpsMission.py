from tokenize import String

import dcs
import os
import random

import RotorOpsGroups
import RotorOpsUnits
import time


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
                self.m.map_resource.add_resource_file(filename)

        #add all of our lua scripts
        os.chdir(script_directory)
        path = os.getcwd()
        dir_list = os.listdir(path)
        # print("Files and directories in '", path, "' :")
        # print(dir_list)

        for filename in dir_list:
            if filename.endswith(".lua"):
                print("Adding script to mission: " + filename)
                self.scripts[filename] = self.m.map_resource.add_resource_file(filename)

    def getUnitsFromMiz(self, filename, side):
        forces = []
        os.chdir(self.home_dir)
        os.chdir(self.forces_dir + "/" + side)
        print("Looking for " + side + " Forces files in '", os.getcwd(), "' :")
        source_mission = dcs.mission.Mission()
        try:
            source_mission.load_file(filename)

            for country_name in source_mission.coalition.get(side).countries:
                country_obj = source_mission.coalition.get(side).countries[country_name]
                for vehicle_group in country_obj.vehicle_group:
                    forces.append(vehicle_group)
            return forces
        except:
            print("Failed to load units from " + filename)


    def generateMission(self, options):
        #get the template mission file

        os.chdir(self.scenarios_dir)
        print("Looking for mission files in '", os.getcwd(), "' :")

        self.m.load_file(options["scenario_filename"])

        if not self.m.country("Russia") or not self.m.country("USA"):
            failure_msg = "You must include a USA and Russia unit in the scenario template.  See the instructions in " + self.scenarios_dir
            return {"success": False, "failure_msg": failure_msg}


        red_forces = self.getUnitsFromMiz(options["red_forces_filename"], "red")
        blue_forces = self.getUnitsFromMiz(options["blue_forces_filename"], "blue")



        # add zones to target mission
        for zone in self.m.triggers.zones():
            if zone.name == "ALPHA":
                self.addZone(self.conflict_zones, self.RotorOpsZone("ALPHA", 101, zone.position, zone.radius))
            elif zone.name == "BRAVO":
                self.addZone(self.conflict_zones, self.RotorOpsZone("BRAVO", 102, zone.position, zone.radius))
            elif zone.name == "CHARLIE":
                self.addZone(self.conflict_zones, self.RotorOpsZone("CHARLIE", 103, zone.position, zone.radius))
            elif zone.name == "DELTA":
                self.addZone(self.conflict_zones, self.RotorOpsZone("DELTA", 104, zone.position, zone.radius))
            elif zone.name.rfind("STAGING") >= 0:
                self.addZone(self.staging_zones, self.RotorOpsZone(zone.name, None, zone.position, zone.radius))
            elif zone.name.rfind("SPAWN") >= 0:
                self.addZone(self.spawn_zones, self.RotorOpsZone(zone.name, None, zone.position, zone.radius))


        blue_zones = self.staging_zones
        red_zones = self.conflict_zones
        if options["defending"]:
            blue_zones = self.conflict_zones
            red_zones = self.staging_zones
            #swap airport sides
            blue_airports = self.getCoalitionAirports("blue")
            red_airports = self.getCoalitionAirports("red")
            for airport_name in blue_airports:
                self.m.terrain.airports[airport_name].set_red()
            for airport_name in red_airports:
                self.m.terrain.airports[airport_name].set_blue()


        #Populate Red zones with ground units
        for zone_name in red_zones:
            if red_forces:
                    self.addGroundGroups(red_zones[zone_name], self.m.country('Russia'), red_forces, options["red_quantity"])

            #Add blue FARPS
            if options["zone_farps"] != "farp_never" and not options["defending"]:
                RotorOpsGroups.VehicleTemplate.USA.invisible_farp(self.m, self.m.country('USA'),
                                                              red_zones[zone_name].position,
                                                              180, zone_name + " FARP", late_activation=True)

            if options["zone_protect_sams"]:
                self.m.vehicle_group(
                    self.m.country('Russia'),
                    "Static " + zone_name + " Protection SAM",
                    random.choice(RotorOpsUnits.e_zone_sams),
                    red_zones[zone_name].position,
                    heading=random.randint(0, 359),
                    group_size=6,
                    formation=dcs.unitgroup.VehicleGroup.Formation.Star
                )



        #Populate Blue zones with ground units
        for zone_name in blue_zones:
            if blue_forces:
                self.addGroundGroups(blue_zones[zone_name], self.m.country('USA'), blue_forces,
                                     options["blue_quantity"])

            #add logistics sites
            if options["crates"] and zone_name in self.staging_zones:
                RotorOpsGroups.VehicleTemplate.USA.logistics_site(self.m, self.m.country('USA'),
                                                              blue_zones[zone_name].position,
                                                              180, zone_name)





            if options["zone_protect_sams"] and options["defending"]:
                vg = self.m.vehicle_group(
                    self.m.country('USA'),
                    "Static " + zone_name + " Protection SAM",
                    random.choice(RotorOpsUnits.e_zone_sams),
                    blue_zones[zone_name].position,
                    heading=random.randint(0, 359),
                    group_size=6,
                    formation=dcs.unitgroup.VehicleGroup.Formation.Star
                )



        #Add player slots
        if options["slots"] == "Multiple Slots":
            self.addMultiplayerHelos()
        else:
            for helicopter in dcs.helicopters.helicopter_map:
                if helicopter == options["slots"]:
                    self.addSinglePlayerHelos(dcs.helicopters.helicopter_map[helicopter])

        #Add AI Flights
        self.addFlights(options)

        #Set the Editor Map View
        self.m.map.position = self.m.terrain.airports[self.getCoalitionAirports("blue")[0]].position
        self.m.map.zoom = 100000

        #add files and triggers necessary for RotorOps.lua script
        self.addResources(self.sound_directory, self.script_directory)
        self.scriptTriggerSetup(options)

        #Save the mission file
        print(self.m.triggers.zones())
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
            #pos1 = zone.position.point_from_heading(5, 200)
            #for i in range(0, quantity):
            self.m.vehicle_group_platoon(
                country,
                zone.name + '-GND ' + str(a+1),
                unit_types,
                zone.position.random_point_within(zone.size / 1.2, 100),
                #pos1.random_point_within(zone.size / 2.5, 100),
                heading=random.randint(0, 359),
                formation=dcs.unitgroup.VehicleGroup.Formation.Scattered,
            )


    def getCoalitionAirports(self, side: str):
        coalition_airports = []
        for airport_name in self.m.terrain.airports:
            airportobj = self.m.terrain.airports[airport_name]
            if airportobj.coalition == str.upper(side):
                coalition_airports.append(airport_name)
        return coalition_airports

    def getParking(self, airport, aircraft):
        slot = airport.free_parking_slot(aircraft)
        slots = airport.free_parking_slots(aircraft)
        if slot:
            return airport
        else:
            print("No parking available for " + aircraft.id + " at " + airport.name)
            return None

    #Find parking spots on FARPs and carriers
    def getUnitParking(self, aircraft):
        return


    def addSinglePlayerHelos(self, helotype):

        carrier = self.m.country("USA").find_ship_group(name="HELO_CARRIER")
        farp = self.m.country("USA").find_static_group("HELO_FARP")
        friendly_airports = self.getCoalitionAirports("blue")

        if carrier:
            fg = self.m.flight_group_from_unit(self.m.country('USA'), "CARRIER " + helotype.id, helotype, carrier, dcs.task.CAS, group_size=2)

        elif farp:
            fg = self.m.flight_group_from_unit(self.m.country('USA'), "FARP " + helotype.id, helotype, farp, dcs.task.CAS, group_size=2)
            fg.units[0].position = fg.units[0].position.point_from_heading(90, 30)

            # invisible farps need manual unit placement for multiple units
            if farp.units[0].type == 'Invisible FARP':
                fg.points[0].action = dcs.point.PointAction.FromGroundArea
                fg.points[0].type = "TakeOffGround"
                fg.units[0].position = fg.units[0].position.point_from_heading(0, 30)

        else:
            for airport_name in friendly_airports:
                fg = self.m.flight_group_from_airport(self.m.country('USA'), airport_name + " " + helotype.id, helotype,
                                                      self.getParking(self.m.terrain.airports[airport_name], helotype), group_size=2)
        fg.units[0].set_player()



    def addMultiplayerHelos(self):
        carrier = self.m.country("USA").find_ship_group(name="HELO_CARRIER")
        farp = self.m.country("USA").find_static_group("HELO_FARP")
        friendly_airports = self.getCoalitionAirports("blue")

        heading = 0
        for helotype in RotorOpsUnits.client_helos:
            if carrier:
                fg = self.m.flight_group_from_unit(self.m.country('USA'), "CARRIER " + helotype.id, helotype, carrier,
                                                   dcs.task.CAS, group_size=1)
            elif farp:
                fg = self.m.flight_group_from_unit(self.m.country('USA'), "FARP " + helotype.id, helotype, farp,
                                                   dcs.task.CAS, group_size=1)

                #invisible farps need manual unit placement for multiple units
                if farp.units[0].type == 'Invisible FARP':
                    fg.points[0].action = dcs.point.PointAction.FromGroundArea
                    fg.points[0].type = "TakeOffGround"
                    fg.units[0].position = fg.units[0].position.point_from_heading(heading, 30)
                    heading += 90
            else:
                for airport_name in friendly_airports:
                    fg = self.m.flight_group_from_airport(self.m.country('USA'), airport_name + " " + helotype.id, helotype,
                                                          self.getParking(self.m.terrain.airports[airport_name], helotype), group_size=1)
            fg.units[0].set_client()


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



    def addFlights(self, options):
        usa = self.m.country(dcs.countries.USA.name)
        russia = self.m.country(dcs.countries.Russia.name)
        friendly_airport = self.m.terrain.airports[self.getCoalitionAirports("blue")[0]]
        enemy_airport = self.m.terrain.airports[self.getCoalitionAirports("red")[0]]


        orbit_rect = dcs.mapping.Rectangle(
            int(friendly_airport.position.x), int(friendly_airport.position.y - 100 * 1000), int(friendly_airport.position.x - 100 * 1000),
            int(friendly_airport.position.y))



        if options["f_awacs"]:
            awacs_name = "AWACS"
            awacs_freq = 266
            pos, heading, race_dist = self.TrainingScenario.random_orbit(orbit_rect)
            awacs = self.m.awacs_flight(
                usa,
                awacs_name,
                plane_type=dcs.planes.E_3A,
                airport=self.getParking(friendly_airport, dcs.planes.E_3A),
                position=pos,
                race_distance=race_dist, heading=heading,
                altitude=random.randrange(4000, 5500, 100), frequency=awacs_freq)

            awacs_escort = self.m.escort_flight(
                usa, "AWACS Escort",
                dcs.countries.USA.Plane.F_15C,
                airport=self.getParking(friendly_airport, dcs.countries.USA.Plane.F_15C),
                group_to_escort=awacs,
                group_size=2)
            awacs_escort.load_loadout("Combat Air Patrol") #not working for f-15

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
            pos, heading, race_dist = self.TrainingScenario.random_orbit(orbit_rect)
            refuel_net = self.m.refuel_flight(
                usa,
                t1_name,
                dcs.planes.KC130,
                airport=self.getParking(friendly_airport, dcs.planes.KC130),
                position=pos,
                race_distance=race_dist,
                heading=heading,
                altitude=random.randrange(4000, 5500, 100),
                start_type=dcs.mission.StartType.Warm,
                speed=750,
                frequency=t1_freq,
                tacanchannel=t1_tac)

            pos, heading, race_dist = self.TrainingScenario.random_orbit(orbit_rect)
            refuel_rod = self.m.refuel_flight(
                usa,
                t2_name,
                dcs.planes.KC_135,
                airport=self.getParking(friendly_airport, dcs.planes.KC_135),
                position=pos,
                race_distance=race_dist, heading=heading,
                altitude=random.randrange(4000, 5500, 100),
                start_type=dcs.mission.StartType.Warm,
                frequency=t2_freq,
                tacanchannel=t2_tac)

            #add text to mission briefing
            briefing = self.m.description_text() + "\n\n" + t1_name + "  " + str(t1_freq) + ".00  " + t1_tac + "\n" + t2_name + "  " + str(t2_freq) + ".00  " + t2_tac + "\n"
            self.m.set_description_text(briefing)

        def zone_attack(fg, unit_type):
            fg.set_skill(dcs.unit.Skill.Random)
            fg.late_activation = True
            fg.points[0].tasks.append(dcs.task.OptROE(0))
            #fg.load_loadout(unit_type["loadout"])
            #task = dcs.task.CAS
            #loadout = dcs.planes.Su_25.loadout(task)
            #loadout = dcs.planes.Su_25.loadout_by_name("Ground Attack")
            #fg.load_task_default_loadout(task)
            #fg.load_loadout("Ground Attack")
            #fg.load_task_default_loadout(dcs.task.GroundAttack)

            #fg.load_loadout("2xB-13L+4xATGM 9M114")
            if options["defending"]:
                for zone_name in self.conflict_zones:
                    fg.add_waypoint(self.conflict_zones[zone_name].position, 1000)
            else:
                for zone_name in reversed(self.conflict_zones):
                    fg.add_waypoint(self.conflict_zones[zone_name].position, 1000)
            fg.add_runway_waypoint(enemy_airport)
            fg.land_at(enemy_airport)



        if options["e_attack_helos"]:
            helo = random.choice(RotorOpsUnits.e_attack_helos)
            afg = self.m.flight_group_from_airport(
                russia,
                "Enemy Attack Helicopters",
                helo,
                airport=enemy_airport,
                maintask=dcs.task.CAS,
                start_type=dcs.mission.StartType.Cold,
                group_size=2)
            zone_attack(afg, helo)

        if options["e_attack_planes"]:
            plane = random.choice(RotorOpsUnits.e_attack_planes)
            afg = self.m.flight_group_from_airport(
                russia, "Enemy Attack Planes", plane["type"],
               airport=enemy_airport,
               maintask=dcs.task.CAS,
               start_type=dcs.mission.StartType.Cold,
               group_size=2)
            zone_attack(afg, plane)


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
        trig.actions.append(dcs.action.DoScript(dcs.action.String((
            "--OPTIONS HERE!\n\n" +
            "RotorOps.CTLD_crates = " + lb("crates") + "\n\n" +
            "RotorOps.CTLD_sound_effects = true\n\n" +
            "RotorOps.force_offroad = " + lb("force_offroad") + "\n\n" +
            "RotorOps.voice_overs = " + lb("voiceovers") + "\n\n" +
            "RotorOps.zone_status_display = " + lb("game_display") + "\n\n" +
            "RotorOps.inf_spawn_messages = " + lb("inf_spawn_msgs") + "\n\n" +
            "RotorOps.inf_spawns_per_zone = " + lb("inf_spawn_qty") + "\n\n" +
            "RotorOps.apcs_spawn_infantry = " + lb("apc_spawns_inf") + " \n\n"))))
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
        if options["zone_farps"] == "farp_always" and not options["defending"] and index > 0:
            for index, zone_name in enumerate(self.conflict_zones):
                if index > 0:
                    previous_zone = list(self.conflict_zones)[index - 1]
                    if not self.m.country("USA").find_group(previous_zone + " FARP"):
                        continue
                    z_farps_trig = dcs.triggers.TriggerOnce(comment="Activate " + previous_zone + " FARP")
                    z_farps_trig.rules.append(dcs.condition.FlagEquals(game_flag, index + 1))
                    z_farps_trig.actions.append(dcs.action.ActivateGroup(self.m.country("USA").find_group(previous_zone + " FARP").id))
                    self.m.triggerrules.triggers.append(z_farps_trig)


        #Zone FARPS conditional on staged units remaining
        if options["zone_farps"] == "farp_gunits":
            for index, zone_name in enumerate(self.conflict_zones):
                if index > 0:
                    previous_zone = list(self.conflict_zones)[index - 1]
                    if not self.m.country("USA").find_group(previous_zone + " FARP"):
                        continue
                    z_farps_trig = dcs.triggers.TriggerOnce(comment= "Activate " + previous_zone + " FARP")
                    z_farps_trig.rules.append(dcs.condition.FlagEquals(game_flag, index + 1))
                    z_farps_trig.rules.append(dcs.condition.FlagIsMore(111, 20))
                    z_farps_trig.actions.append(dcs.action.DoScript(dcs.action.String("--The 100 flag indicates which zone is active.  The 111 flag value is the percentage of staged units remaining")))
                    z_farps_trig.actions.append(
                        dcs.action.ActivateGroup(self.m.country("USA").find_group(previous_zone + " FARP").id))
                    self.m.triggerrules.triggers.append(z_farps_trig)



        #Add attack helos triggers
        for index in range(options["e_attack_helos"]):
            random_zone_obj = random.choice(list(self.conflict_zones.items()))
            zone = random_zone_obj[1]
            z_weak_trig = dcs.triggers.TriggerOnce(comment=zone.name + " Attack Helo")
            z_weak_trig.rules.append(dcs.condition.FlagIsMore(zone.flag, 1))
            z_weak_trig.rules.append(dcs.condition.FlagIsLess(zone.flag, random.randrange(20, 90)))
            z_weak_trig.actions.append(dcs.action.DoScript(dcs.action.String("---Flag value represents the percentage of defending ground units remaining in zone. ")))
            z_weak_trig.actions.append(dcs.action.DoScript(dcs.action.String("RotorOps.spawnAttackHelos()")))
            self.m.triggerrules.triggers.append(z_weak_trig)

        #Add attack plane triggers
        for index in range(options["e_attack_planes"]):
            random_zone_obj = random.choice(list(self.conflict_zones.items()))
            zone = random_zone_obj[1]
            z_weak_trig = dcs.triggers.TriggerOnce(comment=zone.name + " Attack Plane")
            z_weak_trig.rules.append(dcs.condition.FlagIsMore(zone.flag, 1))
            z_weak_trig.rules.append(dcs.condition.FlagIsLess(zone.flag, random.randrange(20, 90)))
            z_weak_trig.actions.append(dcs.action.DoScript(dcs.action.String("---Flag value represents the percentage of defending ground units remaining in zone. ")))
            z_weak_trig.actions.append(dcs.action.DoScript(dcs.action.String("RotorOps.spawnAttackPlanes()")))
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


