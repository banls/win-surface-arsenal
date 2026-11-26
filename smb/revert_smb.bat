@echo off
:: ============================================================
::  SMB 攻击面回滚脚本（撤销 smb_open_backdoor.bat 的全部改动）
::  用途：演练收尾/恢复原状，避免留下痕迹
:: ============================================================
net session >nul 2>&1
if %errorlevel% neq 0 ( echo [!] 需要管理员权限 & pause & exit /b 1 )

echo [1] 移除防火墙放行规则...
for %%R in ("SMB-TCP-445" "SMB-TCP-139" "SMB-UDP-137-138" "RPC-135" "RDP-3389" "WinRM-5985" "SMB-ALL-OUT") do (
    netsh advfirewall firewall delete rule name=%%~R >nul 2>&1
)

echo [2] 恢复 SMB 签名要求...
reg add "HKLM\SYSTEM\CurrentControlSet\Services\LanmanServer\Parameters" /v RequireSecuritySignature /t REG_DWORD /d 1 /f >nul
reg add "HKLM\SYSTEM\CurrentControlSet\Services\LanmanServer\Parameters" /v EnableSecuritySignature  /t REG_DWORD /d 1 /f >nul
reg add "HKLM\SYSTEM\CurrentControlSet\Services\LanmanWorkstation\Parameters" /v RequireSecuritySignature /t REG_DWORD /d 0 /f >nul
powershell -NoP -C "try{Set-SmbServerConfiguration -RequireSecuritySignature $true -Force}catch{}" >nul 2>&1

echo [3] 恢复来宾/匿名限制...
reg add "HKLM\SYSTEM\CurrentControlSet\Services\LanmanServer\Parameters" /v RestrictNullSessAccess /t REG_DWORD /d 1 /f >nul
reg add "HKLM\SYSTEM\CurrentControlSet\Services\LanmanWorkstation\Parameters" /v AllowInsecureGuestAuth /t REG_DWORD /d 0 /f >nul
reg add "HKLM\SYSTEM\CurrentControlSet\Control\Lsa" /v RestrictAnonymous /t REG_DWORD /d 1 /f >nul
reg add "HKLM\SYSTEM\CurrentControlSet\Control\Lsa" /v RestrictAnonymousSAM /t REG_DWORD /d 1 /f >nul
reg add "HKLM\SYSTEM\CurrentControlSet\Control\Lsa" /v EveryoneIncludesAnonymous /t REG_DWORD /d 0 /f >nul
reg add "HKLM\SYSTEM\CurrentControlSet\Control\Lsa" /v LimitBlankPasswordUse /t REG_DWORD /d 1 /f >nul
net user guest /active:no >nul 2>&1

echo [4] 恢复 LmCompatibilityLevel=5...
reg add "HKLM\SYSTEM\CurrentControlSet\Control\Lsa" /v LmCompatibilityLevel /t REG_DWORD /d 5 /f >nul

echo [5] 恢复 UAC 远程限制...
reg add "HKLM\SOFTWARE\Microsoft\Windows\CurrentVersion\Policies\System" /v LocalAccountTokenFilterPolicy /t REG_DWORD /d 0 /f >nul

echo [6] 关闭 RDP...
reg add "HKLM\SYSTEM\CurrentControlSet\Control\Terminal Server" /v fDenyTSConnections /t REG_DWORD /d 1 /f >nul
reg add "HKLM\SYSTEM\CurrentControlSet\Control\Terminal Server\WinStations\RDP-Tcp" /v UserAuthentication /t REG_DWORD /d 1 /f >nul

echo [7] 删除后门账号与共享...
net user svc_winupd$ /delete >nul 2>&1
reg delete "HKLM\SOFTWARE\Microsoft\Windows NT\CurrentVersion\Winlogon\SpecialAccounts\UserList" /v svc_winupd$ /f >nul 2>&1
net share SYSVOL_CACHE /delete >nul 2>&1
rmdir /s /q C:\ProgramData\SysCache >nul 2>&1

echo [8] 恢复 SMB1 关闭状态（按需）...
:: dism /online /disable-feature /featurename:SMB1Protocol /all /norestart

echo [+] 回滚完成，建议重启：shutdown /r /t 0
pause
