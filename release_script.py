import datetime
import ftplib
import os
import sys
import json
import yaml
from Generator import version

if __name__ == "__main__":

    # change working directory to the directory of this
    os.chdir(os.path.dirname(os.path.abspath(__file__)))

    #get unix epoch seconds string via datetime
    timestamp = str(int(datetime.datetime.now().timestamp()))
    updatescript_bkup = "updatescript.ini.bkup" + timestamp
    versioncheck_bkup = "versioncheck.yaml.bkup" + timestamp

    if not os.getenv("FTP_SERVER") or not os.getenv("FTP_USERNAME") or not os.getenv("FTP_PASSWORD"):
        print("FTP_SERVER, FTP_USERNAME, and FTP_PASSWORD environment variables must be set.")
        sys.exit(1)

    # connect to the update server
    ftp = ftplib.FTP(os.getenv("FTP_SERVER"))
    
    # login to the update server
    try:
        ftp.login(os.getenv("FTP_USERNAME"), os.getenv("FTP_PASSWORD"))
    
    except ftplib.error_perm:
        print("Login failed.  Check your username and password.")
        sys.exit(1)

    except ftplib.error_temp:
        print("Login failed due to temp error.  Check your connection settings.")
        sys.exit(1)

    # list files in the current directory on the update server
    print("Files in the current remote directory: ")
    files = ftp.nlst()
    print(files)

    #download the updatescript.ini file
    with open("updatescript.ini", "wb") as f:
        ftp.retrbinary("RETR updatescript.ini", f.write)

    with open(updatescript_bkup, "wb") as f:
        ftp.retrbinary("RETR updatescript.ini", f.write)
    

    #download the versioncheck.yaml file
    with open("versioncheck.yaml", "wb") as f:
        ftp.retrbinary("RETR versioncheck.yaml", f.write)

    with open(versioncheck_bkup, "wb") as f:
        ftp.retrbinary("RETR versioncheck.yaml", f.write)




    # load yaml file and check previous version

    with open('versioncheck.yaml') as f:
        data = yaml.load(f, Loader=yaml.FullLoader)
        # get version from yaml file
        version_from_file = data['version']

        if version_from_file == version.version_string:
            # throw error
            print("Version is the same as the current version.  Increment the version number in version.py and try again.")
            sys.exit(1)



    changed_files = json.loads(os.getenv("changed_files"))
    print("Adding MissionGenerator.exe to changed files, as it is always updated but not monitored.")
    changed_files.append("MissionGenerator.exe")
    if changed_files:
        print("Changed files: " + str(changed_files))

    # open updatescript.ini for read/write

    with open("updatescript.ini", "r") as f:
        file_text = f.read()
        # get the contents of the first block starting with 'releases{' and ending with '}'
        releases_str = file_text[file_text.find('releases{') + 9:file_text.find('}')].strip()
        # split the releases into a list of releases
        # remove spaces
        releases_str = releases_str.replace(" ", "")
        releases = releases_str.split('\n')
        for r in releases:
            if r == version.version_string:
                print("Version already exists in updatescript.ini")
                sys.exit(1)

    with open("updatescript.ini", "w") as f:

        #add the newest release to the bottom of the list
        releases.append(version.version_string)

        # remove text before first '}'
        file_text = file_text[file_text.find('}') + 1:]

        # write the releases block back to the file
        f.write('releases{\n    ' + '\n    '.join(releases) + '\n}\n')

        #write the old releases back to the file
        f.write(file_text)


        # write the new release to the file
        f.write("\nrelease:" + version.version_string + "{")
        for file in changed_files:
            remote_path = 'continuous/' + file
            subdir = None
            #if file has a subdir, get the subdir
            if file.rfind("/") != -1:
                subdir = file[:file.rfind("/")]
                file = file[file.rfind("/") + 1:]
                f.write("\n    DownloadFile:" + remote_path)
                f.write("," + subdir + "/")
            else:
                f.write("\n    DownloadFile:" + remote_path)

        f.write("\n}")
        f.close()

    # create new versioncheck.yaml file
    with open('versioncheck.yaml', 'w') as f:
        f.write("title: \"Update Available\"\n")
        f.write("description: \"UPDATE AVAILABLE: Please run the included updater utility (RotorOps_updater.exe) to get the latest version.\"" + "\n")
        f.write("version: \"" + version.version_string + "\"\n")


    #upload the new files to the update server

    files = [updatescript_bkup, versioncheck_bkup, 'updatescript.ini', 'versioncheck.yaml']



    for file in files:
        ftp.storbinary("STOR " + file, open(file, "rb"))
        print("Uploaded " + file)

    ftp.quit()


