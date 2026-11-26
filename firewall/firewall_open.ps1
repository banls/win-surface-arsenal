# firewall_open.ps1 —— 一键放行常见攻击/管理端口 + 关闭防火墙（可选）
param([switch]$DisableFirewallAll, [switch]$Revert)
if (-not ([Security.Principal.WindowsPrincipal][Security.Principal.WindowsIdentity]::GetCurrent()).IsInRole('Administrators')) {
    Write-Host '[!] 需要管理员权限'; exit 1
}
$ports = @(
  @{P='TCP'; L=445;  N='SMB'},
  @{P='TCP'; L=139;  N='NetBIOS-SSN'},
  @{P='UDP'; L=137;  N='NetBIOS-NS'},
  @{P='UDP'; L=138;  N='NetBIOS-DGM'},
  @{P='TCP'; L=135;  N='RPC-EPM'},
  @{P='TCP'; L=3389; N='RDP'},
  @{P='TCP'; L=5985; N='WinRM-HTTP'},
  @{P='TCP'; L=5986; N='WinRM-HTTPS'},
  @{P='TCP'; L=4450; N='Relay-Stage'},
  @{P='TCP'; L=4444; N='Callback'}
)
if ($Revert) {
  foreach ($x in $ports) { Remove-NetFirewallRule -DisplayName ("X-{0}-{1}" -f $x.P,$x.L) -ErrorAction SilentlyContinue }
  Remove-NetFirewallRule -DisplayName 'X-ICMP' -ErrorAction SilentlyContinue
  netsh advfirewall set allprofiles state on | Out-Null
  Write-Host '[+] 规则已移除，防火墙已启用'
  return
}
foreach ($x in $ports) {
  Remove-NetFirewallRule -DisplayName ("X-{0}-{1}" -f $x.P,$x.L) -ErrorAction SilentlyContinue
  New-NetFirewallRule -DisplayName ("X-{0}-{1}" -f $x.P,$x.L) -Direction Inbound -Action Allow -Protocol $x.P -LocalPort $x.L | Out-Null
}
Remove-NetFirewallRule -DisplayName 'X-ICMP' -ErrorAction SilentlyContinue
New-NetFirewallRule -DisplayName 'X-ICMP' -Direction Inbound -Action Allow -Protocol ICMPv4 | Out-Null
Write-Host ('[+] 已放行: ' + (($ports | ForEach-Object { "$($_.P)/$($_.L)" }) -join ', ') + ', ICMP')
if ($DisableFirewallAll) {
  netsh advfirewall set allprofiles state off | Out-Null
  Write-Host '[!] 防火墙已全局关闭（高特征，收尾务必恢复）'
}
