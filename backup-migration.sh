#!/bin/bash

# WordPress Docker 项目迁移备份脚本
# 使用方法: ./backup-migration.sh

set -e

# 配置变量
BACKUP_DIR="wp-backup-$(date +%Y%m%d_%H%M%S)"
PROJECT_NAME="wordpress-shop"

echo "🚀 开始备份 WordPress Docker 项目..."

# 创建备份目录
mkdir -p "$BACKUP_DIR"

echo "📁 备份项目文件..."
# 备份整个项目目录（排除备份目录本身）
rsync -av --exclude="$BACKUP_DIR" --exclude="*.sock" ./ "$BACKUP_DIR/project/"

echo "🗄️  导出数据库..."
# 导出 WordPress 数据库
docker exec $(docker-compose ps -q db) mysqldump -u wordpress -pwordpress wordpress > "$BACKUP_DIR/wordpress_db.sql"

echo "📄 保存 Docker 镜像列表..."
# 保存当前使用的镜像版本
docker-compose config > "$BACKUP_DIR/docker-compose-resolved.yml"
docker images --format "table {{.Repository}}:{{.Tag}}\t{{.ID}}\t{{.Size}}" | grep -E "(wordpress|mysql|traefik)" > "$BACKUP_DIR/docker-images.txt"

echo "⚙️  保存容器配置..."
# 保存运行中的容器配置
docker-compose ps > "$BACKUP_DIR/containers-status.txt"

echo "📦 创建压缩包..."
tar -czf "${PROJECT_NAME}-backup-$(date +%Y%m%d_%H%M%S).tar.gz" "$BACKUP_DIR"

echo "✅ 备份完成！"
echo "📍 备份文件: ${PROJECT_NAME}-backup-$(date +%Y%m%d_%H%M%S).tar.gz"
echo "📍 备份目录: $BACKUP_DIR"

# 显示备份大小
du -sh "${PROJECT_NAME}-backup-$(date +%Y%m%d_%H%M%S).tar.gz"
du -sh "$BACKUP_DIR"

echo ""
echo "🔄 迁移步骤："
echo "1. 将备份文件传输到新服务器"
echo "2. 在新服务器上解压: tar -xzf 备份文件名.tar.gz"
echo "3. 运行恢复脚本: ./restore-migration.sh"
