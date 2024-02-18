import dcs
import aircraftMods

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



