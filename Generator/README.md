# Install a development environment

## Install VSCode

Download and install VSCode: https://code.visualstudio.com/

VS Code is a free, open source, cross-platform code editor.  It is a great tool for editing and debugging python code.  It also has a built-in terminal that can be used to run commands.
## Install python 

If using VSCode, you can install the Python extension to get started: [VS Marketplace Link](https://marketplace.visualstudio.com/items?itemName=ms-python.python)

If not, you may need to install python 3.8.5.  If you are using Windows, you can download it here: https://www.python.org/downloads/release/python-385/

## Create a python virtual environment

If using VSCode, you can use the ">Python: create environment" command.

If not, run the following command in the root of the project: `python -m venv .\Generator\venv`

## Install python dependencies

If using VSCode, you can use the ">Run task: " command and choose the "Install the Python requirements" task.

If not, type `install-requirements.bat` in a terminal.

## Build the mission generator

If using VSCode, you can use the ">Run task: " command and choose the "Build the Mission Generator" task.

If not, type `build.bat` in a terminal.

## Run the mission generator

Using VS Code, you can use the provided launch configuration to run the mission generator.  

Otherwise, you can run the following command in a terminal: `python .\Generator\MissionGenerator.py`	

# Building the exe with build.bat

**Use build.bat to compile the UI files and build the exe.**
The steps are provided below for reference:

## build UI files
pyuic5 -x MissionGeneratorUI.ui -o MissionGeneratorUI.py  

## build resources 
pyrcc5 -o resources.py resources.qrc

## build exe
pyinstaller MissionGenerator.spec --distpath ..\ -i='assets\icon.ico' 


# Adding update to auto-installer

**Merging into the main branch now triggers a deployment action that automatically performs the actions below when significant files are changed (defined in '.change-monitored').**

**Significant files moved/deleted are not supported and may cause issues with the deployment script**

**Version must be incremented in version.py.  Only maj/min version is compared at app startup, so changes to supporting files can be made by incrementing the patch version.**


Files currently live at https://dcs-helicopters.com/app-updates

1) Add new files to /updates folder
2) Update updatescript.ini:

example:

    releases{
        1.1.1
        1.1.2
        1.2.0
    }

    release:1.1.1{
        
    }

    release:1.1.2{
        DownloadFile:MissionGenerator.exe
    }

    release:1.2.0{
        DownloadFile:MissionGenerator.exe
        DownloadFile:RotorOps.lua,scripts\
        DownloadFile:Splash_Damage_2_0.lua,scripts\
    }

3) Update versioncheck.yaml

example:
    --- 
    title: "Update Available"
    description: "UPDATE AVAILABLE:  Please run the included updater utility (RotorOps_updater.exe) to get the latest version."
    version: "1.2.0"

# Building new RotorOps_setup.exe installer package

Uses https://installforge.net/
See install-config.ifp and installforge_constants.txt

# Adding/updating downloadable modules

** Templates now live in their own repo and there is a deployment action to automatically perform the steps below **

Currently lives at https://dcs-helicopters.com/modules
1) Add new folder to remote directory, ie modules/forces
2) Trigger an update to templates by incrementing version in it's .yaml config file
3) Run server/user-files/modules/mapscript.py



