# 快速恢复指南

基于您当前在目标服务器上的情况，以下是具体的恢复步骤：

## 📍 当前状态
- 您已经在目标服务器上
- 备份文件已解压到 `wp-backup-20250820_070021` 目录
- 备份目录结构：
  ```
  wp-backup-20250820_070021/
  ├── project/                    # 项目文件
  ├── wordpress_db.sql           # 数据库备份
  ├── containers-status.txt      # 容器状态
  ├── docker-compose-resolved.yml
  ├── docker-images.txt
  └── system-info.txt
  ```

## 🚀 立即执行的恢复步骤

### 1. 确保在备份目录中
```bash
cd wp-backup-20250820_070021
pwd  # 确认当前位置
```

### 2. 运行恢复脚本
```bash
# 恢复脚本会自动处理所有步骤
./restore-migration.sh
```

### 3. 如果恢复脚本不存在，手动执行以下步骤

#### 3.1 复制项目文件
```bash
# 从备份目录复制项目到上级目录
cp -r project/ ../wordpress-shop
cd ../wordpress-shop
```

#### 3.2 安装 Docker 和 Docker Compose（如果未安装）
```bash
# 检查是否已安装
docker --version
docker-compose --version

# 如果未安装，执行安装
sudo yum update -y
sudo yum install -y docker
sudo systemctl start docker
sudo systemctl enable docker
sudo usermod -aG docker ec2-user

# 安装 Docker Compose
sudo curl -L "https://github.com/docker/compose/releases/latest/download/docker-compose-$(uname -s)-$(uname -m)" -o /usr/local/bin/docker-compose
sudo chmod +x /usr/local/bin/docker-compose

# 重新登录以使用户组生效
exit
# 重新 SSH 登录后继续
```

#### 3.3 拉取 Docker 镜像
```bash
cd wordpress-shop
docker-compose pull
```

#### 3.4 启动数据库容器
```bash
docker-compose up -d db
sleep 30  # 等待数据库启动
```

#### 3.5 导入数据库
```bash
# 回到备份目录导入数据库
docker exec -i $(docker-compose ps -q db) mysql -u wordpress -pwordpress wordpress < ../wp-backup-20250820_070021/wordpress_db.sql
```

#### 3.6 启动所有服务
```bash
docker-compose up -d
```

#### 3.7 检查服务状态
```bash
docker-compose ps
docker-compose logs
```

## 🔧 配置更新

### 1. 检查环境配置
```bash
# 查看当前环境配置
cat .env*

# 根据新服务器情况更新域名等配置
cp .env.production .env
nano .env  # 编辑域名等配置
```

### 2. 验证网站访问
```bash
# 检查端口是否监听
sudo netstat -tlnp | grep :80
sudo netstat -tlnp | grep :443

# 检查防火墙设置
sudo iptables -L
```

## 🚨 常见问题排除

### Docker 权限问题
```bash
sudo systemctl start docker
sudo usermod -aG docker $USER
# 重新登录
```

### 端口被占用
```bash
# 查看端口使用情况
sudo netstat -tlnp | grep :80
sudo netstat -tlnp | grep :443

# 停止占用端口的服务
sudo systemctl stop httpd  # 或 nginx
```

### 数据库连接问题
```bash
# 查看数据库容器日志
docker-compose logs db

# 手动连接测试
docker exec -it $(docker-compose ps -q db) mysql -u wordpress -pwordpress
```

## ✅ 完成验证

1. **检查所有容器运行状态**
   ```bash
   docker-compose ps
   ```

2. **访问网站**
   - 通过服务器 IP 访问（如果没有域名）
   - 检查 WordPress 前台和后台

3. **检查数据完整性**
   ```bash
   # 检查数据库表
   docker exec $(docker-compose ps -q db) mysql -u wordpress -pwordpress -e "SHOW TABLES;" wordpress
   
   # 检查文件
   ls -la wp/html/wp-content/uploads/
   ```

## 📞 需要帮助？

如果遇到问题，请提供以下信息：
- 错误日志：`docker-compose logs`
- 容器状态：`docker-compose ps`
- 系统信息：`uname -a && docker --version`
