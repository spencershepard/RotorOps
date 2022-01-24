import math
import sys
import os
import dcs
import RotorOpsMission as ROps
import RotorOpsUtils

from PyQt5.QtWidgets import (
    QApplication, QDialog, QMainWindow, QMessageBox
)
from PyQt5 import QtGui
from MissionGeneratorUI import Ui_MainWindow

scenarios = []
forces_files = []

class Window(QMainWindow, Ui_MainWindow):


    def __init__(self, parent=None):
        super().__init__(parent)
        self.m = ROps.RotorOpsMission()
        self.setupUi(self)
        self.connectSignalsSlots()
        self.populateScenarios()
        self.populateForces()

        self.label.setPixmap(QtGui.QPixmap(self.m.assets_dir + "/background.PNG"))


    def connectSignalsSlots(self):
        # self.action_Exit.triggered.connect(self.close)
        # self.action_Find_Replace.triggered.connect(self.findAndReplace)
        # self.action_About.triggered.connect(self.about)
        self.action_generateMission.triggered.connect(self.generateMissionAction)
        self.action_scenarioSelected.triggered.connect(self.scenarioChanged)

    def populateScenarios(self):
        mizfound = False
        os.chdir(self.m.scenarios_dir)
        path = os.getcwd()
        dir_list = os.listdir(path)
        print("Looking for mission files in '", path, "' :")

        for filename in dir_list:
            if filename.endswith(".miz"):
                mizfound = True
                scenarios.append(filename)
                self.scenario_comboBox.addItem(filename)

    def populateForces(self):
        os.chdir(self.m.forces_dir)
        path = os.getcwd()
        dir_list = os.listdir(path)
        print("Looking for forces files in '", path, "' :")

        for filename in dir_list:
            if filename.endswith(".miz"):
                mizfound = True
                forces_files.append(filename)
                self.redforces_comboBox.addItem(filename)
                self.blueforces_comboBox.addItem(filename)


    def scenarioChanged(self):
        try:
            os.chdir(self.m.scenarios_dir)
            filename = scenarios[self.scenario_comboBox.currentIndex()]
            source_mission = dcs.mission.Mission()
            source_mission.load_file(filename)
            zones = source_mission.triggers.zones()
            conflict_zones = 0
            staging_zones = 0
            conflict_zone_size_sum = 0
            conflict_zone_distance_sum = 0
            spawn_zones = 0
            conflict_zone_positions = []
            for zone in zones:
                if zone.name == "STAGING":
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

            if conflict_zones and staging_zones :
                average_zone_size = conflict_zone_size_sum / conflict_zones
                self.description_textBrowser.setText(
                    "Map: " + source_mission.terrain.name + "\n" +
                    "Conflict Zones: " + str(conflict_zones) + "\n" +
                    "Average Zone Size " + str(math.floor(average_zone_size)) + "m \n" +
                    "Infantry Spawn Zones: " + str(spawn_zones) + "\n" +
                    "Approx Distance: " + str(math.floor(RotorOpsUtils.convertMeterToNM(conflict_zone_distance_sum))) + "nm \n"
                )
        except:
            self.description_textBrowser.setText("File error occured.")


    def generateMissionAction(self):
        red_forces_filename = forces_files[self.redforces_comboBox.currentIndex()]
        blue_forces_filename = forces_files[self.blueforces_comboBox.currentIndex()]
        scenario_filename = scenarios[self.scenario_comboBox.currentIndex()]

        success = self.m.generateMission(scenario_filename, red_forces_filename, blue_forces_filename, None)
        if success:
            print("Mission generated.")

    # def findAndReplace(self):
    #     dialog = FindReplaceDialog(self)
    #     dialog.exec()
    #
    # def about(self):
    #     QMessageBox.about(
    #         self,
    #         "About Sample Editor",
    #         "<p>A sample text editor app built with:</p>"
    #         "<p>- PyQt</p>"
    #         "<p>- Qt Designer</p>"
    #         "<p>- Python</p>",
    #     )

# class FindReplaceDialog(QDialog):
#     def __init__(self, parent=None):
#         super().__init__(parent)
#         loadUi("ui/find_replace.ui", self)




if __name__ == "__main__":
    app = QApplication(sys.argv)
    win = Window()
    win.show()
    sys.exit(app.exec())



