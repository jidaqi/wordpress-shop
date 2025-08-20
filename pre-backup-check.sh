#!/bin/bash

# WordPress Docker 项目备份前检查脚本
# 使用方法: ./pre-backup-check.sh

echo "🔍 WordPress Docker 项目备份前检查..."
echo "================================"

# 检查 Docker 环境
echo "🐳 检查 Docker 环境..."
if ! command -v docker &> /dev/null; then
    echo "❌ Docker 未安装"
    exit 1
else
    echo "✅ Docker 已安装: $(docker --version)"
fi

if ! command -v docker-compose &> /dev/null; then
    echo "❌ Docker Compose 未安装"
    exit 1
else
    echo "✅ Docker Compose 已安装: $(docker-compose --version)"
fi

# 检查项目状态
echo ""
echo "📋 检查项目状态..."
if [ ! -f "docker-compose.yaml" ] && [ ! -f "docker-compose.yml" ]; then
    echo "❌ 未找到 docker-compose.yaml 文件"
    exit 1
else
    echo "✅ 找到 docker-compose 配置文件"
fi

# 检查容器状态
echo ""
echo "📦 检查容器状态..."
CONTAINERS=$(docker-compose ps -q)
if [ -z "$CONTAINERS" ]; then
    echo "❌ 没有运行中的容器"
    echo "请先启动项目: docker-compose up -d"
    exit 1
fi

echo "运行中的容器:"
docker-compose ps

# 检查数据库连接
echo ""
echo "🗄️  检查数据库连接..."
DB_CONTAINER=$(docker-compose ps -q db)
if [ -z "$DB_CONTAINER" ]; then
    echo "❌ 数据库容器未运行"
else
    if docker exec "$DB_CONTAINER" mysqladmin ping -u wordpress -pwordpress --silent; then
        echo "✅ 数据库连接正常"
        
        # 检查数据库大小
        DB_SIZE=$(docker exec "$DB_CONTAINER" mysql -u wordpress -pwordpress -e "SELECT ROUND(SUM(data_length + index_length) / 1024 / 1024, 1) AS 'DB Size in MB' FROM information_schema.tables WHERE table_schema='wordpress';" --silent --skip-column-names)
        echo "📊 数据库大小: ${DB_SIZE} MB"
        
        # 检查表数量
        TABLE_COUNT=$(docker exec "$DB_CONTAINER" mysql -u wordpress -pwordpress -e "SELECT COUNT(*) FROM information_schema.tables WHERE table_schema='wordpress';" --silent --skip-column-names)
        echo "📊 数据库表数量: $TABLE_COUNT"
    else
        echo "❌ 数据库连接失败"
    fi
fi

# 检查磁盘空间
echo ""
echo "💾 检查磁盘空间..."
DISK_USAGE=$(df -h . | tail -1 | awk '{print $5}' | sed 's/%//')
AVAILABLE_SPACE=$(df -h . | tail -1 | awk '{print $4}')

echo "当前目录磁盘使用率: ${DISK_USAGE}%"
echo "可用空间: $AVAILABLE_SPACE"

if [ "$DISK_USAGE" -gt 85 ]; then
    echo "⚠️  磁盘空间不足，可能影响备份"
else
    echo "✅ 磁盘空间充足"
fi

# 检查项目文件大小
echo ""
echo "📁 检查项目文件大小..."
PROJECT_SIZE=$(du -sh . 2>/dev/null | cut -f1)
echo "项目总大小: $PROJECT_SIZE"

WP_HTML_SIZE=$(du -sh wp/html 2>/dev/null | cut -f1)
echo "WordPress 文件大小: $WP_HTML_SIZE"

WP_DB_SIZE=$(du -sh wp/database 2>/dev/null | cut -f1)
echo "数据库文件大小: $WP_DB_SIZE"

# 检查问题文件
echo ""
echo "🔍 检查可能的问题文件..."
PROBLEM_FILES=0

# 检查 socket 文件
if find . -name "*.sock" -type s 2>/dev/null | head -5; then
    echo "⚠️  发现 socket 文件（将被排除）"
    PROBLEM_FILES=$((PROBLEM_FILES + 1))
fi

# 检查大文件
echo ""
echo "📊 检查大文件 (>100MB)..."
find . -type f -size +100M 2>/dev/null | head -10 | while read file; do
    size=$(du -h "$file" | cut -f1)
    echo "大文件: $file ($size)"
    PROBLEM_FILES=$((PROBLEM_FILES + 1))
done

# 检查权限问题
echo ""
echo "🔐 检查文件权限..."
PERMISSION_ISSUES=$(find . -type f ! -readable 2>/dev/null | wc -l)
if [ "$PERMISSION_ISSUES" -gt 0 ]; then
    echo "⚠️  发现 $PERMISSION_ISSUES 个无读取权限的文件"
    find . -type f ! -readable 2>/dev/null | head -5
else
    echo "✅ 文件权限正常"
fi

# 检查 rsync 可用性
echo ""
echo "🔄 检查 rsync..."
if command -v rsync &> /dev/null; then
    echo "✅ rsync 已安装: $(rsync --version | head -1)"
else
    echo "❌ rsync 未安装，请安装: apt-get install rsync 或 yum install rsync"
fi

# 总结
echo ""
echo "📋 检查总结..."
echo "================================"

if [ "$DISK_USAGE" -lt 85 ] && [ "$PERMISSION_ISSUES" -eq 0 ] && command -v rsync &> /dev/null; then
    echo "✅ 系统状态良好，可以进行备份"
    echo ""
    echo "💡 建议的备份命令："
    echo "   ./backup-migration.sh"
else
    echo "⚠️  发现一些问题，建议解决后再进行备份"
    
    if [ "$DISK_USAGE" -ge 85 ]; then
        echo "   - 清理磁盘空间"
    fi
    
    if [ "$PERMISSION_ISSUES" -gt 0 ]; then
        echo "   - 修复文件权限问题"
    fi
    
    if ! command -v rsync &> /dev/null; then
        echo "   - 安装 rsync"
    fi
fi

echo ""
echo "🔧 如果备份过程中遇到 rsync 错误代码 23，这通常是正常的"
echo "   因为某些系统文件（如 .sock 文件）无法复制，但不影响备份完整性"
