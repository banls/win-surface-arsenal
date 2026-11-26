# smb_minimal.ps1 —— 最小开洞：关签名 + 放行 445/139/135 + 匿名读（低特征）
if (-not ([Security.Principal.WindowsPrincipal][Security.Principal.WindowsIdentity]::GetCurrent()).IsInRole('Administrators')) { Write-Host '[!] need admin'; exit 1 }
Set-SmbServerConfiguration -RequireSecuritySignature $false -EnableSecuritySignature $false -Force
Set-ItemProperty 'HKLM:\SYSTEM\CurrentControlSet\Services\LanmanServer\Parameters' RequireSecuritySignature 0
Set-ItemProperty 'HKLM:\SYSTEM\CurrentControlSet\Services\LanmanServer\Parameters' RestrictNullSessAccess 0
Set-ItemProperty 'HKLM:\SYSTEM\CurrentControlSet\Services\LanmanWorkstation\Parameters' AllowInsecureGuestAuth 1
Set-ItemProperty 'HKLM:\SYSTEM\CurrentControlSet\Control\Lsa' LmCompatibilityLevel 2
foreach ($p in 445,139,135,137,138) {
  $proto = if ($p -in 137,138) { 'UDP' } else { 'TCP' }
  Remove-NetFirewallRule -DisplayName "X-$proto-$p" -ErrorAction SilentlyContinue
  New-NetFirewallRule -DisplayName "X-$proto-$p" -Direction Inbound -Action Allow -Protocol $proto -LocalPort $p | Out-Null
}
Write-Host '[+] minimal surface opened: signing off, 445/139/135 open, anon allowed, LmCompat=2'
