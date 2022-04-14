import secrets
import os
import winreg


path = winreg.HKEY_CURRENT_USER

def saveReg(k,v):
    try:
        key = winreg.OpenKeyEx(path, r"SOFTWARE\\")
        newKey = winreg.CreateKey(key,"RotorOps")
        winreg.SetValueEx(newKey, k, 0, winreg.REG_SZ, str(v))
        if newKey:
            winreg.CloseKey(newKey)
        return True
    except Exception as e:
        print(e)
    return False


def readReg(k):
    try:
        key = winreg.OpenKeyEx(path, r"SOFTWARE\\RotorOps\\")
        value = winreg.QueryValueEx(key,k)
        if key:
            winreg.CloseKey(key)
        return value[0]
    except Exception as e:
        print(e)
    return None

def createUserKey():
    userid = readReg('User')
    if not userid or userid == 'None':
        print("Unable to find userid in registry.")
        userid = secrets.token_urlsafe(10)
        if saveReg('User', userid):
            print("Saved userid to registry")
    return userid


