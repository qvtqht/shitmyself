import hashlib
import os
import re
import string
import time

def GetMyCacheVersion():
    raise NotImplementedError

def GetFileMessageCachePath():
    raise NotImplementedError

def GetCache():
    raise NotImplementedError

def DBAddItemAttribute(*args):
    raise NotImplementedError

def DBAddVoteRecord(*args):
    raise NotImplementedError

def GetTime(*args):
    return int(time.time())

def ExpireAvatarCache(*args):
    raise NotImplementedError

def DBAddKeyAlias(*args):
    raise NotImplementedError

def GetTemplate(*args):
    raise NotImplementedError

def PutFileMessage(*args):
    raise NotImplementedError


def WriteLog(s):
    print(s)

def GetFile(filePath):
    f = open(filePath)
    data = f.read()
    f.close()
    return data

def GetFileHash(filePath):
    data = GetFile(filePath)
    hash = hashlib.sha256()
    hash.update(data)
    return hash.hexdigest()

def IsItem(s):
    if not s:
        return 0

    if len(s) != 40 and len(s) != 8:
        return 0

    if all(c in string.hexdigits for c in s):
        return 1

    return 0

def GetDir(dirName):  # $dirName ; returns path to special directory specified
    # 'html' = html root
    # 'script'
    # 'txt'
    # 'image
    if not dirName:
        WriteLog('GetDir: warning: $dirName missing')
        return ''

    WriteLog('GetDir: $dirName = ' + dirName)

    scriptDir = os.getcwd()

    match = re.search('^([0-9a-zA-Z\/]+)')
    if match:
        scriptDir = match[0]
        WriteLog('GetDir: $scriptDir sanity check passed')
    else:
        WriteLog('GetDir: warning: sanity check failed on $scriptDir')
        return ''
    
    WriteLog('GetDir: $scriptDir = ' + scriptDir)

    if dirName == 'script':
        WriteLog('GetDir: return ' + scriptDir)
        return scriptDir

    if dirName == 'html':
        WriteLog('GetDir: return ' + scriptDir + '/html')
        return scriptDir + '/html'

    if dirName == 'php':
        WriteLog('GetDir: return ' + scriptDir + '/html')
        return scriptDir + '/html'

    if dirName == 'txt':
        WriteLog('GetDir: return ' + scriptDir + '/html/txt')
        return scriptDir + '/html/txt'

    if dirName == 'image':
        WriteLog('GetDir: return ' + scriptDir + '/html/image')
        return scriptDir + '/html/image'

    if dirName == 'cache':
        WriteLog('GetDir: return ' + scriptDir + '/cache/' + GetMyCacheVersion())
        return scriptDir + '/cache/' + GetMyCacheVersion();

    WriteLog('GetDir: warning: fallthrough on $dirName = ' + dirName)
    return ''
