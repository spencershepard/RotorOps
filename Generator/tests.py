import dcs
import dcs.cloud_presets

testm = dcs.mission.Mission()

# testCloudPresets
for i in range(0, len(dcs.cloud_presets.CLOUD_PRESETS)):
    preset_name = list(dcs.cloud_presets.CLOUD_PRESETS)[i]
    cloud_preset = dcs.weather.CloudPreset.by_name(preset_name)
    testm.weather.clouds_preset = cloud_preset
    print("Cloud preset = " + cloud_preset.ui_name)