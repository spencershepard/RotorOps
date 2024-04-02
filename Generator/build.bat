IF EXIST ".\venv" (
  call .\venv\Scripts\activate.bat
) ELSE (
  IF EXIST "..\.venv" ( 
    rem try to activate venv from root directory (VS Code default)
    call ..\.venv\Scripts\activate.bat
  ) ELSE (
    echo "venv not found. Please create a virtual environment and activate it."
    pause >nul
    exit
  )
)
echo activated python venv.

pyuic5 -x MissionGeneratorUI.ui -o MissionGeneratorUI.py
echo built MissionGenerator.py from MissionsGeneratorUI.ui

pyrcc5 -o resources.py resources.qrc
echo compiled ui resource files.

echo building exe with pyinstaller...
pyinstaller MissionGenerator.spec --distpath ..\ --clean

cd ../config
del user-data.yaml
echo removed user-data.yaml

if not %1=="-nopause" (
  pause >nul
)

