![alt text](https://dcs-helicopters.com/images/briefing1.png?raw=true)

# What is RotorOps?
RotorOps is a mission generator and gameplay script for DCS: World.  At its heart is a game type called Conflict, which requires helicopter operations to win battles on the ground.  This is a territory-capture game that promotes focus on individual 'conflict zones'.

At the core of the RotorOps script are AI enhancements that provide a dynamic ground war by causing automatic conflicts between ground forces and a progression of the front line.

![alt text](https://dcs-helicopters.com/images/RotorOps%20v1%20UI.png?raw=true)


# Key Features:
- Unique helicopter-focused gameplay.

- Mission Generator windows app.

- Over 100 built-in voiceovers (or for use in mission customization via trigger actions).

- Splash Damage 2 script for more realistic explosions that no longer require direct hits.

- CTLD troop and logistics transport automatically integrated and enhanced with sound effects.

- Play the role of the attacking or defending force.

- Single-player and multiplayer slot creation.

## Demo Missions

Newest to oldest:

Black Hawk Down Pt 1 (UH-1H UH-60L) https://www.digitalcombatsimulator.com/en/files/3328428/

NightHawks (AH-64D) https://www.digitalcombatsimulator.com/en/files/3322036/

RotorOps: Aleppo Under Siege  https://www.digitalcombatsimulator.com/en/files/3320079/ 

Rota Landing (Mr. Nobody) https://www.digitalcombatsimulator.com/en/files/3320186/




# RotorOps: Conflict
Conflict is a game type in which attacking forces must clear Conflict Zones of defending ground forces. Once a zone is cleared, the next zone is activated and attacking ground vehicles will move to the next Conflict Zone automatically.

![alt text](https://raw.githubusercontent.com/spencershepard/RotorOps/main/documentation/images/rotorops%20conflict%20zones.png?raw=true)

## Dynamic Roles
A RotorOps Conflict mission has opportunities for a variety of roles and tasks. There's no need to artificially select these roles, as the mission is fully dynamic.  

### CAS:
The attacking side starts with ground units that move progressively through enemy conflict zones, seeking out enemy units within each zone.  Protecting our ground forces is essential for establishing forward bases for rearming, troop pickup, and winning the battle.  

### Troop Transport:
Never before has infantry been so important in DCS!   Pick up troops from the staging area or a cleared conflict zone and deliver them to the active conflict zone.  They will move through the zone until no enemies remain (or until they are killed).  Very useful for flushing out enemy infantry and vehicles in densely forested or urban areas.  JTAC units can mark important targets with smoke and laser.

### Transport Logistics:
CTLD logistics crates are available from your starting base or staging zone.  The logistics area has several logistics containers, that can themselves be moved to a new area via DCS inbuilt sling loading.  If you can get one of these containers to a new area safely, it becomes a CTLD logistics zone for spawning crates to build ground units and air defenses.

### Ground Attack:
Destroy enemy vehicles and infantry to ensure the survival of our own ground units.  Clearing conflict zones of enemy units is essential for establishing forward bases for rearming and refueling. All enemy ground units must be destroyed to win the battle!

### Fixed-wing CAP/CAS:
Enemy attack helicopters and planes are optional in the generator.  Add slots in the mission generator for fixed-wing flights to provide cover for our helicopters and ground units. For a unique challenge, try Defense mode in a fixed-wing ground attack role...enemies are nearly always in motion.

## Mission Generator and Customization
The mission generator works by automatically placing units and trigger actions into a map template with defined airports and trigger zones.  

Missions produced by the generator are easy to modify and understand.  For example, units can be moved, and player flights can be added without issue. Use the result of the mission generator for quick plays, or build on it for something epic.  Trigger actions are set up, labeled, and commented so that you can understand how things work and add your own actions.  An additional library of voiceover files is provided for your own use.

Easily add your own templates for friendly/enemy ground units directly in the DCS mission editor.

Create your own scenarios for the RotorOps mission generator,  using the DCS mission editor.

***


### Developers
We welcome contributors to this new project!  Please get in touch on Discord with new ideas or pickup/create an issue in this repo.  

#### Install python 

If using VSCode, you can install the Python extension to get started: [VS Marketplace Link](https://marketplace.visualstudio.com/items?itemName=ms-python.python)

If not, you may need to install python 3.8.5.  If you are using Windows, you can download it here: https://www.python.org/downloads/release/python-385/

#### Create a python virtual environment

To create a virtual environment, run the following command in the root of the project:

`python -m venv .venv`

If using VSCode, you can use the ">Python: create environment" command.

#### Install python dependencies

In a terminal, type `pip install -r .\Generator\requirements.txt`

#### Build the mission generator

In a terminal, type `build.bat`

The mission generator will be built to the `dist` folder.	

#### Run the mission generator

Using VS Code, you can use the provided launch configuration to run the mission generator.  Otherwise, you can run the following command in a terminal: `python .\Generator\MissionGenerator.py`	

### RotorOps Mission Creator Guide:
For more detailed information on how the script works, see this wiki:
https://github.com/spencershepard/RotorOps/wiki/RotorOps:-Mission-Creator-Guide

***

### Thanks to

RotorOps uses MIST and integrates CTLD:

https://github.com/mrSkortch/MissionScriptingTools

https://github.com/ciribob/DCS-CTLD

The mission generator would not be possible without PyDCS:

https://github.com/pydcs/dcs

### Thanks to contributors

Shagrat: For amazing templates and testing for our FARPs, FOBs, and other mission assets.

Mr. Nobody: For awesome scenario and forces templates and helping to indroduce the DCS world to RotorOps.

***

# Join our Discord!

Chat about anything RotorOps or join up to fly!

https://discord.gg/HFqjrZV9xD

# Support this project on Patreon

Any membership level is a huge help to push this project forward, including our goals for new features and a full-time multiplayer server.  Thank you!

https://www.patreon.com/dcs_rotorops
