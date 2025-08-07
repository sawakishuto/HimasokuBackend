#!/bin/bash
set -e

# Create additional databases for test environment
psql -v ON_ERROR_STOP=1 --username "$POSTGRES_USER" --dbname "$POSTGRES_DB" <<-EOSQL
    CREATE DATABASE himasoku_backend_test;
    GRANT ALL PRIVILEGES ON DATABASE himasoku_backend_test TO $POSTGRES_USER;
EOSQL
