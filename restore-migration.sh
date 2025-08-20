#!/bin/bash

# WordPress Docker 项目迁移恢复脚本
# 使用方法: ./restore-migration.sh

set -e

echo "🚀 开始恢复 WordPress Docker 项目..."

# 检查当前目录是否为备份目录
if [ ! -f "wordpress_db.sql" ] || [ ! -d "project" ]; then
    echo "❌ 当前目录不是备份目录"
    echo "请确保您在备份目录中运行此脚本"
    echo "目录应包含: wordpress_db.sql 和 project/ 文件夹"
    echo ""
    echo "正确的使用方法："
    echo "1. cd wp-backup-YYYYMMDD_HHMMSS"
    echo "2. ./restore-migration.sh"
    exit 1
fi

BACKUP_DIR=$(basename "$PWD")
PROJECT_NAME="wordpress-shop"

echo "📁 备份目录: $BACKUP_DIR"
echo "� 备份内容检查..."

# 显示备份内容
ls -la

echo ""

# 检查 Docker 和 Docker Compose
if ! command -v docker &> /dev/null; then
    echo "❌ Docker 未安装，请先安装 Docker"
    exit 1
fi

if ! command -v docker-compose &> /dev/null; then
    echo "❌ Docker Compose 未安装，请先安装 Docker Compose"
    exit 1
fi

echo "📁 恢复项目文件..."
# 检查是否在正确的位置运行
if [ ! -w "." ]; then
    echo "❌ 当前目录没有写权限"
    exit 1
fi

# 创建项目目录
TARGET_DIR="../${PROJECT_NAME}"
if [ -d "$TARGET_DIR" ]; then
    echo "⚠️  目标目录已存在: $TARGET_DIR"
    read -p "是否覆盖现有目录？(y/N): " -n 1 -r
    echo
    if [[ ! $REPLY =~ ^[Yy]$ ]]; then
        echo "❌ 用户取消恢复"
        exit 1
    fi
    echo "🗑️  备份现有目录..."
    mv "$TARGET_DIR" "${TARGET_DIR}.backup.$(date +%Y%m%d_%H%M%S)"
fi

# 复制项目文件到上级目录
echo "📂 恢复项目文件到: $TARGET_DIR"
cp -r project/ "$TARGET_DIR"

# 进入项目目录
cd "$TARGET_DIR"

# 确保脚本有执行权限
chmod +x *.sh 2>/dev/null || true

echo "🐳 拉取 Docker 镜像..."
# 拉取必要的镜像
docker-compose pull

echo "🗄️  恢复数据库..."
# 启动数据库容器
docker-compose up -d db

# 等待数据库就绪
echo "⏳ 等待数据库启动..."
sleep 30

# 导入数据库
if [ -f "../$BACKUP_DIR/wordpress_db.sql" ]; then
    echo "📥 导入 WordPress 数据库..."
    docker exec -i $(docker-compose ps -q db) mysql -u wordpress -pwordpress wordpress < "../$BACKUP_DIR/wordpress_db.sql"
else
    echo "⚠️  未找到数据库备份文件，将使用全新数据库"
fi

echo "🚀 启动所有服务..."
# 启动所有服务
docker-compose up -d

echo "⏳ 等待服务就绪..."
sleep 10

echo "📊 检查服务状态..."
docker-compose ps

echo "✅ 恢复完成！"
echo ""
echo "🌐 访问信息："
echo "- WordPress 前台: http://your-domain/"
echo "- WordPress 后台: http://your-domain/wp-admin/"
echo "- Traefik 控制台: http://your-domain:8080/"
echo ""
echo "⚙️  后续配置："
echo "1. 检查并更新 .env 文件中的域名配置"
echo "2. 如果使用 SSL，请配置证书"
echo "3. 检查 WordPress 中的站点 URL 设置"
