# ============================
# Frontend Build Stage
# ============================
FROM node:18-alpine AS frontend-builder

WORKDIR /app/frontend
COPY frontend/package.json ./
RUN npm install -g pnpm && pnpm install
COPY frontend/ ./
RUN pnpm build


# ============================
# Backend + PostgreSQL Stage
# ============================
FROM python:3.12-slim

# Install system dependencies
RUN apt-get update && apt-get install -y \
    curl \
    sudo \
    postgresql \
    postgresql-contrib \
    sqlite3 \
    && rm -rf /var/lib/apt/lists/*

# Create postgres user home
RUN mkdir -p /var/lib/postgresql && \
    chown -R postgres:postgres /var/lib/postgresql

# Create app directory
WORKDIR /app

# Copy backend code
COPY backend/ ./backend/

# Install Python dependencies
WORKDIR /app/backend
RUN pip install --no-cache-dir -e .

# Copy built frontend
COPY --from=frontend-builder /app/frontend/dist /app/backend/static/

# Expose port
EXPOSE 8802

# Health check
HEALTHCHECK --interval=30s --timeout=10s --start-period=60s --retries=3 \
    CMD curl -f http://localhost:8802/api/health || exit 1


# ============================
# PostgreSQL Startup Script
# ============================
COPY --chmod=755 <<'EOF' /app/check_postgres.sh
#!/bin/bash

DATA_DIR="/var/lib/postgresql/data"

start_postgresql() {
    echo "启动本地 PostgreSQL..."

    # 初始化数据库目录（第一次运行）
    if [ ! -d "$DATA_DIR" ]; then
        echo "初始化 PostgreSQL 数据目录..."
        mkdir -p "$DATA_DIR"
        chown -R postgres:postgres /var/lib/postgresql
        sudo -u postgres initdb -D "$DATA_DIR"
    fi

    # 启动 PostgreSQL
    echo "启动 PostgreSQL 服务..."
    sudo -u postgres pg_ctl -D "$DATA_DIR" -l /var/lib/postgresql/logfile start

    # 等待 PostgreSQL 启动
    echo "等待 PostgreSQL 启动..."
    until pg_isready -h localhost -p 5432 >/dev/null 2>&1; do
        echo "PostgreSQL 尚未就绪..."
        sleep 1
    done

    echo "本地 PostgreSQL 已启动"
}

# 主逻辑：始终使用本地 PostgreSQL
echo "使用本地 PostgreSQL..."
start_postgresql

# 设置环境变量
export POSTGRES_HOST=localhost
export POSTGRES_PORT=5432
export POSTGRES_USER=alpha_user
export POSTGRES_PASSWORD=alpha_pass
export POSTGRES_DB=alpha_arena
export POSTGRES_SNAPSHOT_DB=alpha_snapshots
export PG_ADMIN_USER=postgres
export PG_ADMIN_PASSWORD=postgres
export PGPASSWORD=$PG_ADMIN_PASSWORD

# 创建用户和数据库（幂等）
echo "创建 PostgreSQL 用户和数据库..."

sudo -u postgres psql <<EOF2
DO \$\$
BEGIN
    IF NOT EXISTS (SELECT FROM pg_roles WHERE rolname = 'alpha_user') THEN
        CREATE USER alpha_user WITH PASSWORD 'alpha_pass';
    END IF;
END
\$\$;

CREATE DATABASE alpha_arena OWNER alpha_user;
CREATE DATABASE alpha_snapshots OWNER alpha_user;
EOF2

echo "PostgreSQL 配置:"
echo "  主机: $POSTGRES_HOST:$POSTGRES_PORT"
echo "  用户: $POSTGRES_USER"
echo "  主数据库: $POSTGRES_DB"
echo "  快照数据库: $POSTGRES_SNAPSHOT_DB"
EOF


# ============================
# Start Application
# ============================
CMD ["sh", "-c", "\
    mkdir -p /app/data && \
    \
    # 启动 PostgreSQL \
    . /app/check_postgres.sh && \
    \
    # 生成加密密钥 \
    if [ ! -f /app/data/.encryption_key ]; then \
        python -c 'from cryptography.fernet import Fernet; print(Fernet.generate_key().decode())' > /app/data/.encryption_key; \
    fi && \
    export HYPERLIQUID_ENCRYPTION_KEY=$(cat /app/data/.encryption_key) && \
    \
    # 初始化 PostgreSQL 数据库 \
    echo '初始化 PostgreSQL 数据库...' && \
    python -m database.init_postgresql || echo '警告: PostgreSQL 初始化失败，将继续使用 SQLite' && \
    \
    # 初始化 SQLite 数据库 \
    echo '初始化 SQLite 数据库...' && \
    sqlite3 /app/data/hyperalpha.db \"VACUUM;\" 2>/dev/null || true && \
    python database/init_hyperliquid_tables.py || true && \
    python database/init_snapshot_db.py || true && \
    python database/migration_manager.py || true && \
    \
    # 启动应用 \
    echo '启动 Hyper Alpha Arena...' && \
    python -m uvicorn main:app --host 0.0.0.0 --port 8802 \
"]