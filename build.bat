@echo off

call .\venv\Scripts\activate.bat
echo activated python venv.

pushd Generator

pyuic5 -x MissionGeneratorUI.ui -o MissionGeneratorUI.py
echo built MissionGenerator.py from MissionsGeneratorUI.ui

pyrcc5 -o resources.py resources.qrc
echo compiled ui resource files.

echo building exe with pyinstaller...
pyinstaller MissionGenerator.spec --distpath ..\ --clean

popd
echo moving exe to dist folder...
move .\MissionGenerator.exe .\dist\MissionGenerator.exe

echo built MissionGenerator.exe in dist folder.
pause