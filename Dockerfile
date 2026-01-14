# Multi-stage build for Hyper Alpha Arena
FROM node:18-alpine AS frontend-builder

# Build frontend
WORKDIR /app/frontend
COPY frontend/package.json ./
RUN npm install -g pnpm && pnpm install
COPY frontend/ ./
RUN pnpm build

# Python backend stage
FROM python:3.12-slim

# Install system dependencies including PostgreSQL server and client
RUN apt-get update && apt-get install -y \
    curl \
    postgresql \
    postgresql-contrib \
    sqlite3 \
    && rm -rf /var/lib/apt/lists/*

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

# Script to check and start PostgreSQL
COPY --chmod=755 <<'EOF' /app/check_postgres.sh
#!/bin/bash

# Function to start PostgreSQL service
start_postgresql() {
    echo "Starting local PostgreSQL service..."
    
    # Initialize PostgreSQL data directory if not exists
    if [ ! -d "/var/lib/postgresql/data" ]; then
        mkdir -p /var/lib/postgresql/data
        chown -R postgres:postgres /var/lib/postgresql/data
        su postgres -c "initdb -D /var/lib/postgresql/data" 2>/dev/null
    fi
    
    # Start PostgreSQL service
    su postgres -c "pg_ctl -D /var/lib/postgresql/data -l /var/log/postgresql.log start" 2>/dev/null
    
    # Wait for PostgreSQL to start
    sleep 3
    
    # Create database and user if not exists
    su postgres -c "psql -c \"CREATE USER hyperalpha WITH PASSWORD 'hyperalpha';\"" 2>/dev/null || true
    su postgres -c "psql -c \"ALTER USER hyperalpha WITH SUPERUSER;\"" 2>/dev/null || true
    su postgres -c "psql -c \"CREATE DATABASE hyperalpha_db OWNER hyperalpha;\"" 2>/dev/null || true
    
    echo "Local PostgreSQL started successfully"
}

# Check if external PostgreSQL is available
check_external_postgresql() {
    if [ -n "$POSTGRES_HOST" ] && [ -n "$POSTGRES_PORT" ]; then
        echo "Checking external PostgreSQL at $POSTGRES_HOST:$POSTGRES_PORT..."
        timeout 10 bash -c 'until pg_isready -h $POSTGRES_HOST -p $POSTGRES_PORT 2>/dev/null; do
            echo "Waiting for PostgreSQL at $POSTGRES_HOST:$POSTGRES_PORT...";
            sleep 2;
        done'
        return $?
    fi
    return 1
}

# Main logic
if check_external_postgresql; then
    echo "Using external PostgreSQL connection"
    # Set environment variables for external PostgreSQL
    export POSTGRES_HOST=${POSTGRES_HOST:-localhost}
    export POSTGRES_PORT=${POSTGRES_PORT:-5432}
    export POSTGRES_USER=${POSTGRES_USER:-hyperalpha}
    export POSTGRES_PASSWORD=${POSTGRES_PASSWORD:-hyperalpha}
    export POSTGRES_DB=${POSTGRES_DB:-hyperalpha_db}
else
    echo "External PostgreSQL not available, starting local PostgreSQL..."
    start_postgresql
    # Set environment variables for local PostgreSQL
    export POSTGRES_HOST=localhost
    export POSTGRES_PORT=5432
    export POSTGRES_USER=hyperalpha
    export POSTGRES_PASSWORD=hyperalpha
    export POSTGRES_DB=hyperalpha_db
fi
EOF

# Start application with database initialization
CMD ["sh", "-c", " \
    mkdir -p /app/data && \
    \
    # Run PostgreSQL check script \
    /app/check_postgres.sh && \
    \
    # Generate encryption key if not exists \
    if [ ! -f /app/data/.encryption_key ]; then \
        python -c 'from cryptography.fernet import Fernet; print(Fernet.generate_key().decode())' > /app/data/.encryption_key; \
    fi && \
    export HYPERLIQUID_ENCRYPTION_KEY=$(cat /app/data/.encryption_key) && \
    \
    # Initialize databases \
    python -m database.init_postgresql || echo 'PostgreSQL initialization failed' && \
    sqlite3 /app/data/hyperalpha.db \"VACUUM;\" 2>/dev/null || true && \
    python database/init_hyperliquid_tables.py || true && \
    python database/init_snapshot_db.py || true && \
    python database/migration_manager.py || true && \
    \
    # Start application \
    echo 'Starting Hyper Alpha Arena...' && \
    python -m uvicorn main:app --host 0.0.0.0 --port 8802 \
"]