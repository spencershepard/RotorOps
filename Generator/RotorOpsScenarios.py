import dcs
import RotorOpsMission as ROps
import RotorOpsUnits

nevada_scenarios = {}

map_dict = {
    "Caucasus": dcs.terrain.caucasus.Caucasus(),
    "Persian_Gulf": dcs.terrain.persiangulf.PersianGulf(),
    "Nevada": dcs.terrain.nevada.Nevada(),
    "Normandy": dcs.terrain.normandy.Normandy(),
    "The_Channel": dcs.terrain.thechannel.TheChannel(),
    "Syria": dcs.terrain.syria.Syria(),
    "Mariana": dcs.terrain.marianaislands.MarianaIslands(),
}

def test_scenario():
    sm = ROps.RotorOpsMission("Boulder", dcs.terrain.nevada.Nevada(), dcs.terrain.nevada.Boulder_City())
    sm.addZone(sm.conflict_zones,
       ROps.RotorOpsMission.RotorOpsZone("ALPHA", 101, dcs.terrain.nevada.McCarran_International().position, 5000))
    sm.addZone(sm.conflict_zones,
       ROps.RotorOpsMission.RotorOpsZone("BRAVO", 102, dcs.Point(-419852,-12154), 5000))
    sm.addZone(sm.staging_zones,
       ROps.RotorOpsMission.RotorOpsZone("STAGING", None, dcs.terrain.nevada.Boulder_City().position, 4000))
    sm.addGroundUnits(sm.conflict_zones["ALPHA"], dcs.countries.Russia, RotorOpsUnits.red_unarmed_group)
    sm.addGroundUnits(sm.conflict_zones["BRAVO"], dcs.countries.Russia, RotorOpsUnits.red_unarmed_group)
    sm.addGroundUnits(sm.staging_zones["STAGING"], dcs.countries.USA, RotorOpsUnits.red_armor_group)
    sm.scriptTriggerSetup()
    sm.generateMission()


nevada_scenarios["Boulder to The Strip"] = test_scenario()