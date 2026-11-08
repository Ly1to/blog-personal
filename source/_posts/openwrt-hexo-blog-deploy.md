---
title: 在 OpenWrt 上部署个人博客全记录
date: 2026-11-08 19:40:00
tags:
  - OpenWrt
  - Hexo
  - Docker
  - 博客搭建
categories:
  - 折腾记录
---

> 记录一次从技术路线讨论 → Hexo 静态博客搭建 → wrt Docker 部署 → 排错 → 主题美化 → 面板集成的完整过程。
>
> 环境：本机 Arch Linux（Node v26.13.0 / npm 12.2.2 / git 2.56.0），目标主机 wrt = `192.168.1.1`（OpenWrt 25.12.6 x86_64）。

---

## 目录

1. [目标与约束](#1-目标与约束)
2. [wrt 硬件与现状勘察](#2-wrt-硬件与现状勘察)
3. [技术路线讨论](#3-技术路线讨论)
4. [最终选型：Hexo + Docker nginx](#4-最终选型hexo--docker-nginx)
5. [本地搭建 Hexo](#5-本地搭建-hexo)
6. [wrt 端部署 nginx 容器](#6-wrt-端部署-nginx-容器)
7. [排错记录](#7-排错记录)
8. [架构关系：博主侧 vs 运行侧](#8-架构关系博主侧-vs-运行侧)
9. [git 版本管理](#9-git-版本管理)
10. [换主题 Butterfly](#10-换主题-butterfly)
11. [集成到 sun-panel](#11-集成到-sun-panel)
12. [样式配置踩坑：图片路径](#12-样式配置踩坑图片路径)
13. [当前状态与后续待办](#13-当前状态与后续待办)
14. [命令速查](#14-命令速查)

---

## 1. 目标与约束

**需求**：在 OpenWrt 主机上开一个**只在内网开放**的个人博客网站。

**约定**：

- `wrt` = `192.168.1.1`（OpenWrt 主机）
- 对 wrt 的危险命令（删除/重启/固件/磁盘/网络变更/关键进程等）执行前必须先征得同意，规则记录在 `~/Projects/wrt-docs/AGENTS.md`

---

## 2. wrt 硬件与现状勘察

只读查询获得的事实：

| 项 | 值 |
|---|---|
| 系统 | OpenWrt 25.12.6 r33311 (`x86/64`) |
| CPU | Intel Celeron N3350（双核 1.10GHz） |
| 内存 | 1.8GB（已用约 337MB，可用约 1.4GB） |
| 存储 | eMMC 28.7GB，已用 3%（剩约 27.8GB） |
| Docker | 已安装，Compose v5.1.4 |
| 已有容器 | filebrowser(:8080)、qbittorrent(:8081)、beszel(:8090)、sun-panel(:3002)、beszel-agent |
| 已占端口 | 80 = LuCI(uhttpd)、22 = dropbear、53 = dnsmasq、7890+ = clash |

**结论**：x86 + Docker 的"能力型软路由"，跑博客绰绰有余。

---

## 3. 技术路线讨论

### 3.1 静态 vs 动态的本质区别

- **静态**：网页是**事先生成好的一堆 HTML 文件**，服务器原样发出去。内容在发布那一刻固定。
- **动态**：网页在**访客访问时由程序现场拼出来**（PHP 读数据库 → 生成 HTML → 返回）。

一句话：**静态是"成品仓库"，动态是"现做现卖"。**

这个本质区别连锁决定了其他所有差异：

| 维度 | 静态 | 动态 |
|---|---|---|
| 服务器要什么 | 只要 Web 服务器 | 要 PHP/Node + 数据库 |
| 资源占用 | 几 MB | 上百 MB |
| 攻击面 | 几乎没有 | 有后台/数据库可攻 |
| 写文章 | 本地 Markdown → 生成 → 发布 | 网页后台直接写 |
| 修改生效 | 重新生成 + 推送 | 保存即生效 |
| 评论/搜索 | 需外挂第三方 | 程序内置 |
| 备份 | 文件 + git | 数据库文件 |

两者之间存在混合形态（静态博客 + 外挂评论、动态程序 + 页面缓存、动态后台 + 静态产出），是光谱而非二元对立。

### 3.2 动态博客（路线 B）选型对比

| 程序 | 技术栈 | 内存 | 特点 |
|---|---|---|---|
| Grav | PHP，无数据库 | ~50MB | 文件型、有后台、Markdown |
| **Typecho** | PHP + SQLite/MySQL | ~80MB | 中文、轻快、插件主题够用 |
| WordPress | PHP + MariaDB | ~400MB | 生态最大，但最重 |
| Ghost | Node + MySQL | ~300MB | 写作体验现代 |
| Halo | Java | ~500MB | 功能现代完整 |

**Typecho 现状查证**：v1.3.0 发布于 2026-01-20，v1.3.1-rc 在开发中，**开发活跃**，并非早年"更新慢"的印象。

### 3.3 Hexo（静态）与 Typecho（动态）对比

| 维度 | Hexo | Typecho |
|---|---|---|
| 写文章 | 本地 Markdown + 命令行 | 网页后台，随时在线写 |
| 发布流程 | 生成 + 推送 | 后台点发布 |
| 资源占用 | 极低（几 MB） | 低（~80–150MB） |
| 安全 | 零攻击面 | 有登录入口 |
| 数据 | Markdown + git | SQLite 单文件 |
| 主题美观度 | ★★★★★ | ★★★☆ |
| 评论 | 外挂第三方 | 内置 |
| 多设备写作 | 麻烦 | 方便 |

**结论**：真正的选择标准只有一个——**平时习惯怎么写作**。本地 Markdown 写就选静态，想随时网页写就选动态。

### 3.4 托管方式的三个选项

| 方案 | 优点 | 缺点 |
|---|---|---|
| 用自带 uhttpd 加端口 | 零安装 | 动 LuCI 配置有风险，升级可能被重置 |
| opkg 装 nginx 原生跑 | 不依赖 Docker | 污染系统环境，与现有架构不一致 |
| **Docker 跑 nginx** | 与现有 5 个容器风格统一、隔离、可随手删、不动 LuCI | 多一个 ~20MB 镜像 |

**结论**：Hexo 的**生成**不依赖 Docker（跑在本地电脑），但**托管**用 Docker nginx 更契合既有架构。

---

## 4. 最终选型：Hexo + Docker nginx

```
① 博主侧（源头，本地电脑）           ② 传输          ③ 运行侧（wrt）
~/Projects/hexo-blog  ──deploy.sh──▶  /srv/blog/www ──挂载──▶ nginx 容器 → :8082
Markdown + 配置 + 主题 + git                            （只读发文件）
```

- 生成：Hexo（本地 Node）
- 托管：wrt 上的 nginx 容器，只绑 LAN IP
- 版本管理：本地 git 仓库

---

## 5. 本地搭建 Hexo

### 5.1 目录踩坑

原计划用 `~/Projects/blog`，但该目录已存在（是一个 Vite 项目），`hexo init` 要求空目录：

```
FATAL ~/Projects/blog not empty
```

改用 **`~/Projects/hexo-blog`**。

### 5.2 初始化

```bash
mkdir -p ~/Projects/hexo-blog && cd ~/Projects/hexo-blog
npx --yes hexo-cli init .
```

`hexo init` 复用 `hexo-starter` 模板，安装依赖时因 pnpm 的 build scripts 策略失败：

```
Error: ERR_PNPM_IGNORED_BUILDS
  Ignored build scripts: hexo-util@3.3.0, hexo-util@4.0.0
```

于是删掉 pnpm 产物改用 npm：

```bash
rm -rf node_modules pnpm-lock.yaml
npm install
```

（npm 也提示 `hexo-util` 的 postinstall 被 allowScripts 阻止，但后续验证 highlighter 可用，不影响。）

### 5.3 生成验证

```bash
npx hexo version      # hexo: 8.1.2 / hexo-cli: 4.3.2
npx hexo generate     # 11 files generated
```

---

## 6. wrt 端部署 nginx 容器

### 6.1 改动清单（执行前说明）

1. 创建 `/srv/blog/www`（静态文件目录）
2. 写 `/srv/blog/docker-compose.yml`：`nginx:alpine`，监听 `192.168.1.1:8082`，只读挂载静态目录
3. 推送本地 `public/` 到 `/srv/blog/www`
4. `docker compose up -d` 启动并验证

### 6.2 最终生效的 compose 文件

`/srv/blog/docker-compose.yml`：

```yaml
services:
  blog:
    image: nginx:alpine
    container_name: blog
    restart: unless-stopped
    network_mode: bridge
    ports:
      - "192.168.1.1:8082:80"
    volumes:
      - /srv/blog/www:/usr/share/nginx/html:ro
```

> `network_mode: bridge` 是排错后补的关键项，见 [7.2](#72-问题二compose-自定义网络被-fw4-防火墙拦截)。

### 6.3 推送静态文件

```bash
cd ~/Projects/hexo-blog
tar -C public -czf - . | ssh root@192.168.1.1 'tar -C /srv/blog/www -xzf -'
```

### 6.4 一键发布脚本

`~/Projects/hexo-blog/deploy.sh`：

```bash
#!/usr/bin/env bash
# 一键发布：本地生成 Hexo 静态文件并推送到 wrt 的 nginx 容器
set -euo pipefail
cd "$(dirname "$0")"

echo "==> 生成静态文件"
npx hexo generate

echo "==> 推送到 wrt:/srv/blog/www"
tar -C public -czf - . | ssh -o BatchMode=yes root@192.168.1.1 'tar -C /srv/blog/www -xzf -'

echo "==> 完成，访问 http://192.168.1.1:8082"
```

---

## 7. 排错记录

### 7.1 问题一：docker pull 失败（EOF）

```
failed to resolve reference "docker.io/library/nginx:alpine": ... EOF
```

诊断发现：

- 直连 `https://registry-1.docker.io/v2/` 返回 `HTTP/2 401` → **网络本身是通的**（401 是正常响应）
- `nslookup registry-1.docker.io` → `198.18.0.254`（clash 的 fake-ip）
- 走 `-x http://127.0.0.1:7890` 返回 `407 Proxy Authentication Required` → 代理需认证，不可用

**结论**：首次 EOF 是瞬时抖动。**直接重试即成功**。

### 7.2 问题二：compose 自定义网络被 fw4 防火墙拦截

**现象**：容器正常启动，wrt 内部 `curl` 返回 200，但**局域网其他机器访问超时**。

**对比测试**：

| 端口 | 容器 | 网络 | 局域网访问 |
|---|---|---|---|
| 8080 | filebrowser | 172.17.0.0/24 (docker0) | ✅ 200 |
| 8081 | qbittorrent | 172.17.0.0/24 (docker0) | ✅ 200 |
| 3002 | sun-panel | 172.17.0.0/24 (docker0) | ✅ 200 |
| 8090 | beszel | 172.17.0.0/24 (docker0) | ✅ 200 |
| **8082** | **blog** | **172.18.0.2 (blog_default)** | ❌ 超时 |

**根因**：OpenWrt 使用 fw4(nftables)，只给 Docker 默认桥 `docker0` 生成了转发放行规则：

```
chain accept_to_docker {
    oifname "docker0" counter ... accept
}
```

而 `docker compose` 默认会新建独立网络（`br-3b9d704e307d`，172.18.0.0/16），不在放行范围内 → 转发被 REJECT。

**修复**：在 compose 里加 `network_mode: bridge`，让容器使用默认桥 docker0（与现有容器一致），**无需改动防火墙**。

```bash
docker compose up -d --force-recreate
# 之后：bridge=172.17.0.6，局域网访问 HTTP 200
```

**经验**：在这台 OpenWrt 上跑 compose 服务，若"容器起来了但外网访问不了"，基本就是这个原因。两个选择：

1. `network_mode: bridge`（最简单，但服务间不能用容器名互访）
2. 保留自定义网络 + 另加 fw4 放行规则（能动用容器名互访，但要改防火墙，属需确认操作）

---

## 8. 架构关系：博主侧 vs 运行侧

三层结构：

```
①博主侧（源头，本地）          ②传输          ③运行侧（wrt）
~/Projects/hexo-blog  ──deploy.sh──▶ /srv/blog/www ──挂载──▶ nginx → :8082
 源码 + git                                        只读发文件
```

| | 博主侧 `~/Projects/hexo-blog` | 运行侧 `/srv/blog` |
|---|---|---|
| 是什么 | 源码仓库（Hexo 工程 + git） | 运行时（compose + nginx 容器） |
| 有 git | ✅ | ❌ 不该有 |
| 跑什么 | Node / Hexo（生成） | 只有 nginx（发文件） |
| 懂 Markdown | 懂，它渲染的 | 完全不懂，原样吐 html |
| 修改方式 | 改 md/配置 → 生成 → 推送 | 不许直接改，`www` 会被覆盖 |
| 丢失后果 | 唯一真相，丢了就真没了 | 随时可删掉重建 |

**三条原则**：

1. **单向流动**：源 → `public/` → `www`，永远不要在 wrt 上直接编辑 `www`
2. **运行侧无状态**：容器和 `www` 都是可丢弃的成品
3. **备份 = 备份源**：`git clone → npm install → ./deploy.sh` 即可全量重建

**两种"博客系统"的澄清**：

- **Hexo（生成系统）** 在本地电脑，不参与日常访问
- **Docker/nginx（服务系统）** 在 wrt，只发成品

所以 wrt 上**既没有 Hexo，也没有 git，更没有 Markdown**——它只是台"会发文件的机器"。

### blog 容器里到底有什么

| 部分 | 内容 |
|---|---|
| 镜像自带 | nginx 1.31.8 二进制 + `/etc/nginx/` 默认配置；无 Node/Python/PHP/DB/git |
| 挂载进来 | `/srv/blog/www`（只读）→ 首页、文章页、css、js、img |
| 运行时 | 网络 `bridge=172.17.0.6`，端口 `192.168.1.1:8082→80`，仅 nginx master+worker |

资源占用：**CPU 0.00%，内存 3.3MB**。

---

## 9. git 版本管理

**位置**：`~/Projects/hexo-blog`（本地，不是 wrt）。

理由：git 只管理"源头"（文章 md + 配置 + 主题），`public/` 等生成物被 `.gitignore` 排除；wrt 上的 `www` 是部署目标，不入库。

### 初始化

```bash
cd ~/Projects/hexo-blog
git init
git add -A
git commit -m "init: Hexo 博客源码初始提交"
```

结果：

```
43bcec9 init: Hexo 博客源码初始提交
12 files changed, 3129 insertions(+)
```

### 入库 / 忽略

| 纳入 | 忽略（.gitignore） |
|---|---|
| `_config.yml`、`package.json` + lock | `node_modules/` |
| `source/_posts/*.md` | `public/` |
| `scaffolds/`、`deploy.sh`、`.github/` | `db.json` |
| `themes/`（主题文件） | `*.log`、`.deploy*/` |

### 主题是否入库

| 方式 | 优点 | 缺点 |
|---|---|---|
| clone 进 `themes/` 并提交 | 可复现、离线可建站 | 仓库变大 |
| git submodule | 仓库干净、易更新 | 多设备要多一步 |

**本方案选择直接提交**（简单可靠，出问题能回滚），注意移除主题自带的 `.git` 避免嵌套仓库。

---

## 10. 换主题 Butterfly

**关键认知**：换主题在**本地**做，wrt 上永不碰主题。主题提供模板和源样式（Stylus/Pug），需经 Hexo 编译成 CSS/JS/HTML，而 wrt 上没有 Node。

### 步骤

```bash
cd ~/Projects/hexo-blog
git clone --depth=1 -b master https://github.com/jerryc127/hexo-theme-butterfly.git themes/butterfly
rm -rf themes/butterfly/.git                       # 避免嵌套仓库
npm install hexo-renderer-pug hexo-renderer-stylus hexo-util moment-timezone
cp themes/butterfly/_config.yml _config.butterfly.yml
sed -i 's/^theme: landscape$/theme: butterfly/' _config.yml
npx hexo clean && npx hexo generate
./deploy.sh
```

- 主题版本：**Butterfly 5.7.2**（依赖 hexo-renderer-pug / stylus / hexo-util / moment-timezone）
- 部署验证：首页 11607 bytes，HTML 含 `butterfly`、`card-widget`、`site-title`

### 注意

- 改 `_config.butterfly.yml`、`inject` → 安全（自己的文件）
- 改 `themes/butterfly/layout/`、`source/` → 有效，但**主题更新时会冲突/被覆盖**
- 优先级：先看主题配置和 `inject` 能否实现，不够再改主题源码

---

## 11. 集成到 sun-panel

**目标**：在 sun-panel 首页加一个博客入口卡片。

### 现状

- `sun-panel` 通过 `docker run` 启动（无 compose 文件）
- 数据：`/srv/sun-panel/conf/database/database.db`（SQLite 单文件，无 WAL）
- 相关表：`item_icon`（卡片）、`item_icon_group`（分组）、`sqlite_sequence`

### 操作过程

1. 备份数据库：
   ```bash
   cp /srv/sun-panel/conf/database/database.db /srv/sun-panel/conf/database/database.db.bak-20261108
   ```
2. 短暂停止容器（约 5 秒，非核心服务）
3. 写入新条目（本地 python sqlite3 修改后整文件回传）：
   ```
   title=博客, only_name=blog, url=http://192.168.1.1:8082,
   description=个人博客, sort=4, group=1, card_type=1, open_method=2,
   icon_json={"itemType":1,"text":"📝","backgroundColor":"#8b5cf6"}
   ```
4. 启动容器并验证：`Up`、HTTP 200、日志正常、回读确认 4 条记录且未被覆盖

### 结果

| 标题 | 图标 | 地址 | 描述 |
|---|---|---|---|
| 博客 | 📝（紫底） | http://192.168.1.1:8082 | 个人博客 |

### 回滚

```bash
ssh root@192.168.1.1 'docker stop sun-panel && \
  cp /srv/sun-panel/conf/database/database.db.bak-20261108 /srv/sun-panel/conf/database/database.db && \
  docker start sun-panel'
```

---

## 12. 样式配置踩坑：图片路径

### 现象

在 `_config.butterfly.yml` 设置 `index_img` 后，主页横幅背景不显示。

### 原因

```yaml
index_img: /home/LycOor/Pictures/Wallpapers/xxx.png   # ❌ 本地文件系统路径
```

Hexo 原样输出到 HTML：

```html
<div id="page-header" style="background-image: url(/home/LycOor/Pictures/Wallpapers/...png)">
```

浏览器于是请求 `http://192.168.1.1:8082/home/LycOor/...` → wrt 上没有该文件 → **404**。

### 规则

| 写法 | 结果 |
|---|---|
| `/home/user/a.png` | ❌ 本地绝对路径，浏览器请求不到 |
| `C:\Users\xx\a.png` | ❌ 同上 |
| `/img/banner.webp` | ✅ 站点内路径，文件放在项目 `source/img/` |
| `https://.../a.jpg` | ✅ 完整 URL（外链图） |

### 修正

```bash
mkdir -p source/img
magick "原图.png" -resize 1920x -quality 85 source/img/banner.webp
# 3476×1126 PNG 7.2MB → 1920×622 webp 288KB（缩 25 倍）
```

```yaml
index_img: /img/banner.webp
```

```bash
npx hexo clean && npx hexo generate && ./deploy.sh
```

验证：`/img/banner.webp` HTTP 200，288388 bytes，`content-type: image/webp`。

### 补充

- `index_img` = 顶部横幅；`background` = 整个网页背景（当前仍为空）
- Hexo **不会自动压缩图片**，加图前应自行转 webp/jpg

---

## 13. 当前状态与后续待办

### 当前状态

| 项 | 值 |
|---|---|
| 本地源码 | `~/Projects/hexo-blog`（含 git，初始提交 43bcec9） |
| 一键发布 | `~/Projects/hexo-blog/deploy.sh` |
| wrt 静态目录 | `/srv/blog/www` |
| wrt compose | `/srv/blog/docker-compose.yml` |
| 容器 | `blog`（nginx:alpine，bridge=172.17.0.6，3.3MB 内存） |
| 访问地址 | `http://192.168.1.1:8082`（仅 LAN IP） |
| 主题 | Butterfly 5.7.2 |
| 站点信息 | title `LycOor` / author `Lycor Ye` / timezone `Asia/Shanghai` / language `en` |
| 横幅 | `/img/banner.webp`（webp，288KB） |
| sun-panel | 已加「博客」卡片 |

### 待办 / 可选

- [ ] **清理部署残留**：`/srv/blog/www` 仍有 landscape 旧主题的 `fancybox/`（无害但冗余）。做法是让 `deploy.sh` 推送前清空远端目录——**属删除操作，需先征得同意**
- [ ] **`language` 改 `zh-CN`**（当前仍是 `en`）
- [ ] **填写站点 description/subtitle**
- [ ] **配置导航菜单** `menu`（当前为空：无首页/归档/标签/分类入口）
- [ ] **作者卡片 Follow Me 按钮**：`_config.butterfly.yml` 第 289–292 行，`link` 仍是占位 `https://github.com/xxxxxx`
- [ ] **公告卡片** `card_announcement.content`：仍是 `This is my Blog`
- [ ] **头像** `avatar.img`：仍是默认蝴蝶图标
- [ ] 提交主题与配置到 git（Butterfly 文件 + `_config.butterfly.yml`）
- [ ] 可选：评论（Twikoo/Waline，需再起容器）、本地搜索、归档/标签/分类页
- [ ] 可选：nginx 定制（gzip、缓存头、404 页）——挂载自定义 `nginx.conf`
- [ ] 可选：内网域名 `blog.lan`（需 dnsmasq + 反代，属网络变更需确认）
- [ ] 可选：异地备份（GitHub 私有仓库，或 wrt 上裸仓库）

---

## 14. 命令速查

### 日常写作发布

```bash
cd ~/Projects/hexo-blog
npx hexo new "文章标题"     # 新建，编辑 source/_posts/xxx.md
npx hexo server             # 本地预览 http://localhost:4000
./deploy.sh                 # 生成并推送到 wrt
git add -A && git commit -m "写新文章"
```

### 查看运行状态

```bash
ssh root@192.168.1.1 'docker ps --filter name=blog'
ssh root@192.168.1.1 'docker logs --tail 20 blog'
curl -s -o /dev/null -w "%{http_code}\n" http://192.168.1.1:8082/
```

### 重启/重建容器

```bash
ssh root@192.168.1.1 'cd /srv/blog && docker compose restart'
ssh root@192.168.1.1 'cd /srv/blog && docker compose up -d --force-recreate'
```

### 灾难恢复（换电脑）

```bash
git clone <repo> ~/Projects/hexo-blog
cd ~/Projects/hexo-blog && npm install
./deploy.sh
```
