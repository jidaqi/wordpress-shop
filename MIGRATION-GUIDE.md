# WordPress Docker 项目迁移指南

## 方案一：完整备份迁移（推荐）

这是最安全可靠的迁移方案，包含所有数据和配置。

### 迁移流程概览

```
源服务器 → 备份脚本 → 传输到目标服务器 → 恢复脚本 → 完成迁移
```

### 📋 前置要求

#### 源服务器
- Docker 和 Docker Compose 正常运行
- WordPress 项目正在运行
- 有足够磁盘空间存储备份文件

#### 目标服务器
- 已安装 Docker 和 Docker Compose
- 有足够磁盘空间
- 网络可以访问源服务器（用于文件传输）

### 🚀 迁移步骤

#### 第一步：在源服务器备份

1. 确保 WordPress 项目正在运行：
   ```bash
   docker-compose ps
   ```

2. 运行备份脚本：
   ```bash
   ./backup-migration.sh
   ```

3. 备份完成后会生成：
   - `wp-backup-YYYYMMDD_HHMMSS/` 目录（包含所有文件）
   - `wordpress-shop-backup-YYYYMMDD_HHMMSS.tar.gz` 压缩包

#### 第二步：传输到目标服务器

选择以下任一方式传输备份文件：

**方式1：使用 scp**
```bash
scp wordpress-shop-backup-YYYYMMDD_HHMMSS.tar.gz user@target-server:/opt/
```

**方式2：使用 rsync**
```bash
rsync -avz wordpress-shop-backup-YYYYMMDD_HHMMSS.tar.gz user@target-server:/opt/
```

**方式3：使用云存储**
```bash
# 上传到云存储
aws s3 cp wordpress-shop-backup-YYYYMMDD_HHMMSS.tar.gz s3://your-bucket/

# 在目标服务器下载
aws s3 cp s3://your-bucket/wordpress-shop-backup-YYYYMMDD_HHMMSS.tar.gz ./
```

#### 第三步：在目标服务器恢复

1. 解压备份文件：
   ```bash
   tar -xzf wordpress-shop-backup-YYYYMMDD_HHMMSS.tar.gz
   ```

2. 进入备份目录：
   ```bash
   cd wp-backup-YYYYMMDD_HHMMSS
   ```

3. 运行恢复脚本：
   ```bash
   ./restore-migration.sh wp-backup-YYYYMMDD_HHMMSS
   ```

### 📁 备份内容说明

备份脚本会保存以下内容：

1. **项目文件**
   - `docker-compose.yaml` - Docker 编排配置
   - `.env` 文件 - 环境变量配置
   - `traefik.config/` - Traefik 反向代理配置
   - `wp/html/` - WordPress 网站文件
   - 其他项目相关文件

2. **数据库**
   - `wordpress_db.sql` - WordPress 数据库完整导出

3. **配置信息**
   - `docker-compose-resolved.yml` - 解析后的 Docker 配置
   - `docker-images.txt` - 使用的 Docker 镜像列表
   - `containers-status.txt` - 容器运行状态

### ⚙️ 环境配置

迁移完成后，请检查并更新以下配置：

1. **域名配置**
   - 编辑 `.env` 文件，更新 `DOMAIN` 变量
   - 如果域名发生变化，需要在 WordPress 后台更新站点 URL

2. **SSL 证书**
   - 如果使用 Let's Encrypt，证书会自动重新申请
   - 如果使用自定义证书，需要重新配置

3. **端口配置**
   - 检查 `HTTP_PORT` 和 `HTTPS_PORT` 设置
   - 确保目标服务器上这些端口可用

### 🔍 验证迁移结果

1. **检查服务状态**
   ```bash
   docker-compose ps
   ```

2. **检查网站访问**
   - 前台：`http://your-domain/`
   - 后台：`http://your-domain/wp-admin/`

3. **检查数据库连接**
   ```bash
   docker exec -it $(docker-compose ps -q db) mysql -u wordpress -pwordpress -e "SHOW TABLES;" wordpress
   ```

4. **检查文件权限**
   ```bash
   ls -la wp/html/wp-content/uploads/
   ```

### 🚨 故障排除

#### 常见问题

1. **数据库连接失败**
   - 检查数据库容器是否正常启动
   - 确认数据库密码正确
   - 等待数据库完全启动（通常需要30-60秒）

2. **文件权限问题**
   ```bash
   sudo chown -R www-data:www-data wp/html/
   sudo chmod -R 755 wp/html/
   ```

3. **WordPress 站点 URL 错误**
   - 在数据库中更新：
   ```sql
   UPDATE wp_options SET option_value = 'http://new-domain.com' WHERE option_name = 'home';
   UPDATE wp_options SET option_value = 'http://new-domain.com' WHERE option_name = 'siteurl';
   ```

4. **Traefik 路由问题**
   - 检查 `.env` 文件中的域名配置
   - 查看 Traefik 日志：`docker-compose logs traefik`

### 📊 性能优化建议

1. **备份优化**
   - 对于大型网站，可以先压缩再传输
   - 使用增量备份减少传输时间

2. **恢复优化**
   - 在恢复前预先拉取 Docker 镜像
   - 使用 SSD 硬盘提高 I/O 性能

### 🔐 安全注意事项

1. **备份文件安全**
   - 备份文件包含敏感信息，传输后及时删除
   - 使用加密传输方式

2. **数据库安全**
   - 迁移后更改数据库密码
   - 检查 WordPress 用户权限

3. **文件权限**
   - 确保敏感文件权限正确
   - 检查 `wp-config.php` 权限

### 📈 监控和维护

迁移完成后建议：

1. **设置监控**
   - 监控网站可用性
   - 监控服务器资源使用

2. **定期备份**
   - 在新服务器上设置定期备份
   - 测试备份恢复流程

3. **更新维护**
   - 定期更新 WordPress 核心、主题和插件
   - 定期更新 Docker 镜像
