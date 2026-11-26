# winrm_enable.ps1 —— 开启 WinRM（Basic + 允许不加密），横向执行利器
param([switch]$Revert)
if (-not ([Security.Principal.WindowsPrincipal][Security.Principal.WindowsIdentity]::GetCurrent()).IsInRole('Administrators')) {
    Write-Host '[!] 需要管理员权限'; exit 1
}
if ($Revert) {
    Stop-Service WinRM -Force -ErrorAction SilentlyContinue
    Set-Service WinRM -StartupType Disabled
    winrm set winrm/config/service/auth '@{Basic="false"}' | Out-Null
    winrm set winrm/config/service '@{AllowUnencrypted="false"}' | Out-Null
    Remove-NetFirewallRule -DisplayName 'X-WinRM-5985' -ErrorAction SilentlyContinue
    Write-Host '[+] WinRM 已关闭'
    return
}
Set-Service WinRM -StartupType Automatic
Start-Service WinRM
winrm quickconfig -quiet -force | Out-Null
winrm set winrm/config/service/auth '@{Basic="true"}' | Out-Null
winrm set winrm/config/service '@{AllowUnencrypted="true"}' | Out-Null
winrm set winrm/config/client '@{TrustedHosts="*"}' | Out-Null
Remove-NetFirewallRule -DisplayName 'X-WinRM-5985' -ErrorAction SilentlyContinue
New-NetFirewallRule -DisplayName 'X-WinRM-5985' -Direction Inbound -Action Allow -Protocol TCP -LocalPort 5985 | Out-Null
Write-Host '[+] WinRM 已开启 (5985, Basic/不加密)'
Write-Host '[i] 连接: evil-winrm -i <IP> -u <user> -p <pass>'
