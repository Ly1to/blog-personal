# blog-personal

个人博客源码仓库：**Hexo 8 + Butterfly 主题**，本地生成静态站点，再用 `deploy.sh` 推送到 `wrt`（OpenWrt x86 主机）上的 Docker nginx 容器托管。

- 站点（内网）：<http://192.168.1.1:8082>
- 文章目录：`source/_posts/*.md`
- 部署目标：`wrt:/srv/blog/www`（nginx 容器只读挂载）

> 只在内网开放，不做公网暴露。仓库里只放**源头**（文章、配置、主题），生成物不入库。

---

## 目录结构

```
hexo-blog/
├── _config.yml            # Hexo 主配置（站点信息、permalink、theme）
├── _config.butterfly.yml  # Butterfly 主题配置（菜单、头像、公告、样式）
├── scaffolds/             # hexo new 用的文章模板
├── source/
│   ├── _posts/            # ★ 文章正文（Markdown）
│   └── ...                # 页面（tags/categories 页由主题 layout 自动分发）
├── themes/butterfly/      # 主题（直接入库，便于回滚与离线构建）
├── deploy.sh              # 一键发布：generate + 打包推送 wrt
├── package.json           # 依赖与脚本
└── .github/dependabot.yml # npm 依赖自动更新
```

### 入库 / 忽略

| 纳入 | 忽略（`.gitignore`） |
|---|---|
| `_config*.yml`、`package.json` + lock | `node_modules/` |
| `source/_posts/*.md`、`scaffolds/` | `public/`（生成物） |
| `themes/`、`deploy.sh`、`.github/` | `db.json`（Hexo 缓存） |
| `README.md` | `*.log`、`.deploy*/` |

---

## 快速开始

### 首次安装

```bash
git clone git@github.com:Ly1to/blog-personal.git ~/Projects/hexo-blog
cd ~/Projects/hexo-blog
npm install
```

> 主题已随仓库提交（`themes/butterfly`），无需额外 clone。若主题缺失，可执行：
> `git clone --depth=1 -b master https://github.com/jerryc127/hexo-theme-butterfly.git themes/butterfly`
> 并安装渲染依赖：`npm i hexo-renderer-pug hexo-renderer-stylus hexo-util moment-timezone`

### 写一篇新文章

```bash
npx hexo new "文章标题"     # 生成 source/_posts/文章标题.md
```

打开生成的文件，补齐 front-matter 后写正文：

```yaml
---
title: 文章标题
date: 2026-11-11 21:15:00
tags:
  - 标签A
  - 标签B
categories:
  - 折腾记录
---
```

约定：**正文不再写 H1**（标题由 front-matter 的 `title` 渲染），开头可用 `>` 引用块写一句摘要。

### 本地预览

```bash
npx hexo server            # http://localhost:4000 ，改 md 会热更新
```

### 发布到 wrt

```bash
npx hexo clean && npx hexo generate && ./deploy.sh
```

`deploy.sh` 做的事：

1. `npx hexo generate` 生成 `public/`
2. `tar -C public -czf - . | ssh root@192.168.1.1 'tar -C /srv/blog/www -xzf -'` 覆盖式解包推送

> ⚠️ 推送是**覆盖写入**，不删除远端多余文件。若要清理残留（例如旧主题的 `fancybox/`），需手工删除——属于删除操作，先确认再执行。

---

## 常用命令

| 操作 | 命令 |
|---|---|
| 新建文章 | `npx hexo new "标题"` |
| 本地预览 | `npx hexo server` |
| 清理缓存 | `npx hexo clean` |
| 生成静态文件 | `npx hexo generate` |
| 一键发布 | `./deploy.sh` |
| 完整重建 + 发布 | `npx hexo clean && npx hexo generate && ./deploy.sh` |

### wrt 侧运维（只读查询为主）

```bash
ssh root@192.168.1.1 'docker ps --filter name=blog'          # 容器状态
ssh root@192.168.1.1 'docker logs --tail 20 blog'            # nginx 日志
ssh root@192.168.1.1 'ls -l /srv/blog/www'                   # 静态目录
ssh root@192.168.1.1 'cd /srv/blog && docker compose restart' # 重启容器
```

---

## 架构关系

```
本地 ~/Projects/hexo-blog          wrt 192.168.1.1
┌──────────────────────┐          ┌──────────────────────────────┐
│ source/_posts/*.md   │          │ /srv/blog/docker-compose.yml │
│ _config*.yml         │ deploy.sh│   nginx:alpine :8082         │
│ themes/butterfly     │ ───────▶ │   └─ 只读挂载                │
│ → public/ (生成物)   │   tar    │ /srv/blog/www  ← 静态文件    │
└──────────────────────┘          └──────────────────────────────┘
       博主侧（git 管理）                 运行侧（不入库）
```

- Lua/端口约定：80 是 LuCI（uhttpd），博客用 **8082**，避免和 LuCI 抢端口。
- 静态站没有后台与数据库，攻击面几乎为零，适合内网长期挂着。

---

## 配置备忘

| 文件 | 关键项 |
|---|---|
| `_config.yml` | `title`/`subtitle`/`description`、`permalink: :year/:month/:day/:title/`、`theme: butterfly` |
| `_config.butterfly.yml` | 导航菜单、头像、公告、封面与样式；`type: tags/categories` 页面由主题 `layout/page.pug` 分发 |

- 归档页 `/archives/`、标签页 `/tags/`、分类页 `/categories/` 由 generator 与主题自动生成，不需要手工建页面。
- 主题升级：`cd themes/butterfly && git pull`（仓库内已移除主题自带的 `.git`，升级前请先确认方式）。

---

## 提交约定

```bash
git add -A
git commit -m "docs: 新增「文章标题」"     # 新文章
git commit -m "feat: 配置导航菜单"        # 站点/主题配置变更
git commit -m "chore: 升级依赖"           # 依赖维护
git push
```

- 分支：`main`，远端 `origin` = `git@github.com:Ly1to/blog-personal.git`
- 不要在仓库里提交 `public/`、`db.json`、`node_modules/`
- 文章源文档与博客 md 若同时维护（如 `~/Projects/wrt-docs`），记得两处同步

---

## 排错

| 现象 | 处理 |
|---|---|
| `hexo new` 报目录非空 | 换空目录初始化，或手动在 `source/_posts/` 建 md |
| 生成后样式丢失 | 检查 `themes/butterfly` 是否完整、渲染依赖（pug/stylus）是否装好；`hexo clean` 后重建 |
| 页面 404 | 确认 `public/` 里有对应路径；`permalink` 改了要重新 generate 并推送 |
| 推送失败 | `ssh -o BatchMode=yes root@192.168.1.1 true` 先验证免密登录 |
| 更新后还是旧页面 | 浏览器强刷；确认 `hexo clean` 后重新生成、重新推送 |
| 主题渲染异常 | 查看 `_config.butterfly.yml` 缩进（YAML 对缩进敏感） |

---

## 相关记录

- 部署全过程：`~/Projects/wrt-docs/openwrt-hexo-blog-deploy.md`
- 主机约定与危险命令规则：`~/Projects/wrt-docs/AGENTS.md`
