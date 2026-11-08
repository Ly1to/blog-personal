#!/usr/bin/env bash
# 一键发布：本地生成 Hexo 静态文件并推送到 wrt 的 nginx 容器
set -euo pipefail
cd "$(dirname "$0")"

echo "==> 生成静态文件"
npx hexo generate

echo "==> 推送到 wrt:/srv/blog/www"
tar -C public -czf - . | ssh -o BatchMode=yes root@192.168.1.1 'tar -C /srv/blog/www -xzf -'

echo "==> 完成，访问 http://192.168.1.1:8082"
