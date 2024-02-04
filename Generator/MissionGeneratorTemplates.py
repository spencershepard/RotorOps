from MissionGenerator import directories
import os
import RotorOpsUtils
import dcs
import math
from os.path import exists

class Scenario:
    def __init__(self, path, name):
        self.path = path
        self.name = name
        self.description = ""
        # self.image_path = None
        self.map_name = None
        self.config = None
        self.downloadable = False
        self.tags = []
        self.rating = None
        self.rating_qty = None
        self.packageID = None
        self.local_rating = None
        self.author = "unknown"
        self.display_description = ""


    def applyConfig(self, config):
        self.config = config
        if 'description' in config:
            self.description = config["description"]
        if 'name' in config:
            self.name = config["name"]
        if 'map' in config:
            self.map_name = config["map"].lower()
        if 'tags' in config:
            for tag in config['tags']:
                self.tags.append(tag.lower())
        if 'author' in config:
            self.author = config["author"]


    def getConfigValue(self, key, default):
        if self.config and key in self.config:
            return self.config[key]
        else:
            return default


    def evaluateMiz(self):
        # check if we have the miz file
        if exists(self.path):
            self.exists = True
        else:
            self.exists = False
            return None

        source_mission = dcs.mission.Mission()
        source_mission.load_file(self.path)
        zones = source_mission.triggers.zones()
        conflict_zones = 0
        staging_zones = 0
        conflict_zone_size_sum = 0
        conflict_zone_distance_sum = 0
        spawn_zones = 0
        conflict_zone_positions = []
        #friendly_airports = source_mission.getCoalitionAirports("blue")
        #enemy_airports = source_mission.getCoalitionAirports("red")
        friendly_airports = True
        enemy_airports = True



        for zone in zones:
            if zone.name.rfind("STAGING") == 0:
                staging_zones += 1
            if zone.name == "ALPHA" or zone.name == "BRAVO" or zone.name == "CHARLIE" or zone.name == "DELTA":
                conflict_zones += 1
                conflict_zone_size_sum += zone.radius
                conflict_zone_positions.append(zone.position)
            if zone.name.rfind("_SPAWN") > 0:
                spawn_zones += 1
        if conflict_zones > 1:
            for index, position in enumerate(conflict_zone_positions):
                if index > 0:
                    conflict_zone_distance_sum += RotorOpsUtils.getDistance(conflict_zone_positions[index], conflict_zone_positions[index - 1])

        def validateTemplate():
            valid = True
            if len(staging_zones) < 1:
                valid = False
            if len(conflict_zones) < 1:
                valid = False
            if not friendly_airports:
                valid = False
            if not enemy_airports:
                valid = False
            return valid

        description = ""

        if self.rating:
            description = description + "Rated " + str(self.rating) + "/5 based on " + str(self.rating_qty) + " reviews!\n"

        if self.config:

            if 'name' in self.config and self.config["name"] is not None:
                description = description + '<h4>' + self.config["name"] + '</h4>'
            if 'description' in self.config and self.config["description"] is not None:
               description = description + self.config["description"] + "\n\n"

        if conflict_zones and staging_zones :
            average_zone_size = conflict_zone_size_sum / conflict_zones
            description = (
                description +
                "Map: " + source_mission.terrain.name + "\n" +
                "Conflict Zones: " + str(conflict_zones) + "\n" +
                "Staging Zones: " + str(staging_zones) + "\n" +
                "Average Zone Size: " + str(math.floor(average_zone_size)) + "m \n" +
                "Infantry Spawn Zones: " + str(spawn_zones) + "\n" +
                "Approx Distance: " + str(math.floor(RotorOpsUtils.convertMeterToNM(conflict_zone_distance_sum))) + "nm \n"
                #"Validity Check:" + str(validateTemplate())
                + "\n== BRIEFING ==\n\n"
                + source_mission.description_text()
             )
            if self.packageID:
                description = description + "\n\nScenario module ID: " + self.packageID
            self.display_description = description.replace("\n", "<br />")



class Forces:

    def __init__(self, path, filename, config=None):
        self.path = path
        self.filename = filename
        self.basename = filename.removesuffix('.miz')
        self.name = filename.removesuffix('.miz')
        self.author = "unknown"


        if config:
            if 'name' in config:
                self.name = config["name"]

            if 'author' in config:
                self.author = config["author"]

class Import:

    def __init__(self, path, filename, config=None):
        self.path = path
        self.filename = filename
        self.name = filename.removesuffix('.miz')
        self.author = "unknown"


        if config:
            if 'name' in config:
                self.name = config["name"]

            if 'author' in config:
                self.author = config["author"]
