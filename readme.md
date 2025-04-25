# 生产环境（默认）
cp .env.production .env
docker compose up -d

# 开发环境
cp .env.development .env
docker compose up -d