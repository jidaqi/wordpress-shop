#!/bin/bash

# 备份验证脚本
# 使用方法: ./verify-backup.sh [备份文件名.tar.gz]

set -e

if [ -z "$1" ]; then
    echo "❌ 请指定备份文件"
    echo "使用方法: ./verify-backup.sh wordpress-shop-backup-YYYYMMDD_HHMMSS.tar.gz"
    exit 1
fi

BACKUP_FILE="$1"

if [ ! -f "$BACKUP_FILE" ]; then
    echo "❌ 备份文件不存在: $BACKUP_FILE"
    exit 1
fi

echo "🔍 验证备份文件: $BACKUP_FILE"
echo "================================"

# 检查文件大小
echo "📊 备份文件信息:"
ls -lh "$BACKUP_FILE"
echo ""

# 验证校验和（如果存在）
CHECKSUM_FILE="${BACKUP_FILE}.sha256"
if [ -f "$CHECKSUM_FILE" ]; then
    echo "🔒 验证校验和..."
    if sha256sum -c "$CHECKSUM_FILE" 2>/dev/null || shasum -a 256 -c "$CHECKSUM_FILE" 2>/dev/null; then
        echo "✅ 校验和验证通过"
    else
        echo "❌ 校验和验证失败"
        exit 1
    fi
else
    echo "⚠️  未找到校验和文件"
fi

# 测试压缩包完整性
echo ""
echo "📦 测试压缩包完整性..."
if tar -tzf "$BACKUP_FILE" >/dev/null 2>&1; then
    echo "✅ 压缩包完整性正常"
else
    echo "❌ 压缩包损坏"
    exit 1
fi

# 显示压缩包内容概览
echo ""
echo "📁 备份内容概览:"
tar -tzf "$BACKUP_FILE" | head -20
echo "..."
echo "总文件数: $(tar -tzf "$BACKUP_FILE" | wc -l)"

# 检查关键文件
echo ""
echo "🔍 检查关键文件是否存在..."
TEMP_DIR=$(mktemp -d)
tar -xzf "$BACKUP_FILE" -C "$TEMP_DIR"

BACKUP_DIR=$(find "$TEMP_DIR" -name "wp-backup-*" -type d | head -1)
if [ -z "$BACKUP_DIR" ]; then
    echo "❌ 未找到备份目录"
    rm -rf "$TEMP_DIR"
    exit 1
fi

# 检查项目文件
if [ -f "$BACKUP_DIR/project/docker-compose.yaml" ]; then
    echo "✅ docker-compose.yaml 存在"
else
    echo "❌ docker-compose.yaml 缺失"
fi

if [ -f "$BACKUP_DIR/project/.env.production" ] || [ -f "$BACKUP_DIR/project/.env" ]; then
    echo "✅ 环境配置文件存在"
else
    echo "⚠️  未找到环境配置文件"
fi

# 检查数据库备份
if [ -f "$BACKUP_DIR/wordpress_db.sql" ]; then
    DB_SIZE=$(du -h "$BACKUP_DIR/wordpress_db.sql" | cut -f1)
    echo "✅ 数据库备份存在 ($DB_SIZE)"
    
    # 简单检查数据库文件内容
    if grep -q "WordPress" "$BACKUP_DIR/wordpress_db.sql" && grep -q "CREATE TABLE" "$BACKUP_DIR/wordpress_db.sql"; then
        echo "✅ 数据库备份内容正常"
    else
        echo "⚠️  数据库备份内容可能不完整"
    fi
else
    echo "❌ 数据库备份缺失"
fi

# 检查 WordPress 文件
if [ -d "$BACKUP_DIR/project/wp/html" ]; then
    WP_FILES=$(find "$BACKUP_DIR/project/wp/html" -name "*.php" | wc -l)
    echo "✅ WordPress 文件存在 ($WP_FILES 个 PHP 文件)"
    
    if [ -f "$BACKUP_DIR/project/wp/html/wp-config.php" ]; then
        echo "✅ wp-config.php 存在"
    else
        echo "⚠️  wp-config.php 缺失"
    fi
else
    echo "❌ WordPress 文件目录缺失"
fi

# 检查配置信息
if [ -f "$BACKUP_DIR/docker-compose-resolved.yml" ]; then
    echo "✅ Docker 配置信息存在"
else
    echo "⚠️  Docker 配置信息缺失"
fi

if [ -f "$BACKUP_DIR/system-info.txt" ]; then
    echo "✅ 系统信息存在"
else
    echo "⚠️  系统信息缺失"
fi

# 清理临时文件
rm -rf "$TEMP_DIR"

echo ""
echo "📋 验证总结:"
echo "================================"
echo "✅ 备份验证完成！"
echo ""
echo "💡 下一步："
echo "1. 将备份文件传输到目标服务器"
echo "2. 在目标服务器上解压并运行恢复脚本"
echo "3. 传输命令示例："
echo "   scp $BACKUP_FILE user@target-server:/opt/"
if [ -f "$CHECKSUM_FILE" ]; then
    echo "   scp $CHECKSUM_FILE user@target-server:/opt/"
fi
