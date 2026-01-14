FROM node:18-alpine AS frontend-builder

Build frontend

WORKDIR /app/frontend
COPY frontend/package.json ./
RUN npm install -g pnpm && pnpm install
COPY frontend/ ./
RUN pnpm build

Python backend stage

FROM python:3.12-slim

Install system dependencies including PostgreSQL server and client

RUN apt-get update && apt-get install -y 
    curl 
    postgresql 
    postgresql-contrib 
    sqlite3 
    && rm -rf /var/lib/apt/lists/*

Create app directory

WORKDIR /app

Copy backend code

COPY backend/ ./backend/

Install Python dependencies

WORKDIR /app/backend
RUN pip install --no-cache-dir -e .

Copy built frontend

COPY --from=frontend-builder /app/frontend/dist /app/backend/static/

Expose port

EXPOSE 8802

Health check

HEALTHCHECK --interval=30s --timeout=10s --start-period=60s --retries=3 
    CMD curl -f http://localhost:8802/api/health || exit 1

Script to check and start PostgreSQL

COPY --chmod=755 <<'EOF' /app/check_postgres.sh
#!/bin/bash

Function to start PostgreSQL service

start_postgresql() {
echo "Starting local PostgreSQL service..."

}

Check if external PostgreSQL is available

check_external_postgresql() {
if [ -n "$POSTGRES_HOST" ] && [ -n "$POSTGRES_PORT" ]; then
echo "检查外部 PostgreSQL 连接: $POSTGRES_HOST:$POSTGRES_PORT..."
timeout 10 bash -c 'until pg_isready -h $POSTGRES_HOST -p $POSTGRES_PORT 2>/dev/null; do
echo "等待外部 PostgreSQL...";
sleep 2;
done'
return $?
fi
return 1
}

Main logic

if check_external_postgresql; then
echo "使用外部 PostgreSQL 连接"
# 设置为 init_postgresql.py 期望的值
export POSTGRES_HOST=${POSTGRES_HOST:-localhost}
export POSTGRES_PORT=${POSTGRES_PORT:-5432}
export POSTGRES_USER=alpha_user
export POSTGRES_PASSWORD=alpha_pass
export POSTGRES_DB=alpha_arena
export POSTGRES_SNAPSHOT_DB=alpha_snapshots
export PG_ADMIN_USER=postgres
export PG_ADMIN_PASSWORD=postgres
else
echo "外部 PostgreSQL 不可用，启动本地 PostgreSQL..."
start_postgresql
# 设置为 init_postgresql.py 期望的值
export POSTGRES_HOST=localhost
export POSTGRES_PORT=5432
export POSTGRES_USER=alpha_user
export POSTGRES_PASSWORD=alpha_pass
export POSTGRES_DB=alpha_arena
export POSTGRES_SNAPSHOT_DB=alpha_snapshots
export PG_ADMIN_USER=postgres
export PG_ADMIN_PASSWORD=postgres
fi

#导出 PostgreSQL 密码环境变量

export PGPASSWORD=$POSTGRES_PASSWORD
echo "PostgreSQL 配置:"
echo "  主机: $POSTGRES_HOST:$POSTGRES_PORT"
echo "  用户: $POSTGRES_USER"
echo "  主数据库: $POSTGRES_DB"
echo "  快照数据库: $POSTGRES_SNAPSHOT_DB"
EOF

Start application with database initialization

CMD ["sh", "-c", " 
    mkdir -p /app/data && 
    
    # 运行 PostgreSQL 检查脚本 
    . /app/check_postgres.sh && 
    
    # 生成加密密钥 
    if [ ! -f /app/data/.encryption_key ]; then 
        python -c 'from cryptography.fernet import Fernet; print(Fernet.generate_key().decode())' > /app/data/.encryption_key; 
    fi && 
    export HYPERLIQUID_ENCRYPTION_KEY=$(cat /app/data/.encryption_key) && 
    
    # 初始化 PostgreSQL 数据库 
    echo '初始化 PostgreSQL 数据库...' && 
    python -m database.init_postgresql || echo '警告: PostgreSQL 初始化失败，将继续使用 SQLite' && 
    
    # 初始化 SQLite 数据库 
    echo '初始化 SQLite 数据库...' && 
    sqlite3 /app/data/hyperalpha.db \"VACUUM;\" 2>/dev/null || true && 
    python database/init_hyperliquid_tables.py || true && 
    python database/init_snapshot_db.py || true && 
    python database/migration_manager.py || true && 
    
    # 启动应用 
    echo '启动 Hyper Alpha Arena...' && 
    python -m uvicorn main:app --host 0.0.0.0 --port 8802 
"]