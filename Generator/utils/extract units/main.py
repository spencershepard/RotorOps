import dcs
import os


def main():
    filename = "source.miz"
    print("Attempting to extract units from " + filename + " relative to 'HELO_FARP' initial point.")

    source_mission = dcs.mission.Mission()
    source_mission.load_file(filename)
    fo = open("units.txt", "w")

    usa = source_mission.country("USA")
    initial_point = usa.find_static_group("HELO_FARP").position

    def p(mystring):
        fo.write(mystring + '\n')
        print(mystring)

    group_types = [usa.static_group, usa.vehicle_group, usa.helicopter_group, usa.plane_group, usa.ship_group]

    for group_type in group_types:
        for group in group_type:
            for unit in group.units:
                print(str(unit.position.x))
                x_rel = initial_point.x - unit.position.x
                y_rel = initial_point.y - unit.position.y
                heading = unit.heading

                p(unit.type)
                p("x: " + str(round(x_rel, 7)))
                p("y: " + str(round(y_rel, 7)))
                p("h: " + str(round(heading, 2)))
                p('\n')

    fo.close()


main()
