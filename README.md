# What is RotorOps?
RotorOps brings the ground war in DCS to life.  Infantry becomes useful, and the helicopter operations that support them  will directly contribute to the success of the mission.
RotorOps is a DCS script that makes it easy to create fun and engaging missions on the fly, directly in the mission editor and without ever opening a script file.  

## Demo Missions
RotorOps: Aleppo Under Siege  https://www.digitalcombatsimulator.com/en/files/3320079/

# RotorOps: Conflict
At the heart of this first release is a game type called Conflict, where attacking forces must clear Conflict Zones of defending ground forces. Once a zone is cleared, the next zone is activated and ground vehicles will move to the next Conflict Zone automatically.  It's up to the rotorheads to pickup troops from the cleared zones and transport them to the active Conflict Zone. 

![alt text](https://raw.githubusercontent.com/spencershepard/RotorOps/develop/documentation/images/rotorops%20conflict%20zones.png?raw=true)


### Do I have to transport troops?
This is really up to the mission designer. Transporting troops is not required for mission success in Conflict.  However, friendly troops can be a very valuable asset, especially for clearing enemies in dense urban areas.  If you're in a fixed wing or attack helicopter role, troop transport could be provided by other players or AI.

### What about attack helicopters?  
The constantly moving infantry is easier to see than the statues we are used to seeing.  Destroying defending enemy vehicles so that our troops and vehicles can survive, and intercepting enemy reinforcements may be crucial to mission success.  

## How do I create a Conflict mission?
Just open a demo mission in the DCS mission editor and drop units into the Conflict Zones.  These are trigger areas drawn in the mission editor that will automatically control the ground forces that enter them.  This means that you do not need to worry about creating waypoints; enemy vehicles and infantry will seek each other out automatically.  Move the Conflict Zones or change their size, add friendly or enemy units (remember, no waypoints needed).

Optional USER FLAGS are available to trigger events based on the status of individual zones and the game as a whole.  Simple DO SCRIPT waypoint actions are available to drop troops from friendly or enemy AI helicopters or ground vehicles.

# RotorOps Mission Creator Wiki: https://github.com/spencershepard/RotorOps/wiki

RotorOps uses MIST and integrates CTLD:

https://github.com/mrSkortch/MissionScriptingTools

https://github.com/ciribob/DCS-CTLD
