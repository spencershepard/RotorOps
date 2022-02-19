from dcs.countries import Russia, USA
import dcs.unit as unit
from dcs.mission import Mission
import dcs.mapping as mapping
import dcs.ships
import dcs.vehicles
import dcs.statics
import dcs.unit
import random


class VehicleTemplate:

    class CombinedJointTaskForcesBlue:

        @staticmethod
        def zone_farp(mission, country, farp_country, position, heading, name, late_activation):
            # ai air units attack farp with late activation units, so we will set it to enemy coalition.  It will be captured when frienly units spawn
            farp = mission.farp(farp_country, name, position, hidden=False, dead=False, farp_type=dcs.unit.InvisibleFARP)

            vg = mission.vehicle_group_platoon(
                country,
                name + " Static",
                [
                    dcs.vehicles.Unarmed.M_818,
                    dcs.vehicles.AirDefence.Vulcan,
                    dcs.vehicles.Unarmed.Ural_375,
                    dcs.vehicles.Unarmed.M978_HEMTT_Tanker
                ],
                position.point_from_heading(45, 7),
                heading=random.randint(0, 359),
                formation=dcs.unitgroup.VehicleGroup.Formation.Star,

            )
            vg.late_activation = late_activation
            return vg


        @staticmethod
        def logistics_site(mission, country, position, heading, prefix=""):

            farp = mission.farp(country, "Logistics FARP", position, hidden=False, dead=False, farp_type=dcs.unit.InvisibleFARP)

            sg = mission.static_group(
                country,
                prefix + " Logistics",
                dcs.statics.Fortification.TV_tower,
                position.point_from_heading(heading, 80),
                heading
            )

            dist_from_center = 30

            for i in range(1,4):

                u = mission.static("logistic" + str(i), dcs.statics.Cargo.Iso_container_small)
                u.position = position.point_from_heading(heading + 90, dist_from_center + (i * 15))
                u.heading = 10
                sg.add_unit(u)

            for i in range(5,8):

                u = mission.static("logistic" + str(i), dcs.statics.Cargo.Iso_container_small)
                u.position = position.point_from_heading(heading + 270, dist_from_center + (i * 15))
                u.heading = 10
                sg.add_unit(u)

            a_pos = position.point_from_heading(heading + 180, dist_from_center)

            u = mission.static("Ammo Dump", dcs.statics.Fortification.FARP_Ammo_Dump_Coating)
            u.position = a_pos.point_from_heading(heading + 90, 1)
            u.heading = heading
            sg.add_unit(u)

            u = mission.static("FARP Tent", dcs.statics.Fortification.FARP_Tent)
            u.position = a_pos.point_from_heading(heading + 90, dist_from_center + 20)
            u.heading = heading
            sg.add_unit(u)

            u = mission.static("Fuel Depot", dcs.statics.Fortification.FARP_Fuel_Depot)
            u.position = a_pos.point_from_heading(heading + 90, dist_from_center + 40)
            u.heading = heading
            sg.add_unit(u)

            return sg



        @staticmethod
        def sa6_site(mission, country, position, heading, prefix="", skill=unit.Skill.Average):
            vg = mission.vehicle_group(
                country,
                prefix + "SA6 site",
                dcs.vehicles.AirDefence.Kub_1S91_str,
                position,
                heading
            )

            u = mission.vehicle("Launcher 1", dcs.vehicles.AirDefence.Kub_2P25_ln)
            u.position = position.point_from_heading(heading + 140, 30)
            u.heading = heading
            vg.add_unit(u)

            u = mission.vehicle("Launcher 2", dcs.vehicles.AirDefence.Kub_2P25_ln)
            u.position = position.point_from_heading(heading + 210, 30)
            u.heading = heading
            vg.add_unit(u)

            u = mission.vehicle("Rearm Truck", dcs.vehicles.Unarmed.Ural_375)
            u.position = position.point_from_heading(heading + 0, 40)
            u.heading = heading
            vg.add_unit(u)

            for u in vg.units:
                u.skill = skill

            return vg
