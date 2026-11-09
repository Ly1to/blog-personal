---
title: OpenWrt 全屋去广告：adblock-fast 方案实录
date: 2026-11-09 12:20:00
tags:
  - OpenWrt
  - adblock-fast
  - DNS
  - 去广告
categories:
  - 折腾记录
---


> 记录一次从现状勘察 → 方案对比 → 选型 → 实施 → 排错 → 验证的完整过程。
>
> 环境：wrt = `192.168.1.1`（OpenWrt 25.12.6 r33311 x86_64 / Intel Celeron N3350 / 1.8GB RAM），已运行 OpenClash（fake-ip-tun 模式）与 6 个 Docker 容器。

---

## 目录

1. [需求与最终结论](#1-需求与最终结论)
2. [wrt 现状勘察](#2-wrt-现状勘察)
3. [为什么 DNS 层拦截是唯一正确的位置](#3-为什么-dns-层拦截是唯一正确的位置)
4. [方案对比与选型](#4-方案对比与选型)
5. [实施过程](#5-实施过程)
6. [排错记录](#6-排错记录)
7. [验证结果](#7-验证结果)
8. [运维：白名单、更新、回滚](#8-运维白名单更新回滚)
9. [遗留待办](#9-遗留待办)
10. [命令速查](#10-命令速查)

---

## 1. 需求与最终结论

**需求**：在 wrt 上做全屋去广告，所有接入设备（手机、电视、PC、IoT）无需单独装插件即可生效。

**最终结论**：

| 项目 | 值 |
|---|---|
| 软件 | `adblock-fast` 1.2.4-r4 + `luci-app-adblock-fast` + 中文语言包 |
| 拦截后端 | `dnsmasq.servers`（`servers-file`） |
| 生效规则数 | **248,933** 个域名 |
| 清单源 | StevenBlack Unified hosts + OISD Big |
| 运行开销 | 内存 +24MB；产物文件 6.8MB / 248,934 行 |
| 干预范围 | 仅 `/etc/config/adblock-fast` + dnsmasq 的 `serversfile` 一项 |

一句话：**在 dnsmasq 解析层把广告域名返回 NXDOMAIN，不碰防火墙、不碰 OpenClash、不占 53 端口所有权。**

---

## 2. wrt 现状勘察

只读查询获得的事实：

| 项 | 值 |
|---|---|
| 系统 | OpenWrt 25.12.6 r33311 (`x86/64`)，内核 6.12.112 |
| 包管理 | **apk**（apk-tools 3.0.5）——**不是** opkg |
| 内存 | 1.8GB，静态占用约 368MB，可用约 1.4GB |
| 存储 | `/dev/root` 28.7GB，已用 1.1GB |
| DNS | dnsmasq 2.93（full），编译含 `nftset`，不含 `ipset` |
| dnsmasq confdir | `/tmp/dnsmasq.cfg01411c.d`（25.x 起按实例命名，**不再是** `/tmp/dnsmasq.d`） |
| 代理 | OpenClash `enable=1`，`en_mode=fake-ip-tun`，`enable_redirect_dns=1`，clash DNS 端口 7874 |
| Docker | 运行中 6 个容器（blog/sun-panel/qbittorrent/beszel/beszel-agent/filebrowser） |
| 已有防火墙规则 | `OpenClash DNS Hijack`：`tcp/udp dport 53 → redirect to :53` |

**关键的运行态 dnsmasq 配置**（`/var/etc/dnsmasq.conf.cfg01411c`）：

```
cache-size=0
server=127.0.0.1#7874        # OpenClash fake-ip DNS
addn-hosts=/tmp/hosts
conf-dir=/tmp/dnsmasq.cfg01411c.d
```

---

## 3. 为什么 DNS 层拦截是唯一正确的位置

### 3.1 本机的 DNS 链路

```
客户端（手机/PC/电视）
   │  发往任意 DNS（114、8.8.8.8、路由器）
   ▼
nft: OpenClash DNS Hijack（dport 53 → redirect :53）   ← 全部被拦下
   ▼
dnsmasq :53
   │  server=127.0.0.1#7874
   ▼
clash DNS :7874（fake-ip）
   ▼
真实上游 / 走代理
```

关键推论：**所有客户端的 DNS 查询，无论如何设置，最终都会经过本机 dnsmasq。** 因此在 dnsmasq 里加一条 `server=/广告域名/`（本地域，直接 NXDOMAIN），就等价于对所有设备生效，且位于 clash 之前，不受代理分流策略影响。

### 3.2 与"IP 层拦截"的对比

| 方式 | 在本环境的问题 |
|---|---|
| hosts / dnsmasq 域名级 | ✅ 可靠性最高，与 fake-ip 兼容 |
| nftset 把解析出的 IP 丢进集合再 DROP | ❌ fake-ip 模式下客户端拿到的 198.18.x 是假地址，DROP 它等于打断 clash 隧道，副作用不可控 |
| 路由器上装浏览器广告插件 | ❌ 只管单机，管不了手机/电视 |

结论：**只做域名级拦截，放弃 IP 集合方案。**

---

## 4. 方案对比与选型

### 4.1 三个候选

| 方案 | 原理 | 资源 | 与 OpenClash 共存 |
|---|---|---|---|
| **adblock-fast** | 拉清单 → 生成 dnsmasq 配置片段 | 极低（+24MB） | ✅ 只写 `serversfile` |
| adblock（4.5.9） | 同上，老牌 | 低 | ⚠️ 硬编码 `/tmp/dnsmasq.d` |
| AdGuard Home | 独立 DNS 服务，自带面板/统计 | 高（~200MB+） | ❌ 需要接管 53 端口 |

### 4.2 为什么排除 AdGuard Home

AGH 必须独占 53 端口才能做"全屋"拦截。但本机 53 端口由 dnsmasq 持有，且 OpenClash 把所有 53 流量劫持到 dnsmasq。要上 AGH 就必须：

1. 把 dnsmasq 挪到 5353，
2. 改 OpenClash 的劫持目标，
3. 让 AGH 的上游指向 clash 的 7874，

即"改三个系统的配置换一个功能"，任一环节出错就是全屋断网。收益（统计面板、每客户端规则）远不抵风险，且多占 200MB+ 内存。**否决。**

### 4.3 为什么排除 adblock（老牌那个）

adblock 4.5.9 默认往 `/tmp/dnsmasq.d` 写片段并依赖 dnsmasq 的 `conf-dir` 包含它。而 OpenWrt 25.x 把 confdir 改成了**按实例命名**的 `/tmp/dnsmasq.cfgXXXXXX.d`，老版本常见"配置写了、文件生成了、但不生效"的静默失败。

adblock-fast 1.2.4 则会通过 ubus 读取 dnsmasq 实例的 `-C` 参数，再解析配置文件里的 `conf-dir` 来动态定位（源码 `_dnsmasq_instance_get_confdir()`），并且默认用 `dnsmasq.servers` 模式直接写 `dhcp.@dnsmasq[0].serversfile`，**完全绕开 confdir 差异**。**选它。**

### 4.4 拦截清单选型

| 清单 | 类型 | 规模 | 取舍 |
|---|---|---|---|
| StevenBlack Unified hosts | hosts | ~4.8MB | 经典、误杀少 |
| OISD Big | hosts | ~6.2MB | 覆盖面大 |
| OISD `domainswild` | wildcard | ~5.0MB | ❌ 本版本不支持（见排错） |
| Hagezi Pro / 1Hosts Lite | domains | 3MB 左右 | 可选加项 |

最终启发式选择"**保守偏标准**"：StevenBlack + OISD Big，合并去重后 248,933 条。

---

## 5. 实施过程

### 5.1 前置：apk 源初始化

```sh
apk update      # 首次使用前必须做，否则所有包都"不存在"
```

本机 feeds 已配好（`/etc/apk/repositories.d/distfeeds.list` 指向 25.12.6 官方源），`apk update` 后得到 11258 个可用包。

### 5.2 安装

```sh
apk add adblock-fast luci-app-adblock-fast luci-i18n-adblock-fast-zh-cn
apk add gawk grep sed coreutils-sort      # 官方推荐工具链，25 万条清单必备
```

第一次安装后 service 会报 `The adblock-fast is currently disabled!`，属预期（默认 `enabled=0`）。

### 5.3 配置（uci）

```sh
uci set adblock-fast.config.enabled='1'
uci set adblock-fast.config.force_dns='0'        # OpenClash 已劫持全部 :53，不叠加规则
uci set adblock-fast.config.download_timeout='30'

# 启用 StevenBlack
uci set adblock-fast.@file_url[3].enabled='1'
# 启用 OISD Big
uci set adblock-fast.@file_url[2].enabled='1'

uci commit adblock-fast
```

**为什么 `force_dns=0`**：该选项会让 adblock-fast 自己往 `inet fw4` 插一条"劫持 LAN 内所有 53 流量"的规则。本机 OpenClash 已经有等价规则了，两条并存只会让 nft 规则集更难排查，且 clash 停止时行为不明。

### 5.4 启动

```sh
/etc/init.d/adblock-fast dl     # 强制下载清单并重建
```

输出（首次全新下载 27 秒）：

```
[ DL ] Blocked List: StevenBlack - Unified hosts (hosts) [✓]
[ DL ] Blocked List: OISD - Big (adblockplus) [✓]
[PROC] Sorting / Optimizing / Removing allowed / Formatting [✓]
[DNSM] Updating dnsmasq configuration [✓]
[DNSM] Testing dnsmasq.servers configuration [✓]
[DNSM] Restarting dnsmasq [✓]
[DNSM] Probing heartbeat.mossdef.org for 10 seconds [✓]
[STAT] adblock-fast 1.2.4-r4 is blocking 248933 domains (with dnsmasq.servers)
```

注意 `Restarting dnsmasq` 这一步会造成**数秒 DNS 中断**（已连接不受影响），`openclash_watch` 会自动重新下发劫持规则。此类网络变更在 `AGENTS.md` 中归为需先征得同意之列，本次已确认后执行。

---

## 6. 排错记录

### 6.1 `opkg: not found`

25.x 起 OpenWrt 全面切换到 `apk`。所有旧教程的 `opkg update / opkg install` 一律失效：

```sh
apk update
apk add <pkg>
apk list --installed | grep xxx
```

### 6.2 首次 `apk list` 全量报 `No such file or directory`

feeds 已配置但索引缓存为空，跑一次 `apk update` 即可（会下载各源 `packages.adb`）。属于"看起来像断网、其实是没索引"的经典误判。

### 6.3 OISD `domainswild`：`Failed to detect format`

```
[ DL ] Blocked List: OISD - Big (wildcard) [✗]
[ERROR] Failed to detect format for OISD - Big (wildcard)!
```

根因：adblock-fast 1.2.4 的格式识别器只认四类（`adblockplus` / `dnsmasq` / `hosts` / `domains`），**没有 wildcard 解析器**。`domainswild` 文件里 231,856 行全是 `*.example.com` 形式：

- 不匹配 `^0.0.0.0` / `^127.0.0.1`（不是 hosts）
- 不匹配 `^server=` / `^local=` / `^address=`（不是 dnsmasq）
- 走 `domains` 兜底过滤时，规则 `/^[^[:alnum:]]/d` 会把所有以 `*` 开头的行删光，于是"识别失败"

**解决**：换成同源 hosts 格式 `https://big.oisd.nl/`（默认配置里自带的 `OISD - Big` 条目），覆盖集合一致，只是不以通配符形式表达。

顺带一提：`hosts` 格式的 detect 用 `grep -e '^0\.0\.0\.0\s'`，所以**纯域名列表里若混有注释头不影响识别**，但全通配符列表一定失败。

### 6.4 uci 配置被 awk 污染（本次最蠢的坑）

用 awk 从 `uci show` 里提取 section 路径时写了：

```sh
idx=$(uci show adblock-fast | awk -F"'" '/name=.StevenBlack/ {print $1}')
idx=${idx%.name}          # ← 错误：$1 结尾是 ".name="，不是 ".name"
uci set "$idx.enabled='1'"
```

结果 section 的 `name` 被写成了 `.enabled='1'`：

```
adblock-fast.cfg05ee77.name='.enabled='\''1'\'''
```

原因：`awk -F"'"` 切出的 `$1` 是 `adblock-fast.@file_url[3].name=`（带等号），后缀替换没命中，拼出的路径变成 `...name=.enabled='1'`，uci 把整串当成了新值。

**正确写法**（两种，都更稳）：

```sh
# A. 用 sed 直接从 uci show 输出里截 section 路径
idx=$(uci show adblock-fast | sed -n "s|^\(adblock-fast\.@file_url\[[0-9]*\]\)\.name='StevenBlack.*|\1|p")

# B. 用序号（配置顺序即序号，改配置后要重新确认）
uci set adblock-fast.@file_url[3].enabled='1'
```

**另一个坑**：`uci commit` 之后，被操作过的匿名 section 会获得固定名字（`cfg05ee77`），此后 `@file_url[3]` 与 `cfg05ee77` 指向同一段，但**按 `uci show ... | awk` 匹配 `@file_url[...]` 的脚本会突然失效**。稳妥做法是：改完立刻 `uci show <pkg>.<section>` 复核，或全程用 `uci show <pkg>` 的实际 section 名操作。

**教训**：凡是用 awk 从 `uci show` 里刮 key 再拼 `uci set` 的脚本，都必须先 `echo` 出拼好的 key 肉眼确认，再执行——`uci set` 对畸形 key 不会报错，只会静默写坏配置。

### 6.5 缓存导致"清单改了但数字没变"

`/etc/init.d/adblock-fast restart` 命中缓存时只复用旧产物（`[INIT] Found cache file, reusing it`），条数仍是 42,275。清单变更后必须：

```sh
/etc/init.d/adblock-fast dl
```

### 6.6 推荐包缺失 WARN

```
[WARN] Recommended packages are missing: gawk, grep, sed, coreutils-sort
```

busybox 版 sort/sed 在 20 万行级别会慢且边界行为不同。装 GNU 版即可（`apk add gawk grep sed coreutils-sort`，约 1.5MB）。

---

## 7. 验证结果

### 7.1 拦截生效

```
$ nslookup doubleclick.net 192.168.1.1
** server can't find doubleclick.net: NXDOMAIN

$ nslookup ads.google.com 192.168.1.1
** server can't find ads.google.com: NXDOMAIN
```

### 7.2 正常域名不受影响

| 域名 | 结果 |
|---|---|
| baidu.com | 124.237.177.164 |
| qq.com | 157.255.219.143 |
| weibo.com | 116.133.8.19 |
| bilibili.com | 139.159.241.37 |
| taobao.com | 59.82.43.234 |
| github.com | 198.18.0.169（clash fake-ip ✅） |
| youtube.com | 198.18.3.153（clash fake-ip ✅） |
| raw.githubusercontent.com | 198.18.1.8（clash fake-ip ✅） |

fake-ip 正常返回说明 **OpenClash 隧道完全没有被影响**。

### 7.3 配置与资源

```
$ grep servers-file /var/etc/dnsmasq.conf.*
servers-file=/var/run/adblock-fast/dnsmasq.servers

$ wc -l /var/run/adblock-fast/dnsmasq.servers
248934        # 6.8MB

$ ls /etc/rc.d/ | grep adblock
S20adblock-fast -> ../init.d/adblock-fast      # 开机自启已就绪

$ free -m
              total        used        free
Mem:        1881272      392368      841332     # 368MB → 392MB，+24MB
```

---

## 8. 运维：白名单、更新、回滚

### 8.1 误杀加白

```sh
adblock-fast allow example.com     # 立即对该域名放行，并写入 allowed_domain
```

LuCI：`服务 → AdBlock Fast → 允许的域名`。

### 8.2 更新清单

```sh
/etc/init.d/adblock-fast dl
```

默认触发时机仅三个：开机、WAN 接口 up、配置变更。清单源本身**每天**更新，长期不重启就不会刷新，建议配 cron：

```sh
# /etc/crontabs/root
0 4 * * * /etc/init.d/adblock-fast dl >/dev/null 2>&1
```

### 8.3 完全回滚

```sh
uci set adblock-fast.config.enabled='0'; uci commit adblock-fast
/etc/init.d/adblock-fast stop          # 会移除 dnsmasq 的 serversfile 并 reload
apk del adblock-fast luci-app-adblock-fast luci-i18n-adblock-fast-zh-cn
```

`stop` 是干净的：它把 `dhcp.@dnsmasq[0].serversfile` 删掉、`cleanup` 各实例配置，DNS 行为完全回到安装前。

### 8.4 与其他组件的兼容性

| 组件 | 是否受影响 | 说明 |
|---|---|---|
| OpenClash | 否 | 只多了一层 dnsmasq 本地域，劫持规则不动 |
| Docker 容器 | 否 | 容器 DNS 走 172.17.0.1/172.18.0.1 上的 dnsmasq 同一实例 |
| LuCI | 否 | 新增一个菜单项 |
| `opkg` 时代的教程 | — | 全部不适用，本机是 apk |

---

## 9. 遗留待办

- [ ] **cron 定时刷新清单**（见 8.2），否则清单长期不更新
- [ ] `dhcp.@dnsmasq[0].cachesize='0'`：运行态确实是 `cache-size=0`，OpenClash 的 `dnsmasq_cachesize=1000` 并未落地。与广告过滤无关，但每次解析都回源、体感变慢。属网络变更，需单独评估后调整
- [ ] 观察一周，按误杀情况决定是否追加 Hagezi Pro / 1Hosts Lite
- [ ] 若某类广告（如 YouTube 贴片）无法拦截：那是同域名下发内容，DNS 层天然做不到，属方案边界而非配置错误

---

## 10. 命令速查

```sh
# 状态
/etc/init.d/adblock-fast status
adblock-fast show_blocklist | head
adblock-fast check doubleclick.net

# 清单
adblock-fast sizes
/etc/init.d/adblock-fast dl          # 强制重下
/etc/init.d/adblock-fast killcache   # 清缓存

# 临时暂停（默认 20 秒，方便排障）
adblock-fast pause 300

# 白名单
adblock-fast allow example.com

# 配置
uci show adblock-fast
cat /etc/config/adblock-fast
```
