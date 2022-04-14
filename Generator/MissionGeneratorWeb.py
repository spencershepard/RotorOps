from PyQt5.QtWidgets import QMessageBox

from MissionGenerator import directories, build, logger
import requests
import yaml
import os

modules_url = 'https://dcs-helicopters.com/user-files/modules/'
version_url = 'https://dcs-helicopters.com/app-updates/versions.yaml'
modules_map_url = 'https://dcs-helicopters.com/user-files/modules/modules.yaml'

def checkVersion(self):
    try:
        r = requests.get(version_url, allow_redirects=False, timeout=3)
        v = yaml.safe_load(r.content)
        print(v["build"])
        avail_build = v["build"]
        if avail_build > build:
            msg = QMessageBox()
            msg.setWindowTitle(v["title"])
            msg.setText(v["description"])
            x = msg.exec_()
    except TimeoutError:
        logger.error("Online version check failed: connection timed out.")
    except ConnectionError:
        logger.error("Online version check failed: connection error.")
    except:
        logger.error("Online version check failed.")



# def loadOnlineContent(self):
#     url = user_files_url + 'directory.yaml'
#     r = requests.get(url, allow_redirects=False)
#     user_files = yaml.safe_load(r.content)
#     count = 0
#
#     # Download scenarios files
#     os.chdir(directories.scenarios)
#     if user_files["scenarios"]["files"]:
#         for filename in user_files["scenarios"]["files"]:
#             url = user_files_url + user_files["scenarios"]["dir"] + '/' + filename
#             r = requests.get(url, allow_redirects=False)
#             open(filename, 'wb').write(r.content)
#             count = count + 1
#
#     # Download blue forces files
#     os.chdir(directories.forces + '/blue')
#     if user_files["forces_blue"]["files"]:
#         for filename in user_files["forces_blue"]["files"]:
#             url = user_files_url + user_files["forces_blue"]["dir"] + '/' + filename
#             r = requests.get(url, allow_redirects=False)
#             open(filename, 'wb').write(r.content)
#             count = count + 1
#
#     # Download red forces files
#     os.chdir(directories.forces + '/red')
#     if user_files["forces_red"]["files"]:
#         for filename in user_files["forces_red"]["files"]:
#             url = user_files_url + user_files["forces_red"]["dir"] + '/' + filename
#             r = requests.get(url, allow_redirects=False)
#             open(filename, 'wb').write(r.content)
#             count = count + 1
#
#     # Download imports files
#     os.chdir(directories.imports)
#     if user_files["imports"]["files"]:
#         for filename in user_files["imports"]["files"]:
#             url = user_files_url + user_files["imports"]["dir"] + '/' + filename
#             r = requests.get(url, allow_redirects=False)
#             open(filename, 'wb').write(r.content)
#             count = count + 1
#
#     msg = QMessageBox()
#     msg.setWindowTitle("Downloaded Files")
#     msg.setText("We've downloaded " + str(count) + " new files!")
#     x = msg.exec_()

# class Module:
#
#     def __init__(self, remote_dir, local_dir):
#         self.remote_dir = remote_dir
#         self.local_dir = local_dir
#
#     @classmethod
#     def createFromFile(cls):


