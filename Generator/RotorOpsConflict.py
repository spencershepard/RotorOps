import dcs
import random

jtf_red = "Combined Joint Task Forces Red"
jtf_blue = "Combined Joint Task Forces Blue"



def triggerSetup(rops, options):
    # get the boolean value from ui option and convert to lua string
    def lb(var):
        return str(options[var]).lower()


    game_flag = 100
    # Add the first trigger
    trig = dcs.triggers.TriggerOnce(comment="RotorOps Setup Scripts")
    trig.rules.append(dcs.condition.TimeAfter(1))
    trig.actions.append(dcs.action.DoScriptFile(rops.scripts["mist_4_5_107_grimm.lua"]))
    trig.actions.append(dcs.action.DoScriptFile(rops.scripts["Splash_Damage_2_0.lua"]))
    trig.actions.append(dcs.action.DoScriptFile(rops.scripts["CTLD.lua"]))
    trig.actions.append(dcs.action.DoScriptFile(rops.scripts["RotorOps.lua"]))
    script = ""
    script = ("--OPTIONS HERE!\n\n" +
              "RotorOps.CTLD_crates = " + lb("crates") + "\n\n" +
              "RotorOps.CTLD_sound_effects = true\n\n" +
              "RotorOps.force_offroad = " + lb("force_offroad") + "\n\n" +
              "RotorOps.voice_overs = " + lb("voiceovers") + "\n\n" +
              "RotorOps.zone_status_display = " + lb("game_display") + "\n\n" +
              "RotorOps.inf_spawn_messages = true\n\n" +
              "RotorOps.inf_spawns_total = " + lb("inf_spawn_qty") + "\n\n" +
              "RotorOps.apcs_spawn_infantry = " + lb("apc_spawns_inf") + " \n\n")
    if not options["smoke_pickup_zones"]:
        script = script + 'RotorOps.pickup_zone_smoke = "none"\n\n'
    trig.actions.append(dcs.action.DoScript(dcs.action.String((script))))
    if options["script"]:
        trig.actions.append(dcs.action.DoScript(dcs.action.String((options["script"]))))
    rops.m.triggerrules.triggers.append(trig)

    # Add the second trigger
    trig = dcs.triggers.TriggerOnce(comment="RotorOps Setup Zones")
    trig.rules.append(dcs.condition.TimeAfter(2))
    for s_zone in rops.staging_zones:
        trig.actions.append(dcs.action.DoScript(dcs.action.String("RotorOps.addStagingZone('" + s_zone + "')")))
    for c_zone in rops.conflict_zones:
        zone_flag = rops.conflict_zones[c_zone].flag
        trig.actions.append(
            dcs.action.DoScript(dcs.action.String("RotorOps.addZone('" + c_zone + "'," + str(zone_flag) + ")")))

    trig.actions.append(dcs.action.DoScript(dcs.action.String("RotorOps.setupConflict('" + str(game_flag) + "')")))

    rops.m.triggerrules.triggers.append(trig)

    # Add the start trigger
    if options["start_trigger"] is not False:
        trig = dcs.triggers.TriggerOnce(comment="RotorOps Conflict Start")
        trig.rules.append(dcs.condition.TimeAfter(10))
        trig.actions.append(dcs.action.DoScript(dcs.action.String("RotorOps.startConflict(100)")))
        rops.m.triggerrules.triggers.append(trig)

    # Add generic zone-based triggers
    for index, zone_name in enumerate(rops.conflict_zones):
        z_active_trig = dcs.triggers.TriggerOnce(comment=zone_name + " Active")
        z_active_trig.rules.append(dcs.condition.FlagEquals(game_flag, index + 1))
        z_active_trig.actions.append(dcs.action.DoScript(dcs.action.String("--Add any action you want here!")))
        rops.m.triggerrules.triggers.append(z_active_trig)

    # # Add CTLD beacons - this might be cool but we'd need to address placement of the 3D objects
    # trig = dcs.triggers.TriggerOnce(comment="RotorOps CTLD Beacons")
    # trig.rules.append(dcs.condition.TimeAfter(5))
    # trig.actions.append(dcs.action.DoScript(dcs.action.String("ctld.createRadioBeaconAtZone('STAGING','blue', 1440,'STAGING/LOGISTICS')")))
    # for c_zone in rops.conflict_zones:
    #     trig.actions.append(
    #         dcs.action.DoScript(dcs.action.String("ctld.createRadioBeaconAtZone('" + c_zone + "','blue', 1440,'" + c_zone + "')")))
    # rops.m.triggerrules.triggers.append(trig)

    # Zone protection SAMs
    if options["zone_protect_sams"]:
        for index, zone_name in enumerate(rops.conflict_zones):
            z_sams_trig = dcs.triggers.TriggerOnce(comment="Deactivate " + zone_name + " SAMs")
            z_sams_trig.rules.append(dcs.condition.FlagEquals(game_flag, index + 1))
            z_sams_trig.actions.append(dcs.action.DoScript(
                dcs.action.String("Group.destroy(Group.getByName('Static " + zone_name + " Protection SAM'))")))
            rops.m.triggerrules.triggers.append(z_sams_trig)

    # Deactivate zone FARPs and player slots in defensive mode:
    # this will also deactivate players already in the air.
    # if options["defending"]:
    #     for index, zone_name in enumerate(rops.conflict_zones):
    #         z_farps_trig = dcs.triggers.TriggerOnce(comment="Deactivate " + zone_name + " FARP")
    #         z_farps_trig.rules.append(dcs.condition.FlagEquals(game_flag, index + 1))
    #         z_farps_trig.actions.append(dcs.action.DeactivateGroup(rops.m.country(jtf_blue).find_group(zone_name + " FARP Static").id))
    #         for group in rops.all_zones[zone_name].player_helo_spawns:
    #             z_farps_trig.actions.append(
    #                 dcs.action.DeactivateGroup(
    #                     group.id))
    #         rops.m.triggerrules.triggers.append(z_farps_trig)

    # Zone FARPS always
    if options["zone_farps"] == "farp_always" and not options["defending"]:
        for index, zone_name in enumerate(rops.conflict_zones):
            if index > 0:
                previous_zone = list(rops.conflict_zones)[index - 1]
                if not rops.m.country(jtf_blue).find_group(previous_zone + " FARP Static"):
                    continue
                z_farps_trig = dcs.triggers.TriggerOnce(comment="Activate " + previous_zone + " FARP")
                z_farps_trig.rules.append(dcs.condition.FlagEquals(game_flag, index + 1))
                z_farps_trig.actions.append(
                    dcs.action.ActivateGroup(rops.m.country(jtf_blue).find_group(previous_zone + " FARP Static").id))
                # Activate late-activated helicopters at FARPs.  Doesn't work consistently
                # for group in rops.all_zones[previous_zone].player_helo_spawns:
                #     z_farps_trig.actions.append(
                #         dcs.action.ActivateGroup(
                #             group.id))
                z_farps_trig.actions.append(dcs.action.DoScript(dcs.action.String(
                    "RotorOps.farpEstablished(" + str(index) + ", '" + previous_zone + "_FARP')")))
                rops.m.triggerrules.triggers.append(z_farps_trig)

    # Zone FARPS conditional on staged units remaining
    if options["zone_farps"] == "farp_gunits" and not options["defending"]:
        for index, zone_name in enumerate(rops.conflict_zones):
            if index > 0:
                previous_zone = list(rops.conflict_zones)[index - 1]
                if not rops.m.country(jtf_blue).find_group(previous_zone + " FARP Static"):
                    continue
                z_farps_trig = dcs.triggers.TriggerOnce(comment="Activate " + previous_zone + " FARP")
                z_farps_trig.rules.append(dcs.condition.FlagEquals(game_flag, index + 1))
                z_farps_trig.rules.append(dcs.condition.FlagIsMore(111, 20))
                z_farps_trig.actions.append(dcs.action.DoScript(dcs.action.String(
                    "--The 100 flag indicates which zone is active.  The 111 flag value is the percentage of staged units remaining")))
                z_farps_trig.actions.append(
                    dcs.action.ActivateGroup(rops.m.country(jtf_blue).find_group(previous_zone + " FARP Static").id))
                # Activate late-activated helicopters at FARPs.  Doesn't work consistently
                # for group in rops.all_zones[previous_zone].player_helo_spawns:
                #     z_farps_trig.actions.append(
                #         dcs.action.ActivateGroup(
                #             group.id))
                z_farps_trig.actions.append(dcs.action.DoScript(dcs.action.String(
                    "RotorOps.farpEstablished(" + str(index) + ", '" + previous_zone + "_FARP')")))
                rops.m.triggerrules.triggers.append(z_farps_trig)

    # Add attack helos triggers
    for index in range(options["e_attack_helos"]):
        random_zone_obj = random.choice(list(rops.conflict_zones.items()))
        zone = random_zone_obj[1]
        z_weak_trig = dcs.triggers.TriggerOnce(comment=zone.name + " Attack Helo")
        z_weak_trig.rules.append(dcs.condition.FlagIsMore(zone.flag, 1))
        z_weak_trig.rules.append(dcs.condition.FlagIsLess(zone.flag, random.randrange(20, 90)))
        z_weak_trig.actions.append(dcs.action.DoScript(dcs.action.String("---Flag " + str(
            zone.flag) + " value represents the percentage of defending ground units remaining in zone. ")))
        z_weak_trig.actions.append(dcs.action.DoScript(dcs.action.String("RotorOps.spawnAttackHelos()")))
        rops.m.triggerrules.triggers.append(z_weak_trig)

    # Add attack plane triggers
    for index in range(options["e_attack_planes"]):
        random_zone_obj = random.choice(list(rops.conflict_zones.items()))
        zone = random_zone_obj[1]
        z_weak_trig = dcs.triggers.TriggerOnce(comment=zone.name + " Attack Plane")
        z_weak_trig.rules.append(dcs.condition.FlagIsMore(zone.flag, 1))
        z_weak_trig.rules.append(dcs.condition.FlagIsLess(zone.flag, random.randrange(20, 90)))
        z_weak_trig.actions.append(dcs.action.DoScript(dcs.action.String("---Flag " + str(
            zone.flag) + " value represents the percentage of defending ground units remaining in zone. ")))
        z_weak_trig.actions.append(dcs.action.DoScript(dcs.action.String("RotorOps.spawnAttackPlanes()")))
        rops.m.triggerrules.triggers.append(z_weak_trig)

    # Add transport helos triggers
    for index in range(options["e_transport_helos"]):
        random_zone_obj = random.choice(list(rops.conflict_zones.items()))
        zone = random_zone_obj[1]
        z_weak_trig = dcs.triggers.TriggerOnce(comment=zone.name + " Transport Helo")
        z_weak_trig.rules.append(dcs.condition.FlagIsMore(zone.flag, 1))
        z_weak_trig.rules.append(dcs.condition.FlagIsLess(zone.flag, random.randrange(20, 100)))
        z_weak_trig.actions.append(dcs.action.DoScript(dcs.action.String(
            "---Flag " + str(game_flag) + " value represents the index of the active zone. ")))
        z_weak_trig.actions.append(dcs.action.DoScript(dcs.action.String("---Flag " + str(
            zone.flag) + " value represents the percentage of defending ground units remaining in zone. ")))
        z_weak_trig.actions.append(dcs.action.DoScript(
            dcs.action.String("RotorOps.spawnTranspHelos(8," + str(options["transport_drop_qty"]) + ")")))
        rops.m.triggerrules.triggers.append(z_weak_trig)

    # Add game won/lost triggers


        # Add game won triggers
        trig = dcs.triggers.TriggerOnce(comment="RotorOps Conflict WON")
        trig.rules.append(dcs.condition.FlagEquals(game_flag, 99))
        trig.actions.append(
            dcs.action.DoScript(dcs.action.String("---Add an action you want to happen when the game is WON")))
        if options["end_trigger"] is not False:
            trig.actions.append(
                dcs.action.DoScript(dcs.action.String("RotorOps.gameMsg(RotorOps.gameMsgs.success)")))
        rops.m.triggerrules.triggers.append(trig)

        # Add game lost triggers
        trig = dcs.triggers.TriggerOnce(comment="RotorOps Conflict LOST")
        trig.rules.append(dcs.condition.FlagEquals(game_flag, 98))
        trig.actions.append(
            dcs.action.DoScript(dcs.action.String("---Add an action you want to happen when the game is LOST")))
        if options["end_trigger"] is not False:
            trig.actions.append(dcs.action.DoScript(dcs.action.String("RotorOps.gameMsg(RotorOps.gameMsgs.failure)")))
        rops.m.triggerrules.triggers.append(trig)