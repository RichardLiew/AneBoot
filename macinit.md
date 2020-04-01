新建用户组：

  * Ayoume:
    + `sudo dscl . -create /Groups/Ayoume`
    + `sudo dscl . -create /Groups/Ayoume PrimaryGroupID 2000`
    + `sudo dscl . -create /Groups/Ayoume PrimaryGroupID 2000 RealName Ayoume passwd lZf011027`
    + `sudo dscl . -create /Groups/Ayoume PrimaryGroupID 2000 RealName Ayoume passwd lZf011027`


新建用户：

  * Zeus（预留超级管理员）: `sudo dscl . -create /Users/Zeus UserShell /bin/zsh RealName "Zeus Liew" UniqueID 1000 PrimaryGroupID 2000 NFSHomeDirectory /Users/Zeus passwd lZf011027`

  * Zich（Myself）: `sudo dscl . -create /Users/Zich UserShell /bin/zsh RealName "Zich Liew" UniqueID 1001 PrimaryGroupID 2000 NFSHomeDirectory /Users/Zich passwd lZf011027`


增加管理员权限：

* Zeus: `sudo dscl . -append /Groups/admin GroupMembership Zeus`

* Zich: `sudo dscl . -append /Groups/admin GroupMembership Zich`
