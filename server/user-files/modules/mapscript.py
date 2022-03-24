# A script for creating the modules map file

import os
import yaml

print("Current dir: " + os.getcwd())
modules = []
module_folders = next(os.walk('.'))[1]
for folder in module_folders:

    valid_module = False
    module_filenames = []
    module = {}
    print("searching folder: " + folder)

    for filename in os.listdir(folder):
        module_filenames.append(filename)

        # assume the yaml file is our scenario configuration file
        if filename.endswith(".yaml"):
            #print("found config file: " + filename)
            stream = file(os.path.join(folder, filename), 'r')
            config = yaml.load(stream)
            #print("Config file yaml: " + str(config))

            if 'name' in config:
                print("Config file has name: " + config['name'])
                valid_module = True
                module['name'] = config['name']

    if valid_module:
        print("Populating module attributes for " + folder)
        module['id'] = folder
        module['dist'] = 'add'
        module['path'] = 'templates\Scenarios\downloaded'
        module['files'] = module_filenames

        if 'version' in config:
            module['version'] = config['version']
        else:
            module['version'] = 1

        if 'requires' in config:
            module['requires'] = config['requires']
        else:
            module['requires'] = 1

        modules.append(module)

print("Found modules: " + str(len(modules)))

if len(modules) > 0:
    modulemap = {}
    #print(str(modules))
    for m in modules:
        print("adding module: " + m["id"])
        modulemap[m['id']] = m

    with open('module-map.yaml', 'w') as mapfile:
            print("Creating map file...")
            yaml.dump(modulemap, mapfile)
            print("Success.")




