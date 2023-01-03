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



