import os
import yaml

template_dirs = [
    '/home/rotorops/public_html/user-files/modules/scenario',
    '/home/rotorops/public_html/user-files/modules/forces',
    '/home/rotorops/public_html/user-files/modules/import',
    ]
    


modules = []
config_errors = []

for d in template_dirs:
    os.chdir(d)
    print("Current dir: " + os.getcwd())
    module_folders = next(os.walk('.'))[1]
    for folder in module_folders:
    
        module_filenames = []
        module = {}
        
        print("searching folder: " + folder)
    
        for filename in os.listdir(folder):
            # package files should not be in remote directory, so ignore
            if filename == "package.yaml":
                continue
            
            module_filenames.append(filename)
    
            # assume the yaml file is our scenario configuration file
            if filename.endswith(".yaml"):
                #print("found config file: " + filename)
                stream = open(os.path.join(folder, filename), 'r')
                config = yaml.safe_load(stream)
                #print("Config file yaml: " + str(config))
                
                if not 'type' in config:
                    config_errors.append(filename)
                    print('\nERROR: ' +  folder + '/' + filename + ' is missing the type attribute.\n')
                    continue
                
                if config['type'].lower() == 'scenario':
                    module['path'] = 'templates\Scenarios\downloaded'
                elif config['type'].lower() == 'forces':
                    module['path'] = 'templates\Forces\downloaded'
                elif config['type'].lower() == 'import':
                    module['path'] = 'templates\Imports\downloaded'
                else:
                    config_errors.append(filename)
                    print('\nERROR: ' +  folder + '/' + filename + ' is missing the type attribute.\n')
                    continue
                
                module['type'] = config['type'].lower()
    
                if 'name' in config:
                    print("Config file has name: " + config['name'])
                    module['name'] = config['name']
                    
                if 'version' in config:
                    module['version'] = config['version']
                else:
                    module['version'] = 1
    

        print("Populating module attributes for " + folder)
        module['id'] = folder
        module['dist'] = 'add'
        module['requires'] = 1
        module['files'] = module_filenames
        modules.append(module)


print("Valid modules: " + str(len(modules)))
print(str(len(config_errors)) + " modules had errors in config file.")

if len(modules) > 0:
    modulemap = {}
    #print(str(modules))
    for m in modules:
        print("adding module: " + m["id"])
        modulemap[m['id']] = m
        
    os.chdir('/home/rotorops/public_html/user-files/modules/')

    with open('module-map-v2.yaml', 'w') as mapfile:
            print("Creating map file...")
            yaml.dump(modulemap, mapfile)
            print("Success.")




