import dcs.task as task
from dcs.helicopters import HelicopterType
from typing import Set

# RotorOps class for UH-60L mod
class UH_60L(HelicopterType):
    id = "UH-60L"
    flyable = True
    height = 5.13
    width = 16.4
    length = 19.76
    fuel_max = 1362
    max_speed = 300
    chaff = 30
    flare = 60
    charge_total = 90
    chaff_charge_size = 1
    flare_charge_size = 1

    pylons: Set[int] = {1, 2, 3, 4}

    tasks = [task.Transport]
    task_default = task.Transport
