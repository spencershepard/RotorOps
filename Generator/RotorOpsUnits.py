import dcs
import aircraftMods
from MissionGenerator import logger, directories


client_helos = [
    dcs.helicopters.UH_1H,
    #aircraftMods.UH_60L,
    dcs.helicopters.AH_64D_BLK_II,
    dcs.helicopters.Mi_24P,
    dcs.helicopters.Ka_50,
    dcs.helicopters.Ka_50_3
]

player_helos = [
    dcs.helicopters.AH_64D_BLK_II,
    dcs.helicopters.Ka_50,
    dcs.helicopters.Ka_50_3,
    dcs.helicopters.Mi_8MT,
    dcs.helicopters.Mi_24P,
    dcs.helicopters.SA342M,
    dcs.helicopters.SA342L,
    dcs.helicopters.SA342Minigun,
    dcs.helicopters.SA342Mistral,
    dcs.helicopters.UH_1H,
    dcs.helicopters.OH58D,
    aircraftMods.UH_60L,
    dcs.planes.AV8BNA,
    dcs.planes.L_39ZA,
    dcs.planes.MB_339A
]

e_attack_helos = [
    dcs.helicopters.Mi_24P,
    dcs.helicopters.Ka_50,
    dcs.helicopters.Mi_28N,
]

e_transport_helos = [
    #dcs.helicopters.Mi_26,
    #dcs.helicopters.Mi_24P,
    #dcs.helicopters.Mi_8MT,
    dcs.helicopters.CH_47D,
]

e_attack_planes = [
    dcs.planes.A_10C,
]

e_fighter_planes = [
    dcs.planes.Su_27,
]

f_fighter_planes = [
    dcs.planes.FA_18C_hornet,
]

e_zone_sams = [
    dcs.vehicles.AirDefence.Strela_10M3,
]

#flaming cliffs aircraft
excluded_player_aircraft = [
    dcs.planes.F_15C.id,
    dcs.planes.Su_27.id,
    dcs.planes.Su_33.id,
    dcs.planes.MiG_29A.id,
    dcs.planes.MiG_29S.id,
    dcs.planes.Su_25T.id,
    dcs.planes.Su_25TM.id,
    dcs.planes.L_39C.id,
    dcs.planes.A_10C.id,
    dcs.planes.A_10A.id,
    dcs.planes.MB_339APAN.id,
    dcs.planes.Bf_109K_4.id,
    dcs.planes.C_101CC.id,
    dcs.planes.C_101EB.id,
    dcs.planes.Christen_Eagle_II.id,
    dcs.planes.F_86F_Sabre.id,
    dcs.planes.FW_190A8.id,
    dcs.planes.FW_190D9.id,
    dcs.planes.Hawk.id,
    dcs.planes.I_16.id,
    dcs.planes.J_11A.id,
    dcs.planes.MosquitoFBMkVI.id,
    dcs.planes.P_47D_30.id,
    dcs.planes.P_47D_40.id,
    dcs.planes.P_47D_30bl1.id,
    dcs.planes.P_51D.id,
    dcs.planes.P_51D_30_NA.id,
    dcs.planes.SpitfireLFMkIX.id,
    dcs.planes.SpitfireLFMkIXCW.id,
    dcs.planes.TF_51D.id,
    dcs.planes.Yak_52.id,
    dcs.planes.MiG_15bis.id,
    dcs.planes.MiG_19P.id,
    dcs.planes.Su_25.id
    ]


def getUnitsFromMiz(file, side='both'):
    forces = {}
    vehicles = []
    attack_helos = []
    transport_helos = []
    attack_planes = []
    fighter_planes = []
    helicopters = []
    planes = []

    source_mission = dcs.mission.Mission()

    try:
        source_mission.load_file(file)
        if side == 'both':
            sides = ['red', 'blue']
        else:
            sides = [side]
        for side in sides:
            for country_name in source_mission.coalition.get(side).countries:
                country_obj = source_mission.coalition.get(side).countries[country_name]
                for vehicle_group in country_obj.vehicle_group:
                    vehicles.append(vehicle_group)
                for helicopter_group in country_obj.helicopter_group:
                    helicopters.append(helicopter_group)
                    if helicopter_group.task == 'CAS':
                        attack_helos.append(helicopter_group)
                    elif helicopter_group.task == 'Transport':
                        transport_helos.append(helicopter_group)
                for plane_group in country_obj.plane_group:
                    planes.append(plane_group)
                    if plane_group.task == 'CAS':
                        attack_planes.append(plane_group)
                    elif plane_group.task == 'CAP':
                        fighter_planes.append(plane_group)

        forces["vehicles"] = vehicles
        forces["attack_helos"] = attack_helos
        forces["transport_helos"] = transport_helos
        forces["attack_planes"] = attack_planes
        forces["fighter_planes"] = fighter_planes
        forces["helicopters"] = helicopters
        forces["aircraft"] = planes + helicopters

        return forces
    except:
        logger.error("Failed to load units from " + file)


def getDefaultLoadouts():
    print("Getting default loadouts")
    default_loadouts = {}
    groups = getUnitsFromMiz(directories.home_dir + "\\config\\blue_player_loadouts.miz", "blue")
    for group in groups["aircraft"]:
        default_loadouts[group.units[0].unit_type.id] = {}
        default_loadouts[group.units[0].unit_type.id]["pylons"] = group.units[0].pylons
        default_loadouts[group.units[0].unit_type.id]["livery_id"] = group.units[0].livery_id
        default_loadouts[group.units[0].unit_type.id]["group_frequency"] = group.frequency
        if hasattr(group.units[0], "radio"):
            default_loadouts[group.units[0].unit_type.id]["radio"] = group.units[0].radio
        else:
            logger.warn("No radios found in loadout for " + group.units[0].unit_type.id + ". Is it set as a client aircraft?")
        default_loadouts[group.units[0].unit_type.id]["gun"] = group.units[0].gun
        default_loadouts[group.units[0].unit_type.id]["hardpoint_racks"] = group.units[0].hardpoint_racks
    return default_loadouts

def applyLoadoutsToGroup(group, loadouts):
    for unit in group.units:
        if unit.unit_type.id not in loadouts:
            logger.warn("No loadout found for " + unit.unit_type.id)
            continue

        loadout = loadouts[unit.unit_type.id]
        unit.pylons = loadout.get("pylons", unit.pylons)
        unit.livery_id = loadout.get("livery_id", unit.livery_id)
        group.frequency = loadout.get("group_frequency", group.frequency)
        if hasattr(unit, "radio"):
            unit.radio = loadout.get("radio", unit.radio)
        else:
            logger.warn("No radios to apply for " + unit.unit_type.id)
        unit.gun = loadout.get("gun", unit.gun)
        unit.hardpoint_racks = loadout.get("hardpoint_racks", unit.hardpoint_racks)
    return group

