import dcs
import os

m = dcs.mission.Mission()
m.load_file("template_source.miz")



#add all of our required sounds
os.chdir("../sound/embedded")
path = os.getcwd()
dir_list = os.listdir(path)
#print("Files and directories in '", path, "' :")
#print(dir_list)

for filename in dir_list:
    if filename.endswith(".ogg"):
        print(filename)
        m.map_resource.add_resource_file(filename)


map_dict = {
    "Caucasus": dcs.terrain.caucasus.Caucasus(),
    "Persian_Gulf": dcs.terrain.persiangulf.PersianGulf(),
    "Nevada": dcs.terrain.nevada.Nevada(),
    "Normandy": dcs.terrain.normandy.Normandy(),
    "The_Channel": dcs.terrain.thechannel.TheChannel(),
    "Syria": dcs.terrain.syria.Syria(),
    "Mariana": dcs.terrain.marianaislands.MarianaIslands(),
}



os.chdir("../../Mission Templates")

for theater in map_dict:
    m.terrain = map_dict[theater]

    m.save("RotorOps_template_" + theater + ".miz")

