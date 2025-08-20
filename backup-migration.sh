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
# 备份整个项目目录（排除备份目录本身和常见问题文件）
rsync -av \
    --exclude="$BACKUP_DIR" \
    --exclude="*.sock" \
    --exclude="wp/database/mysql.sock" \
    --exclude="wp/database/auto.cnf" \
    --exclude="wp/database/ib_logfile*" \
    --exclude="wp/database/mysql/general_log.CSV" \
    --exclude="wp/database/mysql/slow_log.CSV" \
    --exclude="**/node_modules/" \
    --exclude="**/.git/" \
    --exclude="**/__pycache__/" \
    --exclude="**/tmp/" \
    --exclude="**/temp/" \
    --partial \
    --ignore-errors \
    ./ "$BACKUP_DIR/project/"

# 检查 rsync 结果
RSYNC_EXIT_CODE=$?
if [ $RSYNC_EXIT_CODE -eq 0 ]; then
    echo "✅ 项目文件备份完成"
elif [ $RSYNC_EXIT_CODE -eq 23 ]; then
    echo "⚠️  项目文件备份完成，但有部分文件被跳过（通常是系统文件或锁文件，这是正常的）"
elif [ $RSYNC_EXIT_CODE -eq 24 ]; then
    echo "⚠️  项目文件备份完成，但有部分文件在传输过程中消失（通常是临时文件，这是正常的）"
else
    echo "❌ 项目文件备份出现错误，退出代码: $RSYNC_EXIT_CODE"
    echo "但继续执行其他备份步骤..."
fi

echo "🗄️  导出数据库..."
# 检查数据库容器是否运行
DB_CONTAINER=$(docker-compose ps -q db)
if [ -z "$DB_CONTAINER" ]; then
    echo "❌ 数据库容器未找到或未运行"
    echo "请确保项目正在运行: docker-compose ps"
    exit 1
fi

# 等待数据库就绪
echo "⏳ 检查数据库连接..."
for i in {1..10}; do
    if docker exec "$DB_CONTAINER" mysqladmin ping -u wordpress -pwordpress --silent; then
        echo "✅ 数据库连接正常"
        break
    fi
    if [ $i -eq 10 ]; then
        echo "❌ 数据库连接超时"
        exit 1
    fi
    echo "等待数据库就绪... ($i/10)"
    sleep 3
done

# 导出 WordPress 数据库
if docker exec "$DB_CONTAINER" mysqldump -u wordpress -pwordpress --single-transaction --routines --triggers wordpress > "$BACKUP_DIR/wordpress_db.sql"; then
    echo "✅ 数据库导出成功"
    # 检查导出文件大小
    DB_SIZE=$(du -h "$BACKUP_DIR/wordpress_db.sql" | cut -f1)
    echo "📊 数据库备份文件大小: $DB_SIZE"
else
    echo "❌ 数据库导出失败"
    exit 1
fi

echo "📄 保存 Docker 镜像列表..."
# 保存当前使用的镜像版本
if docker-compose config > "$BACKUP_DIR/docker-compose-resolved.yml"; then
    echo "✅ Docker 配置已保存"
else
    echo "⚠️  Docker 配置保存失败，跳过..."
fi

if docker images --format "table {{.Repository}}:{{.Tag}}\t{{.ID}}\t{{.Size}}" | grep -E "(wordpress|mysql|traefik)" > "$BACKUP_DIR/docker-images.txt"; then
    echo "✅ Docker 镜像列表已保存"
else
    echo "⚠️  Docker 镜像列表保存失败，跳过..."
fi

echo "⚙️  保存容器配置..."
# 保存运行中的容器配置
if docker-compose ps > "$BACKUP_DIR/containers-status.txt"; then
    echo "✅ 容器状态已保存"
else
    echo "⚠️  容器状态保存失败，跳过..."
fi

# 保存环境信息
echo "💾 保存环境信息..."
{
    echo "=== 备份时间 ==="
    date
    echo ""
    echo "=== 系统信息 ==="
    uname -a
    echo ""
    echo "=== Docker 版本 ==="
    docker --version
    docker-compose --version
    echo ""
    echo "=== 磁盘使用情况 ==="
    df -h .
} > "$BACKUP_DIR/system-info.txt"

echo "📦 创建压缩包..."
BACKUP_ARCHIVE="${PROJECT_NAME}-backup-$(date +%Y%m%d_%H%M%S).tar.gz"

# 创建压缩包时显示进度
if tar -czf "$BACKUP_ARCHIVE" "$BACKUP_DIR" 2>/dev/null; then
    echo "✅ 压缩包创建成功: $BACKUP_ARCHIVE"
else
    echo "❌ 压缩包创建失败"
    exit 1
fi

echo "✅ 备份完成！"
echo "📍 备份文件: $BACKUP_ARCHIVE"
echo "📍 备份目录: $BACKUP_DIR"

# 显示备份大小和校验信息
echo ""
echo "📊 备份统计："
echo "压缩包大小: $(du -sh "$BACKUP_ARCHIVE" | cut -f1)"
echo "备份目录大小: $(du -sh "$BACKUP_DIR" | cut -f1)"
echo "文件数量: $(find "$BACKUP_DIR" -type f | wc -l | tr -d ' ') 个文件"

# 生成校验和
echo "🔒 生成校验和..."
if command -v sha256sum >/dev/null 2>&1; then
    sha256sum "$BACKUP_ARCHIVE" > "${BACKUP_ARCHIVE}.sha256"
    echo "SHA256: $(cat "${BACKUP_ARCHIVE}.sha256")"
elif command -v shasum >/dev/null 2>&1; then
    shasum -a 256 "$BACKUP_ARCHIVE" > "${BACKUP_ARCHIVE}.sha256"
    echo "SHA256: $(cat "${BACKUP_ARCHIVE}.sha256")"
else
    echo "⚠️  无法生成校验和，建议安装 sha256sum 或 shasum"
fi

echo ""
echo "🔄 迁移步骤："
echo "1. 将备份文件传输到新服务器"
echo "2. 在新服务器上解压: tar -xzf 备份文件名.tar.gz"
echo "3. 运行恢复脚本: ./restore-migration.sh"
