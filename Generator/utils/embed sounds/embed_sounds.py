import dcs
import os

from tkinter import messagebox as mbox

mizfound = False
path = os.getcwd()
dir_list = os.listdir(path)
print("Looking for mission files in '", path, "' :")


for filename in dir_list:
    if filename.endswith(".miz") and not filename == "template_source.miz" and not filename.startswith("SoundsAdded"):
        mizfound = True
        print("Attempting to add sound files to: " + filename)
        m = dcs.mission.Mission()
        m.load_file(filename)

        # add all of our required sounds
        os.chdir("../sound/embedded")
        path = os.getcwd()
        sound_file_list = os.listdir(path)
        print("Attempting to add sound files from '", path, "' :")

        for soundfilename in sound_file_list:
            if soundfilename.endswith(".ogg"):
                print("Adding " + soundfilename)
                m.map_resource.add_resource_file(soundfilename)
                continue
            else:
                continue
        os.chdir("../../Generator")
        m.save("SoundsAdded_" + filename)

if not mizfound:
    print("No valid miz files found!")
    mbox.showerror('No Source Files Found', 'Error: Place your .miz files in this directory before running the application.')
