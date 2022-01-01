--[[ This is handy for development, so that you don't need to delete and re-add the individual scripts in the ME when you make a change.  These will not be packaged with the .miz, so you shouldn't use this script loader for packaging .miz files for other machines/users.  You'll want to add each script individually with a DO SCRIPT FILE ]]--
assert(loadfile("C:\\RotorOps\\mist_4_4_90.lua"))()
assert(loadfile("C:\\RotorOps\\CTLD.lua"))()
assert(loadfile("C:\\RotorOps\\RotorOps.lua"))()