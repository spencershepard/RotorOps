from tokenize import String

import dcs
import os
import random


class RotorOpsMission:

    conflict_zones = {}
    staging_zones = {}
    spawn_zones = {}
    scripts = {}
    conflict_defense = False


    def __init__(self):
        self.m = dcs.mission.Mission()
        self.friendly_airport = dcs.terrain.caucasus.Nalchik()
        os.chdir("../")
        self.home_dir = os.getcwd()
        self.scenarios_dir = self.home_dir + "\Generator\Battlefields"
        self.forces_dir = self.home_dir + "\Generator\Forces"
        self.script_directory = self.home_dir
        self.sound_directory = self.home_dir + "\sound\embedded"
        self.output_dir = self.home_dir + "\Generator\Output"
        self.assets_dir = self.home_dir + "\Generator/assets"


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
                print(filename)
                self.scripts[filename] = self.m.map_resource.add_resource_file(filename)

    def getUnitsFromMiz(self, filename):
        red_forces = []
        blue_forces = []
        os.chdir(self.home_dir)
        os.chdir(self.forces_dir)
        print("Looking for Forces files in '", os.getcwd(), "' :")
        source_mission = dcs.mission.Mission()
        source_mission.load_file(filename)

        for country_name in source_mission.coalition.get("red").countries:
            country_obj = source_mission.coalition.get("red").countries[country_name]
            for vehicle_group in country_obj.vehicle_group:
                red_forces.append(vehicle_group)
        for country_name in source_mission.coalition.get("blue").countries:
            country_obj = source_mission.coalition.get("blue").countries[country_name]
            for vehicle_group in country_obj.vehicle_group:
                blue_forces.append(vehicle_group)
        return {"red": red_forces, "blue": blue_forces}

    def generateMission(self, scenario_filename, red_forces_filename, blue_forces_filename, data):
        os.chdir(self.scenarios_dir)
        print("Looking for mission files in '", os.getcwd(), "' :")
        #sm = ROps.RotorOpsMission(dcs.terrain.caucasus.Nalchik)  # get rid of friendly airport req

        path = os.getcwd()
        dir_list = os.listdir(path)
        print("Looking for mission files in '", path, "' :")
        self.m.load_file(scenario_filename)

        red_forces = self.getUnitsFromMiz(red_forces_filename)["red"]
        blue_forces = self.getUnitsFromMiz(blue_forces_filename)["blue"]

        # create target mission
        # sm = ROps.RotorOpsMission("Output filename", source_mission.terrain, dcs.terrain.caucasus.Nalchik())  #we should use red/blue airports here

        # add zones to target mission
        print(self.m.triggers.zones())
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

        self.addResources(self.sound_directory, self.script_directory)
        self.scriptTriggerSetup()

        # for zone_key in self.conflict_zones:
        #     print(self.conflict_zones[zone_key].name)
        #     tz = self.m.triggers.add_triggerzone(self.conflict_zones[zone_key].position, self.conflict_zones[zone_key].size, name=self.conflict_zones[zone_key].name)
        #     print(tz.position)
        #
        # for s_zone in self.staging_zones:
        #     tz = self.m.triggers.add_triggerzone(self.staging_zones[s_zone].position,
        #                                          self.staging_zones[s_zone].size,
        #                                          name=self.staging_zones[s_zone].name)
        #    print(tz.position)

        #self.addPlayerHelos()
        os.chdir(self.output_dir)
        return self.m.save("RotorOpsGenerateMission.miz")


    def addPlayerHelos(self):
        fg = self.m.flight_group_from_airport(self.m.country("USA"), "Player Helos", dcs.helicopters.UH_1H, self.friendly_airport, group_size=2)
        fg.units[0].set_player()
        self.friendly_airport.set_coalition("blue")

    def addGroundUnits(self, zone, _country, unit_types):
        country = self.m.country(_country.name)
        pos1 = zone.position.point_from_heading(5, 500)
        self.m.vehicle_group(country, zone.name + ' Tgt', random.choice(unit_types), pos1)
        for i in range(1, 5):
            self.m.vehicle_group(
                country,
                zone.name + ' Tgt' + str(i),
                random.choice(unit_types),
                pos1.random_point_within(self.conflict_zone_size / 2, 500),
                random.randint(0, 359),
                random.randint(2, 6),
                dcs.unitgroup.VehicleGroup.Formation.Scattered
            )

    def scriptTriggerSetup(self):
        game_flag = 100
        #Add the first trigger
        mytrig = dcs.triggers.TriggerOnce(comment="RotorOps Setup Scripts")
        mytrig.rules.append(dcs.condition.TimeAfter(1))
        mytrig.actions.append(dcs.action.DoScriptFile(self.scripts["mist_4_4_90.lua"]))
        mytrig.actions.append(dcs.action.DoScriptFile(self.scripts["Splash_Damage_2_0.lua"]))
        mytrig.actions.append(dcs.action.DoScriptFile(self.scripts["CTLD.lua"]))
        mytrig.actions.append(dcs.action.DoScriptFile(self.scripts["RotorOps.lua"]))
        mytrig.actions.append(dcs.action.DoScript(dcs.action.String(("--OPTIONS HERE!\n\nRotorOps.CTLD_crates = false\n\nRotorOps.CTLD_sound_effects = true\n\nRotorOps.force_offroad = false\n\nRotorOps.voice_overs = true\n\nRotorOps.apcs_spawn_infantry = false \n\n"))))
        self.m.triggerrules.triggers.append(mytrig)

        #Add the second trigger
        mytrig = dcs.triggers.TriggerOnce(comment="RotorOps Setup Zones")
        mytrig.rules.append(dcs.condition.TimeAfter(2))
        for s_zone in self.staging_zones:
            mytrig.actions.append(dcs.action.DoScript(dcs.action.String("RotorOps.stagingZone('" + s_zone + "')")))
        for c_zone in self.conflict_zones:
            zone_flag = self.conflict_zones[c_zone].flag
            mytrig.actions.append(dcs.action.DoScript(dcs.action.String("RotorOps.addZone('" + c_zone + "'," + str(zone_flag) + ")")))

        mytrig.actions.append(dcs.action.DoScript(dcs.action.String("RotorOps.setupConflict('" + str(game_flag) + "')")))

        self.m.triggerrules.triggers.append(mytrig)

        #Add the third trigger
        mytrig = dcs.triggers.TriggerOnce(comment="RotorOps Conflict Start")
        mytrig.rules.append(dcs.condition.TimeAfter(10))
        mytrig.actions.append(dcs.action.DoScript(dcs.action.String("RotorOps.startConflict(100)")))
        self.m.triggerrules.triggers.append(mytrig)

        #Add all zone-based triggers
        for index, c_zone in enumerate(self.conflict_zones):

            z_active_trig = dcs.triggers.TriggerOnce(comment= c_zone + " Active")
            z_active_trig.rules.append(dcs.condition.FlagEquals(game_flag, index + 1))
            z_active_trig.actions.append(dcs.action.DoScript(dcs.action.String("--Add any action you want here!")))
            self.m.triggerrules.triggers.append(z_active_trig)

            zone_flag = self.conflict_zones[c_zone].flag
            z_weak_trig = dcs.triggers.TriggerOnce(comment= c_zone + " Weak")
            z_weak_trig.rules.append(dcs.condition.FlagIsMore(zone_flag, 10))
            z_weak_trig.rules.append(dcs.condition.FlagIsLess(zone_flag, 50))
            z_weak_trig.actions.append(dcs.action.DoScript(dcs.action.String("--Add any action you want here!\n\n--Flag value represents the percentage of defending ground units remaining. ")))
            self.m.triggerrules.triggers.append(z_weak_trig)

        #Add game won/lost triggers
        mytrig = dcs.triggers.TriggerOnce(comment="RotorOps Conflict WON")
        mytrig.rules.append(dcs.condition.FlagEquals(game_flag, 99))
        mytrig.actions.append(dcs.action.DoScript(dcs.action.String("---Add an action you want to happen when the game is WON")))
        self.m.triggerrules.triggers.append(mytrig)

        mytrig = dcs.triggers.TriggerOnce(comment="RotorOps Conflict LOST")
        mytrig.rules.append(dcs.condition.FlagEquals(game_flag, 98))
        mytrig.actions.append(dcs.action.DoScript(dcs.action.String("---Add an action you want to happen when the game is LOST")))
        self.m.triggerrules.triggers.append(mytrig)


