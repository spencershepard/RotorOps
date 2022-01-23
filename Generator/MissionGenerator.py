import sys
import os
import dcs
import RotorOpsMission
import RotorOpsUtils

from PyQt5.QtWidgets import (
    QApplication, QDialog, QMainWindow, QMessageBox
)
from PyQt5.uic import loadUi

from MissionGeneratorUI import Ui_MainWindow

scenarios = []

class Window(QMainWindow, Ui_MainWindow):


    def __init__(self, parent=None):
        super().__init__(parent)
        self.setupUi(self)
        self.connectSignalsSlots()
        self.populateScenarios()

    def doit(self):
        print(self.testvar)

    def connectSignalsSlots(self):
        # self.action_Exit.triggered.connect(self.close)
        # self.action_Find_Replace.triggered.connect(self.findAndReplace)
        # self.action_About.triggered.connect(self.about)
        self.action_generateMission.triggered.connect(self.generateMission)
        self.action_scenarioSelected.triggered.connect(self.scenarioChanged)
        print("connect stuff")

    def populateScenarios(self):
        mizfound = False
        path = os.getcwd()
        print("Mission generator directory '", path, "' :")
        os.chdir("Battlefields")
        path = os.getcwd()
        dir_list = os.listdir(path)
        print("Looking for mission files in '", path, "' :")

        for filename in dir_list:
            if filename.endswith(".miz"):
                mizfound = True
                scenarios.append(filename)
                self.scenario_comboBox.addItem(filename)



    def scenarioChanged(self):
        try:
            print(self.scenario_comboBox.currentIndex())
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
                        distance = RotorOpsUtils.getDistance(conflict_zone_positions[index], conflict_zone_positions[index - 1])
                        print("point" + str(conflict_zone_positions[index]))
                        print("distance:" + str(distance))
                print(len(conflict_zone_positions))

            if conflict_zones and staging_zones :
                average_zone_size = conflict_zone_size_sum / conflict_zones
                self.description_textBrowser.setText(
                    "Map: " + source_mission.terrain.name + "\n" +
                    "Conflict Zones: " + str(conflict_zones) + "\n" +
                    "Average Zone Size " + str(average_zone_size) + "\n" +
                    "Infantry Spawn Zones: " + str(spawn_zones) + "\n" +
                    "Total Distance: " + str(conflict_zone_distance_sum) + "nm \n"
                )
        except:
            self.description_textBrowser.setText("File error occured.")



    def generateMission(self):
        print(self.scenario_comboBox.currentIndex())
        print(scenarios[self.scenario_comboBox.currentIndex()])

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



