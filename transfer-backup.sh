#!/bin/bash

# 备份文件传输脚本
# 使用方法: ./transfer-backup.sh [备份文件名] [目标服务器] [用户名] [目标目录] [私钥文件]

set -e

# 参数检查
if [ "$#" -lt 3 ]; then
    echo "❌ 参数不足"
    echo "使用方法: ./transfer-backup.sh [备份文件名] [目标服务器] [用户名] [目标目录] [私钥文件]"
    echo "示例1: ./transfer-backup.sh wordpress-shop-backup-20250820_070032.tar.gz 44.214.48.78 ec2-user /opt"
    echo "示例2: ./transfer-backup.sh wordpress-shop-backup-20250820_070032.tar.gz 44.214.48.78 ec2-user /opt ~/.ssh/my-key.pem"
    exit 1
fi

BACKUP_FILE="$1"
TARGET_SERVER="$2"
USERNAME="$3"
TARGET_DIR="${4:-/opt}"
PRIVATE_KEY="$5"

# 构建 SSH 选项
SSH_OPTS=""
SCP_OPTS=""
if [ -n "$PRIVATE_KEY" ]; then
    if [ ! -f "$PRIVATE_KEY" ]; then
        echo "❌ 私钥文件不存在: $PRIVATE_KEY"
        exit 1
    fi
    SSH_OPTS="-i $PRIVATE_KEY"
    SCP_OPTS="-i $PRIVATE_KEY"
    echo "🔑 使用私钥文件: $PRIVATE_KEY"
fi

echo "🚀 开始传输备份文件到目标服务器..."
echo "================================"
echo "备份文件: $BACKUP_FILE"
echo "目标服务器: $TARGET_SERVER"
echo "用户名: $USERNAME"
echo "目标目录: $TARGET_DIR"
echo ""

# 检查备份文件是否存在
if [ ! -f "$BACKUP_FILE" ]; then
    echo "❌ 备份文件不存在: $BACKUP_FILE"
    exit 1
fi

# 显示文件信息
echo "📊 备份文件信息:"
ls -lh "$BACKUP_FILE"
echo ""

# 检查 SSH 连接
echo "🔍 测试 SSH 连接..."
if ssh $SSH_OPTS -o ConnectTimeout=10 -o BatchMode=yes "$USERNAME@$TARGET_SERVER" exit 2>/dev/null; then
    echo "✅ SSH 连接正常"
else
    echo "⚠️  SSH 连接失败"
    echo ""
    echo "🔧 可能的解决方案："
    if [ -z "$PRIVATE_KEY" ]; then
        echo "1. 使用 EC2 私钥: ./transfer-backup.sh $BACKUP_FILE $TARGET_SERVER $USERNAME $TARGET_DIR ~/.ssh/your-key.pem"
        echo "2. 配置 SSH 密钥对"
        echo "3. 通过 AWS 控制台连接配置密钥"
    else
        echo "1. 检查私钥文件权限: chmod 600 $PRIVATE_KEY"
        echo "2. 确认私钥文件正确"
        echo "3. 检查目标服务器的公钥配置"
    fi
    echo ""
    read -p "是否继续尝试传输？(y/N): " -n 1 -r
    echo
    if [[ ! $REPLY =~ ^[Yy]$ ]]; then
        exit 1
    fi
fi

# 检查目标目录
echo "📁 检查目标目录..."
if ssh $SSH_OPTS "$USERNAME@$TARGET_SERVER" "[ -d '$TARGET_DIR' ] && [ -w '$TARGET_DIR' ]" 2>/dev/null; then
    echo "✅ 目标目录可写: $TARGET_DIR"
else
    echo "⚠️  目标目录可能不存在或无写权限，尝试创建..."
    if ssh $SSH_OPTS "$USERNAME@$TARGET_SERVER" "sudo mkdir -p '$TARGET_DIR' && sudo chown $USERNAME:$USERNAME '$TARGET_DIR'" 2>/dev/null; then
        echo "✅ 目标目录已创建"
    else
        echo "❌ 无法创建目标目录，请手动创建或检查权限"
        exit 1
    fi
fi

# 传输备份文件
echo "📤 传输备份文件..."
TRANSFER_START=$(date +%s)

if scp $SCP_OPTS -C "$BACKUP_FILE" "$USERNAME@$TARGET_SERVER:$TARGET_DIR/"; then
    TRANSFER_END=$(date +%s)
    TRANSFER_TIME=$((TRANSFER_END - TRANSFER_START))
    echo "✅ 备份文件传输成功"
    echo "⏱️  传输耗时: ${TRANSFER_TIME} 秒"
else
    echo "❌ 备份文件传输失败"
    exit 1
fi

# 传输校验和文件（如果存在）
CHECKSUM_FILE="${BACKUP_FILE}.sha256"
if [ -f "$CHECKSUM_FILE" ]; then
    echo "🔒 传输校验和文件..."
    if scp $SCP_OPTS "$CHECKSUM_FILE" "$USERNAME@$TARGET_SERVER:$TARGET_DIR/"; then
        echo "✅ 校验和文件传输成功"
    else
        echo "⚠️  校验和文件传输失败，但不影响恢复"
    fi
fi

# 在目标服务器上验证文件
echo "🔍 验证传输结果..."
REMOTE_SIZE=$(ssh $SSH_OPTS "$USERNAME@$TARGET_SERVER" "ls -l '$TARGET_DIR/$(basename "$BACKUP_FILE")'" 2>/dev/null | awk '{print $5}')
LOCAL_SIZE=$(ls -l "$BACKUP_FILE" | awk '{print $5}')

if [ "$REMOTE_SIZE" = "$LOCAL_SIZE" ]; then
    echo "✅ 文件大小验证通过"
else
    echo "❌ 文件大小不匹配，可能传输不完整"
    echo "本地文件大小: $LOCAL_SIZE"
    echo "远程文件大小: $REMOTE_SIZE"
    exit 1
fi

# 在目标服务器上验证校验和（如果存在）
if [ -f "$CHECKSUM_FILE" ]; then
    echo "🔒 验证远程文件校验和..."
    if ssh $SSH_OPTS "$USERNAME@$TARGET_SERVER" "cd '$TARGET_DIR' && sha256sum -c '$(basename "$CHECKSUM_FILE")'" 2>/dev/null; then
        echo "✅ 校验和验证通过"
    else
        echo "⚠️  校验和验证失败或不支持"
    fi
fi

echo ""
echo "🎉 传输完成！"
echo "================================"
echo "📍 远程文件路径: $TARGET_DIR/$(basename "$BACKUP_FILE")"
echo ""
echo "🔄 下一步："
echo "1. 登录目标服务器:"
if [ -n "$PRIVATE_KEY" ]; then
    echo "   ssh $SSH_OPTS $USERNAME@$TARGET_SERVER"
else
    echo "   ssh $USERNAME@$TARGET_SERVER"
fi
echo ""
echo "2. 解压备份文件:"
echo "   cd $TARGET_DIR"
echo "   tar -xzf $(basename "$BACKUP_FILE")"
echo ""
echo "3. 运行恢复脚本:"
echo "   cd wp-backup-*"
echo "   ./restore-migration.sh wp-backup-*"
echo ""
echo "💡 或者使用一键命令:"
if [ -n "$PRIVATE_KEY" ]; then
    echo "ssh $SSH_OPTS $USERNAME@$TARGET_SERVER \"cd $TARGET_DIR && tar -xzf $(basename "$BACKUP_FILE") && cd wp-backup-* && ./restore-migration.sh wp-backup-*\""
else
    echo "ssh $USERNAME@$TARGET_SERVER \"cd $TARGET_DIR && tar -xzf $(basename "$BACKUP_FILE") && cd wp-backup-* && ./restore-migration.sh wp-backup-*\""
fi
