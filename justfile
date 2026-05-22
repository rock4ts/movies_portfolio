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

# Load fw_data.sql into Postgres
admin-load-fw-data:
    set -a && source admin_panel/.env.local && set +a; PGPASSWORD="$POSTGRES_PASSWORD" psql -h "$POSTGRES_HOST" -U "$POSTGRES_USER" -d "$POSTGRES_DB" -f admin_panel/fw_data.sql