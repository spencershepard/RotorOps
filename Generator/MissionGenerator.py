import json
import yaml
import sys
import os

import RotorOpsMission as ROps
import RotorOpsUnits
import user
import logging

import requests
from packaging import version

from PyQt5.QtWidgets import (
    QApplication, QDialog, QMainWindow, QMessageBox, QCheckBox, QSpinBox, QSplashScreen, QFileDialog, QRadioButton,
    QInputDialog, QDialogButtonBox, QVBoxLayout, QLabel, QComboBox
)
from PyQt5 import QtGui
from PyQt5.QtGui import QPixmap, QFont
from PyQt5.QtCore import QObject, QEvent, Qt, QUrl
import resources # pyqt resource file

from MissionGeneratorUI import Ui_MainWindow

import qtmodern.styles
import qtmodern.windows

# UPDATE BUILD VERSION
maj_version = 1
minor_version = 3
patch_version = 2

modules_version = 2
modules_url = 'https://dcs-helicopters.com/user-files/modules/'
version_url = 'https://dcs-helicopters.com/app-updates/versions.yaml'
modules_map_url = 'https://dcs-helicopters.com/user-files/modules/module-map-v2.yaml'
ratings_url = 'https://dcs-helicopters.com/user-files/ratings.php'
allowed_paths = ['templates\\Scenarios\\downloaded', 'templates\\Forces\\downloaded', 'templates\\Imports\\downloaded']

user_files_url = 'https://dcs-helicopters.com/user-files/'
version_url = 'https://dcs-helicopters.com/app-updates/versioncheck.yaml'

#Setup logfile and exception handler
logger = logging.getLogger(__name__)
logging.basicConfig(filename='generator.log', encoding='utf-8', level=logging.DEBUG, format='%(asctime)s %(levelname)-8s %(message)s', datefmt='%Y-%m-%d %H:%M:%S')
handler = logging.StreamHandler(stream=sys.stdout)
logger.addHandler(handler)


class directories:
    home_dir = scenarios = forces = scripts = sound = output = assets = imports = user_datafile_path = scenarios_downloaded = scenarios_user = default_config = None

    @classmethod
    def find(cls):
        current_dir = os.getcwd()
        if os.path.basename(os.getcwd()) == "Generator":
            os.chdir("..")
        cls.home_dir = os.getcwd()
        cls.scenarios = cls.home_dir + "\\templates\\Scenarios"
        cls.forces_downloaded = cls.home_dir + "\\templates\\Forces\\downloaded"
        cls.forces_user = cls.home_dir + "\\templates\\Forces\\user"
        cls.scripts = cls.home_dir + "\\scripts"
        cls.sound = cls.home_dir + "\\sound\\embedded"
        cls.output = cls.home_dir + "\\MissionOutput"
        cls.assets = cls.home_dir + "\\assets"
        cls.imports_downloaded = cls.home_dir + "\\templates\\Imports\\downloaded"
        cls.imports_user = cls.home_dir + "\\templates\\Imports\\user"
        cls.user_datafile_path = cls.home_dir + "\\config\\user-data.yaml"
        cls.scenarios_downloaded = cls.scenarios + "\\downloaded"
        cls.scenarios_user = cls.scenarios + "\\user"
        cls.default_config = cls.home_dir + '\\config\\default-config.yaml'
        os.chdir(current_dir)

    @classmethod
    def createDirectories(cls):
        required_dirs = [cls.scenarios_user, cls.scenarios_downloaded, cls.imports_user, cls.imports_downloaded, cls.forces_user, cls.forces_downloaded, cls.output]
        for path in required_dirs:
            if not os.path.exists(path):
                os.makedirs(path)


directories.find()
directories.createDirectories()

import MissionGeneratorTemplates

def handle_exception(exc_type, exc_value, exc_traceback):
    if issubclass(exc_type, KeyboardInterrupt): #example of handling error subclasses
        sys.__excepthook__(exc_type, exc_value, exc_traceback)
        return

    QApplication.restoreOverrideCursor()
    logger.error("Uncaught exception", exc_info=(exc_type, exc_value, exc_traceback))
    msg = QMessageBox()
    msg.setWindowTitle("Uncaught exception")
    msg.setText("Oops, there was a problem.  Please check the log file for more details or post it in the RotorOps discord where some helpful people will have a look. \n\n" + str(exc_value))
    x = msg.exec_()


sys.excepthook = handle_exception


version_string = str(maj_version) + "." + str(minor_version) + "." + str(patch_version)
defenders_text = "Defending Forces:"
attackers_text = "Attacking Forces:"
ratings_json = None

logger.info("RotorOps v" + version_string)

# Try to set windows app ID to display taskbar icon properly
try:
    from ctypes import windll
    appid = 'RotorOps.MissionGenerator.' + version_string
    windll.shell32.SetCurrentProcessExplicitAppUserModelID(appid)
except ImportError:
    pass



class Window(QMainWindow, Ui_MainWindow):


    def __init__(self, parent=None):
        super().__init__(parent)

        if getattr(sys, 'frozen', False) and hasattr(sys, '_MEIPASS'):
            logger.info('running in a PyInstaller bundle')
            qtmodern.styles._STYLESHEET = directories.assets + '/style.qss'
            qtmodern.windows._FL_STYLESHEET = directories.assets + '/frameless.qss'
        else:
            logger.info('running in a normal Python process')

        self.userid = None
        self.scenarios_list = []
        self.scenario = None
        self.player_slots = []
        self.user_output_dir = None
        self.user_data = None
        self.forces_list = []
        self.imports_list = []

        self.user_data = self.loadUserData()

        self.setupUi(self)
        self.connectSignalsSlots()
        self.populateScenarios()
        self.populateForces()
        self.populateSlotSelection()
        self.getImports()

        # self.blue_forces_label.setText(attackers_text)
        # self.red_forces_label.setText(defenders_text)
        self.background_label.setPixmap(QtGui.QPixmap(directories.assets + "/rotorops-dkgray.png"))
        self.statusbar = self.statusBar()
        self.statusbar.setStyleSheet(
            "QStatusBar{padding-left:5px;}")
        self.version_label.setText("Version " + version_string)

        self.scenarioChanged()

        self.time_comboBox.addItem("Default Time")
        self.time_comboBox.addItem("Day")
        self.time_comboBox.addItem("Night")
        self.time_comboBox.addItem("Dusk")
        self.time_comboBox.addItem("Dawn")
        self.time_comboBox.addItem("Noon")
        self.time_comboBox.addItem("Random")


    def connectSignalsSlots(self):
        self.action_generateMission.triggered.connect(self.generateMissionAction)
        self.action_scenarioSelected.triggered.connect(self.scenarioChanged)
        self.action_defensiveModeChanged.triggered.connect(self.defensiveModeChanged)
        self.action_nextScenario.triggered.connect(self.nextScenario)
        self.action_prevScenario.triggered.connect(self.prevScenario)
        self.actionSave_Directory.triggered.connect(self.chooseSaveDir)
        self.action_slotChanged.triggered.connect(self.slotChanged)
        self.actionCaucasus.triggered.connect(self.filterMenuTouched)
        self.actionPersian_Gulf.triggered.connect(self.filterMenuTouched)
        self.actionMarianas.triggered.connect(self.filterMenuTouched)
        self.actionNevada.triggered.connect(self.filterMenuTouched)
        self.actionSyria.triggered.connect(self.filterMenuTouched)
        self.actionMultiplayer.triggered.connect(self.filterMenuTouched)
        self.actionSingle_Player.triggered.connect(self.filterMenuTouched)
        self.actionCo_Op.triggered.connect(self.filterMenuTouched)
        self.action_rateButton1.triggered.connect(self.rateButtonActionOne)
        self.action_rateButton2.triggered.connect(self.rateButtonActionTwo)
        self.action_rateButton3.triggered.connect(self.rateButtonActionThree)
        self.action_rateButton4.triggered.connect(self.rateButtonActionFour)
        self.action_rateButton5.triggered.connect(self.rateButtonActionFive)

    # Find the selected dropdown menu options and make a list of tags to filter for
    def tagsFromMenuOptions(self):
        tags = []
        maps = []
        if self.actionCaucasus.isChecked():
            maps.append('Caucasus')
        if self.actionPersian_Gulf.isChecked():
            maps.append('PersianGulf')
        if self.actionMarianas.isChecked():
            maps.append('Marianas')
        if self.actionNevada.isChecked():
            maps.append('Nevada')
        if self.actionSyria.isChecked():
            maps.append('Syria')

        if self.actionMultiplayer.isChecked():
            tags.append('MultiPlayer')
        if self.actionSingle_Player.isChecked():
            tags.append('SinglePlayer')
        if self.actionCo_Op.isChecked():
            tags.append('CoOp')

        return maps, tags


    def populateScenarios(self):

        QApplication.setOverrideCursor(Qt.WaitCursor)

        self.scenario_comboBox.clear()
        scenarios = []


        for path in [directories.scenarios_downloaded, directories.scenarios_user]:
            logger.info("Looking for mission files in " + path)
            os.chdir(path)
            module_folders = next(os.walk('.'))[1]

            for folder in module_folders:
                for filename in os.listdir(folder):
                    if filename.endswith(".miz"):
                        basename = filename.removesuffix('.miz')
                        mizpath = os.path.join(path, folder, filename)
                        # create scenario object
                        s = MissionGeneratorTemplates.Scenario(mizpath, basename)

                        #apply some properties if found in the downloads directory
                        if path == directories.scenarios_downloaded:
                            package_name = folder
                            s.downloadable = True
                            s.packageID = folder

                            if ratings_json:
                                for module in ratings_json:
                                    if module['package'] == folder:
                                        s.rating = module["avg_rating"]
                                        s.rating_qty = module["rating_count"]

                        config_file_path = os.path.join(path, folder, basename + '.yaml')
                        if os.path.exists(config_file_path):
                            config = self.loadScenarioConfig(config_file_path)
                            if config:
                                s.applyConfig(config)

                        # all the scenarios we can find
                        scenarios.append(s)

        #remove scenarios if they don't match filter criteria
        filter_maps, filter_tags = self.tagsFromMenuOptions()

        # remove scenarios if map not selected in menu
        for s in scenarios:
            if s.map_name and not s.map_name in filter_maps:
                scenarios.remove(s)

        # add scenarios if tags match
        if len(filter_tags) > 0:
            t_scenarios = []
            for s in scenarios:
                if s.tags: #if the config file has tags set
                    for tag in filter_tags:
                        if tag in s.tags:
                            t_scenarios.append(s)
                else: #add if no tags set
                    t_scenarios.append(s)
            scenarios = t_scenarios.copy()

        self.scenarios_list = sorted(scenarios, key=lambda x: x.name, reverse=False)

        for s in self.scenarios_list:
            self.scenario_comboBox.addItem(s.name)

            QApplication.restoreOverrideCursor()


    def filterMenuTouched(self):
        self.populateScenarios()
        # self.scenarioChanged() haven't tried yet

    def populateForces(self):
        self.forces_list = []

        for path in [directories.forces_downloaded, directories.forces_user]:
            logger.info("Looking for forces files in " + path)
            os.chdir(path)
            module_folders = next(os.walk('.'))[1]

            for folder in module_folders:
                for filename in os.listdir(folder):
                    if filename.endswith(".miz"):
                        basename = filename.removesuffix('.miz')
                        mizpath = os.path.join(path, folder, filename)
                        config_file_path = os.path.join(path, folder, basename + '.yaml')
                        if os.path.exists(config_file_path):
                            # create forces object with config
                            try:
                                config = yaml.safe_load(open(config_file_path))
                                f = MissionGeneratorTemplates.Forces(mizpath, filename, config)
                                self.forces_list.append(f)
                            except:
                                logger.error("Error in " + config_file_path)

                        else:
                            # create forces object without config
                            f = MissionGeneratorTemplates.Forces(mizpath, basename)
                            self.forces_list.append(f)

        self.forces_list = sorted(self.forces_list, key=lambda x: x.name, reverse=False)
        
        for forces in self.forces_list:
            self.redforces_comboBox.addItem(forces.name)
            self.blueforces_comboBox.addItem(forces.name)

    def getImports(self):
        self.imports_list = []

        for path in [directories.imports_downloaded, directories.imports_user]:
            logger.info("Looking for imports files in " + path)
            os.chdir(path)
            module_folders = next(os.walk('.'))[1]

            for folder in module_folders:
                for filename in os.listdir(folder):
                    if filename.endswith(".miz"):
                        basename = filename.removesuffix('.miz')
                        mizpath = os.path.join(path, folder, filename)
                        config_file_path = os.path.join(path, folder, basename + '.yaml')
                        if os.path.exists(config_file_path):
                            # create imports object with config
                            try:
                                config = yaml.safe_load(config_file_path)
                                f = MissionGeneratorTemplates.Import(mizpath, filename, config)
                                self.imports_list.append(f)
                            except:
                                logger.error("Error in " + config_file_path)

                        else:
                            # create imports object without config
                            f = MissionGeneratorTemplates.Import(mizpath, filename)
                            self.imports_list.append(f)

    def populateSlotSelection(self):
        self.slot_template_comboBox.addItem("Multiple Slots")
        for type in RotorOpsUnits.player_helos:
            self.slot_template_comboBox.addItem(type.id)
        self.slot_template_comboBox.addItem("None")

    def slotChanged(self):
        if self.slot_template_comboBox.currentIndex() == 0:
            sd = self.slotDialog(self)
            sd.exec_()
            if sd.helicopter_types:
                self.user_data["player_slots"] = sd.helicopter_types
                self.player_slots = sd.helicopter_types
                self.saveUserData()


    def defensiveModeChanged(self):
        print("defensive checkbox changed")

    def lockedSlot(self):
        return self.slot_template_comboBox.findText("Locked to Scenario")

    def loadScenarioConfig(self, filename):
        try:
            j = open(filename)
            config = yaml.safe_load(j)
            j.close()
            return config
        except yaml.parser.ParserError as e:
            logger.error("Unable to load configuration file. Invalid yaml: " + filename)
            return None
        except OSError as e:
            logger.error(e)
            return None


    def applyScenarioConfig(self, config):

        # reset some UI elements
        self.defense_checkBox.setEnabled(True)
        self.slot_template_comboBox.removeItem(self.lockedSlot())

        self.slot_template_comboBox.setEnabled(True)
        self.slot_template_comboBox.setCurrentIndex(0)

        try:
            if 'player_spawn' in config and config['player_spawn'] == "fixed":
                self.slot_template_comboBox.addItem("Locked to Scenario")
                self.slot_template_comboBox.setCurrentIndex(self.lockedSlot())
                self.slot_template_comboBox.setEnabled(False)

            if 'checkboxes' in config:
                for box in config['checkboxes']:
                    qobj = QObject.findChild(self, QCheckBox, box)
                    if qobj:
                        qobj.setChecked(config['checkboxes'][box])

            for box in QObject.findChildren(self, QCheckBox):
                if 'disable_checkboxes' in config and config['disable_checkboxes'] is not None and box.objectName() in config['disable_checkboxes']:
                    box.setEnabled(False)
                else:
                    box.setEnabled(True)

            if 'spinboxes' in config:
                for box in config['spinboxes']:
                    qobj = QObject.findChild(self, QSpinBox, box)
                    if qobj:
                        qobj.setValue(config['spinboxes'][box])

            for box in QObject.findChildren(self, QSpinBox):
                if 'disable_spinboxes' in config and config['disable_spinboxes'] is not None and box.objectName() in config['disable_spinboxes']:
                    box.setEnabled(False)
                else:
                    box.setEnabled(True)

            for button in QObject.findChildren(self, QRadioButton):
                if 'radiobuttons' in config and button.objectName() in config['radiobuttons']:
                    button.setChecked(True)

            for button in QObject.findChildren(self, QRadioButton):
                if 'disable_radiobuttons' in config and config['disable_radiobuttons'] is not None and button.objectName() in config['disable_radiobuttons']:
                    button.setEnabled(False)
                else:
                    button.setEnabled(True)

            if 'blue_forces' in config:
                for template in self.forces_list:
                    if template.basename == config['blue_forces']:
                        self.blueforces_comboBox.setCurrentIndex(self.blueforces_comboBox.findText(template.name))

            if 'red_forces' in config:
                for template in self.forces_list:
                    if template.basename == config['red_forces']:
                        self.redforces_comboBox.setCurrentIndex(self.redforces_comboBox.findText(template.name))

        except Exception as e:
            logger.error("Error loading config file: " + str(e))

    def loadUserData(self):
        prefs = {}
        if os.path.exists(directories.user_datafile_path):
            try:
                with open(directories.user_datafile_path, 'r') as pfile:
                    prefs = yaml.safe_load(pfile)
                    if "save_directory" in prefs:
                        self.user_output_dir = prefs["save_directory"]

                    if "player_slots" in prefs:
                        self.player_slots = prefs["player_slots"]

                    if "ratings" in prefs:
                        self.user_ratings = prefs["ratings"]
            except:
                logger.error("Could not load prefs.yaml")
        if not prefs:
            prefs = {}

        return prefs

    def saveUserData(self):
        with open(directories.user_datafile_path, 'w') as pfile:
            yaml.dump(self.user_data, pfile)

    def chooseSaveDir(self):
        dlg = QFileDialog()
        dlg.setFileMode(QFileDialog.Directory)

        if "save_directory" in self.user_data:
            dlg.setDirectory(self.user_data["save_directory"])

        if dlg.exec_():
            path = dlg.directory().absolutePath()
            if path:
                self.user_data["save_directory"] = path
                self.user_output_dir = path
                self.saveUserData()


    def scenarioChanged(self):
        if len(self.scenarios_list) <= 0:
            return

        QApplication.setOverrideCursor(Qt.WaitCursor)
        self.slot_template_comboBox.setCurrentIndex(0)

        self.scenario = self.scenarios_list[self.scenario_comboBox.currentIndex()]

        # reset generator options to default
        default_config = self.loadScenarioConfig(directories.default_config)
        self.applyScenarioConfig(default_config)

        if self.scenario.config:
            self.applyScenarioConfig(self.scenario.config)

        path = self.scenario.path.removesuffix(".miz") + ".jpg"
        if os.path.isfile(path):
            self.missionImage.setPixmap(QtGui.QPixmap(path))
        else:
            self.missionImage.setPixmap(QtGui.QPixmap(directories.assets + "/briefing1.png"))

        self.scenario.evaluateMiz()
        self.description_textBrowser.setText(self.scenario.description)

        QApplication.restoreOverrideCursor()

        rate_buttons = [
            self.rateButton1,
            self.rateButton2,
            self.rateButton3,
            self.rateButton4,
            self.rateButton5,
        ]

        # Star rating buttons
        star_full_ss = "border-image:url(:/images/star_full);"
        star_empty_ss = "border-image:url(:/images/star_empty);"

        for button in rate_buttons:
            button.setStyleSheet(star_empty_ss)


        if self.user_data and 'local_ratings' in self.user_data and self.scenario.path in self.user_data["local_ratings"]:
            user_rating = self.user_data['local_ratings'][self.scenario.path]
            for i in range(user_rating):
                rate_buttons[i].setStyleSheet(star_full_ss)

    def generateMissionAction(self):
        QApplication.setOverrideCursor(Qt.WaitCursor)

        red_forces = self.forces_list[self.redforces_comboBox.currentIndex()]
        blue_forces = self.forces_list[self.blueforces_comboBox.currentIndex()]
        scenario_name = self.scenario.name
        scenario_path = self.scenario.path

        credits = ("'" + scenario_name + "' mission template by " + self.scenario.author + "\n" +
                   "'" + red_forces.name + "' by " + red_forces.author + "\n" +
                   "'" + blue_forces.name + "' by " + blue_forces.author + "\n"
                   )

        objects = {
            "imports": self.imports_list,
        }

        data = {
                "objects": objects,
                "credits": credits,
                "scenario_file": scenario_path,
                "scenario_name": scenario_name,
                "red_forces_path": red_forces.path,
                "blue_forces_path": blue_forces.path,
                "red_quantity": self.redqty_spinBox.value(),
                "blue_quantity": self.blueqty_spinBox.value(),
                "inf_spawn_qty": self.inf_spawn_spinBox.value(),
                "apc_spawns_inf": self.apcs_spawn_checkBox.isChecked(),
                "e_attack_helos": self.e_attack_helos_spinBox.value(),
                "e_attack_planes": self.e_attack_planes_spinBox.value(),
                "crates": self.logistics_crates_checkBox.isChecked(),
                "f_awacs": self.awacs_checkBox.isChecked(),
                "f_tankers": self.tankers_checkBox.isChecked(),
                "voiceovers": self.voiceovers_checkBox.isChecked(),
                "force_offroad": self.scenario.getConfigValue("force_offroad", default=False),
                "game_display": self.game_status_checkBox.isChecked(),
                "defending": self.defense_checkBox.isChecked(),
                "slots": self.slot_template_comboBox.currentText(),
                "zone_farps": self.farp_buttonGroup.checkedButton().objectName(),
                "e_transport_helos": self.e_transport_helos_spinBox.value(),
                "transport_drop_qty": self.troop_drop_spinBox.value(),
                "smoke_pickup_zones": self.smoke_pickup_zone_checkBox.isChecked(),
                "player_slots": self.player_slots,
                "player_hotstart": self.hotstart_checkBox.isChecked(),
                "random_weather": self.random_weather_checkBox.isChecked(),
                "time": self.time_comboBox.currentText(),
                "start_trigger": self.scenario.getConfigValue("start_trigger", default=True),
                "end_trigger": self.scenario.getConfigValue("end_trigger", default=True),
                "farp_spawns": self.farp_spawn_checkBox.isChecked(),
                "staging_logistics_file": self.scenario.getConfigValue("staging_logistics_file", default=None),
                "zone_farp_file": self.scenario.getConfigValue("zone_farp_file", default=None),
                "defensive_farp_file": self.scenario.getConfigValue("defensive_farp_file", default=None),
                "logistics_farp_file": self.scenario.getConfigValue("logistics_farp_file", default=None),
                "zone_protect_file": self.scenario.getConfigValue("zone_protect_file", default=None),
                "script": self.scenario.getConfigValue("script", default=None),
                "advanced_defenses": self.advanced_defenses_checkBox.isChecked(),
                "red_cap": self.scenario.getConfigValue("red_cap", default=True),
                "blue_cap": self.scenario.getConfigValue("blue_cap", default=True),
                }

        logger.info("Generating mission with options:")
        logger.info(str(data))
        n = ROps.RotorOpsMission()
        result = n.generateMission(self, data)

        QApplication.restoreOverrideCursor()

        #display results
        if result["success"]:
            logger.info(result["filename"] + "'  successfully generated in " + result["directory"])
            self.statusbar.showMessage(result["filename"] + "'  successfully generated in " + result["directory"], 10000)
            msg = QMessageBox()
            msg.setWindowTitle("Mission Generated")
            msg.setText("Awesome, your mission is ready! It's located in this directory: \n" +
                        result["directory"] + "\n" +
                        "\n" +
                        "Next, you should use the DCS Mission Editor to fine tune unit placements.  Don't be afraid to edit the missions that this generator produces. \n" +
                        "\n" +
                        "There are no hidden script changes, everything is visible in the ME.  Triggers have been created to help you to add your own actions based on active zone and game status. \n" +
                        "\n" +
                        "Units can be changed or moved without issue.  Player slots can be changed or moved without issue (one per group though!) \n" +
                        "\n" +
                        "Don't forget, you can also create your own templates that can include any mission options, objects, or even scripts. \n" +
                        "\n" +
                        "Have fun! \n"
                        )
            x = msg.exec_()
        elif not result["success"]:
            logger.warning(result["failure_msg"])
            msg = QMessageBox()
            msg.setWindowTitle("Error")
            msg.setText(result["failure_msg"])
            x = msg.exec_()

    def prevScenario(self):
        self.scenario_comboBox.setCurrentIndex((self.scenario_comboBox.currentIndex() - 1))

    def nextScenario(self):
        self.scenario_comboBox.setCurrentIndex((self.scenario_comboBox.currentIndex() + 1))


    # works fine but no use for this currently
    # class myWebView(QDialog):
    #     def __init__(self, window, parent=None):
    #         QDialog.__init__(self, parent)
    #         vbox = QVBoxLayout(self)
    #
    #         self.webEngineView = QWebEngineView()
    #         self.webEngineView.load(QUrl('https://dcs-helicopters.com'))
    #
    #         vbox.addWidget(self.webEngineView)
    #
    #         self.setLayout(vbox)
    #
    #         self.setGeometry(600, 600, 700, 500)
    #         self.setWindowTitle('QWebEngineView')

    class slotDialog(QDialog):
        def __init__(self, window, parent=None):
            QDialog.__init__(self, parent)
            self.setWindowTitle("Multiplayer Slots")
            self.layout = QVBoxLayout()
            self.setWindowFlags(self.windowFlags() & ~Qt.WindowContextHelpButtonHint) # remove help button
            message = QLabel("Add your desired multiplayer slots here. \nIt is recommended to check placement in the \nMission Editor before flying your mission.\n")
            self.layout.addWidget(message)
            self.helicopter_types = None


            self.slot_qty = len(window.player_slots)
            self.window = window

            #self.populateBoxes()

            QBtn = QDialogButtonBox.Ok
            self.buttonBox = QDialogButtonBox(QBtn)
            self.addBtn = self.buttonBox.addButton("+", QDialogButtonBox.ActionRole)
            self.removeBtn = self.buttonBox.addButton("-", QDialogButtonBox.ActionRole)
            self.layout.addWidget(self.buttonBox)


            self.buttonBox.accepted.connect(self.accepted)
            self.buttonBox.rejected.connect(self.close)
            self.addBtn.clicked.connect(self.addSlotBox)
            self.removeBtn.clicked.connect(self.removeSlotBox)

            self.slot_boxes = []

            if "player_slots" in window.user_data:
                for index in range(0, len(window.user_data["player_slots"])):
                    self.addSlotBox()

            self.setLayout(self.layout)


        def populateBoxes(self):

            for index in range(0, self.slot_qty):
                self.slot_boxes.append(QComboBox())
                for type in RotorOpsUnits.player_helos:
                    self.slot_boxes[index].addItem(type.id)

            for index in range(0, self.slot_qty):
                self.layout.addWidget(self.slot_boxes[index])
                #self.slot_boxes[index].setCurrentIndex(self.slot_boxes[index].findText(self.window.user_data["player_slots"][index]))



        def addSlotBox(self):
            new_slot = QComboBox()
            self.slot_boxes.append(new_slot)
            self.layout.addWidget(new_slot)
            for helo_type in RotorOpsUnits.player_helos:
                new_slot.addItem(helo_type.id)

            slot_index = len(self.slot_boxes) - 1
            if "player_slots" not in self.window.user_data:
                new_slot.setCurrentIndex(0)
            elif slot_index < len(self.window.user_data["player_slots"]):
                new_slot.setCurrentIndex(new_slot.findText(self.window.user_data["player_slots"][slot_index]))
            return new_slot

        def removeSlotBox(self):
            last_index = len(self.slot_boxes) - 1
            self.layout.removeWidget(self.slot_boxes[last_index])
            self.slot_boxes.pop(last_index)

        def accepted(self):
            heli_types = []
            for box in self.slot_boxes:
                heli_types.append(box.currentText())
            self.helicopter_types = heli_types
            self.close()

    def rateScenario(self, rating):
        if "local_ratings" not in self.user_data:
            self.user_data["local_ratings"] = {}
        self.user_data["local_ratings"][self.scenario.path] = rating
        self.saveUserData()
        self.scenarioChanged()

        if not self.scenario.downloadable:
            return


        params = {}
        params["userid"] = self.userid
        params["package"] = self.scenario.packageID
        params["rating"] = rating
        QApplication.setOverrideCursor(Qt.WaitCursor)
        r = requests.get(ratings_url, allow_redirects=False, timeout=7, params=params)
        QApplication.restoreOverrideCursor()
        if r.status_code == 200:
            logger.info("Rating successfully submitted for " + self.scenario.packageID)
            msg = QMessageBox()
            msg.setWindowTitle("Success")
            msg.setText("Thank you for submitting a " + str(rating) + " star review for " + self.scenario.name + ".  If you have previously submitted a rating for this mission, it will be updated.")
            msg.setIcon(QMessageBox.Icon.Information)
            x = msg.exec_()

    def rateButtonActionOne(self):
        self.rateScenario(1)

    def rateButtonActionTwo(self):
        self.rateScenario(2)

    def rateButtonActionThree(self):
        self.rateScenario(3)

    def rateButtonActionFour(self):
        self.rateScenario(4)

    def rateButtonActionFive(self):
        self.rateScenario(5)



def checkVersion(splashscreen):


   try:
        r = requests.get(version_url, allow_redirects=False, timeout=7)
        v = yaml.safe_load(r.content)
        avail_build = v["version"]
        if version.parse(avail_build) > version.parse(version_string):
            logger.warning("New version available. Please update to available version " + v["version"])
            msg = QMessageBox()
            msg.setWindowTitle(v["title"])
            msg.setText(v["description"])
            msg.setIcon(QMessageBox.Icon.Information)
            x = msg.exec_()
        else:
            logger.info("Version check complete: running the latest version.")
   except:
        logger.error("Online version check failed.")



def loadModules(splashscreen):
    msg = QMessageBox()
    msg.setWindowTitle("Unable to connect to server")
    msg.setText(
        "We were unable to connect to the RotorOps server to download content.  This is a temporary problem, so please try again later.  If the problem persists, please get in touch via Discord.")

    try:
        r = requests.get(modules_map_url, allow_redirects=False, timeout=7)
        if not r.status_code == 200:
            logger.error("Could not retrieve the modules map.")
            x = msg.exec_()
            return
    except:
        logger.error("Failed to retrieve module map.")
        x = msg.exec_()
        return

    module_list = yaml.safe_load(r.content)
    files_success = []
    files_failed = []
    new_modules = []
    updated_modules = []
    outversioned_modules = []


    # Download scenarios files

    if module_list:

        for module in module_list:

            should_download = False
            new_module = False

            # only allow predefined paths
            dp = module_list[module]["path"]
            if dp not in allowed_paths:
                logger.warning("Invalid path for module: " + module)
                continue

            # check if local version already exists
            package_file_path = os.path.join(directories.home_dir, module_list[module]["path"], module, "package.yaml")

            if os.path.exists(package_file_path):
                pkg_file = yaml.safe_load(open(package_file_path))
            else:
                pkg_file = None

            # compare required generator version and actual version
            if 'requires' in module_list[module]:
                if module_list[module]['requires'] > modules_version:
                    name = 'unknown module'
                    if 'name' in module_list[module]:
                        name = module_list[module]['name']
                    outversioned_modules.append(name)
                    continue


            # compare local and remote versions
            if pkg_file and 'version' in pkg_file:
                local_version = pkg_file['version']

                if module_list[module]['version'] > local_version:
                    should_download = True

            else: # package file not found
                should_download = True
                new_module = True

            # delete modules with 'remove' dist property
            if 'dist' in module_list[module] and module_list[module]['dist'] == 'remove':
                for filename in module_list[module]["files"]:
                    module_dir = os.path.join(directories.home_dir, module_list[module]["path"], module)
                    file_path = os.path.join(module_dir, filename)
                    if os.path.exists(file_path):
                        try:
                            os.remove(file_path)
                            print("Removed module file: " + filename)
                        except:
                            logger.error("Error while trying to remove " + filename)
                continue

            # download files
            if should_download:
                logger.info("Updating module: " + module)
                module_dir = os.path.join(directories.home_dir, module_list[module]["path"], module)

                # download files in remote package
                for filename in module_list[module]["files"]:
                    broken_file = False
                    type_path = module_list[module]["type"]
                    splash.showMessage("Downloading " + filename + " ...", Qt.AlignHCenter | Qt.AlignTop, Qt.white)
                    app.processEvents()

                    url = modules_url + type_path + "/" + module + "/" + filename
                    try:
                        r = requests.get(url, allow_redirects=False, timeout=10)
                    except:
                        logger("Request for " + url + " failed.")
                        broken_file = True
                        break

                    if r and r.status_code == 200:
                        os.makedirs(module_dir, exist_ok=True)
                        file_path = os.path.join(module_dir, filename)
                        open(file_path, 'wb+').write(r.content)
                        files_success.append(filename)

                        # do some stuff for the dialog popup
                        if filename.endswith('.miz') and "name" in module_list[module]:
                            if new_module:
                                new_modules.append(module_list[module]["name"])
                            else:
                                updated_modules.append(module_list[module]["name"])
                    else:
                        broken_file = True
                        files_failed.append(filename)
                        logger.error("Download failed: " + filename)

                # create the local package file
                if not broken_file:
                    logger.info("Creating local package file for module " + module)
                    package = {}
                    package['version'] = module_list[module]['version']
                    with open(package_file_path, 'w+') as pfile:
                        yaml.dump(package, pfile)

    else:
        logger.error("Problem encountered with modules map.")

    # show a popup if we downloaded any packages
    if len(files_success) > 0 or len(files_failed) > 0 or len(outversioned_modules) > 0:
        if len(files_failed) > 0:
            fs = ""
            for filename in files_failed:
                fs = fs + filename + ','
            logger.error("Failed to add new files: " + fs)
        msg = QMessageBox()
        msg.setWindowTitle("Downloaded Files")
        message = ""
        if len(new_modules) > 0:
            message = message + "New modules added: \n\n"
            for name in new_modules:
                message = message + name + "\n"
        if len(updated_modules) > 0:
            message = message + "\nModules updated: \n"
            for name in updated_modules:
                message = message + name + "\n"
        if len(files_failed) > 0:
            message = message + "\n\n" + str(len(files_failed)) + " files failed."
        if len(outversioned_modules) > 0:
            message = message + "\n\n" + str(len(outversioned_modules)) + " modules did not download because you need an required update."
        msg.setText(message)
        x = msg.exec_()
    else:
        logger.info("All packages up to date.")

def getRatings(splashscreen):

    try:
        r = requests.get(ratings_url, allow_redirects=False, timeout=7)
        j = json.loads(r.text)
        # for entry in j:
        #     print(entry["package"])
        #     print(entry["avg_rating"])
        logger.info("Retrieved online package info.")
        return j
    except TimeoutError:
        logger.error("Online package info failed: connection timed out.")
    except ConnectionError:
        logger.error("Online package info failed: connection error.")
    except:
        logger.error("Online package info failed.")


class StatusTipFilter(QObject):
    def eventFilter(self, watched: QObject, event: QEvent) -> bool:
        if isinstance(event, QtGui.QStatusTipEvent):
            return True
        return super().eventFilter(watched, event)



if __name__ == "__main__":
 #   os.environ["QT_AUTO_SCREEN_SCALE_FACTOR"] = "1"
    app = QApplication(sys.argv)

    # Splash Screen and loading
    pixmap = QPixmap(directories.assets + "/splash.jpg")
    splash = QSplashScreen(pixmap)
    splash.show()

    font = splash.font()
    font.setPixelSize(14)
    splash.setFont(font)

    splash.showMessage("Checking registry...", Qt.AlignHCenter | Qt.AlignTop, Qt.white)
    userid = user.createUserKey()
    app.processEvents()

    splash.showMessage("Checking version...", Qt.AlignHCenter | Qt.AlignTop, Qt.white)
    checkVersion(splash)
    app.processEvents()

    splash.showMessage("Getting package info...", Qt.AlignHCenter | Qt.AlignTop, Qt.white)
    ratings_json = getRatings(splash)
    app.processEvents()

    splash.showMessage("Getting content...", Qt.AlignHCenter | Qt.AlignTop, Qt.white)
    loadModules(splash)
    app.processEvents()

    app.setWindowIcon(QtGui.QIcon(directories.assets + '/icon.ico'))
 #   QCoreApplication.setAttribute(QtCore.Qt.AA_DisableHighDpiScaling)
    win = Window()
    win.userid = userid
    splash.finish(win)

    win.generateButton.installEventFilter(StatusTipFilter(win)) #prevent button statustip from obscuring other messages
    qtmodern.styles.dark(app)
    mw = qtmodern.windows.ModernWindow(win)
    mw.show()

    # wv = win.myWebView(win)
    # wv.exec_()
    sys.exit(app.exec())
