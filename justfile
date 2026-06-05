set shell := ["bash", "-uc"]

# Start development stack from docker-compose.dev.yml
dev:
    docker compose -f docker-compose.dev.yml up --build -d

# Stop development stack and remove containers
dev-down:
    docker compose -f docker-compose.dev.yml down

admin-local:
    set -a && source admin_panel/.env.local && set +a; cd admin_panel && uv run python manage.py runserver

# Open psql using variables from .env.local
admin-psql:
    set -a && source admin_panel/.env.local && set +a; PGPASSWORD="$POSTGRES_PASSWORD" psql -h "$POSTGRES_HOST" -U "$POSTGRES_USER" -d "$POSTGRES_DB"

# Load database_dump.sql into Postgres
admin-load-fw-data:
    set -a && source admin_panel/.env.local && set +a; PGPASSWORD="$POSTGRES_PASSWORD" psql -h "$POSTGRES_HOST" -U "$POSTGRES_USER" -d "$POSTGRES_DB" -f admin_panel/database_dump.sql

# Dump current Postgres DB to admin_panel/database_dump.sql
admin-dump-db:
    set -a && source admin_panel/.env.local && set +a; PGPASSWORD="$POSTGRES_PASSWORD" pg_dump -h "$POSTGRES_HOST" -U "$POSTGRES_USER" -d "$POSTGRES_DB" --clean --if-exists --no-owner --no-privileges > admin_panel/database_dump.sql

# Run Movies ETL locally
etl-local:
    set -a && source movies_etl/.env.local && set +a; cd movies_etl && uv run python -m app.main

# Run Elasticsearch index initialization container
elastic-init:
    docker compose -f docker-compose.dev.yml up elastic-init

movies-api-local:
    set -a && source movies_api/.env.local && set +a; cd movies_api && uv run uvicorn app.main:app --host 0.0.0.0 --port 8000 --reload